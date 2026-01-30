import Foundation

final class ArgusCorseEngine: AutoPilotStrategyEngine {
    let engineType: AutoPilotEngine = .corse
    
    func propose(for symbol: String, context: AutoPilotContext) async -> AutoPilotProposal {
        let dqScore = calculateDataQuality(context: context)
        
        // Quality Gate for Corse: >= 80
        if dqScore < 80 {
            return .init(engine: .corse, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Data Quality Too Low (<80)", confidence: 0, dataQualityScore: dqScore, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        // 1. Existing Trade Logic
        if let trade = context.openTrade {
            // Manage Existing
             return managePosition(trade: trade, context: context, dq: dqScore)
        }
        
        // 2. New Entry Logic
        // Requirements: Atlas >= 65, Orion >= 60, Hermes >= 40, Aether != Panic (Score >= 20)
        guard let atlas = context.atlasScore, atlas >= 65,
              let orion = context.orionScore, orion >= 60,
              let aether = context.aetherRating, aether.numericScore >= 20,
              (context.hermesInsight?.confidence ?? 50) >= 40 else {
            return .init(engine: .corse, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Entry Criteria Not Met", confidence: 0, dataQualityScore: dqScore, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        // Cronos Check (Time Filter) - REMOVED
        // if let cronos = context.cronosScore, cronos < 40 { return ... }
        
        // Trend Check (Price > Simple check if MA logic is not available directly, rely on Orion)
        // Orion Score >= 60 implies decent trend usually.
        
        // Sizing Proposal
        let riskMult = (aether.numericScore >= 65) ? 1.5 : (aether.numericScore < 40 ? 0.3 : 1.0)
        let rlMult = ArgusFeedbackLoopService.shared.getMultiplier(for: .corse)
        
        let baseExposure = 0.05 // 5% base for Swing
        // Apply Both Multipliers
        // RL Multiplier can boost up to 1.3x or reduce to 0.7x
        let targetExposure = min(baseExposure * riskMult * rlMult, 0.12) // Cap raised slightly to 12% for High Conviction
        
        return AutoPilotProposal(
            engine: .corse,
            symbol: symbol,
            action: .buy,
            targetExposurePercent: targetExposure,
            quantity: nil, // Let Manager calculate Qty based on Price
            rationale: "Corse Swing Entry (Score: \(Int(atlas)), RL: \(String(format: "%.1fx", rlMult)))",
            confidence: (atlas * 0.4 + orion * 0.4 + aether.numericScore * 0.2),
            dataQualityScore: dqScore,
            scores: (atlas, orion, aether.numericScore, context.hermesInsight?.confidence)
        )
    }
    
    private func managePosition(trade: Trade, context: AutoPilotContext, dq: Double) -> AutoPilotProposal {
        let currentPrice = context.price
        // Logic: Stop Loss or Take Profit
        
        // Hard Stop via Argus Score (<40)
        if (context.argusFinalScore ?? 50) < 40 {
             return AutoPilotProposal(engine: .corse, symbol: trade.symbol, action: .sell, targetExposurePercent: 0, quantity: trade.quantity, rationale: "Argus Score Deteriorated (<40)", confidence: 100, dataQualityScore: dq, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        // Cronos Decay (<20) - REMOVED
        // if let cr = context.cronosScore, cr < 20 { ... }
        
        // Take Profit (+15% and Overbought)
        let pnl = (currentPrice - trade.entryPrice) / trade.entryPrice
        if pnl > 0.15 && (context.orionScore ?? 50) > 85 {
             let partQty = trade.quantity * 0.5
             return AutoPilotProposal(engine: .corse, symbol: trade.symbol, action: .sell, targetExposurePercent: nil, quantity: partQty, rationale: "Take Profit Partial (+15%)", confidence: 90, dataQualityScore: dq, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        return AutoPilotProposal(engine: .corse, symbol: trade.symbol, action: .hold, targetExposurePercent: nil, quantity: trade.quantity, rationale: "Holding Position", confidence: 50, dataQualityScore: dq, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
    }
    
    private func calculateDataQuality(context: AutoPilotContext) -> Double {
        var score = 0.0
        if let c = context.candles, c.count > 100 { score += 30 }
        if context.atlasScore != nil { score += 25 }
        if context.aetherRating != nil { score += 25 }
        if context.hermesInsight != nil { score += 20 }
        return score
    }
}
