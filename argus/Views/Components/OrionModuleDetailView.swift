import SwiftUI

// MARK: - Orion Module Detail View (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Kullanıcı Motherboard'daki modül kartına (Momentum/Trend/Yapı/Formasyon)
// tıklayınca açılan full-bleed overlay. Eski: 6 hardcoded Color(red:green:blue:)
// literal (darkBg/cardBg/cyan/orange/green/red/purple), Color.white.opacity
// chain'leri, "LIVE ANALYSIS" ham başlık. Yeni: motor(.orion) tint sarmalı,
// surface1 kartlar, mono caps section caption, ArgusChip delta rozeti,
// ArgusHair ayırıcılar, alarm/paylaş action bar V5 chrome.

struct OrionModuleDetailView: View {
    let type: CircuitNode
    let symbol: String
    let analysis: OrionScoreResult
    let candles: [Candle]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 16) {
                        liveAnalysisCard

                        HStack(spacing: 8) {
                            MotorLogo(.orion, size: 14)
                            ArgusSectionCaption("TEKNİK GÖSTERGELER")
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        indicatorsSection

                        learningSection

                        Color.clear.frame(height: 100)
                    }
                    .padding(.vertical, 12)
                }
            }

            VStack {
                Spacer()
                bottomActionBar
            }
        }
    }

    // MARK: - Dynamic Content Switching

    @ViewBuilder
    private var indicatorsSection: some View {
        switch type {
        case .trend:
            technicalCard(
                title: "PRICE ACTION",
                subtitle: "Hareketli Ortalamalar",
                value: String(format: "%.2f", candles.last?.close ?? 0),
                delta: getPriceChangeText(),
                deltaTone: priceDeltaTone,
                chartTone: .motor(.orion)
            ) {
                maChart
            }

            technicalCard(
                title: "GÖRECELİ GÜÇ ENDEKSİ",
                subtitle: "RSI (14)",
                value: "Momentum",
                delta: "14P",
                deltaTone: .motor(.orion),
                chartTone: .motor(.orion)
            ) {
                rsiChart
            }

        case .momentum:
            technicalCard(
                title: "MOMENTUM",
                subtitle: "RSI & Velocity",
                value: String(format: "%.0f", analysis.components.momentum),
                delta: "/ 25",
                deltaTone: .motor(.orion),
                chartTone: .motor(.orion)
            ) {
                rsiChart
            }

        case .structure:
            technicalCard(
                title: "YAPI ANALİZİ",
                subtitle: "Kanal & Hacim",
                value: String(format: "%.0f", analysis.components.structure),
                delta: "/ 35",
                deltaTone: .motor(.orion),
                chartTone: .aurora
            ) {
                volumeChart
            }

        case .pattern:
            technicalCard(
                title: "FORMASYON",
                subtitle: analysis.components.patternDesc.isEmpty
                    ? "Tespit Edilemedi"
                    : "Grafik Formasyonu",
                value: analysis.components.patternDesc,
                delta: "",
                deltaTone: .crimson,
                chartTone: .crimson
            ) {
                patternSketch
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Live Analysis Card

    private var liveAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ArgusDot(color: InstitutionalTheme.Colors.Motors.orion)
                ArgusSectionCaption("CANLI ANALİZ")
                Spacer()
                ArgusChip(symbol.uppercased(), tone: .motor(.orion))
            }

            let dynamicText = getDynamicText()

            dynamicText.segments
                .reduce(Text("")) { result, segment in
                    result + Text(segment.text)
                        .foregroundColor(segment.color)
                        .fontWeight(segment.isBold ? .bold : .regular)
                }
                .font(.system(size: 13.5, design: .monospaced))
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.orion.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Technical Card Builder (V5)

    private func technicalCard<Content: View>(
        title: String,
        subtitle: String,
        value: String,
        delta: String,
        deltaTone: ArgusChipTone,
        chartTone: ArgusChipTone,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(chartTone.foreground)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .monospacedDigit()
                    if !delta.isEmpty {
                        ArgusChip(delta, tone: deltaTone)
                    }
                }
            }

            ArgusHair()

            content()
                .frame(height: 110)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(chartTone.foreground.opacity(0.28), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Charts (V5 tinted)

    private var rsiChart: some View {
        GeometryReader { geo in
            let prices = candles.suffix(50).map { $0.close }
            if prices.isEmpty {
                emptyChartLabel("Veri yok")
            } else {
                let rsiData = OrionChartHelpers.calculateRSI(period: 14, prices: prices)
                let normalized = OrionChartHelpers.normalize(rsiData)

                ZStack {
                    VStack(spacing: 0) {
                        InstitutionalTheme.Colors.crimson.opacity(0.08)
                            .frame(height: geo.size.height * 0.3)
                        Color.clear.frame(height: geo.size.height * 0.4)
                        InstitutionalTheme.Colors.aurora.opacity(0.08)
                            .frame(height: geo.size.height * 0.3)
                    }

                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        guard normalized.count > 1 else { return }
                        let step = width / CGFloat(normalized.count - 1)
                        for (index, value) in normalized.enumerated() {
                            if value.isNaN || value.isInfinite { continue }
                            let x = CGFloat(index) * step
                            let y = height - (CGFloat(value) * height)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(InstitutionalTheme.Colors.Motors.orion,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private var maChart: some View {
        GeometryReader { geo in
            let prices = candles.suffix(50).map { $0.close }
            if prices.isEmpty {
                emptyChartLabel("Veri yok")
            } else {
                let normPrices = OrionChartHelpers.normalize(prices)
                let sma = OrionChartHelpers.calculateSMA(period: 10, prices: prices)
                let normSMA = OrionChartHelpers.normalize(sma)

                ZStack {
                    pathShape(values: normPrices, in: geo.size)
                        .stroke(InstitutionalTheme.Colors.textPrimary,
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

                    pathShape(values: normSMA, in: geo.size)
                        .stroke(InstitutionalTheme.Colors.titan,
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
    }

    private func pathShape(values: [Double], in size: CGSize) -> Path {
        Path { path in
            let step = size.width / CGFloat(max(values.count - 1, 1))
            for (index, value) in values.enumerated() {
                if value.isNaN || value.isInfinite { continue }
                let x = CGFloat(index) * step
                let y = size.height - (CGFloat(value) * size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private var volumeChart: some View {
        GeometryReader { geo in
            let lastCandles = Array(candles.suffix(50))
            let volumes = lastCandles.map { Double($0.volume) }

            if volumes.isEmpty {
                emptyChartLabel("Hacim verisi yok")
            } else {
                let maxVol = max(volumes.max() ?? 1.0, 1.0)
                let width = geo.size.width
                let count = CGFloat(volumes.count)
                let step = width / count
                let height = geo.size.height

                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(0..<lastCandles.count, id: \.self) { i in
                        let vol = volumes[i]
                        let barH = (vol / maxVol) * Double(height)
                        let safeBarH = barH.isNaN ? 0 : CGFloat(max(barH, 1.0))
                        Rectangle()
                            .fill(lastCandles[i].close >= lastCandles[i].open
                                  ? InstitutionalTheme.Colors.aurora
                                  : InstitutionalTheme.Colors.crimson)
                            .frame(width: max(step - 1, 1), height: safeBarH)
                    }
                }
            }
        }
    }

    private var patternSketch: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let initial = analysis.components.patternDesc.isEmpty
                ? "—"
                : String(analysis.components.patternDesc.prefix(1))

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.8))
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.2),
                        control1: CGPoint(x: w * 0.4, y: h * 0.1),
                        control2: CGPoint(x: w * 0.6, y: h * 0.9)
                    )
                }
                .stroke(InstitutionalTheme.Colors.crimson,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))

                Text(initial.uppercased())
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.08))
                    .position(x: w / 2, y: h / 2)
            }
        }
    }

    private func emptyChartLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm,
                                         style: .continuous)
                            .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm,
                                         style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                ArgusSectionCaption("DETAY ANALİZİ")
                Text(type.title.uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }

            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.Motors.orion)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(ArgusHair(), alignment: .bottom)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("ALARM KUR")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(0.6)
                }
                .foregroundColor(InstitutionalTheme.Colors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(InstitutionalTheme.Colors.Motors.orion)
                .clipShape(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md,
                                     style: .continuous)
                )
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(width: 46, height: 46)
                    .background(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md,
                                         style: .continuous)
                            .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md,
                                         style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(InstitutionalTheme.Colors.background.opacity(0.96))
        .overlay(ArgusHair(), alignment: .top)
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        DisclosureGroup {
            Text(type.educationalContent(for: analysis))
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.titan)
                ArgusSectionCaption("ÖĞREN · \(type.title.uppercased()) NEDİR?")
                Spacer()
            }
        }
        .accentColor(InstitutionalTheme.Colors.textPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.titan.opacity(0.22), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func getDynamicText() -> DynamicAnalysisText {
        switch type {
        case .trend:     return OrionTextGenerator.generateTrendText(for: analysis)
        case .momentum:  return OrionTextGenerator.generateMomentumText(for: analysis)
        case .structure: return OrionTextGenerator.generateStructureText(for: analysis)
        case .pattern:   return OrionTextGenerator.generatePatternText(for: analysis)
        default:         return DynamicAnalysisText(segments: [])
        }
    }

    private func getPriceChangeText() -> String {
        guard let last = candles.last,
              let prev = candles.dropLast().last else { return "0%" }
        let diff = (last.close - prev.close) / prev.close * 100
        return String(format: "%+.2f%%", diff)
    }

    private var priceDeltaTone: ArgusChipTone {
        guard let last = candles.last,
              let prev = candles.dropLast().last else { return .titan }
        if last.close > prev.close { return .aurora }
        if last.close < prev.close { return .crimson }
        return .titan
    }
}
