import Foundation

struct TradingGuardsConfig: Codable {
    static let defaults = TradingGuardsConfig()
    static let shared = TradingGuardsConfig() // Fix for 'shared' access
    
    var maxDailyTrades: Int = 25
    var maxRiskScoreForBuy: Double = 20.0 // Minimum Safety Score (0-100)
    var portfolioConcentrationLimit: Double = 0.25 // Max 25% in one sector
    
    // Churn Configs
    var minTimeBetweenTradesSameSymbol: TimeInterval = 300 // 5 min
    var manualOverrideDuration: TimeInterval = 86400 // 24h
    var cooldownPulse: TimeInterval = 300 // 5m
    var cooldownCorse: TimeInterval = 2700 // 45m
    var minHoldCorse: TimeInterval = 3600 // 1h
    var minHoldTime: TimeInterval = 3600 // 1h (Generic)
    var decisionV2Enabled: Bool = true
    var cooldownAfterSell: TimeInterval = 1800 // 30m
    var reEntryWindow: TimeInterval = 3600
    var reEntryThreshold: Double = 75
}

struct LegalDocument: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct Certificate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}
