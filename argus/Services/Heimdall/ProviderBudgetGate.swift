import Foundation

/// Central Backpressure Gate for Heimdall Providers.
/// Enforces Concurrency Limits and Global Quarantines (Minute Limits).
actor ProviderBudgetGate {
    static let shared = ProviderBudgetGate()
    
    enum GateStatus {
        case open
        case rateLimited(resetAt: Date)
        case quarantined(until: Date, reason: String)
    }
    
    private var providerStatus: [String: GateStatus] = [:]
    private var activeRequests: [String: Int] = [:]
    private var lastGrantTime: [String: Date] = [:] // For MinSpacing
    
    // Config
    private let maxConcurrentTwelveData = 1
    private let minSpacingTwelveData: TimeInterval = 10.0 // 6 requests/min max to stay safe
    
    private init() {}
    
    /// Acquires permission to use a provider.
    /// Throws `HeimdallCoreError.rateLimited` if blocked.
    /// May wait (sleep) if throttling is needed.
    func acquire(provider: String) async throws {
        // 1. Check Status (Hard Lock)
        if let status = providerStatus[provider] {
            switch status {
            case .rateLimited(let resetAt):
                if Date() < resetAt {
                    throw HeimdallCoreError(category: .rateLimited, code: 429, message: "Rate Limit Locked. Reset at \(resetAt)", bodyPrefix: "")
                } else {
                    providerStatus[provider] = .open
                }
                
            case .quarantined(let until, let reason):
                if Date() < until {
                    throw HeimdallCoreError(category: .circuitOpen, code: 503, message: "Quarantined: \(reason)", bodyPrefix: "")
                } else {
                    providerStatus[provider] = .open
                }
                
            case .open:
                break
            }
        }
        
        // 2. Check Concurrency
        let current = activeRequests[provider] ?? 0
        
        if provider == "TwelveData" {
            if current >= maxConcurrentTwelveData {
                throw HeimdallCoreError(category: .rateLimited, code: 429, message: "Max Concurrency (1) Reached for TwelveData", bodyPrefix: "")
            }
            
            // 3. Check Spacing (Throttling)
            if let last = lastGrantTime[provider] {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < minSpacingTwelveData {
                    let waitTime = minSpacingTwelveData - elapsed
                    print("⏳ Gate: Throttling \(provider) for \(String(format: "%.1f", waitTime))s")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        
        // Grant
        activeRequests[provider] = current + 1
        lastGrantTime[provider] = Date()
    }
    
    /// Releases the budget slot. Must be called in `defer`.
    func release(provider: String) {
        let current = activeRequests[provider] ?? 0
        if current > 0 {
            activeRequests[provider] = current - 1
        }
    }
    
    /// Hard locks the provider for a duration (default 70s for minute limit).
    func tripMinuteLimit(_ provider: String, duration: TimeInterval = 70) {
        let resetTime = Date().addingTimeInterval(duration)
        print("⛔️ Gate: Tripping Limit for \(provider). Locked for \(duration)s until \(resetTime)")
        providerStatus[provider] = .rateLimited(resetAt: resetTime)
        
        // Clear active requests count to allow recovery after reset?
        // No, release() should handle it. But if we are tripping, maybe we should force reset?
        // activeRequests[provider] = 0 // Risky if jobs are still running.
    }
    
    /// Short ban for server instability (e.g. 60s)
    func quarantine(_ provider: String, seconds: TimeInterval, reason: String) {
        let until = Date().addingTimeInterval(seconds)
        print("⚠️ Gate: Quarantining \(provider) for \(seconds)s. Reason: \(reason)")
        providerStatus[provider] = .quarantined(until: until, reason: reason)
    }
}
