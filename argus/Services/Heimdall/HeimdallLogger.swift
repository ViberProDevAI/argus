import Foundation

// MARK: - Heimdall Logger
/// Structured JSON logging for Heimdall data fabric
/// Provides observability without overwhelming console output

actor HeimdallLogger {
    static let shared = HeimdallLogger()
    
    // MARK: - Configuration
    private let isEnabled: Bool = true
    private let logLevel: LogLevel = .info
    private var recentLogs: [HeimdallLogEntry] = []
    private let maxRecentLogs = 100
    
    enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warn = 2
        case error = 3
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    func log(_ entry: HeimdallLogEntry) {
        guard isEnabled, entry.level >= logLevel else { return }
        
        // Store for recent logs view
        recentLogs.append(entry)
        if recentLogs.count > maxRecentLogs {
            recentLogs.removeFirst()
        }
        
        // Console output (structured)
        if let json = entry.jsonString {
            let emoji = entry.level.emoji
            print("\(emoji) \(json)")
        }
    }
    
    // Convenience methods
    func info(_ event: String, provider: String, endpoint: String? = nil, symbol: String? = nil, latencyMs: Int? = nil) {
        log(HeimdallLogEntry(
            level: .info,
            event: event,
            provider: provider,
            endpoint: endpoint,
            symbol: symbol,
            success: true,
            latencyMs: latencyMs
        ))
    }
    
    func warn(_ event: String, provider: String, errorClass: String, errorMessage: String? = nil, endpoint: String? = nil) {
        log(HeimdallLogEntry(
            level: .warn,
            event: event,
            provider: provider,
            endpoint: endpoint,
            success: false,
            errorClass: errorClass,
            errorMessage: errorMessage
        ))
    }
    
    func error(_ event: String, provider: String, errorClass: String, errorMessage: String, endpoint: String? = nil) {
        log(HeimdallLogEntry(
            level: .error,
            event: event,
            provider: provider,
            endpoint: endpoint,
            success: false,
            errorClass: errorClass,
            errorMessage: errorMessage
        ))
    }
    
    // MARK: - Recent Logs Access
    
    func getRecentLogs(limit: Int = 50) -> [HeimdallLogEntry] {
        Array(recentLogs.suffix(limit))
    }
    
    func getRecentErrors(limit: Int = 20) -> [HeimdallLogEntry] {
        recentLogs.filter { $0.level >= .warn }.suffix(limit).reversed()
    }
    
    func clearLogs() {
        recentLogs.removeAll()
    }
}

// MARK: - Log Entry Model

struct HeimdallLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: HeimdallLogger.LogLevel
    let event: String
    let provider: String
    let endpoint: String?
    let symbol: String?
    let success: Bool
    let errorClass: String?
    let errorMessage: String?
    let latencyMs: Int?
    let quotaRemaining: Int?
    let retryScheduled: Bool?
    let nextRetryAt: Date?
    
    init(
        level: HeimdallLogger.LogLevel,
        event: String,
        provider: String,
        endpoint: String? = nil,
        symbol: String? = nil,
        success: Bool = true,
        errorClass: String? = nil,
        errorMessage: String? = nil,
        latencyMs: Int? = nil,
        quotaRemaining: Int? = nil,
        retryScheduled: Bool? = nil,
        nextRetryAt: Date? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.event = event
        self.provider = provider
        self.endpoint = endpoint
        self.symbol = symbol
        self.success = success
        self.errorClass = errorClass
        self.errorMessage = errorMessage
        self.latencyMs = latencyMs
        self.quotaRemaining = quotaRemaining
        self.retryScheduled = retryScheduled
        self.nextRetryAt = nextRetryAt
    }
    
    var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // UI Display
    var displayMessage: String {
        if success {
            return "✅ \(event): \(provider)\(symbol.map { " (\($0))" } ?? "")"
        } else {
            return "❌ \(event): \(errorClass ?? "unknown") - \(errorMessage ?? "")"
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - LogLevel Codable + Emoji

extension HeimdallLogger.LogLevel: Codable {
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "📊"
        case .warn: return "⚠️"
        case .error: return "🚨"
        }
    }
    
    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warn: return "WARN"
        case .error: return "ERROR"
        }
    }
}
