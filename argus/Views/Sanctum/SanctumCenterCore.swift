import SwiftUI

// MARK: - Center Core View (V5)
//
// V5 mockup Sanctum merkez Konsey orbu (satır 1181-1186):
//   • 108pt daire
//   • Radial gradient center (holo .35 → surface deep .9 %60)
//   • Border 1.5px holo .6
//   • İçte glow (inset 40px -10px holo) + dışta glow (30px holo .35)
//   • İçerik: Argus logosu + "NİHAİ KARAR" caption + aksiyon chip + "Güven %N"
//
// 2026-04-22 Sprint 5: Eski "dial/knob" interaksiyonu kaldırıldı — V5'te
// merkez statik bir karar orbu, etraftaki 5 motor orbu tıklanınca detaya
// gidilir (SanctumModuleGrid.onSelectModule closure'u aynı).
// Merkeze tap → showDecision toggle (mevcut davranış korundu).

struct CenterCoreView: View {
    let symbol: String
    let decision: ArgusGrandDecision?
    @Binding var showDecision: Bool

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            // Dış dashed halka — V5 dashed border-radius 9999
            Circle()
                .stroke(
                    InstitutionalTheme.Colors.holo.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
                .frame(width: 220, height: 220)

            // İç dashed halka (daha hafif)
            Circle()
                .stroke(
                    InstitutionalTheme.Colors.holo.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                )
                .frame(width: 180, height: 180)

            // V5 Konsey orbu
            councilOrb
        }
    }

    // MARK: - Konsey Orbu
    //
    // 2026-04-24 H-17: "Logo orta yuvarlakla aynı boyutta, hare olmayacak,
    // yazılar logonun üzerine rahatsız etmeyecek şekilde gelecek" direktifi.
    //   • Dış glow (132pt blur) ve iç glow (strokeBorder radial) kaldırıldı.
    //   • Argus aperture logosu 24pt → 108pt; Circle ile clip'lenir.
    //   • Metin bloğu yarı şeffaf backgroundDeep kapsül üzerinde ortalanır —
    //     apertür kirpiklerini bozmaz, okunur kalır.

    private var councilOrb: some View {
        ZStack {
            // Ana daire arka plan — radial gradient aperture kontrastı için korundu
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: InstitutionalTheme.Colors.holo.opacity(0.35), location: 0),
                            .init(color: InstitutionalTheme.Colors.backgroundDeep.opacity(0.9), location: 0.6),
                            .init(color: InstitutionalTheme.Colors.backgroundDeep, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 54
                    )
                )
                .frame(width: 108, height: 108)

            // Argus logosu — daireyi tam dolduran boyut, Circle clip
            MotorLogo(.argus, size: 108)
                .frame(width: 108, height: 108)
                .clipShape(Circle())

            // V5 border — 1.5px holo .6 (logonun üstünde kalır)
            Circle()
                .stroke(InstitutionalTheme.Colors.holo.opacity(0.6), lineWidth: 1.5)
                .frame(width: 108, height: 108)

            // Metin bloğu · logonun apertür merkezine oturur.
            // Yarı şeffaf deep-bg kapsül okunabilirliği sağlar, aperture
            // kirpik desenini blokladığı alan minimum tutulur.
            VStack(spacing: 3) {
                Text("NİHAİ KARAR")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(InstitutionalTheme.Colors.holo)

                decisionChip

                confidenceText
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(InstitutionalTheme.Colors.backgroundDeep.opacity(0.55))
            )
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                showDecision.toggle()
            }
            impactFeedback.impactOccurred(intensity: 0.7)
        }
        .onAppear { showDecision = false }
    }

    // MARK: - Aksiyon chip (V5 KONSEY HÜCUM gibi)

    @ViewBuilder
    private var decisionChip: some View {
        if let d = decision {
            let label = "KONSEY \(d.action.rawValue.uppercased())"
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(actionColor(for: d.action))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(actionColor(for: d.action).opacity(0.2))
                        .overlay(
                            Capsule().stroke(actionColor(for: d.action).opacity(0.5), lineWidth: 0.5)
                        )
                )
        } else {
            Text("KARAR BEKLENİYOR")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(InstitutionalTheme.Colors.textTertiary)
        }
    }

    @ViewBuilder
    private var confidenceText: some View {
        if let d = decision {
            Text("Güven %\(Int(d.confidence * 100))")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(InstitutionalTheme.Colors.textSecondary)
        } else {
            EmptyView()
        }
    }

    private func actionColor(for action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.aurora
        case .accumulate:    return InstitutionalTheme.Colors.holo
        case .neutral:       return InstitutionalTheme.Colors.titan
        case .trim:          return Color.orange
        case .liquidate:     return InstitutionalTheme.Colors.crimson
        }
    }
}
