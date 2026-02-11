import Foundation

/// Represents a single decision made by the Auto-Pilot engine.
/// "Black Box" recording for analysis.
struct AutoPilotDecision: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    
    // Mode / Scenario
    let mode: String           // "live", "shadow", "backtest"
    let strategy: String       // "Corse" (Swing), "Pulse" (Scalp)
    
    // Asset Info
    let symbol: String
    
    // Decision
    let action: String         // "buy", "sell", "hold", "skip"
    let quantity: Double       // 0 for hold/skip
    let positionValueUSD: Double?
    let price: Double?         // Execution price
    
    // Targets / Risk
    let takeProfit: Double?
    let stopLoss: Double?
    let riskMultiple: Double?  // Aether Risk Multiplier used
    
    // Scores (0-100)
    let atlasScore: Double?        // Fundamental
    let orionScore: Double?        // Technical
    let aetherScore: Double?       // Macro
    let hermesScore: Double?       // News/Sentiment
    let demeterScore: Double?      // Sector
    let argusFinalScore: Double?   // Aggregated
    
    // Data Quality
    let dataQualityScore: Double?  // 0-100
    let fundamentalsPartial: Bool
    let technicalPartial: Bool
    let macroPartial: Bool
    let cryptoFallbackUsed: Bool
    let dataSourceNotes: String?
    let provider: String? // Added for visibility (e.g. "TwelveData")
    
    // Portfolio Context
    let portfolioValueBefore: Double?
    let portfolioValueAfter: Double?
    
    // Explanation
    let rationale: String?
}
