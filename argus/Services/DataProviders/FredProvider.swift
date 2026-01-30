import Foundation
import Combine

/// Provides access to Federal Reserve Economic Data (FRED).
/// Implements "SlowMacro" data source requirements with specific caching policies.
final class FredProvider: HeimdallProvider, Sendable {
    static let shared = FredProvider()
    nonisolated var name: String { "FRED" }
    
    nonisolated var capabilities: [HeimdallDataField] {
        return [.macro]
    }
    
    private let baseURL = "https://api.stlouisfed.org/fred/series/observations"
    private let cacheKeyPrefix = "FredProviderCache"
    
    private init() {}
    
    enum SeriesInfo: String, CaseIterable, Sendable {
        case cpi = "CPIAUCSL"       // Headline CPI (Monthly)
        case cpiCore = "CPILFESL"   // Core CPI (Monthly)
        case unemployment = "UNRATE" // Unemployment Rate (Monthly)
        case payrolls = "PAYEMS"    // Non-Farm Payrolls (Monthly)
        case fedFunds = "FEDFUNDS"  // Fed Funds Effective Rate (Monthly)
        case treasury10Y = "DGS10"  // 10-Year Treasury (Daily)
        case treasury2Y = "DGS2"    // 2-Year Treasury (Daily)
        case recession = "USRECD"   // Recession Probability
        case growth = "GDPC1"       // Real GDP (Quarterly)
        
        var ttl: TimeInterval {
            switch self {
            case .treasury10Y, .treasury2Y:
                return 6 * 3600 // 6 Hours for Daily
            default:
                return 14 * 86400 // 14 Days for Monthly
            }
        }
    }
    
    struct CachedDataPoint: Codable {
        let date: Date
        let value: Double
    }
    
    struct CachedSeries: Codable {
        let series: String
        let timestamp: Date
        let data: [CachedDataPoint]
    }
    
    // MARK: - API
    
    // MARK: - API
    
    /// Fetches historical data for a series with caching and rate limiting awareness.
    /// Supports dynamic Series ID (String).
    func fetchSeries(seriesId: String, limit: Int = 24) async throws -> [(Date, Double)] {
        // 1. Check Cache
        if let cached = checkCache(seriesId: seriesId) {
            return cached
        }
        
        // 2. Check API Key
        guard let apiKey = await getApiKey(), !apiKey.isEmpty else {
            // API key yok - stale cache dene
            if let stale = checkCache(seriesId: seriesId, ignoreExpiry: true) {
                print("⚠️ FRED: No API Key. Serving stale data for \(seriesId)")
                return stale
            }
            print("❌ FRED: No API Key and no cached data for \(seriesId)")
            throw HeimdallCoreError(category: .authInvalid, code: 401, message: "FRED API Key missing. Configure in Settings.", bodyPrefix: "")
        }
        
        // FRED API
        let urlString = "\(baseURL)?series_id=\(seriesId)&api_key=\(apiKey)&file_type=json&sort_order=desc&limit=\(limit)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        print("🏛️ FRED Direct: Series \(seriesId)")
        
        do {
            // Basit URLSession - HeimdallNetwork proxy sorunlarından kaçınmak için
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Response kontrolü
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("❌ FRED HTTP Error: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
            
            let fredResponse = try JSONDecoder().decode(FredResponse.self, from: data)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            var results: [(Date, Double)] = []
            
            for obs in fredResponse.observations.reversed() { 
                 if let date = formatter.date(from: obs.date),
                    let val = Double(obs.value) {
                     results.append((date, val))
                 }
            }
            
            if !results.isEmpty {
                saveCache(seriesId: seriesId, data: results)
                print("✅ FRED: \(seriesId) -> \(results.count) observations")
            }
            
            return results
            
        } catch {
            print("❌ FRED Fetch Error (\(seriesId)): \(error.localizedDescription)")
            
            if let stale = checkCache(seriesId: seriesId, ignoreExpiry: true) {
                print("⚠️ FRED: Serving Stale Data for \(seriesId)")
                return stale
            }
            
            throw error
        }
    }
    
    // Convenience for Enum
    func fetchSeries(series: SeriesInfo, limit: Int = 24) async throws -> [(Date, Double)] {
        return try await fetchSeries(seriesId: series.rawValue, limit: limit)
    }
    
    // MARK: - Helper Methods
    
    /// Fetches the latest 10-Year Treasury Yield as a decimal (e.g. 4.5% -> 0.045)
    func getRiskFreeRate() async -> Double? {
        do {
            // DGS10: 10-Year Treasury Constant Maturity Rate
            let data = try await fetchSeries(series: .treasury10Y, limit: 1)
            guard let latest = data.first else { return nil }
            return latest.1 / 100.0 // FRED datas returns percent (e.g. 4.18), convert to decimal
        } catch {
            print("❌ FRED: Failed to fetch Risk-Free Rate: \(error)")
            // Try to use cached data even if expired if real-time fails
            if let cached = checkCache(seriesId: SeriesInfo.treasury10Y.rawValue, ignoreExpiry: true),
               let latest = cached.first {
                return latest.1 / 100.0
            }
            return nil
        }
    }
    
    // MARK: - Cache Helpers
    
    private func checkCache(seriesId: String, ignoreExpiry: Bool = false) -> [(Date, Double)]? {
        let key = "\(cacheKeyPrefix)_\(seriesId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedSeries.self, from: data) else { return nil }
        
        // Dynamic TTL: If it matches a known series, use that TTL, else default 7 days
        let ttl: TimeInterval = SeriesInfo(rawValue: seriesId)?.ttl ?? (7 * 86400)
        
        if !ignoreExpiry && -cached.timestamp.timeIntervalSinceNow > ttl {
            return nil // Expired
        }
        
        return cached.data.map { ($0.date, $0.value) }
    }
    
    private func saveCache(seriesId: String, data: [(Date, Double)]) {
        let key = "\(cacheKeyPrefix)_\(seriesId)"
        let points = data.map { CachedDataPoint(date: $0.0, value: $0.1) }
        let cached = CachedSeries(series: seriesId, timestamp: Date(), data: points)
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func getApiKey() async -> String? {
        return APIKeyStore.shared.getKey(for: .fred)
    }
    
    // MARK: - Models
    private struct FredResponse: Decodable {
        let observations: [FredObservation]
    }
    
    private struct FredObservation: Decodable {
        let date: String
        let value: String
    }
    
    // MARK: - Heimdall Protocol Stubs
    
    func fetchQuote(symbol: String) async throws -> Quote { throw URLError(.unsupportedURL) }
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] { throw URLError(.unsupportedURL) }
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] { throw URLError(.unsupportedURL) }
    func fetchFundamentals(symbol: String) async throws -> FinancialsData { throw URLError(.unsupportedURL) }
    func fetchProfile(symbol: String) async throws -> AssetProfile { throw URLError(.unsupportedURL) }
    func fetchNews(symbol: String) async throws -> [NewsArticle] { throw URLError(.unsupportedURL) }
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator { throw URLError(.unsupportedURL) }
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] { throw URLError(.unsupportedURL) }
    func fetchHoldings(symbol: String) async throws -> [EtfHolding] { return [] }
}
