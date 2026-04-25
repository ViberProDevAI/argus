import Foundation

/// Manages the "Budget" for a specific Phoenix Run.
/// Prevents runaway API costs.
final class HeimdallBudgetManager {
    // Mode Configuration
    struct BudgetConfig {
        let maxRequests: Int
        let maxHeavyRequests: Int // e.g. Full Fundamentals
        let maxRetries: Int
        let timeoutSeconds: TimeInterval
    }
    
    // Current State
    private(set) var requestsUsed: Int = 0
    private(set) var heavyRequestsUsed: Int = 0
    private(set) var retriesUsed: Int = 0
    private let startTime: Date
    
    private let config: BudgetConfig
    
    init(mode: PhoenixScanMode) {
        self.startTime = Date()
        
        switch mode {
        case .saver:
            self.config = BudgetConfig(maxRequests: 40, maxHeavyRequests: 5, maxRetries: 1, timeoutSeconds: 30)
        case .balanced:
            self.config = BudgetConfig(maxRequests: 90, maxHeavyRequests: 15, maxRetries: 2, timeoutSeconds: 60)
        case .aggressive:
            self.config = BudgetConfig(maxRequests: 160, maxHeavyRequests: 30, maxRetries: 3, timeoutSeconds: 120)
        }
    }
    
    // Check if we can proceed
    func canSpend(isHeavy: Bool = false) -> Bool {
        // 1. Time Check
        if Date().timeIntervalSince(startTime) > config.timeoutSeconds {
            print("🛑 Heimdall Budget: Time Limit Exceeded.")
            return false
        }
        
        // 2. Request Check
        if requestsUsed >= config.maxRequests {
            print("🛑 Heimdall Budget: Request Limit Exceeded (\(requestsUsed)/\(config.maxRequests)).")
            return false
        }
        
        // 3. Heavy Check
        if isHeavy && heavyRequestsUsed >= config.maxHeavyRequests {
            print("🛑 Heimdall Budget: Heavy Request Limit Exceeded.")
            return false
        }
        
        return true
    }
    
    // Log spending
    func spend(isHeavy: Bool = false) {
        requestsUsed += 1
        if isHeavy {
            heavyRequestsUsed += 1
        }
    }
    
    func recordRetry() {
        retriesUsed += 1
    }
    
    func remainingRequests() -> Int {
        return max(0, config.maxRequests - requestsUsed)
    }
    
    func snapshot() -> String {
        return "Req: \(requestsUsed)/\(config.maxRequests) | Heavy: \(heavyRequestsUsed)/\(config.maxHeavyRequests) | Time: \(Int(Date().timeIntervalSince(startTime)))s/\(Int(config.timeoutSeconds))s"
    }
}
