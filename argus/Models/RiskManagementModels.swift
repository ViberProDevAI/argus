import Foundation

// MARK: - Portfolio Risk Management (v2.1)

struct PositionRecommendation: Codable, Identifiable {
    var id: UUID { recId }
    var recId = UUID()
    let symbol: String
    let computedAt: Date
    
    // Inputs (Snapshots)
    let currentPrice: Double
    let stopLoss: Double
    let accountEquity: Double
    let riskPerTradePct: Double // e.g. 1.0% or 2.0%
    
    // Calculations
    let riskAmount: Double       // $ Risk (Equity * Risk%)
    let riskPerShare: Double     // |Entry - Stop|
    let recommendedShares: Int   // Risk Amount / Risk Per Share
    let positionValue: Double    // Shares * Price
    let percentOfEquity: Double  // Position Value / Total Equity
    
    // Advanced (Kelly)
    let kellySuggestion: Double? // Suggested % of equity if Win Rate known
    
    // Warnings
    var warnings: [String] = []  // "Position > 20% of Portfolio!"
}

struct PortfolioSettings: Codable {
    var accountEquity: Double
    var riskPerTrade: Double // 1.0 = 1%
    var useKellyCriterion: Bool
    
    static let defaults = PortfolioSettings(accountEquity: 10000.0, riskPerTrade: 2.0, useKellyCriterion: false)
}
