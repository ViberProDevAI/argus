import Foundation

// MARK: - Orion Technical Score (Legacy 2.0 - Deprecated but keeping usage in Aether/Macro wrappers if needed. Actually we are replacing it.)
// We will replace OrionTechScore usage with OrionComponentScores where possible, or if other modules (Poseidon?) rely on it, we might need a dummy.
// Investigating usage: Poseidon uses Orion? Unclear.
// Safe bet: Remove it, as we updated OrionAnalysisService.

// MARK: - Orion 3.0 Components
struct OrionComponentScores: Codable, Sendable {
    let trend: Double       // 0-25 (V2)
    let momentum: Double    // 0-25 (V2)
    let relativeStrength: Double // Merged into Trend or kept small? Kept separate for legacy compatibility for now.
    let structure: Double   // 0-35 (V2 NEW)
    let pattern: Double     // 0-15 (V2 NEW)
    let volatility: Double  // 0-15 (Legacy, maybe deprecated or merged)
    
    // Detailed Indicators for Voice/UI
    let rsi: Double?
    let macdHistogram: Double?
    
    // NEW: Chronos Legacy (Transferred to Orion)
    let trendAge: Int?          // How many days since SMA20 > SMA50 cross
    let trendStrength: Double?  // ADX or similar strength metric (0-100)
    let aroon: Double?          // Aroon Oscillator (-100 to +100)
    
    // Flags for missing data
    
    // Flags for missing data
    let isRsAvailable: Bool
    
    // Raw Descriptions for UI
    let trendDesc: String
    let momentumDesc: String
    let structureDesc: String
    let patternDesc: String
    let rsDesc: String
    let volDesc: String
    
    var total: Double {
        // V2 Total is weighted sum already normalized to 100 in Service, but if summing here:
        // Service calculates final. We store components.
        // Let's assume these sum to 100 approx.
        trend + momentum + structure + pattern
    }
}

// MARK: - Consensus Models (Signal Breakdown)
struct VoteCount: Codable, Sendable {
    var buy: Int
    var sell: Int
    var neutral: Int
    
    var total: Int { buy + sell + neutral }
    
    var dominant: String {
        if buy > sell && buy > neutral { return "AL" }
        if sell > buy && sell > neutral { return "SAT" }
        return "NÖTR"
    }
}

struct OrionSignalBreakdown: Codable, Sendable {
    let oscillators: VoteCount
    let movingAverages: VoteCount
    let summary: VoteCount
    
    // Detailed list for UI (Name, Action, Value)
    struct SignalItem: Codable, Sendable {
        let name: String
        let value: String
        let action: String // "AL", "SAT", "NÖTR"
    }
    
    let indicators: [SignalItem]
}

// MARK: - Orion 3.0 Result
struct OrionScoreResult: Codable, Sendable {
    let symbol: String
    let score: Double // 0-100 (Weighted/Normalized)
    let components: OrionComponentScores
    let signalBreakdown: OrionSignalBreakdown? // NEW: Consensus Details
    let verdict: String // "Strong Buy", "Wait", etc.
    let generatedAt: Date
}

// MARK: - Macro Environment (Aether)
enum MacroRegime: String, Codable {
    case riskOn = "Risk İştahı Yüksek"
    case neutral = "Nötr / Kararsız"
    case riskOff = "Riskten Kaçış"
    
    var displayName: String { rawValue }
}

struct MacroEnvironmentRating: Codable {
    let equityRiskScore: Double?
    let volatilityScore: Double?
    let safeHavenScore: Double?
    let cryptoRiskScore: Double?
    let interestRateScore: Double?
    let currencyScore: Double?
    
    // Aether 3.0 Resurrected Cards
    let inflationScore: Double?
    let laborScore: Double?
    let growthScore: Double?
    let creditSpreadScore: Double?  // NEW: HYG-LQD Credit Spread
    let claimsScore: Double?        // NEW: ICSA Initial Claims (Leading)
    
    // Aether v5: Category Scores (Raw Averages)
    let leadingScore: Double?       //  Öncü (VIX, Rates, Claims, BTC)
    let coincidentScore: Double?    //  Eşzamanlı (SPY, Payrolls, DXY)
    let laggingScore: Double?       //  Gecikmeli (CPI, Unemployment, Gold)
    
    // Aether v5: Weighted Contributions (for UI display)
    // Leading × 1.5 / 3.3, Coincident × 1.0 / 3.3, Lagging × 0.8 / 3.3
    let leadingContribution: Double?    // % contribution to final score
    let coincidentContribution: Double? // % contribution to final score
    let laggingContribution: Double?    // % contribution to final score
    
    let numericScore: Double
    let letterGrade: String
    let regime: MacroRegime
    let summary: String
    let details: String
    
    var multiplier: Double {
        return 0.60 + (numericScore / 100.0) * 0.50
    }
    
    // Status Metadata (STALE/OK/MISSING)
    var componentStatuses: [String: String] = [:]
    var componentDates: [String: Date] = [:]
    
    // Data Metadata (Change %)
    var componentChanges: [String: Double] = [:]
    
    var missingComponents: [String] = []
}

// MARK: - Orion Mode
enum OrionMode: String, Codable {
    case full = "Full"
    case lite = "Lite"
    case bare = "Bare"
}

// MARK: - Trade Setup
struct TradeSetup: Codable {
    let entryZone: String
    let stopLoss: Double
    let takeProfit1: Double
    let takeProfit2: Double
    let takeProfit3: Double
    let rrRatio: Double
    let stopDistancePct: Double
}
