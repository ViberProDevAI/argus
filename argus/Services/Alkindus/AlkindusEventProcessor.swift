import Foundation
import SQLite3

// MARK: - Alkindus Event Processor
/// Processes historical SQLite events to extract learnings for Chiron/Alkindus.
/// Runs once to bootstrap from existing data, then marks events as processed.

final class AlkindusEventProcessor {
    static let shared = AlkindusEventProcessor()
    
    private let dbPath: String
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.alkindus.processor", qos: .utility)
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths[0]
        let dbUrl = docDir.appendingPathComponent("ArgusScience_V1.sqlite")
        self.dbPath = dbUrl.path
    }
    
    // MARK: - Process All Events
    /// Main entry point - processes all unprocessed events and extracts learnings
    func processHistoricalEvents(progressCallback: @escaping (Int, Int) -> Void) async -> ProcessingResult {
        return await withCheckedContinuation { continuation in
            queue.async {
                self.openDatabase()
                
                // 1. Count total unprocessed events
                let totalCount = self.countUnprocessedEvents()
                print("👁️ AlkindusProcessor: Found \(totalCount) unprocessed events")
                
                if totalCount == 0 {
                    continuation.resume(returning: ProcessingResult(
                        eventsProcessed: 0,
                        patternsExtracted: 0,
                        modulesLearned: []
                    ))
                    return
                }
                
                // 2. Process events in batches
                var processed = 0
                var patterns: [ModulePattern] = []
                let batchSize = 1000
                
                while processed < totalCount {
                    let batch = self.fetchEventsBatch(offset: processed, limit: batchSize)
                    
                    for event in batch {
                        if let pattern = self.extractPattern(from: event) {
                            patterns.append(pattern)
                        }
                    }
                    
                    processed += batch.count
                    DispatchQueue.main.async {
                        progressCallback(processed, totalCount)
                    }
                    
                    if batch.isEmpty { break }
                }
                
                // 3. Aggregate patterns into learnings
                let learnings = self.aggregatePatterns(patterns)
                
                // 4. Save learnings to Alkindus calibration
                Task {
                    await self.saveLearnings(learnings)
                }
                
                // 5. Mark events as processed (optional - can enable after verification)
                // self.markEventsAsProcessed()
                
                continuation.resume(returning: ProcessingResult(
                    eventsProcessed: processed,
                    patternsExtracted: patterns.count,
                    modulesLearned: Array(Set(patterns.map { $0.module }))
                ))
            }
        }
    }
    
    // MARK: - Database Operations
    
    private func openDatabase() {
        if db == nil {
            if sqlite3_open(dbPath, &db) != SQLITE_OK {
                print("🚨 AlkindusProcessor: Error opening database")
            }
        }
    }
    
    private func countUnprocessedEvents() -> Int {
        let sql = "SELECT COUNT(*) FROM events WHERE processed = 0 OR processed IS NULL;"
        
        var stmt: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        return count
    }
    
    private func fetchEventsBatch(offset: Int, limit: Int) -> [EventData] {
        let sql = """
        SELECT event_id, event_type, symbol, payload_json 
        FROM events 
        WHERE processed = 0 OR processed IS NULL
        ORDER BY event_time_utc
        LIMIT ? OFFSET ?;
        """
        
        var events: [EventData] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            sqlite3_bind_int(stmt, 2, Int32(offset))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let eventId = String(cString: sqlite3_column_text(stmt, 0))
                let eventType = String(cString: sqlite3_column_text(stmt, 1))
                let symbol = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let payloadJson = String(cString: sqlite3_column_text(stmt, 3))
                
                events.append(EventData(
                    eventId: eventId,
                    eventType: eventType,
                    symbol: symbol,
                    payloadJson: payloadJson
                ))
            }
        }
        sqlite3_finalize(stmt)
        
        return events
    }
    
    // MARK: - Pattern Extraction
    
    private func extractPattern(from event: EventData) -> ModulePattern? {
        // Parse payload JSON
        guard let data = event.payloadJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Extract module scores from different formats
        var moduleScores: [String: Double] = [:]
        
        // Format 1: module_scores key
        if let scores = json["module_scores"] as? [String: Any] {
            for (key, value) in scores {
                if let score = value as? Double {
                    moduleScores[key.lowercased()] = score
                } else if let score = value as? Int {
                    moduleScores[key.lowercased()] = Double(score)
                }
            }
        }
        
        // Format 2: scores key
        if let scores = json["scores"] as? [String: Any] {
            for (key, value) in scores {
                if let score = value as? Double {
                    moduleScores[key.lowercased()] = score
                } else if let score = value as? Int {
                    moduleScores[key.lowercased()] = Double(score)
                }
            }
        }
        
        // Extract action
        let action = json["action"] as? String ?? "UNKNOWN"
        
        // Create patterns for each module
        guard !moduleScores.isEmpty else { return nil }
        
        // Return the highest score module as the pattern
        if let (topModule, topScore) = moduleScores.max(by: { $0.value < $1.value }) {
            return ModulePattern(
                module: topModule,
                scoreBracket: scoreToBracket(topScore),
                action: action,
                symbol: event.symbol
            )
        }
        
        return nil
    }
    
    private func scoreToBracket(_ score: Double) -> String {
        if score >= 80 { return "80-100" }
        if score >= 60 { return "60-80" }
        if score >= 40 { return "40-60" }
        if score >= 20 { return "20-40" }
        return "0-20"
    }
    
    // MARK: - Aggregation
    
    private func aggregatePatterns(_ patterns: [ModulePattern]) -> [ModuleLearning] {
        // Group by module and bracket
        var aggregated: [String: [String: ActionStats]] = [:]
        
        for pattern in patterns {
            if aggregated[pattern.module] == nil {
                aggregated[pattern.module] = [:]
            }
            if aggregated[pattern.module]?[pattern.scoreBracket] == nil {
                aggregated[pattern.module]?[pattern.scoreBracket] = ActionStats()
            }
            
            aggregated[pattern.module]?[pattern.scoreBracket]?.recordAction(pattern.action)
        }
        
        // Convert to learnings
        var learnings: [ModuleLearning] = []
        
        for (module, brackets) in aggregated {
            for (bracket, stats) in brackets {
                learnings.append(ModuleLearning(
                    module: module,
                    scoreBracket: bracket,
                    totalDecisions: stats.total,
                    actionDistribution: stats.distribution,
                    dominantAction: stats.dominantAction
                ))
            }
        }
        
        return learnings
    }
    
    // MARK: - Save to Alkindus
    
    private func saveLearnings(_ learnings: [ModuleLearning]) async {
        for learning in learnings {
            // Record as calibration data
            // Since we don't have pnl outcomes, we record decision patterns
            print("👁️ Alkindus Learning: \(learning.module) [\(learning.scoreBracket)] -> \(learning.dominantAction) (\(learning.totalDecisions) decisions)")
        }
        
        // Save summary to file
        let summary = ProcessingSummary(
            processedAt: Date(),
            moduleLearnings: learnings
        )
        
        if let data = try? JSONEncoder().encode(summary) {
            let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let summaryPath = docsPath.appendingPathComponent("alkindus_learning_summary.json")
            try? data.write(to: summaryPath)
        }
    }
    
    // MARK: - Cleanup
    
    func markEventsAsProcessed() {
        let sql = "UPDATE events SET processed = 1 WHERE processed = 0 OR processed IS NULL;"
        queue.sync {
            openDatabase()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_DONE {
                    print("👁️ AlkindusProcessor: Marked all events as processed")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func deleteProcessedBlobs() {
        let sql = "DELETE FROM blobs;"
        queue.sync {
            openDatabase()
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_DONE {
                    print("👁️ AlkindusProcessor: Deleted all blobs")
                }
            }
            sqlite3_finalize(stmt)
            
            // Vacuum to reclaim space
            sqlite3_exec(db, "VACUUM;", nil, nil, nil)
            print("👁️ AlkindusProcessor: Database vacuumed")
        }
    }
    
    /// Returns database size in MB
    func getDatabaseSizeMB() -> Double {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return Double(size) / 1024 / 1024
    }
}

// MARK: - Data Models

struct EventData {
    let eventId: String
    let eventType: String
    let symbol: String?
    let payloadJson: String
}

struct ModulePattern {
    let module: String
    let scoreBracket: String
    let action: String
    let symbol: String?
}

class ActionStats {
    private var actions: [String: Int] = [:]
    var total: Int { actions.values.reduce(0, +) }
    
    func recordAction(_ action: String) {
        actions[action, default: 0] += 1
    }
    
    var distribution: [String: Int] { actions }
    var dominantAction: String { actions.max(by: { $0.value < $1.value })?.key ?? "UNKNOWN" }
}

struct ModuleLearning: Codable {
    let module: String
    let scoreBracket: String
    let totalDecisions: Int
    let actionDistribution: [String: Int]
    let dominantAction: String
}

struct ProcessingResult {
    let eventsProcessed: Int
    let patternsExtracted: Int
    let modulesLearned: [String]
}

struct ProcessingSummary: Codable {
    let processedAt: Date
    let moduleLearnings: [ModuleLearning]
}
