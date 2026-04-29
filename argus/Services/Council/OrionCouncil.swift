import Foundation

// MARK: - Orion Council
/// The main technical decision council - collects proposals, conducts voting, and decides
actor OrionCouncil {
    static let shared = OrionCouncil()
    
    // Council members
    private let members: [any TechnicalCouncilMember]
    
    private init() {
        self.members = [
            TrendMasterEngine(),
            MomentumMasterEngine(),
            StructureMasterEngine(),
            PatternMasterEngine(),
            PriceMasterEngine()
        ]
    }
    
    // Weight store reference
    private let weightStore = ChironWeightStore.shared
    
    // MARK: - Public API
    
    /// Main entry point: Convene the council for a symbol
    func convene(symbol: String, candles: [Candle], engine: AutoPilotEngine = .pulse) async -> CouncilDecision {
        let timestamp = Date()
        
        guard candles.count >= 50 else {
            return CouncilDecision(
                symbol: symbol,
                action: .hold,
                netSupport: 0,
                approveWeight: 0,
                vetoWeight: 0,
                isStrongSignal: false,
                isWeakSignal: false,
                winningProposal: nil,
                allProposals: [],
                votes: [],
                vetoReasons: ["Yetersiz veri (min 50 mum)"],
                timestamp: timestamp
            )
        }
        
        ArgusLogger.info(.orion, "Konsey toplanıyor: \(symbol)")

        // 1. Collect proposals from all members
        let proposals = await collectProposals(symbol: symbol, candles: candles)
        ArgusLogger.info(.orion, "\(proposals.count) öneri toplandı")
        
        // 2. If no proposals, return hold
        guard !proposals.isEmpty else {
            return CouncilDecision(
                symbol: symbol,
                action: .hold,
                netSupport: 0,
                approveWeight: 0,
                vetoWeight: 0,
                isStrongSignal: false,
                isWeakSignal: false,
                winningProposal: nil,
                allProposals: [],
                votes: [],
                vetoReasons: [],
                timestamp: timestamp
            )
        }
        
        // 3. Select the best proposal (highest confidence)
        let bestProposal = proposals.max(by: { $0.confidence < $1.confidence })!
        ArgusLogger.info(.orion, "En iyi öneri: \(bestProposal.proposerName) -> \(bestProposal.action.rawValue) (Güven: \(Int(bestProposal.confidence * 100))%)")
        
        // 4. Conduct voting on the best proposal
        let votes = await conductVoting(
            proposal: bestProposal, 
            candles: candles, 
            symbol: symbol,
            engine: engine
        )
        
        // 5. Calculate final decision
        let decision = calculateDecision(
            symbol: symbol,
            proposal: bestProposal,
            allProposals: proposals,
            votes: votes,
            timestamp: timestamp
        )
        
        ArgusLogger.info(.orion, "Sonuç: \(decision.summary)")
        
        return decision
    }
    
    // MARK: - Proposal Collection
    
    private func collectProposals(symbol: String, candles: [Candle]) async -> [CouncilProposal] {
        var proposals: [CouncilProposal] = []
        
        for member in members {
            if let proposal = await member.analyze(candles: candles, symbol: symbol) {
                proposals.append(proposal)
            }
        }
        
        return proposals
    }
    
    // MARK: - Voting
    
    private func conductVoting(
        proposal: CouncilProposal,
        candles: [Candle],
        symbol: String,
        engine: AutoPilotEngine
    ) async -> [CouncilVote] {
        var votes: [CouncilVote] = []
        
        // Get Chiron weights for this symbol+engine (non-blocking)
        let weights = weightStore.getCouncilWeights(symbol: symbol, engine: engine)
        
        for member in members {
            // Skip the proposer (they don't vote on their own proposal)
            if member.id == proposal.proposer { continue }
            
            var vote = member.vote(on: proposal, candles: candles, symbol: symbol)
            
            // Apply Chiron weight
            let memberWeight = weights.weight(for: member.id)
            vote = CouncilVote(
                voter: vote.voter,
                voterName: vote.voterName,
                decision: vote.decision,
                reasoning: vote.reasoning,
                weight: memberWeight * vote.weight // Combine member's vote strength with Chiron weight
            )
            
            votes.append(vote)
            ArgusLogger.info(.orion, "Oy: \(vote.voterName): \(vote.decision.rawValue) (Ağırlık: \(String(format: "%.0f", vote.weight * 100))%) - \(vote.reasoning ?? "")")
        }
        
        return votes
    }
    
    // MARK: - Decision Calculation
    
    private func calculateDecision(
        symbol: String,
        proposal: CouncilProposal,
        allProposals: [CouncilProposal],
        votes: [CouncilVote],
        timestamp: Date
    ) -> CouncilDecision {
        
        // Calculate weighted support
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
                // Abstain doesn't count
                break
            }
        }
        
        // Add proposer's confidence as part of approve weight
        approveWeight += proposal.confidence * 0.5 // Proposer has some weight
        
        // Net support
        let netSupport = approveWeight - vetoWeight
        
        // Determine signal strength
        let isStrongSignal = netSupport >= 0.30
        let isWeakSignal = netSupport >= 0.10 && netSupport < 0.30
        
        // Final action
        let finalAction: ProposedAction
        if netSupport >= 0.10 {
            finalAction = proposal.action
        } else if netSupport <= -0.20 {
            // Strong veto - opposite action or hold
            finalAction = .hold
        } else {
            finalAction = .hold
        }
        
        return CouncilDecision(
            symbol: symbol,
            action: finalAction,
            netSupport: netSupport,
            approveWeight: approveWeight,
            vetoWeight: vetoWeight,
            isStrongSignal: isStrongSignal,
            isWeakSignal: isWeakSignal,
            winningProposal: proposal,
            allProposals: allProposals,
            votes: votes,
            vetoReasons: vetoReasons,
            timestamp: timestamp
        )
    }
    
    // MARK: - Voting Record (For Chiron Learning)
    
    func createVotingRecord(decision: CouncilDecision, engine: AutoPilotEngine) -> CouncilVotingRecord {
        let approvers = decision.votes.filter { $0.decision == .approve }.map { $0.voter }
        let vetoers = decision.votes.filter { $0.decision == .veto }.map { $0.voter }
        let abstainers = decision.votes.filter { $0.decision == .abstain }.map { $0.voter }
        
        return CouncilVotingRecord(
            id: UUID(),
            symbol: decision.symbol,
            engine: engine,
            timestamp: decision.timestamp,
            proposerId: decision.winningProposal?.proposer ?? "none",
            action: (decision.winningProposal?.action ?? .hold).rawValue,
            approvers: approvers,
            vetoers: vetoers,
            abstainers: abstainers,
            finalDecision: decision.action.rawValue,
            netSupport: decision.netSupport,
            outcome: nil,
            pnlPercent: nil
        )
    }
}

// MARK: - ChironWeightStore Extension (Council Weights)

extension ChironWeightStore {
    /// Get council member weights for a symbol+engine (non-blocking)
    nonisolated func getCouncilWeights(symbol: String, engine: AutoPilotEngine) -> CouncilMemberWeights {
        // Use the council learning service for learned weights
        return ChironCouncilLearningService.shared.getCouncilWeights(symbol: symbol, engine: engine)
    }
    
    /// Update council member weights after learning
    func updateCouncilWeights(symbol: String, engine: AutoPilotEngine, weights: CouncilMemberWeights) async {
        // TODO: Implement persistence for council weights
        ArgusLogger.info(.chiron, "Konsey ağırlıkları güncellendi: \(symbol) (\(engine.rawValue))")
    }
}
