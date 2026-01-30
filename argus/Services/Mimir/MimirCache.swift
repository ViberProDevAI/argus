import Foundation

actor MimirCache {
    private let config: MimirConfig
    // Key -> (Result, timestamp)
    private var storage: [String: (MimirResult, Date)] = [:]
    
    init(config: MimirConfig) {
        self.config = config
    }
    
    func get(key: String, ttlOverride: Int?) -> MimirResult? {
        guard let (result, ts) = storage[key] else { return nil }
        
        // TTL Check
        let ttl = Double(ttlOverride ?? config.defaultTTLSeconds)
        if -ts.timeIntervalSinceNow > ttl {
            storage.removeValue(forKey: key)
            return nil
        }
        
        // Return cached version with updated status
        return MimirResult(
            taskId: result.taskId,
            status: .cached,
            modelUsed: result.modelUsed,
            json: result.json,
            explanation: result.explanation,
            timestamp: Date()
        )
    }
    
    func set(key: String, result: MimirResult) {
        storage[key] = (result, Date())
        
        // Cleanup if too big (simple prune)
        if storage.count > 100 {
            let sorted = storage.sorted { $0.value.1 < $1.value.1 }
            // Remove oldest 20
            for i in 0..<20 {
                storage.removeValue(forKey: sorted[i].key)
            }
        }
    }
    
    static func generateKey(task: MimirTask) -> String {
        // Key = Type + SortedInputsHash
        let inputStr = task.inputs.sorted(by: { $0.key < $1.key }).description
        let hash = inputStr.hashValue
        return "\(task.type.rawValue)-\(hash)"
    }
}
