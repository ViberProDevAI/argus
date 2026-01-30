import Foundation

// MARK: - Chronos Walk-Forward Models
/// Time Machine Results (Zaman Makinesi Çıktıları)

struct WalkForwardConfig: Codable {
    let inSampleDays: Int      // Optimizasyon penceresi (örn: 252 = 1 yıl)
    let outOfSampleDays: Int   // Test penceresi (örn: 63 = 3 ay)
    let stepDays: Int          // Her iterasyonda kaydırma (örn: 63 = 3 aylık rolling)
    let initialCapital: Double
    
    static let standard = WalkForwardConfig(
        inSampleDays: 252,
        outOfSampleDays: 63,
        stepDays: 63,
        initialCapital: 10000
    )
    
    static let aggressive = WalkForwardConfig(
        inSampleDays: 180,
        outOfSampleDays: 45,
        stepDays: 45,
        initialCapital: 10000
    )
    
    static let conservative = WalkForwardConfig(
        inSampleDays: 504,  // 2 yıl
        outOfSampleDays: 126, // 6 ay
        stepDays: 126,
        initialCapital: 10000
    )
}

struct WindowResult: Codable, Identifiable {
    var id: Int { windowNumber }
    
    let windowNumber: Int
    let inSampleStart: Date
    let inSampleEnd: Date
    let outSampleStart: Date
    let outSampleEnd: Date
    
    let inSampleReturn: Double
    let outOfSampleReturn: Double
    let tradeCount: Int
    let winRate: Double
    
    let optimizedParams: OptimizedParameters
}

struct OptimizedParameters: Codable {
    let stopLossPct: Double
    let entryThreshold: Double
    let exitThreshold: Double
    
    let inSampleReturn: Double
    let inSampleWinRate: Double
    let inSampleDrawdown: Double
}

struct WalkForwardResult {
    let symbol: String
    let strategy: BacktestConfig.StrategyType
    let config: WalkForwardConfig
    
    let windowResults: [WindowResult]
    
    // Aggregate Metrics
    let totalOutOfSampleReturn: Double
    let avgOutOfSampleReturn: Double
    let avgInSampleReturn: Double
    let overfitRatio: Double    // OOS/IS - 1.0'a yakın = iyi
    let consistencyScore: Double // Kârlı window yüzdesi
    
    let totalTrades: Int
    let overallWinRate: Double
    
    let combinedTrades: [BacktestTrade]
    let outOfSampleEquity: [EquityPoint]
    
    let generatedAt: Date
    
    // Quality Assessment
    var isReliable: Bool {
        overfitRatio > 0.6 && consistencyScore > 60 && totalTrades >= 10
    }
}

struct OverfitAnalysis: Codable {
    let score: Double          // 0-100, düşük = iyi
    let level: OverfitLevel
    let warnings: [String]
    let recommendation: String
}

enum OverfitLevel: String, Codable {
    case low = "Düşük"
    case moderate = "Orta"
    case high = "Yüksek"
    case critical = "Kritik"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
