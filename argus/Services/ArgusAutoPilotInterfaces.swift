import Foundation

// MARK: - AutoPilot Proposal System

enum AutoPilotAction: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case hold = "HOLD"
    case skip = "SKIP" // No action
}

struct AutoPilotProposal {
    let engine: AutoPilotEngine
    let symbol: String
    let action: AutoPilotAction
    
    // Sizing / Risk
    let targetExposurePercent: Double? // e.g. 0.05 for 5%
    let quantity: Double?
    
    // Explanation
    let rationale: String?
    let confidence: Double // 0-100
    
    // Context Snapshot (Validation)
    let dataQualityScore: Double
    let scores: (atlas: Double?, orion: Double?, aether: Double?, hermes: Double?)
}

// MARK: - Context & Protocol

struct AutoPilotContext {
    let symbol: String
    let price: Double
    let equity: Double
    let buyingPower: Double
    
    // Portfolio State
    let openTrade: Trade? // If we already sort it
    
    // Data
    let candles: [Candle]?
    let atlasScore: Double?
    let orionScore: Double?
    let aetherRating: MacroEnvironmentRating?
    let hermesInsight: NewsInsight?
    let argusFinalScore: Double?
    // let cronosScore: Double? (REMOVED)
}

protocol AutoPilotStrategyEngine {
    var engineType: AutoPilotEngine { get }
    
    func propose(for symbol: String, context: AutoPilotContext) async -> AutoPilotProposal
}

protocol TradeExecutor: AnyObject {
    func executeBuy(symbol: String, quantity: Double, price: Double, engine: AutoPilotEngine)
    func executeSell(symbol: String, quantity: Double, price: Double, engine: AutoPilotEngine, reason: String)
}
