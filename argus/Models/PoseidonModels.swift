import Foundation
import SwiftUI

// MARK: - Poseidon Models

/// Represents a single Insider Trading transaction (Form 4).
struct InsiderTrade: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String // e.g. "Elon Musk"
    let role: String // e.g. "CEO", "Director"
    let type: TransactionType // Buy/Sell
    let amount: Double // Value in USD
    let shares: Int
    let price: Double
    let date: Date
    
    var formattedAmount: String {
        if amount >= 1_000_000 {
            return String(format: "$%.1fM", amount / 1_000_000)
        } else {
            return String(format: "$%.0fK", amount / 1_000)
        }
    }
}

/// Represents Institutional Money Flow (13F).
struct InstitutionalFlow: Identifiable, Codable, Sendable {
    let id: UUID
    let institution: String // e.g. "BlackRock", "Vanguard"
    let changePercent: Double // +5.2% or -1.2%
    let sharesHeld: Int
    let date: Date
}

/// Represents a Dark Pool Block Trade using volume spikes.
struct DarkPoolPrint: Identifiable, Codable, Sendable {
    let id: UUID
    let price: Double
    let volume: Int
    let notional: Double // Price * Volume
    let type: String // "Block", "Sweep"
    let date: Date
    
    var sentiment: SignalAction {
        // Simple heuristic: If price rose after print -> Buy, else Sell styling
        return .hold 
    }
}

/// The composite "Smart Money" sentiment score.
struct WhaleScore: Codable, Sendable {
    let symbol: String
    let totalScore: Double // 0-100 (0=Bearish Whirlpool, 100=Bullish Tsunami)
    
    // Components
    let insiderScore: Double
    let institutionalScore: Double
    let darkPoolScore: Double
    
    // Insight
    let summary: String // "CEO is buying, but BlackRock is selling."
    
    var sentimentColor: Color {
        if totalScore >= 70 { return Theme.positive }
        if totalScore <= 30 { return Theme.negative }
        return .gray
    }
}
