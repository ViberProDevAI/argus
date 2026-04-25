import Foundation

actor CircuitBreaker {
    private let config: MimirConfig
    
    enum State: String {
        case closed     // Normal
        case open       // Blocked
        case halfOpen   // Testing
    }
    
    private var state: State = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    
    init(config: MimirConfig) {
        self.config = config
    }
    
    func canRequest() -> Bool {
        switch state {
        case .closed:
            return true
            
        case .open:
            // Check cooldown
            if let last = lastFailureTime, -last.timeIntervalSinceNow > Double(config.circuitBreakerOpenSeconds) {
                state = .halfOpen
                print("⚡️ Mimir Circuit: Half-Open via Cooldown")
                return true
            }
            return false
            
        case .halfOpen:
            // Only allow one request at a time (simplified: allow, rely on sequential processing provided by Actor isolation)
            return true
        }
    }
    
    func reportSuccess() {
        if state == .halfOpen {
            state = .closed
            failureCount = 0
            print("⚡️ Mimir Circuit: Closed (Restored)")
        } else if state == .closed {
            failureCount = 0 // Reset burst counter on stable success
        }
    }
    
    func reportFailure(isCritical: Bool = false) {
        failureCount += 1
        lastFailureTime = Date()
        
        if state == .halfOpen {
            state = .open
            print("⚡️ Mimir Circuit: Re-Opened (Half-Open Fail)")
        }
        else if state == .closed && (failureCount >= config.circuitBreakerThreshold || isCritical) {
            state = .open
            print("⚡️ Mimir Circuit: Opened (Fail Threshold)")
        }
    }
    
    func getState() -> String {
        return state.rawValue.uppercased()
    }
}
