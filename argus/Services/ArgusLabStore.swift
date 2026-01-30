import Foundation

class ArgusLabStore {
    static let shared = ArgusLabStore()
    
    // In-memory logs
    private(set) var logs: [ArgusDecisionLogEntry] = []
    
    private let fileName = "argus_decision_logs.json"
    
    private init() {
        loadResult()
    }
    
    // MARK: - Public API
    
    func getAllLogs() -> [ArgusDecisionLogEntry] {
        return logs
    }
    
    func getLogs(for symbol: String) -> [ArgusDecisionLogEntry] {
        return logs.filter { $0.symbol == symbol }
    }
    
    func appendOrUpdate(_ entry: ArgusDecisionLogEntry) {
        // Prevent duplicate logging: Check if we have a log for this symbol + mode within the last 12 hours
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 3600)
        
        let hasRecentLog = logs.contains { log in
            log.symbol == entry.symbol &&
            log.mode == entry.mode &&
            log.timestamp > twelveHoursAgo
        }
        
        if hasRecentLog {
            // Update existing? Or just ignore?
            // For now, let's ignore to prevent noise, unless we specifically want to update the latest.
            print("📝 ArgusLab: Log skipped for \(entry.symbol) (\(entry.mode)) - already logged recently.")
            return
        }
        
        // Append new
        logs.append(entry)
        saveResult()
        print("✅ ArgusLab: Decision logged for \(entry.symbol) (\(entry.mode))")
    }
    
    // Update existing log with calculated returns (ID based)
    func updateLog(_ updatedLog: ArgusDecisionLogEntry) {
        if let index = logs.firstIndex(where: { $0.id == updatedLog.id }) {
            logs[index] = updatedLog
            saveResult()
        }
    }
    
    // MARK: - Persistence
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    private func saveResult() {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: getFileURL(), options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("❌ ArgusLabStore Save Error: \(error)")
        }
    }
    
    private func loadResult() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            logs = try JSONDecoder().decode([ArgusDecisionLogEntry].self, from: data)
            print("📂 ArgusLabStore loaded \(logs.count) logs.")
        } catch {
            print("❌ ArgusLabStore Load Error: \(error)")
        }
    }
}
