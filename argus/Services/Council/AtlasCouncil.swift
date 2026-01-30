import Foundation

// MARK: - Atlas Council
/// The Fundamental Council - evaluates stocks based on financial metrics
actor AtlasCouncil {
    static let shared = AtlasCouncil()
    
    // Council members
    private let members: [any FundamentalCouncilMember]
    
    private init() {
        self.members = [
            ValueMasterEngine(),
            GrowthMasterEngine(),
            QualityMasterEngine(),
            DividendMasterEngine(),
            MoatMasterEngine()
        ]
    }
    
    // MARK: - Public API
    
    /// Main entry point: Convene the council for a symbol
    func convene(symbol: String, financials: FinancialSnapshot, engine: AutoPilotEngine = .corse) async -> AtlasDecision {
        let timestamp = Date()
        
        print("🏛️ Atlas Konseyi Toplanıyor: \(symbol)")
        
        // 1. Collect proposals from all members
        let proposals = await collectProposals(symbol: symbol, financials: financials)
        print("   📋 \(proposals.count) öneri toplandı")
        
        // 2. If no proposals, return hold
        guard !proposals.isEmpty else {
            return AtlasDecision(
                symbol: symbol,
                action: .hold,
                netSupport: 0,
                isStrongSignal: false,
                intrinsicValue: nil,
                marginOfSafety: nil,
                winningProposal: nil,
                allProposals: [],
                votes: [],
                vetoReasons: [],
                timestamp: timestamp
            )
        }
        
        // 3. Select the best proposal (highest confidence)
        let bestProposal = proposals.max(by: { $0.confidence < $1.confidence })!
        print("   🎯 En iyi öneri: \(bestProposal.proposerName) → \(bestProposal.action.rawValue) (Güven: \(Int(bestProposal.confidence * 100))%)")
        
        // 4. Conduct voting on the best proposal
        let votes = conductVoting(proposal: bestProposal, financials: financials, engine: engine)
        
        // 5. Calculate final decision
        let decision = calculateDecision(
            symbol: symbol,
            proposal: bestProposal,
            allProposals: proposals,
            votes: votes,
            timestamp: timestamp
        )
        
        print("   📊 Sonuç: \(decision.summary)")
        
        return decision
    }
    
    // MARK: - Proposal Collection
    
    private func collectProposals(symbol: String, financials: FinancialSnapshot) async -> [FundamentalProposal] {
        var proposals: [FundamentalProposal] = []
        
        for member in members {
            if let proposal = await member.analyze(financials: financials, symbol: symbol) {
                proposals.append(proposal)
            }
        }
        
        return proposals
    }
    
    // MARK: - Voting
    
    private func conductVoting(
        proposal: FundamentalProposal,
        financials: FinancialSnapshot,
        engine: AutoPilotEngine
    ) -> [FundamentalVote] {
        var votes: [FundamentalVote] = []
        
        // Get weights based on engine
        let weights: AtlasMemberWeights
        switch engine {
        case .corse:
            weights = .defaultCorse
        case .pulse:
            weights = .defaultPulse
        default:
            weights = .defaultCorse
        }
        
        for member in members {
            // Skip the proposer
            if member.id == proposal.proposer { continue }
            
            var vote = member.vote(on: proposal, financials: financials)
            
            // Apply weight
            let memberWeight = weights.weight(for: member.id)
            vote = FundamentalVote(
                voter: vote.voter,
                voterName: vote.voterName,
                decision: vote.decision,
                reasoning: vote.reasoning,
                weight: memberWeight * vote.weight
            )
            
            votes.append(vote)
            print("      \(vote.decision.emoji) \(vote.voterName): \(vote.decision.rawValue) (Ağırlık: \(String(format: "%.0f", vote.weight * 100))%) - \(vote.reasoning ?? "")")
        }
        
        return votes
    }
    
    // MARK: - Decision Calculation
    
    private func calculateDecision(
        symbol: String,
        proposal: FundamentalProposal,
        allProposals: [FundamentalProposal],
        votes: [FundamentalVote],
        timestamp: Date
    ) -> AtlasDecision {
        
        var approveWeight = 0.0
        var vetoWeight = 0.0
        var vetoReasons: [String] = []
        
        for vote in votes {
            switch vote.decision {
            case .approve:
                approveWeight += vote.weight
            case .veto:
                vetoWeight += vote.weight
                if let reason = vote.reasoning {
                    vetoReasons.append("\(vote.voterName): \(reason)")
                }
            case .abstain:
                break
            }
        }
        
        // Add proposer's confidence
        approveWeight += proposal.confidence * 0.5
        
        let netSupport = approveWeight - vetoWeight
        let isStrongSignal = netSupport >= 0.30
        
        let finalAction: ProposedAction
        if netSupport >= 0.10 {
            finalAction = proposal.action
        } else {
            finalAction = .hold
        }
        
        return AtlasDecision(
            symbol: symbol,
            action: finalAction,
            netSupport: netSupport,
            isStrongSignal: isStrongSignal,
            intrinsicValue: proposal.intrinsicValue,
            marginOfSafety: proposal.marginOfSafety,
            winningProposal: proposal,
            allProposals: allProposals,
            votes: votes,
            vetoReasons: vetoReasons,
            timestamp: timestamp
        )
    }
}
