import SwiftUI

struct OrionPatternGraphView: View {
    let pattern: OrionChartPattern
    let candles: [Candle]
    
    // Config
    private let padding: Int = 10
    
    var body: some View {
        GeometryReader { geo in
            let window = getWindow()
            let slice = Array(candles[window.start..<window.end])
            
            let minPrice = slice.map { $0.low }.min() ?? 0
            let maxPrice = slice.map { $0.high }.max() ?? 100
            let priceRange = maxPrice - minPrice
            
            let width = geo.size.width
            let height = geo.size.height
            
            // X Scale: index -> x position
            let stepX = width / CGFloat(max(1, slice.count))
            
            ZStack {
                // 1. Draw Candles
                Path { path in
                    for (i, candle) in slice.enumerated() {
                        let x = CGFloat(i) * stepX + (stepX / 2)
                        
                        // Wick
                        let yHigh = height - ((candle.high - minPrice) / priceRange) * height
                        let yLow = height - ((candle.low - minPrice) / priceRange) * height
                        path.move(to: CGPoint(x: x, y: yHigh))
                        path.addLine(to: CGPoint(x: x, y: yLow))
                    }
                }.stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                // Candle Bodies
                ForEach(Array(slice.enumerated()), id: \.offset) { i, candle in
                    let x = CGFloat(i) * stepX + 2
                    let candleWidth = max(2, stepX - 4)
                    
                    let yOpen = height - ((candle.open - minPrice) / priceRange) * height
                    let yClose = height - ((candle.close - minPrice) / priceRange) * height
                    
                    let isGreen = candle.close >= candle.open
                    
                    Rectangle()
                        .fill(isGreen ? Color.green : Color.red)
                        .frame(width: candleWidth, height: max(1, abs(yOpen - yClose)))
                        .position(x: x + (candleWidth/2) - 2, y: (yOpen + yClose) / 2)
                }
                
                // 2. Draw Pattern Lines
                if !pattern.points.isEmpty {
                    Path { path in
                        for (i, point) in pattern.points.enumerated() {
                            // Map global index to local slice index
                            let localIndex = point.index - window.start
                            
                            if localIndex >= 0 && localIndex < slice.count {
                                let x = CGFloat(localIndex) * stepX + (stepX / 2)
                                let y = height - ((point.price - minPrice) / priceRange) * height
                                
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    // Draw Points
                    ForEach(pattern.points, id: \.index) { point in
                        let localIndex = point.index - window.start
                        if localIndex >= 0 && localIndex < slice.count {
                            let x = CGFloat(localIndex) * stepX + (stepX / 2)
                            let y = height - ((point.price - minPrice) / priceRange) * height
                            
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                
                // 3. Draw Target Price Line
                if let target = pattern.targetPrice {
                    let yTarget = height - ((target - minPrice) / (priceRange > 0 ? priceRange : 1) * height)
                    
                    if yTarget >= 0 && yTarget <= height {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yTarget))
                            path.addLine(to: CGPoint(x: width, y: yTarget))
                        }
                        .stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        
                        Text("HEDEF")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.blue)
                            .position(x: 20, y: yTarget - 6)
                    }
                }
            }
        }
        .drawingGroup() // Promote to Metal for performance
    }
    
    private func getWindow() -> (start: Int, end: Int) {
        guard !pattern.points.isEmpty else { return (0, candles.count) }
        
        let minIndex = pattern.points.map { $0.index }.min() ?? 0
        let maxIndex = pattern.points.map { $0.index }.max() ?? 0
        
        let start = max(0, minIndex - padding)
        let end = min(candles.count, maxIndex + padding)
        
        return (start, end)
    }
}
