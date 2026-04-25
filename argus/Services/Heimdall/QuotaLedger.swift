import Foundation

/// "The Accountant" - Tracks API usage against limits.
final actor QuotaLedger {
    static let shared = QuotaLedger()
    
    struct QuotaMetrics: Codable, Sendable {
        var attempted: Int = 0
        var success: Int = 0
        var failed: Int = 0
        var lastSuccess: Date?
        var lastFailure: Date?
    }
    
    private static let cacheKey = "heimdall_quota_ledger_v2"
    private var metrics: [String: QuotaMetrics] = [:] // Provider -> Metrics
    private var lastReset: Date = Date()
    
    // Simple static limits (Safe Defaults)
    private let dailyLimits: [String: Int] = [
        "FMP": 50000,
        "Yahoo": 100000,
        "TwelveData": 800,
        "Finnhub": 60,
        "AlphaVantage": 25,
        "Tiingo": 50,
        "EODHD": 100000 
    ]
    
    private init() {
        // Initialize with data loaded synchronously via non-isolated helper
        let (loadedMetrics, loadedReset) = QuotaLedger.loadDataSync()
        self.metrics = loadedMetrics
        self.lastReset = loadedReset
        
        if !Calendar.current.isDateInToday(lastReset) {
            self.metrics = [:]
            self.lastReset = Date()
            QuotaLedger.saveDataSync(metrics: [:], lastReset: Date())
        }
    }
    
    // MARK: - Transactional API
    
    func recordAttempt(provider: String) {
        checkReset()
        var m = metrics[provider] ?? QuotaMetrics()
        m.attempted += 1
        metrics[provider] = m
        save() 
    }
    
    func recordSuccess(provider: String) {
        spend(provider: provider, cost: 1)
    }
    
    func recordFailure(provider: String) {
        checkReset()
        var m = metrics[provider] ?? QuotaMetrics()
        m.failed += 1
        m.lastFailure = Date()
        metrics[provider] = m
        save()
    }
    
    // For Debug Bundle
    func getSnapshot() -> [String: ProviderQuotaStatus] {
        var stats: [String: ProviderQuotaStatus] = [:]
        for (provider, limit) in dailyLimits {
            let m = metrics[provider] ?? QuotaMetrics()
            
            stats[provider] = ProviderQuotaStatus(
                attempted: m.attempted,
                success: m.success,
                failed: m.failed,
                limit: limit,
                remaining: max(0, limit - m.success),
                isExhausted: m.success >= limit
            )
        }
        return stats
    }
    
    // MARK: - Admin
    
    func canSpend(provider: String, cost: Int = 1) -> Bool {
        checkReset()
        
        guard let limit = dailyLimits[provider] else { return true } // No limit = Uncapped
        let m = metrics[provider] ?? QuotaMetrics()
        
        return (m.success + cost) <= limit
    }

    func isExhausted(provider: String) -> Bool {
        checkReset()
        guard let limit = dailyLimits[provider] else { return false }
        let m = metrics[provider] ?? QuotaMetrics()
        return m.success >= limit
    }
    
    func spend(provider: String, cost: Int = 1) {
        checkReset()
        var m = metrics[provider] ?? QuotaMetrics()
        m.success += cost
        m.lastSuccess = Date()
        metrics[provider] = m
        save()
    }
    
    func reset(provider: String) {
        checkReset()
        metrics.removeValue(forKey: provider)
        save()
        print("🟢 QuotaLedger: Reset metrics for \(provider)")
    }
    
    // MARK: - Internal Logic
    
    private func checkReset() {
        if !Calendar.current.isDateInToday(lastReset) {
            print("📅 QuotaLedger: New Day Detected. Resetting Daily Limits.")
            metrics.removeAll()
            lastReset = Date()
            save()
        }
    }
    
    private func save() {
         QuotaLedger.saveDataSync(metrics: metrics, lastReset: lastReset)
    }
    
    private nonisolated static func saveDataSync(metrics: [String: QuotaMetrics], lastReset: Date) {
         if let data = try? JSONEncoder().encode(metrics) {
             UserDefaults.standard.set(data, forKey: cacheKey)
             UserDefaults.standard.set(lastReset, forKey: "\(cacheKey)_date")
         }
    }
    
    private nonisolated static func loadDataSync() -> ([String: QuotaMetrics], Date) {
        var rDate = Date()
        var rMetrics: [String: QuotaMetrics] = [:]
        
        if let date = UserDefaults.standard.object(forKey: "\(cacheKey)_date") as? Date {
            rDate = date
        }
        
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([String: QuotaMetrics].self, from: data) {
            rMetrics = decoded
        }
        return (rMetrics, rDate)
    }
}
