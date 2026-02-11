import Foundation

final class ArgusShieldEngine: AutoPilotStrategyEngine {
    let engineType: AutoPilotEngine = .shield
    
    // Configuration
    private let hedgeSymbol = "SQQQ" // ProShares UltraPro Short QQQ (3x Bear)
    // Note: In real production, we might choose based on portfolio beta, but SQQQ is a good proxy for Tech-heavy portfolios like Argus.
    
    func propose(for symbol: String, context: AutoPilotContext) async -> AutoPilotProposal {
        // Shield Engine ONLY cares about the Hedge Symbol or managing its own trades
        if symbol != hedgeSymbol {
            // However, we might want to check existing Hedge trades?
            // The Manager calls propose for every symbol in "analysis list".
            // Shield probably shouldn't be called for AAPL.
            // It should be injected into the cycle for SQQQ specifically.
            return .init(engine: .shield, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Not Hedge Symbol", confidence: 0, dataQualityScore: 0, scores: (nil, nil, nil, nil))
        }
        
        let aetherScore = context.aetherRating?.numericScore ?? 50.0
        
        // 1. Manage Existing Hedge
        if let trade = context.openTrade, trade.engine == .shield {
             return manageHedge(trade: trade, aetherScore: aetherScore, context: context)
        }
        
        // 2. Entry Logic (Bear Mode)
        // Trigger: Aether < 25 (Deep Risk Off)
        // Confirm with Technicals? SQQQ Technicals should be Bullish if Market is Bearish.
        // But Shield is primarily Macro driven.
        
        if aetherScore < 25 {
            // Crash Protection Mode
            
            // Target Exposure:
            // If < 15: 20% Exposure
            // If < 25: 10% Exposure
            let exposure = aetherScore < 15 ? 0.20 : 0.10
            
            return AutoPilotProposal(
                engine: .shield,
                symbol: hedgeSymbol,
                action: .buy,
                targetExposurePercent: exposure,
                quantity: nil,
                rationale: "SHIELD ACTIVATED: Macro Risk Critical (\(Int(aetherScore)))",
                confidence: 100 - aetherScore, // Lower aether = Higher confidence in hedge
                dataQualityScore: 100, // Trusted internal logic
                scores: (nil, nil, aetherScore, nil)
            )
        }
        
        return .init(engine: .shield, symbol: symbol, action: .skip, targetExposurePercent: nil, quantity: 0, rationale: "Macro Stable", confidence: 0, dataQualityScore: 0, scores: (nil, nil, aetherScore, nil))
    }
    
    private func manageHedge(trade: Trade, aetherScore: Double, context: AutoPilotContext) -> AutoPilotProposal {
        // Exit Logic
        // If Aether improves (> 40), remove hedge.
        // If Aether is "Neutral" (30-40), maybe trim?
        
        if aetherScore > 40 {
            return AutoPilotProposal(
                engine: .shield,
                symbol: trade.symbol,
                action: .sell,
                targetExposurePercent: 0,
                quantity: trade.quantity, // Close All
                rationale: "SHIELD DEACTIVATED: Macro Recovering (\(Int(aetherScore)) > 40)",
                confidence: 100,
                dataQualityScore: 100,
                scores: (nil, nil, aetherScore, nil)
            )
        }
        
        // Dynamic Adjustment (Optional): If Aether drops further, increase size? 
        // Manager usually handles "Buy" for adding size if we return Buy proposal again?
        // For simplicity, HOLD if between 25-40 or < 25 (already bought).
        
        return AutoPilotProposal(
            engine: .shield,
            symbol: trade.symbol,
            action: .hold,
            targetExposurePercent: nil,
            quantity: trade.quantity,
            rationale: "Holding Shield (Risk: \(Int(aetherScore)))",
            confidence: 100,
            dataQualityScore: 100,
            scores: (nil, nil, aetherScore, nil)
        )
    }
}
