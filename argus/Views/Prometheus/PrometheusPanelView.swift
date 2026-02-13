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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryCard
                continuationChartCard
                rationaleCard
            }
            .padding(16)
        }
        .task {
            await loadForecast()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "crystal.ball")
                .font(.title2)
                .foregroundColor(SanctumTheme.hologramBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("PROMETHEUS")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("Bilimsel Zaman Cizgisi ve Karar Mantigi")
                    .font(.caption)
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
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        recommendationBadge(f.recommendation)
                        Spacer()
                        Text("Ufuk: \(f.horizonDays)g")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    HStack(spacing: 16) {
                        metric("Simdi", value: formatPrice(f.currentPrice))
                        metric("Tahmin", value: formatPrice(f.predictedPrice))
                        metric("Degisim", value: f.formattedChange)
                        metric("Guven", value: "\(Int(f.confidence))%")
                    }

                    HStack(spacing: 16) {
                        metric("MAPE", value: String(format: "%.2f%%", f.validationMAPE))
                        metric("Yon Isabet", value: String(format: "%.1f%%", f.directionalAccuracy * 100))
                        metric("Veri", value: "\(f.dataPointsUsed) bar")
                    }
                }
            } else {
                missingDataBlock
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var continuationChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fiyat Devam Grafigi")
                .font(.subheadline.bold())
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            if let f = forecast, f.isValid, !historicalTail.isEmpty {
                let chartData = buildChartData(forecast: f, history: historicalTail)

                Chart {
                    ForEach(chartData.history) { p in
                        LineMark(
                            x: .value("Tarih", p.date),
                            y: .value("Fiyat", p.price)
                        )
                        .foregroundStyle(InstitutionalTheme.Colors.textSecondary.opacity(0.9))
                    }

                    ForEach(chartData.future) { p in
                        LineMark(
                            x: .value("Tarih", p.date),
                            y: .value("Tahmin", p.price)
                        )
                        .foregroundStyle(SanctumTheme.hologramBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [6, 4]))
                    }

                    ForEach(chartData.futureBand) { p in
                        AreaMark(
                            x: .value("Tarih", p.date),
                            yStart: .value("Alt", p.lower),
                            yEnd: .value("Ust", p.upper)
                        )
                        .foregroundStyle(SanctumTheme.hologramBlue.opacity(0.16))
                    }
                }
                .frame(height: 230)
            } else {
                Text("Grafik icin tahmin verisi yok.")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var rationaleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Neden Bu Karar?")
                .font(.subheadline.bold())
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            if let f = forecast, !f.rationale.isEmpty {
                ForEach(Array(f.rationale.enumerated()), id: \.offset) { idx, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.caption.bold())
                            .foregroundColor(SanctumTheme.hologramBlue)
                        Text(line)
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Aciklama verisi hazir degil.")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var loadingBlock: some View {
        VStack(spacing: 8) {
            ProgressView().tint(SanctumTheme.hologramBlue)
            Text("Prometheus hesaplama yapiyor...")
                .font(.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private var missingDataBlock: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("Tahmin icin yeterli veri yok")
                .font(.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
        }
    }

    private func recommendationBadge(_ recommendation: PrometheusRecommendation) -> some View {
        let color: Color
        switch recommendation {
        case .buy: color = SanctumTheme.auroraGreen
        case .sell: color = SanctumTheme.crimsonRed
        case .hold: color = SanctumTheme.titanGold
        }

        return HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
            Text(recommendation.rawValue)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
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
