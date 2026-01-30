import Foundation

// MARK: - Hermes Council
/// The News Council - evaluates news and sentiment impact
@MainActor
struct HermesCouncil {
    static let shared = HermesCouncil()
    
    private let members: [any NewsCouncilMember]
    
    private init() {
        self.members = [
            HermesSentimentMasterEngine(),
            HermesImpactMasterEngine(),
            HermesTimingMasterEngine(),
            HermesCredibilityMasterEngine(),
            HermesCatalystMasterEngine()
        ]
    }
    
    // MARK: - Public API
    
    func convene(symbol: String, news: HermesNewsSnapshot) async -> HermesDecision {
        let timestamp = Date()
        
        print("🏛️ Hermes Konseyi Toplanıyor: \(symbol)")
        
        // 1. Collect proposals
        let proposals = await collectProposals(news: news, symbol: symbol)
        print("   📋 \(proposals.count) öneri toplandı")
        
        // 2. No news = neutral
        guard !proposals.isEmpty else {
            return HermesDecision(
                symbol: symbol,
                sentiment: .neutral,
                actionBias: .hold,
                netSupport: 0,
                isHighImpact: false,
                winningProposal: nil,
                votes: [],
                keyHeadlines: [],
                catalysts: [],
                timestamp: timestamp
            )
        }
        
        // 3. Best proposal
        let bestProposal = proposals.max(by: { $0.confidence < $1.confidence })!
        print("   🎯 En iyi öneri: \(bestProposal.proposerName) → \(bestProposal.sentiment.rawValue)")
        
        // 4. Voting
        let votes = conductVoting(proposal: bestProposal, news: news)
        
        // 5. Calculate decision
        let decision = calculateDecision(
            symbol: symbol,
            proposal: bestProposal,
            votes: votes,
            news: news,
            timestamp: timestamp
        )
        
        print("   📊 Sonuç: \(decision.summary)")
        
        return decision
    }
    
    // MARK: - Proposal Collection
    
    private func collectProposals(news: HermesNewsSnapshot, symbol: String) async -> [HermesNewsProposal] {
        var proposals: [HermesNewsProposal] = []
        
        for member in members {
            if let proposal = await member.analyze(news: news, symbol: symbol) {
                proposals.append(proposal)
            }
        }
        
        return proposals
    }
    
    // MARK: - Voting
    
    private func conductVoting(proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> [HermesNewsVote] {
        var votes: [HermesNewsVote] = []
        let weights = HermesMemberWeights.defaultWeights
        
        for member in members {
            if member.id == proposal.proposer { continue }
            
            var vote = member.vote(on: proposal, news: news)
            let memberWeight = weights.weight(for: member.id)
            vote = HermesNewsVote(
                voter: vote.voter,
                voterName: vote.voterName,
                decision: vote.decision,
                reasoning: vote.reasoning,
                weight: memberWeight * vote.weight
            )
            
            votes.append(vote)
            print("      \(vote.decision.emoji) \(vote.voterName): \(vote.decision.rawValue) - \(vote.reasoning ?? "")")
        }
        
        return votes
    }
    
    // MARK: - Decision
    
    private func calculateDecision(
        symbol: String,
        proposal: HermesNewsProposal,
        votes: [HermesNewsVote],
        news: HermesNewsSnapshot,
        timestamp: Date
    ) -> HermesDecision {
        
        var approveWeight = 0.0
        var vetoWeight = 0.0
        
        for vote in votes {
            switch vote.decision {
            case .approve:
                approveWeight += vote.weight
            case .veto:
                vetoWeight += vote.weight
            case .abstain:
                break
            }
        }
        
        approveWeight += proposal.confidence * 0.5
        let netSupport = approveWeight - vetoWeight
        
        let finalSentiment: NewsSentiment
        if netSupport >= 0.10 {
            finalSentiment = proposal.sentiment
        } else if vetoWeight > 0.30 {
            finalSentiment = .neutral
        } else {
            finalSentiment = .neutral
        }
        
        // Key headlines
        let keyHeadlines = news.articles
            .prefix(3)
            .map { $0.headline }
        
        // Catalysts
        var catalysts: [String] = []
        if news.hasUpgrade { catalysts.append("Analist Yükseltme") }
        if news.hasDowngrade { catalysts.append("Analist Düşürme") }
        if news.hasDividendAnnouncement { catalysts.append("Temettü") }
        if news.hasMergersAcquisitions { catalysts.append("M&A") }
        if news.hasEarnings { catalysts.append("Kazanç Raporu") }
        
        let isHighImpact = news.insights.contains { $0.impactScore > 70 } || !catalysts.isEmpty
        
        return HermesDecision(
            symbol: symbol,
            sentiment: finalSentiment,
            actionBias: proposal.actionBias,
            netSupport: netSupport,
            isHighImpact: isHighImpact,
            winningProposal: proposal,
            votes: votes,
            keyHeadlines: Array(keyHeadlines),
            catalysts: catalysts,
            timestamp: timestamp
        )
    }
}
