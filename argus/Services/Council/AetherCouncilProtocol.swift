import Foundation

// MARK: - Aether Council Protocol & Models
// The Macro Council - evaluates market conditions and macro environment

// MARK: - Macro Council Member Protocol

protocol MacroCouncilMember: Sendable {
    var id: String { get }
    var name: String { get }
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal?
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote
}

// MacroSnapshot and Enums moved to Models/MacroModels.swift

// MARK: - Macro Proposal

struct MacroProposal: Sendable, Identifiable, Codable {
    let id = UUID()
    let proposer: String
    let proposerName: String
    let stance: MacroStance
    let confidence: Double
    let reasoning: String
    let timestamp: Date = Date()
}

enum MacroStance: String, Sendable, Codable {
    case riskOn = "RİSK AL"
    case cautious = "DİKKATLİ"
    case defensive = "SAVUN"
    case riskOff = "RİSK KAPAT"
    
    var emoji: String {
        switch self {
        case .riskOn: return "🟢"
        case .cautious: return "🟡"
        case .defensive: return "🟠"
        case .riskOff: return "🔴"
        }
    }
}

// MARK: - Macro Vote

struct MacroVote: Sendable, Codable {
    let voter: String
    let voterName: String
    let decision: VoteDecision
    let reasoning: String?
    let weight: Double
}

// MARK: - Aether Decision

struct AetherDecision: Sendable, Codable {
    let stance: MacroStance
    let marketMode: MarketMode
    let netSupport: Double
    let isStrongSignal: Bool
    let winningProposal: MacroProposal?
    let votes: [MacroVote]
    let warnings: [String]
    let timestamp: Date
    
    /// Should we block all buys?
    var blockBuys: Bool {
        stance == .riskOff || stance == .defensive
    }
    
    /// Position size multiplier (0.0 - 1.0)
    var positionMultiplier: Double {
        switch stance {
        case .riskOn: return 1.0
        case .cautious: return 0.7
        case .defensive: return 0.4
        case .riskOff: return 0.0
        }
    }
    
    var summary: String {
        "Makro: \(stance.rawValue) | Mod: \(marketMode.rawValue) | Destek: \(String(format: "%.0f", netSupport * 100))%"
    }
}

// MARK: - Aether Member Weights

struct AetherMemberWeights: Codable, Sendable {
    var fedMaster: Double
    var sentimentMaster: Double
    var sectorMaster: Double
    var cycleMaster: Double
    var correlationMaster: Double
    var updatedAt: Date
    var confidence: Double
    
    static let defaultWeights = AetherMemberWeights(
        fedMaster: 0.25,
        sentimentMaster: 0.25,
        sectorMaster: 0.20,
        cycleMaster: 0.15,
        correlationMaster: 0.15,
        updatedAt: Date(),
        confidence: 0.5
    )
    
    func weight(for memberId: String) -> Double {
        switch memberId {
        case "fed_master": return fedMaster
        case "sentiment_master": return sentimentMaster
        case "sector_master": return sectorMaster
        case "cycle_master": return cycleMaster
        case "correlation_master": return correlationMaster
        default: return 0.1
        }
    }
}
