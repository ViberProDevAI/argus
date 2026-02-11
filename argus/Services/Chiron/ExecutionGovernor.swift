import Foundation

/// The Gatekeeper.
/// All AutoPilot signals must pass through here before Execution.
/// Enforces Risk Budgets, Cooldowns, and Capacity Limits.
actor ExecutionGovernor {
    static let shared = ExecutionGovernor()
    
    // State
    private var lastTradeTime: [String: Date] = [:]
    private var lastTradeAction: [String: SignalAction] = [:]
    private var lastTradePrice: [String: Double] = [:]
    
    // Dependencies
    // - Heimdall (Global Access via singleton)
    // - TradeJournal (Actor)
    
    private init() {}
    
    // MARK: - Main Review Function
    
    /// Reviews a trading signal against system constraints.
    /// Returns:
    /// - `.success(Signal)`: Approved (possibly modified quantity).
    /// - `.failure(Reason)`: Rejected (Budget full, Cooldown, etc).
    func review(
        signal: AutoPilotSignal, // Action, Reason, Stop
        symbol: String, // Explicit Symbol
        quantity: Double, // Proposed Quantity
        portfolio: [Trade],
        equity: Double,
        scores: (atlas: Double?, orion: Double?, aether: Double?, hermes: Double?)
    ) -> ExecutionDecision {
        
        let isRiskReducing = (signal.action == .sell)
        
        // 1. Cooldown Check (Spam Prevention)
        // Exempt Sells usually, unless we want to prevent panic selling loops? 
        // No, sells are usually urgent. But we might block RE-ENTRY (Buy after Sell).
        
        if signal.action == .buy, let lastTime = lastTradeTime[symbol], let lastAction = lastTradeAction[symbol] {
             let elapsed = Date().timeIntervalSince(lastTime)
             
             // Rule: Cooldown after ANY trade
             if elapsed < (RiskBudgetConfig.cooldownMinutes * 60) {
                 return .rejected(reason: "Chiron Cooldown Aktif (\(Int(RiskBudgetConfig.cooldownMinutes - (elapsed/60)))dk kaldı).")
             }
             
             // Rule: Hysteresis (Re-Entry after Sell)
             if lastAction == .sell {
                 // We sold recently. To re-enter, we need a BETTER setup.
                 // E.g. Price is significantly lower (buy dip) OR Consensus is super strong.
                 /* 
                  Since we don't have current Price here easily (it's in the signal context in higher layers),
                  we will rely on TIME or SCORE hysteresis.
                  If it's been less than 2 hours since sell, require strict score.
                 */
                 if elapsed < 7200 { // 2 Hours
                     let orion = scores.orion ?? 0
                     if orion < 70 { // Must be very strong trend to re-enter quickly
                         return .rejected(reason: "Hysteresis: Satış sonrası 2 saat içinde yeniden giriş için Orion > 70 olmalı.")
                     }
                 }
             }
        }
        
        // 2. Position Count Hard Cap
        // Exempt Sells
        // REMOVED BY USER REQUEST (Unlimited Positions)
        /*
        if !isRiskReducing && isMaxPositionsReached(portfolio: portfolio) {
            return .rejected(reason: "Maksimum Pozisyon Sayısına Ulaşıldı (\(RiskBudgetConfig.maxPositions)). Satış yaparak yer açın.")
        }
        */
        
        // 3. Cluster Saturation Check
        // Exempt Sells
        if !isRiskReducing && isClusterSaturated(symbol: symbol, portfolio: portfolio) {
            let cluster = ClusterMap.getCluster(for: symbol)
            return .rejected(reason: "Sektör Limiti Dolu: \(cluster)")
        }
        
        // 4. Risk Budget Check (R-Unit)
        // Exempt Sells
        if !isRiskReducing {
            // Measure current risk
            let currentTotalRiskR = calculateTotalRiskR(portfolio: portfolio, equity: equity)
            
            // Estimate New Trade Risk
            var tradeRiskR = 0.0
            if signal.stopLoss != nil {
                 tradeRiskR = 0.5 // Simplified assumption as before
            }
            
            // DYNAMIC RISK BUDGETING
            let aetherScore = scores.aether ?? 50.0 // Default to Neutral if missing
            let maxRiskR = RiskBudgetConfig.dynamicMaxRiskR(aetherScore: aetherScore)
            
            if (currentTotalRiskR + tradeRiskR) > maxRiskR {
                return .rejected(reason: "Risk Bütçesi Dolu (Mevcut: \(String(format:"%.1f", currentTotalRiskR))R / Max: \(maxRiskR)R - Aether: \(Int(aetherScore))).")
            }
        }
        
        // 5. Data Confidence & Quantity Scaling
        var finalQuantity = quantity
        var finalSignal = signal
        
        // Heimdall Check (Simplistic)
        if !isRiskReducing, let or = scores.orion, or < 65 {
            // Signal was generated with low confidence
            finalQuantity = floor(quantity * 0.7)
            if finalQuantity > 0 {
                finalSignal = AutoPilotSignal(
                    action: finalSignal.action,
                    quantity: finalQuantity,
                    reason: finalSignal.reason + " [Chiron: Scaled 0.7x]",
                    stopLoss: finalSignal.stopLoss,
                    takeProfit: finalSignal.takeProfit,
                    strategy: finalSignal.strategy,
                    trimPercentage: finalSignal.trimPercentage
                )
            }
        }
        
        // APPROVED
        lastTradeTime[symbol] = Date()
        lastTradeAction[symbol] = signal.action
        // Note: lastTradePrice update requires Price passed in. For now, skipping Price hysteresis logic to avoid signature change.
        
        return .approved(signal: finalSignal, adjustedQuantity: finalQuantity)
    }
    
    // MARK: - Internal Risk Logic
    
    private func calculateTotalRiskR(portfolio: [Trade], equity: Double) -> Double {
        guard equity > 0 else { return 0.0 }
        
        var totalR = 0.0
        for trade in portfolio where trade.isOpen {
            let riskMoney: Double
            if let sl = trade.stopLoss {
                let riskPerShare = max(0, trade.entryPrice - sl)
                riskMoney = riskPerShare * trade.quantity
            } else {
                riskMoney = (trade.entryPrice * trade.quantity) * 0.10
            }
            let riskPercent = (riskMoney / equity) * 100.0
            totalR += riskPercent
        }
        return totalR
    }
    
    private func isClusterSaturated(symbol: String, portfolio: [Trade]) -> Bool {
        let targetCluster = ClusterMap.getCluster(for: symbol)
        let openTradesInCluster = portfolio.filter {
            $0.isOpen && ClusterMap.getCluster(for: $0.symbol) == targetCluster
        }.count
        return openTradesInCluster >= RiskBudgetConfig.maxConcentrationPerCluster
    }
    
    private func isMaxPositionsReached(portfolio: [Trade]) -> Bool {
        let openCount = portfolio.filter { $0.isOpen }.count
        // Correctly read dynamic limit from User Settings
        let limit = UserDefaults.standard.integer(forKey: "maxOpenPositions")
        let effectiveLimit = limit > 0 ? limit : RiskBudgetConfig.maxPositions
        return openCount >= effectiveLimit
    }

    // MARK: - Journaling Hook (ARGUS 3.0: Migrated to ArgusLedger)
    
    func didExecute(trade: Trade, scores: (Double, Double, Double, Double, Double?)) async {
        // Create entry reason from scores
        let reason = "Atlas: \(Int(scores.0)), Orion: \(Int(scores.1)), Aether: \(Int(scores.2)), Hermes: \(Int(scores.3))"
        let dominantSignal = scores.1 > scores.0 ? "Orion" : "Atlas"
        
        // Log to ArgusLedger (Single Source of Truth)
        ArgusLedger.shared.openTrade(
            symbol: trade.symbol,
            price: trade.entryPrice,
            reason: reason,
            dominantSignal: dominantSignal,
            decisionId: trade.id.uuidString
        )
    }
}

enum ExecutionDecision {
    case approved(signal: AutoPilotSignal, adjustedQuantity: Double)
    case rejected(reason: String)
}
