import Foundation

struct TradingGuardsConfig: Codable {
    static let defaults = TradingGuardsConfig()
    static let shared = TradingGuardsConfig() // Fix for 'shared' access
    
    var maxDailyTrades: Int = 25
    var maxRiskScoreForBuy: Double = 20.0 // Minimum Safety Score (0-100)
    var portfolioConcentrationLimit: Double = 0.25 // Max 25% in one sector
    
    // Churn Configs
    //
    // Cooldown gevşetmesi: Eski değerler (5 min/1 h/30 m) hızlı scalp fırsatlarını
    // boğuyordu; rally sırasında mikro geri çekilmelerde çıkış + yeniden giriş
    // engelleniyordu. Yeni değerler anti-churn güvencesini koruyarak tepki süresini
    // agresifleştirir. Kullanıcı Settings ekranından override edebilir.
    var minTimeBetweenTradesSameSymbol: TimeInterval = 60   // 1 min (was 5 min)
    var manualOverrideDuration: TimeInterval = 86400        // 24 h (unchanged)
    var cooldownPulse: TimeInterval = 60                    // 1 min (was 5 min) — scalp motoru
    var cooldownCorse: TimeInterval = 600                   // 10 min (was 45 min) — swing motoru
    var minHoldCorse: TimeInterval = 900                    // 15 min (was 1 h)
    var minHoldTime: TimeInterval = 300                     // 5 min (was 1 h) — generic
    var decisionV2Enabled: Bool = true
    var cooldownAfterSell: TimeInterval = 300               // 5 min (was 30 min) — re-entry hızlı
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
