import SwiftUI

/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (geri deco +
/// Aether motor pill, beklenti/kapat aksiyonları custom ikon olarak). Panel
/// içerik, skor halkası, makro ayrıştırma ve beklenti sheet'i aynı.
struct ArgusAetherDetailView: View {
    let rating: MacroEnvironmentRating

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var expectationsStore = ExpectationsStore.shared
    @State private var expandedSections: Set<AetherPanelSection> = [.leading]
    @State private var showExpectationsSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "AETHER",
                        subtitle: "MAKRO REJİM · SKOR · FORMÜL",
                        leadingDeco: .back(onTap: { dismiss() }),
                        titlePill: .init(text: "ANALİZ", tone: .motor(.aether)),
                        actions: [
                            .custom(sfSymbol: "slider.horizontal.3",
                                    action: { showExpectationsSheet = true }),
                            .custom(sfSymbol: "xmark",
                                    action: { dismiss() })
                        ]
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard
                            educationalCard

                            ForEach(AetherPanelSection.allCases) { section in
                                sectionCard(section)
                            }

                            accuracyCard
                            formulaCard
                            decisionCard
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showExpectationsSheet) {
                ExpectationsEntryView()
            }
        }
    }

    private var headerCard: some View {
        // V5: 66pt trimmed ring + motor caption + regime + letter grade/multiplier chips
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.3), lineWidth: 4)
                    .frame(width: 66, height: 66)

                Circle()
                    .trim(from: 0, to: CGFloat(clampedScore / 100.0))
                    .stroke(scoreColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(clampedScore))")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(scoreColor)
                    Text("AETHER")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    MotorLogo(.aether, size: 12)
                    Text("AETHER · MAKRO REJİM")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                }

                Text(rating.regime.displayName)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                HStack(spacing: 6) {
                    ArgusChip("NOT \(rating.letterGrade)", tone: .motor(.aether))
                    ArgusChip(String(format: "×%.2f", rating.multiplier), tone: .holo)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private var educationalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("NASIL OKUNUR?")

            HStack(spacing: 10) {
                legendChip("ÖNCÜ",        tone: .aurora)
                legendChip("EŞZAMANLI",   tone: .holo)
                legendChip("GECİKMELİ",   tone: .titan)
            }

            Text("Aether makro ortamı 3 katmanda değerlendirir: öncü (erken sinyal), eşzamanlı (anlık tablo), gecikmeli (onay katmanı).")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func legendChip(_ text: String, tone: ArgusChipTone) -> some View {
        HStack(spacing: 5) {
            ArgusDot(color: tone.foreground, size: 5)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(tone.foreground)
        }
    }

    private func sectionCard(_ section: AetherPanelSection) -> some View {
        let isExpanded = expandedSections.contains(section)
        let sectionScore = score(for: section)
        let tone = section.tone

        return VStack(alignment: .leading, spacing: 10) {
            Button { toggle(section) } label: {
                HStack(spacing: 10) {
                    ArgusDot(color: tone.foreground, size: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(tone.foreground)
                        Text(section.subtitle)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }

                    Spacer()

                    Text("\(Int(sectionScore))")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(scoreColor(for: sectionScore))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            ArgusBar(value: sectionScore / 100.0,
                     color: scoreColor(for: sectionScore),
                     height: 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(metrics(for: section)) { metric in
                        metricRow(metric)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(tone.foreground.opacity(isExpanded ? 0.4 : 0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    /// Tahmin Doğruluğu kartı — kullanıcının son N tahmininin ne kadarının tuttuğunu gösterir.
    /// Hiç çözümlenmiş tahmin yoksa kısa bir teşvik mesajı, ayrıca "Tahmin Gir" kısayolu gösterir.
    private var accuracyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                ArgusSectionCaption("TAHMİN DOĞRULUĞU")
                Spacer()
                Button(action: { showExpectationsSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                        Text("TAHMİN GİR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                    }
                    .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.4), lineWidth: 1)
                    )
                }
            }

            if let overall = expectationsStore.getOverallAccuracy(lastN: 20) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f%%", overall.accuracy))
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(accuracyColor(for: overall.accuracy))
                        Text("GENEL DOĞRULUK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(overall.correct) / \(overall.total)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("SON \(overall.total) TAHMİN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }

                    Spacer()
                }

                ArgusBar(value: overall.accuracy / 100.0,
                         color: accuracyColor(for: overall.accuracy),
                         height: 5)

                // Gösterge bazlı dağılım (yalnızca çözümlenmiş kayıtları olanlar).
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ExpectationsStore.EconomicIndicator.allCases) { indicator in
                        if let summary = expectationsStore.getAccuracySummary(for: indicator, lastN: 10) {
                            indicatorAccuracyRow(indicator: indicator, summary: summary)
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                // Henüz çözümlenmiş tahmin yok — boş durum
                VStack(alignment: .leading, spacing: 6) {
                    Text("Henüz tahmin geçmişi yok")
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("Ekonomik veri açıklanmadan önce beklentinizi girin. Veri geldiğinde tahmininizin tutup tutmadığı burada izlenir; sürpriz Aether skoruna ±10 puan etki eder.")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func indicatorAccuracyRow(indicator: ExpectationsStore.EconomicIndicator,
                                      summary: ExpectationsStore.AccuracySummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: indicator.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 16)

            Text(indicator.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(summary.correct)/\(summary.total)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            Text(String(format: "%.0f%%", summary.accuracy))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(accuracyColor(for: summary.accuracy))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    private func accuracyColor(for value: Double) -> Color {
        if value >= 70 { return InstitutionalTheme.Colors.aurora }
        if value >= 50 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("SKOR FORMÜLÜ")

            Text("(Öncü×1.5 + Eşzamanlı×1.0 + Gecikmeli×0.8) / 3.3")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            HStack(spacing: 10) {
                contributionPill(label: "ÖNCÜ",   value: rating.leadingContribution,
                                 tone: .aurora)
                contributionPill(label: "EŞZ.",   value: rating.coincidentContribution,
                                 tone: .holo)
                contributionPill(label: "GECİK.", value: rating.laggingContribution,
                                 tone: .titan)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("NİHAİ YORUM")

            Text(decisionSummary)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ArgusPill(decisionAction.uppercased(), tone: decisionActionTone)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(decisionActionTone.foreground.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var decisionActionTone: ArgusChipTone {
        switch rating.regime {
        case .riskOn:  return .aurora
        case .neutral: return .titan
        case .riskOff: return .crimson
        }
    }

    private func metricRow(_ metric: AetherMetric) -> some View {
        let metricScore = clamp(metric.score)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(metric.detail)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if let change = metric.change {
                let isPositiveForScore = metric.inverse ? change <= 0 : change >= 0
                let tone: ArgusChipTone = isPositiveForScore ? .aurora : .crimson
                ArgusChip(String(format: "%@%.2f%%", change >= 0 ? "+" : "", change), tone: tone)
            }

            Text("\(Int(metricScore))")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(scoreColor(for: metricScore))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .overlay(ArgusHair(), alignment: .bottom)
    }

    private func contributionPill(label: String, value: Double?, tone: ArgusChipTone) -> some View {
        let val = max(0, min(100, value ?? 0))
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(tone.foreground)
            Text(String(format: "%.1f", val))
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            ArgusBar(value: val / 100.0, color: tone.foreground, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .stroke(tone.foreground.opacity(0.3), lineWidth: 1)
        )
    }

    private func toggle(_ section: AetherPanelSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func metrics(for section: AetherPanelSection) -> [AetherMetric] {
        switch section {
        case .leading:
            return [
                AetherMetric(title: "VIX", detail: "Volatilite / korku göstergesi", score: rating.volatilityScore, change: rating.componentChanges["volatility"], inverse: true),
                AetherMetric(title: "Faiz Eğrisi", detail: "10Y-2Y yayılımı", score: rating.interestRateScore, change: nil, inverse: false),
                AetherMetric(title: "İşsizlik Başvuruları", detail: "Haftalık ICSA eğilimi", score: rating.claimsScore, change: nil, inverse: true),
                AetherMetric(title: "Bitcoin", detail: "Risk iştahı proxysi", score: rating.cryptoRiskScore, change: rating.componentChanges["crypto"], inverse: false)
            ]
        case .coincident:
            return [
                AetherMetric(title: "SPY Trendi", detail: "Piyasa yönü", score: rating.equityRiskScore, change: rating.componentChanges["equity"], inverse: false),
                AetherMetric(title: "İstihdam", detail: "Büyüme temposu", score: rating.growthScore, change: nil, inverse: false),
                AetherMetric(title: "DXY", detail: "Dolar baskısı", score: rating.currencyScore, change: rating.componentChanges["dollar"], inverse: true)
            ]
        case .lagging:
            return [
                AetherMetric(title: "CPI", detail: "Enflasyon yönü", score: rating.inflationScore, change: nil, inverse: true),
                AetherMetric(title: "İşsizlik", detail: "Gecikmeli iş gücü etkisi", score: rating.laborScore, change: nil, inverse: true),
                AetherMetric(title: "Altın (GLD)", detail: "Güvenli liman eğilimi", score: rating.safeHavenScore, change: rating.componentChanges["gold"], inverse: true)
            ]
        }
    }

    private func score(for section: AetherPanelSection) -> Double {
        switch section {
        case .leading: return clamp(rating.leadingScore)
        case .coincident: return clamp(rating.coincidentScore)
        case .lagging: return clamp(rating.laggingScore)
        }
    }

    private var clampedScore: Double {
        max(0, min(100, rating.numericScore))
    }

    private var scoreColor: Color {
        scoreColor(for: clampedScore)
    }

    private func scoreColor(for value: Double) -> Color {
        if value >= 70 { return InstitutionalTheme.Colors.aurora }
        if value >= 50 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func clamp(_ value: Double?) -> Double {
        max(0, min(100, value ?? 50))
    }

    private var decisionSummary: String {
        if clampedScore >= 70 {
            return "Makro zemin destekleyici. Öncü katman risk iştahını doğruluyorsa pozisyon artırımı düşünülebilir."
        }
        if clampedScore >= 50 {
            return "Makro sinyaller karışık. Yönlü agresyon yerine seçici ve kademeli yaklaşım daha rasyonel."
        }
        return "Makro baskı yüksek. Koruma ve pozisyon küçültme öncelikli tutulmalı."
    }

    private var decisionAction: String {
        switch rating.regime {
        case .riskOn: return "Risk artışı mümkün"
        case .neutral: return "Denge ve seçicilik"
        case .riskOff: return "Risk azalt / koruma artır"
        }
    }
}

private enum AetherPanelSection: CaseIterable, Identifiable {
    case leading
    case coincident
    case lagging

    var id: String { title }

    var title: String {
        switch self {
        case .leading: return "Öncü Katman"
        case .coincident: return "Eşzamanlı Katman"
        case .lagging: return "Gecikmeli Katman"
        }
    }

    var subtitle: String {
        switch self {
        case .leading: return "×1.5 ağırlık · erken sinyal"
        case .coincident: return "×1.0 ağırlık · anlık tablo"
        case .lagging: return "×0.8 ağırlık · onay katmanı"
        }
    }

    var tone: ArgusChipTone {
        switch self {
        case .leading:    return .aurora
        case .coincident: return .holo
        case .lagging:    return .titan
        }
    }
}

private struct AetherMetric: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let score: Double?
    let change: Double?
    let inverse: Bool
}
