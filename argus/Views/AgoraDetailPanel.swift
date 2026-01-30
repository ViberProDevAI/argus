import SwiftUI

struct AgoraDetailPanel: View {
    let symbol: String
    let snapshot: DecisionSnapshot?
    var trace: AgoraTrace? // NEW: Agora V2 Trace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            Divider()
            
            if let t = trace {
                // AGORA V2 VIEW
                agoraDecisionView(t)
                Divider()
                agoraRiskView(t)
                Divider()
                agoraDebateView(t)
            } else if let s = snapshot {
                // LEGACY VIEW
                actionHeroView(s: s)
                moduleGrid(s: s)
                evidenceList(s: s)
                lockStatus(s: s)
            } else {
                emptyState
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    private var borderColor: Color {
        if let t = trace {
            return t.riskEvaluation.isApproved ? Theme.border.opacity(0.3) : Theme.negative.opacity(0.5)
        }
        return snapshot?.locks.isLocked == true ? Color.orange.opacity(0.3) : Theme.border.opacity(0.3)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(Theme.tint)
            Text("Argus Karar Protokolü (Agora)")
                .font(.caption)
                .bold()
                .foregroundColor(Theme.tint)
            Spacer()
            // Trace freshness or Legacy coverage
            if let t = trace {
                Text(t.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else if let s = snapshot {
                 Text("%\(Int(s.dataCoverage)) Veri")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // --- AGORA V2 SUBVIEWS ---
    
    private func agoraDecisionView(_ t: AgoraTrace) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t.finalDecision.action.rawValue.uppercased())
                    .font(.title2)
                    .bold()
                    .foregroundColor(actionColor(t.finalDecision.action))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(actionColor(t.finalDecision.action).opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
                
                // Data Health & Source Badges
                HStack(spacing: 4) {
                    if !t.dataHealth.isAcceptable {
                        Text("DataHealthGate=BLOCK")
                            .font(.system(size: 8)) // Tiny
                            .bold()
                            .padding(4)
                            .background(Theme.negative.opacity(0.2))
                            .foregroundColor(Theme.negative)
                            .cornerRadius(4)
                    }
                    
                    if let src = t.dataSourceUsage["Price"] {
                        Text(src)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Text(t.finalDecision.rationale)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(nil)
                .padding(12)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)
            
            // --- NEW: Execution Plan & Phoenix ---
            if let plan = t.finalDecision.executionPlan {
                Divider().padding(.vertical, 4)
                
                HStack(alignment: .top, spacing: 16) {
                    // 1. Sizing
                    VStack(alignment: .leading) {
                        Text("BÜYÜKLÜK")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.2f", plan.targetSizeR))R")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    // 2. Risk Levels
                    VStack(alignment: .leading) {
                        Text("RİSK PLANI")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.gray)
                        if let sl = plan.riskPlan.stopLoss {
                            Text("SL: \(String(format: "%.2f", sl))")
                                .font(.caption2)
                                .foregroundColor(Theme.negative)
                        } else {
                            Text("SL: Dinamik")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // 3. Phoenix Guidance
                    if let ph = plan.entryGuidance {
                        VStack(alignment: .trailing) {
                            Text("PHOENIX")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.purple)
                            Text(ph.priceBand)
                                .font(.caption2)
                                .foregroundColor(.white)
                            Text(ph.recommendedEntry)
                                .font(.caption2)
                                .italic()
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Unused Factors (Heimdall Debug)
            if !t.unusedFactors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Divider().padding(.vertical, 4)
                    Text("KULLANILMAYAN FAKTÖRLER")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.gray)
                    
                    ForEach(t.unusedFactors, id: \.self) { factor in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(factor)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func agoraRiskView(_ t: AgoraTrace) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(t.riskEvaluation.isApproved ? Theme.positive : Theme.negative)
                Text("Risk Bütçesi (R-Model)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                Spacer()
                Text(t.riskEvaluation.isApproved ? "ONAYLANDI" : "REDDEDİLDİ")
                    .font(.caption)
                    .bold()
                    .foregroundColor(t.riskEvaluation.isApproved ? Theme.positive : Theme.negative)
            }
            
            // Risk Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(t.riskEvaluation.isApproved ? Theme.positive : Theme.negative)
                        .frame(width: min(geo.size.width, geo.size.width * (t.riskEvaluation.riskBudgetR / t.riskEvaluation.maxR)))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
            
            Text(t.riskEvaluation.reason)
                .font(.caption2)
                .foregroundColor(.gray)
                .italic()
        }
    }
    
    private func agoraDebateView(_ t: AgoraTrace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Münazara Detayı")
                .font(.caption)
                .bold()
                .foregroundColor(.gray)
            
            // 1. Claimant (if exists)
            if let claimant = t.debate.claimant {
                stanceRow(op: claimant, icon: "mic.fill")
            } else {
                Text("Başlatıcı Yok (Veri Yetersiz)")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.gray)
            }
            
            // 2. Others (Supporters, Objectors, Abstainers)
            let others = t.debate.opinions.filter { $0.module != t.debate.claimant?.module }
            
            if !others.isEmpty {
                Divider().opacity(0.5)
                ForEach(others) { op in
                    stanceRow(op: op, icon: stanceIcon(op.stance))
                }
            }
        }
    }
    
    private func stanceRow(op: ModuleOpinion, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(stanceColor(op.stance))
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(op.module.rawValue)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text(localizedStance(op.stance))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(stanceColor(op.stance).opacity(0.2))
                        .foregroundColor(stanceColor(op.stance))
                        .cornerRadius(4)
                }
                
                if let ev = op.evidence.first {
                    Text(ev)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private func stanceColor(_ s: AgoraStance) -> Color {
        switch s {
        case .claim: return .blue
        case .support: return .green // Green
        case .object: return .orange // Objection
        case .abstain: return .gray.opacity(0.5)
        }
    }
    
    private func stanceIcon(_ s: AgoraStance) -> String {
        switch s {
        case .claim: return "mic.fill"
        case .support: return "hand.thumbsup.fill"
        case .object: return "hand.raised.fill" // Stop/Raise hand
        case .abstain: return "eye.slash.fill"
        }
    }
    
    // --- LEGACY SUBVIEWS (Renamed/Private) ---

    private func actionHeroView(s: DecisionSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(displayAction(s.action))
                .font(.system(size: 16, weight: .heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(actionColor(s.action).opacity(DesignTokens.Opacity.glassCard))
                .foregroundColor(actionColor(s.action))
                .cornerRadius(8)
            
            Text(s.reasonOneLiner)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func localizedStance(_ s: AgoraStance) -> String {
        switch s {
        case .claim: return "İDDİA"
        case .support: return "DESTEK"
        case .object: return "İTİRAZ"
        case .abstain: return "ÇEKİMSER"
        }
    }
    
    @ViewBuilder
    private func moduleGrid(s: DecisionSnapshot) -> some View {
        if !s.moduleStatuses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("SİSTEM DURUMU")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(s.moduleStatuses) { mod in
                        HStack {
                            Circle()
                                .fill(statusColor(mod.status))
                                .frame(width: 6, height: 6)
                            Text(mod.name)
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            if let score = mod.score, score > 0 {
                                Text("\(Int(score))")
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func evidenceList(s: DecisionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KARAR MANTIĞI")
                .font(.caption2)
                .bold()
                .foregroundColor(.gray)
            
            ForEach(s.evidence, id: \.claim) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundColor(directionColor(item.direction))
                        .padding(.top, 4)
                    
                    Text(item.claim)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    @ViewBuilder
    private func lockStatus(s: DecisionSnapshot) -> some View {
        if s.locks.isLocked {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("KORUMA KALKANI AKTİF")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    if let until = s.locks.cooldownUntil {
                        Text("Bitiş: \(until.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var emptyState: some View {
        Text("Henüz bir karar kaydı yok.")
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 8)
    }
    

    func statusColor(_ status: String) -> Color {
        switch status {
        case "OK": return Theme.positive
        case "NO_DATA": return .gray
        case "DISABLED": return .gray.opacity(0.5)
        case "ERROR": return Theme.negative
        default: return .gray
        }
    }
    
    // Helpers
    func displayAction(_ action: SignalAction) -> String {
        switch action {
        case .buy: return "AL"
        case .sell: return "SAT"
        case .hold: return "TUT"
        case .wait: return "BEKLE"
        case .skip: return "PAS"
        }
    }
    
    func actionColor(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .wait, .skip: return .orange
        case .hold: return .blue
        }
    }
    
    func directionColor(_ dir: String) -> Color {
        switch dir {
        case "POSITIVE": return Theme.positive
        case "NEGATIVE": return Theme.negative
        default: return .gray
        }
    }
}

// MARK: - Local Helpers

struct ModuleStatus: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let score: Double?
}

extension DecisionSnapshot {
    var dataCoverage: Double {
        // Placeholder or derived from evidence count?
        return 100.0
    }
    
    var moduleStatuses: [ModuleStatus] {
        guard let std = standardizedOutputs else { return [] }
        return std.map { key, value in
            ModuleStatus(name: key, status: "OK", score: value.strength)
        }.sorted { $0.name < $1.name }
    }
}
