import Foundation

/// Request Coalescer
/// Responsibility: Merge concurrent identical requests into a single in-flight task.
actor RequestCoalescer {
    static let shared = RequestCoalescer()
    
    // Key -> In-Flight Task
    private var inflight: [String: Task<Any, Error>] = [:]
    // Stats for Debugging
    private var collisionStats: [String: Int] = [:]
    
    private init() {}
    
    func coalesce<T>(key: String, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        // 1. Check if already in flight
        if let existing = inflight[key] {
            trackCollision(key: key)
            // Wait for the existing task
            // We must cast the result carefully. 
            // Since we use Generics, we assume the Caller knows T matches the Key's expected type.
            // If mismatch, this will crash or throw. In a strict system, Key should include Type info.
            guard let result = try await existing.value as? T else {
                throw CoalescerInternalError.coalescerTypeMismatch
            }
            return result
        }
        
        // 2. Launch new task
        let task = Task<Any, Error> {
            return try await operation()
        }
        
        inflight[key] = task
        
        // 3. Cleanup on completion
        // We use a detached task or similar mechanism to cleanup, 
        // OR simply await and remove.
        // Better: usage of `defer` is hard with async Tasks stored in property.
        // We attach a cleanup handling via the Task itself? No.
        // We simply await it here, then remove it.
        
        do {
            let result = try await task.value
            inflight.removeValue(forKey: key)
            return result as! T
        } catch {
            inflight.removeValue(forKey: key)
            throw error
        }
    }
    
    // Debugging
    private func trackCollision(key: String) {
        collisionStats[key, default: 0] += 1
        // Optional: Print if high collision
        if collisionStats[key]! % 5 == 0 {
             print("🔥 Coalesced \(collisionStats[key]!) times for: \(key)")
        }
    }
    
    func getReport(top n: Int) -> String {
        let sorted = collisionStats.sorted { $0.value > $1.value }.prefix(n)
        return sorted.map { "\($0.key): \($0.value)x" }.joined(separator: "\n")
    }
}

enum CoalescerInternalError: Error {
    case coalescerTypeMismatch
}
