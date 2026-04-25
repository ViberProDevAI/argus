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
                    // 2026-04-22 Sprint 4 V5: Pulse indicator yerine
                    // Chiron motor logosu (kentaur okçu). V5 mockup
                    // Neural Link kartı Chiron glow halkası içinde.
                    ZStack {
                        Circle()
                            .fill(regimeColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .scaleEffect(isPulsing ? 1.25 : 1.0)
                            .opacity(isPulsing ? 0.0 : 1.0)
                            .animation(Animation.easeOut(duration: 2.2).repeatForever(autoreverses: false), value: isPulsing)

                        Circle()
                            .fill(regimeColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Circle()
                            .stroke(regimeColor.opacity(0.5), lineWidth: 1)
                            .frame(width: 36, height: 36)

                        MotorLogo(.chiron, size: 22)
                    }
                    .padding(.leading, 12)
                    
                    // Middle: Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHIRON NEURAL LINK")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.7))
                            .tracking(1)
                        
                        HStack(spacing: 6) {
                            Text(engine.globalResult.regime.descriptor.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .default))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            
                            Text("•")
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            
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
                    
                    // V5 sağ ikon — cpu chip, daha küçük + tint
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .padding(.trailing, 14)
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
