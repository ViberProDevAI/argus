import Foundation

// MARK: - Atlas Council Protocol & Models
// The Fundamental Council - evaluates stocks based on financial metrics

// MARK: - Fundamental Council Member Protocol

/// A member of the Atlas Fundamental Council
protocol FundamentalCouncilMember: Sendable {
    var id: String { get }
    var name: String { get }
    
    /// Analyze financial data and optionally propose an action
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal?
    
    /// Vote on another member's proposal
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote
}

// MARK: - Financial Snapshot (Input Data)

/// Snapshot of financial data for analysis
struct FinancialSnapshot: Sendable, Codable {
    let symbol: String
    let marketCap: Double?
    let price: Double
    
    // Valuation
    let peRatio: Double?
    let forwardPE: Double?
    let pbRatio: Double?
    let psRatio: Double?
    let evToEbitda: Double?
    
    // Growth
    let revenueGrowth: Double?      // YoY %
    let earningsGrowth: Double?     // YoY %
    let epsGrowth: Double?          // YoY %
    
    // Quality
    let roe: Double?                // Return on Equity %
    let roa: Double?                // Return on Assets %
    let debtToEquity: Double?
    let currentRatio: Double?
    let grossMargin: Double?
    let operatingMargin: Double?
    let netMargin: Double?
    
    // Dividend
    let dividendYield: Double?
    let payoutRatio: Double?
    let dividendGrowth: Double?     // 5yr avg
    
    // Other
    let beta: Double?
    let sharesOutstanding: Double?
    let floatShares: Double?
    let insiderOwnership: Double?
    let institutionalOwnership: Double?
    
    // Sector comparison
    let sectorPE: Double?
    let sectorPB: Double?
    
    // Analyst Expectations (Yahoo Finance)
    let targetMeanPrice: Double?     // Analist hedef fiyat ortalaması
    let targetHighPrice: Double?     // En yüksek hedef
    let targetLowPrice: Double?      // En düşük hedef
    let recommendationMean: Double?  // 1.0=Strong Buy, 5.0=Sell
    let analystCount: Int?           // Kaç analist
    
    static func empty(symbol: String, price: Double) -> FinancialSnapshot {
        FinancialSnapshot(
            symbol: symbol, marketCap: nil, price: price,
            peRatio: nil, forwardPE: nil, pbRatio: nil, psRatio: nil, evToEbitda: nil,
            revenueGrowth: nil, earningsGrowth: nil, epsGrowth: nil,
            roe: nil, roa: nil, debtToEquity: nil, currentRatio: nil,
            grossMargin: nil, operatingMargin: nil, netMargin: nil,
            dividendYield: nil, payoutRatio: nil, dividendGrowth: nil,
            beta: nil, sharesOutstanding: nil, floatShares: nil,
            insiderOwnership: nil, institutionalOwnership: nil,
            sectorPE: nil, sectorPB: nil,
            targetMeanPrice: nil, targetHighPrice: nil, targetLowPrice: nil,
            recommendationMean: nil, analystCount: nil
        )
    }
}

// MARK: - Fundamental Proposal

struct FundamentalProposal: Sendable, Identifiable, Codable {
    let id = UUID()
    let proposer: String
    let proposerName: String
    let action: ProposedAction
    let confidence: Double
    let reasoning: String
    let targetPrice: Double?
    let intrinsicValue: Double?
    let marginOfSafety: Double?  // % discount to intrinsic value
    let timestamp: Date = Date()
}

// MARK: - Fundamental Vote

struct FundamentalVote: Sendable, Codable {
    let voter: String
    let voterName: String
    let decision: VoteDecision
    let reasoning: String?
    let weight: Double
}

// MARK: - Atlas Council Decision

struct AtlasDecision: Sendable, Codable {
    let symbol: String
    let action: ProposedAction
    let netSupport: Double
    let isStrongSignal: Bool
    let intrinsicValue: Double?
    let marginOfSafety: Double?
    let winningProposal: FundamentalProposal?
    let allProposals: [FundamentalProposal]
    let votes: [FundamentalVote]
    let vetoReasons: [String]
    let timestamp: Date
    
    var signalStrength: String {
        if isStrongSignal { return "GÜÇLÜ" }
        if netSupport >= 0.10 { return "ZAYIF" }
        return "YOK"
    }
    
    var summary: String {
        let actionStr = winningProposal?.action.rawValue ?? "KARAR YOK"
        return "[\(symbol)] \(actionStr) | Destek: \(String(format: "%.0f", netSupport * 100))%"
    }
}

// MARK: - Atlas Voting Record (For Learning)

struct AtlasVotingRecord: Codable, Sendable {
    let id: UUID
    let symbol: String
    let engine: AutoPilotEngine
    let timestamp: Date
    let proposerId: String
    let action: ProposedAction
    let approvers: [String]
    let vetoers: [String]
    let abstainers: [String]
    let finalDecision: ProposedAction
    let netSupport: Double
    var outcome: TradeOutcome?
    var pnlPercent: Double?
}

// MARK: - Atlas Member Weights

struct AtlasMemberWeights: Codable, Sendable {
    var valueMaster: Double
    var growthMaster: Double
    var qualityMaster: Double
    var dividendMaster: Double
    var moatMaster: Double
    var updatedAt: Date
    var confidence: Double
    
    static let defaultCorse = AtlasMemberWeights(
        valueMaster: 0.30,      // Değer yatırımı önemli
        growthMaster: 0.25,     // Büyüme de önemli
        qualityMaster: 0.25,    // Kalite kritik
        dividendMaster: 0.10,   // Temettü ikincil
        moatMaster: 0.10,       // Rekabet avantajı
        updatedAt: Date(),
        confidence: 0.5
    )
    
    static let defaultPulse = AtlasMemberWeights(
        valueMaster: 0.15,      // Kısa vadede değer az önemli
        growthMaster: 0.40,     // Büyüme momentum için kritik
        qualityMaster: 0.20,    // Kalite
        dividendMaster: 0.05,   // Temettü önemsiz
        moatMaster: 0.20,       // Moat haber/hype için önemli
        updatedAt: Date(),
        confidence: 0.5
    )
    
    func weight(for memberId: String) -> Double {
        switch memberId {
        case "value_master": return valueMaster
        case "growth_master": return growthMaster
        case "quality_master": return qualityMaster
        case "dividend_master": return dividendMaster
        case "moat_master": return moatMaster
        default: return 0.1
        }
    }
    
    func normalized() -> AtlasMemberWeights {
        let total = valueMaster + growthMaster + qualityMaster + dividendMaster + moatMaster
        guard total > 0 else { return self }
        return AtlasMemberWeights(
            valueMaster: valueMaster / total,
            growthMaster: growthMaster / total,
            qualityMaster: qualityMaster / total,
            dividendMaster: dividendMaster / total,
            moatMaster: moatMaster / total,
            updatedAt: Date(),
            confidence: confidence
        )
    }
}
