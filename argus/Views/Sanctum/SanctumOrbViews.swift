import SwiftUI

// MARK: - Global Module Orb View
/// Orbit uzerinde gosterilen modul ikonlari (Global piyasalar icin)
struct OrbView: View {
    let module: SanctumModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .stroke(module.color.opacity(0.65), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                
                // Icon
                SanctumModuleIconView(module: module, size: 32)
                    .foregroundColor(module.color)
            }

            // LOCALIZED LABELS
            let label: String = {
                if symbol.uppercased().hasSuffix(".IS") {
                    switch module {
                    case .aether: return "SIRKIYE"
                    case .orion: return "TAHTA"
                    case .atlas: return "KASA"
                    case .hermes: return "KULIS"
                    case .chiron: return "KISMET"
                    default: return module.rawValue
                    }
                } else {
                    return module.rawValue
                }
            }()
            
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
                .tracking(1)
        }
    }
}

// MARK: - BIST Module Orb View
/// Orbit uzerinde gosterilen modul ikonlari (BIST piyasasi icin)
struct BistOrbView: View {
    let module: SanctumBistModuleType
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .stroke(module.color.opacity(0.65), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                    
                // Icon
                SanctumModuleIconView(bistModule: module, size: 32)
                    .foregroundColor(module.color)
            }

            // Modul Ismi
            Text(module.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
                .tracking(1)
        }
    }
}
