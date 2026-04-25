import SwiftUI

// MARK: - SirkiyeDashboardView (in-place refactor — ArgusDesignKit v1)
//
// Tek dokunuş: kortex skoru + mod etiketi + canlı BIST 100 endeksi.
// Tıklanınca SirkiyeAetherView açılır (mevcut davranış korunur).
// Veri kaynakları:
//   • viewModel.bistAtmosphere           (anlık karar)
//   • SirkiyeAetherEngine.shared.analyze (fallback makro snapshot)
//   • BorsaPyProvider.shared.getXU100()  (endeks canlı)
// Demo veri yok. Empty/loading durumu status etiketi ile ifade edilir.

struct SirkiyeDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel

    @State private var showDetails = false
    @State private var xu100Value: Double = 0
    @State private var xu100Change: Double = 0
    @State private var fallbackMacroScore: Double = 50
    @State private var fallbackMacroReady = false

    // MARK: - Derived Data

    private var atmosphere: (score: Double, mode: MarketMode, reason: String) {
        if let decision = viewModel.bistAtmosphere {
            let score = decision.netSupport * 100.0
            let reason = decision.winningProposal?.reasoning ?? "Analiz tamamlandı"
            return (score, decision.marketMode, reason)
        } else {
            return (fallbackMacroScore, modeFrom(score: fallbackMacroScore), "TCMB makro snapshot")
        }
    }

    private var statusIndicator: (color: Color, text: String) {
        if viewModel.bistAtmosphere != nil {
            return (InstitutionalTheme.Colors.aurora, "CANLI")
        } else if fallbackMacroReady {
            return (InstitutionalTheme.Colors.holo, "MAKRO")
        } else {
            return (InstitutionalTheme.Colors.titan, "YÜKLENİYOR")
        }
    }

    private var xu100DisplayValue: String {
        xu100Value > 0 ? String(format: "%.0f", xu100Value) : "—"
    }

    // MARK: - Body

    var body: some View {
        Button(action: { showDetails = true }) {
            ArgusCard(style: .elevated, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow
                    mainRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(Text("Sirkiye Aether detayını aç"))
        .onAppear {
            Task {
                if viewModel.bistAtmosphere == nil {
                    await viewModel.refreshBistAtmosphere()
                }
                await loadFallbackMacroScore()
                await loadXU100()
            }
        }
        .sheet(isPresented: $showDetails) {
            NavigationStack {
                SirkiyeAetherView(linkedDecision: viewModel.bistAtmosphere)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    MotorLogo(.aether, size: 12)
                    ArgusSectionCaption("SİRKİYE KORTEKS")
                }
                .accessibilityAddTraits(.isHeader)

                Text(modeDisplayText)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 8)
            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            ArgusDot(color: statusIndicator.color, size: 5)
            Text(statusIndicator.text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(statusIndicator.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(statusIndicator.color.opacity(0.14))
        )
        .overlay(
            Capsule().stroke(statusIndicator.color.opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 16) {
            scoreRing
            stanceBlock
            Spacer(minLength: 8)
            xu100Block
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 4)
                .frame(width: 56, height: 56)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, atmosphere.score / 100.0))))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: modeColors), center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))

            Text("\(Int(atmosphere.score))")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.heavy)
                .monospacedDigit()
                .foregroundColor(scoreColor)
        }
        .frame(width: 56, height: 56)
    }

    private var stanceBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("DURUŞ")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .tracking(1.1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)

            Text(stanceText)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(stanceColor)
                .lineLimit(1)
        }
    }

    private var xu100Block: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("BIST 100")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .tracking(1.1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)

            Text(xu100DisplayValue)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.heavy)
                .monospacedDigit()
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(1)

            if xu100Value > 0 {
                ArgusDeltaPill(delta: xu100Change, isPercent: true, compact: true)
            }
        }
    }

    // MARK: - Data Loading

    private func loadXU100() async {
        do {
            let quote = try await BorsaPyProvider.shared.getXU100()
            await MainActor.run {
                xu100Value = quote.last
                xu100Change = quote.changePercent
            }
        } catch {
            print("⚠️ XU100 yüklenemedi: \(error)")
        }
    }

    private func loadFallbackMacroScore() async {
        let macro = await SirkiyeAetherEngine.shared.analyze(forceRefresh: true)
        await MainActor.run {
            fallbackMacroScore = max(0, min(100, macro.overallScore))
            fallbackMacroReady = true
        }
    }

    // MARK: - Derived Styling

    private var modeColors: [Color] {
        switch atmosphere.mode {
        case .panic:        return [InstitutionalTheme.Colors.crimson, InstitutionalTheme.Colors.titan]
        case .extremeFear:  return [InstitutionalTheme.Colors.crimson, InstitutionalTheme.Colors.textSecondary]
        case .fear:         return [InstitutionalTheme.Colors.titan, InstitutionalTheme.Colors.textSecondary]
        case .neutral:      return [InstitutionalTheme.Colors.holo, InstitutionalTheme.Colors.textSecondary]
        case .greed:        return [InstitutionalTheme.Colors.aurora, InstitutionalTheme.Colors.holo]
        case .extremeGreed: return [InstitutionalTheme.Colors.aurora, InstitutionalTheme.Colors.titan]
        case .complacency:  return [InstitutionalTheme.Colors.textSecondary, InstitutionalTheme.Colors.textTertiary]
        }
    }

    private var scoreColor: Color {
        if atmosphere.score >= 70 { return InstitutionalTheme.Colors.aurora }
        else if atmosphere.score >= 50 { return InstitutionalTheme.Colors.holo }
        else if atmosphere.score >= 30 { return InstitutionalTheme.Colors.titan }
        else { return InstitutionalTheme.Colors.crimson }
    }

    private var modeDisplayText: String {
        switch atmosphere.mode {
        case .panic:        return "PANİK MOD"
        case .extremeFear:  return "AŞIRI KORKU"
        case .fear:         return "KORKU MOD"
        case .neutral:      return "NÖTR ATMOSFER"
        case .greed:        return "AÇGÖZLÜ MOD"
        case .extremeGreed: return "AŞIRI AÇGÖZLÜLÜK"
        case .complacency:  return "REHAVET"
        }
    }

    private func modeFrom(score: Double) -> MarketMode {
        switch score {
        case ..<25:  return .panic
        case ..<40:  return .extremeFear
        case ..<50:  return .fear
        case ..<60:  return .neutral
        case ..<75:  return .greed
        case ..<90:  return .extremeGreed
        default:     return .complacency
        }
    }

    private var stanceText: String {
        guard let decision = viewModel.bistAtmosphere else { return "BEKLENİYOR" }
        switch decision.stance {
        case .riskOff:   return "RİSK KAPALI"
        case .defensive: return "DEFANSİF"
        case .cautious:  return "TEDBİRLİ"
        case .riskOn:    return "RİSK AÇIK"
        }
    }

    private var stanceColor: Color {
        guard let decision = viewModel.bistAtmosphere else {
            return InstitutionalTheme.Colors.textSecondary
        }
        switch decision.stance {
        case .riskOff:   return InstitutionalTheme.Colors.crimson
        case .defensive: return InstitutionalTheme.Colors.titan
        case .cautious:  return InstitutionalTheme.Colors.holo
        case .riskOn:    return InstitutionalTheme.Colors.aurora
        }
    }

    // MARK: - Accessibility

    private var accessibilitySummary: Text {
        let changeStr = xu100Value > 0
            ? String(format: "%+.2f yüzde", xu100Change)
            : "endeks yükleniyor"
        return Text(
            "Sirkiye Korteks, \(modeDisplayText), skor \(Int(atmosphere.score)), duruş \(stanceText). " +
            "BIST 100 \(xu100DisplayValue), \(changeStr)."
        )
    }
}

// MARK: - Custom Badge Helper (legacy, korunuyor — diğer ekranlar kullanıyor olabilir)

extension View {
    func paddingbadge(_ color: Color) -> some View {
        self.padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
