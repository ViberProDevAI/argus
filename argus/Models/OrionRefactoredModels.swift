import Foundation

/// Pillar 5: Orion Refactor
/// Simplifies the Technical Score into "Core" (Actionable) and "Lab" (Experimental).

// MARK: - 1. Orion Core (The Signal)
/// The pure technical score used for ArgusDecisionEngine.
/// 0-100 Score based on established Trend and Momentum.
struct OrionCoreScore: Codable, Sendable {
    let score: Double // 0-100
    
    // Components (0-100 each)
    let trendScore: Double    // MA alignment
    let momentumScore: Double // RSI, ROC
    let volScore: Double      // ATR, Bands
    let setupScore: Double    // Pullback / Breakout quality
    
    var signal: SignalAction {
        if score >= 65 { return .buy }
        if score <= 35 { return .sell }
        return .hold
    }
    
    var summary: String {
        if score >= 80 { return "Çok Güçlü Trend" }
        if score >= 60 { return "Pozitif Görünüm" }
        if score <= 20 { return "Çöküş / Trend Yok" }
        if score <= 40 { return "Zayıf Görünüm" }
        return "Nötr / Kararsız"
    }
}

// MARK: - 2. Orion Lab (The Research)
/// Experimental indicators not yet affecting the core score.
struct OrionLabSnapshot: Codable, Sendable {
    // TSI (True Strength Index)
    let tsiValue: Double
    let tsiSignal: Double
    let tsiTrend: MarketRegime // Trend/Chop based on TSI
    
    // Phoenix (Deep Dip Hunter)
    let phoenixScore: Double // 0-100 (100 = Perfect Dip Buy)
    let isPhoenixTriggered: Bool
    
    // Linear Regression
    let lrcSlope: Double
    let lrcChannelStatus: String // "Upper", "Lower", "Mid"
    
    // Lucid SAR
    let sarDirection: String // "Long" / "Short"
}
