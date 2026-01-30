import Foundation

// MARK: - Chiron Telemetry Models

/// A detailed snapshot of a trade at the moment of entry.
/// Used for RL training and system health analysis.
struct TradeSnapshot: Codable, Identifiable {
    var id: UUID { tradeId }
    let tradeId: UUID
    let symbol: String
    let entryDate: Date
    let direction: String // "Long" (Short not supported yet)
    
    // Execution Details
    let entryPrice: Double
    let quantity: Double
    let riskAmount: Double? // Dollar risk
    let stopLoss: Double?
    let takeProfit: Double?
    
    // Regime State (The \"Weather\" when trade was opened)
    let aetherScore: Double
    let orionScore: Double
    let atlasScore: Double
    let hermesScore: Double
    let demeterScore: Double?
    
    // Cluster Context
    let cluster: String
    
    // Outcome Metrics (Populated after exit)
    var exitDate: Date?
    var exitPrice: Double?
    var exitReason: String?
    var pnlPercent: Double?
    var mfe: Double? // Max Favorable Excursion (% from entry)
    var mae: Double? // Max Adverse Excursion (% from entry)
    var timeInTradeSec: TimeInterval?
}


