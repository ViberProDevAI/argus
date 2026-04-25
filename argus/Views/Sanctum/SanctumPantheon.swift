import SwiftUI

// MARK: - Pantheon Deck View
/// Argus Sanctum'da Chiron, Athena ve Demeter mini modülleri.
/// Daha küçük toplar halinde yerleştirilmiş - Tab Bar ile çakışmayı önler.
struct PantheonDeckView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    let isBist: Bool
    @Binding var selectedModule: SanctumModuleType?
    @Binding var selectedBistModule: SanctumBistModuleType?
    
    var body: some View {
        HStack(spacing: 20) {
            // ATHENA (Sol)
            if !isBist {
                MiniPantheonOrb(
                    name: "ATHENA",
                    icon: "AthenaIcon",
                    color: SanctumTheme.athenaColor
                )
                .onTapGesture {
                    selectedModule = .athena
                }
            }
            
            // CHIRON (Orta)
            MiniPantheonOrb(
                name: "CHIRON",
                icon: "ChironIcon",
                color: SanctumTheme.chironColor,
                isPrimary: true
            )
            .onTapGesture {
                // Chiron always opens Chiron UI.
                // Oracle belongs to the Rejim flow, not Chiron.
                selectedModule = .chiron
            }
            
            // DEMETER (Sağ)
            if !isBist {
                MiniPantheonOrb(
                    name: "DEMETER",
                    icon: "DemeterIcon",
                    color: SanctumTheme.demeterColor
                )
                .onTapGesture {
                    selectedModule = .demeter
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
    }
}

// MARK: - Mini Pantheon Orb (V5)
//
// V5 mockup Pantheon deck (satır 1161-1174):
//   • Athena 9x9 (36pt), Chiron 10x10 (40pt — primary), Demeter 9x9 (36pt)
//   • surface2 zemin, motor rengi 1.5px border opacity 0.7
//   • 12/16px glow motor renginde
//   • Alt caption mono 8pt/700, tracking 0.5
//
// 2026-04-22 Sprint 5: MotorLogo kullanımı + V5 boyut/glow hizalama.
struct MiniPantheonOrb: View {
    let name: String
    let motor: MotorEngine
    let color: Color
    var isPrimary: Bool = false

    private var size: CGFloat { isPrimary ? 40 : 36 }
    private var logoSize: CGFloat { isPrimary ? 22 : 20 }
    private var fontSize: CGFloat { isPrimary ? 8 : 8 }

    /// Legacy init — icon string üzerinden motor eşleştirmesi için
    /// uyumluluk katmanı. Yeni kod doğrudan `motor:` parametresini kullansın.
    init(name: String, icon: String, color: Color, isPrimary: Bool = false) {
        self.name = name
        self.color = color
        self.isPrimary = isPrimary
        // Icon string'den motor türet
        switch icon {
        case "AthenaIcon":     self.motor = .athena
        case "ChironIcon":     self.motor = .chiron
        case "DemeterIcon":    self.motor = .demeter
        case "OrionIcon":      self.motor = .orion
        case "AtlasIcon":      self.motor = .atlas
        case "AetherIcon":     self.motor = .aether
        case "HermesIcon":     self.motor = .hermes
        case "PrometheusIcon": self.motor = .prometheus
        case "AlkindusIcon":   self.motor = .alkindus
        case "AnalystIcon":    self.motor = .council
        default:               self.motor = .argus
        }
    }

    /// V5 tercih edilen init — motor engine doğrudan.
    init(name: String, motor: MotorEngine, color: Color, isPrimary: Bool = false) {
        self.name = name
        self.motor = motor
        self.color = color
        self.isPrimary = isPrimary
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // V5 dış glow — box-shadow 12/16px motor renginde
                Circle()
                    .fill(color.opacity(isPrimary ? 0.5 : 0.35))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: isPrimary ? 8 : 6)

                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: size, height: size)

                Circle()
                    .stroke(color.opacity(isPrimary ? 0.85 : 0.7), lineWidth: isPrimary ? 1.5 : 1.2)
                    .frame(width: size, height: size)

                MotorLogo(motor, size: logoSize)
            }

            Text(name)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.9))
                .tracking(0.5)
        }
    }
}

// MARK: - Legacy Flank View (Eski tasarım için korunuyor)
struct PantheonFlankView: View {
    let name: String
    let icon: String
    let color: Color
    let score: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.9))
                    .tracking(1)
                
                Text(score)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
        }
    }
}
