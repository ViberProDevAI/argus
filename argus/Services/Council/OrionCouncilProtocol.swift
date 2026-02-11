import Foundation

// MARK: - Orion Council Protocol & Models
// The Council is a voting-based decision system where each technical member
// can propose actions and vote on others' proposals.

// MARK: - Council Member Protocol

/// A member of the Orion Technical Council
protocol TechnicalCouncilMember: Sendable {
    /// Unique identifier for this member
    var id: String { get }
    
    /// Display name
    var name: String { get }
    
    /// Analyze candles and optionally propose an action
    /// Returns nil if no strong opinion
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal?
    
    /// Vote on another member's proposal
    func vote(on proposal: CouncilProposal, candles: [Candle], symbol: String) -> CouncilVote
}

// MARK: - Proposal

/// A proposed action from a council member
struct CouncilProposal: Sendable, Identifiable, Codable {
    let id = UUID()
    let proposer: String           // Member ID who proposed
    let proposerName: String       // Display name
    let action: ProposedAction     // AL / SAT / BEKLE
    let confidence: Double         // 0-1
    let reasoning: String          // Why this action?
    let entryPrice: Double?        // Suggested entry
    let stopLoss: Double?          // Suggested stop
    let target: Double?            // Suggested target
    let timestamp: Date = Date()
}

/// Possible actions a member can propose
enum ProposedAction: String, Sendable, Codable {
    case buy = "AL"
    case sell = "SAT"
    case hold = "BEKLE"
    
    var emoji: String {
        switch self {
        case .buy: return "🟢"
        case .sell: return "🔴"
        case .hold: return "⚪"
        }
    }
}

// MARK: - Vote

/// A council member's vote on a proposal
struct CouncilVote: Sendable, Codable {
    let voter: String              // Member ID
    let voterName: String          // Display name
    let decision: VoteDecision
    let reasoning: String?         // Optional explanation
    let weight: Double             // Chiron-assigned weight (0-1)
}

/// Possible vote decisions
enum VoteDecision: String, Sendable, Codable {
    case approve = "ONAY"
    case veto = "VETO"
    case abstain = "ÇEKİMSER"
    
    var emoji: String {
        switch self {
        case .approve: return "✅"
        case .veto: return "❌"
        case .abstain: return "➖"
        }
    }
}

// MARK: - Council Decision (Final Output)

/// The final decision after council deliberation
struct CouncilDecision: Sendable, Codable {
    let symbol: String
    let action: ProposedAction
    let netSupport: Double              // APPROVE weight - VETO weight
    let approveWeight: Double           // Total approve weight
    let vetoWeight: Double              // Total veto weight
    let isStrongSignal: Bool            // netSupport >= 0.30
    let isWeakSignal: Bool              // netSupport >= 0.10 && < 0.30
    let winningProposal: CouncilProposal?
    let allProposals: [CouncilProposal]
    let votes: [CouncilVote]
    let vetoReasons: [String]           // Veto explanations
    let timestamp: Date
    
    /// Signal strength description
    var signalStrength: String {
        if isStrongSignal { return "GÜÇLÜ" }
        if isWeakSignal { return "ZAYIF" }
        return "YOK"
    }
    
    /// Summary for logging
    var summary: String {
        let actionStr = winningProposal?.action.rawValue ?? "KARAR YOK"
        return "[\(symbol)] \(actionStr) | Destek: \(String(format: "%.0f", netSupport * 100))% | Güç: \(signalStrength)"
    }
}

// MARK: - Voting Record (For Chiron Learning)

/// Records who proposed/voted what for later learning
struct CouncilVotingRecord: Codable, Sendable {
    let id: UUID
    let symbol: String
    let engine: AutoPilotEngine
    let timestamp: Date
    let proposerId: String              // Who proposed
    let action: String                  // Action RawValue (ProposedAction or ArgusAction)
    let approvers: [String]             // Member IDs who approved
    let vetoers: [String]               // Member IDs who vetoed
    let abstainers: [String]            // Member IDs who abstained
    let finalDecision: String           // Final Decision RawValue
    let netSupport: Double
    
    // Filled after trade closes
    var outcome: TradeOutcome?
    var pnlPercent: Double?
}

enum TradeOutcome: String, Codable, Sendable {
    case win
    case loss
    case breakeven
}

// MARK: - Council Member Weights (Chiron-managed)

/// Weights for each council member, per symbol+engine
struct CouncilMemberWeights: Codable, Sendable {
    var trendMaster: Double
    var momentumMaster: Double
    var structureMaster: Double
    var patternMaster: Double
    var priceMaster: Double
    var updatedAt: Date
    var confidence: Double
    
    static let defaultCorse = CouncilMemberWeights(
        trendMaster: 0.30,      // Trend önemli uzun vadede
        momentumMaster: 0.20,   // Momentum ikincil
        structureMaster: 0.25,  // Yapı önemli (destek/direnç)
        patternMaster: 0.15,    // Formasyonlar
        priceMaster: 0.10,      // Fiyat/hacim
        updatedAt: Date(),
        confidence: 0.5
    )
    
    static let defaultPulse = CouncilMemberWeights(
        trendMaster: 0.20,      // Kısa vadede trend daha az önemli
        momentumMaster: 0.35,   // Momentum kritik
        structureMaster: 0.15,  // Yapı
        patternMaster: 0.20,    // Formasyonlar önemli
        priceMaster: 0.10,      // Fiyat/hacim
        updatedAt: Date(),
        confidence: 0.5
    )
    
    /// Get weight for a member by ID
    func weight(for memberId: String) -> Double {
        switch memberId {
        case "trend_master": return trendMaster
        case "momentum_master": return momentumMaster
        case "structure_master": return structureMaster
        case "pattern_master": return patternMaster
        case "price_master": return priceMaster
        default: return 0.1
        }
    }
    
    /// Normalize weights to sum to 1.0
    func normalized() -> CouncilMemberWeights {
        let total = trendMaster + momentumMaster + structureMaster + patternMaster + priceMaster
        guard total > 0 else { return self }
        
        return CouncilMemberWeights(
            trendMaster: trendMaster / total,
            momentumMaster: momentumMaster / total,
            structureMaster: structureMaster / total,
            patternMaster: patternMaster / total,
            priceMaster: priceMaster / total,
            updatedAt: Date(),
            confidence: confidence
        )
    }
}

// MARK: - Absolute Veto Conditions

/// Conditions that trigger an absolute veto (cannot be overridden)
enum AbsoluteVetoCondition: String, Sendable {
    case majorResistance = "Major direnç noktası"
    case extremeOverbought = "Aşırı alım (RSI > 85)"
    case bearishPatternComplete = "Düşüş formasyonu tamamlandı"
    case strongDowntrend = "Güçlü düşüş trendi"
    case volumeDivergence = "Hacim uyumsuzluğu"
    
    var blocksAction: ProposedAction {
        switch self {
        case .majorResistance, .extremeOverbought, .bearishPatternComplete:
            return .buy
        case .strongDowntrend, .volumeDivergence:
            return .buy
        }
    }
}
