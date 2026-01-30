import Foundation

/// Decoupled sub-module for Yahoo Candle fetching
/// Responsible strictly for /v8/finance/chart parsing and normalizing.
actor YahooCandleAdapter {
    static let shared = YahooCandleAdapter()
    
    // Config
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    
    private init() {}
    
    /// Fetches candles with robust error handling for 502/HTML responses
    /// Returns: (Candles, SnapshotHash)
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> ([Candle], String) {
        // Use Builder for strict URL compliance
        let url = try YahooChartURLBuilder.build(symbol: symbol, timeframe: timeframe)
        
        let start = Date()
        
        // Use HeimdallNetwork for observability
        let data = try await HeimdallNetwork.request(
            url: url,
            engine: .market,
            provider: .yahoo,
            symbol: symbol
        )
        
        // HOOK-1: Data Snapshot
        let latency = Date().timeIntervalSince(start) * 1000
        let blobHash = ArgusLedger.shared.logDataSnapshot(
            symbol: symbol,
            type: "CANDLES_OHLCV",
            blobData: data,
            marketTime: nil,
            provider: "Yahoo",
            latencyMs: Int(latency)
        ) ?? "ERROR"
        
        let candles = try parseResponse(data, limit: limit)
        return (candles, blobHash)
    }
    
    private func parseResponse(_ data: Data, limit: Int) throws -> [Candle] {
        // 1. Detect HTML / Gateway Leakage (Strict)
        // Check first 64 bytes
        if let prefix = String(data: data.prefix(64), encoding: .utf8)?.lowercased() {
             if prefix.contains("<html") || prefix.contains("<!doctype") {
                 // CRITICAL: This is a server instability, not a data error.
                 throw HeimdallCoreError(category: .serverError, code: 502, message: "Yahoo returned HTML (Gateway/Auth)", bodyPrefix: "HTML Content")
             }
        }
        
        struct YChartResp: Codable {
            struct Chart: Codable {
                struct Result: Codable {
                    struct Indicators: Codable {
                        struct YQuote: Codable {
                            let open: [Double?]?
                            let high: [Double?]?
                            let low: [Double?]?
                            let close: [Double?]?
                            let volume: [Double?]?
                        }
                        let quote: [YQuote]
                    }
                    let timestamp: [Int]?
                    let indicators: Indicators
                }
                let result: [Result]?
                let error: YError?
            }
            struct YError: Codable {
                let code: String?
                let description: String?
            }
            let chart: Chart
        }
        
        // 2. Decode JSON
        let resp: YChartResp
        do {
            print("📦 YahooAdapter: Decoding \(data.count) bytes...")
            resp = try JSONDecoder().decode(YChartResp.self, from: data)
            print("✅ YahooAdapter: Decode Success")
        } catch {
             print("❌ YahooAdapter: JSON Decode Failed: \(error)")
             if let str = String(data: data, encoding: .utf8) {
                 print("Dump: \(str.prefix(500))")
             }
             // JSON Decode failed -> Likely garbage response -> Server Error
             throw HeimdallCoreError(category: .serverError, code: 500, message: "Yahoo JSON Decode Failed", bodyPrefix: "")
        }
        
        // 3. Handle Logical Errors
        if let err = resp.chart.error {
            // "Not Found" or "No data found" -> Symbol Scope (Not Critical)
            let desc = err.description ?? ""
            if desc.localizedCaseInsensitiveContains("Not Found") || desc.contains("No data found") {
                 throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "Symbol Not Found: \(desc)", bodyPrefix: "")
            }
            
            // Other API Errors -> Treat as Unavailable but not necessarily locking provider unless frequent
            throw HeimdallCoreError(category: .unknown, code: 400, message: "Yahoo Syntax Error: \(desc)", bodyPrefix: "")
        }
        
        // 4. Validate Data Presence
        guard let res = resp.chart.result?.first,
              let timestamps = res.timestamp,
              let quote = res.indicators.quote.first else {
            // Technically a 404 if result is null and no error
             throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "Yahoo Result Empty", bodyPrefix: "")
        }
        
        var candles: [Candle] = []
        let opens = quote.open ?? []
        let highs = quote.high ?? []
        let lows = quote.low ?? []
        let closes = quote.close ?? []
        let vols = quote.volume ?? []
        
        // ZIP logic
        for i in 0..<timestamps.count {
            if i < opens.count, let o = opens[i],
               i < highs.count, let h = highs[i],
               i < lows.count, let l = lows[i],
               i < closes.count, let c = closes[i] {
                
                let v = (i < vols.count ? vols[i] : 0) ?? 0
                let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                
                candles.append(Candle(
                    date: date,
                    open: o,
                    high: h,
                    low: l,
                    close: c,
                    volume: v
                ))
            }
        }
        // Tarihe göre sırala (eski → yeni) ve limit uygula
        // NOT: .reversed() KALDIRILDI - Yahoo zaten kronolojik döndürüyor!
        return Array(candles.suffix(limit))
    }
}
