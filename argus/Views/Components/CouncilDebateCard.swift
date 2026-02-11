import SwiftUI

// MARK: - Council Debate Card
/// Displays the internal council voting process and reasoning for educational purposes
struct CouncilDebateCard: View {
    let title: String
    let icon: String
    let accentColor: Color
    
    let winningProposal: (name: String, action: String, reasoning: String)?
    let votes: [(name: String, decision: VoteDecision, reasoning: String?, weight: Double)]
    let finalDecision: String
    let netSupport: Double
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Net support badge
                Text("\(netSupport > 0 ? "+" : "")\(Int(netSupport * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(netSupport > 0 ? .green : (netSupport < 0 ? .red : .yellow))
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // Proposal summary (always visible)
            if let proposal = winningProposal {
                HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                    
                    Text(proposal.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)
                    
                    Text("→")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(proposal.action)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(actionColor(for: proposal.action))
                }
                
                Text(proposal.reasoning)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .italic()
                    .lineLimit(2)
            }
            
            // Expanded: Show all votes
            if isExpanded {
                Divider().background(Theme.border)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text("OYLAR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                    }
                    
                    ForEach(Array(votes.enumerated()), id: \.offset) { _, vote in
                        DebateVoteRow(
                            name: vote.name,
                            decision: vote.decision,
                            reasoning: vote.reasoning,
                            weight: vote.weight
                        )
                    }
                }
                
                Divider().background(Theme.border)
                
                // Summary
                HStack {
                    let approveCount = votes.filter { $0.decision == .approve }.count
                    let vetoCount = votes.filter { $0.decision == .veto }.count
                    
                    Text("\(approveCount) Onay, \(vetoCount) Veto")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("→ \(finalDecision)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(actionColor(for: finalDecision))
                }
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func actionColor(for action: String) -> Color {
        let lowercased = action.lowercased()
        if lowercased.contains("al") || lowercased.contains("buy") { return .green }
        if lowercased.contains("sat") || lowercased.contains("sell") { return .red }
        return .yellow
    }
}

// MARK: - Debate Vote Row
struct DebateVoteRow: View {
    let name: String
    let decision: VoteDecision
    let reasoning: String?
    let weight: Double
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(decision.emoji)
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(decision.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(decisionColor)
                    
                    if weight > 0.8 {
                        Text("⚡")
                            .font(.system(size: 8))
                    }
                }
                
                if let reason = reasoning, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
    }
    
    private var decisionColor: Color {
        switch decision {
        case .approve: return .green
        case .veto: return .red
        case .abstain: return .gray
        }
    }
}

// MARK: - Atlas Debate Card Helper
struct AtlasDebateCard: View {
    let decision: AtlasDecision
    
    var body: some View {
        let proposal: (name: String, action: String, reasoning: String)? = {
            guard let p = decision.winningProposal else { return nil }
            return (p.proposerName, p.action.rawValue, p.reasoning)
        }()
        
        let votes: [(name: String, decision: VoteDecision, reasoning: String?, weight: Double)] = decision.votes.map {
            ($0.voterName, $0.decision, $0.reasoning, $0.weight)
        }
        
        CouncilDebateCard(
            title: "Atlas Konseyi",
            icon: "building.columns",
            accentColor: .blue,
            winningProposal: proposal,
            votes: votes,
            finalDecision: decision.action.rawValue,
            netSupport: decision.netSupport
        )
    }
}

// MARK: - Orion Debate Card Helper
struct OrionDebateCard: View {
    let decision: CouncilDecision
    
    var body: some View {
        let proposal: (name: String, action: String, reasoning: String)? = {
            guard let p = decision.winningProposal else { return nil }
            return (p.proposerName, p.action.rawValue, p.reasoning)
        }()
        
        let votes: [(name: String, decision: VoteDecision, reasoning: String?, weight: Double)] = decision.votes.map {
            ($0.voterName, $0.decision, $0.reasoning, $0.weight)
        }
        
        CouncilDebateCard(
            title: "Orion Konseyi",
            icon: "sparkles",
            accentColor: .purple,
            winningProposal: proposal,
            votes: votes,
            finalDecision: decision.action.rawValue,
            netSupport: decision.netSupport
        )
    }
}
