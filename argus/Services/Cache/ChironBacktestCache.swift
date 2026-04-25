import Foundation

/// Synchronous bridge for ChironRegimeEngine to access backtest cache
/// This avoids async/await in the synchronous calculateAdaptiveWeights function
final class ChironBacktestCache {
    static let shared = ChironBacktestCache()
    
    private var orionWinRate: Double?
    private var phoenixWinRate: Double?
    private var lastSymbol: String?
    private var lastUpdate: Date?
    
    private init() {}
    
    // MARK: - Public API (Synchronous)
    
    func getOrionWinRate() -> Double? {
        return orionWinRate
    }
    
    func getPhoenixWinRate() -> Double? {
        return phoenixWinRate
    }
    
    func getCurrentSymbol() -> String? {
        return lastSymbol
    }
    
    // MARK: - Async Loading (Called from ViewModel/View)
    
    /// Load latest backtest results for a symbol into the synchronous cache
    @MainActor
    func loadFromCache(for symbol: String) async {
        guard let entry = await BacktestCacheService.shared.getCache(for: symbol) else {
            // Clear cache if no data
            clearCache()
            return
        }
        
        self.lastSymbol = symbol
        self.lastUpdate = entry.lastUpdated
        self.orionWinRate = entry.orion?.winRate
        self.phoenixWinRate = entry.phoenix?.winRate
        
        print("🧠 ChironBacktestCache: Loaded for \(symbol) - Orion: \(orionWinRate ?? 0)%, Phoenix: \(phoenixWinRate ?? 0)%")
    }
    
    /// Directly update cache from a fresh backtest result (Orion)
    func updateOrion(symbol: String, winRate: Double) {
        self.lastSymbol = symbol
        self.orionWinRate = winRate
        self.lastUpdate = Date()
    }
    
    /// Directly update cache from a fresh backtest result (Phoenix)
    func updatePhoenix(symbol: String, winRate: Double) {
        self.lastSymbol = symbol
        self.phoenixWinRate = winRate
        self.lastUpdate = Date()
    }
    
    func clearCache() {
        orionWinRate = nil
        phoenixWinRate = nil
        lastSymbol = nil
        lastUpdate = nil
    }
    
    /// Check if cache is stale (older than 1 hour for same symbol)
    func isStale(for symbol: String) -> Bool {
        guard let lastSymbol = lastSymbol, lastSymbol == symbol,
              let lastUpdate = lastUpdate else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) > 3600 // 1 hour
    }
}
