import SwiftUI

struct AssetChipView: View {
    let symbol: String
    let quantity: Double
    let currentPrice: Double?
    let entryPrice: Double
    let engine: AutoPilotEngine? // Optional, e.g. .corse, .pulse
    
    private var pnl: Double {
        guard let current = currentPrice else { return 0 }
        return (current - entryPrice) * quantity
    }
    
    private var pnlPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return (pnl / (entryPrice * quantity)) * 100
    }
    
    private var pnlColor: Color {
        if pnl > 0 { return Theme.positive }
        if pnl < 0 { return Theme.negative }
        return Theme.neutral
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Logo (Inset into glass)
            CompanyLogoView(symbol: symbol, size: 40)
                .clipShape(Circle())
                .shadow(color: Theme.tint.opacity(0.2), radius: 4)
            
            // 2. Info Column
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(symbol)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    // Engine Badge with Info
                    if let engine = engine {
                        HStack(spacing: 4) {
                            Text(engine == .corse ? "CORSE" : (engine == .pulse ? "PULSE" : "MANUEL"))
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    (engine == .corse ? Color.blue : (engine == .pulse ? Color.purple : Color.gray)).opacity(0.3)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            // Info Icon logic requires binding, simpler to just use button to show alert/sheet?
                            // Since this is inside a button (AssetChip is usually tapped), nested buttons are tricky.
                            // Better approach: AssetChip doesn't handle the tap, the parent does.
                            // But for now, let's keep it visual or use a high-z-index overlay if needed.
                            // User requested 'i' icon.
                            
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Text("\(String(format: "%.0f", quantity)) Adet")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    
                    if let price = currentPrice {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        
                        let symbolPrefix = symbol.hasSuffix(".IS") ? "₺" : "$"
                        Text("\(symbolPrefix)\(String(format: "%.2f", price))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            
            Spacer()
            
            // 3. Mini Sparkline (Placeholder for now, animated sine wave)
            SparklinePlaceholder(color: pnlColor)
                .frame(width: 40, height: 20)
                .opacity(0.5)
            
            Spacer().frame(width: 8)
            
            // 4. PnL Column
            VStack(alignment: .trailing, spacing: 2) {
                let currencySymbol = symbol.hasSuffix(".IS") ? "₺" : "$"
                Text("\(currencySymbol)\(String(format: "%.2f", pnl))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(pnlColor)
                    // Glow if profitable
                    .shadow(color: pnl > 0 ? pnlColor.opacity(0.5) : .clear, radius: 4)
                
                Text(String(format: "%.1f%%", pnlPercent))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(pnlColor.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            GlassCard(cornerRadius: 16) {
                // Dynamic backglow based on PnL?
                pnlColor.opacity(0.05)
            }
        )
    }
}

// Simple placeholder for sparkline
struct SparklinePlaceholder: View {
    let color: Color
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Path { path in
            let width: CGFloat = 40
            let height: CGFloat = 20
            let mid = height / 2
            
            path.move(to: CGPoint(x: 0, y: mid))
            for x in stride(from: 0, through: width, by: 1) {
                let relativeX = x / width
                let sine = sin(relativeX * .pi * 2 + phase)
                let y = mid + sine * (height * 0.4)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(color, lineWidth: 1.5)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
