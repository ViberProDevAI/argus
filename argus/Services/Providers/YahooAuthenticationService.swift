import Foundation

/// Handles Yahoo Finance Authentication (Cookie & Crumb Management)
/// Solves "Invalid Crumb" (401) errors for v10 endpoints.
actor YahooAuthenticationService {
    static let shared = YahooAuthenticationService()
    
    private var crumb: String?
    private var cookie: String?
    private var lastAuthTime: Date?

    // Circuit Breaker State
    private var consecutiveFailures: Int = 0
    private var circuitBreakUntil: Date?

    // Phase 7 PR-2 (2026-04-29): Proactive renewal flag.
    // Crumb TTL'in %75'ine geldiğinde arka planda yenileme tetikler;
    // birden fazla concurrent caller'ın aynı anda warmup başlatmasını engeller.
    private var warmupInFlight: Bool = false

    // Phase 7 PR-2v2 (2026-04-29): Refresh coalescing.
    // Uygulama startup'ta 50+ sembol paralel quote/fundamentals atıyor;
    // her biri stale crumb görüp ayrı `refresh()` tetikliyordu (loglarda 7+
    // ardışık refresh mesajı). Aktif bir refresh task varsa yeni caller'lar
    // onu bekler — Yahoo'ya 1 auth isteği yeter.
    private var refreshTask: Task<(String, String), Error>?

    // Phase 7 PR-2: Crumb TTL 3600 → 600.
    // Yahoo crumb gerçek ömrü 5-15 dk arası — 1 saat TTL'de çoğu istek
    // stale crumb ile gidip 401 yiyor → invalidate → refresh → retry cycle.
    // 10 dk TTL + proactive warm-renewal (TTL'in %75'i ≈ 7.5 dk) ile çoğu
    // istek fresh crumb'a denk gelir.
    private let crumbTTL: TimeInterval = 600
    private var crumbRefreshThreshold: TimeInterval { crumbTTL * 0.75 }
    
    // Session with cookie storage
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 10 // Short timeout to fail fast
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func getCrumb() async throws -> (String, String) {
        // 0. Check Circuit Breaker
        if let breakUntil = circuitBreakUntil, Date() < breakUntil {
            print("🚫 YahooAuth: Circuit Breaker OPEN. Waiting until \(breakUntil)")
            throw URLError(.userAuthenticationRequired)
        }

        // 1. Check Cache (10 dk TTL — Phase 7 PR-2).
        if let c = crumb, let k = cookie, let t = lastAuthTime {
            let age = -t.timeIntervalSinceNow
            if age < crumbTTL {
                // Proactive renewal: TTL'in %75'i geçtiyse arka planda taze al.
                // Bu istek yine cached değer dönecek; bir sonraki çağrı fresh.
                if age > crumbRefreshThreshold && !warmupInFlight && refreshTask == nil {
                    warmupInFlight = true
                    Task { [weak self] in
                        guard let self else { return }
                        _ = try? await self.warmRefresh()
                    }
                }
                return (c, k)
            }
        }

        // 2. Phase 7 PR-2v2: Coalesce concurrent refresh'es.
        //    Aktif refresh task varsa onu bekle — Yahoo'ya 1 auth isteği yeter.
        if let existing = refreshTask {
            return try await existing.value
        }

        // 3. Start new refresh (and store task for coalescing).
        let task = Task<(String, String), Error> { [weak self] in
            guard let self else { throw URLError(.cancelled) }
            return try await self.refresh()
        }
        refreshTask = task

        do {
            let result = try await task.value
            refreshTask = nil
            consecutiveFailures = 0
            circuitBreakUntil = nil
            return result
        } catch {
            refreshTask = nil
            // Aşağıdaki blok original error handling — backoff vs.
            return try await handleRefreshFailure(error: error)
        }
    }

    /// Refresh failure path'i — getCrumb'tan ayrılmış ki coalescing logic'i temiz olsun.
    /// Backoff/breaker mantığını uygular ve hatayı caller'a yeniden fırlatır.
    private func handleRefreshFailure(error: Error) async throws -> (String, String) {
        consecutiveFailures += 1
        print("⚠️ YahooAuth: Refresh attempt failed (\(consecutiveFailures)/5)")

        if consecutiveFailures >= 5 {
            let backoffSeconds = 300.0 // 5 Minutes
            circuitBreakUntil = Date().addingTimeInterval(backoffSeconds)
            print("⛔️ YahooAuth: Too many failures. Circuit Breaker ACTIVATED for \(Int(backoffSeconds))s")
        } else {
            // Short backoff (Exponential: 2s, 4s, 8s, 16s...)
            let backoff = pow(2.0, Double(consecutiveFailures))
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
        }
        throw error
    }
    
    /// Invalidate cached crumb (call this on 401 errors)
    func invalidate() {
        print("🔐 YahooAuth: Invalidating Crumb Cache")
        self.crumb = nil
        self.cookie = nil
        self.lastAuthTime = nil
    }

    /// Phase 7 PR-2: Background warm-renewal.
    /// `getCrumb` TTL'in %75'i geçtiyse bu metod fire-and-forget tetiklenir;
    /// caller anında cached crumb'ı alır, bir sonraki çağrı taze crumb'a denk gelir.
    /// Hata olursa sessiz (zaten cached crumb hâlâ valid; expire olunca normal yol işler).
    private func warmRefresh() async throws -> (String, String) {
        defer { warmupInFlight = false }
        let result = try await refresh()
        consecutiveFailures = 0
        circuitBreakUntil = nil
        print("🔐 YahooAuth: Warm-refresh tamam — yeni crumb hazır.")
        return result
    }
    
    private func refresh() async throws -> (String, String) {
        print("🔐 YahooAuth: Refreshing Crumb & Cookie (Robust Mode V2)...")
        
        // Standard User Agent used for all requests
        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        // 1. Hit FC (Consent/Redirect) - This sets the 'A3' or 'B' cookie effectively
        // Yahoo uses this to check consent, visiting it ensures cookies are seeded.
        let fcURL = URL(string: "https://fc.yahoo.com")!
        var fcReq = URLRequest(url: fcURL)
        fcReq.setValue(ua, forHTTPHeaderField: "User-Agent")
        _ = try? await session.data(for: fcReq) // Ignore result, just want cookies
        
        // 2. Get Cookies via Quote Page (Most reliable source for session initiation)
        let cookieURL = URL(string: "https://finance.yahoo.com/quote/AAPL")!
        var cookieReq = URLRequest(url: cookieURL)
        cookieReq.setValue(ua, forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await session.data(for: cookieReq)
        
        guard (response as? HTTPURLResponse) != nil else {
            throw URLError(.badServerResponse)
        }
        
        // 3. Refresh Cookies variable from Session Storage
        if let cookies = session.configuration.httpCookieStorage?.cookies(for: cookieURL) {
            self.cookie = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }
        
        // 4. Get Crumb (Try query2 first, then query1)
        let crumbSources = [
            "https://query2.finance.yahoo.com/v1/test/getcrumb",
            "https://query1.finance.yahoo.com/v1/test/getcrumb"
        ]
        
        var acquiredCrumb: String? = nil
        
        // Short pause to let cookies settle?
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        for source in crumbSources {
            if let c = try? await fetchCrumb(from: source, userAgent: ua) {
                acquiredCrumb = c
                break
            }
        }
        
        guard let finalCrumb = acquiredCrumb else {
            print("⚠️ YahooAuth: Failed to get crumb from all sources.")
            throw URLError(.userAuthenticationRequired)
        }
        
        self.crumb = finalCrumb
        self.lastAuthTime = Date()
        
        print("✅ YahooAuth: Acquired Crumb [\(finalCrumb)]")
        return (finalCrumb, self.cookie ?? "")
    }
    
    // Helper to fetch crumb with correct headers
    private func fetchCrumb(from urlString: String, userAgent: String) async throws -> String {
        guard let url = URL(string: urlString) else { return "" }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://finance.yahoo.com/quote/AAPL", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await session.data(for: req)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
              let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return text
    }
}
