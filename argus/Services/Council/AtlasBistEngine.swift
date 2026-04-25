import Foundation

/// Atlas BIST Engine (Project Turquoise)
/// Specialized Fundamental Engine for Turkey Markets
/// Adapts valuation metrics for BIST (High Inflation, Local Dynamics)
actor AtlasBistEngine {
    static let shared = AtlasBistEngine()
    
    // MARK: - Public API
    
    func analyze(symbol: String, financials: FinancialSnapshot) async -> AtlasDecision {
        let timestamp = Date()
        
        // 1. Data Safety Check
        // In BIST, we heavily rely on Revenue and Net Income. If missing, we can't judge.
        guard let revenueGrowth = financials.revenueGrowth,
              let peRatio = financials.peRatio,
              let pbRatio = financials.pbRatio,
              let netIncome = financials.netMargin else {
            
            return createNeutralDecision(symbol: symbol, reason: "Eksik Temel Veri (BIST)")
        }
        
        // 2. Inflation-Adjusted Growth Analysis
        // Assumption: Official Inflation ~50%. Real Growth requires > 40-50% nominal growth.
        let inflationThreshold = 0.40 // 40%
        let isRealGrowth = revenueGrowth > inflationThreshold
        
        let growthScore: Double
        if revenueGrowth > 0.80 {
            growthScore = 100 // Excellent
        } else if revenueGrowth > 0.50 {
            growthScore = 80 // Good
        } else if revenueGrowth > 0.30 {
            growthScore = 50 // Matching Inflation (Neutral)
        } else {
            growthScore = 20 // Real Contraction
        }
        
        // 3. Valuation Analysis (BIST Specific Multiples)
        // BIST is generally cheaper than US.
        // PE < 5 is Cheap, PE > 30 is Expensive.
        let valuationScore: Double
        
        if peRatio < 0 {
            valuationScore = 0 // Loss making
        } else if peRatio < 5.0 {
            valuationScore = 90 // Deep Value
        } else if peRatio < 10.0 {
            valuationScore = 75 // Value
        } else if peRatio < 20.0 {
            valuationScore = 50 // Fair
        } else if peRatio < 35.0 {
            valuationScore = 30 // Expensive
        } else {
            valuationScore = 10 // Bubble?
        }
        
        // PB Deep Value Check
        let isDeepValue = pbRatio < 1.0 && pbRatio > 0.3
        
        // 4. Synthesis
        // Weighted Average: 40% Growth, 60% Valuation (Value Trap Protection)
        var finalScore = (growthScore * 0.4) + (valuationScore * 0.6)
        
        // Bonus: Deep Value with Profits
        if isDeepValue && netIncome > 0 {
            finalScore += 15.0
        }
        
        // Penalty: Real Contraction
        if !isRealGrowth {
            finalScore -= 20.0
        }
        
        // 5. Decision
        let action: ProposedAction
        let confidence = min(max(finalScore / 100.0, 0.0), 1.0)
        
        if finalScore >= 75 {
            action = .buy
        } else if finalScore <= 30 {
            action = .sell
        } else {
            action = .hold
        }
        
        // Reasoning
        var reasons: [String] = []
        if isDeepValue { reasons.append("PD/DD < 1.0 (Kelepir)") }
        if peRatio < 8.0 { reasons.append("F/K Cazip (\(String(format: "%.1f", peRatio)))") }
        if !isRealGrowth { reasons.append("Enflasyon Altı Büyüme") }
        if revenueGrowth > 0.80 { reasons.append("Agresif Büyüme (%\(Int(revenueGrowth * 100)))") }
        
        let reasonStr = reasons.isEmpty ? "Nötr Görünüm" : reasons.joined(separator: ", ")
        
        let proposal = FundamentalProposal(
            proposer: "AtlasBist",
            proposerName: "Atlas (Turquoise)",
            action: action,
            confidence: confidence,
            reasoning: reasonStr,
            targetPrice: nil,
            intrinsicValue: nil,
            marginOfSafety: nil
        )
        
        return AtlasDecision(
            symbol: symbol,
            action: action,
            netSupport: confidence,
            isStrongSignal: confidence > 0.75,
            intrinsicValue: nil,
            marginOfSafety: nil,
            winningProposal: proposal,
            allProposals: [proposal],
            votes: [],
            vetoReasons: [],
            timestamp: timestamp
        )
    }
    
    // MARK: - Helpers
    
    private func createNeutralDecision(symbol: String, reason: String) -> AtlasDecision {
        return AtlasDecision(
            symbol: symbol,
            action: .hold,
            netSupport: 0.0,
            isStrongSignal: false,
            intrinsicValue: nil,
            marginOfSafety: nil,
            winningProposal: nil,
            allProposals: [],
            votes: [],
            vetoReasons: [reason],
            timestamp: Date()
        )
    }
}
