import Foundation

/// "The Gatekeeper" - SIMPLIFIED Yahoo-Only Mode
/// All routing complexity removed. Direct Yahoo Finance calls.
@MainActor
final class HeimdallOrchestrator {
    static let shared = HeimdallOrchestrator()
    
    private let yahoo = YahooFinanceProvider.shared
    private let fred = FredProvider.shared
    
    private init() {
        print("🏛️ HEIMDALL: Yahoo Direct Mode initialized")
    }
    
    // MARK: - Quote
    
    func requestQuote(symbol: String, context: UsageContext = .interactive) async throws -> Quote {
        let provider = "yahoo"
        let endpoint = "/quote"
        
        // Circuit Breaker Check
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: provider) else {
            await HeimdallLogger.shared.warn("circuit_blocked", provider: provider, errorClass: "circuit_open")
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for \(provider)", bodyPrefix: "")
        }
        
        await RateLimiter.shared.waitIfNeeded()
        let start = Date()
        
        do {
            let quote = try await yahoo.fetchQuote(symbol: symbol)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: provider)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            await HealthStore.shared.reportSuccess(provider: provider, latency: Double(latency))
            
            return quote
        } catch {
            await HeimdallCircuitBreaker.shared.reportFailure(provider: provider, error: error)
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            await HealthStore.shared.reportError(provider: provider, error: error)
            throw error
        }
    }
    
    // MARK: - Fundamentals
    
    func requestFundamentals(symbol: String, context: UsageContext = .interactive) async throws -> FinancialsData {
        let provider = "yahoo"
        let endpoint = "/fundamentals"
        
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: provider) else {
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open", bodyPrefix: "")
        }

        await RateLimiter.shared.waitIfNeeded()
        let start = Date()

        do {
            let data = try await yahoo.fetchFundamentals(symbol: symbol)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: provider)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            return data
        } catch {
            await HeimdallCircuitBreaker.shared.reportFailure(provider: provider, error: error)
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            throw error
        }
    }

    
    // MARK: - Candles
    
    func requestCandles(
        symbol: String,
        timeframe: String,
        limit: Int,
        context: UsageContext = .interactive,
        provider providerTag: ProviderTag? = nil,
        instrument: CanonicalInstrument? = nil
    ) async throws -> [Candle] {
        let provider = "yahoo"
        let endpoint = "/candles"
        
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: provider) else {
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open", bodyPrefix: "")
        }
        
        await RateLimiter.shared.waitIfNeeded()
        let start = Date()
        
        do {
            let candles = try await yahoo.fetchCandles(symbol: symbol, timeframe: timeframe, limit: limit)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: provider)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            return candles
        } catch {
            await HeimdallCircuitBreaker.shared.reportFailure(provider: provider, error: error)
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            throw error
        }
    }

    
    // MARK: - News
    
    func requestNews(symbol: String, limit: Int = 10, context: UsageContext = .interactive) async throws -> [NewsArticle] {
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: News for \(symbol)")
        return try await yahoo.fetchNews(symbol: symbol)
    }
    
    // MARK: - Screener (Phoenix)
    
    func requestScreener(type: ScreenerType, limit: Int = 10) async throws -> [Quote] {
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: Screener \(type)")
        return try await yahoo.fetchScreener(type: type, limit: limit)
    }
    
    // MARK: - Macro
    
    func requestMacro(symbol: String, context: UsageContext = .interactive) async throws -> HeimdallMacroIndicator {
        // Routing Logic
        if symbol.hasPrefix("FRED.") || ["INFLATION", "FEDFUNDS", "GDP", "UNRATE"].contains(symbol) {
            // Map common aliases to FRED Series IDs
            let seriesId: String
            switch symbol {
            case "INFLATION": seriesId = "CPIAUCSL"
            case "FEDFUNDS": seriesId = "FEDFUNDS"
            case "GDP": seriesId = "GDPC1"
            case "UNRATE": seriesId = "UNRATE"
            default: seriesId = symbol.replacingOccurrences(of: "FRED.", with: "")
            }
            
            print("🏛️ HEIMDALL: Routing \(symbol) -> FRED Provider (\(seriesId))")
            
            // Fetch series from Fred
            let series = try await fred.fetchSeries(seriesId: seriesId, limit: 1)
            guard let latest = series.first else { throw URLError(.badServerResponse) }
            
            return HeimdallMacroIndicator(
                symbol: symbol,
                value: latest.1,
                change: nil,
                changePercent: nil,
                lastUpdated: latest.0
            )
        } else {
            // Default to Yahoo (VIX, DXY, Etc)
            print("🏛️ HEIMDALL: Routing \(symbol) -> Yahoo Provider")
            return try await yahoo.fetchMacro(symbol: symbol)
        }
    }
    
    // MARK: - FRED Series (Special - Direct to FRED)
    
    func requestMacroSeries(instrument: CanonicalInstrument, limit: Int = 24) async throws -> [(Date, Double)] {
        guard let seriesId = instrument.fredSeriesId else {
            throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "No FRED Series ID for \(instrument.internalId)", bodyPrefix: "")
        }
        
        let provider = "fred"
        let endpoint = "/series/\(seriesId)"
        
        // Circuit Breaker Check
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: provider) else {
            await HeimdallLogger.shared.warn("circuit_blocked", provider: provider, errorClass: "circuit_open", endpoint: endpoint)
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for FRED", bodyPrefix: "")
        }
        
        let start = Date()
        
        do {
            let result = try await fred.fetchSeries(seriesId: seriesId, limit: limit)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: provider)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: seriesId, latencyMs: latency)
            
            return result
        } catch {
            await HeimdallCircuitBreaker.shared.reportFailure(provider: provider, error: error)
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            throw error
        }
    }
    
    func requestFredSeries(series: FredProvider.SeriesInfo, limit: Int = 24) async throws -> [(Date, Double)] {
        let provider = "fred"
        let endpoint = "/series/\(series.rawValue)"
        
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: provider) else {
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for FRED", bodyPrefix: "")
        }
        
        let start = Date()
        
        do {
            let result = try await fred.fetchSeries(seriesId: series.rawValue, limit: limit)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: provider)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, latencyMs: latency)
            
            return result
        } catch {
            await HeimdallCircuitBreaker.shared.reportFailure(provider: provider, error: error)
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Instrument Candles
    
    func requestInstrumentCandles(instrument: CanonicalInstrument, timeframe: String = "1D", limit: Int = 60) async throws -> [Candle] {
        if instrument.internalId == "macro.trend" {
            throw HeimdallCoreError(category: .unknown, code: 400, message: "Cannot fetch candles for derived (TREND)", bodyPrefix: "")
        }
        
        // FIX: Yahoo için yahooSymbol kullan, yoksa internalId'ye fallback
        let symbol = instrument.yahooSymbol ?? instrument.internalId
        return try await requestCandles(symbol: symbol, timeframe: timeframe, limit: limit, instrument: instrument)
    }
    
    // MARK: - System Health
    
    enum SystemHealthStatus: String {
        case operational = "Operational"
        case degraded = "Degraded"
        case critical = "Critical - DO NOT TRADE"
    }
    
    func checkSystemHealth() async -> SystemHealthStatus {
        // Simple: Try a test quote
        do {
            _ = try await yahoo.fetchQuote(symbol: "SPY")
            return .operational
        } catch {
            return .critical
        }
    }
    
    func getProviderScores() async -> [String: ProviderScore] {
        return ["Yahoo": ProviderScore.neutral]
    }
    
    // MARK: - Error Classification Helper
    
    private func classifyError(_ error: Error) -> String {
        if let heimdallError = error as? HeimdallCoreError {
            return heimdallError.category.rawValue
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return "timeout"
            case .notConnectedToInternet: return "network"
            case .userAuthenticationRequired: return "auth"
            case .cancelled: return "cancelled"
            default: return "network"
            }
        }
        
        return "unknown"
    }
}

// MARK: - Usage Context (required for API compatibility)
enum UsageContext {
    case interactive
    case background
    case realtime
}

