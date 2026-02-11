import SwiftUI

struct AetherHUDView: View {
    let rating: MacroEnvironmentRating?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let r = rating {
                // Ultra Compact Card
                HStack(spacing: 12) {
                    // Score
                    ZStack {
                        Circle()
                            .stroke(scoreColor(r.numericScore).opacity(0.3), lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: r.numericScore / 100)
                            .stroke(scoreColor(r.numericScore), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(r.numericScore))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor(r.numericScore))
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("AETHER")
                                .font(.caption2)
                                .bold()
                                .tracking(1)
                                .foregroundColor(.cyan)
                        }
                        Text(r.regime.rawValue)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Mini Category Pills
                    HStack(spacing: 4) {
                        MiniPill(emoji: "", score: r.leadingScore ?? 50)
                        MiniPill(emoji: "", score: r.coincidentScore ?? 50)
                        MiniPill(emoji: "", score: r.laggingScore ?? 50)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(scoreColor(r.numericScore).opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
            } else {
                // Loading State
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Aether Yükleniyor...")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Theme.secondaryBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// Mini Pill for compact view
struct MiniPill: View {
    let emoji: String
    let score: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 8))
            Text("\(Int(score))")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(scoreColor.opacity(DesignTokens.Opacity.glassCard))
        .clipShape(Capsule())
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}
