import SwiftUI

// MARK: - Orion Module Detail View
struct OrionModuleDetailView: View {
    let type: CircuitNode
    let symbol: String
    let analysis: OrionScoreResult
    let candles: [Candle]
    let onClose: () -> Void
    
    // Theme
    private let darkBg = Color(red: 0.02, green: 0.02, blue: 0.04)
    private let cardBg = Color(red: 0.05, green: 0.05, blue: 0.08)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let orange = Color(red: 1.0, green: 0.6, blue: 0.0)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let purple = Color(red: 0.7, green: 0.3, blue: 1.0)
    
    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Live Analysis Text (Dynamic)
                        liveAnalysisCard
                        
                        // 2. Section Title
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(cyan)
                            Text("Teknik Göstergeler")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // 3. Indicator Charts & Stats (Dynamic per Type)
                        indicatorsSection
                        
                        // 4. Learning Section (Static per Type)
                        learningSection
                        
                        Color.clear.frame(height: 100)
                    }
                    .padding(.vertical)
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
            // Trend: RSI (Force) + MA (Direction)
            technicalCard(
                title: "PRICE ACTION",
                subtitle: "Hareketli Ortalamalar",
                value: String(format: "%.2f", candles.last?.close ?? 0),
                delta: getPriceChangeText()
            ) {
                maChart
            }
            
            technicalCard(
                title: "GÖRECELİ GÜÇ ENDEKSİ",
                subtitle: "RSI (14)",
                value: "Momentum",
                delta: ""
            ) {
                rsiChart
            }
            
        case .momentum:
            // Momentum: RSI Focus + Liquidty
             technicalCard(
                title: "MOMENTUM",
                subtitle: "RSI & Velocity",
                value: String(format: "%.0f", analysis.components.momentum),
                delta: "/ 25"
            ) {
                rsiChart
            }
            
        case .structure:
            // Structure (Was Volume) - Now S/R and Vol
             technicalCard(
                title: "YAPI ANALİZİ",
                subtitle: "Kanal & Hacim",
                value: String(format: "%.0f", analysis.components.structure),
                delta: "/ 35"
            ) {
                volumeChart
            }
            
        case .pattern:
            // Pattern Section
             technicalCard(
                title: "FORMASYON",
                subtitle: analysis.components.patternDesc.isEmpty ? "Tespit Edilemedi" : "Grafik Formasyonu",
                value: analysis.components.patternDesc,
                delta: ""
            ) {
                // Placeholder pattern visual
                GeometryReader { geo in
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: 0, y: h*0.8))
                        path.addCurve(to: CGPoint(x: w, y: h*0.2), control1: CGPoint(x: w*0.4, y: h*0.1), control2: CGPoint(x: w*0.6, y: h*0.9))
                    }
                    .stroke(purple, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
                    
                    Text(analysis.components.patternDesc.isEmpty ? "YOK" : analysis.components.patternDesc.prefix(1))
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(Color.white.opacity(0.1))
                        .position(x: geo.size.width/2, y: geo.size.height/2)
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Views
    
    private var liveAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(cyan).frame(width: 8, height: 8)
                Text("LIVE ANALYSIS")
                    .font(.caption)
                    .foregroundColor(cyan)
                    .bold()
                Spacer()
            }
            
            // Render Dynamic Text
            let dynamicText = getDynamicText()
            
            // Build text view from segments
            dynamicText.segments.reduce(Text("")) { (result, segment) in
                result + Text(segment.text)
                    .foregroundColor(segment.color)
                    .fontWeight(segment.isBold ? .bold : .regular)
            }
            .font(.system(size: 15, design: .monospaced))
            .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .background(cardBg)
        )
        .padding(.horizontal)
    }
    
    private func getDynamicText() -> DynamicAnalysisText {
        switch type {
        case .trend: return OrionTextGenerator.generateTrendText(for: analysis)
        case .momentum: return OrionTextGenerator.generateMomentumText(for: analysis)
        case .structure: return OrionTextGenerator.generateStructureText(for: analysis)
        case .pattern: return OrionTextGenerator.generatePatternText(for: analysis)
        default: return DynamicAnalysisText(segments: [])
        }
    }
    
    private func technicalCard<Content: View>(title: String, subtitle: String, value: String, delta: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(cyan)
                    Text(subtitle).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    Text(delta).font(.caption).foregroundColor(cyan)
                }
            }
            content().frame(height: 120)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .background(cardBg)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Safe Charts (Crash Proof)
    
    private var rsiChart: some View {
        GeometryReader { geo in
            let prices = candles.suffix(50).map { $0.close }
            if prices.isEmpty {
                 Text("Veri Yok").font(.caption).foregroundColor(.gray)
            } else {
                let rsiData = OrionChartHelpers.calculateRSI(period: 14, prices: prices)
                let normalized = OrionChartHelpers.normalize(rsiData)
                
                ZStack {
                    VStack(spacing: 0) {
                        Color.red.opacity(0.1).frame(height: geo.size.height * 0.3)
                        Color.clear.frame(height: geo.size.height * 0.4)
                        Color.green.opacity(0.1).frame(height: geo.size.height * 0.3)
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
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
    
    private var maChart: some View {
        GeometryReader { geo in
            let prices = candles.suffix(50).map { $0.close }
            if prices.isEmpty { Text("Veri Yok").font(.caption).foregroundColor(.gray) }
            else {
                let normPrices = OrionChartHelpers.normalize(prices)
                let sma = OrionChartHelpers.calculateSMA(period: 10, prices: prices)
                let normSMA = OrionChartHelpers.normalize(sma)
                ZStack {
                    Path { path in
                         let width = geo.size.width
                         let height = geo.size.height
                         let step = width / CGFloat(normPrices.count - 1)
                         for (index, value) in normPrices.enumerated() {
                             if value.isNaN || value.isInfinite { continue }
                             let x = CGFloat(index) * step
                             let y = height - (CGFloat(value) * height)
                             if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                         }
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2))
                    
                    Path { path in
                         let width = geo.size.width
                         let height = geo.size.height
                         let step = width / CGFloat(normSMA.count - 1)
                         for (index, value) in normSMA.enumerated() {
                             if value.isNaN || value.isInfinite { continue }
                             let x = CGFloat(index) * step
                             let y = height - (CGFloat(value) * height)
                             if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                         }
                    }
                    .stroke(orange, style: StrokeStyle(lineWidth: 2))
                }
            }
        }
    }
    
    private var volumeChart: some View {
        GeometryReader { geo in
            let lastCandles = Array(candles.suffix(50))
            let volumes = lastCandles.map { Double($0.volume) }
            
            if volumes.isEmpty {
                Text("Hacim Verisi Yok").font(.caption).foregroundColor(.gray)
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
                            .fill(lastCandles[i].close >= lastCandles[i].open ? green : red)
                            .frame(width: max(step - 1, 1), height: safeBarH)
                    }
                }
            }
        }
    }

    
    // MARK: - Header & Footer
    private var headerView: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left").font(.title3).foregroundColor(cyan)
            }
            Spacer()
            Text("\(type.title) DETAY ANALİZİ").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(cyan)
        }
        .padding()
        .background(cardBg.opacity(0.8))
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                HStack { Image(systemName: "bell.fill"); Text("ALARM KUR") }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(cyan)
                    .cornerRadius(12)
            }
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(darkBg.opacity(0.95))
    }
    
    private var learningSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(
                content: {
                    Text(type.educationalContent(for: analysis))
                        .foregroundColor(.gray)
                        .padding()
                },
                label: {
                    HStack {
                        Image(systemName: "graduationcap.fill").foregroundColor(orange)
                        Text("Öğren: \(type.title) Nedir?")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            )
            .accentColor(.white)
        }
        .background(cardBg)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func getPriceChangeText() -> String {
        guard let last = candles.last, let prev = candles.dropLast().last else { return "0%" }
        let diff = (last.close - prev.close) / prev.close * 100
        return String(format: "%+.2f%%", diff)
    }
}
