import SwiftUI

// MARK: - Chiron Neural Link (V5.H-24 redesign)
//
// **2026-04-24 redesign**. Eski kart `#0F172A → #1E293B` gradient + drop
// shadow + 36pt pulse animasyonlu circle ile diğer institutional kartlardan
// (AetherDashboardCard, sanctum holo paneller) kopuk duruyordu. Yeni hâl:
//   • `surface1` arka plan + `Motors.chiron` 0.3 stroke (Aether kartı ile
//     aynı dil; rejim renkleri sadece sağdaki chip'te yaşıyor).
//   • Tek satır kompakt layout: 14pt logo · iki satır metin · rejim chip'i
//     · chevron. Toplam yükseklik ~40pt (önceden ~70pt + shadow alanı).
//   • Pulse halkaları kaldırıldı — diğer kartlarda yok, gürültüydü.
//   • Hardcoded renkler (`.green/.red/.orange/.purple/.blue`) `ArgusChipTone`
//     üzerinden tema token'larına bağlandı; dark mode + tema değişimine
//     hazır.

struct ChironNeuralLink: View {
    @ObservedObject var engine = ChironRegimeEngine.shared
    @Binding var showEducation: Bool

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            showEducation = true
        }) {
            HStack(spacing: 10) {
                // Compact chiron logo — pulse halkası yok, motor tint'li hafif arka plan
                MotorLogo(.chiron, size: 16)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(InstitutionalTheme.Colors.Motors.chiron.opacity(0.12))
                    )

                // İki satır metin: küçük caption + büyük rejim descriptor'ı
                VStack(alignment: .leading, spacing: 1) {
                    Text("CHIRON · REJİM")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(InstitutionalTheme.Colors.textTertiary)

                    Text(engine.globalResult.regime.descriptor.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Aktif motor — rejim tonunda küçük chip
                ArgusChip(activeEngineName, tone: regimeTone)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.Motors.chiron.opacity(0.3), lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    /// Rejim → tema chip token'ı eşlemesi.
    /// Hardcoded RGB literalleri yerine `ArgusChipTone` kullanıyoruz —
    /// böylece tema/dark-mode ile tutarlı kalıyor.
    /// 2026-04-24 H-25: Mor/magenta yasağı sonrası newsShock `.holo` (mavi)
    /// tonuna alındı — daha grounded, "haber/uyarı" hissi vermeye yeter.
    private var regimeTone: ArgusChipTone {
        switch engine.globalResult.regime {
        case .trend:     return .aurora
        case .riskOff:   return .crimson
        case .chop:      return .titan
        case .newsShock: return .holo
        case .neutral:   return .neutral
        }
    }

    private var activeEngineName: String {
        switch engine.globalResult.regime {
        case .trend:     return "ORION"
        case .riskOff:   return "ATLAS SHIELD"
        case .chop:      return "CORSE SWING"
        case .newsShock: return "HERMES FEED"
        case .neutral:   return "STANDBY"
        }
    }
}
