import Foundation
import SwiftUI
import Combine

// MARK: - Argus Integration (The Brain)
extension TradingViewModel {
    
    // Argus ETF State (Moved usage from main file if needed, properties stay in main for Storage)
    
    // Loading Argus Data
    // MARK: - Scout Logic
    func startScoutLoop() {
        // Delegated to AutoPilotStore
    }
    
    func stopScoutLoop() {
        // No-op
    }
    
    func runScout() async {
        // print("🔭 Scout: runScout() ÇAĞRILDI")
        
        // 1. Refresh Discovery Lists (Yahoo Gainers/Losers)
        await refreshMarketPulse()
        
        // 2. Combine Watchlist + Discovery + ScoutUniverse
        let discoverySymbols = (topGainers + topLosers + mostActive).compactMap { $0.symbol }
        
        // ADD SCOUT UNIVERSE (Top 50 US Stocks)
        let universeSymbols = ScoutUniverse.dailyRotation(count: 20) // 20 random from top 50
        
        let allSymbolsToScout = Array(Set(watchlist + discoverySymbols + universeSymbols))
        
        // 3. Debug log
        // print("🔭 Scout: Watchlist=\(watchlist.count), Discovery=\(discoverySymbols.count), Universe=\(universeSymbols.count)")
        // print("🔭 Scout: Toplam \(allSymbolsToScout.count) sembol taranacak: \(allSymbolsToScout.prefix(5).joined(separator: ", "))...")
        
        if allSymbolsToScout.isEmpty {
            // print("⚠️ Scout: Taranacak sembol YOK! Lütfen watchlist'e hisse ekleyin.")
            return
        }
        
        let candidates = await ArgusScoutService.shared.scoutOpportunities(watchlist: allSymbolsToScout, currentQuotes: quotes)
        
        // print("🔭 Scout: Tarama tamamlandı. \(candidates.count) aday bulundu.")
        
        // HANDOVER TO CORSE (AutoPilot)
        if !candidates.isEmpty {
            // print("🔭 Scout Handover: \(candidates.count) candidates passed to Corse Engine.")
            for (symbol, score) in candidates {
                await self.processHighConvictionCandidate(symbol: symbol, score: score)
            }
        }
    }

    // MARK: - Argus Core Data Loading
    
    @MainActor
    func loadArgusData(for symbol: String) async {
        self.isLoadingArgus = true
        
        // 0. Detect Asset Type FIRST (Optimization: Don't fetch Fundamentals for Crypto/FX)
        var detectedSafeType = await detectAssetType(for: symbol)
        
        // Convert to Heimdall Type
        let assetType: AssetType
        switch detectedSafeType {
        case .stock: assetType = .stock
        case .etf: assetType = .etf
        case .crypto: assetType = .crypto
        case .commodity: assetType = .unknown // Commodities via Futures don't have Fundamentals
        case .index: assetType = .index
        case .forex: assetType = .forex
        case .gold: assetType = .unknown
        case .bond, .cashLike, .hedge: assetType = .unknown
        }
        
        // Check dependencies on Main Actor before entering TaskGroup
        let needsCandles = self.candles[symbol]?.isEmpty ?? true
        let hasOrion = self.orionScores[symbol] != nil
        
        // Parallel Data Loading Pattern
        await withTaskGroup(of: Void.self) { group in
            
            // Task 1: Fetch Candles (Critical for Chart & Orion)
            group.addTask {
                if needsCandles {
                    // Force PRIORITY load for Detail View
                    let result = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1G")

                    // Sync to ViewModel with BOTH key formats for UI compatibility
                    if let candleData = result.value {
                        await MainActor.run {
                            self.candles[symbol] = candleData // UI uses this key
                            self.objectWillChange.send()
                        }
                    }
                }
            }
            
            // Task 2: Fetch Fundamentals (Orion/Atlas)
            group.addTask {
                 // Ensure Orion Score (Needs Candles, but can start check/fetch dependencies)
                 if !hasOrion {
                     // Pass assetType to optimize fetch
                     await self.loadOrionScore(for: symbol, assetType: assetType)
                 }
            }
            
            // Task 3: Checks Atlas (Fundamentals) - NOW VIA SNAPSHOT SERVICE
            group.addTask {
                // Check if we need to calc Atlas - verify cache has VALID data
                let existingAtlas = await MainActor.run { self.fundamentalScoreStore.getScore(for: symbol) }
                let hasValidCache = existingAtlas != nil && existingAtlas!.totalScore > 0
                let shouldCalcAtlas = !hasValidCache && (assetType == .stock || assetType == .etf)
                
                // Fetch Data First (Efficient Pipeline)
                if shouldCalcAtlas || assetType == .stock { // Always fetch for snapshot if stock
                    if let (fin, _, snap) = try? await FinancialSnapshotService.shared.fetchComprehensiveData(symbol: symbol) {
                         // Store Snapshot
                         await MainActor.run {
                             self.analysis.snapshots[symbol] = snap
                             self.objectWillChange.send()
                         }
                         
                         // Calculate Score if needed
                         if shouldCalcAtlas {
                             await self.calculateFundamentalScore(for: symbol, assetType: assetType, preloadedData: fin)
                         }
                    }
                }
            }
            
            // Task 4: Experimental Lab check
            group.addTask {
                await self.loadSarTsiLab(symbol: symbol)
            }
            
            // Task 5: KAP Disclosures (BIST Only)
            group.addTask {
                if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                    let disclosures = await KAPDataService.shared.getDisclosures(for: symbol)
                    await MainActor.run {
                        self.kapDisclosures[symbol] = disclosures
                    }
                }
            }

            
            // Task 6: Ensure Macro Data (Moved from loadOrionScore)
            group.addTask {
                if self.macroRating == nil {
                    let rating = await MacroRegimeService.shared.computeMacroEnvironment()
                    await MainActor.run { self.macroRating = rating }
                }
            }
        }
        
        // 2. Gather Inputs (Now that data is likely fetched)
        
        var aetherScore: Double? = MacroRegimeService.shared.getCachedRating()?.numericScore
        let orionScore: Double? = orionScores[symbol]?.score
        
        // CORRECTION: Check if Score Store knows it's an ETF (e.g. from FMP)
        if detectedSafeType == .stock,
           let storedScore = fundamentalScoreStore.getScore(for: symbol),
           storedScore.isETF {
            detectedSafeType = .etf
        }
        
        // Experimental Lab (Async) - Does not block Argus
        Task { await loadSarTsiLab(symbol: symbol) }
        
        // 3. Hermes Score Logic (News)
        var hermesScore: Double? = nil
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        if isBist {
            let events = self.kulisEventsBySymbol[symbol] ?? HermesLLMService.shared.getCachedEvents(for: symbol)
            hermesScore = events.sorted { $0.finalScore > $1.finalScore }.first?.finalScore
            
            // B. Prometheus (Forecast) Boost for Orion (Technical)
            if let candles = self.candles[symbol], candles.count >= 30, let orion = orionScore {
                let forecast = await PrometheusEngine.shared.forecast(symbol: symbol, historicalPrices: candles.map { $0.close })
                if forecast.isValid {
                    // Forecast Trend'ine göre Orion skorunu modifiye et
                    var forecastBoost = 0.0
                    switch forecast.trend {
                    case .strongBullish: forecastBoost = 5.0
                    case .bullish: forecastBoost = 2.5
                    case .neutral: forecastBoost = 0.0
                    case .bearish: forecastBoost = -2.5
                    case .strongBearish: forecastBoost = -5.0
                    }
                    // print("🔮 Prometheus Forecast: \(symbol) -> \(forecast.trend) (Boost: \(forecastBoost))")
                    // Orion skorunu geçici olarak artırıp decision engine'e öyle verelim
                    // Not: self.orionScores[symbol] kalıcı storage olduğu için sadece local 'orionScore' değişkenini etkilemek daha güvenli
                    // Ancak burada orionScore 'let' olduğu için aşağıda decision tuple oluşturulurken müdahale edeceğiz.
                    // (Implementation detail: argusDecision çağrılırken bu boost'u ekleyeceğiz)
                }
            }
            
        } else {
            let events = self.hermesEventsBySymbol[symbol] ?? HermesLLMService.shared.getCachedEvents(for: symbol)
            hermesScore = events.sorted { $0.finalScore > $1.finalScore }.first?.finalScore
        }
        
        // CORRECTION: Populate ViewModel with insights for UI
        await MainActor.run {
            let summaries = HermesCacheStore.shared.getSummaries(for: symbol)
            self.newsInsightsBySymbol[symbol] = summaries.map { summary in
                NewsInsight(
                    symbol: symbol,
                    articleId: summary.id,
                    headline: summary.summaryTR,
                    summaryTRLong: summary.impactCommentTR,
                    impactSentenceTR: summary.impactCommentTR,
                    sentiment: summary.impactScore > 60 ? .strongPositive : (summary.impactScore < 40 ? .weakNegative : .neutral),
                    confidence: Double(summary.impactScore) / 100.0,
                    impactScore: Double(summary.impactScore),
                    createdAt: summary.createdAt
                )
            }
        }
        
        // 3a. Prepare Hermes News Snapshot for Council
        var hermesSnapshot: HermesNewsSnapshot? = nil
        let currentInsights = self.newsInsightsBySymbol[symbol] ?? []
        if !currentInsights.isEmpty {
             hermesSnapshot = HermesNewsSnapshot(
                 symbol: symbol,
                 timestamp: Date(),
                 insights: currentInsights,
                 articles: [] // Raw articles not strictly needed for voting main sentiment
             )
        }
        
        // 4. Atlas Score (Fundamentals) Logic
        var atlasScore: Double? = nil
        
        switch detectedSafeType {
        case .etf:
            let currentPrice = quotes[symbol]?.currentPrice ?? 0.0
            
            // Pass Cached Scores for Holdings
            let provider: (String) -> (Double?, Double?) = { [weak self] hSymbol in
                let atlas = self?.fundamentalScoreStore.getScore(for: hSymbol)?.totalScore
                
                var hHermes: Double? = nil
                if let summaries = self?.hermesSummaries[hSymbol], !summaries.isEmpty {
                    let total = summaries.map { Double($0.impactScore) }.reduce(0.0, +)
                    hHermes = total / Double(summaries.count)
                }
                return (atlas, hHermes)
            }
            
            let etfSummary = await ArgusEtfEngine.shared.analyzeETF(
                symbol: symbol,
                currentPrice: currentPrice,
                orionScore: orionScore,
                hermesScore: hermesScore,
                holdingScoreProvider: provider
            )
            atlasScore = etfSummary.weightedAtlasScore 
            
            // Store Summary
            self.etfSummaries[symbol] = etfSummary
            
        case .stock:
            if let score = fundamentalScoreStore.getScore(for: symbol)?.totalScore {
                atlasScore = score
            }
            
        default:
            atlasScore = nil
        }
        
        
        
        // 5. Cronos Score (Time) - REMOVED (Migrated to Walk-Forward Engine)
        // let cronosScore: Double = CronosTimeEngine.shared.calculateTimingScore(candles: symbolCandles)
        // self.cronosScores[symbol] = cronosScore
        
        let symbolCandles = self.candles[symbol] ?? []
        
        // 6. Poseidon (Big Fish)
        let whaleScore = await PoseidonService.shared.analyzeSmartMoney(symbol: symbol, candles: symbolCandles)
        self.poseidonWhaleScores[symbol] = whaleScore
        
        // 7. Overreaction Hunter (Lab)
        self.analyzeOverreaction(symbol: symbol, candles: symbolCandles, atlas: atlasScore, aether: aetherScore)
        
        // 6. Athena Score (Smart Beta)
        // A. Fetch Financials (Try Cache first)
        let financials = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol).flatMap { try? JSONDecoder().decode(FinancialsData.self, from: $0.data) }
        
        // B. Get Atlas Result
        let fullAtlas = self.fundamentalScoreStore.getScore(for: symbol)
        
        // C. Calculate
        let athenaResult = AthenaFactorService.shared.calculateFactors(
            symbol: symbol,
            financials: financials,
            atlasResult: fullAtlas,
            candles: symbolCandles
        )
        SignalStateViewModel.shared.athenaResults[symbol] = athenaResult
        
        let athenaScore = athenaResult.factorScore
        
        // 7. PHOENIX SCENARIO ENGINE (Level/Scenario)
        // Resolve Timeframe
        let ptfRaw = UserDefaults.standard.string(forKey: "phoenixTimeframe") ?? "Otomatik"
        var ptf = PhoenixTimeframe(rawValue: ptfRaw) ?? .auto
        
        if ptf == .auto {
            // Auto Logic: Default to 1H (Safe Balance)
            ptf = .h1
        }
        
        let phoenixAdvice = await PhoenixScenarioEngine.shared.analyze(symbol: symbol, timeframe: ptf)
        
        // 🆕 SIRKIYE ENTEGRASYONU (Makro Rüzgar)
        // 🆕 SIRKIYE ENTEGRASYONU (Makro Rüzgar)
        if isBist {
            // print("🇹🇷 BIST Integrasyonu: Sirkiye Aether Makro Analizi...")
            
            // 1. Sirkiye Aether Analizini Çalıştır (Yeni Motor)
            let macroAnalysis = await SirkiyeAetherEngine.shared.analyze()
            let turkeyMacroScore = macroAnalysis.overallScore
            
            // 2. Argus Decision için 'aetherScore'u güncelle
            // Sirkiye skoru, BIST sembolleri için Aether (Global Makro) skorunun yerini tamamen alır.
            // BIST yerel makro dinamiklerden daha fazla etkilendiği için Global Aether'i eziyoruz.
            aetherScore = turkeyMacroScore
            
            // print("🇹🇷 Sirkiye Aether Skoru: \(Int(turkeyMacroScore)) (\(macroAnalysis.investmentRisk.rawValue))")
            
            // Not: ForeignInvestorFlowService verisi şimdilik Aether skoruna dahil edilmiyor.
            // İleride 'Poseidon' veya 'Orion' içine eklenebilir.
        }

        // 8. DECISION ENGINE (The Brain)
        // ------------------------------
        
        // A. Prepare Portfolio Context (Churn Guard)
        // Find existing open trade
        let existingTrade = portfolio.first(where: { $0.symbol == symbol && $0.isOpen })
        
        // Find Last Manual Action (For 24h Override)
        // Filter history for this symbol, manual source, sorted descending
        let manualTx = transactionHistory
            .filter { $0.symbol == symbol && $0.source == TradeSource.user.rawValue }
            .sorted { $0.date > $1.date }
            .first
        
        let lastManualAction: SignalAction?
        if let type = manualTx?.type {
            lastManualAction = (type == .buy) ? .buy : .sell
        } else {
            lastManualAction = nil
        }
        
        // B. Call Engine
        // Enum Conversion Helper
        let safeAssetType: SafeAssetType
        switch assetType {
        case .stock: safeAssetType = .stock
        case .etf: safeAssetType = .etf
        case .crypto: safeAssetType = .crypto
        case .index: safeAssetType = .index
        case .forex: safeAssetType = .forex
        default: safeAssetType = .stock // Fallback
        }
        
        // C. Determine Source (Traceability)
        let uniReason = UniverseEngine.shared.getReason(for: symbol)
        let candidateSource: CandidateSource
        if uniReason.contains("Scout") { candidateSource = .scout }
        else if uniReason.contains("Manual") { candidateSource = .manual }
        else if uniReason.contains("Hermes") { candidateSource = .hermes }
        else { candidateSource = .watchlist } // Default
        
        let decisionTuple = ArgusDecisionEngine.shared.makeDecision(
            symbol: symbol,
            assetType: safeAssetType,
            atlas: atlasScore,
            orion: orionScore,
            orionDetails: self.orionScores[symbol],
            aether: aetherScore,
            hermes: hermesScore,
            athena: athenaScore,
            phoenixAdvice: phoenixAdvice,
            demeterScore: self.getDemeterScore(for: symbol)?.totalScore, // Demeter Integration
            marketData: (
                price: quotes[symbol]?.currentPrice ?? 0,
                equity: self.getEquity(), // Using helper
                currentRiskR: 0.0 // Placeholder: In real app, sum existing positions' R risk.
            ),
            traceContext: (
                price: quotes[symbol]?.currentPrice ?? 0,
                freshness: Date().timeIntervalSince(quotes[symbol]?.timestamp ?? Date()),
                source: MarketDataStore.shared.getQuoteProvenance(for: symbol)?.source ?? "Heimdall/Unknown"
            ),
            portfolioContext: (
                isInPosition: existingTrade != nil,
                lastTradeTime: existingTrade?.entryDate ?? manualTx?.date,
                lastAction: existingTrade != nil ? .buy : (manualTx?.type == .sell ? .sell : .hold),
                lastManualActionTime: manualTx?.date,
                lastManualActionType: lastManualAction
            ),
            config: .defaults,
            candidateSource: candidateSource
        )
        
        let decision = decisionTuple.1
        let trace = decisionTuple.0
        
        self.argusDecisions[symbol] = decision
        self.agoraTraces[symbol] = trace
        

        
        // AGORA AUDIT (Decision V2)
        let snapshot = AgoraExecutionGovernor.shared.audit(
            decision: decision,
            currentPrice: quotes[symbol]?.currentPrice ?? 0.0,
            portfolio: portfolio,
            lastTradeTime: lastTradeTimes[symbol],
            lastActionPrice: nil 
        )
        ExecutionStateViewModel.shared.addAgoraSnapshot(snapshot)
        
        // Log to Argus Lab for Performance Tracking
        if let quote = quotes[symbol] {
            ArgusLabEngine.shared.logDecision(symbol: symbol, decision: decision, currentPrice: quote.currentPrice)
            
            // Sync with Widget
            persistToWidget(symbol: symbol, quote: quote, decision: decision)
            
            // Forward Testing (Oto Takip - High Conviction)
            let isStrongBuy = decision.finalScoreCore >= 75 && decision.finalActionCore == SignalAction.buy
            let isStrongSell = decision.finalScoreCore <= 35 && decision.finalActionCore == SignalAction.sell
            
            if isStrongBuy || isStrongSell {
                // SignalTrackerService removed (ArgusLedger auto-logs via Council)
                // print("📝 Auto-Tracked Context: \(symbol) Score: \(Int(decision.finalScoreCore)) Action: \(decision.finalActionCore.rawValue)")
            }
        }
        
        // 7. EXPLANATION SERVICE (DISABLED TO SAVE LLM QUOTA)
        // LLM explanation is now generated ON-DEMAND only when user opens detail view and taps "Explain"
        // This saves approximately 500-1000 tokens per symbol scan.
        // To re-enable: Uncomment the Task block below.
        /*
        Task {
            if self.argusExplanations[symbol] == nil || (self.argusExplanations[symbol]?.isOffline ?? false) {
                do {
                    let explanation = try await ArgusExplanationService.shared.generateExplanation(for: decision)
                    await MainActor.run {
                        self.argusExplanations[symbol] = explanation
                    }
                } catch {
                    print("⚠️ Argus Explanation Failed: \(error)")
                    let fallback = ArgusExplanationService.shared.generateOfflineExplanation(
                        for: decision,
                        reason: error.localizedDescription
                    )
                     await MainActor.run {
                        self.argusExplanations[symbol] = fallback
                    }
                }
            }
        }
        */
        // ALTERNATIVE: Use offline fallback always during Scout
        if self.argusExplanations[symbol] == nil {
            let offline = ArgusExplanationService.shared.generateOfflineExplanation(for: decision, reason: nil)
            self.argusExplanations[symbol] = offline
        }
        
        self.isLoadingArgus = false
        
        // 9. GRAND COUNCIL CONVENE (The V3 Brain) -- NEW SYNC POINT
        if let dailyCandles = self.candles[symbol], !dailyCandles.isEmpty {
             let existingScore = await MainActor.run { self.fundamentalScoreStore.getScore(for: symbol) }
             // let finData = existingScore?.financials ?? FundamentalsCache.shared.get(symbol: symbol) NO LONGER NEEDED DIRECTLY
             let snapshot = await MainActor.run { self.analysis.snapshots[symbol] }
             
             // Advisors
             let athenaScore = self.athenaResults[symbol]
             let demeterScore = self.getDemeterScore(for: symbol)
             // let chronos = ChronosService.shared.analyzeTime(symbol: symbol, candles: dailyCandles)
             // await MainActor.run { self.chronosDetails[symbol] = chronos }

             // Prepare BIST Input (Turquoise - Sirkiye (Politik Korteks))
             var sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil
             if symbol.uppercased().hasSuffix(".IS") {
                 let usdQuote = await MainActor.run { self.quotes["USD/TRY"] }
                 if let q = usdQuote {
                     sirkiyeInput = SirkiyeEngine.SirkiyeInput(
                         usdTry: q.currentPrice,
                         usdTryPrevious: q.previousClose ?? q.currentPrice,
                         dxy: 104.0,
                         brentOil: 80.0,
                         globalVix: 20.0,
                         newsSnapshot: hermesSnapshot,
                         currentInflation: 45.0,
                         policyRate: 50.0,
                         xu100Change: nil,
                         xu100Value: nil,
                         goldPrice: nil
                     )
                 }
             }

             let grandDecision = await ArgusGrandCouncil.shared.convene(
                 symbol: symbol,
                 candles: dailyCandles,
                 snapshot: snapshot, // NEW SNAPSHOT FLOW
                 macro: await MacroSnapshotService.shared.getSnapshot(),
                 news: hermesSnapshot, // Pass the correctly constructed snapshot!
                 engine: .pulse, // Defaulting to pulse/standard for now
                 athena: athenaScore,
                 demeter: demeterScore,
                 sirkiyeInput: sirkiyeInput,
                 origin: "UI_SCAN"
             )
             
             await MainActor.run {
                 SignalStateViewModel.shared.grandDecisions[symbol] = grandDecision
             }
        }
    }

    func calculateFundamentalScore(for symbol: String, assetType: AssetType = .stock, preloadedData: FinancialsData? = nil) async {
        // print("⚡️ CORE DEBUG: calculateFundamentalScore START for \(symbol)")
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // BIST Check - BIST için BISTBilancoEngine kullan
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        if isBist {
            // BIST YOLU: BorsaPy + BISTBilancoEngine
            await calculateBistFundamentalScore(for: symbol)
            return
        }
        
        // GLOBAL YOLU: Yahoo Finance + FundamentalScoreEngine
        do {
            // 1. API'den Veri Çek - Yahoo Finance (TwelveData Pro plan gerekli)
            // print("⚡️ ATLAS: Fetching Fundamentals from Yahoo for \(symbol)...")
            
            // Rate Limit Guard
            if preloadedData == nil {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // Use Preloaded OR Fetch
            let financials: FinancialsData
            if let pre = preloadedData {
                financials = pre
            } else {
                financials = try await YahooFinanceProvider.shared.fetchFundamentals(symbol: symbol)
            }
            
            // Explicit Cache
            FundamentalsCache.shared.set(symbol: symbol, data: financials)

            // print("⚡️ ATLAS: Yahoo returned: Rev=\(financials.totalRevenue ?? -1), PE=\(financials.peRatio ?? -1), MC=\(financials.marketCap ?? -1)")
            
            // 2. Risk Skoru için Candle Verisi
            var symbolCandles = candles[symbol]
            if symbolCandles == nil || symbolCandles!.isEmpty {
                if let fetched = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 365) {
                     await MainActor.run {
                        self.candles[symbol] = fetched
                    }
                    symbolCandles = fetched
                }
            }
            
            // 3. Risk Skoru Hesapla
            var riskScore: Double? = nil
            if let c = symbolCandles {
                riskScore = RiskMetricService.shared.calculateVolatilityScore(candles: c)
            }
            
            // 4. Skor Hesapla
            if let result = FundamentalScoreEngine.shared.calculate(data: financials, riskScore: riskScore) {
                await MainActor.run {
                    self.fundamentalScoreStore.saveScore(result)
                    
                    // --- ATLAS LOGGING ---
                    let currentPrice = self.quotes[symbol]?.currentPrice ?? symbolCandles?.last?.close ?? 0.0
                    if currentPrice > 0 {
                        let fundCoverage = CoverageComponent(available: true, quality: result.dataCoverage / 100.0)
                        
                        // Technical: If we have candles, data is good (0.8 or higher based on count)
                        let candleCount = symbolCandles?.count ?? 0
                        let techQuality = candleCount >= 100 ? 1.0 : (candleCount >= 50 ? 0.8 : (candleCount > 0 ? 0.6 : 0.0))
                        let techCoverage = CoverageComponent(available: candleCount > 0, quality: techQuality)
                        
                        // Macro: We always have some macro context from Aether, mark as present
                        let macroCoverage = CoverageComponent.present(quality: 0.7)
                        
                        // News: If no explicit news service, still count as partially covered
                        let newsCoverage = CoverageComponent.present(quality: 0.5)
                        
                        let health = DataHealth(
                             symbol: symbol,
                             lastUpdated: Date(),
                             fundamental: fundCoverage,
                             technical: techCoverage,
                             macro: macroCoverage,
                             news: newsCoverage
                        )
                        self.dataHealthBySymbol[symbol] = health
                    }
                    // ---------------------
                    
                    self.objectWillChange.send() // UI Update
                    self.isLoading = false
                }
            } else {
                 // print("⚠️ Atlas Engine returned NIL for \(symbol) (Insufficient Data)")
                 await MainActor.run {
                     self.failedFundamentals.insert(symbol)
                     self.isLoading = false
                 }
            }
        } catch {
            // print("❌ Fundamental Data Fetch Failed: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.failedFundamentals.insert(symbol)
            }
        }
    }
    
    // MARK: - BIST Fundamental Score (BorsaPy + BISTBilancoEngine)
    
    private func calculateBistFundamentalScore(for symbol: String) async {
        // print("🏛️ BIST ATLAS: Calculating fundamental score for \(symbol) via BorsaPy...")
        
        do {
            // 1. BISTBilancoEngine'den analiz çek
            let bistSonuc = try await BISTBilancoEngine.shared.analiz(sembol: symbol)
            
            // print("✅ BIST ATLAS: \(symbol) - Toplam Skor: \(bistSonuc.toplamSkor), F/K: \(bistSonuc.degerlemeVerisi.fk.deger ?? -1)")
            
            // 2. BISTBilancoSonuc'u FundamentalScoreResult'a dönüştür
            // Böylece mevcut Argus altyapısıyla uyumlu olur
            let result = convertBistToFundamentalResult(bistSonuc: bistSonuc, symbol: symbol)
            
            await MainActor.run {
                // 3. Store'a kaydet
                self.fundamentalScoreStore.saveScore(result)
                
                // 4. DataHealth güncelle
                let health = DataHealth(
                    symbol: symbol,
                    lastUpdated: Date(),
                    fundamental: CoverageComponent(available: true, quality: 0.6), // BorsaPy sınırlı veri
                    technical: CoverageComponent(available: true, quality: 0.8),
                    macro: CoverageComponent.present(quality: 0.7),
                    news: CoverageComponent.present(quality: 0.5)
                )
                self.dataHealthBySymbol[symbol] = health
                
                self.objectWillChange.send()
                self.isLoading = false
            }
        } catch {
            // print("❌ BIST ATLAS Failed: \(error)")
            await MainActor.run {
                self.failedFundamentals.insert(symbol)
                self.isLoading = false
            }
        }
    }
    
    /// BISTBilancoSonuc -> FundamentalScoreResult dönüşümü
    private func convertBistToFundamentalResult(bistSonuc: BISTBilancoSonuc, symbol: String) -> FundamentalScoreResult {
        // Değerleme verilerini FinancialsData'ya çevir
        let financials = FinancialsData(
            symbol: symbol,
            currency: "TRY",
            lastUpdated: Date(),
            totalRevenue: nil,
            netIncome: nil,
            totalShareholderEquity: nil,
            marketCap: bistSonuc.profil.piyasaDegeri,
            revenueHistory: [],
            netIncomeHistory: [],
            ebitda: nil,
            shortTermDebt: nil,
            longTermDebt: nil,
            operatingCashflow: nil,
            capitalExpenditures: nil,
            cashAndCashEquivalents: nil,
            peRatio: bistSonuc.degerlemeVerisi.fk.deger,
            forwardPERatio: nil,
            priceToBook: bistSonuc.degerlemeVerisi.pddd.deger,
            evToEbitda: bistSonuc.degerlemeVerisi.fdFavok.deger,
            dividendYield: nil,
            forwardGrowthEstimate: nil,
            isETF: false,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
        
        // Değerleme grade'i belirle
        let valuationGrade: String
        let degerleme = bistSonuc.degerleme
        if degerleme >= 75 { valuationGrade = "Ucuz" }
        else if degerleme >= 50 { valuationGrade = "Makul" }
        else { valuationGrade = "Pahalı" }
        
        // Özet ve highlights oluştur
        let summary = bistSonuc.ozet
        var highlights: [String] = []
        if let fk = bistSonuc.degerlemeVerisi.fk.deger {
            highlights.append("F/K: \(String(format: "%.1f", fk))x")
        }
        if let pddd = bistSonuc.degerlemeVerisi.pddd.deger {
            highlights.append("PD/DD: \(String(format: "%.2f", pddd))x")
        }
        highlights.append(contentsOf: bistSonuc.oneCikanlar)
        
        // FundamentalScoreResult oluştur (doğru init parametreleri)
        return FundamentalScoreResult(
            symbol: symbol,
            date: Date(),
            totalScore: bistSonuc.toplamSkor,
            realizedScore: bistSonuc.degerleme, // Kullanılabilir tek veri: değerleme
            forwardScore: nil,
            profitabilityScore: nil, // Veri yok
            growthScore: nil,        // Veri yok
            leverageScore: nil,      // Veri yok
            cashQualityScore: nil,   // Veri yok
            dataCoverage: 40,        // BorsaPy sınırlı veri sağlıyor
            summary: summary,
            highlights: highlights,
            proInsights: bistSonuc.uyarilar,
            calculationDetails: "BIST verileri İş Yatırım HTML scraping ile alınmaktadır. Sadece F/K ve PD/DD metrikleri mevcut.",
            valuationGrade: valuationGrade,
            riskScore: nil,
            isETF: false,
            financials: financials
        )
    }
    
    // MARK: - Voice & Explanations (Gemini)

    @MainActor
    func generateVoiceReport(for symbol: String, tradeId: UUID? = nil, existingTrace: ArgusVoiceTrace? = nil, depth: Int = 1) async {
        isGeneratingVoiceReport = true
        defer { isGeneratingVoiceReport = false }
        
        // V3 REFORM: Use ArgusGrandDecision as the Single Source of Truth
        // We prioritizing the latest Council Decision over legacy traces for now to ensure quality.
        // If we are viewing a historical trade, we might need to map it later, but for now assuming live view.
        
        var decision = grandDecisions[symbol]
        
        // If no decision exists (e.g. fresh launch), try to load it first
        if decision == nil {
            // print("🎙️ Argus Voice: No decision found for \(symbol), triggering load...")
            await loadArgusData(for: symbol) // This will populate argusDecisions
            decision = grandDecisions[symbol]
        }
        
        guard let grandDecision = decision else {
            // print("⚠️ Argus Voice: Could not obtain Grand Decision for \(symbol). Aborting report.")
            voiceReports[symbol] = "⚠️ Rapor oluşturulamadı: Konsey kararı bulunamadı."
            return
        }
        
        // Generate via Gemini (Omniscient) - V3
        let report = await ArgusVoiceService.shared.generateReport(decision: grandDecision)
        
        // Update Local State for UI
        voiceReports[symbol] = report
        
        // Persist to Trade if ID provided
        if let tid = tradeId {
            attachVoiceReport(tradeId: tid, report: report)
        }
    }
    
    private func attachVoiceReport(tradeId: UUID, report: String) {
        if let index = portfolio.firstIndex(where: { $0.id == tradeId }) {
            portfolio[index].voiceReport = report
            // didSet on portfolio triggers savePortfolio()
            print("🎙️ Argus Voice: Report attached to Trade \(tradeId). Saved.")
        }
    }
    
    func retryArgusExplanation(for symbol: String) async {
        guard let decision = argusDecisions[symbol] else { return }
        
        self.isLoadingArgus = true
        // Delay slightly to allow UI to update state
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        do {
            // Force fetch
            let explanation = try await ArgusExplanationService.shared.generateExplanation(for: decision)
            self.argusExplanations[symbol] = explanation
        } catch {
             print("⚠️ Argus Retry Failed: \(error)")
             self.argusExplanations[symbol] = ArgusExplanationService.shared.generateOfflineExplanation(
                for: decision,
                reason: error.localizedDescription
            )
        }
        self.isLoadingArgus = false
    }

    // MARK: - Orion Score Integration
    
    func loadOrionScore(for symbol: String, assetType: AssetType = .stock) async {
        // Phase 4: Delegate to OrionStore (Orion 2.0 MTF)
        // Store handles Multi-Timeframe Analysis now.
        await OrionStore.shared.ensureAnalysis(for: symbol)
        
        // Sync Widget (Legacy Side Effect)
        await MainActor.run {
             self.syncWidgetData()
        }
    }
    
    // MARK: - Experimental Lab
    @MainActor
    func loadSarTsiLab(symbol: String) async {
        // Reset State
        self.isLoadingSarTsiBacktest = true
        self.sarTsiErrorMessage = nil
        self.sarTsiBacktestResult = nil
        
        do {
            // Fetch 5 Years (approx 1260 trading days)
            let limit = 1260
            let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1day", limit: limit)
            let result = try await OrionSarTsiBacktester.shared.runBacktest(symbol: symbol, candles: candles)
            self.sarTsiBacktestResult = result
        } catch {
            self.sarTsiErrorMessage = error.localizedDescription
            self.sarTsiBacktestResult = nil
        }
        
        self.isLoadingSarTsiBacktest = false
    }

    // MARK: - Overreaction Hunter
    func analyzeOverreaction(symbol: String, candles: [Candle], atlas: Double?, aether: Double?) {
        Task {
            let result = OverreactionEngine.shared.analyze(
                symbol: symbol,
                candles: candles,
                atlasScore: atlas,
                aetherScore: aether
            )
            
            await MainActor.run {
                self.overreactionResult = result
            }
        }
    }
    
    // MARK: - Safe and Smart Asset Type Detection
    
    func detectAssetType(for symbol: String) async -> SafeAssetType {
        // 0. Check User Manual Override (Highest Priority)
        if let userOverride = SafeUniverseService.shared.getUserOverride(for: symbol) {
            return userOverride
        }
        
        // 1. Check SafeUniverse Overrides (System Defaults)
        if let type = SafeUniverseService.shared.getUniverseType(for: symbol) {
            return type
        }
        
        // 2. Check Known ETFs (MarketDataProvider)
        if isETF(symbol: symbol) {
            return .etf
        }
        
        // 3. Pattern Matching
        if symbol.hasSuffix("=F") { return .commodity } // Futures (Crude, Gold, Corn)
        if symbol.hasPrefix("^") { return .index } // Indices (^GSPC, ^IXIC)
        if symbol.contains("-USD") { return .crypto } // Crypto (BTC-USD)
        
        // 4. Common Keyword Heuristics -- skipped
        
        // 5. Hardcoded Common Commodities/ETFs check
        let commodityEtfs = ["GLD", "IAU", "SLV", "USO", "UNG", "DBC", "GSG", "PALL", "PPLT"]
        if commodityEtfs.contains(symbol) { return .commodity } // Or Gold
        
        // Default to Stock if unknown
        return .stock
    }

    // Manual Override Trigger
    @MainActor
    func updateAssetType(for symbol: String, to type: SafeAssetType) async {
        // 1. Save Preference
        SafeUniverseService.shared.setUserOverride(for: symbol, type: type)
        
        // 2. Clear relevant caches to force fresh calculation
        self.argusDecisions[symbol] = nil
        self.etfSummaries[symbol] = nil
        
        // 3. Reload Data with new Context
        await loadArgusData(for: symbol)
    }
    
    func checkIsEtf(_ symbol: String) async -> Bool {
        return isETF(symbol: symbol)
    }
    
    func loadEtfData(for symbol: String) async {
        await MainActor.run { isLoadingEtf = true }
        
        let isEtf = isETF(symbol: symbol)
        guard isEtf else {
             await MainActor.run { isLoadingEtf = false }
             return 
        }
        
        // Ensure price is up to date
        if quotes[symbol] == nil {
             let val = await MarketDataStore.shared.ensureQuote(symbol: symbol)
             if let q = val.value {
                 await MainActor.run { quotes[symbol] = q }
             }
        }
        
        let currentPrice = quotes[symbol]?.currentPrice ?? 0.0
        let orionScore = orionScores[symbol]?.score // Uses existing Orion calculation if available
        
        let summary = await ArgusEtfEngine.shared.analyzeETF(
            symbol: symbol,
            currentPrice: currentPrice,
            orionScore: orionScore,
            hermesScore: nil,
            holdingScoreProvider: nil
        )
        
        await MainActor.run {
            self.etfSummaries[symbol] = summary
            self.isLoadingEtf = false
        }
    }
    
    func hydrateAtlas() async {
        ArgusLogger.phase(.atlas, "Temel Analiz: \(watchlist.count) sembol işleniyor...")
        
        let now = Date()
        var symbolsToHydrate: [String] = []
        
        // 1. Önce hangi sembollerin güncellenmesi gerektiğini belirle
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol) {
                let daysOld = Calendar.current.dateComponents([.day], from: score.date, to: now).day ?? 999
                if daysOld < 7 {
                    continue // Valid cache
                }
            }
            symbolsToHydrate.append(symbol)
        }
        
        if symbolsToHydrate.isEmpty {
            ArgusLogger.info(.atlas, "Tüm veriler güncel (önbellek valid)")
            return
        }
        
        ArgusLogger.info(.atlas, "\(symbolsToHydrate.count) sembol güncellenecek")
        
        // 2. Batch halinde işle (5'er sembol - Yahoo rate limit hassasiyeti)
        let batchSize = 5
        let batches = stride(from: 0, to: symbolsToHydrate.count, by: batchSize).map {
            Array(symbolsToHydrate[$0..<min($0 + batchSize, symbolsToHydrate.count)])
        }
        
        var hydratedCount = 0
        
        for (batchIndex, batch) in batches.enumerated() {
            // Paralel yükleme
            await withTaskGroup(of: Void.self) { group in
                for symbol in batch {
                    group.addTask { [weak self] in
                        await self?.calculateFundamentalScore(for: symbol)
                    }
                }
            }
            
            ArgusLogger.batchProgress(module: .atlas, batch: batchIndex + 1, totalBatches: batches.count, processed: hydratedCount, total: symbolsToHydrate.count)
            
            // Rate limit için kısa bekleme (Yahoo 429 önlemi)
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        ArgusLogger.complete("Atlas Temel Analiz tamamlandı (\(hydratedCount) sembol)")
    }
    
    // MARK: - Widget Integration
    
    func persistToWidget(symbol: String, quote: Quote, decision: ArgusDecisionResult) {
        var currentScores = ArgusStorage.shared.loadWidgetScores()
        
        let miniData = WidgetScoreData(
            symbol: symbol,
            price: quote.currentPrice,
            changePercent: quote.percentChange,
            signal: decision.finalActionCore,
            lastUpdated: Date()
        )
        
        currentScores[symbol] = miniData
        ArgusStorage.shared.saveWidgetScores(scores: currentScores)
    }
    
    func generateAISignals() async {
        let signals = await AISignalService.shared.generateSignals(quotes: quotes, candles: candles)
        await MainActor.run {
            self.aiSignals = signals
        }
    }
    
    func refreshArgusLabStats() {
        Task {
            // Update historical returns if needed
            await ArgusLabEngine.shared.resolveUnifiedEvents(using: MarketDataProvider.shared)
            
            // Compute fresh stats
            let stats = ArgusLabEngine.shared.getStats(for: ArgusAlgoId.argusCoreV1)
            
            await MainActor.run {
                self.argusLabStats = stats
            }
        }
    }
    
    // MARK: - Athena (Smart Money / Factor Analysis)
    
    /// Athena faktör analizini çalıştır ve sonucu kaydet
    func loadAthena(for symbol: String) async {
        guard let candles = self.candles[symbol], candles.count >= 50 else {
            ArgusLogger.warning(.argus, "Athena: Yetersiz veri - \(symbol)")
            return
        }
        
        // Get financial data from cache if available
        let financialsEntry = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol)
        let financials = financialsEntry.flatMap { try? JSONDecoder().decode(FinancialsData.self, from: $0.data) }
        
        // Get atlas result if available
        let atlasResult = self.fundamentalScoreStore.getScore(for: symbol)
        
        // Get orion score if available
        let orionScore = self.orionScores[symbol]
        
        let athenaResult = AthenaFactorService.shared.calculateFactors(
            symbol: symbol,
            financials: financials,
            atlasResult: atlasResult,
            candles: candles,
            orionScore: orionScore
        )
        
        await MainActor.run {
            SignalStateViewModel.shared.athenaResults[symbol] = athenaResult
        }
        
        ArgusLogger.success(.argus, "Athena: \(symbol) analizi tamamlandı - Skor: \(athenaResult.factorScore)")
    }
    
    // MARK: - Demeter (Sector Analysis)
    
    /// Global sektör analizini çalıştır
    func loadDemeterSectorAnalysis() async {
        ArgusLogger.phase(.argus, "Demeter: Sektör analizi başlatılıyor...")
        
        await DemeterEngine.shared.analyze()
        
        ArgusLogger.success(.argus, "Demeter: Sektör analizi tamamlandı")
    }
    
    /// Belirli bir sembol için Demeter skoru al (sektör bazlı)
    /// Not: getDemeterScore zaten başka yerde tanımlıysa bu fonksiyonu kaldırıyoruz
    // getDemeterScore fonksiyonu zaten loadArgusData içinde satır 621'de kullanılıyor
    // Bu duplicate tanımı kaldırıyoruz çünkü çakışma yarattı
}
