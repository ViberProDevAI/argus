import SwiftUI

// MARK: - Observatory Learning View
/// Displays a list of Chiron learning events (weight updates)
// MARK: - Observatory Learning View
/// Displays a list of Chiron learning events (weight updates)
struct ObservatoryLearningView: View {
    @State private var events: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header stats or filter could go here
            
            if isLoading {
                Spacer()
                ProgressView().tint(SanctumTheme.hologramBlue)
                Spacer()
            } else if events.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(SanctumTheme.ghostGrey.opacity(0.3))
                    Text("NO LEARNING DATA DETECTED")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(SanctumTheme.ghostGrey)
                    Text("AWAITING CHIRON SYNAPSES...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SanctumTheme.ghostGrey.opacity(0.6))
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(events) { event in
                            HoloLearningCardView(event: event)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadEvents()
        }
    }
    
    private func loadEvents() {
        isLoading = true
        Task {
            let loaded = ArgusLedger.shared.loadLearningEvents(limit: 50)
            await MainActor.run {
                self.events = loaded
                self.isLoading = false
            }
        }
    }
}

// MARK: - Holo Learning Card
struct HoloLearningCardView: View {
    let event: LearningEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Timestamp + Regime
            HStack {
                Text(formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(SanctumTheme.ghostGrey)
                
                Spacer()
                
                if let regime = event.regime {
                    Text(regime.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(regimeColor(regime).opacity(0.2))
                        .foregroundColor(regimeColor(regime))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(regimeColor(regime).opacity(0.5), lineWidth: 1)
                        )
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Weight Deltas (Synaptic Updates)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(event.weightDeltas.sorted(by: { abs($0.value) > abs($1.value) }), id: \.key) { module, delta in
                    HStack {
                        // Module Name
                        HStack(spacing: 4) {
                            Text(moduleIcon(module))
                                .font(.caption)
                            Text(module.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Old -> New
                        HStack(spacing: 4) {
                            let oldW = event.oldWeights[module] ?? 0
                            let newW = event.newWeights[module] ?? 0
                            
                            Text(String(format: "%.2f", oldW))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(SanctumTheme.ghostGrey)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(SanctumTheme.ghostGrey)
                            
                            Text(String(format: "%.2f", newW))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // Delta Badge
                        Text(String(format: "%+.2f", delta))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(delta >= 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(delta >= 0 ? SanctumTheme.auroraGreen.opacity(0.1) : SanctumTheme.crimsonRed.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Reason
            if !event.reason.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundStyle(SanctumTheme.titanGold)
                    
                    Text(event.reason)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SanctumTheme.titanGold)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SanctumTheme.titanGold.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Footer Metadata
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(event.windowDays)D WINDOW")
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text("\(event.sampleSize) SAMPLES")
                }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(SanctumTheme.ghostGrey.opacity(0.5))
            .padding(.top, 4)
        }
        .padding(16)
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [SanctumTheme.hologramBlue.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: event.timestamp)
    }
    
    private func regimeColor(_ regime: String) -> Color {
        switch regime.lowercased() {
        case "trend": return .green
        case "chop": return .orange
        case "riskoff", "risk-off": return .red
        case "neutral": return .gray
        default: return .blue
        }
    }
    
    private func moduleIcon(_ module: String) -> String {
        switch module.lowercased() {
        case "orion": return "🏹"
        case "atlas": return "🏛️"
        case "aether": return "🌌"
        case "hermes": return "⚡"
        case "alkindus": return "🧠"
        case "athena": return "🦉"
        case "demeter": return "🌿"
        case "phoenix": return "🔥"
        default: return "⚪"
        }
    }
}

// MARK: - Preview
#Preview {
    ObservatoryLearningView()
}
