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
        
        // 1. Check Cache (1 Hour TTL)
        if let c = crumb, let k = cookie, let t = lastAuthTime, -t.timeIntervalSinceNow < 3600 {
            return (c, k)
        }
        
        // 2. Refresh
        do {
            let result = try await refresh()
            // Success: Reset breaker
            consecutiveFailures = 0
            circuitBreakUntil = nil
            return result
        } catch {
            // Failure: Increment breaker
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
    }
    
    /// Invalidate cached crumb (call this on 401 errors)
    func invalidate() {
        print("🔐 YahooAuth: Invalidating Crumb Cache")
        self.crumb = nil
        self.cookie = nil
        self.lastAuthTime = nil
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
