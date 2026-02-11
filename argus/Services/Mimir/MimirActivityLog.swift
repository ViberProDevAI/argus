import Foundation

/// Ring Buffer for Mimir Activity visibility
actor MimirActivityLog {
    static let shared = MimirActivityLog()
    
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let details: String
        let type: EntryType
        
        enum EntryType: String, Sendable {
            case info = "INFO"
            case warning = "WARN"
            case success = "SUCCESS"
            case failure = "FAIL"
        }
    }
    
    private var logs: [Entry] = []
    private let maxLogs = 50
    
    private init() {}
    
    func log(_ message: String, type: Entry.EntryType = .info) {
        let entry = Entry(timestamp: Date(), details: message, type: type)
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst()
        }
    }
    
    func getLogs() -> [Entry] {
        return logs.reversed()
    }
}
