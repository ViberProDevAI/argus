import Foundation

/// Static Configuration for Chiron Risk Governor
struct RiskBudgetConfig: Sendable {
    // Risk Limits
    // Removed static limit: nonisolated static let maxOpenRiskR: Double = 2.5 
    nonisolated static let maxPositions: Int = 10     // Max concurrent positions
    
    // Cluster Limits
    nonisolated static let maxConcentrationPerCluster: Int = 100 // Max positions per sector/cluster (Expanded from 2)
    
    // Time Limits
    nonisolated static let cooldownMinutes: Double = 30 // Min minutes between trades on same symbol

    // Regime thresholds (Aether)
    nonisolated static let deepRiskOffMaxScore: Double = 25
    nonisolated static let riskOffMaxScore: Double = 40

    // Forced unwind settings
    nonisolated static let deepRiskOffTrimPercent: Double = 50
    nonisolated static let riskOffTrimPercent: Double = 25
    
    // Dynamic Risk Ceiling
    // Aether Safe Mode: < 30 -> 1.5R
    // Aether >= 50 -> UNLIMITED (20.0R) to allow Learning
    nonisolated static func dynamicMaxRiskR(aetherScore: Double) -> Double {
        if aetherScore <= deepRiskOffMaxScore { return 0.8 } // Hard defense
        if aetherScore <= riskOffMaxScore { return 1.5 }     // Defensive
        if aetherScore >= 50 { return 20.0 }                 // Learning mode
        return 2.5                                            // Cautious
    }
}
