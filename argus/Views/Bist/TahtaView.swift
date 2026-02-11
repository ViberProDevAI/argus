import SwiftUI

/// TAHTA: Birleşik Teknik Analiz Görünümü
/// OrionBist (SAR, TSI) + MoneyFlow (Hacim, A/D) + RelativeStrength (RS, Beta, Momentum)

struct TahtaView: View {
    let symbol: String

    @State private var result: TahtaResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEducation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let r = result {
                    // Ana Sinyal Kartı
                    mainSignalCard(r)

                    // Hızlı Göstergeler Grid
                    quickIndicatorsGrid(r)

                    // Endekse Göre Performans
                    if r.rsResult != nil {
                        relativePerformanceCard(r)
                    }

                    // Detaylı Metrikler (Expandable)
                    detailedMetricsSection(r)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { loadData() }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.cyan)

            Text("Teknik analiz yapılıyor...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("Tekrar Dene") {
                loadData()
            }
            .foregroundColor(.cyan)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Ana Sinyal Kartı

    private func mainSignalCard(_ r: TahtaResult) -> some View {
        VStack(spacing: 16) {
            // Üst: Başlık
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.cyan)
                Text("TAHTA")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Teknik Analiz")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(symbol)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
            }

            // Orta: Ana Sinyal
            HStack(spacing: 20) {
                // Sinyal Badge (Büyük)
                VStack(spacing: 8) {
                    Image(systemName: r.signal.icon)
                        .font(.system(size: 36))
                        .foregroundColor(signalColor(r.signal))

                    Text(r.signal.rawValue)
                        .font(.title2)
                        .bold()
                        .foregroundColor(signalColor(r.signal))
                }
                .frame(width: 100)

                // Skor ve Destek
                VStack(alignment: .leading, spacing: 12) {
                    // Güven Skoru
                    HStack {
                        Text("Güven:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("%\(Int(r.confidence))")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                    }

                    // Destek Sayısı
                    HStack {
                        Text("Destek:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(r.supportRatio)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(supportCountColor(r.supportCount, total: r.totalIndicators))
                        Text("gösterge")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Skor Gauge
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(signalColor(r.signal))
                                .frame(width: geo.size.width * (r.totalScore / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Alt: Özet
            Text(r.summary)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(signalColor(r.signal).opacity(0.1))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color(hex: "0A0A0F"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(signalColor(r.signal).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Hızlı Göstergeler Grid

    private func quickIndicatorsGrid(_ r: TahtaResult) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // SAR
            QuickIndicatorCell(
                icon: "arrow.triangle.swap",
                title: "SAR",
                value: r.orionResult.sarStatus.replacingOccurrences(of: "SAR ", with: ""),
                color: r.orionResult.sarStatus.contains("AL") ? .green : .red
            )

            // TSI
            QuickIndicatorCell(
                icon: "gauge.with.dots.needle.50percent",
                title: "TSI",
                value: String(format: "%+.0f", r.orionResult.tsiValue),
                color: r.orionResult.tsiValue > 0 ? .green : .red
            )

            // RSI
            QuickIndicatorCell(
                icon: "speedometer",
                title: "RSI",
                value: String(format: "%.0f", r.rsi),
                color: rsiColor(r.rsi)
            )

            // Para Akışı
            if let mf = r.moneyFlowResult {
                QuickIndicatorCell(
                    icon: mf.flowStatus.icon,
                    title: "AKIM",
                    value: flowStatusShort(mf.flowStatus),
                    color: flowColor(mf.flowStatus)
                )
            } else {
                QuickIndicatorCell(
                    icon: "arrow.left.arrow.right",
                    title: "AKIM",
                    value: "N/A",
                    color: .gray
                )
            }
        }
    }

    // MARK: - Rölatif Performans Kartı

    private func relativePerformanceCard(_ r: TahtaResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Endekse Göre (XU100)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)

                Spacer()

                if let rs = r.rsResult {
                    Text(rs.statusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(rsStatusColor(rs.status).opacity(0.2))
                        .foregroundColor(rsStatusColor(rs.status))
                        .cornerRadius(6)
                }
            }

            if let rs = r.rsResult {
                HStack(spacing: 16) {
                    // RS
                    VStack(spacing: 4) {
                        Text("RS")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", rs.relativeStrength))
                            .font(.headline)
                            .bold()
                            .foregroundColor(rs.relativeStrength > 1.0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)

                    // Beta
                    VStack(spacing: 4) {
                        Text("Beta")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", rs.beta))
                            .font(.headline)
                            .bold()
                            .foregroundColor(rs.beta < 1.0 ? .blue : .orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)

                    // Momentum
                    VStack(spacing: 4) {
                        Text("Mom.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%+.1f%%", rs.momentum))
                            .font(.headline)
                            .bold()
                            .foregroundColor(rs.momentum > 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "0A0A0F"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Detaylı Metrikler

    private func detailedMetricsSection(_ r: TahtaResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring()) { showEducation.toggle() } }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.cyan)
                    Text("Formüller & Eğitim")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: showEducation ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showEducation {
                VStack(spacing: 0) {
                    ForEach(r.metrics) { metric in
                        TahtaMetricRow(metric: metric)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(hex: "0A0A0F"))
        .cornerRadius(16)
    }

    // MARK: - Data Loading

    private func loadData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await TahtaEngine.shared.analyze(symbol: symbol)
                await MainActor.run {
                    self.result = data
                    self.isLoading = false
                }
            } catch TahtaEngine.TahtaError.insufficientData {
                await MainActor.run {
                    self.errorMessage = "Yetersiz veri. En az 30 günlük tarihsel veri gerekli."
                    self.isLoading = false
                }
            } catch TahtaEngine.TahtaError.dataUnavailable {
                await MainActor.run {
                    self.errorMessage = "Veri kaynağına ulaşılamıyor."
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Analiz hatası: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func signalColor(_ signal: TahtaSignal) -> Color {
        switch signal {
        case .gucluAl: return .green
        case .al: return Color(red: 0.4, green: 0.9, blue: 0.7) // mint
        case .tut: return .yellow
        case .sat: return .orange
        case .gucluSat: return .red
        }
    }

    private func supportCountColor(_ count: Int, total: Int) -> Color {
        let ratio = Double(count) / Double(max(1, total))
        if ratio >= 0.7 { return .green }
        if ratio >= 0.4 { return .yellow }
        return .red
    }

    private func rsiColor(_ rsi: Double) -> Color {
        if rsi > 70 { return .red }
        if rsi < 30 { return .green }
        return .yellow
    }

    private func flowStatusShort(_ status: FlowStatus) -> String {
        switch status {
        case .strongInflow: return "G++"
        case .inflow: return "GİR"
        case .neutral: return "NÖTR"
        case .outflow: return "ÇIK"
        case .strongOutflow: return "Ç--"
        }
    }

    private func flowColor(_ status: FlowStatus) -> Color {
        switch status {
        case .strongInflow: return .green
        case .inflow: return Color(red: 0.4, green: 0.9, blue: 0.7)
        case .neutral: return .yellow
        case .outflow: return .orange
        case .strongOutflow: return .red
        }
    }

    private func rsStatusColor(_ status: RSStatus) -> Color {
        switch status {
        case .outperforming: return .green
        case .stable: return .blue
        case .neutral: return .yellow
        case .underperforming: return .red
        }
    }
}

// MARK: - Quick Indicator Cell

struct QuickIndicatorCell: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Tahta Metric Row

struct TahtaMetricRow: View {
    let metric: TahtaMetric
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.snappy) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.caption)
                        .foregroundColor(metricColor)
                        .frame(width: 20)

                    Text(metric.name)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(metric.value)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(metricColor)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.8))
                        .offset(y: 2)

                    Text(metric.education)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().background(Color.white.opacity(0.1))
        }
    }

    private var metricColor: Color {
        switch metric.color {
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "orange": return .orange
        case "blue": return .blue
        case "mint": return Color(red: 0.4, green: 0.9, blue: 0.7)
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    TahtaView(symbol: "THYAO")
}
