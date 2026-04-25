import Foundation

// MARK: - Heimdall Circuit Breaker
/// Provider-based circuit breaker for Heimdall data fabric
/// Prevents cascading failures when a provider is down

actor HeimdallCircuitBreaker {
    static let shared = HeimdallCircuitBreaker()
    
    // MARK: - State per Provider
    private var states: [String: CircuitState] = [:]
    
    // MARK: - Configuration
    struct Config {
        let failureThreshold: Int = 5          // 5 hata → OPEN
        let successThreshold: Int = 2          // 2 başarı → CLOSED
        let openTimeout: TimeInterval = 60     // 1 dk sonra HALF_OPEN
        let resetTimeout: TimeInterval = 300   // 5 dk sonra otomatik reset
    }
    
    private let config = Config()
    
    private init() {
        // This initializer is guaranteed not to throw or fail.
    }
    
    // MARK: - Circuit State
    
    enum State: String, Sendable {
        case closed = "CLOSED"       // Normal - istekler geçiyor
        case open = "OPEN"           // Bloklu - istekler reddediliyor
        case halfOpen = "HALF_OPEN"  // Test - tek istek izinli
    }
    
    struct CircuitState: Sendable {
        var state: State = .closed
        var failureCount: Int = 0
        var successCount: Int = 0
        var lastFailureTime: Date?
        var lastStateChange: Date = Date()
    }
    
    // MARK: - Public API
    
    /// İstek yapmadan önce kontrol et
    func canRequest(provider: String) -> Bool {
        var circuit = states[provider] ?? CircuitState()
        
        switch circuit.state {
        case .closed:
            return true
            
        case .open:
            // Cooldown süresi geçti mi?
            if let lastFail = circuit.lastFailureTime,
               Date().timeIntervalSince(lastFail) > config.openTimeout {
                circuit.state = .halfOpen
                circuit.lastStateChange = Date()
                states[provider] = circuit
                
                Task {
                    await HeimdallLogger.shared.info(
                        "circuit_state_change",
                        provider: provider,
                        endpoint: "→ HALF_OPEN"
                    )
                }
                return true
            }
            return false
            
        case .halfOpen:
            // Sadece tek istek izinli (actor isolation bunu sağlar)
            return true
        }
    }
    
    /// Başarılı istek sonrası
    func reportSuccess(provider: String) {
        var circuit = states[provider] ?? CircuitState()
        
        switch circuit.state {
        case .halfOpen:
            circuit.successCount += 1
            if circuit.successCount >= config.successThreshold {
                circuit.state = .closed
                circuit.failureCount = 0
                circuit.successCount = 0
                circuit.lastStateChange = Date()
                
                Task {
                    await HeimdallLogger.shared.info(
                        "circuit_state_change",
                        provider: provider,
                        endpoint: "→ CLOSED (Restored)"
                    )
                }
            }
            
        case .closed:
            // Reset failure counter on stable success
            circuit.failureCount = 0
            
        case .open:
            break // Should not happen
        }
        
        states[provider] = circuit
    }
    
    /// Başarısız istek sonrası
    func reportFailure(provider: String, error: Error, isCritical: Bool = false) {
        var circuit = states[provider] ?? CircuitState()
        
        circuit.failureCount += 1
        circuit.lastFailureTime = Date()
        
        // Error classification
        let errorClass = classifyError(error)
        
        switch circuit.state {
        case .halfOpen:
            // Half-open'da hata = tekrar aç
            circuit.state = .open
            circuit.successCount = 0
            circuit.lastStateChange = Date()
            
            Task {
                await HeimdallLogger.shared.warn(
                    "circuit_state_change",
                    provider: provider,
                    errorClass: errorClass,
                    errorMessage: "→ OPEN (Half-Open Failed)"
                )
            }
            
        case .closed:
            // Threshold aşıldı veya kritik hata
            if circuit.failureCount >= config.failureThreshold || isCritical {
                circuit.state = .open
                circuit.lastStateChange = Date()
                
                Task {
                    await HeimdallLogger.shared.warn(
                        "circuit_state_change",
                        provider: provider,
                        errorClass: errorClass,
                        errorMessage: "→ OPEN (Threshold: \(circuit.failureCount))"
                    )
                }
            }
            
        case .open:
            // Already open, just update failure time
            break
        }
        
        states[provider] = circuit
    }
    
    /// Manuel reset
    func reset(provider: String) {
        states[provider] = CircuitState()
        
        Task {
            await HeimdallLogger.shared.info(
                "circuit_reset",
                provider: provider
            )
        }
    }
    
    /// Tüm provider'ları reset
    func resetAll() {
        states.removeAll()
    }
    
    // MARK: - Status Queries
    
    func getState(provider: String) -> State {
        states[provider]?.state ?? .closed
    }
    
    func getStatus(provider: String) -> CircuitStatus {
        let circuit = states[provider] ?? CircuitState()
        return CircuitStatus(
            provider: provider,
            state: circuit.state,
            failureCount: circuit.failureCount,
            lastFailure: circuit.lastFailureTime,
            lastStateChange: circuit.lastStateChange
        )
    }
    
    func getAllStatuses() -> [CircuitStatus] {
        states.map { (provider, circuit) in
            CircuitStatus(
                provider: provider,
                state: circuit.state,
                failureCount: circuit.failureCount,
                lastFailure: circuit.lastFailureTime,
                lastStateChange: circuit.lastStateChange
            )
        }
    }
    
    // MARK: - Error Classification
    
    private func classifyError(_ error: Error) -> String {
        if let heimdallError = error as? HeimdallCoreError {
            return heimdallError.category.rawValue
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return "timeout"
            case .notConnectedToInternet: return "network"
            case .userAuthenticationRequired: return "auth"
            default: return "network"
            }
        }
        
        return "unknown"
    }
}

// MARK: - Circuit Status (for UI)

struct CircuitStatus: Identifiable, Sendable {
    let id = UUID()
    let provider: String
    let state: HeimdallCircuitBreaker.State
    let failureCount: Int
    let lastFailure: Date?
    let lastStateChange: Date
    
    var stateColor: String {
        switch state {
        case .closed: return "green"
        case .open: return "red"
        case .halfOpen: return "yellow"
        }
    }
    
    var displayState: String {
        switch state {
        case .closed: return "✅ Normal"
        case .open: return "🔴 Bloklu"
        case .halfOpen: return "🟡 Test"
        }
    }
}

