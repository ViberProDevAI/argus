import SwiftUI
import CoreMotion

// A card that reacts to device tilt (Gyroscope) to give a 3D hologram feel.
// A card that reacts to device tilt (Gyroscope) to give a 3D hologram feel.
struct HolographicBalanceCard: View {
    @ObservedObject var viewModel: TradingViewModel
    var mode: TradeMarket = .global // Default to Global
    
    @State private var pitch: Double = 0.0
    @State private var roll: Double = 0.0
    private let motionManager = CMMotionManager()
    
    // Dynamic Properties based on Mode
    var equity: Double {
        switch mode {
        case .global: return viewModel.getEquity()
        case .bist: return calculateBistEquity()
        }
    }
    
    var balance: Double {
        switch mode {
        case .global: return viewModel.balance
        case .bist: return viewModel.bistBalance
        }
    }
    
    var realized: Double {
        switch mode {
        case .global: return viewModel.getRealizedPnL()
        case .bist: return calculateBistRealized()
        }
    }
    
    var unrealized: Double {
        switch mode {
        case .global: return viewModel.getUnrealizedPnL()
        case .bist: return calculateBistUnrealized()
        }
    }
    
    var currencySymbol: String {
        return mode == .global ? "$" : "₺"
    }
    
    var themeColor: Color {
        return mode == .global ? Theme.accent : Color.orange
    }
    
    var themeSecondary: Color {
        return mode == .global ? Theme.primary : Color.red
    }
    
    var cardTitle: String {
        return mode == .global ? "ARGUS PORTFOLIO" : "BIST PORTFÖY"
    }
    
    // BIST Helpers - Artık ViewModel fonksiyonlarını kullanıyoruz
    private func calculateBistEquity() -> Double {
        return viewModel.getBistEquity()
    }
    
    private func calculateBistRealized() -> Double {
        // BIST realized calculation (Tüm kapalı BIST işlemlerinden)
        return viewModel.portfolio
            .filter { !$0.isOpen && ($0.symbol.hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0.symbol)) }
            .reduce(0.0) { $0 + $1.profit }
    }
    
    private func calculateBistUnrealized() -> Double {
        return viewModel.getBistUnrealizedPnL()
    }
    
    var body: some View {
        ZStack {
            // 1. Cyber Glass Background
            GlassCard(cornerRadius: 24, brightness: 0.05) {
                ZStack {
                    // Moving Gradient (based on tilt)
                    RadialGradient(
                        colors: [themeColor.opacity(0.3), .clear],
                        center: UnitPoint(x: 0.5 + roll * 0.2, y: 0.5 + pitch * 0.2),
                        startRadius: 20,
                        endRadius: 200
                    )
                    
                    // Grid Pattern overlay
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [.white.opacity(0.03), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .mask(
                            Image(systemName: "square.grid.3x3.fill") // Placeholder for grid texture
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(2)
                                .opacity(0.1)
                        )
                }
            }
            .shadow(color: themeColor.opacity(0.3), radius: 15, x: 0, y: 5)
            .rotation3DEffect(
                .degrees(pitch * 10),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(roll * 10),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // 2. Content Layer (Floating above)
            VStack(alignment: .leading, spacing: 20) {
                // Header: Identity
                HStack {
                    Image(systemName: mode == .global ? "eye.circle.fill" : "turkishlirasign.circle.fill")
                        .foregroundColor(themeSecondary)
                    Text(cardTitle)
                        .font(.caption)
                        .bold()
                        .tracking(2)
                        .foregroundColor(themeSecondary)
                    
                    Spacer()
                    
                    // Live Status Pulse
                    Circle()
                        .fill(Theme.positive)
                        .frame(width: 6, height: 6)
                        .shadow(color: Theme.positive, radius: 4)
                }
                
                // Balance Big
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOPLAM VARLIK")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1)
                    
                    Text("\(currencySymbol)\(String(format: "%.0f", equity))")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: themeColor.opacity(0.5), radius: 10)
                }
                
                // Stat Row
                HStack(spacing: 24) {
                    statItem(label: "NAKİT", value: balance, color: themeColor)
                    statItem(label: "K/Z (R)", value: realized, color: realized >= 0 ? Theme.positive : Theme.negative)
                    statItem(label: "ANLIK", value: unrealized, color: unrealized >= 0 ? Theme.positive : Theme.negative)
                }
            }
            .padding(24)
            // Parallax Effect for content (moves opposite to background tilt)
            .offset(x: roll * 10, y: pitch * 10)
        }
        .frame(height: 220)
        .onAppear(perform: startMotionUpdates)
    }
    
    private func statItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Text("\(currencySymbol)\(String(format: "%.0f", value))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion = motion else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                self.pitch = motion.attitude.pitch
                self.roll = motion.attitude.roll
            }
        }
    }
}
