import Foundation

// MARK: - FAZ 3: Service Protocols
// Protocol-based abstraction for testability and DI

/// Market data fetching protocol
protocol MarketDataProviding: Sendable {
    func fetchQuote(symbol: String) async throws -> Quote?
    func fetchCandles(symbol: String, timeframe: String) async throws -> [Candle]
}

/// Fundamental data protocol
protocol FundamentalsProviding {
    func getScore(for symbol: String) -> FundamentalScoreResult?
    func calculateScore(data: FinancialsData, riskScore: Double?) -> FundamentalScoreResult?
}

/// Orion technical analysis protocol
protocol OrionAnalyzing {
    func calculateOrionScore(symbol: String, candles: [Candle], spyCandles: [Candle]?) -> OrionScoreResult?
}

// MARK: - Faz 2 Ek Protokoller

/// Aether macro analysis protocol
protocol AetherAnalyzing {
    func evaluate() async -> MacroEnvironmentRating?
    func getCachedRating() -> MacroEnvironmentRating?
}

/// Cache management protocol
protocol CacheManaging {
    func get<T>(_ key: String) -> T?
    func set<T>(_ key: String, value: T, ttl: TimeInterval)
    func invalidate(_ key: String)
    func invalidateAll()
}

/// Portfolio management protocol
protocol PortfolioManaging: AnyObject {
    var portfolio: [Trade] { get }
    var balance: Double { get }
    var bistBalance: Double { get }
    
    func buy(symbol: String, quantity: Double, source: TradeSource, engine: AutoPilotEngine?) async throws
    func sell(symbol: String, quantity: Double, source: TradeSource, reason: String?) async throws
    func getEquity() -> Double
    func getBistEquity() -> Double
}

/// Watchlist management protocol
protocol WatchlistManaging: AnyObject {
    var watchlist: [String] { get set }
    
    func add(_ symbol: String)
    func remove(_ symbol: String)
    func contains(_ symbol: String) -> Bool
}

/// AutoPilot coordination protocol
protocol AutoPilotCoordinating: AnyObject {
    var isEnabled: Bool { get set }
    
    func start()
    func stop()
    func evaluateSignals() async
}

/// Notification management protocol
protocol NotificationManaging {
    func sendNotification(title: String, body: String, category: String?)
    func scheduleNotification(title: String, body: String, at date: Date)
}

/// Data persistence protocol
protocol DataPersisting {
    func save<T: Encodable>(_ value: T, forKey key: String) throws
    func load<T: Decodable>(forKey key: String) throws -> T?
    func delete(forKey key: String)
}
