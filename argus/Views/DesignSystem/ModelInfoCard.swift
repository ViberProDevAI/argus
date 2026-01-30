import SwiftUI

struct SystemInfoCard: View {
    let entity: ArgusSystemEntity
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }
            
            // Card Container (No GlassCard, use Direct Background)
            VStack(spacing: 20) {
                // Header
                    HStack {
                        Image(systemName: entity.icon)
                            .font(.title)
                            .foregroundColor(color(for: entity))
                        
                        Text(entity.rawValue.uppercased())
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button { withAnimation { isPresented = false } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Description
                    Text(entity.description)
                        .font(.custom("Menlo", size: 14)) // Monospaced for terminal feel
                        .foregroundColor(SanctumTheme.ghostGrey)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                    
                    // Stats / Traits handled generically or customized logic below
                    HStack(spacing: 16) {
                        trait(icon: "brain.head.profile", label: "AI Modülü")
                        trait(icon: "lock.shield", label: "Aktif")
                    }
                }
                .padding(24)

            .background(SanctumTheme.bg) // Deep Navy Background
            .cornerRadius(12) // FIXED: Geometric Standard 12px
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color(for: entity).opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: 340)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func color(for entity: ArgusSystemEntity) -> Color {
        switch entity {
        case .atlas: return SanctumTheme.atlasColor      // Titan Gold
        case .orion: return SanctumTheme.orionColor      // Hologram Blue
        case .aether: return SanctumTheme.aetherColor    // Ghost Grey
        case .hermes: return SanctumTheme.hermesColor    // Orange
        case .demeter: return SanctumTheme.demeterColor  // Aurora Green
        case .argus, .council, .corse, .pulse, .shield, .poseidon: return SanctumTheme.chironColor // White/System
        }
    }
    
    private func trait(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
                .bold()
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}
