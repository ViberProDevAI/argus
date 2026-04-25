import Foundation

// MARK: - Yahoo Finance Adapter
// YahooFinanceProvider'ı MarketDataAdapter'a uyarlayan wrapper

final class YahooAdapter: MarketDataAdapter, @unchecked Sendable {
    
    // MARK: - Properties
    let name = "Yahoo Finance"
    
    let capabilities: ProviderCapabilities = [
        .quotes, .candles, .search,
        .usStocks, .bistStocks, .forex, .crypto, .etfs, .indices, .commodities
    ]
    
    let priority = 10 // En yüksek öncelik (düşük sayı)
    
    // MARK: - Private
    private let provider = YahooFinanceProvider.shared
    
    // MARK: - Health Check
    func getHealth() async -> ProviderHealth {
        // Basit health check - son başarılı istek
        return ProviderHealth(
            status: .available,
            lastCheck: Date(),
            errorCount: 0,
            avgResponseMs: 250,
            remainingQuota: nil // Yahoo'da quota yok
        )
    }
    
    // MARK: - Quote
    func fetchQuote(symbol: String) async throws -> StandardQuote {
        let quote = try await provider.fetchQuote(symbol: symbol)
        
        return StandardQuote(
            symbol: quote.symbol ?? symbol,
            price: quote.currentPrice,
            change: quote.change,
            changePercent: quote.percentChange,
            volume: quote.volume ?? 0,
            timestamp: Date(),
            source: name
        )
    }
    
    // MARK: - Candles
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [StandardCandle] {
        let candles = try await provider.fetchCandles(
            symbol: symbol,
            interval: timeframe,
            outputSize: limit
        )
        
        return candles.map { candle in
            StandardCandle(
                date: candle.date,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: candle.volume,
                source: name
            )
        }
    }
    
    // MARK: - Search
    func searchSymbols(query: String) async throws -> [SearchResult] {
        // YahooFinanceProvider'da searchSymbols yoksa MarketDataProvider kullan
        return try await MarketDataProvider.shared.searchSymbols(query: query)
    }
}

