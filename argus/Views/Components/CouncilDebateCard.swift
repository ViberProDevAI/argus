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
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                Spacer()
                
                // Net support badge
                Text("\(netSupport > 0 ? "+" : "")\(Int(netSupport * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(netSupport > 0 ? .green : (netSupport < 0 ? .red : .yellow))
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Text(proposal.action)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(actionColor(for: proposal.action))
                }
                
                Text(proposal.reasoning)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .italic()
                    .lineLimit(2)
            }
            
            // Expanded: Show all votes
            if isExpanded {
                Divider().background(InstitutionalTheme.Colors.border)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("OYLAR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
                
                Divider().background(InstitutionalTheme.Colors.border)
                
                // Summary
                HStack {
                    let approveCount = votes.filter { $0.decision == .approve }.count
                    let vetoCount = votes.filter { $0.decision == .veto }.count
                    
                    Text("\(approveCount) Onay, \(vetoCount) Veto")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("→ \(finalDecision)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(actionColor(for: finalDecision))
                }
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
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
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    
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
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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

// MARK: - Grand Council Debate Card
//
// ArgusGrandDecision için karar patikası kartı: kim oy verdi, hangi yönde,
// hangi modül veto etti, kim oy vermedi neden, danışmanlar ne dedi.
//
// 2026-04-25 — Dürüstlük revizyonu:
// 1. SAT oyu artık "VETO" diye gösterilmiyor. Önceki version
//    `.sell → .veto` mapping yapıyordu, ama satış OYU ile sert VETO ayrı şeyler.
//    Sert veto sadece ModuleVeto listesindeki kayıtlar.
// 2. "BEKLEYEN MODÜL" bölümü: Atlas/Hermes oy vermediyse (snapshot yok / haber
//    yok), bunlar ayrı bölümde "veri bekleniyor" notuyla gösterilir.
//    Eskiden contributors listesi sadece oy verenleri içeriyordu — kullanıcı
//    "2 modül oy verdi" görüp "kalan modüller nerede?" diye haklı şikayet ediyordu.
struct GrandCouncilDebateCard: View {
    let decision: ArgusGrandDecision
    @State private var isExpanded: Bool = true

    /// Tüm Council üyeleri — oy verenler + bekleyenler.
    /// Bekleyenler: Atlas (atlasDecision nil), Hermes (hermesDecision nil).
    private var pendingMembers: [(name: String, reason: String)] {
        var pending: [(String, String)] = []
        let voted = Set(decision.contributors.map { $0.module.lowercased() })
        if decision.atlasDecision == nil && !voted.contains("atlas") {
            pending.append(("Atlas", "Bilanço/temel veri yüklenmedi"))
        }
        if decision.hermesDecision == nil && !voted.contains("hermes") {
            pending.append(("Hermes", "Haber verisi yok"))
        }
        return pending
    }

    private var totalExpectedVoters: Int {
        decision.contributors.count + pendingMembers.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.sequence.fill")
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                Text("KARAR PATİKASI")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text(decision.action.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(actionColor(decision.action))
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }

            // Reasoning özet (sayım + ağırlık + eşik dahil)
            Text(decision.reasoning)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                Divider().background(InstitutionalTheme.Colors.border)

                // Oy verenler
                VStack(alignment: .leading, spacing: 8) {
                    Text("OYLAR (\(decision.contributors.count)/\(totalExpectedVoters) modül)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    ForEach(Array(decision.contributors.enumerated()), id: \.offset) { _, contrib in
                        contributorRow(contrib)
                    }
                }

                // Oy vermeyenler (Atlas/Hermes vb. veri yok durumu)
                if !pendingMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BEKLEYEN MODÜL (\(pendingMembers.count))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(InstitutionalTheme.Colors.titan)
                        ForEach(Array(pendingMembers.enumerated()), id: \.offset) { _, p in
                            pendingRow(name: p.name, reason: p.reason)
                        }
                    }
                }

                // Hard veto'lar (gerçek veto — ModuleVeto listesi)
                if !decision.vetoes.isEmpty {
                    Divider().background(InstitutionalTheme.Colors.border)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SERT VETO (\(decision.vetoes.count))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(InstitutionalTheme.Colors.crimson)
                        ForEach(Array(decision.vetoes.enumerated()), id: \.offset) { _, veto in
                            HStack(spacing: 6) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(InstitutionalTheme.Colors.crimson)
                                Text(veto.module)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text("·").foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                Text(veto.reason)
                                    .font(.system(size: 10))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                // Danışman notları
                if !decision.advisors.isEmpty {
                    Divider().background(InstitutionalTheme.Colors.border)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DANIŞMAN NOTLARI (\(decision.advisors.count))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        ForEach(Array(decision.advisors.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: noteIcon(for: note.tone))
                                    .font(.system(size: 9))
                                    .foregroundColor(noteColor(for: note.tone))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.module)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    Text(note.advice)
                                        .font(.system(size: 10))
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.holo.opacity(0.3), lineWidth: 1)
        )
    }

    /// Modül oy satırı — AL/SAT/BEKLE yönünde + güven yüzdesi + 1 satır rationale.
    @ViewBuilder
    private func contributorRow(_ contrib: ModuleContribution) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: voteIcon(for: contrib.action))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(voteColor(for: contrib.action))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(contrib.module)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(voteLabel(for: contrib.action))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(voteColor(for: contrib.action))
                    Spacer()
                    Text("%\(Int(abs(contrib.confidence) * 100))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                if !contrib.reasoning.isEmpty {
                    Text(contrib.reasoning)
                        .font(.system(size: 10))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Bekleyen (oy vermemiş) modül satırı — neden oy vermediğini açıklar.
    @ViewBuilder
    private func pendingRow(name: String, reason: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.titan)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("BEKLENİYOR")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.titan)
                    Spacer()
                }
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func voteIcon(for action: ProposedAction) -> String {
        switch action {
        case .buy:  return "arrow.up.circle.fill"
        case .sell: return "arrow.down.circle.fill"
        case .hold: return "minus.circle.fill"
        }
    }

    private func voteLabel(for action: ProposedAction) -> String {
        switch action {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        }
    }

    private func voteColor(for action: ProposedAction) -> Color {
        switch action {
        case .buy:  return InstitutionalTheme.Colors.aurora
        case .sell: return InstitutionalTheme.Colors.crimson
        case .hold: return InstitutionalTheme.Colors.textSecondary
        }
    }

    private func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy, .accumulate: return InstitutionalTheme.Colors.aurora
        case .trim, .liquidate: return InstitutionalTheme.Colors.crimson
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        }
    }

    private func noteIcon(for tone: AdvisorNote.AdvisorTone) -> String {
        switch tone {
        case .positive: return "checkmark.seal.fill"
        case .caution:  return "exclamationmark.triangle.fill"
        case .warning:  return "xmark.octagon.fill"
        case .neutral:  return "info.circle"
        }
    }

    private func noteColor(for tone: AdvisorNote.AdvisorTone) -> Color {
        switch tone {
        case .positive: return InstitutionalTheme.Colors.aurora
        case .caution:  return InstitutionalTheme.Colors.titan
        case .warning:  return InstitutionalTheme.Colors.crimson
        case .neutral:  return InstitutionalTheme.Colors.textSecondary
        }
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
