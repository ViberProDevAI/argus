import Foundation

actor MimirQueue {
    // Priority 0 (Highest) to Priority 3 (Lowest)
    private var queues: [[MimirTask]] = [[], [], [], []]
    
    func enqueue(_ task: MimirTask) {
        let p = max(0, min(3, task.priority))
        queues[p].append(task)
    }
    
    func dequeue() -> MimirTask? {
        // Check highest priority first
        for p in 0...3 {
            if !queues[p].isEmpty {
                return queues[p].removeFirst()
            }
        }
        return nil
    }
    
    func count() -> Int {
        return queues.reduce(0) { $0 + $1.count }
    }
}
