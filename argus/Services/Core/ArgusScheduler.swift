import Foundation

/// "The Traffic Police"
/// Manages concurrency limits and task prioritization to prevent UI freeze and rate limit hits.
actor ArgusScheduler {
    static let shared = ArgusScheduler()
    
    private var maxConcurrentTasks = 6
    private var currentTasks = 0
    private var queue: [ScheduledTask] = []
    
    // Dedup / Coalescing State
    // We store 'Task' handles for in-flight requests to allow coalescing.
    // Key: "Provider_Endpoint_Symbol_Range"
    private var inFlightRequests: [String: Task<Any, Error>] = [:]
    
    struct ScheduledTask {
        let id: UUID
        let priority: Int // 0 (Critical) - 5 (Background)
        let continuation: CheckedContinuation<Void, Never>
    }
    
    // MARK: - API
    
    /// Waits for a slot in the scheduler based on priority.
    /// Call this before starting a heavy network operation.
    func waitSlot(priority: Int) async {
        if currentTasks < maxConcurrentTasks {
            currentTasks += 1
            return // Use slot immediately
        }
        
        await withCheckedContinuation { continuation in
            let task = ScheduledTask(id: UUID(), priority: priority, continuation: continuation)
            queue.append(task)
            queue.sort { $0.priority < $1.priority }
        }
    }
    
    func signalDone() {
        if !queue.isEmpty {
            // Give slot to next high priority
            let next = queue.removeFirst()
            next.continuation.resume()
        } else {
            currentTasks -= 1
        }
    }
    
    // MARK: - Deduplication / Coalescing
    
    /// Executes a work item with deduplication. If a request with the same key is in flight, returns the existing task's result.
    func deduplicatedRequest<T>(key: String, priority: Int, work: @escaping () async throws -> T) async throws -> T {
        // 1. Check In-Flight
        if let existing = inFlightRequests[key] {
            print("⚡ ArgusScheduler: Dedup Hit for \(key)")
            // Await the existing task (unsafe cast required, assume T matches key)
            // Note: This relies on the caller ensuring Key maps to T uniquely.
            do {
                let result = try await existing.value
                return result as! T
            } catch {
                throw error
            }
        }
        
        // 2. Schedule New
        let task = Task {
            await waitSlot(priority: priority)
            defer { signalDone() }
            return try await work()
        }
        
        inFlightRequests[key] = Util.safeCast(task) // storing as Task<Any, Error>
        
        // 3. Cleanup on finish
        defer {
            inFlightRequests.removeValue(forKey: key)
        }
        
        let result = try await task.value
        return result
    }
    
    // Helper to erase type for storage
    private struct Util {
        static func safeCast<U>(_ task: Task<U, Error>) -> Task<Any, Error> {
             return Task<Any, Error> {
                 let v = try await task.value
                 return v as Any
             }
        }
    }
}
