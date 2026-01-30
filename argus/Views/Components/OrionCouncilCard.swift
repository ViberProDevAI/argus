import SwiftUI

// MARK: - Orion Council Card (Premium Version)
/// Shows the council members' votes and decision with premium styling
struct OrionCouncilCard: View {
    let symbol: String
    let candles: [Candle]
    
    @State private var councilDecision: CouncilDecision?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with gradient
            headerSection
            
            // Content
            if isLoading {
                loadingSection
            } else if let decision = councilDecision {
                decisionSection(decision: decision)
            } else {
                errorSection
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
        .task {
            await loadCouncilDecision()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ORİON KONSEYİ")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Teknik Karar Kurulu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isLoading, let decision = councilDecision {
                PremiumDecisionBadge(decision: decision)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Loading
    
    private var loadingSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.purple, lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                }
                
                Text("Konsey toplanıyor...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
    }
    
    // MARK: - Decision Content
    
    private func decisionSection(decision: CouncilDecision) -> some View {
        VStack(spacing: 16) {
            // Winning Proposal Card
            if let proposal = decision.winningProposal {
                proposalCard(proposal: proposal)
            }
            
            // Net Support Gauge
            netSupportGauge(decision: decision)
            
            // Members Grid
            membersGrid(decision: decision)
            
            // Veto Warnings
            if !decision.vetoReasons.isEmpty {
                vetoWarnings(reasons: decision.vetoReasons)
            }
            
            // Expand Button
            expandButton
            
            // Expanded Content: Chiron Weights & Learning Info
            if isExpanded {
                chironWeightsSection
            }
        }
        .padding()
    }
    
    // MARK: - Chiron Weights Section (NEW!)
    
    @ViewBuilder
    private var chironWeightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Chiron Öğrenme Ağırlıkları")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Weight bars for each member
            let weights = ChironWeightStore.shared.getWeights(symbol: symbol, engine: .pulse)
            
            VStack(spacing: 8) {
                ChironWeightBar(name: "Orion (Teknik)", weight: weights.orion, color: .purple)
                ChironWeightBar(name: "Atlas (Temel)", weight: weights.atlas, color: .blue)
                ChironWeightBar(name: "Phoenix (Senaryo)", weight: weights.phoenix, color: .orange)
                ChironWeightBar(name: "Aether (Makro)", weight: weights.aether, color: .cyan)
                ChironWeightBar(name: "Hermes (Haber)", weight: weights.hermes, color: .green)
            }
            
            // Learning status
            if weights.confidence > 0 {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Öğrenme Güveni: \(Int(weights.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !weights.reasoning.isEmpty {
                        Text(weights.reasoning)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
            
            // Trade count info
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Bu hisse için öğrenme verisine Chiron Detay'dan ulaşabilirsin.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Proposal Card
    
    private func proposalCard(proposal: CouncilProposal) -> some View {
        HStack(spacing: 12) {
            // Star icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Öneri:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(proposal.proposerName)
                        .font(.caption)
                        .bold()
                }
                
                if let reasoning = proposal.reasoning.isEmpty ? nil : proposal.reasoning {
                    Text(reasoning)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action + Confidence
            VStack(alignment: .trailing, spacing: 2) {
                Text(proposal.action.rawValue)
                    .font(.caption)
                    .bold()
                    .foregroundColor(proposal.action == .buy ? .green : (proposal.action == .sell ? .red : .gray))
                
                Text("\(Int(proposal.confidence * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Net Support Gauge
    
    private func netSupportGauge(decision: CouncilDecision) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Net Destek")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(decision.signalStrength)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(signalColor(decision).opacity(0.2))
                            .foregroundColor(signalColor(decision))
                            .cornerRadius(4)
                        
                        if decision.isStrongSignal {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Spacer()
                
                // Percentage
                Text("\(decision.netSupport >= 0 ? "+" : "")\(Int(decision.netSupport * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(decision.netSupport > 0 ? .green : (decision.netSupport < 0 ? .red : .gray))
            }
            
            // Gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    
                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    
                    // Value bar
                    let normalizedValue = (decision.netSupport + 1) / 2 // -1 to 1 -> 0 to 1
                    let barWidth = geo.size.width * CGFloat(min(1, max(0, normalizedValue)))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: decision.netSupport > 0 ? [.green.opacity(0.8), .green] : [.red, .red.opacity(0.8)],
                                startPoint: decision.netSupport > 0 ? .leading : .trailing,
                                endPoint: decision.netSupport > 0 ? .trailing : .leading
                            )
                        )
                        .frame(width: barWidth)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Members Grid
    
    private func membersGrid(decision: CouncilDecision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Üye Oyları")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(decision.votes, id: \.voter) { vote in
                    PremiumVoteBadge(vote: vote)
                }
            }
        }
    }
    
    // MARK: - Veto Warnings
    
    private func vetoWarnings(reasons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Vetolar")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.orange)
            }
            
            ForEach(reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Expand Button
    
    private var expandButton: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                Spacer()
                Text(isExpanded ? "Daralt" : "Detaylar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    // MARK: - Error
    
    private var errorSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("Konsey kararı alınamadı")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func signalColor(_ decision: CouncilDecision) -> Color {
        if decision.isStrongSignal { return .green }
        if decision.isWeakSignal { return .yellow }
        return .gray
    }
    
    private func loadCouncilDecision() async {
        isLoading = true
        councilDecision = await OrionCouncil.shared.convene(
            symbol: symbol,
            candles: candles,
            engine: .pulse
        )
        isLoading = false
    }
}

// MARK: - Premium Decision Badge
struct PremiumDecisionBadge: View {
    let decision: CouncilDecision
    
    var backgroundColor: Color {
        switch decision.action {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(decision.action.emoji)
                .font(.system(size: 14))
            Text(decision.action.rawValue)
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(backgroundColor.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(backgroundColor.opacity(0.5), lineWidth: 1)
                )
        )
        .foregroundColor(backgroundColor)
    }
}

// MARK: - Premium Vote Badge
struct PremiumVoteBadge: View {
    let vote: CouncilVote
    
    var backgroundColor: Color {
        switch vote.decision {
        case .approve: return .green
        case .veto: return .red
        case .abstain: return .gray
        }
    }
    
    var iconName: String {
        switch vote.decision {
        case .approve: return "checkmark.circle.fill"
        case .veto: return "xmark.circle.fill"
        case .abstain: return "minus.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(backgroundColor)
            
            // Name & Reason
            VStack(alignment: .leading, spacing: 2) {
                Text(vote.voterName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                
                if let reason = vote.reasoning {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Weight
            Text("\(Int(vote.weight * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(backgroundColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Chiron Weight Bar
struct ChironWeightBar: View {
    let name: String
    let weight: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(weight))
                }
            }
            .frame(height: 8)
            
            Text("\(Int(weight * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(color)
                .frame(width: 35, alignment: .trailing)
        }
    }
}
