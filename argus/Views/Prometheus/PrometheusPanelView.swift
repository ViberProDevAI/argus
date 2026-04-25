import SwiftUI
import Charts

struct PrometheusPanelView: View {
    let symbol: String
    let candles: [Candle]

    @State private var forecast: PrometheusForecast?
    @State private var isLoading = false

    private var historicalTail: [Candle] {
        Array(candles.suffix(80))
    }

    var body: some View {
        // 2026-04-23 QA: iç ScrollView kaldırıldı. HoloPanelView zaten
        // dış ScrollView sağlıyor; nested scroll view iç bounds'u çökertip
        // paneli boş gösteriyordu. Artık dış scroll paneli naturel sarıyor.
        VStack(alignment: .leading, spacing: 14) {
            header
            summaryCard
            continuationChartCard
            rationaleCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await loadForecast()
        }
    }

    private var header: some View {
        // V5.B-4 — motor avatar + mono caps başlık + info chip
        HStack(spacing: 12) {
            ArgusOrb(size: 44,
                     ringColor: InstitutionalTheme.Colors.Motors.prometheus,
                     glowColor: InstitutionalTheme.Colors.Motors.prometheus) {
                MotorLogo(.prometheus, size: 24)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("PROMETHEUS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(InstitutionalTheme.Colors.Motors.prometheus)
                    Text("·")
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("FIYAT PROJEKSİYONU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                Text("Bilimsel zaman çizgisi ve karar mantığı")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    private var summaryCard: some View {
        Group {
            if isLoading {
                loadingBlock
            } else if let f = forecast, f.isValid {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        recommendationBadge(f.recommendation)
                        Spacer()
                        ArgusChip("UFUK · \(f.horizonDays)G", tone: .motor(.prometheus))
                    }

                    // Büyük skor: tahmin fiyatı
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TAHMİN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(formatPrice(f.predictedPrice))
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Text(f.formattedChange)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(recommendationColor(f.recommendation))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(recommendationColor(f.recommendation).opacity(0.18))
                                )
                        }
                    }

                    ArgusHair()

                    HStack(spacing: 12) {
                        v5Metric("ŞİMDİ", value: formatPrice(f.currentPrice))
                        v5Metric("GÜVEN", value: "%\(Int(f.confidence))",
                                 tone: confidenceTone(f.confidence))
                        v5Metric("MAPE", value: String(format: "%.2f%%", f.validationMAPE))
                    }

                    HStack(spacing: 12) {
                        v5Metric("YÖN İSABET",
                                 value: String(format: "%.1f%%", f.directionalAccuracy * 100),
                                 tone: f.directionalAccuracy >= 0.55 ? .aurora : .titan)
                        v5Metric("VERİ", value: "\(f.dataPointsUsed) bar")
                    }
                }
            } else {
                missingDataBlock
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.prometheus.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    /// V5 metrik kutusu — mini-stat; opsiyonel ton vurgusu.
    private func v5Metric(_ title: String, value: String, tone: ArgusChipTone? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(tone?.foreground ?? InstitutionalTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confidenceTone(_ value: Double) -> ArgusChipTone {
        if value >= 70 { return .aurora }
        if value >= 50 { return .titan }
        return .crimson
    }

    private func recommendationColor(_ rec: PrometheusRecommendation) -> Color {
        switch rec {
        case .buy:  return InstitutionalTheme.Colors.aurora
        case .sell: return InstitutionalTheme.Colors.crimson
        case .hold: return InstitutionalTheme.Colors.titan
        }
    }

    private var continuationChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ArgusSectionCaption("FİYAT DEVAM GRAFİĞİ")
                Spacer()
                if let f = forecast, f.isValid {
                    ArgusChip("\(historicalTail.count) + \(f.predictions.count)",
                              tone: .motor(.prometheus))
                }
            }

            if let f = forecast, f.isValid, !historicalTail.isEmpty {
                let chartData = buildChartData(forecast: f, history: historicalTail)
                let promColor = InstitutionalTheme.Colors.Motors.prometheus

                Chart {
                    ForEach(chartData.history) { p in
                        LineMark(
                            x: .value("Tarih", p.date),
                            y: .value("Fiyat", p.price)
                        )
                        .foregroundStyle(InstitutionalTheme.Colors.textSecondary.opacity(0.85))
                    }

                    ForEach(chartData.future) { p in
                        LineMark(
                            x: .value("Tarih", p.date),
                            y: .value("Tahmin", p.price)
                        )
                        .foregroundStyle(promColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [6, 4]))
                    }

                    ForEach(chartData.futureBand) { p in
                        AreaMark(
                            x: .value("Tarih", p.date),
                            yStart: .value("Alt", p.lower),
                            yEnd: .value("Üst", p.upper)
                        )
                        .foregroundStyle(promColor.opacity(0.18))
                    }
                }
                .frame(height: 230)

                HStack(spacing: 10) {
                    legendDot(color: InstitutionalTheme.Colors.textSecondary, label: "GEÇMİŞ")
                    legendDot(color: InstitutionalTheme.Colors.Motors.prometheus, label: "TAHMİN")
                    legendDot(color: InstitutionalTheme.Colors.Motors.prometheus.opacity(0.5),
                              label: "GÜVEN ARALIĞI")
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                    Text("Grafik için tahmin verisi yok.")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }

    private var rationaleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("NEDEN BU KARAR?")

            if let f = forecast, !f.rationale.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(f.rationale.enumerated()), id: \.offset) { idx, line in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.Motors.prometheus)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(InstitutionalTheme.Colors.Motors.prometheus.opacity(0.16))
                                )
                            Text(line)
                                .font(.system(size: 11))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                    Text("Açıklama verisi hazır değil.")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private var loadingBlock: some View {
        VStack(spacing: 10) {
            ProgressView().tint(InstitutionalTheme.Colors.Motors.prometheus)
            Text("PROMETHEUS HESAPLANIYOR…")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.Motors.prometheus)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private var missingDataBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 18))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Tahmin için yeterli veri yok")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private func recommendationBadge(_ recommendation: PrometheusRecommendation) -> some View {
        let tone: ArgusChipTone
        switch recommendation {
        case .buy:  tone = .aurora
        case .sell: tone = .crimson
        case .hold: tone = .titan
        }
        return ArgusPill(recommendation.rawValue.uppercased(), tone: tone)
    }

    private func formatPrice(_ price: Double) -> String {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        let currency = isBist ? "₺" : "$"
        if price > 1000 { return String(format: "%@%.0f", currency, price) }
        if price > 1 { return String(format: "%@%.2f", currency, price) }
        return String(format: "%@%.4f", currency, price)
    }

    private func loadForecast() async {
        isLoading = true
        defer { isLoading = false }
        let newestFirst = Array(candles.map(\.close).reversed())
        forecast = await PrometheusEngine.shared.forecast(symbol: symbol, historicalPrices: newestFirst)
    }

    private func buildChartData(forecast: PrometheusForecast, history: [Candle]) -> PrometheusChartData {
        let historyPoints = history.map { PricePoint(date: $0.date, price: $0.close) }
        guard let lastDate = history.last?.date else {
            return PrometheusChartData(history: historyPoints, future: [], futureBand: [])
        }

        var future: [PricePoint] = []
        var futureBand: [BandPoint] = []

        for i in 0..<forecast.predictions.count {
            let date = nextTradingDate(from: lastDate, offset: i + 1)
            future.append(PricePoint(date: date, price: forecast.predictions[i]))
            if i < forecast.lowerBand.count && i < forecast.upperBand.count {
                futureBand.append(BandPoint(date: date, lower: forecast.lowerBand[i], upper: forecast.upperBand[i]))
            }
        }

        return PrometheusChartData(history: historyPoints, future: future, futureBand: futureBand)
    }

    private func nextTradingDate(from start: Date, offset: Int) -> Date {
        var date = start
        var advanced = 0
        let calendar = Calendar.current
        while advanced < offset {
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
            let weekday = calendar.component(.weekday, from: date)
            if weekday != 1 && weekday != 7 {
                advanced += 1
            }
        }
        return date
    }
}

private struct PrometheusChartData {
    let history: [PricePoint]
    let future: [PricePoint]
    let futureBand: [BandPoint]
}

private struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

private struct BandPoint: Identifiable {
    let id = UUID()
    let date: Date
    let lower: Double
    let upper: Double
}
