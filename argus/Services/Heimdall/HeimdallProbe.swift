import Foundation

/// "The Scout" - Active Probing for Capability Discovery
/// Runs on app launch or key update to determine what features are actually unlocked.
/// Prevents runtime 403s by preemptively detecting plan limits.
actor HeimdallProbe {
    static let shared = HeimdallProbe()
    
    private init() {}
    
    // MARK: - FMP Logic
    
    enum FMPMode: String {
        case full = "FULL" // Intraday + Daily
        case dailyOnly = "DAILY_ONLY" // Legacy/Starter (No Intraday)
        case locked = "LOCKED" // Auth Failed
        case unknown = "UNKNOWN"
    }
    
    func probeFMP() async -> FMPMode {
        // APIKeyStore is @MainActor, so we must await access
        let key = await APIKeyStore.shared.getKey(for: .fmp)
        
        guard let k = key, !k.isEmpty else {
            print("🕵️ Probe: FMP Key Missing. Skipping.")
            return .unknown
        }
        
        print("🕵️ Probe: Testing FMP capabilities...")
        
        // 0. Reset previous locks to allow fresh probe/fallback logic
        await ProviderCapabilityRegistry.shared.reportSuccess(provider: "FMP", field: .quote)
        await ProviderCapabilityRegistry.shared.reportSuccess(provider: "FMP", field: .candles)
        
        // 1. Test Auth (Profile)
        // Cheapest endpoint, usually available on all plans.
        let authResult = await testEndpoint(url: "https://financialmodelingprep.com/api/v3/profile/AAPL?apikey=\(k)")
        
        if case .authInvalid = authResult {
            print("🛑 Probe: FMP Auth Failed. Locking.")
            await ProviderCapabilityRegistry.shared.reportCriticalFailure(provider: "FMP", field: .profile, error: HeimdallCoreError(category: .authInvalid, code: 401, message: "Probe Auth Failed", bodyPrefix: "Auth Invalid"))
            return .locked
        }
        
        if case .serverError = authResult {
            print("⚠️ Probe: FMP Server Error. Assuming Transient.")
             // Don't lock, but downgrade mode?
        }
        
        // 2. Test Entitlement (Intraday vs Daily)
        // Try the risky endpoint that caused "Legacy Endpoint" error
        let legacyResult = await testEndpoint(url: "https://financialmodelingprep.com/api/v3/historical-chart/1hour/AAPL?apikey=\(k)")
        
        if case .entitlementDenied = legacyResult {
            print("⚠️ Probe: FMP Intraday (Legacy/1h) Denied. Mode -> DAILY_ONLY")
            // Disable Intraday endpoint specifically
            // We set a mode tag that FMPProvider can read, or we trust FMPProvider's safe default.
            return .dailyOnly
        }
        
        if case .success = legacyResult {
            print("✅ Probe: FMP Intraday OK. Mode -> FULL")
            return .full
        }
        
        // Fallback: If 1h chart failed with something else, check Daily
        let dailyResult = await testEndpoint(url: "https://financialmodelingprep.com/api/v3/historical-price-full/AAPL?timeseries=1&apikey=\(k)")
        if case .success = dailyResult {
             print("✅ Probe: FMP Daily OK. Mode -> DAILY_ONLY (Conservative)")
             return .dailyOnly
        }
        
        // Run User-Mandated Evidence Tests
        await runSmokeTests()
        
        return .unknown
    }
    
    // MARK: - Evidence / Smoke Tests
    
     private func runSmokeTests() async {
        print("\n=== 🕵️ HEIMDALL SMOKE TESTS (PROOF) ===")
        guard let k = await APIKeyStore.shared.getKey(for: .fmp) else { return }
        
        // 1. AMD 1h Candles (Legacy)
        await logEvidence(label: "TEST 1: AMD 1h Candles", url: "https://financialmodelingprep.com/api/v3/historical-chart/1hour/AMD?apikey=\(k)")
        
        // 2. SPY Quote (Standard)
        await logEvidence(label: "TEST 2: SPY Quote", url: "https://financialmodelingprep.com/api/v3/quote/SPY?apikey=\(k)")
        
        // 3. AAPL Profile (Fallback Source)
        await logEvidence(label: "TEST 3: AAPL Profile", url: "https://financialmodelingprep.com/api/v3/profile/AAPL?apikey=\(k)")
        
        // 4. TSLA News (Premium Feature Check)
        await logEvidence(label: "TEST 4: TSLA News", url: "https://financialmodelingprep.com/api/v3/stock_news?tickers=TSLA&limit=1&apikey=\(k)")
        
        // 5. MSFT Fundamentals (Income Statement)
        await logEvidence(label: "TEST 5: MSFT Fundamentals", url: "https://financialmodelingprep.com/api/v3/income-statement/MSFT?limit=1&apikey=\(k)")

        // 6. TwelveData Connectivity
        if let tdKey = await APIKeyStore.shared.getKey(for: .twelveData) {
             // Simple Quote
             await logEvidence(label: "TEST 6: TwelveData Quote (AAPL)", url: "https://api.twelvedata.com/quote?symbol=AAPL&apikey=\(tdKey)")
        } else {
             print("⚠️ Probe: TwelveData Key Missing!")
        }
        
        // 7. Finnhub Connectivity
        /*
        if let fhKey = await APIKeyStore.shared.getKey(for: .finnhub) {
             // Quote
             await logEvidence(label: "TEST 7: Finnhub Quote (AAPL)", url: "https://finnhub.io/api/v1/quote?symbol=AAPL&token=\(fhKey)")
        }
        */

        print("=== END SMOKE TESTS ===\n")
    }
    
    private func logEvidence(label: String, url: String) async {
        guard let u = URL(string: url) else { return }
        print(">> \(label)")
        // Masked URL for Log
        let masked = maskSensitiveURL(url)
        print("   URL: \(masked)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: u)
            if let h = response as? HTTPURLResponse {
                print("   STATUS: \(h.statusCode)")
            }
            if let body = String(data: data, encoding: .utf8) {
                let clean = body.replacingOccurrences(of: "\n", with: " ")
                print("   BODY: \(clean.prefix(200))...")
            }
        } catch {
            print("   ERROR: \(error)")
        }
    }
    
    // MARK: - Helper
    
    enum ProbeResult {
        case success
        case authInvalid
        case entitlementDenied
        case serverError
        case networkError
    }
    
    // MARK: - Active Key Verification (Heimdall 3.2)
    
    func verifyKey(provider: ArgusProvider, key: String) async -> (isValid: Bool, log: String) {
        var log = ""
        var isValid = false
        
        func append(_ msg: String) { log += msg + "\n" }
        append("🔍 Verifying \(provider.rawValue) key...")
        
        let urlString: String
        switch provider {
        /*case .finnhub:
            urlString = "https://finnhub.io/api/v1/quote?symbol=AAPL&token=\(key)"*/
        case .eodhd:
            urlString = "https://eodhd.com/api/real-time/AAPL.US?api_token=\(key)&fmt=json"
        case .fmp:
            urlString = "https://financialmodelingprep.com/api/v3/profile/AAPL?apikey=\(key)"
        case .twelveData:
            urlString = "https://api.twelvedata.com/quote?symbol=AAPL&apikey=\(key)"
        default:
            append("⚠️ No specific probe for \(provider). Skipping.")
            return (true, log + "Skipped.")
        }
        
        guard let url = URL(string: urlString) else {
            return (false, "Invalid URL construction.")
        }
        
        // Log Actual Request (Masked)
        append("   URL: \(maskSensitiveURL(urlString))")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let http = response as? HTTPURLResponse {
                append("   HTTP Status: \(http.statusCode)")
                append("   Content-Type: \(http.allHeaderFields["Content-Type"] ?? "Unknown")")
                
                if let str = String(data: data, encoding: .utf8) {
                    let preview = str.replacingOccurrences(of: "\n", with: " ").prefix(250)
                    append("   Body: \(preview)...")
                    
                    if http.statusCode == 200 {
                        isValid = true
                        
                        // Deep Body Check
                        if str.contains("Error Message") {
                            isValid = false
                            append("❌ API Error: 'Error Message' found.")
                        } else if str.contains("Invalid API KEY") {
                            isValid = false
                            append("❌ API Error: 'Invalid API KEY' found.")
                        } else if str.contains("daily API requests limit") {
                             // Rate Limit is NOT Invalid Key
                             isValid = true 
                             append("⚠️ Rate Limited (Daily Limit) - Key exists and is valid.")
                        } else {
                            append("✅ Probe Success.")
                        }
                    } else if http.statusCode == 429 {
                        isValid = true
                        append("⚠️ Rate Limited (429) - Key exists and is valid.")
                    } else if http.statusCode == 401 || http.statusCode == 403 {
                        isValid = false
                         append("❌ Auth Error (401/403).")
                    } else {
                        isValid = false
                        append("❌ HTTP Error \(http.statusCode).")
                    }
                }
            }
        } catch {
            append("❌ Network Error: \(error.localizedDescription)")
        }
        
        return (isValid, log)
    }

    private func testEndpoint(url: String) async -> ProbeResult {
        guard let u = URL(string: url) else { return .networkError }
        do {
            let (data, response) = try await URLSession.shared.data(from: u)
            guard let http = response as? HTTPURLResponse else { return .networkError }
            
            if http.statusCode == 200 {
                // Verify not empty/error json
                if let str = String(data: data, encoding: .utf8), str.contains("Error Message") {
                     // FMP sometimes sends 200 OK with "Error Message": "Invalid API KEY"
                     if str.contains("Invalid API KEY") { return .authInvalid }
                     if str.contains("Legacy Endpoint") { return .entitlementDenied }
                }
                return .success
            }
            
            if http.statusCode == 401 { return .authInvalid }
            if http.statusCode == 403 {
                // Check body
                if let str = String(data: data, encoding: .utf8) {
                    if str.contains("Legacy") || str.contains("Upgrade") { return .entitlementDenied }
                }
                return .authInvalid // Assume auth if not labeled legacy
            }
            if http.statusCode >= 500 { return .serverError }
            
            return .networkError
        } catch {
            return .networkError
        }
    }

    private func maskSensitiveURL(_ url: String) -> String {
        var masked = url
        let patterns = [
            "(?i)(apikey|api_key|api_token|token|auth|authorization|key)=([^&]+)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            masked = regex.stringByReplacingMatches(
                in: masked,
                range: NSRange(masked.startIndex..., in: masked),
                withTemplate: "$1=***"
            )
        }

        return masked
    }

}
