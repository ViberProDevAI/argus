import Foundation

/// Pillar 7 & 4: Argus Auto-Pilot (Sniper & Shadow)
/// Handles the execution logic, safety gating, and shadow learning.
final class ArgusAutoPilot {
    static let shared = ArgusAutoPilot()
    
    private let marketProvider = MarketDataProvider.shared
    private let logger = AutoPilotLogger.shared
    private let decisionEngine = ArgusDecisionEngine.shared
    
    // Thresholds
    private let realTradeThreshold: Double = 78.0
    private let shadowTradeThreshold: Double = 60.0
    
    private init() {}
    
    /// The Brain: Decides whether to enter a trade, shadow box, or ignore.
    func attemptEntry(symbol: String, quote: Quote) async {
        // 1. SAFETY GATE (Pillar 7)
        // Stop garbage data from ever reaching the decision engine.
        let health = await marketProvider.evaluateDataHealth(symbol: symbol)
        
        guard health.isSafeForTrading else {
            logger.logSystemEvent("⛔ AutoPilot Rejection: \(symbol) - Data Unsafe (Score: \(health.qualityScore))")
            return
        }
        
        // 2. FETCH CONTEXT (Pillar 2/5)
        // Using Heimdall Orchestrator for robust data
        guard let candles = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 200) else { return }
        
        // 3. ANALYZE (Pillar 5)
        async let atlas = FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore // Cached/Async
        let orion = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles)?.score
        let aether = MacroRegimeService.shared.getCachedRating()?.numericScore
        
        // 4. SCORE
        let decision = decisionEngine.makeDecision(
            symbol: symbol,
            assetType: .stock,
            atlas: await atlas,
            orion: orion,
            orionDetails: nil,
            aether: aether,
            hermes: nil,
            athena: nil,
            phoenixAdvice: nil,
            demeterScore: nil, 
            marketData: nil,
            traceContext: (price: quote.currentPrice, freshness: 100, source: "Heimdall/AutoPilot")
        ).1 // Take Decision Result (Ignore Trace)
        
        let score = decision.finalScoreCore
        let vix = MacroRegimeService.shared.getCurrentVix()
        
        // 5. EXECUTION LOGIC (Pillar 4 - Shadow Boxing)
        
        if score >= realTradeThreshold {
            // A. REAL SNIPER MODE
            print("🦅 SNIPER ENTRY: \(symbol) Score: \(Int(score))")
            // Call ViewModel to execute real trade
            await executeRealTrade(symbol: symbol, price: quote.currentPrice, size: calculatePositionSize(score: score, macro: aether))
            
        } else if score >= shadowTradeThreshold {
            // B. SHADOW BOXING MODE
            print("🥊 SHADOW ENTRY: \(symbol) Score: \(Int(score)) - Virtual Trade Recorded")
            saveShadowTrade(symbol: symbol, price: quote.currentPrice, atlas: await atlas ?? 0, orion: orion ?? 0, aether: aether ?? 0, vix: vix)
            
        } else {
            // C. IGNORE
            // logger.logSystemEvent("💤 Ignore: \(symbol) Score: \(Int(score))")
        }
    }
    
    // MARK: - Internals
    
    private func calculatePositionSize(score: Double, macro: Double?) -> Double {
        // Pillar 7: Macro-based Sizing
        // Base risk 1%. If Macro (Aether) is bullish (>60), scale up to 3%.
        let baseRisk = 0.01
        let macroBonus = ((macro ?? 50.0) - 50.0) / 1000.0 // small scaler
        return min(0.03, max(0.005, baseRisk + macroBonus))
    }
    
    private func executeRealTrade(symbol: String, price: Double, size: Double) async {
        // Handover to TradingViewModel via Notification (Decoupled)
        let intent: [String: Any] = [
            "symbol": symbol,
            "action": "BUY", // For now AutoPilot only does Buy Entry here? Exit is separate.
            "amount": 1000.0, // Fixed amount for now or calculate Notional: size * Bal? 
            // Better: Pass 'size' as risk percentage? 
            // Let's stick to ViewModel handling sizing or use fixed notional for MVP.
            // User asked for "Anti-Churn", assumes existing logic executes.
            // Sending fixed amount of $1000 for Demo purposes as before?
            // "size" calc was 0.01 (1%). 
            // Let's send the raw 'size' (pct) or value.
            "value": 1000.0 // Placeholder fixed notional
        ]
        
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("ArgusExecuteTradeIntent"), object: nil, userInfo: intent)
            print("🚀 EXECUTE INTENT SENT: Buy \(symbol)")
        }
    }
    
    private func saveShadowTrade(symbol: String, price: Double, atlas: Double, orion: Double, aether: Double, vix: Double) {
        Task { @MainActor in
            LearningPersistenceManager.shared.logShadowEntry(
                symbol: symbol,
                price: price,
                atlas: atlas,
                orion: orion,
                aether: aether,
                vix: vix
            )
        }
    }
    
    // MARK: - Exits
    func executeExit(trade: Trade, reason: String) async {
        print("🚨 Auto-Pilot Exit: \(trade.symbol) - \(reason)")
        // Logic to close trade in Portfolio Service or notify VM
        // For MVP, just log notification
    }
}
