import Foundation

/// Argus Scout: Pre-Cognition Service.
/// Runs in background to detect "Near Breakout" or "High Interest" symbols
/// Abandoned to check signature first. pre-fetches their heavy data (Hermes News, Fundamentals) to ensure
/// zero-latency execution when the user or AutoPilot acts.
final class ArgusScoutService: Sendable {
    static let shared = ArgusScoutService()
    
    // private let marketProvider = MarketDataProvider.shared (REMOVED)
    private let logger = AutoPilotLogger.shared
    
    // Stats
    private var skippedCandidates: Int = 0
    private var analyzedCandidates: Int = 0
    
    private init() {}
    
    /// Entry point: Scout the watchlist for opportunities.
    /// Call this periodically (e.g. every 5 minutes) from ViewModel.
    /// Returns: List of (Symbol, Score) tuples for high-conviction candidates.
    func scoutOpportunities(watchlist: [String], currentQuotes: [String: Quote]) async -> [(String, Double)] {
        // 0. System Health Check
        let sysHealth = await HeimdallOrchestrator.shared.checkSystemHealth()
        if sysHealth == .critical {
            print("🔭 Scout: Sistem Sağlığı Kritik (Heimdall). Tarama iptal edildi.")
            return []
        }
        
        print("🔭 Scout: Scanning \(watchlist.count) symbols for opportunities...")
        
        // Batching to prevent Rate Limit (Yahoo/Network Throttling)
        // Process in chunks of 5
        let batchSize = 5
        var candidates: [(String, Double)] = []
        
        let chunks = watchlist.chunked(into: batchSize)
        print("🔭 Scout: Processing \(chunks.count) batches...")
        
        for (index, batch) in chunks.enumerated() {
            print("🔭 Scout: Batch \(index + 1)/\(chunks.count) (\(batch.joined(separator: ", ")))")
            
            let batchResults = await withTaskGroup(of: (String, Double)?.self) { group in
                for symbol in batch {
                    group.addTask {
                        var effectiveQuote = currentQuotes[symbol]
                        
                        // FETCH ON DEMAND if missing (User Requirement)
                        if effectiveQuote == nil {
                            // print("🔭 Scout: Fetching missing quote for \(symbol)...")
                            if let fetched = try? await HeimdallOrchestrator.shared.requestQuote(symbol: symbol, context: .background) {
                                effectiveQuote = fetched
                            }
                        }
                        
                        guard let validQuote = effectiveQuote else { return nil }
                        return await self.checkSymbol(symbol, quote: validQuote)
                    }
                }
                
                var results: [(String, Double)] = []
                for await res in group {
                    if let val = res { results.append(val) }
                }
                return results
            }
            
            candidates.append(contentsOf: batchResults)
            
            // Throttle between batches (1 seconds)
            if index < chunks.count - 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        // Log Summary
        print("🔭 Scout Finished: \(candidates.count) opportunities found.")
        return candidates
    }
    
    // Returns (Symbol, Score) if passed, nil if skipped
    private func checkSymbol(_ symbol: String, quote: Quote) async -> (String, Double)? {
        // 1. Fetch Candles (Daily) via Heimdall
        guard let candles = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1day", limit: 200, context: .background) else {
            print("🔭 Scout: \(symbol) - Candle verisi yok, atlandı")
            return nil // Skipped (No Data)
        }
        
        // 2. Data Health Gatekeeper - RELAXED for Scout (only needs candles)
        // Scout is for discovery, not trading - so we only need technical data
        let health = evaluateLocalHealth(symbol: symbol, quote: quote, candles: candles)
        
        // For Scout: Only check if technical data is available (not full health score)
        if !health.technical.available {
            print("🔭 Scout: \(symbol) - Teknik veri yok, atlandı")
            return nil // Skipped (No Technical Data)
        }
        
        // 3. Detect "Interest" (for candidate selection)
        let isInteresting = detectInterest(quote: quote, candles: candles)
        
        // 4. ALWAYS DO FULL ANALYSIS (for story creation)
        var atlasScore = FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore
        
        // PATCH: Scout Blind Spot Fix
        if atlasScore == nil {
            do {
                let financials = try await HeimdallOrchestrator.shared.requestFundamentals(symbol: symbol)
                // Calculate and Save
                if let score = FundamentalScoreEngine.shared.calculate(data: financials) {
                    FundamentalScoreStore.shared.saveScore(score)
                    atlasScore = score.totalScore
                     print("🔭 Scout: Calculated fresh Atlas score for \(symbol): \(Int(score.totalScore))")
                }
            } catch {
                // Still nil, proceed with technicals only
                // print("🔭 Scout: Atlas failed for \(symbol): \(error)")
            }
        }
        
        let aether = MacroRegimeService.shared.getCachedRating()?.numericScore
        
        // Calculate Orion Score
        let orionResult = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles)
        let orion = orionResult?.score
        
        // ADD STORY CAUTIOUSLY
        // Only add story if Score is decent (>45) OR it is technically interesting (Breakout/Support)
        // User Feedback: "Too much clutter, low confidence items."
        if let orionResult = orionResult, (orionResult.score >= 45 || isInteresting) {
            let highlights = [
                ScoutHighlight(type: .structure, value: orionResult.components.structureDesc ?? "Yapı", score: orionResult.components.structure),
                ScoutHighlight(type: .trend, value: orionResult.components.trendDesc ?? "Trend", score: orionResult.components.trend),
                ScoutHighlight(type: .momentum, value: orionResult.components.momentumDesc ?? "Momentum", score: orionResult.components.momentum),
                ScoutHighlight(type: .pattern, value: orionResult.components.patternDesc ?? "Pattern", score: orionResult.components.pattern)
            ]
            
            let story = ScoutStory(
                id: UUID(),
                symbol: symbol,
                price: quote.c,
                changePercent: quote.dp ?? 0,
                orionScore: orionResult.score,
                signal: ScoutSignal.from(score: orionResult.score),
                highlights: highlights,
                scannedAt: Date(),
                isViewed: false
            )
            
            await MainActor.run {
                ScoutStoryStore.shared.addStory(story)
            }
            print("📱 Story oluşturuldu: \(symbol) (Orion: \(Int(orionResult.score)))")
        } else {
             // print("🔭 Scout: Skipped story for \(symbol) (Score: \(Int(orionResult?.score ?? 0)), Interesting: \(isInteresting))")
        }
        
        // 5. Only return candidate if "interesting" (high conviction)
        guard isInteresting else {
            return nil // Story created but not a trade candidate
        }
        
        let decision = ArgusDecisionEngine.shared.makeDecision(
            symbol: symbol,
            assetType: .stock,
            atlas: atlasScore,
            orion: orion,
            orionDetails: orionResult,
            aether: aether,
            hermes: nil,
            athena: nil,
            phoenixAdvice: nil,
            demeterScore: nil,
            marketData: nil,
            traceContext: (price: quote.currentPrice, freshness: 100, source: "Heimdall/Scout")
        ).1
        
        let coreScore = decision.finalScoreCore
        let pulseScore = decision.finalScorePulse
        
        // Check for Opportunity (Core OR Pulse) - for notifications only
        if coreScore >= 70 || pulseScore >= 70 {
            let bestScore = max(coreScore, pulseScore)
            let type = coreScore > pulseScore ? "CORSE" : "PULSE"
            
            print("🚨 SCOUT FOUND OPPORTUNITY (\(type)): \(symbol) (Core: \(Int(coreScore)), Pulse: \(Int(pulseScore)))")
            
            await MainActor.run {
                NotificationManager.shared.sendNotification(
                    title: "Argus Avcısı: \(symbol) (\(type))",
                    body: "Fırsat Tespit Edildi. Puan: \(Int(bestScore)). Otomatik inceleme başlatıldı."
                )
            }
            return (symbol, bestScore)
        }
        
        return nil
    }
    
    private func detectInterest(quote: Quote, candles: [Candle]) -> Bool {
        guard candles.count > 50 else { return false }
        let closes = candles.map { $0.close }
        let lastClose = quote.currentPrice
        
        // SMA 50
        let sma50 = closes.suffix(50).reduce(0, +) / 50.0
        let dist50 = abs(lastClose - sma50) / sma50
        
        // Breakout Logic: Near 20-day High
        let high20 = candles.suffix(20).map { $0.high }.max() ?? lastClose
        let distHigh = abs(high20 - lastClose) / lastClose
        
        // Trigger if close to SMA50 (support/resistance) or Breakout point
        // LOOSENED: Was 1.5%, now 5% to catch more opportunities
        if dist50 < 0.05 || distHigh < 0.05 {
            return true
        }
        
        return false
    }


    private func evaluateLocalHealth(symbol: String, quote: Quote, candles: [Candle]) -> DataHealth {
        var h = DataHealth(symbol: symbol)
        
        // 1. Technical Check
        // Require at least 50 candles for SMA50 and logic
        if candles.count >= 50 && quote.currentPrice > 0 {
             let quality = min(1.0, Double(candles.count) / 200.0)
             h.technical = .present(quality: quality)
        } else {
             h.technical = .missing
        }
        
        return h
    }
}
extension AutoPilotLogger {
    func logSystemEvent(_ message: String) {
        // Placeholder simple log
        print("[SYSTEM] \(message)")
    }
}
