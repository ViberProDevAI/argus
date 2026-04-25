import SwiftUI

// MARK: - Athena Card
/// Chimera sinyallerini gösteren öğretici kart.
/// Terminal estetiğine uygun, profesyonel tasarım.

struct AthenaCard: View {
    let signals: [ChimeraSignal]
    
    var body: some View {
        if signals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "owl")
                        .font(.system(size: 16, weight: .semibold))
                    Text("ATHENA")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("Sinyal Analizi")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Signal List
                ForEach(signals) { signal in
                    AthenaSignalRow(signal: signal)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Signal Row

struct AthenaSignalRow: View {
    let signal: ChimeraSignal
    @State private var isExpanded = false
    
    private var signalColor: Color {
        Color(hex: signal.type.severityColor) ?? .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main Row (Tappable)
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Color Indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(signalColor)
                        .frame(width: 4, height: 32)
                    
                    // Signal Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.type.turkishName.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Text(signal.title)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Expand Indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACIKLAMA")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(signal.type.turkishDescription)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Advice
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ONERI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(signal.type.turkishAdvice)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    AthenaCard(signals: [
        ChimeraSignal(
            type: .deepValueBuy,
            title: "AAPL - Temel Guclu",
            description: "Demo",
            severity: 0.8
        ),
        ChimeraSignal(
            type: .bullTrap,
            title: "Dikkat - Hacim Zayif",
            description: "Demo",
            severity: 0.6
        )
    ])
    .padding()
}
