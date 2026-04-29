import Foundation

/// Y3: Per-provider sliding-window rate limiter.
/// Ücretsiz/limitli API'larda (TwelveData 8/min, AlphaVantage 5/min) 429 yemeden önce
/// lokal throttle uygular. Böylece quota bitmiyor ve retry storm'u tetiklenmiyor.
/// DispatchQueue-guarded singleton — ağ çağrısı fan-out TaskGroup'tan geliyor.
final class HeimdallRateLimiter {
    static let shared = HeimdallRateLimiter()

    private let lock = DispatchQueue(label: "argus.heimdall.ratelimiter.lock", qos: .userInitiated)
    private var timestamps: [ProviderTag: [Date]] = [:]

    // MARK: - Y3-HOTFIX Phase 4 + Phase 5: Inflight (eşzamanlılık) limiti.
    //
    // Phase 4 (cap=6): sliding-window cap'in burst sönümleyicisi.
    //
    // Phase 5 (2026-04-29, cap=4): Loglarda 41-59 sn latency gözlendi. Yahoo aslında
    // 200ms-2sn cevap veriyor; gecikme inflight kuyruğunda bekleme. Cap 6 + Yahoo
    // ortalama 1.5sn cevap = 4 req/sn throughput. 400+ pending istek → 100 sn drain.
    //
    // Ayrıca yüksek inflight Yahoo'yu boğdukça kendi cevap süresi 1.5sn → 5sn'e
    // çıkıyor (Yahoo da rate kontrolü yapıyor olabilir). Daha düşük cap = Yahoo'yu
    // boğmama = daha hızlı cevap. Throughput az düşer ama latency dramatik iyileşir.
    private let yahooInflight = InflightSemaphore(value: 4)
    private let defaultInflight = InflightSemaphore(value: 2)
    private let localInflight = InflightSemaphore(value: 32) // localScanner için yüksek cap

    private func inflightSemaphore(for provider: ProviderTag) -> InflightSemaphore {
        switch provider {
        case .yahoo:        return yahooInflight
        case .localScanner: return localInflight
        default:            return defaultInflight
        }
    }

    /// Ücretsiz tier limitleri baz alınarak seçildi. Değişirse burayı güncellemek yeter.
    /// Bilmediğimiz provider için 60/min varsayıyoruz — çoğu public endpoint için güvenli.
    ///
    /// Y3-HOTFIX (2026-04-24): Yahoo cap 60 → 300. Gerekçe: tek hisse açılışı
    /// ~8 Yahoo çağrısı (6 MTF candle + quote + fundamentals). 60/min cap'i
    /// normal kullanımda 4-5 hisse içinde patlıyor ve circuit breaker'ı açıp
    /// tüm Yahoo trafiğini 60s durduruyordu. 300/min = 5/sec — query1.finance
    /// endpoint'inin rahat kaldırdığı aralık, MTF + watchlist refresh için
    /// yeterli baş alanı bırakıyor.
    private func capPerMinute(for provider: ProviderTag) -> Int {
        switch provider {
        case .twelvedata:   return 8      // Free tier: 8 req/min
        case .alphavantage: return 5      // Free tier: 5 req/min
        case .coingecko:    return 30     // Free tier: ~10-50 req/min (muhafazakar)
        case .eodhd:        return 20     // Free tier: ~20 req/sec; dakikada yine cap
        case .fmp:          return 30     // Free tier: 250/day; burst koruması
        case .yahoo:        return 300    // Public scraping; MTF fan-out için headroom
        case .tiingo:       return 60
        case .finnhub:      return 60     // Free tier: 60 req/min
        case .fred:         return 120
        case .massive:      return 30
        case .localScanner: return 1000   // Local
        case .unknown:      return 60
        }
    }

    /// Pencere içinde kapasite varsa timestamp'i kaydedip true döner, yoksa throttle için false.
    /// Pencere 60s sliding; sıkışık anlarda retry+jitter katmanı bir sonraki denemede drop'u yakalar.
    func allowRequest(for provider: ProviderTag) -> Bool {
        lock.sync {
            let now = Date()
            let windowStart = now.addingTimeInterval(-60)
            var recent = (timestamps[provider] ?? []).filter { $0 > windowStart }
            let cap = capPerMinute(for: provider)
            if recent.count >= cap {
                timestamps[provider] = recent
                return false
            }
            recent.append(now)
            timestamps[provider] = recent
            return true
        }
    }

    /// Y3-HOTFIX Phase 3 (2026-04-24): Wait-and-serve.
    /// Eski `allowRequest` fail-fast: slot yoksa anında 1059 fırlatıyordu. AutoPilot
    /// tek turda ~608 Yahoo çağrısı (304 sembol × 2 endpoint) yolluyor; 300/min cap'e
    /// burst içinde çarpan ~150 çağrı retry bile etmeden ölüyordu (guard retry
    /// döngüsünün dışındaydı). Sonuç: "hisselerin çok azından veri alındı".
    ///
    /// Yeni davranış: slot açılana kadar bounded bekleme (varsayılan 30sn).
    /// Backoff linear-to-cap (0.5s, 1s, 1.5s...max 3s) + jitter — paralel
    /// çağrıların aynı tick'te tekrar çarpışmasını engeller. Timeout olursa
    /// hâlâ `.rateLimited` + 1059 sentinel fırlatır → HealthStore/CircuitBreaker
    /// hâlâ "bizim frenimiz" diye ayırt edebilir, self-DoS cascade'i açılmaz.
    ///
    /// Neden `async`: `Task.sleep` kullanabilmek için. `allowRequest`'teki
    /// `lock.sync` kısa kritik bölüm; bekleme süresi dışarıda yapıldığı için
    /// queue'yu bloke etmiyor.
    func acquireSlot(for provider: ProviderTag, timeout: TimeInterval = 30) async throws {
        // 1) Burst freni: aynı anda havadaki istek sayısı bir cap'i aşmasın.
        //    Bu inflight semaphore FIFO; adil kuyruk = starvation yok.
        let semaphore = inflightSemaphore(for: provider)
        await semaphore.acquire()

        // 2) Sliding window: dakikalık tavanı respect et. Inflight cap zaten burst'ü
        //    sönümlediği için burada beklemek nadir; düştüğünde de timeout dolmadan
        //    geçer çünkü bu task tek başına waiting.
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            if allowRequest(for: provider) { return }
            attempt += 1
            let base = min(Double(attempt) * 0.5, 3.0)
            let jittered = Double.random(in: (base * 0.6)...(base * 1.2))
            try? await Task.sleep(nanoseconds: UInt64(jittered * 1_000_000_000))
        }

        // Sliding window timeout → semaphore'u serbest bırak ki bekleyenler ilerlesin.
        await semaphore.release()
        throw HeimdallCoreError(
            category: .rateLimited,
            code: HeimdallNetwork.localThrottleCode,
            message: "Local rate cap wait timeout (\(Int(timeout))s) for \(provider.rawValue)",
            bodyPrefix: "wait-timeout"
        )
    }

    /// İstek tamamlandığında (başarı/başarısızlık fark etmez) inflight slotunu serbest bırak.
    /// `HeimdallNetwork.request` defer içinde çağırır.
    func releaseSlot(for provider: ProviderTag) async {
        await inflightSemaphore(for: provider).release()
    }
}

/// Centralized Networking Layer for Heimdall Providers
/// Enforces observability, error categorization, and body logging for all API traffic.
enum HeimdallNetwork {

    /// Y3-HOTFIX: Lokal throttle ile gerçek Yahoo 429'unu ayırmak için sentinel kod.
    /// HeimdallOrchestrator bu kodu gördüğünde circuit breaker'a failure RAPORLAMAZ;
    /// çünkü "bizim kendi frenimiz" ile Yahoo'nun gerçek hatasını birbirine karıştırmak
    /// cascade yapıp tüm trafiği kilitliyordu. Ayrıca kısa süreliğine sessizce retry
    /// edilsin diye `.rateLimited` kategorisinde kalıyor — sadece circuit'e dokunmuyor.
    ///
    /// `nonisolated` Y3-HOTFIX Phase 2: `HealthStore` bir `actor`, bu sabiti cross-actor
    /// okuyor. Immutable `Int` — MainActor izolasyonuna bağlamak için sebep yok. Swift 6
    /// mode'unda warning → error. Şimdiden işaretleyip migration sırasında sıkıntı çıkmasın.
    nonisolated static let localThrottleCode = 1059

    /// Performs a network request with full Heimdall Telepresence tracing.
    static func request(
        url: URL,
        engine: EngineTag,
        provider: ProviderTag,
        symbol: String,
        explicitRequest: URLRequest? = nil, // Added for Yahoo Auth injections
        timeout: TimeInterval = 25.0
    ) async throws -> Data {

        // 1. Trace Start
        // We use 'trace' extension but since we want to capture body/status specifically,
        // we might do manual recording inside or rely on the extension catching errors.
        // Let's use the extension but enhance it by throwing rich errors.

        return try await HeimdallTelepresence.shared.trace(
            engine: engine,
            provider: provider,
            symbol: symbol,
            canonicalAsset: nil,
            endpoint: url.path
        ) {

            // Y3-HOTFIX Phase 3+4: Wait-and-serve + inflight cap.
            // Phase 3: Slot açılana kadar bounded bekle (sliding window cap).
            // Phase 4 (2026-04-29): Burst freni — `acquireSlot` artık önce inflight
            // semaphore'a giriyor (Yahoo: 6 paralel max). 50+ task aynı anda gelirse
            // adil FIFO kuyruğa girip sırayla geçiyor; 30sn timeout artık nadir.
            //
            // Slot acquire'dan sonra hangi yoldan çıksak çıkalım (success / throw /
            // cancel) inflight slot'u **mutlaka** release edilmeli; Task.detached
            // çağrılarında Swift bu defer'i async olarak çalıştırır → fire-and-forget
            // ama eninde sonunda actor metodu çalışır, kayıp yok.
            try await HeimdallRateLimiter.shared.acquireSlot(for: provider, timeout: 30)
            defer {
                Task.detached {
                    await HeimdallRateLimiter.shared.releaseSlot(for: provider)
                }
            }

            var request: URLRequest
            if let explicit = explicitRequest {
                request = explicit
                // Ensure timeout matches (override explicit or keep it? explicit wins usually, but let's respect param)
                request.timeoutInterval = timeout
            } else {
                request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
            }

            // Common Headers (Merge if needed, specific headers should already be in explicitRequest)
            if request.value(forHTTPHeaderField: "User-Agent") == nil {
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            }

            // RETRY LOGIC (Max 3 attempts for transient errors)
            var attempt = 0
            let maxAttempts = 3
            var lastError: Error?
            
            while attempt < maxAttempts {
                attempt += 1
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResp = response as? HTTPURLResponse else {
                         throw URLError(.badServerResponse)
                    }
                    
                    // Capture Body Prefix for Analysis
                    let bodyPrefix = String(data: data.prefix(300), encoding: .utf8)?.replacingOccurrences(of: "\n", with: " ") ?? "Bin/Empty"
                    let bodyLower = bodyPrefix.lowercased()
                    
                    // Status Code Analysis
                    switch httpResp.statusCode {
                    case 200...299:
                        // Success (Technically). Check for Soft Errors
                        if data.isEmpty {
                            throw HeimdallCoreError(category: .emptyPayload, code: httpResp.statusCode, message: "Empty Body", bodyPrefix: bodyPrefix)
                        }
                        if bodyPrefix.contains("Error Message") || bodyPrefix.contains("\"code\": 429") || bodyPrefix.contains("exceeded your daily API") {
                             throw HeimdallCoreError(category: .rateLimited, code: 429, message: "API Error in 200 OK", bodyPrefix: bodyPrefix)
                        }
                        if bodyLower.contains("1013") && (bodyLower.contains("rate") || bodyLower.contains("try again later")) {
                            throw HeimdallCoreError(category: .rateLimited, code: 1013, message: "Provider Rate Limited (1013)", bodyPrefix: bodyPrefix)
                        }
                        return data
                        
                    case 401:
                        throw HeimdallCoreError(category: .authInvalid, code: httpResp.statusCode, message: "Unauthorized", bodyPrefix: bodyPrefix)
                    case 403:
                         let lower = bodyPrefix.lowercased()
                         if lower.contains("legacy") || lower.contains("upgrade") || lower.contains("plan") {
                             throw HeimdallCoreError(category: .entitlementDenied, code: 403, message: "Entitlement Denied", bodyPrefix: bodyPrefix)
                         }
                         throw HeimdallCoreError(category: .authInvalid, code: 403, message: "Forbidden", bodyPrefix: bodyPrefix)
                    case 404:
                        throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "Not Found", bodyPrefix: bodyPrefix)
                    case 429:
                        throw HeimdallCoreError(category: .rateLimited, code: 429, message: "Rate Limit Exceeded", bodyPrefix: bodyPrefix)
                    case 500...599:
                        if bodyLower.contains("1013") && (bodyLower.contains("rate") || bodyLower.contains("try again later")) {
                            throw HeimdallCoreError(category: .rateLimited, code: 1013, message: "Provider Rate Limited (1013)", bodyPrefix: bodyPrefix)
                        }
                        throw HeimdallCoreError(category: .serverError, code: httpResp.statusCode, message: "Server Error", bodyPrefix: bodyPrefix)
                    default:
                        throw HeimdallCoreError(category: .unknown, code: httpResp.statusCode, message: "HTTP \(httpResp.statusCode)", bodyPrefix: bodyPrefix)
                    }
                    
                } catch {
                    lastError = error
                    
                    // Retry Decision Logic
                    let isTransient: Bool
                    
                    if let urlError = error as? URLError {
                        // -1008 (resourceUnavailable), -1009 (notConnected), -1001 (timeout), -1011 (badServerResponse sometimes if connection dropped)
                        // User specifically mentioned -1008, -1009, -1011, -1017
                        switch urlError.code {
                        case .resourceUnavailable, .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                            isTransient = true
                        default:
                            isTransient = false
                        }
                    } else if let heimdallError = error as? HeimdallCoreError {
                        switch heimdallError.category {
                        case .rateLimited, .serverError, .networkError:
                            isTransient = true
                        default:
                            isTransient = false
                        }
                    } else {
                        // HeimdallCoreError is NOT transient usually (4xx, 5xx)
                        // Unless we decide 5xx is transient?
                        isTransient = false
                    }
                    
                    if isTransient && attempt < maxAttempts {
                        // Y3: exponential back-off + full jitter. Aynı provider'a paralel
                        // istek atan TaskGroup'lar lock-step retry yaparsa thundering-herd
                        // olur ve rate limit daha da kötüleşir. Jitter bu senkronizasyonu kırar.
                        let base: Double
                        if let heimdallError = error as? HeimdallCoreError, heimdallError.category == .rateLimited {
                            base = pow(2.0, Double(attempt - 1)) * 1.5 // 1.5s, 3s, 6s
                        } else {
                            base = pow(2.0, Double(attempt - 1)) * 0.5 // 0.5s, 1s, 2s
                        }
                        // Full jitter (AWS öneri): delay = random(0, base). Deterministik
                        // minimum yerine dağılımı genişletip eşzamanlı retry'ları parçalıyoruz.
                        let delay = Double.random(in: (base * 0.5)...base)
                        print("⏳ Network Retry (\(attempt)/\(maxAttempts)) for \(url.lastPathComponent) in \(String(format: "%.2f", delay))s: \(error.localizedDescription)")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    
                    // If not retryable or max attempts, throw
                    throw error
                }
            }
            throw lastError ?? URLError(.unknown)
        }
    }
}

/// Rich Error type for Heimdall
