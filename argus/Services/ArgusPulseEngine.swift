import Foundation

final class ArgusPulseEngine: AutoPilotStrategyEngine {
    let engineType: AutoPilotEngine = .pulse
    
    func propose(for symbol: String, context: AutoPilotContext) async -> AutoPilotProposal {
        let dqScore = calculateDataQuality(context: context)
        
        // Quality Gate for Pulse: >= 60
        if dqScore < 60 {
             return .init(engine: .pulse, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "DQ < 60", confidence: 0, dataQualityScore: dqScore, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        // 1. Manage Existing
        if let trade = context.openTrade {
             // If engine mismatches, we usually shouldn't manage it here, but Protocol allows knowing own trades?
            // The Context passes openTrade for this symbol.
            // Pulse logic for Pulse trades:
            if trade.engine == .pulse {
               return managePosition(trade: trade, context: context, dq: dqScore)
            } else {
               // Don't touch Corse trades
               return .init(engine: .pulse, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Not Pulse Trade", confidence: 0, dataQualityScore: dqScore, scores: (nil, nil, nil, nil))
            }
        }
        
        // 2. New Entry Logic
        // Hermes >= 70, Orion >= 55, Aether >= 40 (Neutral)
        guard let hermes = context.hermesInsight, hermes.confidence >= 70,
              let orion = context.orionScore, orion >= 55,
              let aether = context.aetherRating, aether.numericScore >= 40 else {
            return .init(engine: .pulse, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Logic Fail", confidence: 0, dataQualityScore: dqScore, scores: (context.atlasScore, context.orionScore, context.aetherRating?.numericScore, context.hermesInsight?.confidence))
        }
        
        // Cronos Check (Pulse needs good timing!) - REMOVED
        // if let cronos = context.cronosScore, cronos < 50 { return ... }
        
        // Sizing
        let baseExposure = 0.03 // 3% for Scalp
        let rlMult = ArgusFeedbackLoopService.shared.getMultiplier(for: .pulse)
        let finalExposure = min(baseExposure * rlMult, 0.05) // Cap 5%
        
        return AutoPilotProposal(
            engine: .pulse,
            symbol: symbol,
            action: .buy,
            targetExposurePercent: finalExposure,
            quantity: nil,
            rationale: "Pulse Scalp (News: \(hermes.sentiment), RL: \(String(format: "%.1fx", rlMult)))",
            confidence: hermes.confidence,
            dataQualityScore: dqScore,
            scores: (context.atlasScore, orion, aether.numericScore, hermes.confidence)
        )
    }
    
    private func managePosition(trade: Trade, context: AutoPilotContext, dq: Double) -> AutoPilotProposal {
        let currentPrice = context.price
        let pnl = (currentPrice - trade.entryPrice) / trade.entryPrice
        
        // Pulse Exit: Quick Profit or Quick Loss
        // Stop hard at -3%
        if pnl < -0.03 {
            return AutoPilotProposal(engine: .pulse, symbol: trade.symbol, action: .sell, targetExposurePercent: 0, quantity: trade.quantity, rationale: "Pulse Hard Stop (-3%)", confidence: 100, dataQualityScore: dq, scores: (nil, nil, nil, nil))
        }
        
        // Take Profit: +5%
        if pnl > 0.05 {
            return AutoPilotProposal(engine: .pulse, symbol: trade.symbol, action: .sell, targetExposurePercent: 0, quantity: trade.quantity, rationale: "Pulse TP (+5%)", confidence: 100, dataQualityScore: dq, scores: (nil, nil, nil, nil))
        }
        
        // Cronos Check (Exit if timing sours < 30) - REMOVED
        // if let cr = context.cronosScore, cr < 30 { return ... }
        
        return AutoPilotProposal(engine: .pulse, symbol: trade.symbol, action: .hold, targetExposurePercent: nil, quantity: trade.quantity, rationale: "Pulse Hold", confidence: 50, dataQualityScore: dq, scores: (nil, nil, nil, nil))
    }
    
    private func calculateDataQuality(context: AutoPilotContext) -> Double {
        // Pulse cares less about Atlas
        var score = 0.0
        if let c = context.candles, c.count > 50 { score += 30 }
        if context.orionScore != nil { score += 30 }
        if context.hermesInsight != nil { score += 40 } // News heavy
        return score
    }
}
