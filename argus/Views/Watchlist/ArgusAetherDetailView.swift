import SwiftUI

struct ArgusAetherDetailView: View {
    let rating: MacroEnvironmentRating

    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<AetherPanelSection> = [.leading]
    @State private var showExpectationsSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    educationalCard

                    ForEach(AetherPanelSection.allCases) { section in
                        sectionCard(section)
                    }

                    formulaCard
                    decisionCard
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Aether Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Beklenti") {
                        showExpectationsSheet = true
                    }
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
            .sheet(isPresented: $showExpectationsSheet) {
                ExpectationsEntryView()
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 4)
                    .frame(width: 66, height: 66)

                Circle()
                    .trim(from: 0, to: CGFloat(clampedScore / 100.0))
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(clampedScore))")
                    .font(InstitutionalTheme.Typography.data)
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AETHER")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1.1)

                Text(rating.regime.displayName)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Text("Not: \(rating.letterGrade) · Çarpan: x\(String(format: "%.2f", rating.multiplier))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var educationalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nasıl Okunur?")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text("Aether, makro ortamı 3 katmanda değerlendirir: öncü (erken sinyal), eşzamanlı (anlık tablo), gecikmeli (onay katmanı).")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func sectionCard(_ section: AetherPanelSection) -> some View {
        let isExpanded = expandedSections.contains(section)
        let sectionScore = score(for: section)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                toggle(section)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                        Text(section.subtitle)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Text("\(Int(sectionScore))")
                        .font(InstitutionalTheme.Typography.dataSmall)
                        .foregroundColor(scoreColor(for: sectionScore))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            scoreBar(value: sectionScore)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
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
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skor Formülü")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text("Skor = (Öncü x 1.5 + Eşzamanlı x 1.0 + Gecikmeli x 0.8) / 3.3")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.primary)

            HStack(spacing: 14) {
                contributionPill(label: "Öncü", value: rating.leadingContribution)
                contributionPill(label: "Eşz.", value: rating.coincidentContribution)
                contributionPill(label: "Gecik.", value: rating.laggingContribution)
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nihai Yorum")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text(decisionSummary)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(decisionAction)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(scoreColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(scoreColor.opacity(0.16))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func metricRow(_ metric: AetherMetric) -> some View {
        let metricScore = clamp(metric.score)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(metric.detail)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Spacer()

            if let change = metric.change {
                let isPositiveForScore = metric.inverse ? change <= 0 : change >= 0
                Text("\(change >= 0 ? "+" : "")\(String(format: "%.2f", change))%")
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(isPositiveForScore ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
            }

            Text("\(Int(metricScore))")
                .font(InstitutionalTheme.Typography.dataSmall)
                .foregroundColor(scoreColor(for: metricScore))
        }
        .padding(.vertical, 4)
    }

    private func contributionPill(label: String, value: Double?) -> some View {
        let val = max(0, min(100, value ?? 0))
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("\(String(format: "%.1f", val))")
                .font(InstitutionalTheme.Typography.dataSmall)
                .foregroundColor(scoreColor(for: val))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
    }

    private func scoreBar(value: Double) -> some View {
        GeometryReader { proxy in
            let width = max(0, min(proxy.size.width, proxy.size.width * CGFloat(value / 100.0)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(InstitutionalTheme.Colors.surface2)
                RoundedRectangle(cornerRadius: 4)
                    .fill(scoreColor(for: value))
                    .frame(width: width)
            }
        }
        .frame(height: 8)
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
        if value >= 70 { return InstitutionalTheme.Colors.positive }
        if value >= 50 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
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
        case .leading: return "x1.5 ağırlık"
        case .coincident: return "x1.0 ağırlık"
        case .lagging: return "x0.8 ağırlık"
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
