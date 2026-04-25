import Foundation

/// Adapter to allow existing MarketDataProvider/EODHD logic to function as a Priority Provider within the Fallback System.
final class EODHDProviderAdapter: FallbackDataProvider {
    let name = "EODHD (Primary)"
    
    // Reference to native provider
    private let provider = EODHDProvider.shared
    
    func supports(symbol: String, field: DataField) -> Bool {
        // EODHD supports almost everything except maybe specific Crypto percent changes if not computed
        // But for "Last Price" etc it works.
        switch field {
        case .btcDailyChangePercent, .ethDailyChangePercent:
             return true
        default:
             return true
        }
    }
    
    func fetch(field: DataField, for symbol: String) async throws -> DataFieldValue {
        // Map DataField to legacy calls
        
        switch field {
        case .lastPrice, .btcPrice, .ethPrice, .goldPrice:
             let quote = try await provider.fetchQuote(symbol: symbol)
             return .quote(quote)
             
        case .previousClose:
             let quote = try await provider.fetchQuote(symbol: symbol)
             // Derive Previous Close from Price - Change
             let prev = quote.currentPrice - quote.change
             return .double(prev)
             
        // Special Logic for Change Percent (Aether Crypto)
        case .btcDailyChangePercent, .ethDailyChangePercent:
             // Try getting Quote first
             if let quote = try? await provider.fetchQuote(symbol: symbol) {
                 return .double(quote.percentChange)
             }
             // Fallback to fetchCandles if Quote lacks percent
             // EODHD Candles call: Use outputSize=30 instead of range
             if let candles = try? await provider.fetchCandles(symbol: symbol, timeframe: "d", limit: 30) { 
                 if let last = candles.last, let prev = candles.dropLast().last {
                     let pct = ((last.close - prev.close) / prev.close) * 100.0
                     return .double(pct)
                 }
             }
             throw DataFallbackError.invalidData
             
        default:
             throw DataFallbackError.notSupported
        }
    }
}
