import Foundation
import WidgetKit

// MARK: - Shared Models

struct WidgetAetherData: Codable {
    let score: Double // 0-100
    let regime: String // "Risk-On", "Risk-Off", etc.
    let summary: String // "Makro hava: Savunmacı..."
    let lastUpdated: Date
    
    // Mini metrics
    let spyChange: Double
    let vixValue: Double
    let gldChange: Double
    let btcChange: Double
}

struct WidgetPortfolioData: Codable {
    let totalEquity: Double
    let totalPnL: Double
    let dayPnLPercent: Double
    
    // Auto-Pilot
    let isAutoPilotActive: Bool
    let autoPilotWinRate: Double // e.g., 65.0
    
    // Last Action
    let lastActionTitle: String? // "TSLA • AL • 3 ad"
    let topSignalTitle: String? // "GÜÇLÜ AL: NVDA (82)"
    
    let lastUpdated: Date
}

// MARK: - Data Service

final class WidgetDataService: Sendable {
    static let shared = WidgetDataService()
    
    // Using UserDefaults for simplicity as App Group setup might be complex in this env.
    // In a real app with App Group capability enabled:
    // private let defaults = UserDefaults(suiteName: "group.com.argusterminal")
    // For now, standard defaults works if Widget and App are in same sandbox (not possible usually),
    // BUT since we are replacing the widget code entirely, we'll try to use a specific suite name
    // hoping the user has App Groups configured, or fallback to standard.
    // IF standard defaults doesn't work for Widget, we'd need file sharing.
    // Let's stick to standard `UserDefaults(suiteName: ...)` pattern as requested.
    
    private let suiteName = "group.com.argusterminal"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    private let aetherKey = "widget_aether_data"
    private let portfolioKey = "widget_portfolio_data"
    
    private init() {}
    
    // MARK: - Write
    
    func saveAether(data: WidgetAetherData) {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults?.set(encoded, forKey: aetherKey)
            // defaults?.synchronize() // Not needed in newer iOS but good for safety
            WidgetCenter.shared.reloadAllTimelines()
            print("✅ WidgetDataService: Aether data saved.")
        }
    }
    
    func savePortfolio(data: WidgetPortfolioData) {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults?.set(encoded, forKey: portfolioKey)
            WidgetCenter.shared.reloadAllTimelines()
            print("✅ WidgetDataService: Portfolio data saved.")
        }
    }
    
    // MARK: - Read
    
    func loadAether() -> WidgetAetherData? {
        guard let data = defaults?.data(forKey: aetherKey) else { return nil }
        return try? JSONDecoder().decode(WidgetAetherData.self, from: data)
    }
    
    func loadPortfolio() -> WidgetPortfolioData? {
        guard let data = defaults?.data(forKey: portfolioKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPortfolioData.self, from: data)
    }
}
