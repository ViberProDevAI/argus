import SwiftUI

struct TechnicalConsensusView: View {
    let breakdown: OrionSignalBreakdown
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Header & Gauge
            VStack {
                Text("TEKNİK KONSENSUS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    GaugeView(value: consensusValue)
                        .frame(height: 120)
                    
                    VStack {
                        Spacer()
                        Text(breakdown.summary.dominant)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(dominantColor)
                        
                        Text("\(breakdown.summary.buy) AL : \(breakdown.summary.sell) SAT")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .offset(y: 20)
                }
            }
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .cornerRadius(12)
            
            // 2. Breakdown Grid
            HStack(alignment: .top, spacing: 12) {
                // Oscillators Column
                SignalColumn(title: "OSİLATÖRLER", 
                             vote: breakdown.oscillators, 
                             signals: breakdown.indicators.filter { isOscillator($0.name) })
                
                // Moving Averages Column
                SignalColumn(title: "HAREKETLİ ORT.", 
                             vote: breakdown.movingAverages, 
                             signals: breakdown.indicators.filter { !isOscillator($0.name) })
            }
        }
        .padding(.horizontal)
    }
    
    // -1 (Strong Sell) to 1 (Strong Buy)
    var consensusValue: Double {
        let total = Double(breakdown.summary.total)
        if total == 0 { return 0 }
        let net = Double(breakdown.summary.buy - breakdown.summary.sell)
        return net / total 
    }
    
    var dominantColor: Color {
        if breakdown.summary.dominant == "AL" { return .green }
        if breakdown.summary.dominant == "SAT" { return .red }
        return .gray
    }
    
    func isOscillator(_ name: String) -> Bool {
        let oscs = ["RSI", "Stoch", "CCI", "Williams", "Momentum", "MACD Level", "Aroon"]
        return oscs.contains { name.contains($0) }
    }
}

struct SignalColumn: View {
    let title: String
    let vote: VoteCount
    let signals: [OrionSignalBreakdown.SignalItem]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                Text("A:\(vote.buy) S:\(vote.sell) N:\(vote.neutral)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(10)
            .background(Color(red: 0.15, green: 0.15, blue: 0.18))
            
            // List
            ForEach(signals, id: \.name) { signal in
                HStack {
                    Text(signal.name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(signal.action)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(color(for: signal.action))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color(for: signal.action).opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(10)
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.black),
                    alignment: .bottom
                )
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func color(for action: String) -> Color {
        switch action {
        case "AL": return .green
        case "SAT": return .red
        default: return .gray
        }
    }
}

// Simple Gauge implementation using Canvas
struct GaugeView: View {
    let value: Double // -1.0 to 1.0
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height)
            let radius = min(size.width / 2, size.height) - 10
            
            // Draw Arc Background (Red to Green)
            // Left (Sell - Red)
            let pathRed = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(240), clockwise: false)
            }
            context.stroke(pathRed, with: .color(.red), lineWidth: 12)
            
            // Middle-Left (Weak Sell - Orange)
            let pathOrange = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(240), endAngle: .degrees(270), clockwise: false)
            }
            context.stroke(pathOrange, with: .color(.orange), lineWidth: 12)
            
            // Middle-Right (Weak Buy - Blue/Yellow)
            let pathYellow = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(270), endAngle: .degrees(300), clockwise: false)
            }
            context.stroke(pathYellow, with: .color(.blue), lineWidth: 12)
            
            // Right (Strong Buy - Green)
            let pathGreen = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(300), endAngle: .degrees(360), clockwise: false)
            }
            context.stroke(pathGreen, with: .color(.green), lineWidth: 12)
            
            // Needle
            let angle = 180 + ((value + 1.0) / 2.0) * 180 // Map -1..1 to 180..360
            let needleEnd = CGPoint(
                x: center.x + Foundation.cos(Angle(degrees: angle).radians) * (radius - 20),
                y: center.y + Foundation.sin(Angle(degrees: angle).radians) * (radius - 20)
            )
            
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: needleEnd)
            
            context.stroke(needle, with: .color(.white), lineWidth: 4)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.white))
        }
    }
}
