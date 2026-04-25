import Foundation

// MARK: - Forward Test Events (Black Box V0)

/// Represents a raw data capture.
struct DataSnapshotEvent: Codable {
    let snapshot_id: String
    let symbol: String
    let data_type: String // CANDLES_OHLCV | FUNDAMENTALS | MACRO | NEWS
    let blob_ref: String
    let ingestion_time_utc: String
    let market_time_utc: String?
    let provider_attempts: [ProviderAttempt]
    let final_source: String
    
    struct ProviderAttempt: Codable {
        let provider_name: String
        let status: String // ok | timeout | error
        let latency_ms: Int
    }
}

/// Represents the final decision of the Council.
struct DecisionEvent: Codable {
    let decision_id: String
    let symbol: String
    let action: String // BUY | SELL | HOLD | PASS | VETO
    let current_price: Double? // Forward test icin eklendi
    let module_scores: [String: Double]? // Orion, Atlas, etc.
    let input_blobs: [BlobRef]
    let signatures: DecisionSignatures
    
    struct BlobRef: Codable {
        let type: String
        let hash_id: String
    }
    
    struct DecisionSignatures: Codable {
        let engine_version: String
        let config_hash: String
        let weights_hash: String
    }
}

/// Represents a single module's vote.
struct ModuleOpinionEvent: Codable {
    let decision_id: String
    let module: String
    let stance: String
    let score: Double
    let confidence: Double
    let reasoning_code: String
}

// MARK: - Event Recording Extension

extension ArgusLedger {
    
    func logDataSnapshot(
        symbol: String,
        type: String,
        blobData: Data,
        marketTime: Date?,
        provider: String,
        latencyMs: Int
    ) -> String? {
        // 1. Write Blob
        let meta: [String: Any] = ["provider": provider, "latency": latencyMs]
        guard let hash = writeBlob(type: type, data: blobData, meta: meta) else { return nil }
        
        // 2. Create Event Payload
        let attempt = DataSnapshotEvent.ProviderAttempt(provider_name: provider, status: "ok", latency_ms: latencyMs)
        let event = DataSnapshotEvent(
            snapshot_id: UUID().uuidString,
            symbol: symbol,
            data_type: type,
            blob_ref: hash,
            ingestion_time_utc: Date().iso8601,
            market_time_utc: marketTime?.iso8601,
            provider_attempts: [attempt],
            final_source: provider
        )
        
        // 3. Serialize and Record
        if let jsonDict = try? event.asDictionary() {
            recordEvent(type: "DataSnapshotEvent", decisionId: nil, symbol: symbol, payload: jsonDict)
        }
        return hash
    }
    
    func logDecision(
        decisionId: String,
        symbol: String,
        action: String,
        currentPrice: Double, // Forward test icin eklendi
        moduleScores: [String: Double]?, // Modul skorlari
        inputBlobHashes: [String],
        configHash: String,
        weightsHash: String
    ) {
        let blobs = inputBlobHashes.map { DecisionEvent.BlobRef(type: "UNKNOWN", hash_id: $0) }
        let sigs = DecisionEvent.DecisionSignatures(
            engine_version: "AGORA-2.1",
            config_hash: configHash,
            weights_hash: weightsHash
        )
        
        let event = DecisionEvent(
            decision_id: decisionId,
            symbol: symbol,
            action: action,
            current_price: currentPrice,
            module_scores: moduleScores,
            input_blobs: blobs,
            signatures: sigs
        )
        
        if let jsonDict = try? event.asDictionary() {
            recordEvent(type: "DecisionEvent", decisionId: decisionId, symbol: symbol, payload: jsonDict)
        }
    }
}

// Helper to convert Encodable to Dictionary
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}
