import Foundation

/// A "Last Resort" data provider using unofficial Yahoo Finance endpoints.
/// Used only when primary official APIs fail or for specific missing data (e.g. Crypto fallback).
final class YahooFallbackProvider: FallbackDataProvider {
    static let shared = YahooFallbackProvider()
    let name = "YahooFallback"
    
    // Yahoo specific tickers might differ, simplest map:
    private func mapSymbol(_ symbol: String) -> String {
        // Crypto mapping
        if symbol == "BTC" || symbol == "BTC-USD" { return "BTC-USD" }
        if symbol == "ETH" || symbol == "ETH-USD" { return "ETH-USD" }
        if symbol == "DXY" { return "DX-Y.NYB" } // Yahoo Map
        // XIST mapping?
        if symbol.hasSuffix(".IS") { return symbol }
        // US Default
        return symbol
    }
    
    func supports(symbol: String, field: DataField) -> Bool {
        // Supports basic price data for almost anything Yahoo tracks
        switch field {
        case .lastPrice, .previousClose, .btcPrice, .ethPrice, .btcDailyChangePercent, .ethDailyChangePercent, .goldPrice:
            return true
        default:
            return false // Complex candles or macro might be harder to parse from simple JSON
        }
    }
    
    func fetchQuote(symbol: String) async throws -> Quote {
        let yahooSymbol = mapSymbol(symbol)
        // Check custom overrides for Gold/Oil if needed
        let targetSymbol = (symbol.hasSuffix("=F")) ? symbol : yahooSymbol
        
        let urlStr = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(targetSymbol)"
        guard let url = URL(string: urlStr) else { throw DataFallbackError.invalidData }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // Add User-Agent to prevent 403 Forbidden
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
             throw DataFallbackError.networkError("Yahoo HTTP Error")
        }
        
        let result = try JSONDecoder().decode(PrivateYahooQuoteResponse.self, from: data)
        guard let q = result.quoteResponse.result.first else {
            throw DataFallbackError.invalidData
        }
        
        // Calculate change/percent if missing (Yahoo usually provides)
        let change = q.regularMarketPrice - q.regularMarketPreviousClose
        let pct = (q.regularMarketPreviousClose > 0) ? (change / q.regularMarketPreviousClose) * 100.0 : 0.0
        
        return Quote(
            c: q.regularMarketPrice,
            d: change,
            dp: pct,
            currency: "USD" // Yahoo generic
        )
    }

    func fetchCandles(symbol: String, days: Int = 90) async throws -> [Candle] {
        let yahooSymbol = mapSymbol(symbol)
        // Check custom overrides
        let targetSymbol = (symbol.hasSuffix("=F")) ? symbol : yahooSymbol
        
        // Interval: 1d, Range: Xd
        let interval = "1d"
        var range = "1y" // Default to 1 year
        
        if days <= 5 { range = "5d" }
        else if days <= 30 { range = "1mo" }
        else if days <= 90 { range = "3mo" }
        else if days <= 180 { range = "6mo" }
        else if days <= 400 { range = "1y" } // Cover 600 request with 2y
        else if days <= 800 { range = "2y" }
        else { range = "5y" }
        
        print("🌍 Yahoo Fallback: Fetching \(symbol) with range: \(range) (Requested: \(days)d)")
        
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(targetSymbol)?interval=\(interval)&range=\(range)"
        guard let url = URL(string: urlStr) else { throw DataFallbackError.invalidData }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
             throw DataFallbackError.networkError("Yahoo Candle HTTP Error")
        }
        
        // Rename usage here
        let result = try JSONDecoder().decode(YFPChartResponse.self, from: data)
        guard let resultData = result.chart.result.first,
              let timestamps = resultData.timestamp,
              let quote = resultData.indicators.quote.first else {
            throw DataFallbackError.invalidData
        }
        
        // Ensure arrays are same size
        let count = min(timestamps.count, quote.close.count)
        
        var candles: [Candle] = []
        for i in 0..<count {
            if let c = quote.close[i],
               let o = quote.open[i],
               let h = quote.high[i],
               let l = quote.low[i] {
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                // Volume can be nil or Int.
                // quote.volume[i] is Int?.
                let v = Double(quote.volume[i] ?? 0)
                
                candles.append(Candle(date: date, open: o, high: h, low: l, close: c, volume: v))
            }
        }
        
        return candles
    }
    
    // MARK: - ETF Holdings (New)
    func fetchHoldings(symbol: String) async throws -> [EtfHolding] {
        let yahooSymbol = mapSymbol(symbol)
        // https://query1.finance.yahoo.com/v10/finance/quoteSummary/SPY?modules=topHoldings
        
        let urlStr = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(yahooSymbol)?modules=topHoldings"
        guard let url = URL(string: urlStr) else { throw DataFallbackError.invalidData }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
             throw DataFallbackError.networkError("Yahoo Holdings HTTP Error")
        }
        
        let result = try JSONDecoder().decode(YahooHoldingsResponse.self, from: data)
        guard let holdingsData = result.quoteSummary.result.first?.topHoldings else {
            return [] // No holdings found
        }
        
        // Map to EtfHolding
        return holdingsData.holdings.map { h in
            EtfHolding(
                symbol: h.symbol,
                name: h.holdingName,
                weight: (h.holdingPercent.raw), 
                sector: "Unknown", 
                country: "USA"
            )
        }
    }

    func fetch(field: DataField, for symbol: String) async throws -> DataFieldValue {
        let yahooSymbol = mapSymbol(symbol)
        // Check custom overrides for Gold/Oil if needed
        let targetSymbol = (field == .goldPrice) ? "GC=F" : yahooSymbol
        
        // URL for JSON Quote
        let urlStr = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(targetSymbol)"
        guard let url = URL(string: urlStr) else { throw DataFallbackError.invalidData }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // Add User-Agent to prevent 403 Forbidden (Mirroring previous fix)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
             throw DataFallbackError.networkError("Yahoo HTTP Error")
        }
        
        // Parse
        let result = try JSONDecoder().decode(PrivateYahooQuoteResponse.self, from: data)
        guard let quote = result.quoteResponse.result.first else {
            throw DataFallbackError.invalidData
        }
        
        switch field {
        case .lastPrice, .btcPrice, .ethPrice, .goldPrice:
            return .double(quote.regularMarketPrice)
            
        case .previousClose:
            return .double(quote.regularMarketPreviousClose)
            
        case .btcDailyChangePercent, .ethDailyChangePercent:
            if quote.regularMarketPreviousClose > 0 {
                let change = quote.regularMarketPrice - quote.regularMarketPreviousClose
                let pct = (change / quote.regularMarketPreviousClose) * 100.0
                return .double(pct)
            } else {
                throw DataFallbackError.invalidData
            }
            
        default:
            throw DataFallbackError.notSupported
        }
    }
}

// MARK: - Yahoo Holdings Models
struct YahooHoldingsResponse: Codable {
    let quoteSummary: QuoteSummary
    struct QuoteSummary: Codable {
        let result: [QuoteResult]
    }
    struct QuoteResult: Codable {
        let topHoldings: TopHoldings?
    }
    struct TopHoldings: Codable {
        let holdings: [HoldingItem]
        let sectorWeightings: [SectorWeightItem]?
    }
    struct HoldingItem: Codable {
        let symbol: String
        let holdingName: String
        let holdingPercent: RawFmt
    }
    struct SectorWeightItem: Codable {
        let sector: RawFmt
        let weight: RawFmt // ? Need to verify structure
    }
    struct RawFmt: Codable {
        let raw: Double
        let fmt: String?
    }
}

// MARK: - Yahoo Chart Models (Renamed to avoid collision with APIService)
private struct YFPChartResponse: Codable {
    let chart: YFPChartData
}

private struct YFPChartData: Codable {
    let result: [YFPChartResult]
}

private struct YFPChartResult: Codable {
    let timestamp: [Int]?
    let indicators: YFPChartIndicators
}

private struct YFPChartIndicators: Codable {
    let quote: [YFPChartQuote]
}

private struct YFPChartQuote: Codable {
    let open: [Double?]
    let high: [Double?]
    let low: [Double?]
    let close: [Double?]
    let volume: [Int?] 
}

// MARK: - Private DTOs
private struct PrivateYahooQuoteResponse: Codable {
    struct QuoteResult: Codable {
        let result: [YahooQuoteItem]
    }
    let quoteResponse: QuoteResult
}

private struct YahooQuoteItem: Codable {
    let symbol: String
    let regularMarketPrice: Double
    let regularMarketPreviousClose: Double
}
