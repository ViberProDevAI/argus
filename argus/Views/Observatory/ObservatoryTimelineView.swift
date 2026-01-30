import SwiftUI

// MARK: - Observatory Timeline View
/// Displays a list of Argus decisions as "story cards"
// MARK: - Observatory Timeline View
/// Displays a list of Argus decisions as "story cards"
struct ObservatoryTimelineView: View {
    @State private var decisions: [DecisionCard] = []
    @State private var isLoading = true
    @State private var selectedFilter: TimelineFilter = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker (Neon Style)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TimelineFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.displayName)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedFilter == filter ? 
                                    SanctumTheme.hologramBlue.opacity(0.2) : 
                                    Color.white.opacity(0.05)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedFilter == filter ? 
                                            SanctumTheme.hologramBlue : 
                                            Color.white.opacity(0.1), 
                                            lineWidth: 1
                                        )
                                )
                                .cornerRadius(8)
                                .foregroundColor(
                                    selectedFilter == filter ? 
                                    SanctumTheme.hologramBlue : 
                                    SanctumTheme.ghostGrey
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.black.opacity(0.2))
            
            // Timeline List
            if isLoading {
                Spacer()
                ProgressView().tint(SanctumTheme.hologramBlue)
                Spacer()
            } else if decisions.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 60))
                        .foregroundStyle(SanctumTheme.ghostGrey.opacity(0.3))
                    Text("NO DATA DETECTED")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(SanctumTheme.ghostGrey)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredDecisions) { decision in
                            HoloDecisionCardView(decision: decision)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadDecisions()
        }
    }
    
    private var filteredDecisions: [DecisionCard] {
        switch selectedFilter {
        case .all: return decisions
        case .pending: return decisions.filter { $0.outcome == .pending }
        case .matured: return decisions.filter { $0.outcome == .matured }
        case .bist: return decisions.filter { $0.market == "BIST" }
        case .global: return decisions.filter { $0.market == "US" }
        }
    }
    
    private func loadDecisions() {
        isLoading = true
        Task {
            let events = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            await MainActor.run {
                self.decisions = events
                self.isLoading = false
            }
        }
    }
}

// MARK: - Holo Decision Card
struct HoloDecisionCardView: View {
    let decision: DecisionCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Symbol + Date
            HStack {
                Text(decision.symbol)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                
                Text(decision.market)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SanctumTheme.ghostGrey)
                
                Spacer()
                
                Text(decision.formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(SanctumTheme.ghostGrey)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Action Section
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: decision.actionIcon)
                        .font(.system(size: 16))
                    Text(decision.action)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(decision.actionColor)
                
                Spacer()
                
                // Confidence Badge
                HStack(spacing: 2) {
                    Text("CONF:")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(SanctumTheme.ghostGrey)
                    Text("\(Int(decision.confidence * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            
            // Factors Grid
            HStack(spacing: 8) {
                ForEach(decision.topFactors.prefix(3), id: \.name) { factor in
                    HStack(spacing: 3) {
                        Text(factor.name.prefix(3).uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(SanctumTheme.ghostGrey)
                        Text("\(Int(factor.value))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(factor.value >= 50 ? .green : .red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
            }
            
            // Footer: Outcome Status
            if decision.outcome != .pending {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    Image(systemName: decision.outcome == .matured ? "checkmark.circle.fill" : "clock")
                        .font(.system(size: 10))
                        .foregroundColor(decision.outcomeColor)
                    Text(decision.outcome.displayName.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(decision.outcomeColor)
                    
                    Spacer()
                    
                    if let pnl = decision.actualPnl {
                        Text(String(format: "%+.2f%%", pnl))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(pnl >= 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                    }
                }
            }
        }
        .padding(16)
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [decision.actionColor.opacity(0.5), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Supporting Models

// MARK: - View Extension for DecisionCard (UI Logic)
extension DecisionCard {
    var actionIcon: String {
        switch action {
        case "HÜCUM", "BİRİKTİR": return "arrow.up.circle.fill"
        case "AZALT", "ÇIK": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }
    
    var actionColor: Color {
        switch action {
        case "HÜCUM": return .green
        case "BİRİKTİR": return .blue
        case "AZALT": return .orange
        case "ÇIK": return .red
        default: return .gray
        }
    }
    
    var outcomeColor: Color {
        switch outcome {
        case .pending: return .yellow
        case .matured: return .green
        case .stale: return .gray
        }
    }
}


enum TimelineFilter: String, CaseIterable {
    case all = "all"
    case pending = "pending"
    case matured = "matured"
    case bist = "bist"
    case global = "global"
    
    var displayName: String {
        switch self {
        case .all: return "Tümü"
        case .pending: return "Bekleyen"
        case .matured: return "Tamamlanan"
        case .bist: return "BIST"
        case .global: return "Global"
        }
    }
}

// MARK: - Preview
#Preview {
    ObservatoryTimelineView()
}
