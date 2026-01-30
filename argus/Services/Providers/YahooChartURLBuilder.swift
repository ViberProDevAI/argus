import Foundation

/// Robust URL Builder for Yahoo Finance Chart V8 API.
/// Handles special character encoding (^VIX, DX-Y.NYB) and timeframe mapping.
struct YahooChartURLBuilder: Sendable {
    
    nonisolated private static let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    
    nonisolated static func build(symbol: String, timeframe: String) throws -> URL {
        // 1. Encode Symbol
        // Yahoo expects strict encoding for special chars like ^, =
        // e.g. ^VIX -> %5EVIX, SI=F -> SI%3DF
        // But URLComponents generic encoding often misses some needed by Yahoo or double encodes.
        // Best practice: Do manual encoding for known specials if standard fails, 
        // but standard allowedCharacters usually works if configured right.
        
        let safeSymbol = encodeSymbol(symbol)
        
        // 2. Map Timeframe to Interval/Range
        let (interval, range) = mapTimeframe(timeframe)
        
        // 3. Construct Components
        // Path is /v8/finance/chart/{symbol}
        guard var components = URLComponents(string: "\(baseURL)/\(safeSymbol)") else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "symbol", value: safeSymbol), // Redundant but safe
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "includePrePost", value: "false"),
            URLQueryItem(name: "events", value: "div,split")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        return url
    }
    
    // MARK: - Helpers
    
    /// strict custom encoding for Yahoo symbols
    nonisolated static func encodeSymbol(_ s: String) -> String {
        // Allowed: Alphanumeric, dot, dash.
        // Bad: ^, =, @, etc. need percent.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-") // DX-Y.NYB is fine without encoding dot/dash usually? 
        // Actually usually standard URL path encoding is fine.
        // The issue is often ^VIX becoming %255EVIX (double) or not encoded.
        // Swift's addingPercentEncoding with urlPathAllowed leaves some chars.
        
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
    
    nonisolated static func mapTimeframe(_ tf: String) -> (String, String) {
        switch tf {
        // Daily / Long Term (English)
        case "1day", "1d": return ("1d", "2y")
        case "1week", "1wk": return ("1wk", "5y")
        case "1month", "1mo": return ("1mo", "10y")
        case "3month", "3mo": return ("3mo", "10y")
        
        // Intraday (Strict Range to avoid nulls) (English)
        case "1min", "1m": return ("1m", "1d")   // Risk: 7d limit
        case "5min", "5m": return ("5m", "5d")   // Risk: 60d limit
        case "15min": return ("15m", "5d")
        case "30min": return ("30m", "1mo")
        case "60min", "1hour", "1h": return ("60m", "3mo") // 2y limit

        // =====================================================
        // TURKISH UI MAPPINGS (Türkçe Kısaltmalar)
        // =====================================================
        // 1S = 1 Saat (Hour)
        case "1S": return ("60m", "3mo")
        // 4S = 4 Saat (4 Hours) - Yahoo doesn't have 4h native, use 60m with more range
        case "4S": return ("60m", "6mo")
        // 5D = 5 Dakika (5 Minutes)
        case "5D": return ("5m", "5d")
        // 15D = 15 Dakika (15 Minutes)
        case "15D": return ("15m", "5d")
        // 1G = 1 Gün (1 Day)
        case "1G", "GUNLUK": return ("1d", "2y")
        // 1H = 1 Hafta (1 Week)
        case "1H": return ("1wk", "5y")
        // 1A = 1 Ay (1 Month)
        case "1A": return ("1mo", "10y")
        
        default: return ("1d", "1y")
        }
    }
}
