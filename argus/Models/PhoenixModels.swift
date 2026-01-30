import Foundation

/// The explicit timeframe for Phoenix Analysis
enum PhoenixTimeframe: String, Codable, CaseIterable, Sendable {
    case auto = "Otomatik" // Auto logic
    case m15 = "15 Dakika"
    case h1 = "1 Saat"
    case h4 = "4 Saat"
    case d1 = "1 Gün"
    
    var yahooInterval: String {
        switch self {
        case .m15: return "15m"
        case .h1: return "1h"
        case .h4: return "1h" // Fetch 1h, resample manually
        case .d1: return "1d"
        case .auto: return "1h" // Default fallback
        }
    }
    
    var localizedName: String { rawValue }
}

/// Configuration for the Engine
struct PhoenixConfig: Codable, Sendable {
    var lookback: Int = 180
    var minBars: Int = 120
    var atrPeriod: Int = 14
    var regressionMultiplier: Double = 2.0
    var bufferAtrFraction: Double = 0.25
    var bufferSigmaFraction: Double = 0.10
    
    nonisolated init() {}
}

/// The output of the Phoenix Engine
struct PhoenixAdvice: Codable, Sendable {
    enum Status: String, Codable {
        case active = "ACTIVE"
        case inactive = "INACTIVE"  // NEW: Not triggered but valid data
        case insufficientData = "INSUFFICIENT_DATA"
        case error = "ERROR"
    }
    
    let id: UUID
    let timestamp: Date // updatedAt
    let symbol: String
    let timeframe: PhoenixTimeframe
    let status: Status
    
    // Regression Channel
    let lookback: Int
    let regressionSlope: Double?
    let channelUpper: Double?
    let channelMid: Double?
    let channelLower: Double?
    let sigma: Double?
    
    // Zones
    let entryZoneLow: Double?
    let entryZoneHigh: Double?
    let invalidationLevel: Double?
    let targets: [Double] // [T1, T2]
    
    // Triggers
    struct Triggers: Codable {
        let touchLowerBand: Bool
        let rsiReversal: Bool
        let bullishDivergence: Bool
        let trendOk: Bool
    }
    let triggers: Triggers
    
    // Meta
    let confidence: Double // 0-100
    let reasonShort: String // "Fiyat kanal dibine yakın..."
    let atr: Double?
    let rSquared: Double?  // NEW: Channel reliability (0-1)
    
    // Factory: INSUFFICIENT DATA
    nonisolated static func insufficient(symbol: String, timeframe: PhoenixTimeframe) -> PhoenixAdvice {
        PhoenixAdvice(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            timeframe: timeframe,
            status: .insufficientData,
            lookback: 0,
            regressionSlope: nil,
            channelUpper: nil,
            channelMid: nil,
            channelLower: nil,
            sigma: nil,
            entryZoneLow: nil,
            entryZoneHigh: nil,
            invalidationLevel: nil,
            targets: [],
            triggers: Triggers(touchLowerBand: false, rsiReversal: false, bullishDivergence: false, trendOk: false),
            confidence: 0,
            reasonShort: "Yetersiz veri veya geçmiş bulunamadı.",
            atr: nil,
            rSquared: nil
        )
    }
    
    // Factory: INACTIVE (Valid data but Phoenix not triggered)
    nonisolated static func inactive(symbol: String, timeframe: PhoenixTimeframe, reason: String) -> PhoenixAdvice {
        PhoenixAdvice(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            timeframe: timeframe,
            status: .inactive,
            lookback: 0,
            regressionSlope: nil,
            channelUpper: nil,
            channelMid: nil,
            channelLower: nil,
            sigma: nil,
            entryZoneLow: nil,
            entryZoneHigh: nil,
            invalidationLevel: nil,
            targets: [],
            triggers: Triggers(touchLowerBand: false, rsiReversal: false, bullishDivergence: false, trendOk: false),
            confidence: 0,
            reasonShort: reason,
            atr: nil,
            rSquared: nil
        )
    }
}

// MARK: - Pipeline Models

enum PhoenixScanMode: String, Codable, CaseIterable {
    case saver = "Tasruf Modu" // Only Low Cost
    case balanced = "Dengeli"  // Mix
    case aggressive = "Agresif" // High Cost
}

struct PhoenixCandidate: Identifiable, Codable {
    var id = UUID()
    let symbol: String
    let assetType: SafeAssetType
    let lastPrice: Double
    let dayChangePct: Double
    let volume: Double
    
    // Metadata
    let universeSource: String // "Yahoo:Losers", "Yahoo:Active"
    let level0Reason: String
    
    // Evidence (Level 1)
    var evidence: PhoenixEvidence?
    var isPartial: Bool = true
}

struct PhoenixEvidence: Codable {
    let candlesAvailable: Bool
    let liquidityOk: Bool
    
    // Techs
    let volatilityATR: Double?
    let trendScore: Double? // -1 to 1
    let channelStatus: String?
    
    // Fundamentals (Optional)
    let atlasConfidence: Double?
}

struct PhoenixRunReport: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let mode: PhoenixScanMode
    let regime: String // "Bull", "Bear", "Neutral"
    
    // Funnel Stats
    let candidatesFound: Int
    let shortlistCount: Int
    let verifiedCount: Int
    let sentCount: Int
    
    // Cost Stats
    let budgetUsed: Int
    let budgetLimit: Int
    let stoppedByBudget: Bool
    
    // Detail
    let logs: [String]
    let errors: [String]
    let sentSymbols: [String]
}
