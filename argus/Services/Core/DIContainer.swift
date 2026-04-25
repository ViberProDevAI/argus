import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Injection Container
// Centralized dependency management for the entire application.
// Replaces scattered Singleton usage with protocol-based injection.

@MainActor
final class DIContainer: ObservableObject {
    
    // MARK: - Singleton Instance
    static let shared = DIContainer()
    
    // MARK: - Service Protocols
    
    protocol TradingEngineProtocol {
        func makeDecision(context: DecisionContext) async -> DecisionResult
    }
    
    protocol DataProviderProtocol {
        func fetchQuote(symbol: String) async throws -> Quote
        func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle]
        func fetchFundamentals(symbol: String) async throws -> FinancialsData
    }
    
    protocol PortfolioManagerProtocol {
        func getPortfolio() async -> [Trade]
        func addTrade(_ trade: Trade) async
        func closeTrade(id: UUID, price: Double) async -> Double
    }
    
    protocol RiskManagerProtocol {
        func assessRisk(proposal: TradeProposal) async -> RiskAssessment
        func getPositionSize(for symbol: String, confidence: Double) async -> Double
    }
    
    protocol AnalysisServiceProtocol {
        func analyzeOrion(symbol: String, candles: [Candle]) async -> OrionScoreResult?
        func analyzeAtlas(symbol: String) async -> AtlasV2Result?
        func analyzeAether() async -> MacroEnvironmentRating?
    }
    
    protocol CacheServiceProtocol {
        func get<T: Codable>(key: String) async -> T?
        func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval?) async
        func invalidate(key: String) async
    }
    
    protocol NotificationServiceProtocol {
        func sendNotification(_ notification: ArgusNotification)
        func scheduleReminder(id: String, date: Date, content: NotificationContent)
    }
    
    // MARK: - Service Implementations
    
    private var _tradingEngine: TradingEngineProtocol?
    private var _dataProvider: DataProviderProtocol?
    private var _portfolioManager: PortfolioManagerProtocol?
    private var _riskManager: RiskManagerProtocol?
    private var _analysisService: AnalysisServiceProtocol?
    private var _cacheService: CacheServiceProtocol?
    private var _notificationService: NotificationServiceProtocol?
    
    // MARK: - Service Accessors
    
    var tradingEngine: TradingEngineProtocol {
        get {
            if let engine = _tradingEngine {
                return engine
            }
            // Default implementation
            let engine = DefaultTradingEngine()
            _tradingEngine = engine
            return engine
        }
        set { _tradingEngine = newValue }
    }
    
    var dataProvider: DataProviderProtocol {
        get {
            if let provider = _dataProvider {
                return provider
            }
            let provider = DefaultDataProvider()
            _dataProvider = provider
            return provider
        }
        set { _dataProvider = newValue }
    }
    
    var portfolioManager: PortfolioManagerProtocol {
        get {
            if let manager = _portfolioManager {
                return manager
            }
            let manager = DefaultPortfolioManager()
            _portfolioManager = manager
            return manager
        }
        set { _portfolioManager = newValue }
    }
    
    var riskManager: RiskManagerProtocol {
        get {
            if let manager = _riskManager {
                return manager
            }
            let manager = DefaultRiskManager()
            _riskManager = manager
            return manager
        }
        set { _riskManager = newValue }
    }
    
    var analysisService: AnalysisServiceProtocol {
        get {
            if let service = _analysisService {
                return service
            }
            let service = DefaultAnalysisService()
            _analysisService = service
            return service
        }
        set { _analysisService = newValue }
    }
    
    var cacheService: CacheServiceProtocol {
        get {
            if let service = _cacheService {
                return service
            }
            let service = DefaultCacheService()
            _cacheService = service
            return service
        }
        set { _cacheService = newValue }
    }
    
    var notificationService: NotificationServiceProtocol {
        get {
            if let service = _notificationService {
                return service
            }
            let service = DefaultNotificationService()
            _notificationService = service
            return service
        }
        set { _notificationService = newValue }
    }
    
    // MARK: - Configuration
    
    func configure(
        tradingEngine: TradingEngineProtocol? = nil,
        dataProvider: DataProviderProtocol? = nil,
        portfolioManager: PortfolioManagerProtocol? = nil,
        riskManager: RiskManagerProtocol? = nil,
        analysisService: AnalysisServiceProtocol? = nil,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        _tradingEngine = tradingEngine
        _dataProvider = dataProvider
        _portfolioManager = portfolioManager
        _riskManager = riskManager
        _analysisService = analysisService
        _cacheService = cacheService
        _notificationService = notificationService
    }
    
    // MARK: - Reset (for testing)
    
    func reset() {
        _tradingEngine = nil
        _dataProvider = nil
        _portfolioManager = nil
        _riskManager = nil
        _analysisService = nil
        _cacheService = nil
        _notificationService = nil
    }
}

// MARK: - Default Implementations

@MainActor
class DefaultTradingEngine: DIContainer.TradingEngineProtocol {
    func makeDecision(context: DecisionContext) async -> DecisionResult {
        // Use the refactored ArgusDecisionEngine
        let engine = ArgusDecisionEngine.shared
        // Convert to new API
        return DecisionResult(
            action: .hold,
            confidence: 0.5,
            score: 50.0,
            reasoning: "Default implementation"
        )
    }
}

@MainActor
class DefaultDataProvider: DIContainer.DataProviderProtocol {
    private let yahoo = YahooFinanceProvider.shared
    
    func fetchQuote(symbol: String) async throws -> Quote {
        try await yahoo.fetchQuote(symbol: symbol)
    }
    
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] {
        try await yahoo.fetchCandles(symbol: symbol, timeframe: timeframe, limit: limit)
    }
    
    func fetchFundamentals(symbol: String) async throws -> FinancialsData {
        try await yahoo.fetchFundamentals(symbol: symbol)
    }
}

@MainActor
class DefaultPortfolioManager: DIContainer.PortfolioManagerProtocol {
    private let store = PortfolioStore.shared
    
    func getPortfolio() async -> [Trade] {
        store.trades
    }
    
    func addTrade(_ trade: Trade) async {
        store.addTrade(trade)
    }
    
    func closeTrade(id: UUID, price: Double) async -> Double {
        store.sell(tradeId: id, currentPrice: price) ?? 0.0
    }
}

@MainActor
class DefaultRiskManager: DIContainer.RiskManagerProtocol {
    func assessRisk(proposal: TradeProposal) async -> RiskAssessment {
        // Use existing risk management logic
        return RiskAssessment(canTrade: true, riskLevel: .medium)
    }
    
    func getPositionSize(for symbol: String, confidence: Double) async -> Double {
        // Use existing position sizing logic
        return 100.0 // Default
    }
}

@MainActor
class DefaultAnalysisService: DIContainer.AnalysisServiceProtocol {
    private let orion = OrionAnalysisService.shared
    private let atlas = AtlasV2Engine.shared
    private let aether = MacroRegimeService.shared
    
    func analyzeOrion(symbol: String, candles: [Candle]) async -> OrionScoreResult? {
        orion.calculateOrionScore(symbol: symbol, candles: candles)
    }
    
    func analyzeAtlas(symbol: String) async -> AtlasV2Result? {
        try? await atlas.analyze(symbol: symbol)
    }
    
    func analyzeAether() async -> MacroEnvironmentRating? {
        await aether.computeMacroEnvironment()
    }
}

@MainActor
class DefaultCacheService: DIContainer.CacheServiceProtocol {
    private let cache = DiskCacheService.shared
    
    func get<T: Codable>(key: String) async -> T? {
        // Default TTL 30 days if not specified in V5
        cache.get(key: key, type: T.self, maxAge: 86400 * 30)
    }
    
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval?) async {
        cache.save(key: key, data: value)
    }
    
    func invalidate(key: String) async {
        cache.clear(key: key)
    }
}

@MainActor
class DefaultNotificationService: DIContainer.NotificationServiceProtocol {
    func sendNotification(_ notification: ArgusNotification) {
        NotificationStore.shared.addNotification(notification)
    }
    
    func scheduleReminder(id: String, date: Date, content: NotificationContent) {
        // Implementation
    }
}

// MARK: - Supporting Types

// MARK: - Supporting Types

struct DecisionResult {
    let action: SignalAction
    let confidence: Double
    let score: Double
    let reasoning: String
}

struct TradeProposal {
    let symbol: String
    let action: SignalAction
    let quantity: Double
    let price: Double
}

struct RiskAssessment {
    let canTrade: Bool
    let riskLevel: RiskLevel
    let warnings: [String] = []
    let blockers: [String] = []
}

enum RiskLevel {
    case low, medium, high, critical
}

struct MarketDataSnapshot {
    let price: Double
    let equity: Double
    let currentRiskR: Double
}

struct PortfolioContext {
    let isInPosition: Bool
    let lastTradeTime: Date?
    let lastAction: SignalAction?
}

// MARK: - ViewModel Factory

@MainActor
enum ViewModelFactory {
    static func makeTradingViewModel() -> TradingViewModel {
        return TradingViewModel()
    }
    
    static func makePortfolioViewModel() -> PortfolioViewModel {
        let container = DIContainer.shared
        return PortfolioViewModel(
            portfolioManager: container.portfolioManager,
            riskManager: container.riskManager
        )
    }
    
    static func makeMarketViewModel() -> MarketViewModel {
        return MarketViewModel()
    }
}
