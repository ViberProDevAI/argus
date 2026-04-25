import SwiftUI

// MARK: - ORION MOTHERBOARD VIEW (V5.H-11 · Reaktif Grafik Hero)
//
// **2026-04-23 V5.H-11 yeniden yazım.** Eski yapı: timeframe segment +
// provenance panel + score chips + CPU ring + 2x2 grid 4 kart + advice.
// Toplam 624 satır, görsel olarak yoğun ve kalabalıktı.
//
// Yeni tasarım (Yön D onayı):
//   1. Minimal header (sembol + timeframe tabs)
//   2. Kompakt skor barı (52pt ring + AL chip + güven metni)
//   3. HERO grafik — InteractiveCandleChart dominant
//   4. 4 bileşen satırı — tek sütun, kompakt pill stili (MOM/TRD/YPI/FRM)
//   5. Orion tavsiyesi — tek cümle
//
// Reaktif: timeframe değişince `analysis.scoreFor(timeframe:)` her şeyi
// yeniler — skor, 4 bileşen, tavsiye. Mum grafiği `viewModel.candles`
// üzerinden `changeTimeframe(to:)` ile yenilenir.
//
// Public API korundu — `OrionMotherboardView(analysis:, symbol:, viewModel:)`
// çağrı siteleri değişmiyor.
//
// Provenance paneli (fallback durumu) küçük bir uyarı şeridine indirildi —
// skor barı altında ince bir satır. Timeframe score chips kaldırıldı
// (timeframe tab'ı seçime yetiyor).
//
// Kart tıklama → `OrionModuleDetailView` overlay (korundu).

struct OrionMotherboardView: View {
    let analysis: MultiTimeframeAnalysis
    let symbol: String

    @ObservedObject var viewModel: SanctumViewModel

    @State private var selectedTimeframe: TimeframeMode = .daily
    @State private var selectedNode: CircuitNode? = nil

    private let orionTint = InstitutionalTheme.Colors.Motors.orion

    /// Aktif timeframe'in Orion skoru.
    var currentOrion: OrionScoreResult {
        analysis.scoreFor(timeframe: selectedTimeframe)
    }

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                minimalHeader
                timeframeSegment
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 14) {
                        scoreBar
                        fallbackNoteIfNeeded
                        chartHero
                        componentRows
                        adviceBar
                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            if let node = selectedNode {
                OrionModuleDetailView(
                    type: node,
                    symbol: symbol,
                    analysis: currentOrion,
                    candles: viewModel.candles,
                    onClose: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedNode = nil
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }
        }
        .onAppear {
            selectedTimeframe = viewModel.selectedTimeframe
            viewModel.orionScore = analysis.scoreFor(timeframe: selectedTimeframe)
        }
    }

    // MARK: - Minimal Header

    private var minimalHeader: some View {
        HStack(spacing: 10) {
            MotorLogo(.orion, size: 14)
            VStack(alignment: .leading, spacing: 2) {
                ArgusSectionCaption("ORION · TEKNİK ANALİZ")
                Text(symbol.uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Timeframe Segment (reaktif — dokunulduğunda skor + grafik + bileşenler yenilenir)

    private var timeframeSegment: some View {
        HStack(spacing: 3) {
            ForEach(TimeframeMode.allCases, id: \.rawValue) { mode in
                timeframeTab(mode)
            }
        }
        .padding(3)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
    }

    private func timeframeTab(_ mode: TimeframeMode) -> some View {
        let isSelected = selectedTimeframe == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeframe = mode
            }
            Task { await viewModel.changeTimeframe(to: mode) }
        } label: {
            Text(mode.displayLabel.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(
                    isSelected ? orionTint : InstitutionalTheme.Colors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? orionTint.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kompakt Skor Barı

    /// Sol: 52pt skor ring. Sağ: KONSENSÜS caption + AL/TUT/SAT chip +
    /// güven metni. Tap → CPU node detail overlay.
    private var scoreBar: some View {
        Button {
            withAnimation { selectedNode = .cpu }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(orionTint.opacity(0.15), lineWidth: 4)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, currentOrion.score)) / 100.0))
                        .stroke(verdictTone.foreground,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: currentOrion.score)
                        .frame(width: 52, height: 52)
                    Text(String(format: "%.0f", currentOrion.score))
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("KONSENSÜS · \(selectedTimeframe.displayLabel.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundColor(orionTint)
                    HStack(spacing: 8) {
                        ArgusChip(verdictText, tone: verdictTone)
                        Text(confidenceText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(orionTint.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .stroke(orionTint.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var confidenceText: String {
        // Güven metni — skordan basit türetim (servis güven skoru yoksa).
        let c = max(50, min(95, 50 + Int(currentOrion.score) / 2))
        return "güven %\(c)"
    }

    // MARK: - Fallback uyarı şeridi (sadece gerektiğinde)

    @ViewBuilder
    private var fallbackNoteIfNeeded: some View {
        if analysis.isFallback(timeframe: selectedTimeframe) {
            let source = analysis.sourceFor(timeframe: selectedTimeframe)
            HStack(spacing: 8) {
                ArgusDot(color: InstitutionalTheme.Colors.titan, size: 6)
                Text("\(selectedTimeframe.displayLabel) skoru \(source.displayLabel) verisinden türetildi.")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.titan)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(InstitutionalTheme.Colors.titan.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.titan.opacity(0.2), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
        }
    }

    // MARK: - HERO Grafik

    private var chartHero: some View {
        ZStack {
            if !viewModel.candles.isEmpty {
                InteractiveCandleChart(
                    candles: viewModel.candles,
                    trades: nil,
                    showSMA: true,
                    showBollinger: false,
                    showIchimoku: false,
                    showMACD: false,
                    showVolume: true,
                    showRSI: false,
                    showStochastic: false,
                    showSAR: false,
                    showTSI: false
                )
                .frame(height: 280)
                .opacity(viewModel.isCandlesLoading ? 0.3 : 1.0)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 22))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Grafik verisi yükleniyor…")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .frame(height: 280)
            }

            if viewModel.isCandlesLoading {
                VStack(spacing: 8) {
                    ProgressView().tint(orionTint)
                    Text("\(selectedTimeframe.displayLabel.uppercased()) YÜKLENİYOR…")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(orionTint)
                }
                .padding(14)
                .background(InstitutionalTheme.Colors.surface1.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                        .stroke(orionTint.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
            }
        }
        .padding(8)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - 4 Bileşen Satırı (kompakt pill stili)

    private var componentRows: some View {
        VStack(spacing: 6) {
            momentumRow
            trendRow
            structureRow
            patternRow
        }
    }

    private var momentumRow: some View {
        let rsi = currentOrion.components.rsi ?? (currentOrion.components.momentum * 4)
        let (status, tone): (String, ArgusChipTone) = {
            if rsi > 70 { return ("aşırı alım", .crimson) }
            if rsi < 30 { return ("aşırı satım", .crimson) }
            if rsi > 55 { return ("güçlü", .aurora) }
            if rsi < 45 { return ("zayıf", .titan) }
            return ("nötr", .motor(.orion))
        }()

        return componentRow(
            node: .momentum,
            code: "MOM",
            title: "MOMENTUM",
            valueText: String(format: "%.0f", rsi),
            statusText: status,
            tone: tone,
            barRatio: max(0, min(1, rsi / 100))
        )
    }

    private var trendRow: some View {
        let adx = currentOrion.components.trendStrength ?? (currentOrion.components.trend * 2)
        let (status, tone): (String, ArgusChipTone) = {
            if adx >= 25 { return ("yerleşik", .aurora) }
            if adx >= 15 { return ("zayıf trend", .titan) }
            return ("yatay", .neutral)
        }()

        return componentRow(
            node: .trend,
            code: "TRD",
            title: "TREND",
            valueText: String(format: "%.0f", adx),
            statusText: status,
            tone: tone,
            barRatio: max(0, min(1, adx / 50))
        )
    }

    private var structureRow: some View {
        let s = max(0, min(currentOrion.components.structure, 35))
        let pos = s / 35.0
        let (status, tone): (String, ArgusChipTone) = {
            if pos > 0.8 { return ("dirence yakın", .crimson) }
            if pos < 0.2 { return ("desteğe yakın", .aurora) }
            if pos >= 0.55 { return ("sağlam", .aurora) }
            return ("kanal içi", .motor(.orion))
        }()

        return componentRow(
            node: .structure,
            code: "YPI",
            title: "YAPI",
            valueText: "\(Int(s))/35",
            statusText: status,
            tone: tone,
            barRatio: pos
        )
    }

    private var patternRow: some View {
        let desc = currentOrion.components.patternDesc
        let isEmpty = desc.isEmpty || desc == "Yok"
        let status = isEmpty ? "tespit yok" : desc.lowercased()
        let tone: ArgusChipTone = isEmpty ? .neutral : .aurora

        return componentRow(
            node: .pattern,
            code: "FRM",
            title: "FORMASYON",
            valueText: "",
            statusText: status,
            tone: tone,
            barRatio: isEmpty ? 0 : 1
        )
    }

    /// Tek satır bileşen kartı — 26pt kod rozeti + isim + skor + durum +
    /// altta ince bar. Tıklanınca detay overlay açılır.
    private func componentRow(
        node: CircuitNode,
        code: String,
        title: String,
        valueText: String,
        statusText: String,
        tone: ArgusChipTone,
        barRatio: Double
    ) -> some View {
        Button {
            withAnimation { selectedNode = node }
        } label: {
            HStack(spacing: 10) {
                // Kod rozeti
                Text(code)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(tone.foreground)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(tone.background)
                    )
                    .overlay(
                        Circle().stroke(tone.foreground.opacity(0.35), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        if !valueText.isEmpty {
                            Text(valueText)
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .monospacedDigit()
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                        Text(statusText)
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(tone.foreground)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    ArgusBar(value: barRatio, color: tone.foreground, height: 3)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.background.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(tone.foreground.opacity(0.25), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tavsiye Barı

    private var adviceBar: some View {
        HStack(alignment: .top, spacing: 10) {
            ArgusDot(color: orionTint)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text("ORION · \(selectedTimeframe.displayLabel.uppercased()) TAVSİYESİ")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundColor(orionTint)
                Text(analysis.strategicAdvice)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(orionTint.opacity(0.06))
        .overlay(
            Rectangle()
                .fill(orionTint)
                .frame(width: 2)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Verdict helpers

    private var verdictText: String {
        if currentOrion.score >= 55 { return "AL" }
        if currentOrion.score >= 45 { return "TUT" }
        return "SAT"
    }

    private var verdictTone: ArgusChipTone {
        if currentOrion.score >= 55 { return .aurora }
        if currentOrion.score >= 45 { return .titan }
        return .crimson
    }
}
