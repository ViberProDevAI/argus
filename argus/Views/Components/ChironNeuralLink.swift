import SwiftUI

struct ChironNeuralLink: View {
    @ObservedObject var engine = ChironRegimeEngine.shared
    @Binding var showEducation: Bool
    
    // Animation State
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: { 
            HapticManager.shared.impact(style: .light)
            showEducation = true 
        }) {
            ZStack {
                // Background: Deep Tech
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "0F172A"),
                                Color(hex: "1E293B")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        regimeColor.opacity(0.1),
                                        regimeColor.opacity(0.3),
                                        regimeColor.opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Content
                HStack(spacing: 12) {
                    // Left: Pulse Indicator
                    ZStack {
                        Circle()
                            .fill(regimeColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .scaleEffect(isPulsing ? 1.2 : 1.0)
                            .opacity(isPulsing ? 0.0 : 1.0)
                            .animation(Animation.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isPulsing)
                        
                        Circle()
                            .fill(regimeColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: regimeColor.opacity(0.8), radius: 4)
                        
                        // Connector Lines (Matrix Style)
                        if isPulsing {
                            ForEach(0..<2) { i in
                                Circle()
                                    .stroke(regimeColor.opacity(0.2), lineWidth: 1)
                                    .frame(width: CGFloat(12 + i * 8), height: CGFloat(12 + i * 8))
                            }
                        }
                    }
                    .padding(.leading, 12)
                    
                    // Middle: Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHIRON NEURAL LINK")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                            .tracking(1)
                        
                        HStack(spacing: 6) {
                            Text(engine.globalResult.regime.descriptor.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .default))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("•")
                                .foregroundColor(Theme.textSecondary)
                            
                            Text(activeEngineName)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(regimeColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(regimeColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    // Right: Action Icon
                    Image(systemName: "cpu")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            isPulsing = true
        }
    }
    
    // Helpers
    private var regimeColor: Color {
        switch engine.globalResult.regime {
        case .trend: return .green
        case .riskOff: return .red
        case .chop: return .orange
        case .newsShock: return .purple
        case .neutral: return .blue
        }
    }
    
    private var activeEngineName: String {
        switch engine.globalResult.regime {
        case .trend: return "ORION ENGINE"
        case .riskOff: return "ATLAS SHIELD" // Defensive
        case .chop: return "CORSE SWING" // Ranging
        case .newsShock: return "HERMES FEED"
        case .neutral: return "STANDBY"
        }
    }
}
