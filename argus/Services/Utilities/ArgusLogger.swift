import Foundation
import OSLog

// MARK: - Argus Logger
/// Centralized logging system for the entire application.
/// Replaces scattered print statements with structured, rigorous logging.
/// Supports log levels, categorization, and optional persistence.

actor ArgusLogger {
    static let shared = ArgusLogger()
    
    // MARK: - Configuration
    private var isEnabled: Bool = true
    #if DEBUG
    private var minLogLevel: LogLevel = .debug
    #else
    private var minLogLevel: LogLevel = .warning // Production: only warnings and above
    #endif
    
    // In-memory buffer for UI display (e.g. Debug Console)
    private var recentLogs: [ArgusLogEntry] = []
    private let maxBufferSize = 200
    
    // OSLog for unified logging system
    private let osLog = OSLog(subsystem: "com.argus.trading", category: "Argus")
    
    enum LogLevel: Int, Comparable, Codable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "🚨"
            case .critical: return "🔥"
            }
        }
        
        var label: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "FATAL"
            }
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    func log(_ message: String, level: LogLevel, category: String, metadata: [String: String]? = nil) {
        guard isEnabled, level >= minLogLevel else { return }
        
        let entry = ArgusLogEntry(
            timestamp: Date(),
            level: level,
            category: category.uppercased(),
            message: message,
            metadata: metadata
        )
        
        // 1. Add to Buffer
        recentLogs.append(entry)
        if recentLogs.count > maxBufferSize {
            recentLogs.removeFirst()
        }
        
        // 2. OSLog (Unified Logging System) - Production safe
        let logMessage = "[\(entry.category)] \(message)"
        os_log(level.osLogType, log: osLog, "%{public}@", logMessage)
        
        // 3. Debug Console Output (DEBUG builds only)
        #if DEBUG
        let timeStr = DateFormatter.localizedString(from: entry.timestamp, dateStyle: .none, timeStyle: .medium)
        var consoleMsg = "[\(timeStr)] \(level.emoji) [\(entry.category)] \(message)"
        
        if let metadata = metadata, !metadata.isEmpty {
            let safeMetadata = metadata.mapValues { maskSensitiveData($0) }
            consoleMsg += " | \(safeMetadata.description)"
        }
        
        // Only use print in DEBUG builds
        Swift.print(consoleMsg)
        #endif
    }
    
    /// Masks potentially sensitive data in logs
    private func maskSensitiveData(_ value: String) -> String {
        // Mask API keys
        if value.count > 20 && (value.contains("key") || value.contains("token")) {
            return value.prefix(4) + "..." + value.suffix(4)
        }
        // Mask long numeric strings (potential IDs)
        if value.count > 15 && value.allSatisfy({ $0.isNumber }) {
            return value.prefix(4) + "..." + value.suffix(4)
        }
        return value
    }
    
    // Convenience Methods
    func debug(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .debug, category: category, metadata: metadata)
    }
    
    func info(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .info, category: category, metadata: metadata)
    }
    
    func warn(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .warning, category: category, metadata: metadata)
    }
    
    func error(_ message: String, category: String, error: Error? = nil, metadata: [String: String]? = nil) {
        var meta = metadata ?? [:]
        if let err = error {
            meta["error_type"] = String(describing: type(of: err))
            meta["error_message"] = err.localizedDescription
        }
        log(message, level: .error, category: category, metadata: meta)
    }
    
    func critical(_ message: String, category: String, error: Error? = nil, metadata: [String: String]? = nil) {
        var meta = metadata ?? [:]
        if let err = error {
            meta["error_type"] = String(describing: type(of: err))
            meta["error_message"] = err.localizedDescription
        }
        log(message, level: .critical, category: category, metadata: meta)
    }
    
    // MARK: - Configuration
    
    func setLogLevel(_ level: LogLevel) {
        minLogLevel = level
    }
    
    func enableLogging(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    // MARK: - Access
    func getRecentLogs() -> [ArgusLogEntry] {
        return recentLogs
    }

    func clearLogs() {
        recentLogs.removeAll()
    }
}

struct ArgusLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: ArgusLogger.LogLevel
    let category: String
    let message: String
    let metadata: [String: String]?
}

// MARK: - Legacy / Simplified Static API
extension ArgusLogger {
    // MARK: - Modüller
    enum Module: String {
        case bootstrap = "BAŞLATMA"
        case portfoy = "PORTFÖY"
        case fiyat = "FİYAT"
        case atlas = "ATLAS"
        case aether = "AETHER"
        case autopilot = "OTOPİLOT"
        case chiron = "CHIRON"
        case orion = "ORION"
        case argus = "ARGUS"
        case heimdall = "HEIMDALL"
        case veri = "VERİ"
    }
    
    // MARK: - Static Log Methods (DEBUG builds only)
    
    static func header(_ text: String) {
        #if DEBUG
        Swift.print("═══════════════════════════════════════")
        Swift.print(text)
        Swift.print("═══════════════════════════════════════")
        #endif
    }
    
    static func phase(_ module: Module, _ message: String) {
        #if DEBUG
        Swift.print("⏳ [\(module.rawValue)] \(message)")
        #endif
    }
    
    static func progress(_ module: Module, _ current: Int, _ total: Int, _ extra: String = "") {
        #if DEBUG
        let pct = total > 0 ? Int(Double(current) / Double(total) * 100) : 0
        let extraText = extra.isEmpty ? "" : " - \(extra)"
        Swift.print("   ▸ \(current)/\(total) (%\(pct))\(extraText)")
        #endif
    }
    
    static func success(_ module: Module, _ message: String) {
        #if DEBUG
        Swift.print("   ✓ [\(module.rawValue)] \(message)")
        #endif
    }
    
    static func warning(_ module: Module, _ message: String) {
        #if DEBUG
        Swift.print("   ⚠️ [\(module.rawValue)] \(message)")
        #endif
    }
    
    static func error(_ module: Module, _ message: String) {
        #if DEBUG
        Swift.print("   ❌ [\(module.rawValue)] \(message)")
        #endif
    }
    
    static func info(_ module: Module, _ message: String) {
        #if DEBUG
        Swift.print("   ℹ️ [\(module.rawValue)] \(message)")
        #endif
    }
    
    static func complete(_ message: String) {
        #if DEBUG
        Swift.print("✅ \(message)")
        #endif
    }
    
    static func bootstrapComplete(seconds: Double) {
        #if DEBUG
        Swift.print("")
        header("✅ ARGUS HAZIR (\(String(format: "%.1f", seconds))s)")
        #endif
    }
    
    static func watchlist(count: Int) {
        #if DEBUG
        Swift.print("📋 İzleme Listesi: \(count) sembol")
        #endif
    }
    
    static func bakiye(usd: Double, tryAmount: Double) {
        #if DEBUG
        let usdStr = usd >= 1000 ? String(format: "%.0fK", usd / 1000) : String(format: "%.0f", usd)
        let tryStr = tryAmount >= 1000 ? String(format: "₺%.0fK", tryAmount / 1000) : String(format: "₺%.0f", tryAmount)
        Swift.print("💵 Bakiye: $\(usdStr) | \(tryStr)")
        #endif
    }
    
    static func batchProgress(module: Module, batch: Int, totalBatches: Int, processed: Int, total: Int) {
        #if DEBUG
        Swift.print("   ▸ Paket \(batch)/\(totalBatches) (\(processed)/\(total))")
        #endif
    }
}
