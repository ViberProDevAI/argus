import SwiftUI

struct ChimeraRadarView: View {
    let dna: ChimeraDna
    
    var body: some View {
        ZStack {
            // Background Web
            RadarShape(values: [1, 1, 1, 1, 1])
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            
            RadarShape(values: [0.5, 0.5, 0.5, 0.5, 0.5])
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            
            // Data Shape
            RadarShape(values: [
                dna.momentum / 100.0,
                dna.trend / 100.0,
                dna.value / 100.0,
                dna.sentiment / 100.0,
                dna.structure / 100.0
            ])
            .fill(LinearGradient(
                gradient: Gradient(colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.2)]),
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay(
                RadarShape(values: [
                    dna.momentum / 100.0,
                    dna.trend / 100.0,
                    dna.value / 100.0,
                    dna.sentiment / 100.0,
                    dna.structure / 100.0
                ])
                .stroke(Color.cyan, lineWidth: 2)
            )
            
            // Labels
            RadarLabels()
        }
        .frame(height: 200)
    }
}

struct RadarShape: Shape {
    var values: [Double] // 5 values between 0-1
    
    func path(in rect: CGRect) -> Path {
        guard values.count == 5 else { return Path() }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleStep = (2 * Double.pi) / 5
        var path = Path()
        
        for (i, value) in values.enumerated() {
            let angle = CGFloat(i) * CGFloat(angleStep) - CGFloat.pi / 2
            let x = center.x + CGFloat(cos(angle)) * radius * CGFloat(value)
            let y = center.y + CGFloat(sin(angle)) * radius * CGFloat(value)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct RadarLabels: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let labels = ["MOM", "TREND", "DEĞER", "ALGI", "YAPI"]
            
            ForEach(0..<5) { i in
                let angle = CGFloat(i) * (2 * CGFloat.pi / 5) - CGFloat.pi / 2
                let labelRadius = radius + 20
                let x = center.x + cos(angle) * labelRadius
                let y = center.y + sin(angle) * labelRadius
                
                Text(labels[i])
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .position(x: x, y: y)
            }
        }
    }
}
