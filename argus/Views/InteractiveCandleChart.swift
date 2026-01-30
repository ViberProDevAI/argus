import SwiftUI
import Charts

struct InteractiveCandleChart: View {
    let candles: [Candle]
    let trades: [SimulatedTrade]?
    let showSMA: Bool
    let showBollinger: Bool
    let showIchimoku: Bool
    let showMACD: Bool
    let showVolume: Bool
    let showRSI: Bool
    let showStochastic: Bool
    let showSAR: Bool // NEW: Parabolic SAR overlay
    let showTSI: Bool // NEW: True Strength Index sub-chart
    
    @State private var selectedDate: Date?
    @State private var selectedCandle: Candle?
    
    // Zoom & Pan State
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isInspectionMode: Bool = false
    
    // Main Chart Height
    private var mainChartHeight: CGFloat {
        var reduced: CGFloat = 0
        if showMACD { reduced += 100 }
        if showRSI { reduced += 100 }
        if showStochastic { reduced += 100 }
        if showVolume { reduced += 60 }
        return max(200, 350 - reduced) // Dynamic height adjustment
    }
    
    var body: some View {
        let sortedCandles = candles.sorted { $0.date < $1.date }
        
        VStack(alignment: .leading, spacing: 4) {
            // Header Controls
            HStack {
                // Inspection Info
                    if let candle = selectedCandle {
                        HStack(spacing: 8) {
                            InfoBadge(title: "O", value: String(format: "%.2f", candle.open))
                            InfoBadge(title: "H", value: String(format: "%.2f", candle.high))
                            InfoBadge(title: "L", value: String(format: "%.2f", candle.low))
                            InfoBadge(title: "C", value: String(format: "%.2f", candle.close), color: candle.close >= candle.open ? Theme.positive : Theme.negative)
                            if showVolume {
                                InfoBadge(title: "V", value: formatVolume(Int(candle.volume)))
                            }
                        }
                    } else {
                        Text(isInspectionMode ? "Parmağınızı sürükleyerek inceleyin" : "Grafiği kaydırabilir ve büyütebilirsiniz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                
                Spacer()
                
                // Mode Toggle
                Button(action: { 
                    isInspectionMode.toggle() 
                    selectedCandle = nil 
                    selectedDate = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isInspectionMode ? "crosshair" : "hand.draw")
                        Text(isInspectionMode ? "İncele" : "Gezin")
                            .font(.caption2)
                            .bold()
                    }
                    .padding(6)
                    .background(isInspectionMode ? Theme.tint : Theme.secondaryBackground)
                    .foregroundColor(isInspectionMode ? .white : .gray)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Main Chart Area
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // The Chart
                        Chart {
                            ForEach(sortedCandles) { candle in
                                RectangleMark(
                                    x: .value("Date", candle.date),
                                    yStart: .value("Open", candle.open),
                                    yEnd: .value("Close", candle.close),
                                    width: .fixed(6 * (zoomScale > 2 ? 0.8 : 1.0)) // Adaptive width hint
                                )
                                .foregroundStyle(candle.close >= candle.open ? Theme.positive : Theme.negative)
                                
                                RectangleMark(
                                    x: .value("Date", candle.date),
                                    yStart: .value("Low", candle.low),
                                    yEnd: .value("High", candle.high),
                                    width: .fixed(1)
                                )
                                .foregroundStyle(Theme.neutral)
                            }
                            
                            // SMA Overlay
                            if showSMA {
                                let smaData = IndicatorService.calculateSMA(values: sortedCandles.map { $0.close }, period: 20)
                                ForEach(smaData.indices, id: \.self) { i in
                                    if let val = smaData[i] {
                                        LineMark(x: .value("Date", sortedCandles[i].date), y: .value("SMA 20", val))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            
                            // Bollinger Overlay (Wave)
                            if showBollinger {
                                let bbData = IndicatorService.calculateBollingerBands(values: sortedCandles.map { $0.close })
                                ForEach(bbData.upper.indices, id: \.self) { i in
                                    if let upper = bbData.upper[i], let lower = bbData.lower[i] {
                                        // Area Fill (Wave)
                                        AreaMark(
                                            x: .value("Date", sortedCandles[i].date),
                                            yStart: .value("Upper", upper),
                                            yEnd: .value("Lower", lower)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue.opacity(DesignTokens.Opacity.glassCard), .blue.opacity(0.05)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        
                                        // Lines
                                        LineMark(x: .value("Date", sortedCandles[i].date), y: .value("Upper", upper)).foregroundStyle(.blue.opacity(0.4))
                                        LineMark(x: .value("Date", sortedCandles[i].date), y: .value("Lower", lower)).foregroundStyle(.blue.opacity(0.4))
                                    }
                                }
                            }
                            
                            // Ichimoku Overlay
                            if showIchimoku {
                                let ichimoku = IndicatorService.calculateIchimoku(candles: sortedCandles)
                                ForEach(sortedCandles.indices, id: \.self) { i in
                                    if let spanA = ichimoku.senkouSpanA[i], let spanB = ichimoku.senkouSpanB[i] {
                                        AreaMark(x: .value("Date", sortedCandles[i].date), yStart: .value("Span A", spanA), yEnd: .value("Span B", spanB))
                                            .foregroundStyle(spanA >= spanB ? Color.green.opacity(DesignTokens.Opacity.glassCard) : Color.red.opacity(DesignTokens.Opacity.glassCard))
                                    }
                                    if let tenkan = ichimoku.tenkanSen[i] {
                                        LineMark(x: .value("Date", sortedCandles[i].date), y: .value("Tenkan", tenkan)).foregroundStyle(.red.opacity(0.8))
                                    }
                                    if let kijun = ichimoku.kijunSen[i] {
                                        LineMark(x: .value("Date", sortedCandles[i].date), y: .value("Kijun", kijun)).foregroundStyle(.blue.opacity(0.8))
                                    }
                                }
                            }
                            
                            // SAR Overlay (Parabolic Stop & Reverse)
                            if showSAR {
                                let sarData = IndicatorService.calculateSAR(candles: sortedCandles)
                                ForEach(sortedCandles.indices, id: \.self) { i in
                                    if let sarValue = sarData[i] {
                                        let close = sortedCandles[i].close
                                        let isAbovePrice = sarValue > close
                                        PointMark(x: .value("Date", sortedCandles[i].date), y: .value("SAR", sarValue))
                                            .foregroundStyle(isAbovePrice ? Color.red : Color.green)
                                            .symbolSize(20)
                                    }
                                }
                            }
                            
                            // Trades (Dots)
                            if let trades = trades {
                                ForEach(trades) { trade in
                                    // Entry Marker (Green Dot)
                                    PointMark(x: .value("Date", trade.entryDate), y: .value("Entry", trade.entryPrice))
                                        .foregroundStyle(.green)
                                        .symbol(.circle)
                                    
                                    // Exit Marker (Red Dot)
                                    PointMark(x: .value("Date", trade.exitDate), y: .value("Exit", trade.exitPrice))
                                        .foregroundStyle(.red)
                                        .symbol(.circle)
                                }
                            }
                            
                            // Crosshair Rule
                            if isInspectionMode, let selectedDate = selectedDate {
                                RuleMark(x: .value("Selected", selectedDate))
                                    .foregroundStyle(Color.gray)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(width: max(geo.size.width * zoomScale, geo.size.width), height: mainChartHeight)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    let delta = val / 1.0
                                    self.zoomScale = max(1.0, min(10.0, self.lastZoomScale * delta))
                                }
                                .onEnded { _ in
                                    self.lastZoomScale = self.zoomScale
                                }
                        )
                        .chartOverlay { proxy in
                             GeometryReader { g in
                                 Rectangle().fill(.clear).contentShape(Rectangle())
                                     .gesture(
                                         isInspectionMode ? DragGesture()
                                            .onChanged { value in
                                                 let x = value.location.x
                                                 if let date: Date = proxy.value(atX: x) {
                                                     selectedDate = date
                                                     if let candle = sortedCandles.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                         selectedCandle = candle
                                                     }
                                                 }
                                             } : nil
                                     )
                             }
                        }
                    }
                }
                .scrollDisabled(isInspectionMode)
            }
            .frame(height: mainChartHeight)
            
            // Sub-Charts Stack
            VStack(spacing: 2) {
                // Volume Chart
                if showVolume {
                    VolumeChart(candles: sortedCandles)
                        .frame(height: 60)
                }
                
                // RSI Chart
                if showRSI {
                    RSIChart(candles: sortedCandles)
                        .frame(height: 100)
                }
                
                // MACD Chart (Existing + Stochastic)
                if showStochastic {
                    StochasticChart(candles: sortedCandles)
                         .frame(height: 100)
                }
                
                if showMACD {
                    MACDChart(candles: sortedCandles)
                        .frame(height: 100)
                }
                
                // TSI Chart (True Strength Index)
                if showTSI {
                    TSIChart(candles: sortedCandles)
                        .frame(height: 100)
                }
            }
        }
    }
    
    private func formatVolume(_ vol: Int) -> String {
        if vol >= 1_000_000 {
            return String(format: "%.1fM", Double(vol)/1_000_000)
        } else if vol >= 1_000 {
            return String(format: "%.1fK", Double(vol)/1_000)
        } else {
            return "\(vol)"
        }
    }
}

// MARK: - Sub-Chart Components

struct VolumeChart: View {
    let candles: [Candle]
    var body: some View {
        Chart {
            ForEach(candles) { candle in
                BarMark(
                    x: .value("Date", candle.date),
                    y: .value("Volume", candle.volume)
                )
                .foregroundStyle(candle.close >= candle.open ? Theme.positive.opacity(0.3) : Theme.negative.opacity(0.3))
            }
        }
    }
}

struct RSIChart: View {
    let candles: [Candle]
    var body: some View {
        Chart {
            let rsi = IndicatorService.calculateRSI(values: candles.map { $0.close })
            ForEach(candles.indices, id: \.self) { i in
                if let val = rsi[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("RSI", val))
                        .foregroundStyle(.purple)
                }
            }
            
            // Bounds
            RuleMark(y: .value("Overbought", 70)).foregroundStyle(.red.opacity(0.5)).lineStyle(StrokeStyle(dash: [4]))
            RuleMark(y: .value("Oversold", 30)).foregroundStyle(.green.opacity(0.5)).lineStyle(StrokeStyle(dash: [4]))
        }
        .chartYScale(domain: 0...100)
        .padding(4)
        .background(Theme.cardBackground.opacity(0.5))
    }
}

struct StochasticChart: View {
    let candles: [Candle]
    var body: some View {
        Chart {
            let stoch = IndicatorService.calculateStochastic(candles: candles)
            ForEach(candles.indices, id: \.self) { i in
                if let k = stoch.k[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("%K", k)).foregroundStyle(.blue)
                }
                if let d = stoch.d[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("%D", d)).foregroundStyle(.orange)
                }
            }
            
            // Bounds
            RuleMark(y: .value("Overbought", 80)).foregroundStyle(.red.opacity(0.5)).lineStyle(StrokeStyle(dash: [2]))
            RuleMark(y: .value("Oversold", 20)).foregroundStyle(.green.opacity(0.5)).lineStyle(StrokeStyle(dash: [2]))
        }
        .chartYScale(domain: 0...100)
        .padding(4)
        .background(Theme.cardBackground.opacity(0.5))
    }
}

struct MACDChart: View {
    let candles: [Candle]
    var body: some View {
        Chart {
             let macdData = IndicatorService.calculateMACD(values: candles.map { $0.close })
             ForEach(candles.indices, id: \.self) { i in
                 if let hist = macdData.histogram[i] {
                    BarMark(x: .value("Date", candles[i].date), y: .value("Hist", hist))
                        .foregroundStyle(hist >= 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                 }
                 if let macd = macdData.macd[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("MACD", macd)).foregroundStyle(.blue)
                 }
                 if let signal = macdData.signal[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("Signal", signal)).foregroundStyle(.orange)
                 }
             }
        }
        .padding(4)
        .background(Theme.cardBackground.opacity(0.5))
    }
}

struct TSIChart: View {
    let candles: [Candle]
    var body: some View {
        Chart {
            let tsiData = IndicatorService.calculateTSI(values: candles.map { $0.close })
            ForEach(candles.indices, id: \.self) { i in
                if let val = tsiData[i] {
                    LineMark(x: .value("Date", candles[i].date), y: .value("TSI", val))
                        .foregroundStyle(val >= 0 ? Color.green : Color.red)
                }
            }
            
            // Zero line
            RuleMark(y: .value("Zero", 0)).foregroundStyle(.gray.opacity(0.5)).lineStyle(StrokeStyle(dash: [4]))
            // Overbought/Oversold
            RuleMark(y: .value("Overbought", 25)).foregroundStyle(.red.opacity(0.3)).lineStyle(StrokeStyle(dash: [2]))
            RuleMark(y: .value("Oversold", -25)).foregroundStyle(.green.opacity(0.3)).lineStyle(StrokeStyle(dash: [2]))
        }
        .chartYScale(domain: -50...50)
        .padding(4)
        .background(Theme.cardBackground.opacity(0.5))
    }
}

struct InfoBadge: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 8)).foregroundColor(.gray)
            Text(value).font(.caption2).bold().foregroundColor(color)
        }
        .padding(4)
        .background(Color.black.opacity(0.1))
        .cornerRadius(4)
    }
}
