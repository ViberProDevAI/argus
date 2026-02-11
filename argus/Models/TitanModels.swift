import Foundation
import SwiftUI

// MARK: - 1. ETF Profile Model
struct ETFProfile: Codable, Sendable {
    let symbol: String
    let name: String
    let description: String
    let inceptionDate: String?
    let sector: String? // e.g. "Technology"
    let expenseRatio: Double? // e.g. 0.09 for 0.09%
    let domicile: String? // "USA", "Ireland" etc.
    let holdingsCount: Int?
    
    // Helper accessors
    var isLowCost: Bool {
        return (expenseRatio ?? 0.0) < 0.20
    }
}

// MARK: - 2. Titan Signal Log (Persistence)
enum TitanContext: String, Codable, Sendable {
    case bullish = "Bullish"
    case bearish = "Bearish"
    case neutral = "Neutral"
    case mixed = "Mixed"
}

struct TitanSignalLog: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let date: Date
    let symbol: String
    
    // Scores
    let totalScore: Double // 0-100
    let techScore: Double
    let macroScore: Double
    let qualityScore: Double
    
    // Context
    let technicalContext: String // "Strong Trend + RSI Safe"
    let macroContext: String // "Sector Rotation Favorite"
    let qualityContext: String // "Low Cost Leader"
    
    var signalColor: String {
        if totalScore >= 70 { return "Green" }
        if totalScore <= 30 { return "Red" }
        return "Yellow"
    }
}


