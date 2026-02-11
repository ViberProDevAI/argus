import SwiftUI

// MARK: - Chiron Cockpit Widget
/// Shows recent learning events and Chiron status in Cockpit
struct ChironCockpitWidget: View {
    @State private var recentEvents: [ChironLearningEvent] = []
    @State private var showChironDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.green)
                
                Text("CHİRON ÖĞRENİYOR")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Button(action: { showChironDetail = true }) {
                    HStack(spacing: 4) {
                        Text("Detaylar")
                            .font(.caption2)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(Theme.tint)
                }
            }
            .padding(.horizontal)
            
            // Content
            if recentEvents.isEmpty {
                // Empty State
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sistem Öğrenmeye Hazır")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Trade'ler kapandıkça Chiron öğrenecek ve ağırlıkları optimize edecek.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Animated Brain
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Image(systemName: "brain")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Recent Events
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentEvents.prefix(5)) { event in
                            ChironEventChip(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            recentEvents = await ChironDataLakeService.shared.loadLearningEvents()
        }
        .sheet(isPresented: $showChironDetail) {
            ChironDetailView()
        }
    }
}

// MARK: - Event Chip
struct ChironEventChip: View {
    let event: ChironLearningEvent
    
    var chipColor: Color {
        switch event.eventType {
        case .weightUpdate: return .blue
        case .ruleAdded: return .green
        case .ruleRemoved: return .red
        case .analysisCompleted: return .cyan
        case .anomalyDetected: return .orange
        case .forwardTest: return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol = event.symbol {
                    Text(symbol)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                }
                
                if let engine = event.engine {
                    Text(engine == .corse ? "" : "⚡")
                        .font(.caption)
                }
            }
            
            Text(event.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            Text(event.date, style: .relative)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(width: 160)
        .background(chipColor.opacity(DesignTokens.Opacity.glassCard))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(chipColor.opacity(0.3), lineWidth: 1)
        )
    }
}
