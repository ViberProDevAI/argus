import Foundation

// MARK: - Macro Snapshot
// Real-world economic and market data for Grand Council decision making.

struct MacroSnapshot: Sendable, Codable {
    let timestamp: Date
    
    // Market Sentiment
    let vix: Double?                    // Fear index
    let fearGreedIndex: Double?         // CNN Fear & Greed (0-100)
    let putCallRatio: Double?
    
    // Fed & Rates
    let fedFundsRate: Double?
    let tenYearYield: Double?
    let twoYearYield: Double?
    let yieldCurveInverted: Bool
    
    // Market Breadth
    let advanceDeclineRatio: Double?    // NYSE A/D
    let percentAbove200MA: Double?      // % of stocks above 200MA
    let newHighsNewLows: Double?        // NH-NL difference
    
    // Economic
    let gdpGrowth: Double?
    let unemploymentRate: Double?
    let inflationRate: Double?
    let consumerConfidence: Double?
    
    // MARK: - Global Commodities & FX (for Sirkiye Engine)
    let dxy: Double?                    // US Dollar Index
    let brent: Double?                  // Brent Oil Price
    
    // Sector
    let sectorRotation: SectorRotationPhase?
    let leadingSectors: [String]
    let laggingSectors: [String]
    
    // Market Mode
    var marketMode: MarketMode {
        if let vix = vix {
            if vix > 30 { return .panic }
            if vix > 20 { return .fear }
            if vix < 12 { return .complacency }
        }
        if let fg = fearGreedIndex {
            if fg < 25 { return .extremeFear }
            if fg > 75 { return .extremeGreed }
        }
        return .neutral
    }
    
    static let empty = MacroSnapshot(
        timestamp: Date(),
        vix: nil, fearGreedIndex: nil, putCallRatio: nil,
        fedFundsRate: nil, tenYearYield: nil, twoYearYield: nil, yieldCurveInverted: false,
        advanceDeclineRatio: nil, percentAbove200MA: nil, newHighsNewLows: nil,
        gdpGrowth: nil, unemploymentRate: nil, inflationRate: nil, consumerConfidence: nil,
        dxy: nil, brent: nil,
        sectorRotation: nil, leadingSectors: [], laggingSectors: []
    )
}

enum MarketMode: String, Sendable, Codable {
    case panic = "PANİK"
    case extremeFear = "AŞIRI KORKU"
    case fear = "KORKU"
    case neutral = "NÖTR"
    case greed = "AÇGÖZLÜLÜK"
    case extremeGreed = "AŞIRI AÇGÖZLÜLÜK"
    case complacency = "REHAVET"
}

enum SectorRotationPhase: String, Codable, Sendable {
    case earlyExpansion = "Erken Genişleme"     // Financials, Tech lead
    case lateExpansion = "Geç Genişleme"        // Energy, Materials lead
    case earlyRecession = "Erken Resesyon"      // Utilities, Healthcare lead
    case lateRecession = "Geç Resesyon"         // Consumer Staples lead
}
