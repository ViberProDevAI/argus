import SwiftUI

struct SanctumSignalCapsule: View {
    let signal: ArgusGrandDecision?
    let dataHealth: DataHealth?
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Data Quality Orb
            HStack(spacing: 4) {
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: healthColor.opacity(0.5), radius: 4)
                
                // Quality Score is Int (0-100)
                Text("KALİTE %\(dataHealth?.qualityScore ?? 0)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(healthColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(healthColor.opacity(0.1))
            
            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.1))
            
            // 2. Signal Action
            HStack(spacing: 4) {
                Text(signal?.action.rawValue.uppercased() ?? "NÖTR")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(signalColor)
                
                if let confidence = signal?.confidence {
                    Text(String(format: "%.0f", confidence * 100))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(signalColor.opacity(0.1))
        }
        .background(
            Capsule()
                .strokeBorder(LinearGradient(colors: [healthColor.opacity(0.3), signalColor.opacity(0.3)], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
                .background(Color.black.opacity(0.3))
        )
        .clipShape(Capsule())
    }
    
    private var healthColor: Color {
        let score = dataHealth?.qualityScore ?? 0
        if score >= 80 { return SanctumTheme.auroraGreen }
        if score >= 50 { return SanctumTheme.titanGold }
        return SanctumTheme.crimsonRed
    }
    
    private var signalColor: Color {
        guard let signal = signal else { return .gray }
        let score = signal.confidence * 100
        if score >= 70 { return SanctumTheme.auroraGreen }
        if score <= 30 { return SanctumTheme.crimsonRed }
        return SanctumTheme.titanGold
    }
}
