import Foundation

public actor MimirService {
    public static let shared = MimirService()
    
    private let config: MimirConfig
    private let governor: QuotaGovernor
    private let circuit: CircuitBreaker
    private let cache: MimirCache
    private let queue: MimirQueue
    private let gateway: MimirLLMGateway
    
    private init() {
        let conf = MimirConfig.standard // Should load from overrides
        self.config = conf
        self.governor = QuotaGovernor(config: conf)
        self.circuit = CircuitBreaker(config: conf)
        self.cache = MimirCache(config: conf)
        self.queue = MimirQueue()
        self.gateway = MimirLLMGateway()
    }
    
    // Injectable Init for Tests
    init(config: MimirConfig, gateway: MimirLLMGateway) {
        self.config = config
        self.governor = QuotaGovernor(config: config)
        self.circuit = CircuitBreaker(config: config)
        self.cache = MimirCache(config: config)
        self.queue = MimirQueue()
        self.gateway = gateway
    }
    
    public func submit(_ task: MimirTask) async -> MimirResult {
        // 1. Cache Check
        let cacheKey = MimirCache.generateKey(task: task)
        if let cached = await cache.get(key: cacheKey, ttlOverride: task.ttlSeconds) {
            log("CACHED", task, 0, "HIT", "CLOSED")
            return cached
        }
        
        // 2. Circuit Breaker Check
        if await !circuit.canRequest() {
            log("REJECT", task, 0, "MISS", "OPEN")
            // Fallback Degraded
            return MimirResult(taskId: task.id, status: .degraded, modelUsed: nil, json: nil, explanation: "Circuit Open", timestamp: Date())
        }
        
        // 3. Token Estimation & Quota Check
        let estTok = TokenEstimator.estimate(inputs: task.inputs)
        let decision = await governor.check(estimatedTokens: estTok, priority: task.priority)
        
        if decision == .reject {
             log("REJECT", task, estTok, "MISS", "CLOSED")
             return MimirResult.error(id: task.id, message: "Quota Exceeded")
        }
        
        if decision == .queue {
             await queue.enqueue(task)
             log("QUEUED", task, estTok, "MISS", "CLOSED")
             // In real impl, a background worker would process queue. 
             // For now, return queued status immediately so caller knows to wait or retry.
             return MimirResult(taskId: task.id, status: .queued, modelUsed: nil, json: nil, explanation: "Rate Limited - Queued", timestamp: Date())
        }
        
        // 4. Execution (Allow)
        await governor.recordDispatch(tokens: estTok)
        log("CALL", task, estTok, "MISS", await circuit.getState())
        
        do {
            let result = try await gateway.execute(task: task, model: config.modelPrimary)
            await circuit.reportSuccess()
            
            // Update Cache & Quota Correction (Not implemented yet, expensive to count tokens on response)
            await cache.set(key: cacheKey, result: result)
            
            return result
        } catch {
            await circuit.reportFailure()
            // Error handling?
            return MimirResult.error(id: task.id, message: "Gateway Error: \(error.localizedDescription)")
        }
    }
    
    private func log(_ dec: String, _ task: MimirTask, _ est: Int, _ c: String, _ cb: String) {
        Task {
            let stats = await governor.getStats()
            MimirLogger.log(decision: dec, task: task, model: config.modelPrimary, estTok: est, rpm: stats.rpm, tpm: stats.tpm, cache: c, cb: cb)
            
            // Visual Activity Log
            let type: MimirActivityLog.Entry.EntryType
            if dec == "REJECT" { type = .failure }
            else if dec == "CACHED" { type = .success }
            else { type = .info }
            
            await MimirActivityLog.shared.log("[\(dec)] \(task.type.rawValue) - Tokens: \(est)", type: type)
        }
    }
}
