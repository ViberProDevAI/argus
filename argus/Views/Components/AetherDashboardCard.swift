import SwiftUI

// MARK: - Aether v5 Premium Dashboard Card
struct AetherDashboardCard: View {
    let rating: MacroEnvironmentRating
    var isCompact: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: isCompact ? 12 : 20) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("AETHER")
                        .font(.caption)
                        .bold()
                        .tracking(2)
                        .foregroundColor(.cyan)
                }
                
                Spacer()
                
                // Regime Badge
                Text(rating.regime.rawValue)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(regimeColor.opacity(0.2))
                    .foregroundColor(regimeColor)
                    .clipShape(Capsule())
            }
            
            if !isCompact {
                // Main Score
                HStack(spacing: 20) {
                    // Big Score Circle
                    ZStack {
                        Circle()
                            .stroke(Theme.border.opacity(0.3), lineWidth: 6)
                            .frame(width: 90, height: 90)
                        
                        Circle()
                            .trim(from: 0, to: rating.numericScore / 100)
                            .stroke(
                                LinearGradient(colors: scoreGradient, startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(Int(rating.numericScore))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("/ 100")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    // Category Breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        CategoryRow(
                            icon: "🟢",
                            label: "Öncü",
                            score: rating.leadingScore ?? 50,
                            weight: "x1.5"
                        )
                        CategoryRow(
                            icon: "🟡",
                            label: "Eşzamanlı",
                            score: rating.coincidentScore ?? 50,
                            weight: "x1.0"
                        )
                        CategoryRow(
                            icon: "🔴",
                            label: "Gecikmeli",
                            score: rating.laggingScore ?? 50,
                            weight: "x0.8"
                        )
                    }
                }
            } else {
                // Ultra Compact: Single row
                HStack(spacing: 10) {
                    // Small Score Circle
                    ZStack {
                        Circle()
                            .stroke(scoreGradient[0].opacity(0.3), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        Circle()
                            .trim(from: 0, to: rating.numericScore / 100)
                            .stroke(scoreGradient[0], style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(rating.numericScore))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(scoreGradient[0])
                    }
                    
                    Spacer()
                    
                    // Mini Category Pills
                    HStack(spacing: 6) {
                        MiniCategoryPill(emoji: "🟢", score: rating.leadingScore ?? 50)
                        MiniCategoryPill(emoji: "🟡", score: rating.coincidentScore ?? 50)
                        MiniCategoryPill(emoji: "🔴", score: rating.laggingScore ?? 50)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
            }
        }
        .padding(isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [scoreGradient[0].opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
    
    // MARK: - Helpers
    
    private var regimeColor: Color {
        switch rating.regime {
        case .riskOn: return .green
        case .neutral: return .yellow
        case .riskOff: return .red
        }
    }
    
    private var scoreGradient: [Color] {
        let score = rating.numericScore
        if score >= 70 { return [.green, .mint] }
        if score >= 50 { return [.yellow, .orange] }
        return [.red, .pink]
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let icon: String
    let label: String
    let score: Double
    let weight: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 12))
            
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            // Mini Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.border.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(scoreColor)
                        .frame(width: geo.size.width * (score / 100), height: 4)
                }
            }
            .frame(width: 50, height: 4)
            
            Text("\(Int(score))")
                .font(.caption)
                .bold()
                .foregroundColor(scoreColor)
                .frame(width: 25, alignment: .trailing)
            
            Text(weight)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.6))
                .frame(width: 28, alignment: .trailing)
        }
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Mini Category Pill
struct MiniCategoryPill: View {
    let emoji: String
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 10))
            Text("\(Int(score))")
                .font(.caption2)
                .bold()
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(scoreColor.opacity(DesignTokens.Opacity.glassCard))
        .clipShape(Capsule())
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Full Version
        AetherDashboardCard(
            rating: MacroEnvironmentRating(
                equityRiskScore: 72, volatilityScore: 85, safeHavenScore: 55,
                cryptoRiskScore: 78, interestRateScore: 60, currencyScore: 62,
                inflationScore: 65, laborScore: 76, growthScore: 80,
                creditSpreadScore: 70, claimsScore: 82,
                leadingScore: 74, coincidentScore: 68, laggingScore: 65,
                leadingContribution: 33.6, coincidentContribution: 20.6, laggingContribution: 15.8,
                numericScore: 72, letterGrade: "B+", regime: .riskOn,
                summary: "Aether v5", details: ""
            )
        )
        
        // Compact Version
        AetherDashboardCard(
            rating: MacroEnvironmentRating(
                equityRiskScore: 72, volatilityScore: 85, safeHavenScore: 55,
                cryptoRiskScore: 78, interestRateScore: 60, currencyScore: 62,
                inflationScore: 65, laborScore: 76, growthScore: 80,
                creditSpreadScore: 70, claimsScore: 82,
                leadingScore: 74, coincidentScore: 68, laggingScore: 65,
                leadingContribution: 33.6, coincidentContribution: 20.6, laggingContribution: 15.8,
                numericScore: 72, letterGrade: "B+", regime: .riskOn,
                summary: "Aether v5", details: ""
            ),
            isCompact: true
        )
    }
    .padding()
    .background(Theme.background)
}

