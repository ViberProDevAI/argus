import SwiftUI

/// Prometheus: 5-Day Forecast Card
/// Displays price predictions using Holt-Winters algorithm
struct ForecastCard: View {
    let symbol: String
    let historicalPrices: [Double]
    
    @State private var forecast: PrometheusForecast?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.orange)
                Text("PROMETHEUS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Text("\(forecast?.horizonDays ?? 5) Günlük Tahmin")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .frame(height: 120)
            } else if let forecast = forecast, forecast.isValid {
                // Main Prediction Display
                VStack(spacing: 12) {
                    // Current vs Predicted
                    HStack(spacing: 30) {
                        // Current Price
                        VStack(spacing: 4) {
                            Text("ŞİMDİ")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.gray)
                            Text(formatPrice(forecast.currentPrice))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // Arrow
                        Image(systemName: forecast.trend.icon)
                            .font(.title2)
                            .foregroundColor(trendColor(forecast.trend))
                        
                        // Predicted Price
                        VStack(spacing: 4) {
                            Text("\(forecast.horizonDays) GÜN SONRA")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.gray)
                            Text(formatPrice(forecast.predictedPrice))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(trendColor(forecast.trend))
                        }
                    }
                    
                    // Change Badge
                    HStack {
                        Text(forecast.formattedChange)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(trendColor(forecast.trend))
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(forecast.trend.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(trendColor(forecast.trend))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(trendColor(forecast.trend).opacity(DesignTokens.Opacity.glassCard))
                    )
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Mini Forecast Chart
                    ForecastMiniChart(
                        currentPrice: forecast.currentPrice,
                        predictions: forecast.predictions,
                        trend: forecast.trend
                    )
                    .frame(height: 60)
                    
                    // Confidence Meter
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(.gray)
                        Text("Güven:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        ConfidenceMeter(confidence: forecast.confidence)
                        
                        Text("\(forecast.confidenceLevel)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(confidenceColor(forecast.confidence))
                    }
                    
                    // NEW: Insight Text
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                        
                        Text(generateInsight(trend: forecast.trend, confidence: forecast.confidence))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Algorithm Footer
                    Text("Powered by Holt-Winters Exponential Smoothing")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                // Insufficient Data
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.orange.opacity(0.5))
                    Text("Yeterli veri yok")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("En az 30 günlük fiyat gerekli")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(height: 120)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .task {
            await loadForecast()
        }
    }
    
    private func loadForecast() async {
        isLoading = true
        forecast = await PrometheusEngine.shared.forecast(
            symbol: symbol,
            historicalPrices: Array(historicalPrices.reversed())
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
    
    // NEW: Insight Generator
    private func generateInsight(trend: PrometheusTrend, confidence: Double) -> String {
        switch trend {
        case .strongBullish:
            return "Fiyatın önümüzdeki 5 gün içinde sert yükseliş ivmesini koruması bekleniyor. Momentum güçlü."
        case .bullish:
            return "Yükseliş trendinin devamı öngörülüyor. Kısa vadeli geri çekilmeler alım fırsatı olabilir."
        case .neutral:
            return "Belirgin bir yön yok. Fiyatın mevcut aralıkta yatay seyretmesi bekleniyor."
        case .bearish:
            return "Zayıflama sinyalleri var. Fiyatın aşağı yönlü baskı altında kalması muhtemel."
        case .strongBearish:
            return "Keskin düşüş riski yüksek. Algoritma satış baskısının artacağını öngörüyor."
        }
    }
    
    private func trendColor(_ trend: PrometheusTrend) -> Color {
        switch trend {
        case .strongBullish, .bullish: return .green
        case .neutral: return .gray
        case .bearish, .strongBearish: return .red
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Supporting Views

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
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.5), trendColor],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            
            // Day markers
            ForEach(0..<allPrices.count, id: \.self) { index in
                let x = (geo.size.width / CGFloat(allPrices.count - 1)) * CGFloat(index)
                let price = allPrices[index]
                let y = geo.size.height - ((price - minPrice) / range * geo.size.height)
                
                Circle()
                    .fill(index == 0 ? Color.white : trendColor)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .strongBullish, .bullish: return .green
        case .neutral: return .gray
        case .bearish, .strongBearish: return .red
        }
    }
}

struct ConfidenceMeter: View {
    let confidence: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(meterColor)
                    .frame(width: geo.size.width * (confidence / 100))
            }
        }
        .frame(width: 60, height: 6)
    }
    
    private var meterColor: Color {
        switch confidence {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ForecastCard(
            symbol: "AAPL",
            historicalPrices: Array(stride(from: 180.0, through: 195.0, by: 0.5))
        )
        .padding()
    }
}
