import Foundation
import SQLite3
import CryptoKit

// MARK: - Argus Ledger (The Scientific Truth)
/// The Single Source of Truth for Argus. Records validation events, trades, and learning outcomes.
/// Uses raw SQLite3 for zero-dependency, offline-first storage.
final class ArgusLedger: Sendable {
    static let shared = ArgusLedger()
    
    private let dbPath: String
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.argus.ledger", qos: .utility)
    
    // MARK: - Integration Context (Runtime Only)
    // Acts as a bridge between DataGateway and AGORA without changing method signatures.
    private var latestSnapshots: [String: [String: String]] = [:] // Symbol -> { Type -> Hash }
    private let contextLock = NSLock()
    
    // MARK: - Initialization
    private init() {
        // Store in Application Support or Documents
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths[0]
        // Clean start for Scientific Era
        let dbUrl = docDir.appendingPathComponent("ArgusScience_V1.sqlite")
        self.dbPath = dbUrl.path
        
        // Lazy init: Do strictly nothing here to prevent Main Thread Hangs.
        // DB will be opened on first write/read on the queue.
    }
    
    private var isDbReady = false
    
    private func ensureConnection() {
        guard !isDbReady else { return }
        openDatabase()
        createSchema()
        isDbReady = true
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("🚨 ArgusLedger: Error opening database at \(dbPath)")
        } else {
            print("💾 ArgusLedger: Database opened at \(dbPath)")
        }
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Schema Management
    private func createSchema() {
        let createBlobs = """
        CREATE TABLE IF NOT EXISTS blobs (
            hash_id TEXT PRIMARY KEY,
            blob_type TEXT NOT NULL,
            compression TEXT NOT NULL,
            payload_bytes BLOB NOT NULL,
            created_at_utc TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            source_meta_json TEXT
        );
        """
        
        let createEvents = """
        CREATE TABLE IF NOT EXISTS events (
            event_id TEXT PRIMARY KEY,
            event_type TEXT NOT NULL,
            event_time_utc TEXT NOT NULL,
            run_id TEXT NOT NULL,
            decision_id TEXT,
            symbol TEXT,
            payload_json TEXT NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1,
            app_build TEXT NOT NULL,
            engine_version TEXT,
            
            -- Scientific Validation Columns
            processed INTEGER DEFAULT 0,
            outcome_score REAL,
            horizon_pnl_percent REAL,
            validation_date TEXT
        );
        """
        
        // ARGUS 3.0: Unified Trade Log (Scientific Schema)
        let createTrades = """
        CREATE TABLE IF NOT EXISTS trades (
            trade_id TEXT PRIMARY KEY,
            symbol TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'OPEN', -- OPEN, CLOSED
            
            -- Entry Context (Experiment Conditions)
            entry_date TEXT NOT NULL, -- Execution Time
            as_of_date TEXT,          -- Data Knowledge Time (No Lookahead)
            entry_price REAL NOT NULL,
            entry_action TEXT NOT NULL, -- BUY, SELL
            decision_id TEXT,
            
            -- Experiment Meta
            instrument_type TEXT DEFAULT 'STOCK', -- STOCK, ETF, CRYPTO
            market_region TEXT DEFAULT 'US',      -- US, BIST
            data_version_hash TEXT,               -- Snapshot Hash
            engine_config_hash TEXT,              -- Model/Rule Hash
            
            -- Exit & Outcome
            exit_date TEXT,
            exit_price REAL,
            exit_reason TEXT,
            
            -- Scientific Metrics
            pnl_percent REAL,
            max_drawdown REAL,
            holding_period_days REAL,
            
            -- Learning
            learned_weight_adjustment REAL,
            lesson_blob_id TEXT
        );
        """
        
        let createLessons = """
        CREATE TABLE IF NOT EXISTS lessons (
            lesson_id TEXT PRIMARY KEY,
            trade_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            lesson_text TEXT NOT NULL,
            deviation_percent REAL,
            weight_changes_json TEXT,
            FOREIGN KEY (trade_id) REFERENCES trades(trade_id)
        );
        """
        
        let createWeightHistory = """
        CREATE TABLE IF NOT EXISTS weight_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            module TEXT NOT NULL,
            old_weight REAL NOT NULL,
            new_weight REAL NOT NULL,
            reason TEXT,
            trade_id TEXT,
            
            -- Observatory: Extended Learning Tracking
            regime TEXT,           -- Trend, Chop, RiskOff
            window_days INTEGER,   -- 30, 60, 90
            sample_size INTEGER,   -- Kaç karar üzerinden hesaplandı
            trigger_metric TEXT,   -- win_rate, sharpe vb.
            trigger_value REAL     -- Tetikleyici metrik değeri
        );
        """
        
        let indices = [
            "CREATE INDEX IF NOT EXISTS idx_events_time ON events(event_time_utc);",
            "CREATE INDEX IF NOT EXISTS idx_events_symbol_time ON events(symbol, event_time_utc);",
            "CREATE INDEX IF NOT EXISTS idx_events_decision ON events(decision_id);",
            "CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);",
            "CREATE INDEX IF NOT EXISTS idx_trades_status ON trades(status);",
            "CREATE INDEX IF NOT EXISTS idx_lessons_trade ON lessons(trade_id);"
        ]
        
        execute(sql: createBlobs)
        execute(sql: createEvents)
        execute(sql: createTrades)
        execute(sql: createLessons)
        execute(sql: createWeightHistory)
        for idx in indices { execute(sql: idx) }
    }
    
    // MARK: - Core API
    
    /// Writes a compressed blob to storage. Returns the SHA-256 hash.
    /// If blob exists, strictly ignores (CAS).
    func writeBlob(type: String, data: Data, meta: [String: Any]) -> String? {
        // 1. Skip compression for simplicity (zlib API issue on iOS)
        // Store uncompressed data directly
        let storageData = data
        
        // 2. Hash (We hash the data to ensure strict CAS for what determines storage)
        let hash = sha256(data: storageData)
        let size = storageData.count
        let metaJson = asJsonString(meta) ?? "{}"
        let now = Date().iso8601
        
        let sql = """
        INSERT OR IGNORE INTO blobs (hash_id, blob_type, compression, payload_bytes, created_at_utc, size_bytes, source_meta_json)
        VALUES (?, ?, 'NONE', ?, ?, ?, ?);
        """
        
        return queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (hash as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (type as NSString).utf8String, -1, nil)
                
                // Bind BLOB
                storageData.withUnsafeBytes { ptr in
                     _ = sqlite3_bind_blob(stmt, 3, ptr.baseAddress, Int32(storageData.count), nil) // SQLITE_TRANSIENT
                }
                
                sqlite3_bind_text(stmt, 4, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, Int32(size))
                sqlite3_bind_text(stmt, 6, (metaJson as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 FlightRecorder: Blob Write Error")
                }
            } else {
                let errMsg = String(cString: sqlite3_errmsg(db))
                print("🚨 FlightRecorder: Prepare Error: \(errMsg)")
            }
            sqlite3_finalize(stmt)
            return hash
        }
    }
    
    /// Reads a blob from storage by hash.
    func readBlob(hash: String) -> Data? {
        let sql = """
        SELECT payload_bytes FROM blobs WHERE hash_id = ? LIMIT 1;
        """
        
        return queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            var result: Data?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (hash as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let blobPtr = sqlite3_column_blob(stmt, 0) {
                        let blobSize = Int(sqlite3_column_bytes(stmt, 0))
                        result = Data(bytes: blobPtr, count: blobSize)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    /// Caches a blob reference for the current symbol cycle.
    /// Used to implicitly pass data provenance to AGORA.
    func cacheSnapshotRef(symbol: String, type: String, hash: String) {
        contextLock.lock()
        defer { contextLock.unlock() }
        
        var refs = latestSnapshots[symbol] ?? [:]
        refs[type] = hash
        latestSnapshots[symbol] = refs
    }
    
    /// Retrieves cached snapshot references for linking to a Decision.
    func getSnapshotRefs(symbol: String) -> [String: String] {
        contextLock.lock()
        defer { contextLock.unlock() }
        return latestSnapshots[symbol] ?? [:]
    }
    
    func recordEvent(
        type: String,
        decisionId: String?,
        symbol: String?,
        payload: [String: Any]
    ) {
        let eventId = UUID().uuidString
        let now = Date().iso8601
        let runId = SessionID.shared.id // Assuming we have or will create this
        let payloadJson = asJsonString(payload) ?? "{}"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let engineVer = "AGORA-2.1" // Constant for now
        
        let sql = """
        INSERT INTO events (event_id, event_type, event_time_utc, run_id, decision_id, symbol, payload_json, app_build, engine_version)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.async {
            self.ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (eventId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (type as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (runId as NSString).utf8String, -1, nil)
                
                if let decId = decisionId {
                    sqlite3_bind_text(stmt, 5, (decId as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                
                if let sym = symbol {
                    sqlite3_bind_text(stmt, 6, (sym as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                sqlite3_bind_text(stmt, 7, (payloadJson as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 8, (appBuild as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 9, (engineVer as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 FlightRecorder: Event Write Error")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Forecast Logging
    func logForecast(
        symbol: String,
        currentPrice: Double,
        predictedPrice: Double,
        predictions: [Double],
        confidence: Double
    ) {
        let payload: [String: Any] = [
            "current_price": currentPrice,
            "predicted_price": predictedPrice,
            "predictions": predictions,
            "confidence": confidence,
            "model": "Holt-Winters-V1",
            "horizon_days": 5
        ]
        
        recordEvent(
            type: "ForecastEvent",
            decisionId: nil,
            symbol: symbol,
            payload: payload
        )
    }
    
    /// Logs a Grand Council Decision with full scientific context.
    func logDecision(
        decisionId: UUID,
        symbol: String,
        action: String,
        confidence: Double,
        scores: [String: Double],
        vetoes: [String],
        origin: String, // UI_SCAN, AUTOPILOT, BACKTEST
        runId: String? = nil,
        currentPrice: Double? = nil
    ) {
        let now = Date().iso8601
        let snapshots = getSnapshotRefs(symbol: symbol)
        
        // Calculate Data Hash (Composite of all snapshots)
        let dataHash = snapshots.values.sorted().joined(separator: "|")
        let dataVersionHash = sha256(data: dataHash.data(using: .utf8) ?? Data())
        
        let payload: [String: Any] = [
            "action": action,
            "confidence": confidence,
            "scores": scores,
            "vetoes": vetoes,
            "origin": origin,
            "snapshots": snapshots,
            "current_price": currentPrice ?? 0.0,
            
            // Scientific Meta
            "as_of_utc": now, // For now, decision time is data time (until historical fetch is ready)
            "data_version_hash": dataVersionHash,
            "engine_config_hash": "ARGUS_V3_DEFAULT", // TODO: Hash config dynamically
            "instrument_type": "STOCK",
            "market_region": symbol.contains(".IS") ? "BIST" : "US"
        ]
        
        let runIdentifier = runId ?? SessionID.shared.id
        
        // Record Event
        let eventSql = """
        INSERT INTO events (event_id, event_type, event_time_utc, run_id, decision_id, symbol, payload_json, app_build, engine_version, processed)
        VALUES (?, 'DecisionEvent', ?, ?, ?, ?, ?, ?, 'ARGUS-3.0', 0);
        """
        
        let payloadJson = asJsonString(payload) ?? "{}"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        queue.async {
            self.ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, eventSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (UUID().uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (runIdentifier as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (decisionId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (symbol as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 6, (payloadJson as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 7, (appBuild as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 ArgusLedger: Decision Log Error")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Helpers
    private func execute(sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("🚨 FlightRecorder: SQL Error: \(errMsg)")
        }
    }
    
    private func asJsonString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // Simple SHA256 Helper using CryptoKit
    private func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - ARGUS 3.0: Trade Lifecycle API
    
    /// Opens a new trade and returns its UUID.
    @discardableResult
    func openTrade(
        symbol: String,
        price: Double,
        reason: String,
        dominantSignal: String? = nil,
        decisionId: String? = nil
    ) -> UUID {
        let tradeId = UUID()
        let now = Date().iso8601
        
        let sql = """
        INSERT INTO trades (trade_id, symbol, status, entry_date, entry_price, entry_reason, dominant_signal, decision_id)
        VALUES (?, ?, 'OPEN', ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (tradeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (symbol as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 4, price)
                sqlite3_bind_text(stmt, 5, (reason as NSString).utf8String, -1, nil)
                
                if let signal = dominantSignal {
                    sqlite3_bind_text(stmt, 6, (signal as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                if let decId = decisionId {
                    sqlite3_bind_text(stmt, 7, (decId as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 ArgusLedger: Trade Open Error")
                } else {
                    print("📈 ArgusLedger: Trade Opened for \(symbol) @ \(price)")
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return tradeId
    }
    
    /// Closes an open trade and calculates PnL.
    func closeTrade(tradeId: UUID, exitPrice: Double) {
        let now = Date().iso8601
        
        // First, get entry price to calculate PnL
        var entryPrice: Double = 0
        var symbol: String = ""
        
        let selectSql = "SELECT entry_price, symbol FROM trades WHERE trade_id = ?;"
        
        queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (tradeId.uuidString as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    entryPrice = sqlite3_column_double(stmt, 0)
                    if let symPtr = sqlite3_column_text(stmt, 1) {
                        symbol = String(cString: symPtr)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        guard entryPrice > 0 else {
            print("⚠️ ArgusLedger: Trade not found for closing: \(tradeId)")
            return
        }
        
        let pnlPercent = ((exitPrice - entryPrice) / entryPrice) * 100.0
        
        let updateSql = """
        UPDATE trades SET status = 'CLOSED', exit_date = ?, exit_price = ?, pnl_percent = ? WHERE trade_id = ?;
        """
        
        queue.sync {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 2, exitPrice)
                sqlite3_bind_double(stmt, 3, pnlPercent)
                sqlite3_bind_text(stmt, 4, (tradeId.uuidString as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 ArgusLedger: Trade Close Error")
                } else {
                    print("💰 ArgusLedger: Trade Closed for \(symbol). PnL: \(String(format: "%.2f", pnlPercent))%")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Records a lesson learned from a trade.
    func recordLesson(tradeId: UUID, lesson: String, deviationPercent: Double? = nil, weightChanges: [String: Double]? = nil) {
        let lessonId = UUID()
        let now = Date().iso8601
        let weightJson = weightChanges != nil ? asJsonString(weightChanges! as [String: Any]) : nil
        
        let sql = """
        INSERT INTO lessons (lesson_id, trade_id, created_at, lesson_text, deviation_percent, weight_changes_json)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        queue.async {
            self.ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (lessonId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (tradeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (lesson as NSString).utf8String, -1, nil)
                
                if let dev = deviationPercent {
                    sqlite3_bind_double(stmt, 5, dev)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                
                if let wJson = weightJson {
                    sqlite3_bind_text(stmt, 6, (wJson as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("🚨 ArgusLedger: Lesson Record Error")
                } else {
                    print("📚 ArgusLedger: Lesson Recorded for Trade \(tradeId.uuidString.prefix(8))")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Observatory: Learning Event Logging
    
    /// Logs a learning event (weight update) for Observatory.
    func logLearning(event: LearningEvent) {
        let now = Date().iso8601
        
        // Insert one row per module weight change
        let sql = """
        INSERT INTO weight_history (timestamp, module, old_weight, new_weight, reason, regime, window_days, sample_size, trigger_metric, trigger_value)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.async {
            self.ensureConnection()
            
            for (module, delta) in event.weightDeltas {
                let oldWeight = event.oldWeights[module] ?? 0.0
                let newWeight = event.newWeights[module] ?? 0.0
                
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (now as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (module as NSString).utf8String, -1, nil)
                    sqlite3_bind_double(stmt, 3, oldWeight)
                    sqlite3_bind_double(stmt, 4, newWeight)
                    sqlite3_bind_text(stmt, 5, (event.reason as NSString).utf8String, -1, nil)
                    
                    if let regime = event.regime {
                        sqlite3_bind_text(stmt, 6, (regime as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 6)
                    }
                    
                    sqlite3_bind_int(stmt, 7, Int32(event.windowDays))
                    sqlite3_bind_int(stmt, 8, Int32(event.sampleSize))
                    
                    if let metric = event.triggerMetric {
                        sqlite3_bind_text(stmt, 9, (metric as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 9)
                    }
                    
                    if let value = event.triggerValue {
                        sqlite3_bind_double(stmt, 10, value)
                    } else {
                        sqlite3_bind_null(stmt, 10)
                    }
                    
                    if sqlite3_step(stmt) != SQLITE_DONE {
                        print("🚨 ArgusLedger: Learning Event Write Error")
                    }
                }
                sqlite3_finalize(stmt)
            }
            
            print("🧠 ArgusLedger: Learning Event Logged (\(event.weightDeltas.count) modules)")
        }
    }
    
    /// Loads recent learning events for Observatory UI.
    func loadLearningEvents(limit: Int = 50) -> [LearningEvent] {
        let sql = """
        SELECT timestamp, module, old_weight, new_weight, reason, regime, window_days, sample_size, trigger_metric, trigger_value
        FROM weight_history
        ORDER BY timestamp DESC
        LIMIT ?;
        """
        
        var results: [(String, String, Double, Double, String?, String?, Int, Int, String?, Double?)] = []
        
        queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let timestamp = String(cString: sqlite3_column_text(stmt, 0))
                    let module = String(cString: sqlite3_column_text(stmt, 1))
                    let oldWeight = sqlite3_column_double(stmt, 2)
                    let newWeight = sqlite3_column_double(stmt, 3)
                    let reason = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let regime = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let windowDays = Int(sqlite3_column_int(stmt, 6))
                    let sampleSize = Int(sqlite3_column_int(stmt, 7))
                    let triggerMetric = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                    let triggerValue = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 9)
                    
                    results.append((timestamp, module, oldWeight, newWeight, reason, regime, windowDays, sampleSize, triggerMetric, triggerValue))
                }
            }
            sqlite3_finalize(stmt)
        }
        
        // Group by timestamp to form LearningEvents
        var eventsByTimestamp: [String: (reason: String?, regime: String?, windowDays: Int, sampleSize: Int, triggerMetric: String?, triggerValue: Double?, deltas: [String: Double], oldWeights: [String: Double], newWeights: [String: Double])] = [:]
        
        for row in results {
            let (timestamp, module, oldW, newW, reason, regime, windowDays, sampleSize, triggerMetric, triggerValue) = row
            let delta = newW - oldW
            
            if var existing = eventsByTimestamp[timestamp] {
                existing.deltas[module] = delta
                existing.oldWeights[module] = oldW
                existing.newWeights[module] = newW
                eventsByTimestamp[timestamp] = existing
            } else {
                eventsByTimestamp[timestamp] = (
                    reason: reason,
                    regime: regime,
                    windowDays: windowDays,
                    sampleSize: sampleSize,
                    triggerMetric: triggerMetric,
                    triggerValue: triggerValue,
                    deltas: [module: delta],
                    oldWeights: [module: oldW],
                    newWeights: [module: newW]
                )
            }
        }
        
        return eventsByTimestamp.map { (timestamp, data) in
            LearningEvent(
                id: UUID(),
                timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
                weightDeltas: data.deltas,
                oldWeights: data.oldWeights,
                newWeights: data.newWeights,
                reason: data.reason ?? "Bilinmiyor",
                triggerMetric: data.triggerMetric,
                triggerValue: data.triggerValue,
                regime: data.regime,
                windowDays: data.windowDays,
                sampleSize: data.sampleSize
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Records a weight change in history.
    func recordWeightChange(module: String, oldWeight: Double, newWeight: Double, reason: String?, tradeId: UUID? = nil) {
        let now = Date().iso8601
        
        let sql = """
        INSERT INTO weight_history (timestamp, module, old_weight, new_weight, reason, trade_id)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        queue.async {
            self.ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (now as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (module as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, oldWeight)
                sqlite3_bind_double(stmt, 4, newWeight)
                
                if let r = reason {
                    sqlite3_bind_text(stmt, 5, (r as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                
                if let tid = tradeId {
                    sqlite3_bind_text(stmt, 6, (tid.uuidString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - ARGUS 3.0: Query API for UI
    
    /// Returns all open trades.
    func getOpenTrades() async -> [TradeRecord] {
        let sql = """
        SELECT trade_id, symbol, status, entry_date, entry_price, entry_reason, 
               exit_date, exit_price, pnl_percent, dominant_signal, decision_id
        FROM trades WHERE status = 'OPEN' ORDER BY entry_date DESC;
        """
        
        return await withCheckedContinuation { continuation in
            queue.async {
                self.ensureConnection()
                var results: [TradeRecord] = []
                var stmt: OpaquePointer?
                
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let record = self.parseTradeRow(stmt: stmt) {
                        results.append(record)
                    }
                }
                
                sqlite3_finalize(stmt)
                continuation.resume(returning: results)
            }
        }
    }
    
    /// Returns closed trades with limit.
    func getClosedTrades(limit: Int = 50) async -> [TradeRecord] {
        let sql = """
        SELECT trade_id, symbol, status, entry_date, entry_price, entry_reason, 
               exit_date, exit_price, pnl_percent, dominant_signal, decision_id
        FROM trades WHERE status = 'CLOSED' ORDER BY exit_date DESC LIMIT ?;
        """
        
        return await withCheckedContinuation { continuation in
            queue.async {
                self.ensureConnection()
                var results: [TradeRecord] = []
                var stmt: OpaquePointer?
                
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                
                sqlite3_bind_int(stmt, 1, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let record = self.parseTradeRow(stmt: stmt) {
                        results.append(record)
                    }
                }
                
                sqlite3_finalize(stmt)
                continuation.resume(returning: results)
            }
        }
    }
    
    /// Returns lessons with limit.
    func getLessons(limit: Int = 50) async -> [LessonRecord] {
        let sql = """
        SELECT lesson_id, trade_id, created_at, lesson_text, deviation_percent, weight_changes_json
        FROM lessons ORDER BY created_at DESC LIMIT ?;
        """
        
        return await withCheckedContinuation { continuation in
            queue.async {
                self.ensureConnection()
                var results: [LessonRecord] = []
                var stmt: OpaquePointer?
                
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                
                sqlite3_bind_int(stmt, 1, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let lessonIdPtr = sqlite3_column_text(stmt, 0),
                          let tradeIdPtr = sqlite3_column_text(stmt, 1),
                          let createdAtPtr = sqlite3_column_text(stmt, 2),
                          let lessonTextPtr = sqlite3_column_text(stmt, 3) else { continue }
                    
                    let lessonId = UUID(uuidString: String(cString: lessonIdPtr)) ?? UUID()
                    let tradeId = UUID(uuidString: String(cString: tradeIdPtr)) ?? UUID()
                    let createdAt = Date.fromISO8601(String(cString: createdAtPtr)) ?? Date()
                    let lessonText = String(cString: lessonTextPtr)
                    
                    var deviation: Double? = nil
                    if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
                        deviation = sqlite3_column_double(stmt, 4)
                    }
                    
                    var weightChanges: [String: Double]? = nil
                    if let jsonPtr = sqlite3_column_text(stmt, 5) {
                        let jsonStr = String(cString: jsonPtr)
                        if let data = jsonStr.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
                            weightChanges = dict
                        }
                    }
                    
                    results.append(LessonRecord(
                        id: lessonId,
                        tradeId: tradeId,
                        createdAt: createdAt,
                        lessonText: lessonText,
                        deviationPercent: deviation,
                        weightChanges: weightChanges
                    ))
                }
                
                sqlite3_finalize(stmt)
                continuation.resume(returning: results)
            }
        }
    }
    
    // MARK: - Observatory: Load Recent Decisions for Timeline
    
    /// Loads recent decision events for Observatory Timeline.
    func loadRecentDecisions(limit: Int = 100) -> [DecisionCard] {
        let sql = """
        SELECT event_id, symbol, event_time_utc, payload_json, processed, horizon_pnl_percent
        FROM events
        WHERE event_type = 'DecisionEvent'
        ORDER BY event_time_utc DESC
        LIMIT ?;
        """
        
        var results: [DecisionCard] = []
        
        queue.sync {
            ensureConnection()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let eventIdPtr = sqlite3_column_text(stmt, 0),
                          let symbolPtr = sqlite3_column_text(stmt, 1),
                          let timestampPtr = sqlite3_column_text(stmt, 2),
                          let payloadPtr = sqlite3_column_text(stmt, 3) else { continue }
                    
                    let eventId = String(cString: eventIdPtr)
                    let symbol = String(cString: symbolPtr)
                    let timestampStr = String(cString: timestampPtr)
                    let payloadJson = String(cString: payloadPtr)
                    let processed = Int(sqlite3_column_int(stmt, 4))
                    let pnl = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
                    
                    // Parse payload
                    guard let data = payloadJson.data(using: .utf8),
                          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    let action = payload["action"] as? String ?? "GÖZLE"
                    let confidence = payload["confidence"] as? Double ?? 0.5
                    let scoresDict = payload["scores"] as? [String: Double] ?? [:]
                    let marketRegion = payload["market_region"] as? String ?? (symbol.contains(".IS") ? "BIST" : "US")
                    
                    // Extract top factors
                    var factors: [DecisionCard.Factor] = []
                    for (name, value) in scoresDict.sorted(by: { $0.value > $1.value }).prefix(3) {
                        let emoji: String
                        switch name.lowercased() {
                        case "orion": emoji = "📊"
                        case "atlas": emoji = "💰"
                        case "aether": emoji = "🌍"
                        case "hermes": emoji = "📰"
                        case "athena": emoji = "🧠"
                        case "demeter": emoji = "🌾"
                        default: emoji = "📈"
                        }
                        factors.append(DecisionCard.Factor(name: name, emoji: emoji, value: value))
                    }
                    
                    let card = DecisionCard(
                        id: UUID(uuidString: eventId) ?? UUID(),
                        symbol: symbol,
                        market: marketRegion,
                        timestamp: ISO8601DateFormatter().date(from: timestampStr) ?? Date(),
                        action: action,
                        confidence: confidence,
                        topFactors: factors,
                        horizon: .t7, // Default, can be enhanced later
                        outcome: processed == 1 ? .matured : .pending,
                        actualPnl: pnl
                    )
                    
                    results.append(card)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return results
    }
    
    // MARK: - Trade Row Parser
    
    private func parseTradeRow(stmt: OpaquePointer?) -> TradeRecord? {
        guard let stmt = stmt,
              let tradeIdPtr = sqlite3_column_text(stmt, 0),
              let symbolPtr = sqlite3_column_text(stmt, 1),
              let statusPtr = sqlite3_column_text(stmt, 2),
              let entryDatePtr = sqlite3_column_text(stmt, 3) else { return nil }
        
        let tradeId = UUID(uuidString: String(cString: tradeIdPtr)) ?? UUID()
        let symbol = String(cString: symbolPtr)
        let status = String(cString: statusPtr)
        let entryDate = Date.fromISO8601(String(cString: entryDatePtr)) ?? Date()
        let entryPrice = sqlite3_column_double(stmt, 4)
        
        var entryReason: String? = nil
        if let ptr = sqlite3_column_text(stmt, 5) {
            entryReason = String(cString: ptr)
        }
        
        var exitDate: Date? = nil
        if let ptr = sqlite3_column_text(stmt, 6) {
            exitDate = Date.fromISO8601(String(cString: ptr))
        }
        
        var exitPrice: Double? = nil
        if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
            exitPrice = sqlite3_column_double(stmt, 7)
        }
        
        var pnlPercent: Double? = nil
        if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
            pnlPercent = sqlite3_column_double(stmt, 8)
        }
        
        var dominantSignal: String? = nil
        if let ptr = sqlite3_column_text(stmt, 9) {
            dominantSignal = String(cString: ptr)
        }
        
        var decisionId: String? = nil
        if let ptr = sqlite3_column_text(stmt, 10) {
            decisionId = String(cString: ptr)
        }
        
        return TradeRecord(
            id: tradeId,
            symbol: symbol,
            status: status,
            entryDate: entryDate,
            entryPrice: entryPrice,
            entryReason: entryReason,
            exitDate: exitDate,
            exitPrice: exitPrice,
            pnlPercent: pnlPercent,
            dominantSignal: dominantSignal,
            decisionId: decisionId
        )
    }
}

// Session Helper
struct SessionID {
    static let shared = SessionID()
    let id = UUID().uuidString
}

// Date Extension for ISO8601
extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
    
    static func fromISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

// MARK: - Reading API for Forward Test Processing
extension ArgusLedger {
    
    /// ForecastEvent'leri okur (işlenmemiş olanlar)
    func getUnprocessedForecasts() async -> [ForecastEventData] {
        let sql = """
        SELECT event_id, symbol, event_time_utc, payload_json 
        FROM events 
        WHERE event_type = 'ForecastEvent' AND (processed IS NULL OR processed = 0)
        ORDER BY event_time_utc ASC;
        """
        
        return await withCheckedContinuation { continuation in
            queue.async {
                self.ensureConnection()
                var results: [ForecastEventData] = []
                var stmt: OpaquePointer?
                
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let eventIdPtr = sqlite3_column_text(stmt, 0),
                          let symbolPtr = sqlite3_column_text(stmt, 1),
                          let datePtr = sqlite3_column_text(stmt, 2),
                          let payloadPtr = sqlite3_column_text(stmt, 3) else { continue }
                    
                    let eventId = String(cString: eventIdPtr)
                    let symbol = String(cString: symbolPtr)
                    let dateStr = String(cString: datePtr)
                    let payloadStr = String(cString: payloadPtr)
                    
                    guard let eventDate = Date.fromISO8601(dateStr),
                          let payloadData = payloadStr.data(using: .utf8),
                          let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else { continue }
                    
                    let currentPrice = payload["current_price"] as? Double ?? 0
                    let predictedPrice = payload["predicted_price_5d"] as? Double ?? 0
                    
                    results.append(ForecastEventData(
                        eventId: eventId,
                        symbol: symbol,
                        eventDate: eventDate,
                        currentPrice: currentPrice,
                        predictedPrice: predictedPrice
                    ))
                }
                
                sqlite3_finalize(stmt)
                continuation.resume(returning: results)
            }
        }
    }
    
    /// DecisionEvent'leri okur (işlenmemiş olanlar)
    func getUnprocessedDecisions() async -> [DecisionEventData] {
        let sql = """
        SELECT event_id, symbol, event_time_utc, payload_json 
        FROM events 
        WHERE event_type = 'DecisionEvent' AND (processed IS NULL OR processed = 0)
        ORDER BY event_time_utc ASC;
        """
        
        return await withCheckedContinuation { continuation in
            queue.async {
                self.ensureConnection()
                var results: [DecisionEventData] = []
                var stmt: OpaquePointer?
                
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let eventIdPtr = sqlite3_column_text(stmt, 0),
                          let symbolPtr = sqlite3_column_text(stmt, 1),
                          let datePtr = sqlite3_column_text(stmt, 2),
                          let payloadPtr = sqlite3_column_text(stmt, 3) else { continue }
                    
                    let eventId = String(cString: eventIdPtr)
                    let symbol = String(cString: symbolPtr)
                    let dateStr = String(cString: datePtr)
                    let payloadStr = String(cString: payloadPtr)
                    
                    guard let eventDate = Date.fromISO8601(dateStr),
                          let payloadData = payloadStr.data(using: .utf8),
                          let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else { continue }
                    
                    let action = payload["action"] as? String ?? "HOLD"
                    
                    // Fiyatı blob'dan almamız gerekiyor ama şimdilik 0 koyalım
                    // TODO: input_blobs'tan fiyat bilgisi çekilecek
                    let currentPrice = payload["current_price"] as? Double ?? 0
                    
                    // Module scores
                    var moduleScores: [String: Double]? = nil
                    if let scores = payload["module_scores"] as? [String: Double] {
                        moduleScores = scores
                    }
                    
                    results.append(DecisionEventData(
                        eventId: eventId,
                        symbol: symbol,
                        eventDate: eventDate,
                        currentPrice: currentPrice,
                        action: action,
                        moduleScores: moduleScores ?? [:]
                    ))
                }
                
                sqlite3_finalize(stmt)
                continuation.resume(returning: results)
            }
        }
    }
    
    /// Event'i işlenmiş olarak işaretler
    func markEventProcessed(eventId: String) async {
        // Önce processed kolonu var mı kontrol et, yoksa ekle
        let alterSql = "ALTER TABLE events ADD COLUMN processed INTEGER DEFAULT 0;"
        queue.sync {
            ensureConnection()
            // Hata olursa (kolon zaten varsa) önemseme
            sqlite3_exec(db, alterSql, nil, nil, nil)
        }
        
        let sql = "UPDATE events SET processed = 1 WHERE event_id = ?;"
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (eventId as NSString).utf8String, -1, nil)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
                continuation.resume()
            }
        }
    }
    
    /// İşlenmiş event'leri ve ilişkili blob'ları siler
    func cleanupProcessedEvents() async {
        // 1. İşlenmiş event'lerin blob referanslarını bul
        let findBlobsSql = """
        SELECT DISTINCT json_extract(payload_json, '$.input_blobs[0].hash_id') as blob_hash
        FROM events WHERE processed = 1;
        """
        
        // 2. Blob'ları sil
        let deleteBlobsSql = "DELETE FROM blobs WHERE hash_id = ?;"
        
        // 3. Event'leri sil
        let deleteEventsSql = "DELETE FROM events WHERE processed = 1;"
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.ensureConnection()
                
                // Blob hash'leri topla
                var blobHashes: [String] = []
                var stmt: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, findBlobsSql, -1, &stmt, nil) == SQLITE_OK {
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let hashPtr = sqlite3_column_text(stmt, 0) {
                            blobHashes.append(String(cString: hashPtr))
                        }
                    }
                }
                sqlite3_finalize(stmt)
                
                // Blob'ları sil
                for hash in blobHashes {
                    var deleteStmt: OpaquePointer?
                    if sqlite3_prepare_v2(self.db, deleteBlobsSql, -1, &deleteStmt, nil) == SQLITE_OK {
                        sqlite3_bind_text(deleteStmt, 1, (hash as NSString).utf8String, -1, nil)
                        sqlite3_step(deleteStmt)
                    }
                    sqlite3_finalize(deleteStmt)
                }
                
                // Event'leri sil
                sqlite3_exec(self.db, deleteEventsSql, nil, nil, nil)
                
                // Vacuum
                sqlite3_exec(self.db, "VACUUM;", nil, nil, nil)
                
                print("FlightRecorder: \(blobHashes.count) blob ve iliskili eventler temizlendi")
                continuation.resume()
            }
        }
    }
}

// MARK: - Export / Dump Extension
extension ArgusLedger {
    
    /// Dumps all events to a JSONL file at the specified URL.
    func dumpEvents(to fileUrl: URL) throws {
        let sql = "SELECT payload_json FROM events ORDER BY event_time_utc ASC;"
        var stmt: OpaquePointer?
        
        // Ensure blocking on queue
        try queue.sync {
            ensureConnection()
            
            // Create file handle
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil)
            let handle = try FileHandle(forWritingTo: fileUrl)
            defer { try? handle.close() }
            
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw NSError(domain: "FlightRecorder", code: 500, userInfo: ["msg": "Prep failed"])
            }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let textPtr = sqlite3_column_text(stmt, 0) {
                    let json = String(cString: textPtr)
                    if let data = (json + "\n").data(using: .utf8) {
                        try? handle.write(data)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Dumps all blobs as individual files in the target directory.
    func dumpBlobs(to dirUrl: URL) throws {
        let sql = "SELECT hash_id, payload_bytes, blob_type FROM blobs;"
        var stmt: OpaquePointer?
        
        try queue.sync {
            ensureConnection()
            
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let hashPtr = sqlite3_column_text(stmt, 0),
                      let blobPtr = sqlite3_column_blob(stmt, 1) else { continue }
                
                let hash = String(cString: hashPtr)
                let bytes = sqlite3_column_bytes(stmt, 1)
                let data = Data(bytes: blobPtr, count: Int(bytes))
                
                // Filename: hash (e.g., a1b2...CANDLES_OHLCV)
                let fileUrl = dirUrl.appendingPathComponent(hash)
                try? data.write(to: fileUrl)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Aggressive Cleanup (Storage Optimization)
    
    /// Agresif temizlik - Eski verileri siler, depolama alanını küçültür
    /// - Parameters:
    ///   - maxBlobAgeDays: Blob'ları bu günden eski ise sil (varsayılan: 3)
    ///   - maxEventAgeDays: Event'leri bu günden eski ise sil (varsayılan: 7)
    ///   - maxTradeAgeDays: Trade'leri bu günden eski ise sil (varsayılan: 30)
    func aggressiveCleanup(maxBlobAgeDays: Int = 3, maxEventAgeDays: Int = 7, maxTradeAgeDays: Int = 30) async -> CleanupResult {
        return await withCheckedContinuation { (continuation: CheckedContinuation<CleanupResult, Never>) in
            queue.async {
                self.ensureConnection()
                
                var deletedBlobs = 0
                var deletedEvents = 0
                var deletedTrades = 0
                var freedBytes: Int64 = 0
                
                // 1. Eski blob'ları sil
                let blobCutoff = Date().addingTimeInterval(-Double(maxBlobAgeDays) * 24 * 60 * 60).iso8601
                let deleteBlobsSql = "DELETE FROM blobs WHERE created_at_utc < '\(blobCutoff)';"
                
                // Önce boyutu hesapla
                let sizeSql = "SELECT SUM(size_bytes) FROM blobs WHERE created_at_utc < '\(blobCutoff)';"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sizeSql, -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        freedBytes += sqlite3_column_int64(stmt, 0)
                    }
                }
                sqlite3_finalize(stmt)
                
                // Blob'ları sil
                if sqlite3_prepare_v2(self.db, deleteBlobsSql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_step(stmt)
                    deletedBlobs = Int(sqlite3_changes(self.db))
                }
                sqlite3_finalize(stmt)
                
                // 2. Eski event'leri sil
                let eventCutoff = Date().addingTimeInterval(-Double(maxEventAgeDays) * 24 * 60 * 60).iso8601
                let deleteEventsSql = "DELETE FROM events WHERE event_time_utc < '\(eventCutoff)';"
                
                if sqlite3_prepare_v2(self.db, deleteEventsSql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_step(stmt)
                    deletedEvents = Int(sqlite3_changes(self.db))
                }
                sqlite3_finalize(stmt)
                
                // 3. VACUUM to reclaim space
                self.execute(sql: "VACUUM;")
                
                print("🧹 ArgusLedger Cleanup: \(deletedBlobs) blobs, \(deletedEvents) events deleted. ~\(freedBytes / 1024 / 1024)MB freed.")
                
                continuation.resume(returning: CleanupResult(
                    deletedBlobs: deletedBlobs,
                    deletedEvents: deletedEvents,
                    deletedTrades: deletedTrades,
                    freedBytes: freedBytes
                ))
            }
        }
    }
    
    struct CleanupResult {
        let deletedBlobs: Int
        let deletedEvents: Int
        let deletedTrades: Int
        let freedBytes: Int64
        
        var summary: String {
            let mb = freedBytes / 1024 / 1024
            return "🧹 \(deletedBlobs) blob, \(deletedEvents) event silindi. ~\(mb)MB kazanıldı."
        }
    }
    
    /// Uygulama başlangıcında otomatik çağrılmalı
    func autoCleanupIfNeeded() async {
        // Son temizlikten 24 saat geçtiyse çalıştır
        let lastCleanupKey = "ArgusLedger_lastCleanup"
        let lastCleanup = UserDefaults.standard.object(forKey: lastCleanupKey) as? Date ?? .distantPast
        
        if Date().timeIntervalSince(lastCleanup) > 24 * 60 * 60 {
            let result = await aggressiveCleanup()
            print(result.summary)
            UserDefaults.standard.set(Date(), forKey: lastCleanupKey)
        }
    }
}
