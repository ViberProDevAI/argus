import SwiftUI

// MARK: - Prometheus Forecast Card (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Orion modülü içinde, `orionAnalysis` yoksa gösterilen 5-günlük
// fiyat projeksiyonu. Eski: `.orange / .green / .red / .gray` literals,
// `Color(hex: "1C1C1E")` dolgu, `LinearGradient(.white, trend)` çizgi,
// `DesignTokens.Opacity.glassCard`.
// Yeni: motor(.prometheus) tint, mono caps caption, tek renk motor-tint
// mini chart, `ArgusBar` güven metresi, `ArgusChip` yön/güven rozetleri.
struct ForecastCard: View {
    let symbol: String
    let historicalPrices: [Double]

    @State private var forecast: PrometheusForecast?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingBlock
            } else if let forecast = forecast, forecast.isValid {
                priceRow(forecast)
                trendBadge(forecast)
                ArgusHair()
                ForecastMiniChart(
                    currentPrice: forecast.currentPrice,
                    predictions: forecast.predictions,
                    trend: forecast.trend
                )
                .frame(height: 60)
                confidenceRow(forecast)
                insightRow(forecast)
                footerLine
            } else {
                insufficientBlock
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.prometheus.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
        .task { await loadForecast() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.prometheus, size: 14)
            ArgusSectionCaption("PROMETHEUS · PROJEKSİYON")
            Spacer()
            ArgusChip("UFUK · \(forecast?.horizonDays ?? 5)G", tone: .motor(.prometheus))
        }
    }

    private func priceRow(_ f: PrometheusForecast) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ŞİMDİ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(formatPrice(f.currentPrice))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }

            Spacer()

            Image(systemName: f.trend.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(trendTone(f.trend).foreground)
                .padding(8)
                .background(
                    Circle().fill(trendTone(f.trend).background)
                )

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(f.horizonDays) GÜN SONRA")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(formatPrice(f.predictedPrice))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(trendTone(f.trend).foreground)
            }
        }
    }

    private func trendBadge(_ f: PrometheusForecast) -> some View {
        HStack(spacing: 8) {
            ArgusChip(f.formattedChange, tone: trendTone(f.trend))
            Text(f.trend.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(trendTone(f.trend).foreground)
        }
    }

    private func confidenceRow(_ f: PrometheusForecast) -> some View {
        HStack(spacing: 10) {
            Text("GÜVEN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .frame(width: 50, alignment: .leading)

            ArgusBar(value: max(0, min(1, f.confidence / 100)),
                     color: confidenceTone(f.confidence).foreground,
                     height: 4)

            Text("%\(Int(f.confidence))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 40, alignment: .trailing)

            Text(f.confidenceLevel.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(confidenceTone(f.confidence).foreground)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func insightRow(_ f: PrometheusForecast) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ArgusDot(color: InstitutionalTheme.Colors.Motors.prometheus)
                .padding(.top, 5)
            Text(generateInsight(trend: f.trend, confidence: f.confidence))
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerLine: some View {
        Text("HOLT-WINTERS EXPONENTIAL SMOOTHING")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var loadingBlock: some View {
        VStack(spacing: 8) {
            ProgressView().tint(InstitutionalTheme.Colors.Motors.prometheus)
            Text("PROMETHEUS HESAPLANIYOR…")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.Motors.prometheus)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var insufficientBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 18))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Yeterli veri yok")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("En az 30 günlük fiyat gerekli")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Helpers (tone mapping)

    private func trendTone(_ trend: PrometheusTrend) -> ArgusChipTone {
        switch trend {
        case .strongBullish, .bullish: return .aurora
        case .neutral:                 return .titan
        case .bearish, .strongBearish: return .crimson
        }
    }

    private func confidenceTone(_ c: Double) -> ArgusChipTone {
        if c >= 70 { return .aurora }
        if c >= 50 { return .motor(.prometheus) }
        if c >= 30 { return .titan }
        return .crimson
    }

    private func loadForecast() async {
        isLoading = true
        // Engine oldest-first istiyor; ForecastCard prop'u zaten kronolojik (oldest-first).
        forecast = await PrometheusEngine.shared.forecast(
            symbol: symbol,
            historicalPrices: historicalPrices
        )
        isLoading = false
    }

    private func formatPrice(_ price: Double) -> String {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        let currency = isBist ? "₺" : "$"

        if price > 1000 {
            return String(format: "%@%.0f", currency, price)
        } else if price > 1 {
            return String(format: "%@%.2f", currency, price)
        } else {
            return String(format: "%@%.4f", currency, price)
        }
    }

    private func generateInsight(trend: PrometheusTrend, confidence: Double) -> String {
        // Şartlı dil: model son trendi sönümlü olarak uzatıyor; "kesinlikle olacak" iddiası yok.
        let qualifier = confidence < 50 ? " Güven düşük; tek başına işlem sinyali olarak kullanılmamalı." : ""
        switch trend {
        case .strongBullish:
            return "Mevcut trend devam ederse ufuk sonunda yukarı yönlü projeksiyon güçlü." + qualifier
        case .bullish:
            return "Son trendin sönümlü uzantısı yukarı yönlü; kısa vadeli geri çekilmeler bu projeksiyonu doğrudan değiştirmez." + qualifier
        case .neutral:
            return "Belirgin bir yön yok. Projeksiyon mevcut seviyenin etrafında kalıyor." + qualifier
        case .bearish:
            return "Son trendin sönümlü uzantısı aşağı yönlü." + qualifier
        case .strongBearish:
            return "Mevcut serinin lineer projeksiyonu belirgin aşağı yönlü; bant genişliği riski büyütüyor." + qualifier
        }
    }
}

// MARK: - Forecast Mini Chart (V5)
//
// Tek renk motor(.prometheus) çizgi. Dashed değil — solid ama ince.
// Current nokta textPrimary, future noktalar motor tint.

struct ForecastMiniChart: View {
    let currentPrice: Double
    let predictions: [Double]
    let trend: PrometheusTrend

    var body: some View {
        GeometryReader { geo in
            let allPrices = [currentPrice] + predictions
            let minPrice = allPrices.min() ?? 0
            let maxPrice = allPrices.max() ?? 1
            let range = max(maxPrice - minPrice, 0.01)

            Path { path in
                for (index, price) in allPrices.enumerated() {
                    let x = (geo.size.width / CGFloat(allPrices.count - 1)) * CGFloat(index)
                    let y = geo.size.height - ((price - minPrice) / range * geo.size.height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(trendColor,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            ForEach(0..<allPrices.count, id: \.self) { index in
                let x = (geo.size.width / CGFloat(allPrices.count - 1)) * CGFloat(index)
                let price = allPrices[index]
                let y = geo.size.height - ((price - minPrice) / range * geo.size.height)

                Circle()
                    .fill(index == 0
                          ? InstitutionalTheme.Colors.textPrimary
                          : trendColor)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
    }

    private var trendColor: Color {
        switch trend {
        case .strongBullish, .bullish: return InstitutionalTheme.Colors.aurora
        case .neutral:                 return InstitutionalTheme.Colors.Motors.prometheus
        case .bearish, .strongBearish: return InstitutionalTheme.Colors.crimson
        }
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.background.ignoresSafeArea()
        ForecastCard(
            symbol: "AAPL",
            historicalPrices: Array(stride(from: 180.0, through: 195.0, by: 0.5))
        )
        .padding()
    }
}
