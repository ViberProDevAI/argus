import Foundation

@available(*, deprecated, message: "Use MarketDataProvider instead")
class APIService {
    static let shared = APIService()
    
    // ⚠️ Replace with your own API Key if needed
    // ⚠️ Replace with your own API Key if needed
    private var apiKey = "" // Secrets.finnhubKey removed
    
    private init() {}
    
    func updateApiKey(_ key: String) {
        self.apiKey = key
    }
    
    // MARK: - Fetch Candles (Real Data Only)
    // Resolution: "1", "5", "15", "30", "60", "D", "W", "M"
    func fetchCandles(symbol: String, resolution: String = "D") async -> [Candle] {
        do {
            return try await fetchRealCandles(symbol: symbol, resolution: resolution)
        } catch {
            print("⚠️ API Error for \(symbol): \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Quote (Real Data Only)
    func fetchQuote(symbol: String) async -> Quote? {
        do {
            return try await fetchRealQuote(symbol: symbol)
        } catch {
            print("⚠️ API Error for \(symbol): \(error)")
            return nil
        }
    }
    
    // MARK: - Discover Categories (Simulated)
    func getDiscoverCategories() -> [MarketCategory] {
        return [] // Deprecated, using dynamic load in ViewModel
    }
    
    // MARK: - Private Real API Calls
    
    // MARK: - Private Real API Calls
    
    // MARK: - Private Real API Calls
    
    private func fetchRealQuote(symbol: String) async throws -> Quote? {
        let urlString = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
        
        guard let result = response.quoteResponse.result.first else { return nil }
        
        return Quote(
            c: result.regularMarketPrice,
            d: result.regularMarketChange,
            dp: result.regularMarketChangePercent,
            currency: nil,
            symbol: result.symbol
        )
    }
    
    // HYBRID MODE: Use Yahoo Finance for Candles (No Rate Limit)
    private func fetchRealCandles(symbol: String, resolution: String) async throws -> [Candle] {
        // Map App Resolution to Yahoo Interval & Range
        var interval = "1d"
        var range = "1y"
        
        switch resolution {
        case "5":  interval = "5m";  range = "5d"   // 5 Minute candles, last 5 days
        case "60": interval = "60m"; range = "1mo"  // 1 Hour candles, last 1 month
        case "D":  interval = "1d";  range = "1y"   // Daily candles, last 1 year
        case "W":  interval = "1wk"; range = "5y"   // Weekly candles, last 5 years
        case "M":  interval = "1mo"; range = "10y"  // Monthly candles, last 10 years
        default:   interval = "1d";  range = "1y"
        }
        
        let urlString = "https://query2.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=\(interval)&range=\(range)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        
        guard let result = response.chart.result.first else { return [] }
        
        var candles: [Candle] = []
        let timestamps = result.timestamp
        let indicators = result.indicators.quote.first
        
        for i in 0..<timestamps.count {
            // Yahoo sometimes returns nulls for some intervals, skip them
            guard let open = indicators?.open[i],
                  let high = indicators?.high[i],
                  let low = indicators?.low[i],
                  let close = indicators?.close[i] else { continue }
            
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
            let volume = Double(indicators?.volume[i] ?? 0)
            
            let candle = Candle(
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            )
            candles.append(candle)
        }
        return candles
    }
    
    // MARK: - Mock Data Generator
    
    private func generateMockCandles(resolution: String, endPrice: Double) -> [Candle] {
        // ... (Mock logic kept as backup, though currently unused)
        return [] 
    }
}

// MARK: - Yahoo Finance Response Models

struct YahooQuoteResponse: Codable {
    let quoteResponse: YahooQuoteResult
}

struct YahooQuoteResult: Codable {
    let result: [YahooQuoteData]
}

struct YahooQuoteData: Codable {
    let symbol: String
    let regularMarketPrice: Double
    let regularMarketChange: Double
    let regularMarketChangePercent: Double
}

struct YahooChartResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooChartResult]
    let error: String?
}

struct YahooChartResult: Codable {
    let meta: YahooMeta
    let timestamp: [Int]
    let indicators: YahooIndicators
}

struct YahooMeta: Codable {
    let currency: String
    let symbol: String
}

struct YahooIndicators: Codable {
    let quote: [YahooQuote]
}

struct YahooQuote: Codable {
    let open: [Double?]
    let high: [Double?]
    let low: [Double?]
    let close: [Double?]
    let volume: [Int?]
}

// Helper for Finnhub JSON Decoding (Kept for reference if needed)
struct FinnhubCandleResponse: Codable {
    let c: [Double]
    let h: [Double]
    let l: [Double]
    let o: [Double]
    let v: [Double]
    let t: [Double]
    let s: String
}
