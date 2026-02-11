import Foundation
import Combine

// Placeholder for App Group ID - User needs to replace this
let APP_GROUP_ID = "group.com.yourcompany.argus"

/// Central Shared Storage for Argus Terminal (App + Widget + Lab)
/// Uses UserDefaults with App Group Suite for sharing data between App and Widget.
class ArgusStorage: ObservableObject {
    static let shared = ArgusStorage()
    
    private let defaults: UserDefaults?
    
    // In-memory cache for fast access
    @Published var config: WidgetConfig?
    @Published var portfolio: [Trade] = []
    @Published var labEvents: [ArgusDecisionLogEntry] = []
    
    private init() {
        self.defaults = UserDefaults(suiteName: APP_GROUP_ID)
        
        // Initial Load
        self.config = loadWidgetConfig()
        self.portfolio = loadPortfolio()
        self.labEvents = loadLabEvents()
        
        // Load Unified Events (v2)
        self.unifiedEvents = load(key: "argus_unified_lab_events") ?? []
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
    
    // MARK: - 4. Argus Lab Events
    
    func appendLabEvent(_ event: ArgusDecisionLogEntry) {
        // De-duplication Logic (Simple time window check)
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 3600)
        let exists = labEvents.contains { 
            $0.symbol == event.symbol && 
            $0.mode == event.mode && 
            $0.timestamp > twelveHoursAgo 
        }
        
        if !exists {
            var currentEvents = loadLabEvents()
            currentEvents.append(event)
            // Limit size? Maybe keep last 1000?
            if currentEvents.count > 1000 { currentEvents.removeFirst(currentEvents.count - 1000) }
            
            save(currentEvents, key: "argus_lab_events")
            self.labEvents = currentEvents
            print("✅ ArgusStorage: Logged Lab Event for \(event.symbol)")
        }
    }
    
    func updateLabEvent(_ event: ArgusDecisionLogEntry) {
        var currentEvents = loadLabEvents()
        if let index = currentEvents.firstIndex(where: { $0.id == event.id }) {
            currentEvents[index] = event
            save(currentEvents, key: "argus_lab_events")
            self.labEvents = currentEvents
        }
    }
    
    func loadLabEvents() -> [ArgusDecisionLogEntry] {
        return load(key: "argus_lab_events") ?? []
    }
    
    // MARK: - 5. Unified Argus Lab System (v2)
    
    // In-memory cache for v2 events
    @Published var unifiedEvents: [ArgusLabEvent] = []
    
    func loadUnifiedEvents() -> [ArgusLabEvent] {
        // If memory is empty, try to load? Or rely on init?
        // We rely on Init loading it once.
        return self.unifiedEvents
    }
    
    func appendUnifiedEvent(_ event: ArgusLabEvent) {
        self.unifiedEvents.append(event)
        
        // Limit size (Keep last 2000)
        if self.unifiedEvents.count > 2000 { 
            self.unifiedEvents.removeFirst(self.unifiedEvents.count - 2000) 
        }
        
        // Async Background Save
        persistUnifiedEvents()
        print("✅ ArgusStorage: Logged Unified Event for \(event.algoId) - \(event.symbol)")
    }
    
    func updateUnifiedEvent(_ event: ArgusLabEvent) {
        if let index = self.unifiedEvents.firstIndex(where: { $0.id == event.id }) {
            self.unifiedEvents[index] = event
            persistUnifiedEvents()
        }
    }
    
    /// Batch Update (Prevents O(N^2) save loops)
    func updateUnifiedEventsBatch(_ updates: [ArgusLabEvent]) {
        var changed = false
        for event in updates {
            if let index = self.unifiedEvents.firstIndex(where: { $0.id == event.id }) {
                self.unifiedEvents[index] = event
                changed = true
            }
        }
        
        if changed {
            persistUnifiedEvents()
            print("✅ ArgusStorage: Batch Updated \(updates.count) Unified Events")
        }
    }
    
    // Helper to persist current state to background
    private func persistUnifiedEvents() {
        let eventsSnapshot = self.unifiedEvents
        Task {
            await ArgusDataStore.shared.save(eventsSnapshot, key: "argus_unified_lab_events")
        }
    }
    
    func getEvents(for algoId: String) -> [ArgusLabEvent] {
         // Filter from memory (Fast)
        return self.unifiedEvents.filter { $0.algoId == algoId }
    }
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
