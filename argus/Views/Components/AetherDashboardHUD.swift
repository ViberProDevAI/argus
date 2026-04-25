import SwiftUI

/// V5 mockup "01 · Piyasa" Aether HUD kartının Swift karşılığı.
/// (`Argus_Mockup_V5.html` satır 323-342).
///
/// Kompakt tek satır layout:
///   • 44pt trimmed circle — skor + aurora/holo/titan renk
///   • AETHER caption + rejim açıklaması
///   • 3 mini chip — leading / coincident / lagging
///   • Chevron
///
/// Tap → Aether detay sheet.
struct AetherDashboardHUD: View {
    let rating: MacroEnvironmentRating?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                scoreCircle
                captionBlock
                Spacer(minLength: 8)
                if let r = rating {
                    miniChips(rating: r)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    // MARK: - Score circle (V5 44pt trimmed ring + merkezdeki skor)

    private var scoreCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    InstitutionalTheme.Colors.Motors.aether.opacity(0.3),
                    lineWidth: 3
                )
                .frame(width: 44, height: 44)

            if let r = rating {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, r.numericScore / 100))))
                    .stroke(
                        scoreColor(r.numericScore),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(r.numericScore))")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(scoreColor(r.numericScore))
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
    }

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                MotorLogo(.aether, size: 12)
                Text("AETHER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
            }
            Text(subtitleText)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
        }
    }

    private var subtitleText: String {
        guard let r = rating else { return "Rejim hesaplanıyor…" }
        let regimeText = r.regime.displayName
        switch r.numericScore {
        case 70...:  return "Güçlü risk-on · \(regimeText)"
        case 55...:  return "Dengeli risk ortamı · \(regimeText)"
        case 40..<55: return "Kararsız · \(regimeText)"
        default:     return "Risk-off · \(regimeText)"
        }
    }

    private func miniChips(rating r: MacroEnvironmentRating) -> some View {
        HStack(spacing: 4) {
            miniChip(value: r.leadingScore, fallback: nil, tone: .aurora)
            miniChip(value: r.coincidentScore, fallback: nil, tone: .holo)
            miniChip(value: r.laggingScore, fallback: nil, tone: .titan)
        }
    }

    private func miniChip(value: Double?, fallback: Double?, tone: ArgusChipTone) -> some View {
        let v = value ?? fallback
        let text = v.map { String(Int($0)) } ?? "—"
        return Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.3)
            .foregroundColor(tone.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tone.foreground.opacity(0.14)))
    }

    private func scoreColor(_ s: Double) -> Color {
        if s >= 70 { return InstitutionalTheme.Colors.aurora }
        if s >= 50 { return InstitutionalTheme.Colors.holo }
        if s >= 40 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }
}
