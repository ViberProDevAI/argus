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
        let trimmed = tf.trimmingCharacters(in: .whitespacesAndNewlines)

        // Case-sensitive özel kısaltmalar (Türkçe UI)
        switch trimmed {
        case "1S": return ("60m", "2y")    // 1 Saat
        case "4S": return ("60m", "2y")    // 4 Saat (yaklaşık)
        case "5D": return ("5m", "60d")    // 5 Dakika
        case "15D": return ("15m", "60d")  // 15 Dakika
        case "1G", "GUNLUK": return ("1d", "max")
        case "1H": return ("1wk", "max")   // 1 Hafta
        case "1A": return ("1mo", "max")
        default: break
        }

        let normalized = trimmed.lowercased()
        switch normalized {
        // Daily / Long Term
        case "1day", "1d": return ("1d", "max")
        case "1week", "1wk", "1w": return ("1wk", "max")
        case "1month", "1mo": return ("1mo", "max")
        case "3month", "3mo": return ("3mo", "max")

        // Intraday (Yahoo native + uygulama eşlemleri)
        case "1min", "1m": return ("1m", "7d")
        case "5min", "5m": return ("5m", "60d")
        case "15min", "15m": return ("15m", "60d")
        case "30min", "30m": return ("30m", "60d")
        case "60min", "1hour", "1h": return ("60m", "2y")
        case "4h", "4hour", "240m", "240min": return ("60m", "2y")

        default: return ("1d", "5y")
        }
    }
}
