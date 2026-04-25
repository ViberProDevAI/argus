import Foundation

// MARK: - BIST Ticker Model
struct BistTicker: Codable, Identifiable, Hashable {
    let id = UUID()
    let symbol: String        // Örn: "THYAO.IS"
    let shortSymbol: String   // Örn: "THYAO" (UI için)
    let companyName: String?
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Double?
    let lastUpdated: Date
    
    // Yardımcı: Pozitif/Negatif durumu
    var isPositive: Bool { change >= 0 }
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
    }
    
    static func == (lhs: BistTicker, rhs: BistTicker) -> Bool {
        return lhs.symbol == rhs.symbol
    }
}

// MARK: - BIST Candle Model (Grafik)
struct BistCandle: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

// MARK: - Yahoo API Response Modelleri (Internal - BIST Specific)
struct BistYahooChartResponse: Codable {
    let chart: BistYahooChartResult
}

struct BistYahooChartResult: Codable {
    let result: [BistYahooChartMeta]?
    let error: BistYahooChartError?
}

struct BistYahooChartError: Codable {
    let code: String
    let description: String
}

struct BistYahooChartMeta: Codable {
    let meta: BistYahooMetaInfo
    let timestamp: [TimeInterval]?
    let indicators: BistYahooIndicators?
}

struct BistYahooMetaInfo: Codable {
    let currency: String
    let symbol: String
    let regularMarketPrice: Double?
    let previousClose: Double?
}

struct BistYahooIndicators: Codable {
    let quote: [BistYahooQuoteIndicator]?
}

struct BistYahooQuoteIndicator: Codable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Double?]?
}
