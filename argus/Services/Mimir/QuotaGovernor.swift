import Foundation

actor QuotaGovernor {
    private let config: MimirConfig
    
    // Internal State
    private var requestTimestamps: [Date] = [] // Rolling window for RPM
    private var tokenTimestamps: [(Date, Int)] = [] // Rolling window for TPM
    private var dailyUsage: Int = 0
    private var lastDayReset: Date = Date()
    
    enum Decision: String {
        case allow
        case queue
        case reject
    }
    
    init(config: MimirConfig) {
        self.config = config
    }
    
    func check(estimatedTokens: Int, priority: Int) -> Decision {
        cleanOldEntries()
        checkDailyReset()
        
        // 1. Daily Limit
        if dailyUsage + estimatedTokens > config.maxTokensPerDay {
            return .reject // Daily Budget Exhausted
        }
        
        // 2. RPM (Requests Per Minute)
        if requestTimestamps.count >= config.maxRequestsPerMinute {
            // Burst limit check could be added here, but simplest is strict RPM
            return priority <= 1 ? .queue : .reject // Queue critical, reject others
        }
        
        // 3. TPM (Tokens Per Minute)
        let currentTPM = tokenTimestamps.reduce(0) { (sum, record) in sum + record.1 }
        if currentTPM + estimatedTokens > config.maxTokensPerMinute {
             return priority <= 1 ? .queue : .reject
        }
        
        return .allow
    }
    
    /// Call this immediately BEFORE dispatching to API
    func recordDispatch(tokens: Int) {
        let now = Date()
        requestTimestamps.append(now)
        tokenTimestamps.append((now, tokens))
        dailyUsage += tokens
    }
    
    /// Call this AFTER response to correct the usage
    func correctUsage(estimated: Int, actual: Int) {
        // Adjust daily
        dailyUsage = dailyUsage - estimated + actual
        
        // Adjust TPM window (Simplified: We just accept the variance in the window for now, 
        // to avoid complex index matching. The estimate is usually safe.)
    }
    
    // MARK: - Helpers
    
    private func cleanOldEntries() {
        let windowStart = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > windowStart }
        tokenTimestamps = tokenTimestamps.filter { $0.0 > windowStart }
    }
    
    private func checkDailyReset() {
        // Reset at UTC Midnight
        let calendar = Calendar(identifier: .gregorian)
        if !calendar.isDate(lastDayReset, inSameDayAs: Date()) {
            dailyUsage = 0
            lastDayReset = Date()
            print("📅 Mimir Governor: Daily Budget Reset")
        }
    }
    
    // Inspection
    func getStats() -> (rpm: Int, tpm: Int, daily: Int) {
        cleanOldEntries()
        return (requestTimestamps.count, tokenTimestamps.reduce(0) { (sum, record) in sum + record.1 }, dailyUsage)
    }
}
