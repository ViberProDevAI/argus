import Foundation
import Combine

// MARK: - Models

struct ProviderCallLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let provider: String        // "EODHD", "TwelveData", "Finnhub", "AlphaVantage"
    let field: String           // "dailyPrice", "candles", "fundamentals", "news", "etfHoldings"
    let symbol: String
    let durationMs: Int         // request duration in milliseconds
    let success: Bool
    let errorCode: String?      // "rate_limit", "network", "empty", "unknown", nil if success
    
    init(provider: String, field: String, symbol: String, durationMs: Int, success: Bool, errorCode: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.provider = provider
        self.field = field
        self.symbol = symbol
        self.durationMs = durationMs
        self.success = success
        self.errorCode = errorCode
    }
}

struct ProviderFieldStats: Identifiable {
    let id = UUID()
    let provider: String
    let field: String
    let requestCount: Int
    let successRate: Double   // 0–100
    let avgLatencyMs: Double
}

// MARK: - Store

final class ArgusProviderStatsStore: ObservableObject {
    static let shared = ArgusProviderStatsStore()
    
    @Published private(set) var logs: [ProviderCallLog] = []
    
    private let fileName = "argus_provider_logs.json"
    private let maxLogCount = 10_000
    private let queue = DispatchQueue(label: "com.argus.providerStatsQueue", qos: .background)
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func addLog(_ log: ProviderCallLog) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.logs.append(log)
                
                // Trim if needed
                if self.logs.count > self.maxLogCount {
                    // Remove oldest (first elements)
                    let excess = self.logs.count - self.maxLogCount
                    self.logs.removeFirst(excess)
                }
                
                self.saveToDisk()
            }
        }
    }
    
    func clearAll() {
        logs.removeAll()
        saveToDisk()
    }
    
    /// Calculate stats for the last N days
    func stats(forLastDays days: Int, field: String? = nil) -> [ProviderFieldStats] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let filteredLogs = logs.filter { log in
            log.timestamp >= cutoff && (field == nil || log.field == field)
        }
        
        // Group by (Provider, Field)
        // Key: "Provider|Field"
        var groups: [String: [ProviderCallLog]] = [:]
        
        for log in filteredLogs {
            let key = "\(log.provider)|\(log.field)"
            groups[key, default: []].append(log)
        }
        
        var results: [ProviderFieldStats] = []
        
        for (key, groupLogs) in groups {
            let components = key.split(separator: "|")
            guard components.count == 2 else { continue }
            let provider = String(components[0])
            let fieldName = String(components[1])
            
            let total = groupLogs.count
            let successCount = groupLogs.filter { $0.success }.count
            let totalDuration = groupLogs.reduce(0) { $0 + $1.durationMs }
            
            let rate = total > 0 ? (Double(successCount) / Double(total) * 100.0) : 0.0
            let avg = total > 0 ? (Double(totalDuration) / Double(total)) : 0.0
            
            results.append(ProviderFieldStats(
                provider: provider,
                field: fieldName,
                requestCount: total,
                successRate: rate,
                avgLatencyMs: avg
            ))
        }
        
        // Sort: Field stats -> Provider results usually handy to see side-by-side
        // But the View will likely group them. Let's sort by Field then Provider
        return results.sorted {
            if $0.field == $1.field {
                return $0.provider < $1.provider
            }
            return $0.field < $1.field
        }
    }
    
    // MARK: - Persistence
    
    private func getFileURL() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documents.appendingPathComponent(fileName)
    }
    
    private func saveToDisk() {
        guard let url = getFileURL() else { return }
        
        // Perform encoding in background to assume UI not blocked if large
        // But for <10k items json encoding is fast enough on main mostly.
        // Let's do it safely.
        let logsToSave = logs
        
        queue.async {
            do {
                let data = try JSONEncoder().encode(logsToSave)
                try data.write(to: url)
            } catch {
                print("❌ ArgusProviderStatsStore Save Error: \(error)")
            }
        }
    }
    
    private func loadFromDisk() {
        guard let url = getFileURL() else { return }
        
        // Read synchronously at startup or async?
        // ObservableObject init runs on creation. Safe to read.
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([ProviderCallLog].self, from: data)
                self.logs = decoded
            } catch {
                print("❌ ArgusProviderStatsStore Load Error: \(error)")
            }
        }
    }
}
