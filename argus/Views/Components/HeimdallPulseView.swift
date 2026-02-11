import SwiftUI

struct HeimdallPulseView: View {
    let status: HeimdallOrchestrator.SystemHealthStatus
    @State private var isPulsing = false
    
    var color: Color {
        switch status {
        case .operational: return .green
        case .degraded: return .yellow
        case .critical: return .red
        }
    }
    
    var body: some View {
        ZStack {
            // Outer Glow
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 140, height: 140)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .opacity(isPulsing ? 0 : 0.5)
                .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false), value: isPulsing)
            
            // Middle Ring
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(isPulsing ? 1.1 : 0.9)
                .opacity(isPulsing ? 0 : 1)
                .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false).delay(0.5), value: isPulsing)
            
            // Core Shield
            ZStack {
                Circle()
                    .fill(Theme.background)
                    .frame(width: 80, height: 80)
                    .shadow(color: color.opacity(0.5), radius: 10, x: 0, y: 0)
                
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Image(systemName: "eye.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.background)
                    .offset(y: -4)
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}
