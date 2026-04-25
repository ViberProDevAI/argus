import Foundation
import SwiftUI

// MARK: - FAZ 3: ServiceContainer
// Lightweight Dependency Injection container for the app

/// Central service container providing access to all services.
/// Uses lazy initialization to avoid startup overhead.
@MainActor
final class ServiceContainer {
    
    // MARK: - Singleton (Production)
    static let shared = ServiceContainer()
    
    // MARK: - Services (Lazy Loaded - Concrete Types)
    // Protocol abstraction yerine concrete type kullanıyoruz 
    // çünkü mevcut servisler farklı signature'lar kullanıyor.
    // İleride refactor edilebilir.
    
    /// Market data provider
    lazy var marketData: MarketDataProvider = MarketDataProvider.shared
    
    /// Fundamental score store
    lazy var fundamentals: FundamentalScoreStore = FundamentalScoreStore.shared
    
    /// Orion technical analysis
    lazy var orion: OrionAnalysisService = OrionAnalysisService.shared
    
    /// Argus decision engine
    lazy var argus: ArgusDecisionEngine = ArgusDecisionEngine.shared
    
    /// Hermes news coordinator
    lazy var hermes: HermesCoordinator = HermesCoordinator.shared
    
    /// Macro regime evaluator
    lazy var macro: MacroRegimeService = MacroRegimeService.shared
    
    // MARK: - Data Stores
    
    /// Central market data store (SSoT)
    var dataStore: MarketDataStore { MarketDataStore.shared }
    
    // MARK: - Init
    
    private init() {
        // Production init - uses real services
        // Test init için özel mock servisleri ileride eklenecek
    }
}

// MARK: - Environment Key

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

extension MarketDataProvider: MarketDataProviding {
    func fetchQuote(symbol: String) async throws -> Quote? {
        let dataValue = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        return dataValue.value
    }
    
    func fetchCandles(symbol: String, timeframe: String) async throws -> [Candle] {
        let dataValue = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: timeframe)
        return dataValue.value ?? []
    }
}

extension FundamentalScoreStore: FundamentalsProviding {
    func calculateScore(data: FinancialsData, riskScore: Double?) -> FundamentalScoreResult? {
        return FundamentalScoreEngine.shared.calculate(data: data, riskScore: riskScore)
    }
}

extension OrionAnalysisService: OrionAnalyzing {
    // Already conforms - calculateOrionScore exists
}

// Note: ArgusDecisionEngine, HermesCoordinator, MacroRegimeService
// zaten protokollere uyumlu - signature'ları mevcut metodlarla eşleşiyor
