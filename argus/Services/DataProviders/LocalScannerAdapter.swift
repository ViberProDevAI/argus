import Foundation

/// A self-contained adapter that acts as a Screener Provider.
/// It uses the local Watchlist and Discovery metrics to generate "Top Lists".
/// This ensures Phoenix never crashes even if Yahoo/EODHD are down.
actor LocalScannerAdapter: HeimdallProvider {
    static let shared = LocalScannerAdapter()
    let name: String = "LocalScanner"
    nonisolated let capabilities: [HeimdallDataField] = [.screener]
    
    // Dependencies
    
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] {
        // 1. Gather Universe from Watchlist
        let watchlistSymbols = await MainActor.run { ArgusStorage.shared.loadWatchlist() }
        
        // 2. Compute Metrics using stored Widget Data (Offline Cache)
        let widgetScores = await MainActor.run { ArgusStorage.shared.loadWidgetScores() }
        
        var candidates: [Quote] = []
        
        for symbol in watchlistSymbols {
            // Try Widget Cache first (Fastest, Offline)
            if let score = widgetScores[symbol] {
                candidates.append(Quote(
                    c: score.price,
                    d: 0.0,
                    dp: score.changePercent,
                    currency: "USD",
                    shortName: symbol,
                    symbol: symbol,
                    previousClose: score.price / (1.0 + (score.changePercent/100.0)),
                    volume: 0,
                    marketCap: nil,
                    peRatio: nil,
                    eps: nil,
                    sector: nil,
                    timestamp: score.lastUpdated
                ))
            }
        }
        
        guard !candidates.isEmpty else {
            throw HeimdallCoreError(category: .emptyPayload, code: 404, message: "No local matches", bodyPrefix: "Count: 0")
        }
        
        // 3. Sort by Type
        let sorted: [Quote]
        switch type {
        case .gainers:
            sorted = candidates.sorted { ($0.dp ?? 0) > ($1.dp ?? 0) }
        case .losers:
            sorted = candidates.sorted { ($0.dp ?? 0) < ($1.dp ?? 0) }
        case .mostActive:
            // No volume data in WidgetScore, return by volatility
             sorted = candidates.sorted { abs($0.dp ?? 0) > abs($1.dp ?? 0) }
        case .etf:
             sorted = candidates
        }
        
        return Array(sorted.prefix(limit))
    }
    
    // Stub other methods required by protocol if any
    // Stub other methods required by protocol if any
    func fetchQuote(symbol: String) async throws -> Quote { throw HeimdallCoreError(category: .entitlementDenied, code: 403, message: "Not available in Local Mode", bodyPrefix: "Screener Only") }
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] { throw HeimdallCoreError(category: .entitlementDenied, code: 501, message: "Not Supported", bodyPrefix: "") }
    // ...
}
