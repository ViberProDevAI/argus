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

// MARK: - Risk Escape Policy

enum RiskPolicyMode: String, Codable, Sendable {
    case normal = "NORMAL"
    case riskOff = "RISK_OFF"
    case deepRiskOff = "DEEP_RISK_OFF"
}

enum RiskUnwindAction: String, Codable, Sendable {
    case hold
    case trim
    case liquidate
}

struct RiskEscapePolicy: Codable, Sendable {
    let mode: RiskPolicyMode
    let aetherScore: Double
    let blockRiskyBuys: Bool
    let forceSafeOnlyBuys: Bool
    let minimumTrimPercent: Double
    let reason: String

    static func from(aetherScore: Double) -> RiskEscapePolicy {
        switch aetherScore {
        case ...RiskBudgetConfig.deepRiskOffMaxScore:
            return RiskEscapePolicy(
                mode: .deepRiskOff,
                aetherScore: aetherScore,
                blockRiskyBuys: true,
                forceSafeOnlyBuys: true,
                minimumTrimPercent: RiskBudgetConfig.deepRiskOffTrimPercent,
                reason: "Aether \(Int(aetherScore)) -> DEEP_RISK_OFF"
            )
        case ...RiskBudgetConfig.riskOffMaxScore:
            return RiskEscapePolicy(
                mode: .riskOff,
                aetherScore: aetherScore,
                blockRiskyBuys: true,
                forceSafeOnlyBuys: true,
                minimumTrimPercent: RiskBudgetConfig.riskOffTrimPercent,
                reason: "Aether \(Int(aetherScore)) -> RISK_OFF"
            )
        default:
            return RiskEscapePolicy(
                mode: .normal,
                aetherScore: aetherScore,
                blockRiskyBuys: false,
                forceSafeOnlyBuys: false,
                minimumTrimPercent: 0,
                reason: "Aether \(Int(aetherScore)) -> NORMAL"
            )
        }
    }
}

struct SafeAllocationOrder: Codable, Sendable {
    let symbol: String
    let amount: Double
    let type: SafeAssetType
    let reason: String
}
