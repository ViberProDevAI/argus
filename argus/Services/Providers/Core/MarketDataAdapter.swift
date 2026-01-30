import Foundation

// MARK: - FAZ 4: Provider Capabilities
// Her provider'ın hangi özellikleri desteklediğini belirler

/// Provider yetenekleri - hangi veri türlerini ve bölgeleri destekliyor
struct ProviderCapabilities: OptionSet, Sendable {
    let rawValue: Int
    
    // Data Types
    static let quotes = ProviderCapabilities(rawValue: 1 << 0)
    static let candles = ProviderCapabilities(rawValue: 1 << 1)
    static let fundamentals = ProviderCapabilities(rawValue: 1 << 2)
    static let news = ProviderCapabilities(rawValue: 1 << 3)
    static let search = ProviderCapabilities(rawValue: 1 << 4)
    static let streaming = ProviderCapabilities(rawValue: 1 << 5)
    
    // Markets
    static let usStocks = ProviderCapabilities(rawValue: 1 << 10)
    static let bistStocks = ProviderCapabilities(rawValue: 1 << 11)
    static let forex = ProviderCapabilities(rawValue: 1 << 12)
    static let crypto = ProviderCapabilities(rawValue: 1 << 13)
    static let etfs = ProviderCapabilities(rawValue: 1 << 14)
    static let indices = ProviderCapabilities(rawValue: 1 << 15)
    static let commodities = ProviderCapabilities(rawValue: 1 << 16)
    static let macro = ProviderCapabilities(rawValue: 1 << 17)
    
    // Bundles
    static let basicData: ProviderCapabilities = [.quotes, .candles, .search]
    static let fullStock: ProviderCapabilities = [.quotes, .candles, .fundamentals, .news, .search, .usStocks]
    static let allMarkets: ProviderCapabilities = [.usStocks, .bistStocks, .forex, .crypto, .etfs, .indices, .commodities]
}

/// Provider durumu
enum ProviderStatus: String, Sendable {
    case available = "OK"
    case rateLimited = "RATE_LIMITED"
    case unavailable = "UNAVAILABLE"
    case apiKeyMissing = "NO_API_KEY"
    case error = "ERROR"
}

/// Provider health bilgisi
struct ProviderHealth: Sendable {
    let status: ProviderStatus
    let lastCheck: Date
    let errorCount: Int
    let avgResponseMs: Double
    let remainingQuota: Int?
    
    var isHealthy: Bool {
        status == .available && errorCount < 3
    }
}

// MARK: - Standard Models
// Tüm provider'ların ortak çıktı formatı

/// Standart Quote - tüm provider'lar bu formata dönüştürür
struct StandardQuote: Sendable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Double
    let timestamp: Date
    let source: String
    
    // Provider'ın Quote tipine dönüşüm
    func toQuote() -> Quote {
        return Quote(
            c: price,
            d: change,
            dp: changePercent,
            currency: "USD",
            shortName: nil,
            symbol: symbol,
            volume: volume
        )
    }
}

/// Standart Candle - tüm provider'lar bu formata dönüştürür  
struct StandardCandle: Sendable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let source: String
    
    // Provider'ın Candle tipine dönüşüm
    func toCandle() -> Candle {
        return Candle(
            date: date,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )
    }
}

// MARK: - MarketDataAdapter Protocol
// Tüm data provider'ların uyması gereken adapter protokolü

/// Data Provider Adapter - standart interface
protocol MarketDataAdapter: Sendable {
    /// Provider adı
    var name: String { get }
    
    /// Provider yetenekleri
    var capabilities: ProviderCapabilities { get }
    
    /// Provider önceliği (düşük = daha öncelikli)
    var priority: Int { get }
    
    /// Provider sağlık durumu
    func getHealth() async -> ProviderHealth
    
    /// Quote çek
    func fetchQuote(symbol: String) async throws -> StandardQuote
    
    /// Candle'lar çek
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [StandardCandle]
    
    /// Sembol arama
    func searchSymbols(query: String) async throws -> [SearchResult]
}

// MARK: - Default Implementations
extension MarketDataAdapter {
    var priority: Int { 100 } // Varsayılan düşük öncelik
    
    func searchSymbols(query: String) async throws -> [SearchResult] {
        throw DataProviderError.resourceUnavailable
    }
}

// MARK: - Provider Registry
/// Aktif provider'ları yöneten kayıt defteri
@MainActor
final class ProviderRegistry {
    static let shared = ProviderRegistry()
    
    private var adapters: [any MarketDataAdapter] = []
    private var healthCache: [String: ProviderHealth] = [:]
    
    private init() {
        // Provider'ları kaydet (öncelik sırasına göre)
        // Not: Mevcut provider'lar adapter'a dönüştürülecek
    }
    
    /// Belirli capability için en iyi provider'ı bul
    func bestAdapter(for capability: ProviderCapabilities) -> (any MarketDataAdapter)? {
        return adapters
            .filter { $0.capabilities.contains(capability) }
            .sorted { $0.priority < $1.priority }
            .first
    }
    
    /// Tüm sağlıklı provider'ları getir
    func healthyAdapters() -> [any MarketDataAdapter] {
        return adapters.filter { adapter in
            healthCache[adapter.name]?.isHealthy ?? true
        }
    }
    
    /// Provider kaydet
    func register(_ adapter: any MarketDataAdapter) {
        adapters.append(adapter)
        adapters.sort { $0.priority < $1.priority }
    }
    
    /// Tüm provider'ların sağlığını kontrol et
    func checkHealth() async {
        for adapter in adapters {
            let health = await adapter.getHealth()
            healthCache[adapter.name] = health
        }
    }
}
