import SwiftUI

// MARK: - Aether Dashboard Card (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Eski kart `.cyan / .blue / .green / .yellow / .orange / .red / .pink / .mint`
// literalleri ve `LinearGradient` yığınıyla doluydu — makro kartı "promo
// kampanyası" gibi duruyordu. Artık institutional: motor(.aether) tint,
// `ArgusSectionCaption`, `ArgusChip`, `ArgusBar`. Ring gauge korundu ama
// tek renk motor tint. Compact ve full mode ikisi de aynı dile oturdu.
//
// Data sözleşmesi dokunulmadı: `MacroEnvironmentRating` aynen geliyor.
struct AetherDashboardCard: View {
    let rating: MacroEnvironmentRating
    var isCompact: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            header

            if isCompact {
                compactRow
            } else {
                fullHero
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isCompact ? 12 : 14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.aether, size: 14)
            ArgusSectionCaption("AETHER MAKRO")
            Spacer()
            ArgusChip(regimeLabel.uppercased(), tone: regimeTone)
        }
    }

    // MARK: - Full mode

    private var fullHero: some View {
        HStack(alignment: .top, spacing: 18) {
            ringGauge
            categoryStack
        }
    }

    private var ringGauge: some View {
        let tone = scoreTone(rating.numericScore)
        return ZStack {
            Circle()
                .stroke(InstitutionalTheme.Colors.surface3, lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, rating.numericScore)) / 100))
                .stroke(tone.foreground,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: rating.numericScore)

            VStack(spacing: 2) {
                Text("\(Int(rating.numericScore))")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(rating.letterGrade.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(tone.foreground)
            }
        }
        .frame(width: 92, height: 92)
    }

    private var categoryStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryRow(label: "ÖNCÜ",
                        score: rating.leadingScore ?? 50,
                        weight: "×1.5")
            categoryRow(label: "EŞZAMANLI",
                        score: rating.coincidentScore ?? 50,
                        weight: "×1.0")
            categoryRow(label: "GECİKMELİ",
                        score: rating.laggingScore ?? 50,
                        weight: "×0.8")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryRow(label: String, score: Double, weight: String) -> some View {
        let tone = scoreTone(score)
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .frame(width: 76, alignment: .leading)

            ArgusBar(value: max(0, min(1, score / 100)),
                     color: tone.foreground,
                     height: 4)

            Text("\(Int(score))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 26, alignment: .trailing)

            Text(weight)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Compact mode

    private var compactRow: some View {
        HStack(spacing: 12) {
            compactRing
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                miniPill(label: "Ö", score: rating.leadingScore ?? 50)
                miniPill(label: "E", score: rating.coincidentScore ?? 50)
                miniPill(label: "G", score: rating.laggingScore ?? 50)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }

    private var compactRing: some View {
        let tone = scoreTone(rating.numericScore)
        return ZStack {
            Circle()
                .stroke(InstitutionalTheme.Colors.surface3, lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, rating.numericScore)) / 100))
                .stroke(tone.foreground,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(rating.numericScore))")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
        }
        .frame(width: 38, height: 38)
    }

    private func miniPill(label: String, score: Double) -> some View {
        let tone = scoreTone(score)
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("\(Int(score))")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(tone.foreground)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(tone.background))
    }

    // MARK: - Tone mapping

    private var regimeLabel: String {
        switch rating.regime {
        case .riskOn:  return "RISK ON"
        case .neutral: return "NÖTR"
        case .riskOff: return "RISK OFF"
        }
    }

    private var regimeTone: ArgusChipTone {
        switch rating.regime {
        case .riskOn:  return .aurora
        case .neutral: return .titan
        case .riskOff: return .crimson
        }
    }

    /// Skor → 4 V5 tone.  Aether motoru makro duyarlı olduğundan
    /// 50 civarı titan (ne pozitif ne negatif), 70+ aurora.
    private func scoreTone(_ score: Double) -> ArgusChipTone {
        if score >= 70 { return .aurora }
        if score >= 55 { return .motor(.aether) }
        if score >= 45 { return .titan }
        return .crimson
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AetherDashboardCard(
            rating: MacroEnvironmentRating(
                equityRiskScore: 72, volatilityScore: 85, safeHavenScore: 55,
                cryptoRiskScore: 78, interestRateScore: 60, currencyScore: 62,
                inflationScore: 65, laborScore: 76, growthScore: 80,
                creditSpreadScore: 70, claimsScore: 82,
                leadingScore: 74, coincidentScore: 68, laggingScore: 65,
                leadingContribution: 33.6, coincidentContribution: 20.6,
                laggingContribution: 15.8,
                numericScore: 72, letterGrade: "B+", regime: .riskOn,
                summary: "Aether v5", details: ""
            )
        )

        AetherDashboardCard(
            rating: MacroEnvironmentRating(
                equityRiskScore: 72, volatilityScore: 85, safeHavenScore: 55,
                cryptoRiskScore: 78, interestRateScore: 60, currencyScore: 62,
                inflationScore: 65, laborScore: 76, growthScore: 80,
                creditSpreadScore: 70, claimsScore: 82,
                leadingScore: 74, coincidentScore: 68, laggingScore: 65,
                leadingContribution: 33.6, coincidentContribution: 20.6,
                laggingContribution: 15.8,
                numericScore: 72, letterGrade: "B+", regime: .riskOn,
                summary: "Aether v5", details: ""
            ),
            isCompact: true
        )
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
