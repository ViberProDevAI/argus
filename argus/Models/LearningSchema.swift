import Foundation
import SwiftData

/// Pillar 8: Learning Data Schema
/// Stores virtual trades and missed opportunities for Chiron's adaptive learning.

@Model
final class ShadowTradeSession {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var entryDate: Date
    var status: String // "Pending", "Won", "Lost"
    
    // Virtual Execution
    var entryPrice: Double
    var exitPrice: Double?
    var pnlPercent: Double?
    
    // Context Snapshot (The "Why")
    var recordedAtlasScore: Double
    var recordedOrionScore: Double
    var recordedAetherScore: Double
    var recordedVix: Double
    
    init(symbol: String, price: Double, atlas: Double, orion: Double, aether: Double, vix: Double) {
        self.id = UUID()
        self.symbol = symbol
        self.entryDate = Date()
        self.status = "Pending"
        self.entryPrice = price
        self.recordedAtlasScore = atlas
        self.recordedOrionScore = orion
        self.recordedAetherScore = aether
        self.recordedVix = vix
    }
}

@Model
final class MissedOpportunityLog {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var date: Date
    var score: Double
    var reason: String // e.g. "Low Health", "Score 65 (Below Threshold)"
    
    // Context to verify if we should have taken it
    var subsequentPriceChange24h: Double?
    
    init(symbol: String, score: Double, reason: String) {
        self.id = UUID()
        self.symbol = symbol
        self.date = Date()
        self.score = score
        self.reason = reason
    }
}
