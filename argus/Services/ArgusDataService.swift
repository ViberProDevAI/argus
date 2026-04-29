import Foundation

/// Basit Veri Servisi - Heimdall yerine doğrudan Yahoo Finance kullanır
/// Tüm veri çekme işlemleri buradan yapılır
@MainActor
final class ArgusDataService {
    static let shared = ArgusDataService()
    
    private let yahoo = YahooFinanceProvider.shared
    private let fred = FredProvider.shared
    
    private init() {
        print("📡 ArgusDataService: Başlatıldı (Yahoo Direct Mode)")
    }
    
    // MARK: - Quote
    
    func fetchQuote(symbol: String) async throws -> Quote {
        print("📡 Quote: \(symbol)")
        return try await yahoo.fetchQuote(symbol: symbol)
    }
    
    /// Phase 6 PR-A (2026-04-29): `fetchQuotes(symbols:)` silindi (orphan'dı).
    /// Batch quote artık `MarketDataStore.refreshQuotes(symbols:)` →
    /// `HeimdallOrchestrator.requestQuotesBatch(symbols:)` yolu üzerinden
    /// canonical akışla çalışır. Tek source-of-truth.
    
    // MARK: - Candles
    
    func fetchCandles(symbol: String, timeframe: String = "1D", limit: Int = 200) async throws -> [Candle] {
        print("📡 Candles: \(symbol) (\(timeframe), \(limit) bar)")
        return try await yahoo.fetchCandles(symbol: symbol, timeframe: timeframe, limit: limit)
    }
    
    // MARK: - Fundamentals
    
    func fetchFundamentals(symbol: String) async throws -> FinancialsData {
        print("📡 Fundamentals: \(symbol)")
        return try await yahoo.fetchFundamentals(symbol: symbol)
    }
    
    // MARK: - News
    
    func fetchNews(symbol: String, limit: Int = 10) async throws -> [NewsArticle] {
        print("📡 News: \(symbol)")
        
        // BIST için RSS kullan
        if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
            let rss = RSSNewsProvider()
            return try await rss.fetchNews(symbol: symbol, limit: limit)
        }
        
        // Global için Yahoo
        return try await yahoo.fetchNews(symbol: symbol)
    }
    
    // MARK: - Screener
    
    func fetchScreener(type: ScreenerType, limit: Int = 10) async throws -> [Quote] {
        print("📡 Screener: \(type)")
        return try await yahoo.fetchScreener(type: type, limit: limit)
    }
    
    // MARK: - Macro (FRED)
    
    func fetchFredSeries(seriesId: String, limit: Int = 24) async throws -> [(Date, Double)] {
        print("📡 FRED: \(seriesId)")
        return try await fred.fetchSeries(seriesId: seriesId, limit: limit)
    }
    
    // MARK: - System Health
    
    func checkHealth() async -> Bool {
        do {
            _ = try await yahoo.fetchQuote(symbol: "SPY")
            return true
        } catch {
            return false
        }
    }
}
