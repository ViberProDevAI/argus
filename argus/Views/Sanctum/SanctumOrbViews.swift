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
                // Background (Deep Navy)
                Circle()
                    .fill(Color(hex: "1E293B")) // Slate 800
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Tech Ring (Cleaner V2)
                Circle()
                    .stroke(module.color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20, weight: .regular))
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
                // Background
                Circle()
                    .fill(Color(hex: "1E293B"))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Tech Ring
                Circle()
                    .stroke(module.color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                    
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20, weight: .regular))
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
