import SwiftUI

// MARK: - ORION MOTHERBOARD VIEW (Pyramid Layout)
// Redesigned: Consensus Top, 4 Modules Bottom (Momentum, Trend, Structure, Pattern)

struct OrionMotherboardView: View {
    let analysis: MultiTimeframeAnalysis
    let symbol: String

    // ViewModel for reactive candle updates
    @ObservedObject var viewModel: SanctumViewModel

    @State private var selectedTimeframe: TimeframeMode = .daily
    @State private var selectedNode: CircuitNode? = nil
    
    // Theme
    private let boardColor = InstitutionalTheme.Colors.background
    private let cardBg = InstitutionalTheme.Colors.surface1

    // Accents
    private let activeGreen = InstitutionalTheme.Colors.positive
    private let activeRed = InstitutionalTheme.Colors.negative
    private let cyan = SanctumTheme.orionColor
    private let purple = Color(hex: "6366F1")
    
    /// Current Orion score (selected timeframe)
    var currentOrion: OrionScoreResult {
        return analysis.scoreFor(timeframe: selectedTimeframe)
    }
    
    var body: some View {
        ZStack {
            // Background
            boardColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Fixed)
                headerBar
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 0. VISUAL CHART (Timeframe-aware, reactive to ViewModel)
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
                                .frame(height: 300)
                                .opacity(viewModel.isCandlesLoading ? 0.3 : 1.0)
                            } else {
                                // Empty state
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.largeTitle)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary.opacity(0.6))
                                    Text("Grafik verisi yükleniyor...")
                                        .font(.caption)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                                .frame(height: 300)
                            }

                            // Loading overlay
                            if viewModel.isCandlesLoading {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(cyan)
                                    Text("\(selectedTimeframe.displayLabel) yükleniyor...")
                                        .font(.caption)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                                .padding(12)
                                .background(InstitutionalTheme.Colors.surface1.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(.top, 16)
                        
                        // 1. TOP: Consensus Engine (The "Eye")
                        cpuNode
                        
                        // 2. BOTTOM: Modules Grid (2x2)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // Row 1
                            momentumCard
                            trendCard
                            
                            // Row 2
                            structureCard
                            patternCard
                        }
                        .padding(.horizontal, 16)
                        
                        // Footer
                        strategicAdviceBar
                            .padding(.bottom, 40)
                    }
                }
            }
            
            // Detail Overlay
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
    
    // MARK: - Header
    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANALIZ ÇEKİRDEĞİ")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .tracking(2)
                    Text(symbol)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                Spacer()
            }
            
            // 6 Timeframe Buttons
            HStack(spacing: 0) {
                ForEach(TimeframeMode.allCases, id: \.rawValue) { mode in
                    timeframeButton(mode)
                }
            }
            .background(InstitutionalTheme.Colors.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )

            timeframeProvenancePanel
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var timeframeProvenancePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                timeframeStatusBadge(
                    title: "GÖSTERİLEN",
                    value: selectedTimeframe.displayLabel,
                    color: cyan
                )
                timeframeStatusBadge(
                    title: "ARGUS RAPOR",
                    value: analysis.argusReportingTimeframe.displayLabel,
                    color: InstitutionalTheme.Colors.warning
                )
            }

            if analysis.isFallback(timeframe: selectedTimeframe) {
                let source = analysis.sourceFor(timeframe: selectedTimeframe)
                Text("\(selectedTimeframe.displayLabel) skoru şu an \(source.displayLabel) verisinden türetildi.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.warning)
            } else {
                Text("\(selectedTimeframe.displayLabel) skoru doğrudan kendi mum verisiyle hesaplanıyor.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TimeframeMode.allCases, id: \.rawValue) { mode in
                        timeframeScoreChip(mode)
                    }
                }
            }
        }
        .padding(10)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func timeframeStatusBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(InstitutionalTheme.Colors.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func timeframeScoreChip(_ mode: TimeframeMode) -> some View {
        let score = analysis.scoreFor(timeframe: mode).score
        let source = analysis.sourceFor(timeframe: mode)
        let isFallback = source != mode
        let isSelected = selectedTimeframe == mode

        return VStack(alignment: .leading, spacing: 2) {
            Text(mode.displayLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? cyan : InstitutionalTheme.Colors.textSecondary)
            Text(String(format: "%.0f", score))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
            if isFallback {
                Text("↪\(source.displayLabel)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.warning)
            } else {
                Text("NATIVE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? cyan.opacity(0.12) : InstitutionalTheme.Colors.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? cyan.opacity(0.45) : InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func timeframeButton(_ mode: TimeframeMode) -> some View {
        Button(action: {
            withAnimation {
                selectedTimeframe = mode
            }
            // Load new candles via ViewModel
            Task {
                await viewModel.changeTimeframe(to: mode)
            }
        }) {
            Text(mode.displayLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(selectedTimeframe == mode ? InstitutionalTheme.Colors.background : InstitutionalTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(selectedTimeframe == mode ? cyan : Color.clear)
        }
    }
    
    // MARK: - Top: Consensus CPU
    private var cpuNode: some View {
        Button(action: { withAnimation { selectedNode = .cpu } }) {
            ZStack {
                // Outer Glow
                Circle()
                    .fill(getVerdictColor().opacity(0.22))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                // Ring
                Circle()
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Active Arc
                Circle()
                    .trim(from: 0.0, to: currentOrion.score / 100.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                InstitutionalTheme.Colors.negative,
                                InstitutionalTheme.Colors.warning,
                                InstitutionalTheme.Colors.positive
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                // Content
                VStack(spacing: 2) {
                    Text("KONSENSUS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(String(format: "%.0f", currentOrion.score))
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .monospacedDigit()
                    Text(getVerdictText())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(getVerdictColor())
                        .padding(.top, 2)
                }
            }
        }
    }
    
    // MARK: - Module Cards (Refined for Grid)
    
    // 1. MOMENTUM (RSI Bar + Value)
    private var momentumCard: some View {
        let rsi = currentOrion.components.rsi ?? 50
        let status = rsi > 70 ? "Aşırı Alım" : (rsi < 30 ? "Aşırı Satım" : "Nötr")
        
        return moduleCard(
            node: .momentum,
            icon: "speedometer",
            title: "MOMENTUM",
            subtitle: "RSI",
            value: String(format: "%.0f", rsi),
            color: cyan,
            status: status
        ) {
            // Custom Bar: RSI
            Capsule()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 6)
                .overlay(
                    GeometryReader { g in
                        Capsule().fill(cyan)
                            .frame(width: min(1.0, max(0.0, rsi/100.0)) * g.size.width)
                    }
                )
        }
    }
    
    // 2. TREND (ADX Bar + Value)
    private var trendCard: some View {
        let adx = currentOrion.components.trendStrength ?? 0
        let status = adx > 25 ? "Güçlü" : "Zayıf/Yatay"
        
        return moduleCard(
            node: .trend,
            icon: "chart.xyaxis.line",
            title: "TREND",
            subtitle: "GÜÇ (ADX)",
            value: String(format: "%.1f", adx),
            color: purple,
            status: status
        ) {
            // Custom Bar: ADX
             Capsule()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 6)
                .overlay(
                    GeometryReader { g in
                        Capsule().fill(purple)
                            .frame(width: min(1.0, max(0.0, adx/50.0)) * g.size.width) // Scale to 50
                    }
                )
        }
    }
    
    // 3. STRUCTURE (Volume/S-R Slide)
    private var structureCard: some View {
        let structureScore = max(0, min(currentOrion.components.structure, 35))
        let position = structureScore / 35.0
        let status = position > 0.8 ? "Dirence Yakın" : (position < 0.2 ? "Desteğe Yakın" : "Kanal İçi")
        
        return moduleCard(
            node: .structure, // Was Volume
            icon: "building.columns.fill",
            title: "YAPI",
            subtitle: "KONUM", // S-R Position
            value: String(format: "%.0f", structureScore),
            color: activeGreen,
            status: status
        ) {
            // S-R Slider
            HStack(spacing: 8) {
                Text("S").font(.caption2).foregroundColor(activeGreen).bold()
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 4)
                        Circle()
                            .fill(InstitutionalTheme.Colors.textPrimary)
                            .frame(width: 8, height: 8)
                            .offset(x: (geo.size.width - 8) * position)
                    }
                    .frame(height: 8)
                }
                Text("R").font(.caption2).foregroundColor(activeRed).bold()
            }
        }
    }
    
    // 4. PATTERN (New)
    private var patternCard: some View {
        let patternDesc = currentOrion.components.patternDesc
        let isEmpty = patternDesc.isEmpty || patternDesc == "Yok"
        
        return moduleCard(
            node: .pattern,
            icon: "eye.fill",
            title: "FORMASYON",
            subtitle: "TESPİT",
            value: "",
            color: activeRed,
            status: isEmpty ? "Nötr" : "Aktif"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isEmpty ? "Formasyon tespit edilmedi" : patternDesc)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                // Pattern Mini Graphic (Curve)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addCurve(to: CGPoint(x: 40, y: 10), control1: CGPoint(x: 10, y: 10), control2: CGPoint(x: 20, y: 0))
                }
                .stroke(activeRed, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(height: 10)
            }
        }
    }
    
    // Generic Card Builder
    private func moduleCard<Content: View>(node: CircuitNode, icon: String, title: String, subtitle: String, value: String, color: Color, status: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        Button(action: { withAnimation { selectedNode = node } }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Icon + Title
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(title)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .tracking(1)
                    Spacer()
                }
                
                // Subtitle + Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        if !value.isEmpty {
                            Text(value)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .monospacedDigit()
                        }
                    }
                    
                    // The Graphical Content (Bar, Slider, etc)
                    content()
                }
                
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                
                // Footer: Status
                HStack {
                    Text("Durum")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Spacer()
                    Text(status)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.16))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Traces (Pyramid Flow)
    private func circuitTraces(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Coordinates based on layout estimates
            let cpuBottom = CGPoint(x: canvasSize.width / 2, y: 160) // Approx bottom of CPU ring
            
            // Grid Top Points (Row 1)
             // Not easily precise without GeometryReader prefs, but visual approximation is okay for canvas bg
             // We draw vertical lines down from CPU, splitting to the grid area
            
            var path = Path()
            path.move(to: cpuBottom)
            path.addLine(to: CGPoint(x: cpuBottom.x, y: cpuBottom.y + 40)) // Down stem
            
            // Split to left/right columns
            path.move(to: CGPoint(x: cpuBottom.x, y: cpuBottom.y + 20))
            path.addLine(to: CGPoint(x: canvasSize.width * 0.25, y: cpuBottom.y + 20))
            path.addLine(to: CGPoint(x: canvasSize.width * 0.25, y: cpuBottom.y + 60)) // To Row 1 Left
            
            path.move(to: CGPoint(x: cpuBottom.x, y: cpuBottom.y + 20))
            path.addLine(to: CGPoint(x: canvasSize.width * 0.75, y: cpuBottom.y + 20))
            path.addLine(to: CGPoint(x: canvasSize.width * 0.75, y: cpuBottom.y + 60)) // To Row 1 Right
            
            context.stroke(path, with: .color(InstitutionalTheme.Colors.textTertiary.opacity(0.4)), lineWidth: 1)
        }
    }
    
    private var strategicAdviceBar: some View {
        Text(analysis.strategicAdvice)
            .font(.caption)
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(InstitutionalTheme.Colors.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
    }
    
    // Helpers
    private func getVerdictText() -> String {
         if currentOrion.score >= 55 { return "AL" }
         if currentOrion.score >= 45 { return "TUT" }
         return "SAT"
    }
    
    private func getVerdictColor() -> Color {
        if currentOrion.score >= 55 { return activeGreen }
        if currentOrion.score >= 45 { return InstitutionalTheme.Colors.warning }
        return activeRed
    }
}
