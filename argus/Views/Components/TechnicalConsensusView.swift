import SwiftUI

struct TechnicalConsensusView: View {
    let breakdown: OrionSignalBreakdown
    
    var body: some View {
        VStack(spacing: 14) {
            // 1. Header & Gauge
            VStack(spacing: 12) {
                Text("TEKNİK KONSENSUS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    .offset(y: 20)
                }
            }
            .padding()
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
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
        if breakdown.summary.dominant == "AL" { return InstitutionalTheme.Colors.positive }
        if breakdown.summary.dominant == "SAT" { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.textSecondary
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
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("A:\(vote.buy) S:\(vote.sell) N:\(vote.neutral)")
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .padding(4)
                    .background(InstitutionalTheme.Colors.surface3)
                    .cornerRadius(4)
            }
            .padding(10)
            .background(InstitutionalTheme.Colors.surface2)
            
            // List
            ForEach(signals, id: \.name) { signal in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.name)
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(signal.value)
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
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
                .background(InstitutionalTheme.Colors.surface1)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(InstitutionalTheme.Colors.borderSubtle),
                    alignment: .bottom
                )
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    func color(for action: String) -> Color {
        switch action {
        case "AL": return InstitutionalTheme.Colors.positive
        case "SAT": return InstitutionalTheme.Colors.negative
        default: return InstitutionalTheme.Colors.warning
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
            context.stroke(pathRed, with: .color(InstitutionalTheme.Colors.negative), lineWidth: 12)
            
            // Middle-Left (Weak Sell - Orange)
            let pathOrange = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(240), endAngle: .degrees(270), clockwise: false)
            }
            context.stroke(pathOrange, with: .color(InstitutionalTheme.Colors.warning), lineWidth: 12)
            
            // Middle-Right (Weak Buy - Blue/Yellow)
            let pathYellow = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(270), endAngle: .degrees(300), clockwise: false)
            }
            context.stroke(pathYellow, with: .color(InstitutionalTheme.Colors.primary), lineWidth: 12)
            
            // Right (Strong Buy - Green)
            let pathGreen = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(300), endAngle: .degrees(360), clockwise: false)
            }
            context.stroke(pathGreen, with: .color(InstitutionalTheme.Colors.positive), lineWidth: 12)
            
            // Needle
            let angle = 180 + ((value + 1.0) / 2.0) * 180 // Map -1..1 to 180..360
            let needleEnd = CGPoint(
                x: center.x + Foundation.cos(Angle(degrees: angle).radians) * (radius - 20),
                y: center.y + Foundation.sin(Angle(degrees: angle).radians) * (radius - 20)
            )
            
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: needleEnd)
            
            context.stroke(needle, with: .color(InstitutionalTheme.Colors.textPrimary), lineWidth: 4)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                with: .color(InstitutionalTheme.Colors.textPrimary)
            )
        }
    }
}
