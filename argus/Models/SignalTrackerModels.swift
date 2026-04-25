import Foundation

/// Represents a snapshot of an Argus Decision at a specific point in time.
/// Used for "Forward Testing" (Live Tracking) to validate strategy performance with 100% real data.
struct TrackedSignal: Codable, Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let date: Date
    
    // Market Data Snapshot
    let entryPrice: Double
    
    // Scores Snapshot
    let atlasScore: Double?
    let orionScore: Double?
    let aetherScore: Double?
    let hermesScore: Double?
    let athenaScore: Double? // Factors
    
    // Decision Snapshot
    let actionCore: String // "BUY", "SELL", "HOLD"
    let actionPulse: String // "BUY", "SELL", "HOLD"
    let regime: String // "Trend", "Chop", etc.
    
    // Performance Tracking
    var outcomes: [ArgusSignalOutcome] = []
    
    init(
        id: UUID = UUID(),
        symbol: String,
        date: Date = Date(),
        entryPrice: Double,
        atlasScore: Double?,
        orionScore: Double?,
        aetherScore: Double?,
        hermesScore: Double?,
        athenaScore: Double?,
        actionCore: String,
        actionPulse: String,
        regime: String
    ) {
        self.id = id
        self.symbol = symbol
        self.date = date
        self.entryPrice = entryPrice
        self.atlasScore = atlasScore
        self.orionScore = orionScore
        self.aetherScore = aetherScore
        self.hermesScore = hermesScore
        self.athenaScore = athenaScore
        self.actionCore = actionCore
        self.actionPulse = actionPulse
        self.regime = regime
    }
}

/// Represents a performance check at a future date.
struct ArgusSignalOutcome: Codable, Identifiable, Sendable {
    let id: UUID
    let checkDate: Date
    let currentPrice: Double
    let pnlPercentage: Double
    let timeframeDays: Int // e.g. 5, 20, 60 days later
    
    init(date: Date = Date(), currentPrice: Double, entryPrice: Double, timeframeDays: Int = 0) {
        self.id = UUID()
        self.checkDate = date
        self.currentPrice = currentPrice
        self.pnlPercentage = ((currentPrice - entryPrice) / entryPrice) * 100.0
        self.timeframeDays = timeframeDays
    }
}
