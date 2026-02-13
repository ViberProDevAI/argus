import SwiftUI
struct NeuralNetworkBackground: View {
    @State private var phase = 0.0
    
    var body: some View {
        Canvas { context, size in
            let points = (0..<20).map { _ in
                CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
            }
            
            for point in points {
                for other in points {
                    let dist =  hypot(point.x - other.x, point.y - other.y)
                    if dist < 100 {
                        var path = Path()
                        path.move(to: point)
                        path.addLine(to: other)
                        context.stroke(path, with: .color(SanctumTheme.ghostGrey.opacity(0.1 - (dist/1000))), lineWidth: 1)
                    }
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x-2, y: point.y-2, width: 4, height: 4)), with: .color(SanctumTheme.hologramBlue.opacity(0.3)))
            }
        }
        .opacity(0.3)
    }
}

struct SanctumMiniChart: View {
    let candles: [Candle]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minPrice = candles.map { $0.low }.min() ?? 0
            let maxPrice = candles.map { $0.high }.max() ?? 100
            let priceRange = maxPrice - minPrice
            
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Gradient Fill
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: height))
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                    
                    if index == candles.count - 1 {
                        path.addLine(to: CGPoint(x: xPosition, y: height))
                        path.closeSubpath()
                    }
                }
            }
            .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.01)]), startPoint: .top, endPoint: .bottom))
        }
    }
}
struct HermesInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SanctumTheme.hermesColor.opacity(0.8))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }
}
// MARK: - Error View
struct OrionMotherboardErrorView: View {
    let symbol: String
    
    var body: some View {
        VStack(spacing: 16) {
             Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(SanctumTheme.titanGold)
             
             Text("Analiz Başarısız")
                .font(.headline)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
             
             Text("Heimdall protokolü \(symbol) için teknik verileri derleyemedi. Lütfen internet bağlantısını kontrol edin veya daha sonra tekrar deneyin.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SanctumTheme.titanGold.opacity(0.3), lineWidth: 1)
        )
    }
}
