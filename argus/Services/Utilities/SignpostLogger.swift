import Foundation
import os.signpost
import os.log

/// A centralized logger for performance profiling using `os_signpost`.
/// Only active in DEBUG builds to minimize production overhead.
final class SignpostLogger {
    static let shared = SignpostLogger()
    
    // MARK: - Categories
    
    let startup: OSLog
    let cache: OSLog
    let quotes: OSLog
    let candles: OSLog
    let atlas: OSLog
    let orion: OSLog
    let aether: OSLog
    let hermes: OSLog
    let scout: OSLog
    let ui: OSLog
    
    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.algotrading.app"
        
        self.startup = OSLog(subsystem: subsystem, category: "startup")
        self.cache = OSLog(subsystem: subsystem, category: "cache")
        self.quotes = OSLog(subsystem: subsystem, category: "quotes")
        self.candles = OSLog(subsystem: subsystem, category: "candles")
        self.atlas = OSLog(subsystem: subsystem, category: "atlas")
        self.orion = OSLog(subsystem: subsystem, category: "orion")
        self.aether = OSLog(subsystem: subsystem, category: "aether")
        self.hermes = OSLog(subsystem: subsystem, category: "hermes")
        self.scout = OSLog(subsystem: subsystem, category: "scout")
        self.ui = OSLog(subsystem: subsystem, category: "ui")
    }
    
    // MARK: - API
    
    /// Begins a signpost interval. Returns a SignpostID that must be passed to `end`.
    func begin(log: OSLog, name: StaticString) -> OSSignpostID {
        #if DEBUG
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
        #else
        return OSSignpostID(0)
        #endif
    }
    
    /// Ends a sighpost interval initiated by `begin`.
    func end(log: OSLog, name: StaticString, id: OSSignpostID) {
        #if DEBUG
        os_signpost(.end, log: log, name: name, signpostID: id)
        #endif
    }
    
    /// Logs a single point of interest event.
    func event(log: OSLog, name: StaticString, message: String = "") {
        #if DEBUG
        os_signpost(.event, log: log, name: name, "%{public}s", message)
        #endif
    }
}
