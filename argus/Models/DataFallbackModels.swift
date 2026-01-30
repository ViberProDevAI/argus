import Foundation

// MARK: - 1. Data Field Enum
/// Represents specific data fields required by Argus modules.
enum DataField: Sendable {
    // Market Data
    case lastPrice
    case previousClose
    case ohlcDaily
    case intradayCandles
    case volume
    case marketCap
    
    // Macro / Indicators
    case vixValue
    case bondYield10Y
    case bondYield2Y
    case goldPrice
    
    // Crypto
    case btcPrice
    case ethPrice
    case btcDailyChangePercent
    case ethDailyChangePercent
    
    // Add more as needed
}

// MARK: - 2. Data Field Value
/// A flexible wrapper for returning different types of data.
enum DataFieldValue: Sendable {
    case double(Double)
    case quote(Quote)
    case candles([Candle])
    // Add others if needed
    
    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .quote(let q): return q.currentPrice
        default: return nil
        }
    }
}

// MARK: - 3. Data Provider Protocol
/// Protocol for any service that can provide market data.
protocol FallbackDataProvider: Sendable {
    var name: String { get }
    
    /// Checks if this provider supports the given symbol and field.
    func supports(symbol: String, field: DataField) -> Bool
    
    /// Fetches the requested field.
    /// Throws error if fetch fails or data is invalid.
    func fetch(field: DataField, for symbol: String) async throws -> DataFieldValue
}

// MARK: - Errors
enum DataFallbackError: Error {
    case notSupported
    case invalidData
    case networkError(String)
    case noProviderForField
}
