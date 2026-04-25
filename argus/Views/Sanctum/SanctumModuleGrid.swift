import SwiftUI

// MARK: - SanctumModuleGrid
//
// Argus Sanctum ekranının merkez bölgesi:
//   • Ortada CenterCoreView (konsey dialı)
//   • Yörüngede OrbView (global) veya BistOrbView (BIST) ikonları
//
// Önceden ArgusSanctumView içinde `centerCoreArea` computed property olarak
// yaşıyordu. Faz C6 kapsamında split edildi ve bağımsız bir bileşen olarak
// Views/Sanctum/ altına alındı.
//
// Preserve notları:
//   • Orbit radius ve offset matematiği birebir korunur.
//   • `onSelectModule` / `onSelectBistModule` closure'ları ebeveyn ekranın
//     mevcut binding davranışını (spring animation + showDecision reset)
//     devralır.
//   • `CenterCoreView`, `OrbView`, `BistOrbView` imzaları değişmemiştir.

struct SanctumModuleGrid: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    let decision: ArgusGrandDecision?
    let bistModules: [SanctumBistModuleType]
    @Binding var showDecision: Bool

    let onSelectModule: (SanctumModuleType) -> Void
    let onSelectBistModule: (SanctumBistModuleType) -> Void

    // Visual constants (view-only — logic ebeveynde)
    private let orbitRadius: CGFloat = 130

    private var isBistSymbol: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }

    var body: some View {
        ZStack {
            CenterCoreView(
                symbol: symbol,
                decision: decision,
                showDecision: $showDecision
            )

            if isBistSymbol {
                bistOrbitRing
            } else {
                globalOrbitRing
            }
        }
        .frame(height: 260) // Daha kompakt — yukarıda konumlanır
        .accessibilityElement(children: .contain)
    }

    // MARK: - Orbit Rings

    private var bistOrbitRing: some View {
        ForEach(0..<bistModules.count, id: \.self) { i in
            let angle = Double(i) * (360.0 / Double(bistModules.count)) - 90 // Top-anchored
            let mod = bistModules[i]

            BistOrbView(module: mod)
                .offset(
                    x: cos(angle * .pi / 180) * orbitRadius,
                    y: sin(angle * .pi / 180) * orbitRadius
                )
                .onTapGesture {
                    onSelectBistModule(mod)
                }
                .accessibilityLabel(Text("BIST modülü \(mod.rawValue)"))
                .accessibilityHint(Text("Modül detayını aç"))
        }
    }

    private var globalOrbitRing: some View {
        let globalModules: [SanctumModuleType] = [.orion, .atlas, .aether, .hermes, .prometheus]
        return ForEach(0..<globalModules.count, id: \.self) { i in
            let angle = Double(i) * (360.0 / Double(globalModules.count)) - 90
            let mod = globalModules[i]

            OrbView(module: mod, viewModel: viewModel, symbol: symbol)
                .offset(
                    x: cos(angle * .pi / 180) * orbitRadius,
                    y: sin(angle * .pi / 180) * orbitRadius
                )
                .onTapGesture {
                    onSelectModule(mod)
                }
                .accessibilityLabel(Text("Modül \(mod.rawValue)"))
                .accessibilityHint(Text("Modül detayını aç"))
        }
    }
}
