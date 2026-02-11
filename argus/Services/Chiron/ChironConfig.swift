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
    
    // Dynamic Risk Ceiling
    // Aether Safe Mode: < 30 -> 1.5R
    // Aether >= 50 -> UNLIMITED (20.0R) to allow Learning
    nonisolated static func dynamicMaxRiskR(aetherScore: Double) -> Double {
        if aetherScore >= 50 { return 20.0 }    // Limit Kaldırıldı (Öğrenme Modu)
        if aetherScore >= 30 { return 2.5 }     // Temkinli
        return 1.5                             // Ayı/Çöküş
    }
}
