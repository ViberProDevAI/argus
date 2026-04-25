import Foundation
import Combine

// Placeholder for App Group ID - User needs to replace this
let APP_GROUP_ID = "group.com.yourcompany.argus"

/// Central Shared Storage for Argus Terminal (App + Widget)
/// Uses UserDefaults with App Group Suite for sharing data between App and Widget.
class ArgusStorage: ObservableObject {
    static let shared = ArgusStorage()

    private let defaults: UserDefaults?

    // In-memory cache for fast access
    @Published var config: WidgetConfig?
    @Published var portfolio: [Trade] = []

    private init() {
        self.defaults = UserDefaults(suiteName: APP_GROUP_ID)

        // Initial Load
        self.config = loadWidgetConfig()
        self.portfolio = loadPortfolio()

        // Lab system purge (2026-04-21): eski "argus_lab_events" ve
        // "argus_unified_lab_events" anahtarları temizleniyor.
        defaults?.removeObject(forKey: "argus_lab_events")
        defaults?.removeObject(forKey: "argus_unified_lab_events")
    }
    
    // MARK: - Generic Helpers
    
    private func save<T: Codable>(_ object: T, key: String) {
        guard let defaults = defaults else { return }
        if let data = try? JSONEncoder().encode(object) {
            defaults.set(data, forKey: key)
        }
    }
    
    private func load<T: Codable>(key: String) -> T? {
        guard let defaults = defaults,
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - 1. Widget Config
    
    func saveWidgetConfig(_ config: WidgetConfig) {
        self.config = config
        save(config, key: "argus_widget_config")
        // Notifying WidgetCenter would happen in ViewModel or via a callback if we imported WidgetKit here.
        // But we keep this service clean of UI/WidgetKit imports if possible, or we import WidgetKit only if available.
    }
    
    func loadWidgetConfig() -> WidgetConfig? {
        return load(key: "argus_widget_config")
    }
    
    // MARK: - 2. Portfolio & Watchlist
    
    func savePortfolio(_ trades: [Trade]) {
        self.portfolio = trades
        save(trades, key: "argus_portfolio")
    }
    
    func loadPortfolio() -> [Trade] {
        return load(key: "argus_portfolio") ?? []
    }
    
    func saveWatchlist(_ symbols: [String]) {
        defaults?.set(symbols, forKey: "argus_watchlist")
    }
    
    func loadWatchlist() -> [String] {
        return defaults?.stringArray(forKey: "argus_watchlist") ?? []
    }
    
    // MARK: - 3. Scores (For Widget)
    // We save a dictionary of [Symbol: MiniScore] to be lightweight
    
    func saveWidgetScores(scores: [String: WidgetScoreData]) {
        save(scores, key: "argus_widget_scores")
    }
    
    func loadWidgetScores() -> [String: WidgetScoreData] {
        return load(key: "argus_widget_scores") ?? [:]
    }
    
    // Lab system tamamen kaldırıldı (2026-04-21). Eski appendLabEvent/updateLabEvent/
    // appendUnifiedEvent/updateUnifiedEvent/getEvents(for:) API'leri silindi; çağıranlar
    // direkt silindi (Lab viewları/motorları da yok).
}
// MARK: - Shared Models

// Widget Configuration
struct WidgetConfig: Codable, Equatable {
    var symbols: [String] // Symbols to show in widget
    var showOrionBadge: Bool = true
    var lastUpdated: Date = Date()
}

// Leithweight Score Data for Widget (Decoupled from heavy models)
struct WidgetScoreData: Codable {
    let symbol: String
    let price: Double
    let changePercent: Double
    let signal: SignalAction // Buy/Sell/Hold
    let lastUpdated: Date
}
