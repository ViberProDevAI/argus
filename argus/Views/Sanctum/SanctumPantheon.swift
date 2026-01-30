import SwiftUI

// MARK: - Pantheon Deck View
/// Argus Sanctum'un alt kismi - Chiron, Athena ve Demeter modulleri.
/// "Overwatch Deck" olarak da bilinir.
struct PantheonDeckView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    let isBist: Bool
    @Binding var selectedModule: SanctumModuleType?
    @Binding var selectedBistModule: SanctumBistModuleType?
    
    var body: some View {
        ZStack {
            // 0. VISUAL CONNECTORS (Lines)
            Path { path in
                let apex = CGPoint(x: UIScreen.main.bounds.width / 2, y: 35)
                let leftFlank = CGPoint(x: (UIScreen.main.bounds.width / 2) - 100, y: 80)
                let rightFlank = CGPoint(x: (UIScreen.main.bounds.width / 2) + 100, y: 80)
                
                path.move(to: apex); path.addLine(to: leftFlank)
                path.move(to: apex); path.addLine(to: rightFlank)
            }
            .stroke(SanctumTheme.chironColor.opacity(DesignTokens.Opacity.glassCard), lineWidth: 1)
            
            // 1. APEX: CHIRON (Time & Risk)
            let chironColor = SanctumTheme.chironColor
            
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1E293B"))
                        .frame(width: 56, height: 56)
                        .shadow(color: chironColor.opacity(0.3), radius: 10, x: 0, y: 0)
                    
                    Circle()
                        .stroke(chironColor, lineWidth: 2)
                        .frame(width: 56, height: 56)
                        
                    Image(systemName: "hourglass")
                        .font(.system(size: 20))
                        .foregroundColor(chironColor)
                }
                
                Text("CHIRON")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(chironColor)
                    .tracking(2)
            }
            .offset(y: -20)
            .zIndex(100)
            .onTapGesture {
                if isBist {
                    selectedBistModule = .oracle
                } else {
                    selectedModule = .chiron
                }
            }
            
            if !isBist {
                // 2. FLANKS: ATHENA (Left)
                PantheonFlankView(
                    name: "ATHENA",
                    icon: "brain.head.profile",
                    color: SanctumTheme.athenaColor,
                    score: getAthenaScore(),
                    label: getAthenaLabel()
                )
                .offset(x: -100, y: 55)
                .onTapGesture {
                    selectedModule = .athena
                }
                
                // 3. FLANKS: DEMETER (Right)
                PantheonFlankView(
                    name: "DEMETER",
                    icon: "leaf.fill",
                    color: SanctumTheme.demeterColor,
                    score: getDemeterScore(),
                    label: getDemeterLabel()
                )
                .offset(x: 100, y: 55)
                .onTapGesture {
                    selectedModule = .demeter
                }
            }
            
        }
        .frame(height: 120)
        .padding(.top, 10)
    }
    
    // MARK: - Data Helpers
    
    func getAthenaScore() -> String {
        if isBist {
            if let score = viewModel.grandDecisions[symbol]?.bistDetails?.faktor.score {
                return String(format: "%.0f", score)
            }
            return "--"
        } else {
            return String(format: "%.0f", viewModel.athenaResults[symbol]?.totalScore ?? 0.0)
        }
    }
    
    func getAthenaLabel() -> String {
        return isBist ? "AKIL" : "STRATEJI"
    }
    
    func getDemeterScore() -> String {
        if isBist {
            if let score = viewModel.grandDecisions[symbol]?.bistDetails?.sektor.score {
                return String(format: "%.0f", score)
            }
            return "--"
        } else {
            return String(format: "%.0f", viewModel.getDemeterScore(for: symbol)?.totalScore ?? 0.0)
        }
    }
    
    func getDemeterLabel() -> String {
        return isBist ? "ZEMIN" : "SEKTOR"
    }
}

// MARK: - Pantheon Flank View
/// Athena ve Demeter modul ikonlari icin yardimci gorunum.
struct PantheonFlankView: View {
    let name: String
    let icon: String
    let color: Color
    let score: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(Color(hex: "1E293B"))
                    .frame(width: 44, height: 44)
                
                Circle()
                    .stroke(color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            // Info
            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.9))
                    .tracking(1)
                
                Text(score)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
}
