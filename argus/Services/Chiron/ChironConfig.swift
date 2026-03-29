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
    // Aether >= 70 (Boğa)   -> 10R rahat ama sınırlı
    // Aether >= 55 (Nötr)   ->  6R temkinli
    // Aether >= 40 (Dikkat) ->  3R çok küçük
    // Aether >= 25 (Kötü)   ->  1.5R minimal
    // Aether  < 25 (Çöküş)  ->  0R yeni giriş yok
    nonisolated static func dynamicMaxRiskR(aetherScore: Double) -> Double {
        if aetherScore >= 70 { return 10.0 }   // Boğa: rahat ama sınırlı
        if aetherScore >= 55 { return 6.0 }    // Nötr: temkinli
        if aetherScore >= 40 { return 3.0 }    // Dikkat: çok küçük
        if aetherScore >= 25 { return 1.5 }    // Kötü: minimal
        return 0.0                             // Çöküş: yeni giriş yok
    }
}
