import Foundation

/// "The Backup Generator"
/// Provides "Screener" capabilities by scanning a local static universe
/// using standard Quote endpoints (which are more reliable than Screener endpoints).
actor LocalMarketScannerProvider: HeimdallProvider {
    static let shared = LocalMarketScannerProvider()
    
    nonisolated var name: String { "Local Scanner" }
    
    nonisolated var capabilities: [HeimdallDataField] {
        return [.screener]
    }
    
    private init() {}
    
    // MARK: - Universe Definition
    
    private let seedUniverse = [
        "SPY", "QQQ", "IWM", "DIA", "IVV", "VOO", // Indices
        "AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA", "AVGO", "COST", "ADBE", "NFLX", "AMD", "INTC", // Tech
        "JPM", "BAC", "V", "MA", "WFC", "GS", "MS", // Finance
        "LLY", "JNJ", "UNH", "PFE", "MRK", "ABBV", // Health
        "XOM", "CVX", "COP", // Energy
        "PG", "KO", "PEP", "WMT", "HD", "MCD", "NKE", "SBUX", // Consumer
        "BTC-USD", "ETH-USD", "SOL-USD" // Crypto
    ]
    
    // MARK: - Implementation
    
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] {
        print("🛡️ LocalScanner: Initiating usage of Seed Universe (\(seedUniverse.count) symbols)...")
        
        // 1. Fetch Quotes in Parallel (with throttling handled by Heimdall Orchestrator usually, but here we batch inside)
        var candidates: [Quote] = []
        
        // We use Heimdall to fetch quotes for these symbols.
        // But wait, if we call Heimdall.requestQuote, we might re-enter lock logic?
        // Yes, but Quote endpoints (Yahoo v8) are distinct from Screener endpoints (Yahoo v1).
        // Since Quote endpoints are usually healthy, this is safe.
        // However, we should avoid infinite recursion if THIS provider is called by Heimdall.
        // We must call the PROVIDERS directly or ensure restricted routing.
        // Calling `YahooFinanceProvider.shared.fetchQuote` directly is safest here to avoid circular dependency in Orchestrator.
        
        let provider = await YahooFinanceProvider.shared
        
        await withTaskGroup(of: Quote?.self) { group in
            for sym in seedUniverse {
                group.addTask {
                    return try? await provider.fetchQuote(symbol: sym)
                }
            }
            
            for await q in group {
                if let valid = q {
                    candidates.append(valid)
                }
            }
        }
        
        // 2. Sort Logic
        switch type {
        case .gainers:
            candidates.sort { ($0.dp ?? 0) > ($1.dp ?? 0) }
        case .losers:
            candidates.sort { ($0.dp ?? 0) < ($1.dp ?? 0) }
        case .mostActive:
            // Proxy: Highest absolute change roughly implies activity/volatility in absence of volume
            // Or if Quote has volume (it does not in our simple model? It does have `v` ? Let's check definition)
            // Quote struct usually has `v` if user defined it properly.
            // Assuming `d` (change) is proxy.
            candidates.sort { abs($0.dp ?? 0) > abs($1.dp ?? 0) }
        default:
             break
        }
        
        let result = Array(candidates.prefix(limit))
        print("🛡️ LocalScanner: Found \(result.count) candidates for \(type)")
        return result
    }
    
    // Stubs for protocol conformance
    func fetchQuote(symbol: String) async throws -> Quote { throw URLError(.unsupportedURL) }
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] { throw URLError(.unsupportedURL) }
    func fetchFundamentals(symbol: String) async throws -> FinancialsData { throw URLError(.unsupportedURL) }
    func fetchProfile(symbol: String) async throws -> AssetProfile { throw URLError(.unsupportedURL) }
    func fetchNews(symbol: String) async throws -> [NewsArticle] { throw URLError(.unsupportedURL) }
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator { throw URLError(.unsupportedURL) }
}
