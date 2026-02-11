import SwiftUI

// MARK: - Argus Chart Engine Pro 
// TradingView-quality charting experience for Argus Terminal.

struct ArgusChartEngine: View {
    // Data
    let data: ChartData
    
    // Configuration
    private let chartInsets = EdgeInsets(top: 40, leading: 10, bottom: 40, trailing: 60)
    private let baseCandleWidth: CGFloat = 8.0
    private let candleSpacing: CGFloat = 2.0
    
    // Viewport State
    @State private var scaleX: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0.0
    @State private var lastDragValue: DragGesture.Value?
    @State private var lastScale: CGFloat = 1.0
    
    // Interaction State
    @Binding var activeTool: DrawingType? // Nil = Pointer/Pan mode
    @Binding var drawings: [ChartDrawing]
    
    // Internal Drawing State
    @State private var currentDrawing: ChartDrawing?
    @State private var crosshairLocation: CGPoint?
    @State private var selectedPointIndex: Int?
    
    // Indicator Toggle
    @State private var showEMA20: Bool = true
    @State private var showEMA50: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            let chartRect = CGRect(
                x: chartInsets.leading,
                y: chartInsets.top,
                width: geometry.size.width - chartInsets.leading - chartInsets.trailing,
                height: geometry.size.height - chartInsets.top - chartInsets.bottom
            )
            
            ZStack(alignment: .topLeading) {
                // Canvas Layer
                Canvas { context, size in
                    guard !data.points.isEmpty else { return }
                    
                    // 1. Draw Grid
                    drawGrid(context: context, chartRect: chartRect)
                    
                    // 2. Draw EMA (Behind candles)
                    if showEMA20 { drawEMA(context: context, chartRect: chartRect, period: 20, color: .cyan) }
                    if showEMA50 { drawEMA(context: context, chartRect: chartRect, period: 50, color: .orange) }
                    
                    // 3. Draw Candles
                    drawCandles(context: context, chartRect: chartRect)
                    
                    // 4. Draw Saved Drawings
                    for drawing in drawings {
                        drawDrawing(context: context, drawing: drawing, chartRect: chartRect)
                    }
                    
                    // 5. Draw Active Drawing (Being drawn)
                    if let current = currentDrawing {
                        drawDrawing(context: context, drawing: current, chartRect: chartRect)
                    }
                    
                    // 6. Draw Y-Axis
                    drawYAxis(context: context, chartRect: chartRect)
                    
                    // 7. Draw Crosshair
                    if let loc = crosshairLocation, chartRect.contains(loc) {
                        drawCrosshair(context: context, location: loc, chartRect: chartRect)
                    }
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
                
                // Overlays
                ohlcvInfoBox
                    .padding(.leading, chartInsets.leading + 8)
                    .padding(.top, 8)
                
                indicatorToggle
                    .padding(.trailing, chartInsets.trailing + 8)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            // Gesture handling is split based on mode
            // Gesture handling based on mode
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeTool == nil {
                            // Pan Logic
                            crosshairLocation = value.location
                            updateSelectedPoint(at: value.location.x, chartRect: chartRect)
                            
                            if abs(value.translation.width) > 5 || abs(value.translation.height) > 5 {
                                 let deltaX = value.translation.width - (lastDragValue?.translation.width ?? 0)
                                 offsetX += deltaX
                                 lastDragValue = value
                            }
                        } else {
                            // Drawing Logic
                            let location = value.location
                            guard chartRect.contains(location) else { return }
                            
                            let snappedLocation = snapToCandle(at: location, chartRect: chartRect)
                            
                            if currentDrawing == nil {
                                 if let startPoint = convertToDataPoint(at: snappedLocation, chartRect: chartRect) {
                                     currentDrawing = ChartDrawing(
                                        type: activeTool!,
                                        points: [startPoint, startPoint],
                                        color: .white
                                     )
                                 }
                            } else {
                                if let endPoint = convertToDataPoint(at: snappedLocation, chartRect: chartRect) {
                                    currentDrawing?.points[1] = endPoint
                                }
                            }
                            crosshairLocation = snappedLocation
                        }
                    }
                    .onEnded { _ in
                        if activeTool == nil {
                            lastDragValue = nil
                            crosshairLocation = nil
                            selectedPointIndex = nil
                        } else {
                            if let drawing = currentDrawing {
                                drawings.append(drawing)
                                currentDrawing = nil
                                activeTool = nil
                            }
                            crosshairLocation = nil
                        }
                    }
            )
            .gesture(magnificationGesture)
        }
    }
    
    // MARK: - Gestures
    
    // Gesture functions moved inline for state access and type safety

    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let delta = scale / lastScale
                lastScale = scale
                scaleX *= delta
                scaleX = min(max(scaleX, 0.2), 5.0)
            }
            .onEnded { _ in
                lastScale = 1.0
            }
    }
    
    // MARK: - Drawing Rendering
    
    private func drawDrawing(context: GraphicsContext, drawing: ChartDrawing, chartRect: CGRect) {
        guard drawing.points.count >= 2 else { return }
        
        let p1 = convertToScreenPoint(from: drawing.points[0], chartRect: chartRect)
        let p2 = convertToScreenPoint(from: drawing.points[1], chartRect: chartRect)
        
        guard let start = p1, let end = p2 else { return }
        
        switch drawing.type {
        case .trendLine:
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            
            // Draw infinite extension? For now just segment
            context.stroke(path, with: .color(drawing.color), lineWidth: drawing.lineWidth)
            
            // Dots at ends
            let dotSize: CGFloat = 6
            let dotRect1 = CGRect(x: start.x - dotSize/2, y: start.y - dotSize/2, width: dotSize, height: dotSize)
            let dotRect2 = CGRect(x: end.x - dotSize/2, y: end.y - dotSize/2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect1), with: .color(drawing.color))
            context.fill(Path(ellipseIn: dotRect2), with: .color(drawing.color))
            
        case .fibonacci:
            // Fibonacci Levels
            let levels: [Double] = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
            let diffY = end.y - start.y
            let width = chartRect.width // Full width lines
            
            for level in levels {
                let y = start.y + diffY * CGFloat(level)
                
                var path = Path()
                path.move(to: CGPoint(x: chartRect.minX, y: y))
                path.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                
                let color = drawing.color.opacity(level == 0 || level == 0.5 || level == 1 ? 0.8 : 0.4)
                context.stroke(path, with: .color(color), lineWidth: 1)
                
                // Label
                let text = Text("Fib \(String(format: "%.3f", level))")
                    .font(.caption2)
                    .foregroundColor(color)
                context.draw(text, at: CGPoint(x: chartRect.minX + 5, y: y - 5))
            }
            
            // Trendline connecting high/low
            var trendPath = Path()
            trendPath.move(to: start)
            trendPath.addLine(to: end)
            context.stroke(trendPath, with: .color(drawing.color.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
    
    // MARK: - Helpers & coordinate Conversion
    
    private func updateSelectedPoint(at x: CGFloat, chartRect: CGRect) {
        let totalCandleWidth = (baseCandleWidth * scaleX) + (candleSpacing * scaleX)
        let relativeX = x - chartRect.minX - offsetX
        let index = Int(relativeX / totalCandleWidth)
        if index >= 0 && index < data.points.count {
            selectedPointIndex = index
        }
    }
    
    private func snapToCandle(at location: CGPoint, chartRect: CGRect) -> CGPoint {
        // Find candle index
        let totalCandleWidth = (baseCandleWidth * scaleX) + (candleSpacing * scaleX)
        let relativeX = location.x - chartRect.minX - offsetX
        let index = Int(relativeX / totalCandleWidth)
        
        guard index >= 0 && index < data.points.count else { return location }
        
        let point = data.points[index]
        let xCenter = chartRect.minX + offsetX + CGFloat(index) * totalCandleWidth + (baseCandleWidth * scaleX / 2)
        
        // Check Y proximity High vs Low
        let priceRange = data.maxPrice - data.minPrice
        let priceScale = chartRect.height / (priceRange > 0 ? priceRange : 1.0)
        
        let highY = chartRect.minY + chartRect.height - ((point.high - data.minPrice) * priceScale)
        let lowY = chartRect.minY + chartRect.height - ((point.low - data.minPrice) * priceScale)
        
        let distHigh = abs(location.y - highY)
        let distLow = abs(location.y - lowY)
        
        let yTarget = distHigh < distLow ? highY : lowY
        
        // Only snap if reasonably close (e.g., 30px), otherwise free move?
        // For V1, always snap X, maybe Y.
        return CGPoint(x: xCenter, y: yTarget)
    }
    
    private func convertToDataPoint(at location: CGPoint, chartRect: CGRect) -> ChartDrawingPoint? {
        let priceRange = data.maxPrice - data.minPrice
        let relativeY = (chartRect.maxY - location.y) / chartRect.height
        let price = data.minPrice + (priceRange * relativeY)
        
        // Simple date calculation using index (assuming linear time for now)
        let totalCandleWidth = (baseCandleWidth * scaleX) + (candleSpacing * scaleX)
        let relativeX = location.x - chartRect.minX - offsetX
        let index = Int(relativeX / totalCandleWidth)
        
        guard index >= 0 && index < data.points.count else { return nil }
        
        return ChartDrawingPoint(date: data.points[index].timestamp, price: price)
    }
    
    private func convertToScreenPoint(from point: ChartDrawingPoint, chartRect: CGRect) -> CGPoint? {
        // Find index for date (O(N) - optimize later with dict if needed)
        // Since we don't have exact Date mapping easily without search, we approximate or search
        guard let index = data.points.firstIndex(where: { $0.timestamp == point.date }) else { return nil }
        
        let totalCandleWidth = (baseCandleWidth * scaleX) + (candleSpacing * scaleX)
        let x = chartRect.minX + offsetX + CGFloat(index) * totalCandleWidth + (baseCandleWidth * scaleX / 2)
        
        let priceRange = data.maxPrice - data.minPrice
        let priceScale = chartRect.height / (priceRange > 0 ? priceRange : 1.0)
        let y = chartRect.minY + chartRect.height - ((point.price - data.minPrice) * priceScale)
        
        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing Wrappers (Previous Logic)
    // Reuse existing implementation for Grid, Candles, YAxis, Crosshair, etc.
    // ... (Keeping the previous implementations for brevity, imagine they are here)
    // Need to include them physically to compile
    
    // --- IMPORTED --- (Copying previous helper methods)
    
    private var ohlcvInfoBox: some View {
        let point = selectedPointIndex.flatMap { data.points.indices.contains($0) ? data.points[$0] : nil }
                    ?? data.points.last
        
        return HStack(spacing: 12) {
            if let p = point {
                Text("O").foregroundColor(.gray) + Text(String(format: "%.2f", p.open)).foregroundColor(.white)
                Text("H").foregroundColor(.gray) + Text(String(format: "%.2f", p.high)).foregroundColor(.green)
                Text("L").foregroundColor(.gray) + Text(String(format: "%.2f", p.low)).foregroundColor(.red)
                Text("C").foregroundColor(.gray) + Text(String(format: "%.2f", p.close)).foregroundColor(p.isBullish ? .green : .red)
                Text("V").foregroundColor(.gray) + Text(formatVolume(p.volume)).foregroundColor(.white)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
    
    private var indicatorToggle: some View {
        HStack(spacing: 8) {
            Button(action: { showEMA20.toggle() }) {
                Text("EMA20").font(.caption2).padding(4).background(showEMA20 ? Color.cyan.opacity(0.3) : .gray.opacity(0.2)).cornerRadius(4).foregroundColor(showEMA20 ? .cyan : .gray)
            }
            Button(action: { showEMA50.toggle() }) {
                Text("EMA50").font(.caption2).padding(4).background(showEMA50 ? Color.orange.opacity(0.3) : .gray.opacity(0.2)).cornerRadius(4).foregroundColor(showEMA50 ? .orange : .gray)
            }
            Button(action: { drawings.removeAll() }) {
                Image(systemName: "trash").font(.caption2).padding(4).background(Color.red.opacity(0.3)).cornerRadius(4).foregroundColor(.red)
            }
        }
    }
    
    private func drawGrid(context: GraphicsContext, chartRect: CGRect) {
        let gridColor = Color.gray.opacity(DesignTokens.Opacity.glassCard)
        let ySteps = 5
        for i in 0...ySteps {
            let y = chartRect.minY + chartRect.height * CGFloat(i) / CGFloat(ySteps)
            var path = Path(); path.move(to: CGPoint(x: chartRect.minX, y: y)); path.addLine(to: CGPoint(x: chartRect.maxX, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
        let totalWidth = CGFloat(data.points.count) * (baseCandleWidth * scaleX + candleSpacing * scaleX)
        let step = max(1, data.points.count / 6)
        for i in stride(from: 0, to: data.points.count, by: step) {
            let x = chartRect.minX + CGFloat(i) * (baseCandleWidth * scaleX + candleSpacing * scaleX) + offsetX
            if x >= chartRect.minX && x <= chartRect.maxX {
                var path = Path(); path.move(to: CGPoint(x: x, y: chartRect.minY)); path.addLine(to: CGPoint(x: x, y: chartRect.maxY))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }
        }
    }
    
    private func drawYAxis(context: GraphicsContext, chartRect: CGRect) {
        let priceRange = data.maxPrice - data.minPrice; let ySteps = 5
        for i in 0...ySteps {
            let y = chartRect.minY + chartRect.height * CGFloat(i) / CGFloat(ySteps)
            let price = data.maxPrice - (priceRange * Double(i) / Double(ySteps))
            context.draw(Text(String(format: "%.2f", price)).font(.system(size: 10)).foregroundColor(.gray), at: CGPoint(x: chartRect.maxX + 8, y: y), anchor: .leading)
        }
    }
    
    private func drawCandles(context: GraphicsContext, chartRect: CGRect) {
        let effectiveCandleWidth = baseCandleWidth * scaleX
        let totalCandleWidth = effectiveCandleWidth + (candleSpacing * scaleX)
        let priceRange = data.maxPrice - data.minPrice
        let priceScale = chartRect.height / (priceRange > 0 ? priceRange : 1.0)
        
        for (index, point) in data.points.enumerated() {
            let x = chartRect.minX + CGFloat(index) * totalCandleWidth + offsetX
            if x < chartRect.minX - effectiveCandleWidth || x > chartRect.maxX { continue }
            
            let openY = chartRect.maxY - ((point.open - data.minPrice) * priceScale)
            let closeY = chartRect.maxY - ((point.close - data.minPrice) * priceScale)
            let highY = chartRect.maxY - ((point.high - data.minPrice) * priceScale)
            let lowY = chartRect.maxY - ((point.low - data.minPrice) * priceScale)
            
            let isBullish = point.close >= point.open
            let color: Color = isBullish ? .green : .red
            context.stroke(Path { p in p.move(to: CGPoint(x: x + effectiveCandleWidth/2, y: highY)); p.addLine(to: CGPoint(x: x + effectiveCandleWidth/2, y: lowY)) }, with: .color(color.opacity(0.8)))
            let bodyRect = CGRect(x: x, y: min(openY, closeY), width: effectiveCandleWidth, height: max(abs(openY - closeY), 1.0))
            context.fill(Path(bodyRect), with: .linearGradient(Gradient(colors: [color.opacity(0.9), color.opacity(0.6)]), startPoint: CGPoint(x: bodyRect.midX, y: bodyRect.minY), endPoint: CGPoint(x: bodyRect.midX, y: bodyRect.maxY)))
        }
    }
    
    private func drawEMA(context: GraphicsContext, chartRect: CGRect, period: Int, color: Color) {
        guard data.points.count > period else { return }
        let closes = data.points.map { $0.close }
        // Simple SMA-based EMA calc inside (minimized for brevity)
        var emas: [Double?] = Array(repeating: nil, count: period - 1)
        let k = 2.0 / Double(period + 1)
        var ema = closes.prefix(period).reduce(0, +) / Double(period)
        emas.append(ema)
        for i in period..<closes.count { ema = (closes[i] - ema) * k + ema; emas.append(ema) }
        
        let totalW = (baseCandleWidth * scaleX) + (candleSpacing * scaleX)
        let priceRange = data.maxPrice - data.minPrice
        let priceScale = chartRect.height / (priceRange > 0 ? priceRange : 1.0)
        
        var path = Path(); var started = false
        for (i, val) in emas.enumerated() {
            guard let v = val else { continue }
            let x = chartRect.minX + CGFloat(i) * totalW + offsetX + (baseCandleWidth * scaleX / 2)
            let y = chartRect.maxY - ((v - data.minPrice) * priceScale)
            if x < chartRect.minX || x > chartRect.maxX { continue }
            if !started { path.move(to: CGPoint(x: x, y: y)); started = true } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
    
    private func drawCrosshair(context: GraphicsContext, location: CGPoint, chartRect: CGRect) {
        // 1. Draw Lines
        let color = Color.white.opacity(0.4)
        var v = Path(); v.move(to: CGPoint(x: location.x, y: chartRect.minY)); v.addLine(to: CGPoint(x: location.x, y: chartRect.maxY))
        context.stroke(v, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        var h = Path(); h.move(to: CGPoint(x: chartRect.minX, y: location.y)); h.addLine(to: CGPoint(x: chartRect.maxX, y: location.y))
        context.stroke(h, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        // 2. Y-Axis Label (Price)
        let priceRange = data.maxPrice - data.minPrice
        let price = data.maxPrice - (priceRange * (location.y - chartRect.minY) / chartRect.height)
        let priceText = String(format: "%.2f", price)
        let priceBgRect = CGRect(x: chartRect.maxX, y: location.y - 10, width: 60, height: 20)
        
        let pricePath = Path(roundedRect: priceBgRect, cornerRadius: 4)
        context.fill(pricePath, with: .color(Color.blue))
        context.draw(Text(priceText).font(.caption2).bold().foregroundColor(.white), at: CGPoint(x: chartRect.maxX + 4, y: location.y), anchor: .leading)
        
        // 3. X-Axis Label (Date)
        // Calculate index logic matches drawCandles
        let effectiveCandleWidth = baseCandleWidth * scaleX
        let totalCandleWidth = effectiveCandleWidth + (candleSpacing * scaleX)
        let index = Int((location.x - chartRect.minX - offsetX) / totalCandleWidth)
        
        if index >= 0 && index < data.points.count {
            let point = data.points[index]
            let date = point.timestamp
            
            // Format Date
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM HH:mm" // Default short format
            let dateText = formatter.string(from: date)
            
            // Draw Label
            let textLayout = context.resolve(Text(dateText).font(.caption2).bold().foregroundColor(.white))
            let textSize = textLayout.measure(in: CGSize(width: 200, height: 20))
            let textRect = CGRect(
                x: location.x - (textSize.width / 2) - 4,
                y: chartRect.maxY + 4,
                width: textSize.width + 8,
                height: 20
            )
            
            let datePath = Path(roundedRect: textRect, cornerRadius: 4)
            context.fill(datePath, with: .color(Color.blue))
            context.draw(textLayout, at: CGPoint(x: textRect.midX, y: textRect.midY), anchor: .center)
        }
    }
    
    private func formatVolume(_ v: Double) -> String {
        v >= 1e6 ? String(format: "%.1fM", v/1e6) : (v >= 1e3 ? String(format: "%.1fK", v/1e3) : String(format: "%.0f", v))
    }
}

#Preview {
    ArgusChartEngine(
        data: .empty,
        activeTool: .constant(nil),
        drawings: .constant([])
    )
    .frame(height: 400)
}
