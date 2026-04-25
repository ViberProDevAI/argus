import Foundation
import Combine

/// Where did this symbol come from?
enum UniverseSource: String, Codable, CaseIterable {
    case watchlist = "Watchlist"
    case manual = "Manual"      // User searched explicitly
    case scout = "Scout"        // Discovered by Market Scanner
    case safe = "SafeList"      // Standard Safe Assets
    case portfolio = "Portfolio" // Currently held
    case strategy = "Strategy"  // Suggestion from specific strategy (e.g. Phoenix)
}

struct UniverseItem: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    var sources: Set<UniverseSource>
    let firstSeenAt: Date
    var lastSeenAt: Date
    var lastAnalyzedAt: Date?
    var tags: Set<String>
    var isActive: Bool
    
    // Derived: Is this a "High Priority" item?
    var isPriority: Bool {
        return sources.contains(.portfolio) || sources.contains(.watchlist) || sources.contains(.manual)
    }
}

/// The "Grand Registrar" of all symbols Argus knows about.
/// Unifies Watchlist, Scout, Portfolio, and Manual entries into one coherent list.
actor UniverseEngine: ObservableObject {
    @MainActor static let shared = UniverseEngine()
    
    // State
    @MainActor @Published var universe: [String: UniverseItem] = [:]
    
    // Persistence
    private let storeKey = "Argus_Universe_V1"
    
    // Dependencies (Weakly held or observed usually, but here we might push/pull)
    
    @MainActor
    private init() {
        load()
    }
    
    // MARK: - Registration API
    
    @MainActor
    func register(symbol: String, source: UniverseSource, tags: Set<String> = []) {
        var item = universe[symbol] ?? UniverseItem(
            symbol: symbol,
            sources: [],
            firstSeenAt: Date(),
            lastSeenAt: Date(),
            lastAnalyzedAt: nil,
            tags: [],
            isActive: true
        )
        
        // Update Metadata
        item.sources.insert(source)
        item.lastSeenAt = Date()
        item.isActive = true // Revive if it was inactive
        if !tags.isEmpty {
            item.tags.formUnion(tags)
        }
        
        universe[symbol] = item
        save()
        
        print("🌌 Universe: Registered \(symbol) from \(source.rawValue)")
    }
    
    @MainActor
    func deregister(symbol: String, source: UniverseSource) {
        guard var item = universe[symbol] else { return }
        
        item.sources.remove(source)
        
        // If no sources left, mark inactive (Don't delete, keep history)
        // OR if source was the ONLY reason to track it.
        if item.sources.isEmpty {
            item.isActive = false
        }
        
        universe[symbol] = item
        save()
    }
    
    @MainActor
    func markAnalyzed(symbol: String) {
        guard var item = universe[symbol] else { return }
        item.lastAnalyzedAt = Date()
        universe[symbol] = item
        // Don't save every analysis timestamp to disk to avoid thrashing, 
        // or debounce it. For now, we save.
        save()
    }
    
    // MARK: - Queries
    
    @MainActor
    func getActiveUniverse() -> [String] {
        return universe.values.filter { $0.isActive }.map { $0.symbol }
    }
    
    @MainActor
    func getCandidates(for source: UniverseSource) -> [String] {
        return universe.values.filter { $0.isActive && $0.sources.contains(source) }.map { $0.symbol }
    }
    
    @MainActor
    func getPrimarySource(for symbol: String) -> UniverseSource? {
        guard let item = universe[symbol] else { return nil }
        
        if item.sources.contains(.portfolio) { return .portfolio }
        if item.sources.contains(.watchlist) { return .watchlist }
        if item.sources.contains(.scout) { return .scout }
        if item.sources.contains(.strategy) { return .strategy }
        if item.sources.contains(.manual) { return .manual }
        return item.sources.first
    }
    
    @MainActor
    func getReason(for symbol: String) -> String {
        guard let item = universe[symbol] else { return "Unknown" }
        return item.sources.map { $0.rawValue }.joined(separator: ", ")
    }
    
    // MARK: - Persistence
    
    @MainActor
    private func save() {
        if let data = try? JSONEncoder().encode(universe) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
    
    @MainActor
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([String: UniverseItem].self, from: data) {
            self.universe = decoded
        }
    }
    
    // MARK: - Integration Helpers (Sync with Legacy Stores)
    
    @MainActor
    func syncFromWatchlist(_ symbols: [String]) {
        // 1. Register current
        for s in symbols {
            register(symbol: s, source: .watchlist)
        }
        
        // 2. Deregister removed (Advanced: Check diff)
        // For simplicity, we assume this is called on change.
        // Finding removed items requires knowing previous state of watchlist source.
        // We can filter universe for .watchlist items NOT in symbols list.
        for item in universe.values where item.sources.contains(.watchlist) {
            if !symbols.contains(item.symbol) {
                deregister(symbol: item.symbol, source: .watchlist)
            }
        }
    }
}
