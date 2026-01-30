import Foundation

final class EODHDProvider: HeimdallProvider {
    static let shared = EODHDProvider()
    nonisolated var name: String { "EODHD" }
    
    nonisolated var capabilities: [HeimdallDataField] {
        return [.quote, .candles, .screener]
    }
    
    private let baseURL = "https://eodhd.com/api"

    // API Key'i güvenli şekilde Secrets'tan al
    private func getApiKey() async -> String {
        // Önce KeyStore'dan dene (Dinamik key yönetimi)
        if let key = APIKeyStore.shared.getKey(for: .eodhd), !key.isEmpty {
            return key
        }
        // Fallback: Secrets (Info.plist'ten)
        return Secrets.eodhdKey
    }
    
    func fetchQuote(symbol: String) async throws -> Quote {
        // Map symbol (e.g. AAPL -> AAPL.US, ARCLK -> ARCLK.IS)
        let mapped = mapSymbol(symbol)
        let key = await getApiKey()
        let urlString = "\(baseURL)/real-time/\(mapped)?api_token=\(key)&fmt=json"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Refactored to use HeimdallNetwork for global error handling (Rate Limit, Bans)
        let data = try await HeimdallNetwork.request(url: url, engine: .market, provider: .eodhd, symbol: symbol)
        
        // EODHD returns { "code": "AAPL.US", "close": 150.0, ... }
        struct EODRealTime: Codable {
            let close: Double
            let change: Double?
            let change_p: Double
            let code: String
        }
        
        // Custom Decoding for null safety
        // Note: EODHD sometimes returns slightly different keys or nulls
        // We use a lenient decoder strategy or manual if needed.
        // Re-using structure but ensuring change_p is handled if missing
        // EODRealTime struct definition above implies non-optional change_p in original code, 
        // but let's make it robust.
        struct EODRealTimeSafe: Codable {
            let close: Double
            let change: Double?
            let change_p: Double? // Changed to optional
            let code: String
        }

        do {
            let q = try JSONDecoder().decode(EODRealTimeSafe.self, from: data)
            return Quote(
                c: q.close,
                d: q.change ?? 0,
                dp: q.change_p ?? 0,
                currency: "USD",
                symbol: symbol // Use requested symbol
            )
        } catch {
            throw error
        }
    }
    
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] {
        return try await fetchCandles(symbol: symbol, interval: timeframe, outputSize: limit)
    }
    
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        // EOD EODHD...
        let mapped = mapSymbol(symbol)
        // Interval mapping: "1d" is default. EODHD supports 'period=d'
        var period = "d"
        if interval.contains("week") { period = "w" }
        if interval.contains("month") { period = "m" }
        
        if interval.contains("month") { period = "m" }
        
        let key = await getApiKey()
        let urlString = "\(baseURL)/eod/\(mapped)?api_token=\(key)&fmt=json&period=\(period)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Refactored: HeimdallNetwork handles 403, 429, and "Daily Limit" text check
        let data = try await HeimdallNetwork.request(url: url, engine: .market, provider: .eodhd, symbol: symbol)
        
        struct EODCandle: Codable {
            let date: String
            let open: Double?
            let high: Double?
            let low: Double?
            let close: Double?
            let volume: Double?
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Debugging / Observability
        do {
             let raw = try JSONDecoder().decode([EODCandle].self, from: data)
             let candles = raw.compactMap { r -> Candle? in
                guard let dStr = formatter.date(from: r.date), let c = r.close else { return nil }
                return Candle(
                    date: dStr,
                    open: r.open ?? c,
                    high: r.high ?? c,
                    low: r.low ?? c,
                    close: c,
                    volume: r.volume ?? 0.0
                )
            }
            return candles.suffix(outputSize)
        } catch {
             if let str = String(data: data, encoding: .utf8) {
                 print("🛑 EODHD Decode Error for \(symbol): \(error). Response: \(str.prefix(500))")
                 // Detect Common API Errors
                 if str.contains("Forbidden") || str.contains("Invalid Token") {
                     throw HeimdallCoreError(category: .authInvalid, code: 403, message: "EODHD Key Invalid/Expired", bodyPrefix: str)
                 }
             }
             throw error
        }
    }
    
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] {
        // EODHD Screener
        var sort = ""
        switch type {
        case .gainers: sort = "refund_1d_p.desc"
        case .losers:  sort = "refund_1d_p.asc"
        case .mostActive: sort = "volume.desc"
        default: sort = "refund_1d_p.desc"
        }
        

        
        let key = await getApiKey()
        let urlString = "https://eodhd.com/api/screener?api_token=\(key)&sort=\(sort)&filters=[[\"exchange\",\"=\",\"us\"]]&limit=\(limit)&fmt=json"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Refactored
        let data = try await HeimdallNetwork.request(url: url, engine: .phoenix, provider: .eodhd, symbol: "SCREENER")
        
        struct EODScreenerResponse: Codable {
            let data: [EODScreenerItem]
        }
        
        struct EODScreenerItem: Codable {
            let code: String
            let name: String?
            let close: Double?
            let refund_1d_p: Double? // Daily Change %
            let volume: Double?
        }
        
        do {
            let res = try JSONDecoder().decode(EODScreenerResponse.self, from: data)
            
            return res.data.map { item in
                Quote(
                    c: item.close ?? 0.0,
                    d: 0.0, // Abs change unknown from screener unless calculated
                    dp: item.refund_1d_p ?? 0.0,
                    currency: "USD",
                    shortName: item.name,
                    symbol: item.code
                )
            }
        } catch {
            print("❌ EODHD Screener Parse Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Stubs
    
    func fetchFundamentals(symbol: String) async throws -> FinancialsData { throw URLError(.unsupportedURL) }
    func fetchProfile(symbol: String) async throws -> AssetProfile { throw URLError(.unsupportedURL) }
    func fetchNews(symbol: String) async throws -> [NewsArticle] { throw URLError(.unsupportedURL) }
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator { throw URLError(.unsupportedURL) }
    func fetchHoldings(symbol: String) async throws -> [EtfHolding] { return [] }
    
    private func mapSymbol(_ symbol: String) -> String {
        if symbol.contains(".") { return symbol }
        // Special case: BIST
        if symbol.count == 5 && symbol.hasSuffix(".IS") { return symbol }
        // Simple heuristic
        return "\(symbol).US" // Default to US
    }
}
