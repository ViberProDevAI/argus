import Foundation

protocol HeimdallProvider: AnyObject, Sendable {
    nonisolated var name: String { get }
    nonisolated var capabilities: [HeimdallDataField] { get }
    
    // Standard Fetch Methods (Returns Parsed Models or Throws)
    // Providers should implement only what they support.
    
    func fetchQuote(symbol: String) async throws -> Quote
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle]
    
    // Specialized Data
    func fetchFundamentals(symbol: String) async throws -> FinancialsData
    func fetchProfile(symbol: String) async throws -> AssetProfile
    func fetchNews(symbol: String) async throws -> [NewsArticle]
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator
    
    // Lists
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote]
        
    // Options
    func fetchOptions(symbol: String) async throws -> OptionsChain
}

enum ScreenerType: String, Sendable {
    case gainers = "DAY_GAINERS"
    case losers = "DAY_LOSERS"
    case mostActive = "MOST_ACTIVE"
    case etf = "TOP_ETFS"
}

// Default Implementations (Optional Support)
extension HeimdallProvider {
    func fetchFundamentals(symbol: String) async throws -> FinancialsData { throw URLError(.unsupportedURL) }
    func fetchProfile(symbol: String) async throws -> AssetProfile { throw URLError(.unsupportedURL) }
    func fetchNews(symbol: String) async throws -> [NewsArticle] { throw URLError(.unsupportedURL) }
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator { throw URLError(.unsupportedURL) }
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] { throw URLError(.unsupportedURL) }
    func fetchOptions(symbol: String) async throws -> OptionsChain { throw URLError(.unsupportedURL) }
}

struct AssetProfile: Codable {
    let symbol: String
    let name: String
    let sector: String?
    let industry: String?
    let marketCap: Double?
    let currency: String
    let isEtf: Bool
    let description: String?
    let domicile: String?
}
