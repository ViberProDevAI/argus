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

    /// Y3-HOTFIX: Lokal throttle vs. gerçek provider hatası ayrımı.
    /// `HeimdallNetwork`'ün kendi "rate cap" frenini provider'ın arızasıyla karıştırıp
    /// circuit breaker'ı açmamak için bu sentinel'i ayrı tutuyoruz. Yerel fren → transient,
    /// retry+jitter çöz; circuit'e yazma. Gerçek 429/5xx → failure raporla, eşik dolarsa aç.
    private func isLocalThrottle(_ error: Error) -> Bool {
        if let heimdall = error as? HeimdallCoreError {
            return heimdall.code == HeimdallNetwork.localThrottleCode
        }
        return false
    }

    /// Phase 7 PR-3: Auth/entitlement hatası mı?
    /// Bu kategoride sembol-spesifik paywall var; SymbolBlocklist'e raporlanır.
    private func isAuthOrEntitlementError(_ error: Error) -> Bool {
        if let h = error as? HeimdallCoreError {
            return h.category == .authInvalid || h.category == .entitlementDenied
        }
        return false
    }

    /// Phase 7 PR-3: Sembol kara listede ise atılan sentinel hata.
    /// Provider'a network çağrısı yapılmadan, hızlıca dönen lokal hata.
    private func symbolBlockedError(provider: String, endpoint: String, symbol: String, reason: String) -> HeimdallCoreError {
        HeimdallCoreError(
            category: .authInvalid,
            code: HeimdallNetwork.symbolBlockedCode,
            message: "Symbol \(symbol) locally blocked on \(provider)/\(endpoint): \(reason)",
            bodyPrefix: "symbol-blocked"
        )
    }

    // MARK: - Quote
    
    func requestQuote(symbol: String, context: UsageContext = .interactive) async throws -> Quote {
        let provider = "yahoo"
        let endpoint = "/quote"
        let circuitProvider = circuitKey(provider: provider, endpoint: "quote")

        // Phase 7 PR-3: Sembol kara listede mi? Network'e gitmeden hızlıca dön.
        if await SymbolBlocklist.shared.isBlocked(symbol),
           let reason = await SymbolBlocklist.shared.reasonFor(symbol) {
            throw symbolBlockedError(provider: provider, endpoint: endpoint, symbol: symbol, reason: reason)
        }

        // Circuit Breaker Check
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: circuitProvider) else {
            await HeimdallLogger.shared.warn("circuit_blocked", provider: provider, errorClass: "circuit_open")
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for \(provider)/quote", bodyPrefix: "")
        }

        await RateLimiter.shared.waitIfNeeded()
        let start = Date()

        do {
            let quote = try await yahoo.fetchQuote(symbol: symbol)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            await HeimdallCircuitBreaker.shared.reportSuccess(provider: circuitProvider)
            await SymbolBlocklist.shared.reportSuccess(symbol: symbol)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            await HealthStore.shared.reportSuccess(provider: provider, latency: Double(latency))

            return quote
        } catch {
            // Y3-HOTFIX: lokal fren ≠ provider arızası — circuit'i kirletme.
            // Phase 7 PR-5 (2026-04-29): Sembol-spesifik auth/entitlement hataları
            // da provider arızası DEĞİL — Yahoo provider sağlam ama o sembol
            // paywalled. CB'yi sembol kara listesi yerine geçiremeyiz.
            if !isLocalThrottle(error) && !isAuthOrEntitlementError(error) {
                await HeimdallCircuitBreaker.shared.reportFailure(provider: circuitProvider, error: error)
                await HealthStore.shared.reportError(provider: provider, error: error)
            }
            // Phase 7 PR-3: Auth/entitlement hatası → SymbolBlocklist'e raporla.
            // 2 ardışık hatadan sonra sembol 24 saatlik kara listeye alınır.
            if isAuthOrEntitlementError(error) {
                await SymbolBlocklist.shared.reportFailure(symbol: symbol, reason: "quote auth/paywall")
            }
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            throw error
        }
    }

    // MARK: - Quote Batch (DEPRECATED — Yahoo paywalled, do not call)
    //
    // ⚠️ Yahoo (en geç 2025) `v7/finance/quote?symbols=...` çoklu-sembol formuna
    // **HTTP 401 Unauthorized** döndürmeye başladı:
    //
    //   "User is unable to access this feature"
    //   bit.ly/yahoo-finance-api-feedback
    //
    // Tek-sembol form (`?symbols=AAPL`) hâlâ çalışıyor; çoklu engellendi.
    // PR-A bu yolu denedi ama production'da 401 fırtınası ürettiği için geri
    // alındı (Phase 6 PR-A Rollback). Method burada duruyor ki Yahoo politikası
    // gevşerse veya başka batch destekleyen bir provider eklendiğinde tekrar
    // wire'lanabilsin.
    //
    // Kanonik akış: `MarketDataStore.ensureQuotes(symbols:)` → chunked paralel
    // tek-sembol `requestQuote` çağrıları (inflight semaphore ile rate-limit'li).
    @available(*, deprecated, message: "Yahoo batch quote endpoint paywalled (HTTP 401). Use ensureQuotes which routes through single-symbol requestQuote.")
    func requestQuotesBatch(symbols: [String], context: UsageContext = .interactive) async throws -> [String: Quote] {
        guard !symbols.isEmpty else { return [:] }

        let provider = "yahoo"
        let endpoint = "/quote"
        let circuitProvider = circuitKey(provider: provider, endpoint: "quote")

        // Circuit Breaker Check
        guard await HeimdallCircuitBreaker.shared.canRequest(provider: circuitProvider) else {
            await HeimdallLogger.shared.warn("circuit_blocked", provider: provider, errorClass: "circuit_open")
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for \(provider)/quote", bodyPrefix: "")
        }

        await RateLimiter.shared.waitIfNeeded()
        let start = Date()

        do {
            let result = try await yahoo.fetchBatchQuotes(symbols: symbols)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            await HeimdallCircuitBreaker.shared.reportSuccess(provider: circuitProvider)
            await HeimdallLogger.shared.info(
                "fetch_success",
                provider: provider,
                endpoint: endpoint,
                symbol: "BATCH(\(symbols.count))",
                latencyMs: latency
            )
            await HealthStore.shared.reportSuccess(provider: provider, latency: Double(latency))
            return result
        } catch {
            // Phase 7 PR-5: Auth/entitlement hataları sembol-spesifik (paywall),
            // provider arızası değil → CB'yi tetikleme.
            if !isLocalThrottle(error) && !isAuthOrEntitlementError(error) {
                await HeimdallCircuitBreaker.shared.reportFailure(provider: circuitProvider, error: error)
                await HealthStore.shared.reportError(provider: provider, error: error)
            }
            await HeimdallLogger.shared.error(
                "fetch_failed",
                provider: provider,
                errorClass: classifyError(error),
                errorMessage: error.localizedDescription,
                endpoint: endpoint
            )
            throw error
        }
    }

    // MARK: - Fundamentals

    func requestFundamentals(symbol: String, context: UsageContext = .interactive) async throws -> FinancialsData {
        let provider = "yahoo"
        let endpoint = "/fundamentals"
        let circuitProvider = circuitKey(provider: provider, endpoint: "fundamentals")

        // Phase 7 PR-3: Sembol kara listede ise cache fallback'e düş, yeni istek yok.
        if await SymbolBlocklist.shared.isBlocked(symbol) {
            if let cached = await getCachedFundamentals(symbol: symbol) {
                await HeimdallLogger.shared.warn(
                    "cache_fallback_used",
                    provider: provider,
                    errorClass: "symbol_blocked",
                    errorMessage: "Fundamentals served from cache (symbol blocked)",
                    endpoint: endpoint
                )
                return cached
            }
            let reason = await SymbolBlocklist.shared.reasonFor(symbol) ?? "blocked"
            throw symbolBlockedError(provider: provider, endpoint: endpoint, symbol: symbol, reason: reason)
        }

        guard await HeimdallCircuitBreaker.shared.canRequest(provider: circuitProvider) else {
            if let cached = await getCachedFundamentals(symbol: symbol) {
                await HeimdallLogger.shared.warn(
                    "cache_fallback_used",
                    provider: provider,
                    errorClass: "circuit_open",
                    errorMessage: "Fundamentals served from cache",
                    endpoint: endpoint
                )
                return cached
            }
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for \(provider)/fundamentals", bodyPrefix: "")
        }

        await RateLimiter.shared.waitIfNeeded()
        let start = Date()

        do {
            let data = try await yahoo.fetchFundamentals(symbol: symbol)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: circuitProvider)
            await SymbolBlocklist.shared.reportSuccess(symbol: symbol)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            DataCacheService.shared.save(value: data, kind: .fundamentals, symbol: symbol, source: "Yahoo")
            return data
        } catch {
            // Y3-HOTFIX: lokal fren ≠ provider arızası — circuit'i kirletme.
            // Phase 7 PR-5: Auth/entitlement hataları sembol-spesifik (paywall),
            // provider arızası değil → CB'yi tetikleme.
            if !isLocalThrottle(error) && !isAuthOrEntitlementError(error) {
                await HeimdallCircuitBreaker.shared.reportFailure(provider: circuitProvider, error: error)
            }
            // Phase 7 PR-3: Auth/entitlement hatası → SymbolBlocklist'e raporla.
            if isAuthOrEntitlementError(error) {
                await SymbolBlocklist.shared.reportFailure(symbol: symbol, reason: "fundamentals auth/paywall")
            }
            await HeimdallLogger.shared.error("fetch_failed", provider: provider, errorClass: classifyError(error), errorMessage: error.localizedDescription, endpoint: endpoint)
            if shouldFallbackToCachedFundamentals(error),
               let cached = await getCachedFundamentals(symbol: symbol) {
                await HeimdallLogger.shared.warn(
                    "cache_fallback_used",
                    provider: provider,
                    errorClass: "rate_limit_or_transient",
                    errorMessage: "Fundamentals served from cache after provider failure",
                    endpoint: endpoint
                )
                return cached
            }
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
        let circuitProvider = circuitKey(provider: provider, endpoint: "candles")

        // Phase 7 PR-3: Sembol kara listede ise hızlıca dön.
        if await SymbolBlocklist.shared.isBlocked(symbol),
           let reason = await SymbolBlocklist.shared.reasonFor(symbol) {
            throw symbolBlockedError(provider: provider, endpoint: endpoint, symbol: symbol, reason: reason)
        }

        guard await HeimdallCircuitBreaker.shared.canRequest(provider: circuitProvider) else {
            throw HeimdallCoreError(category: .rateLimited, code: 503, message: "Circuit open for \(provider)/candles", bodyPrefix: "")
        }

        await RateLimiter.shared.waitIfNeeded()
        let start = Date()

        do {
            let candles = try await yahoo.fetchCandles(symbol: symbol, timeframe: timeframe, limit: limit)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            await HeimdallCircuitBreaker.shared.reportSuccess(provider: circuitProvider)
            await SymbolBlocklist.shared.reportSuccess(symbol: symbol)
            await HeimdallLogger.shared.info("fetch_success", provider: provider, endpoint: endpoint, symbol: symbol, latencyMs: latency)
            return candles
        } catch {
            // Y3-HOTFIX: lokal fren ≠ provider arızası — circuit'i kirletme.
            // Phase 7 PR-5: Auth/entitlement hataları sembol-spesifik (paywall),
            // provider arızası değil → CB'yi tetikleme.
            if !isLocalThrottle(error) && !isAuthOrEntitlementError(error) {
                await HeimdallCircuitBreaker.shared.reportFailure(provider: circuitProvider, error: error)
            }
            // Phase 7 PR-3: Auth/entitlement hatası → SymbolBlocklist'e raporla.
            if isAuthOrEntitlementError(error) {
                await SymbolBlocklist.shared.reportFailure(symbol: symbol, reason: "candles auth/paywall")
            }
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
        // Y3-HOTFIX Phase 2 (2026-04-24): Üçüncü katman koruma.
        // 72f9ef4 circuit breaker'ı (Layer 1) ve requestQuote HealthStore'u (Layer 2) ayırmıştı,
        // ama bu health probe `yahoo.fetchQuote`'u doğrudan çağırıyor — lokal rate limiter
        // window'u dolmuşsa (319 sembol batch + MTF fan-out) probe'un kendisi self-throttle
        // yiyor ve `.critical` raporluyor. Sonuç: AutoPilot/Scout sistem sağlıklıyken tarama iptal.
        //
        // Invariant (lessons.md Ders 5): "Self-imposed backpressure must not cascade".
        // Self-throttle ≠ Yahoo down. Probe lokal fren nedeniyle düşerse `.degraded` raporla —
        // AutoPilotService/ArgusScoutService `.critical` kontrolü yapıyor, `.degraded` geçiyor.
        do {
            _ = try await yahoo.fetchQuote(symbol: "SPY")
            return .operational
        } catch {
            if isLocalThrottle(error) {
                return .degraded
            }
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
    
    private func circuitKey(provider: String, endpoint: String) -> String {
        "\(provider):\(endpoint)"
    }
    
    private func shouldFallbackToCachedFundamentals(_ error: Error) -> Bool {
        if let heimdallError = error as? HeimdallCoreError {
            switch heimdallError.category {
            case .rateLimited, .serverError, .networkError, .circuitOpen:
                return true
            default:
                return heimdallError.code == 1013
            }
        }
        
        let nsError = error as NSError
        if nsError.code == 1013 || nsError.code == 429 {
            return true
        }
        
        let message = nsError.localizedDescription.lowercased()
        return message.contains("1013") || message.contains("rate limit") || message.contains("try again later")
    }
    
    private func getCachedFundamentals(symbol: String) async -> FinancialsData? {
        guard let entry = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol) else {
            return nil
        }
        return try? JSONDecoder().decode(FinancialsData.self, from: entry.data)
    }
}

// MARK: - Usage Context (required for API compatibility)
enum UsageContext {
    case interactive
    case background
    case realtime
}
