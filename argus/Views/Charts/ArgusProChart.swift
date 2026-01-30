import SwiftUI

struct ArgusProChart: View {
    let candles: [Candle]
    
    // Config
    @State private var zoomLevel: CGFloat = 10.0 // Pixels per candle width
    @State private var lastZoomLevel: CGFloat = 10.0
    
    // Interaction
    @State private var crosshairLocation: CGPoint?
    @State private var selectedCandleInfo: Candle?
    
    // Theme
    let upColor = Color(red: 0.1, green: 0.8, blue: 0.4)
    let downColor = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack(alignment: .topLeading) {
                // Canvas for drawing
                Canvas { context, size in
                    let drawingWidth = size.width
                    let drawingHeight = size.height
                    
                    let totalCandles = candles.count
                    if totalCandles == 0 { return }
                    
                    // Simple logic: Draw mostly recent candles filling the screen
                    let maxVisible = Int(drawingWidth / zoomLevel) + 2
                    let endIndex = totalCandles - 1
                    let startIndex = max(0, endIndex - maxVisible)
                    
                    let visibleSlice = candles[startIndex...endIndex]
                    let highest = visibleSlice.map { $0.high }.max() ?? 100
                    let lowest = visibleSlice.map { $0.low }.min() ?? 0
                    let priceRange = highest - lowest
                    let yScale = drawingHeight / (priceRange == 0 ? 1 : priceRange)
                    
                    func yPos(_ price: Double) -> Double {
                        return drawingHeight - ((price - lowest) * yScale)
                    }
                    
                    for (offset, candle) in visibleSlice.enumerated() {
                        let indexFromEnd = endIndex - (startIndex + offset)
                        // x position from right side
                        let x = drawingWidth - (CGFloat(indexFromEnd) * zoomLevel) - (zoomLevel/2)
                        
                        if x < -zoomLevel { continue }
                        
                        let isUp = candle.close >= candle.open
                        let color = isUp ? upColor : downColor
                        
                        // Draw Wick
                        let wickPath = Path { p in
                            p.move(to: CGPoint(x: x, y: yPos(candle.high)))
                            p.addLine(to: CGPoint(x: x, y: yPos(candle.low)))
                        }
                        context.stroke(wickPath, with: .color(color), lineWidth: 1)
                        
                        // Draw Body
                        let bodyTop = yPos(max(candle.open, candle.close))
                        let bodyBottom = yPos(min(candle.open, candle.close))
                        let bodyHeight = max(1.0, abs(bodyTop - bodyBottom))
                        
                        let bodyRect = CGRect(
                            x: x - (zoomLevel * 0.4),
                            y: bodyTop,
                            width: zoomLevel * 0.8,
                            height: bodyHeight
                        )
                        context.fill(Path(bodyRect), with: .color(color))
                    }
                    
                    // Draw Crosshair
                    if let loc = crosshairLocation {
                        let hPath = Path { p in
                            p.move(to: CGPoint(x: 0, y: loc.y))
                            p.addLine(to: CGPoint(x: drawingWidth, y: loc.y))
                        }
                        context.stroke(hPath, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        
                        let vPath = Path { p in
                            p.move(to: CGPoint(x: loc.x, y: 0))
                            p.addLine(to: CGPoint(x: loc.x, y: drawingHeight))
                        }
                        context.stroke(vPath, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        
                        // Calculate price at Y
                        let priceAtY = lowest + ((drawingHeight - loc.y) / yScale)
                        let text = Text(String(format: "%.2f", priceAtY)).font(.caption).foregroundColor(.white)
                        context.draw(text, at: CGPoint(x: drawingWidth - 30, y: loc.y))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            crosshairLocation = value.location
                        }
                        .onEnded { _ in
                            crosshairLocation = nil
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let delta = val / 1.0
                            zoomLevel = max(2.0, min(50.0, lastZoomLevel * delta))
                        }
                        .onEnded { _ in
                            lastZoomLevel = zoomLevel
                        }
                )
                
                // Info Badge Overlay
                if let _ = crosshairLocation {
                    VStack {
                        Text("Pro Mode Active")
                            .font(.caption)
                            .padding(4)
                            .background(.black.opacity(0.6))
                            .cornerRadius(4)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08)) // Deep background
        .cornerRadius(12)
        .drawingGroup()
    }
}
