import SwiftUI

// MARK: - THE GRAND COUNCIL CHAMBER
struct ArgusGrandCouncilCard: View {
    let symbol: String
    let decision: ArgusGrandDecision
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Verdict Banner
            HStack {
                // Icon
                Image(systemName: iconForAction(decision.action))
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, value: isPulsing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("KONSEY KARARI")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)
                    
                    Text(decision.action.rawValue)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                // Confidence Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: decision.confidence)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(decision.confidence * 100))%")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                }
            }
            .padding(20)
            .background(colorForAction(decision.action))
            
            // 2. Reasoning Strip
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundColor(colorForAction(decision.action))
                
                Text(decision.reasoning)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                    .italic()
                    .lineLimit(3)
                
                Spacer()
            }
            .padding(16)
            .background(Theme.cardBackground)
            
            // 3. Council Chamber (The 4 Members)
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                MemberSlot(
                    name: "ORION",
                    role: "Teknik",
                    status: decision.orionDecision.action.rawValue,
                    color: colorForOrion(decision.orionDecision.action),
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                Divider()
                
                MemberSlot(
                    name: "ATLAS",
                    role: "Temel",
                    status: decision.atlasDecision?.action.rawValue ?? "Veri Yok",
                    color: colorForAtlas(decision.atlasDecision?.action),
                    icon: "building.columns.fill"
                )
                
                Divider()
                
                MemberSlot(
                    name: "AETHER",
                    role: "Makro",
                    status: decision.aetherDecision.marketMode.rawValue,
                    color: colorForAether(decision.aetherDecision.marketMode),
                    icon: "globe.europe.africa.fill"
                )
                
                Divider()
                
                MemberSlot(
                    name: "HERMES",
                    role: "Haber",
                    status: decision.hermesDecision?.sentiment.rawValue ?? "Sessiz",
                    color: colorForHermes(decision.hermesDecision?.sentiment.rawValue),
                    icon: "newspaper.fill"
                )
            }
            .background(Theme.secondaryBackground)
        }
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isPulsing ? colorForAction(decision.action).opacity(0.6) : Color.clear, lineWidth: 4)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .opacity(isPulsing ? 0 : 1)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            if decision.action == .aggressiveBuy || decision.action == .liquidate {
                isPulsing = true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func iconForAction(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "bolt.fill"
        case .accumulate: return "layer.3.all" // Stack icon
        case .neutral: return "eye.fill"
        case .trim: return "scissors"
        case .liquidate: return "exclamationmark.shield.fill"
        }
    }
    
    func colorForAction(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return Theme.positive // Bright Green
        case .accumulate: return Color.blue // Systematic Blue
        case .neutral: return Color.gray
        case .trim: return Color.orange
        case .liquidate: return Theme.negative // Red
        }
    }
    
    func colorForOrion(_ action: ProposedAction) -> Color {
        switch action {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .hold: return .gray
        }
    }
    
    func colorForAtlas(_ action: ProposedAction?) -> Color {
        guard let action = action else { return .gray }
        return colorForOrion(action)
    }
    
    func colorForAether(_ mode: MarketMode) -> Color {
        switch mode {
        case .panic, .fear, .extremeFear: return Theme.negative
        case .neutral, .complacency: return .gray
        case .greed, .extremeGreed: return Theme.positive
        }
    }
    
    func colorForHermes(_ sentiment: String?) -> Color {
        guard let s = sentiment else { return .gray }
        let lower = s.lowercased()
        if lower.contains("positive") || lower.contains("bullish") { return Theme.positive }
        if lower.contains("negative") || lower.contains("bearish") { return Theme.negative }
        return .gray
    }
}

// MARK: - Member Slot (Mini Card)
struct MemberSlot: View {
    let name: String
    let role: String
    let status: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Chiron Learning Strip
struct ChironLearningStrip: View {
    let decision: ArgusGrandDecision
    
    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
            
            Text("Chiron Ağırlıkları:")
                .font(.caption)
                .bold()
                .foregroundColor(.purple)
            
            Spacer()
            
            // Simplified visualization of dynamic weights
            // For V3, we don't need exact percentages, just "Who ruled?"
            if decision.strength == .vetoed {
                Text("Vetolar Devrede")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Dominant: Orion") // Placeholder logic
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
