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

// MARK: - Mini Pantheon Orb
/// Küçük, kompakt modül gösterimi
struct MiniPantheonOrb: View {
    let name: String
    let icon: String
    let color: Color
    var isPrimary: Bool = false
    
    // Boyutlar
    private var size: CGFloat { isPrimary ? 32 : 26 }
    private var iconSize: CGFloat { isPrimary ? 14 : 11 }
    private var fontSize: CGFloat { isPrimary ? 7 : 6 }
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 0)
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    .frame(width: size, height: size)
                
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: isPrimary ? 1.5 : 1)
                    .frame(width: size, height: size)
                
                if icon.hasSuffix("Icon") {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize + 4, height: iconSize + 4)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(color)
                }
            }
            
            Text(name)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
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
