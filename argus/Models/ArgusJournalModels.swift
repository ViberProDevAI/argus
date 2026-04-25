import Foundation

// MARK: - Journal Models

/// The lightweight index entry for the Journal List.
struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let date: Date
    let action: String // "BUY", "SELL"
    var status: JournalStatus // Open, Closed
    let entryPrice: Double
    var currentPrice: Double?
    var outcome: Double? // PnL %
}

enum JournalStatus: String, Codable {
    case open = "OPEN"
    case closed = "CLOSED"
}

/// The heavy detail snapshot saved as a separate JSON file.
struct SignalSnapshot: Identifiable, Codable {
    let id: UUID // Matches JournalEntry.id
    let timestamp: Date
    
    // Context
    let symbol: String
    let price: Double
    
    // The Brain State
    let scores: ArgusScores
    let decision: ArgusDecisionResult
    
    // Deep Context (For "Autopsy")
    let candles: [Candle] // Last 10 candles
    let explanation: String?
}

struct ArgusScores: Codable {
    let atlas: Double?
    let orion: Double?
    let aether: Double?
    let hermes: Double?
    let athena: Double?
    let demeter: Double?
}
