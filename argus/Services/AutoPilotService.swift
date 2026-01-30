import Foundation

// MARK: - Auto-Pilot Service
/// The Engine for Automated Trading (Paper Mode).
/// STRICTLY uses REAL Data. NO Simulations.
final class AutoPilotService: Sendable {
    static let shared = AutoPilotService()
    
    // State
    private let tradeHistoryKey = "Argus_PaperTrades_v1"
    private var isScanning = false
    
    // Dependencies
    private let market = MarketDataProvider.shared
    private let analysis = OrionAnalysisService.shared
    private let cache = HermesCacheStore.shared // For news context if needed later
    
    private init() {}
    
    // MARK: - Public API
    
    /// Scans the provided list of symbols for high-conviction setups.
    /// Returns a list of Signals. Execution happens in ViewModel.
    /// Scans the provided list of symbols for high-conviction setups.
    /// Returns a list of Signals. Execution happens in ViewModel.
    func scanMarket(
        symbols: [String], 
        equity: Double, 
        bistEquity: Double, // NEW: TL Equity for BIST
        buyingPower: Double, 
        bistBuyingPower: Double,
        portfolio: [String: Trade]
    ) async -> (signals: [TradeSignal], logs: [ScoutLog]) {
        guard !isScanning else { return ([], []) }
        isScanning = true
        defer { isScanning = false }
        
        var signals: [TradeSignal] = []
        var logs: [ScoutLog] = []
        
        print("🤖 AutoPilotService: Tarama başlatılıyor - \(symbols.count) sembol")
        print("💰 AutoPilotService: Global Equity: $\(equity), BIST Equity: ₺\(bistEquity)")
        print("💰 AutoPilotService: Global Balance: $\(buyingPower), BIST Balance: ₺\(bistBuyingPower)")
        
        // Ensure Aether Freshness
        var aether = MacroRegimeService.shared.getCachedRating()
        if aether == nil {
            ArgusLogger.warning(.autopilot, "Aether verisi eski. Makro ortam yenileniyor...")
            aether = await MacroRegimeService.shared.computeMacroEnvironment()
        }
        
        if await HeimdallOrchestrator.shared.checkSystemHealth() == .critical {
            ArgusLogger.error(.autopilot, "Sistem Sağlığı KRİTİK. Tarama iptal ediliyor.")
            print("🛑 AutoPilotService: Sistem sağlığı KRİTİK")
            return ([], [])
        }
        
        ArgusLogger.phase(.autopilot, "Piyasa taranıyor: \(symbols.count) sembol (Rejim: \(aether?.regime.displayName ?? "Bilinmiyor"))")
        
        // GLOBAL MARKET: Hafta sonu ve piyasa kapalıyken işlem yapma
        let canTradeGlobal = MarketStatusService.shared.canTrade()
        if !canTradeGlobal {
            let status = MarketStatusService.shared.getMarketStatus()
            let reason: String
            switch status {
            case .closed(let r): reason = r
            case .preMarket: reason = "Pre-Market"
            case .afterHours: reason = "After-Hours"
            default: reason = "Piyasa Kapalı"
            }
            print("STOP Auto-Pilot: Global piyasa kapalı (\(reason)). Sadece BIST taraması yapılacak.")
            ArgusLogger.warning(.autopilot, "Global piyasa kapalı (\(reason)). Sadece BIST taranacak.")
        }
        
        // Batch Processing (Rate Limit Protection)
        let batchSize = 10
        let chunks = stride(from: 0, to: symbols.count, by: batchSize).map {
            Array(symbols[$0..<min($0 + batchSize, symbols.count)])
        }
        
        for (index, batch) in chunks.enumerated() {
            // ArgusLogger.verbose(.autopilot, "Paket işleniyor: \(index + 1)/\(chunks.count) (\(batch.count) sembol)")
            
            // Wait between batches (500ms)
            if index > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // Process Batch concurrently for speed
             await withTaskGroup(of: (TradeSignal?, ScoutLog?).self) { group in
                for symbol in batch {
                    group.addTask {
                        // 1. Determine Correct Context
                        let isBist = symbol.uppercased().hasSuffix(".IS")
                        let effectiveBuyingPower = isBist ? bistBuyingPower : buyingPower
                        let effectiveEquity = isBist ? bistEquity : equity
                        
                        // GLOBAL MARKET CLOSED CHECK
                        if !isBist && !canTradeGlobal {
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "Global piyasa kapalı", score: 0))
                        }
                        
                        // BIST MARKET CLOSED CHECK
                        if isBist && !MarketStatusService.shared.isBistOpen() {
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "BIST piyasası kapalı", score: 0))
                        }
                        
                        // 1. Fetch Data (Prices & Candles)
                        var currentPrice: Double = 0.0
                        let candles = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 200)
                        
                        guard let lastCandle = candles?.last else {
                            return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Mum Verisi Yok (Heimdall)", score: 0))
                        }
                        
                        // Fetch Realtime Price
                        if let quote = try? await HeimdallOrchestrator.shared.requestQuote(symbol: symbol) {
                            currentPrice = quote.currentPrice
                        } else {
                            currentPrice = lastCandle.close
                        }
                        
                        // 2. Scores
                        let orion = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles ?? [], spyCandles: nil)
                        let atlas = FundamentalScoreStore.shared.getScore(for: symbol)
                        
                        // 3. Evaluate via Argus Engine
                        let decision = await ArgusAutoPilotEngine.shared.evaluate(
                            symbol: symbol,
                            currentPrice: currentPrice,
                            equity: effectiveEquity,
                            buyingPower: effectiveBuyingPower,
                            portfolioState: portfolio,
                            candles: candles,
                            atlasScore: atlas?.totalScore,
                            orionScore: orion?.score,
                            orionDetails: orion?.components,
                            aetherRating: aether,
                            hermesInsight: nil,
                            argusFinalScore: nil,
                            demeterScore: 50.0
                        )
                        
                        var signal: TradeSignal? = nil
                        if let sig = decision.signal {
                            signal = TradeSignal(
                                symbol: symbol,
                                action: sig.action,
                                reason: sig.reason,
                                confidence: 80.0,
                                timestamp: Date(),
                                stopLoss: sig.stopLoss,
                                takeProfit: sig.takeProfit,
                                trimPercentage: sig.trimPercentage
                            )
                        }
                        
                        return (signal, decision.log)
                    }
                }
                
                // Collect results from group
                for await (sig, log) in group {
                    if let s = sig {
                        signals.append(s)
                        ArgusLogger.success(.autopilot, "Sinyal Tespit Edildi: \(s.symbol) -> \(s.action.rawValue.uppercased())")
                        print("✅ AutoPilotService: Sinyal - \(s.symbol) -> \(s.action.rawValue) (\(s.reason))")
                    }
                    if let l = log {
                        logs.append(l)
                    }
                }
            }
        }
        
        print("📊 AutoPilotService: Tarama tamamlandı - \(signals.count) sinyal, \(logs.count) log")
        
        return (signals, logs)
    }
}
