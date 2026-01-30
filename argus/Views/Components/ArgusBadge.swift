import SwiftUI

struct ArgusBadge: View {
    let score: Double
    var showLabel: Bool = true
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: 6) {
            // 1. Icon
            ArgusEyeView(mode: .argus, size: size)
            
            // 2. Text (Horizontal)
            if showLabel {
                Text("ARGUS")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .tracking(1) // Slight spacing for premium feel
                    .foregroundColor(Theme.tint)
            }
            
            // 3. Score
            Text("\(Int(score))")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scoreColor(score))
                .cornerRadius(6)
        }
        .padding(6)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return Theme.positive }
        if score <= 40 { return Theme.negative }
        return .orange
    }
}
