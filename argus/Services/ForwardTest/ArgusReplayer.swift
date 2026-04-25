import Foundation

// MARK: - Argus Replayer
/// Offline Decision Engine: Replays past decisions from stored snapshots
/// Ensures reproducibility by using archived data instead of live feeds
actor ArgusReplayer {
    static let shared = ArgusReplayer()
    
    private let ledger = ArgusLedger.shared
    
    // MARK: - Replay Result
    struct ReplayResult: Sendable {
        let originalEventId: String
        let originalAction: String
        let replayedAction: String
        let isConsistent: Bool        // Same decision?
        let originalScores: [String: Double]
        let replayedScores: [String: Double]
        let scoreDrift: [String: Double]  // Difference per module
        let timestamp: Date
        
        var summaryText: String {
            if isConsistent {
                return "✅ Tutarlı: \(originalAction)"
            } else {
                return "⚠️ Sapma: \(originalAction) → \(replayedAction)"
            }
        }
    }
    
    // MARK: - Replay Mode
    enum ReplayMode: Sendable {
        case strict        // Must match exactly (same hash = same output)
        case tolerant      // Allow minor score differences (<5%)
    }
    
    // MARK: - Public API
    
    /// Replays a single decision event using archived data
    func replay(eventId: String, mode: ReplayMode = .tolerant) async -> ReplayResult? {
        // 1. Load event from ledger
        guard let event = loadEvent(eventId: eventId) else {
            print("🔁 ArgusReplayer: Event not found: \(eventId)")
            return nil
        }
        
        // 2. Parse original payload
        guard let originalPayload = parsePayload(event.payloadJson) else {
            print("🔁 ArgusReplayer: Invalid payload for event: \(eventId)")
            return nil
        }
        
        let originalAction = originalPayload["action"] as? String ?? "UNKNOWN"
        let originalScores = originalPayload["scores"] as? [String: Double] ?? [:]
        let dataHash = originalPayload["data_version_hash"] as? String ?? ""
        
        // 3. Load archived snapshot (if available)
        guard let snapshot = loadSnapshot(hash: dataHash) else {
            print("🔁 ArgusReplayer: Snapshot not found for hash: \(dataHash.prefix(16))...")
            // Return "stale" result if no snapshot
            return ReplayResult(
                originalEventId: eventId,
                originalAction: originalAction,
                replayedAction: "STALE",
                isConsistent: false,
                originalScores: originalScores,
                replayedScores: [:],
                scoreDrift: [:],
                timestamp: Date()
            )
        }
        
        // 4. Replay decision with archived data
        let (replayedAction, replayedScores) = await replayDecision(
            symbol: event.symbol,
            snapshot: snapshot
        )
        
        // 5. Compare results
        let scoreDrift = calculateDrift(original: originalScores, replayed: replayedScores)
        let isConsistent = checkConsistency(
            originalAction: originalAction,
            replayedAction: replayedAction,
            drift: scoreDrift,
            mode: mode
        )
        
        print("🔁 ArgusReplayer: \(isConsistent ? "✅" : "⚠️") \(event.symbol) | \(originalAction) → \(replayedAction)")
        
        return ReplayResult(
            originalEventId: eventId,
            originalAction: originalAction,
            replayedAction: replayedAction,
            isConsistent: isConsistent,
            originalScores: originalScores,
            replayedScores: replayedScores,
            scoreDrift: scoreDrift,
            timestamp: Date()
        )
    }
    
    /// Replays multiple events and returns consistency statistics
    func replayBatch(eventIds: [String], mode: ReplayMode = .tolerant) async -> BatchReplayResult {
        var results: [ReplayResult] = []
        
        for eventId in eventIds {
            if let result = await replay(eventId: eventId, mode: mode) {
                results.append(result)
            }
        }
        
        let consistent = results.filter { $0.isConsistent }.count
        let total = results.count
        let rate = total > 0 ? Double(consistent) / Double(total) : 0
        
        return BatchReplayResult(
            results: results,
            consistentCount: consistent,
            totalCount: total,
            consistencyRate: rate
        )
    }
    
    struct BatchReplayResult: Sendable {
        let results: [ReplayResult]
        let consistentCount: Int
        let totalCount: Int
        let consistencyRate: Double
        
        var summaryText: String {
            String(format: "Tutarlılık: %d/%d (%.0f%%)", consistentCount, totalCount, consistencyRate * 100)
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadEvent(eventId: String) -> (symbol: String, payloadJson: String)? {
        // Query from ledger
        let sql = """
        SELECT symbol, payload_json FROM events WHERE event_id = ? LIMIT 1;
        """
        
        var result: (String, String)?
        
        // Sync query (simplified for actor isolation)
        let events = ledger.loadRecentDecisions(limit: 1000)
        if let event = events.first(where: { $0.id.uuidString == eventId }) {
            // Reconstruct minimal info
            return (event.symbol, "{}")  // Simplified: return symbol only
        }
        
        return nil
    }
    
    private func parsePayload(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    private func loadSnapshot(hash: String) -> ArchivedSnapshot? {
        // Load from blob storage
        guard let blobData = ledger.readBlob(hash: hash) else {
            return nil
        }
        
        // Decode snapshot
        guard let snapshot = try? JSONDecoder().decode(ArchivedSnapshot.self, from: blobData) else {
            return nil
        }
        
        return snapshot
    }
    
    private func replayDecision(symbol: String, snapshot: ArchivedSnapshot) async -> (String, [String: Double]) {
        // Simulate decision using archived data
        // In production: call ArgusGrandCouncil with archived data
        
        // For now, return placeholder (actual implementation would feed archived data to council)
        let action = snapshot.suggestedAction ?? "GÖZLE"
        let scores = snapshot.moduleScores
        
        return (action, scores)
    }
    
    private func calculateDrift(original: [String: Double], replayed: [String: Double]) -> [String: Double] {
        var drift: [String: Double] = [:]
        
        for (module, originalScore) in original {
            let replayedScore = replayed[module] ?? 0
            drift[module] = replayedScore - originalScore
        }
        
        return drift
    }
    
    private func checkConsistency(
        originalAction: String,
        replayedAction: String,
        drift: [String: Double],
        mode: ReplayMode
    ) -> Bool {
        // Check action match
        if originalAction != replayedAction {
            return false
        }
        
        // Check score drift
        switch mode {
        case .strict:
            // All scores must match exactly
            return drift.values.allSatisfy { abs($0) < 0.01 }
        case .tolerant:
            // Allow up to 5% drift per module
            return drift.values.allSatisfy { abs($0) < 5.0 }
        }
    }
}

// MARK: - Archived Snapshot
/// Represents a point-in-time data snapshot for replay
struct ArchivedSnapshot: Codable, Sendable {
    let symbol: String
    let timestamp: Date
    let moduleScores: [String: Double]
    let suggestedAction: String?
    let dataHash: String
    
    // Optional: raw input data
    let technicalData: TechnicalDataSnapshot?
    let fundamentalData: FundamentalDataSnapshot?
    let sentimentData: SentimentDataSnapshot?
}

struct TechnicalDataSnapshot: Codable, Sendable {
    let price: Double
    let sma20: Double?
    let sma50: Double?
    let rsi: Double?
    let macd: Double?
    let atr: Double?
}

struct FundamentalDataSnapshot: Codable, Sendable {
    let peRatio: Double?
    let pbRatio: Double?
    let roe: Double?
    let debtToEquity: Double?
}

struct SentimentDataSnapshot: Codable, Sendable {
    let score: Double
    let articleCount: Int
    let positiveRatio: Double
}
