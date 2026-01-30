import Foundation

// MARK: - Macro Models
struct MacroData: Codable, Sendable {
    let vix: Double
    let bond10y: Double
    let bond2y: Double
    let dxy: Double
    let date: Date
}

struct Candle: Identifiable, Codable, @unchecked Sendable, Equatable {
    var id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    
    enum CodingKeys: String, CodingKey {
        case date, open, high, low, close, volume
    }
    
    // Demo Helper
    static func generateMockCandles(count: Int, startPrice: Double) -> [Candle] {
        var candles: [Candle] = []
        var currentPrice = startPrice
        let now = Date()
        
        for i in 0..<count {
            // Random walk
            let change = Double.random(in: -2.0...2.5)
            let open = currentPrice
            let close = open + change
            let high = max(open, close) + Double.random(in: 0.0...1.0)
            let low = min(open, close) - Double.random(in: 0.0...1.0)
            let volume = Double.random(in: 1_000_000...10_000_000)
            
            // Reverse date
            let date = Calendar.current.date(byAdding: .day, value: -(count - 1 - i), to: now)!
            
            candles.append(Candle(
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            ))
            
            currentPrice = close
        }
        
        return candles
    }
}

struct Quote: Codable, Sendable, Equatable {
    let c: Double // Current
    var d: Double? // Change (Raw/Optional)
    var dp: Double? // Percent Change (Raw/Optional)
    let currency: String?
    var shortName: String? = nil
    var symbol: String? = nil
    
    // Recovery Field
    var previousClose: Double? = nil
    
    // New Optional Fields
    var volume: Double? = nil
    var marketCap: Double? = nil
    var peRatio: Double? = nil
    var eps: Double? = nil
    var sector: String? = nil
    
    var currentPrice: Double { return c }
    
    // Computed Change Logic
    var change: Double {
        if let val = d, val != 0 { return val }
        guard let prev = previousClose, prev > 0 else { return 0.0 }
        return c - prev
    }
    
    var percentChange: Double {
        if let val = dp, val != 0 { return val }
        guard let prev = previousClose, prev > 0 else { return 0.0 }
        return ((c - prev) / prev) * 100.0
    }
    
    var isPositive: Bool { change >= 0 }
    
    // Phase 3: Staleness Guard
    var timestamp: Date? = nil
}

enum DataError: Error {
    case staleData
    case insufficientHistory
    case noData
}

// MARK: - Safe Universe Models
struct SafeAsset: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let type: SafeAssetType
    let expenseRatio: Double
}

struct MarketCategory: Identifiable {
    let id = UUID()
    let title: String
    let symbols: [String]
}

// MARK: - TERMINAL OPTIMIZED MODELS
struct TerminalItem: Identifiable, Equatable {
    let id: String // Symbol
    let symbol: String
    let market: MarketType // Global vs BIST
    let currency: Currency
    
    // Live Data
    let price: Double
    let dayChangePercent: Double?
    
    // Scores
    let orionScore: Double?
    let atlasScore: Double?
    let councilScore: Double?
    let action: ArgusAction
    let dataQuality: Int // 0-100
    
    // Forecast
    let forecast: PrometheusForecast?
    
    // Chimera Signal (NEW)
    let chimeraSignal: ChimeraSignal?
}

struct MarketSnapshot: Codable {
    let bid: Double?
    let ask: Double?
    let spreadPct: Double?
    let atr: Double?
    let returns: ReturnsSnapshot

    let barsSummary: BarsSummarySnapshot
    // Schema V2
    let barTimestamp: Date?
    let signalPrice: Double?
    let volatilityHint: Double?
    
    struct ReturnsSnapshot: Codable {
        let r1m: Double?
        let r5m: Double?
        let r1h: Double?
        let r1d: Double?
        let rangePct: Double?
        let gapPct: Double?
    }
    struct BarsSummarySnapshot: Codable {
        let lookback: Int
        let high: Double?
        let low: Double?
        let close: Double?
    }
}
