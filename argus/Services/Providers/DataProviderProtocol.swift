import Foundation

protocol DataProvider {
    var name: String { get }
    
    // Core Market Data
    func fetchQuote(symbol: String) async throws -> Quote
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle]
}

protocol FundamentalsProviderProtocol {
    func fetchFinancials(symbol: String) async throws -> FinancialsData
}

// Common Error Types
enum DataProviderError: Error {
    case resourceUnavailable
    case invalidResponse
    case rateLimited
    case networkError(Error)
    case unknown
}

struct SearchResult: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let description: String
}
