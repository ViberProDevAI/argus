import SwiftUI

struct MultiHorizonDecisionCard: View {
    let decision: MultiHorizonDecision
    
    private var primaryActionColor: Color {
        actionColor(for: decision.primaryRecommendation.action)
    }
    
    private func actionColor(for action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.neutral
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(decision.symbol)
                    .font(InstitutionalTheme.Typography.headline)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(decision.primaryRecommendation.action.rawValue)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(primaryActionColor)
                    )
            }
            
            HStack(spacing: 8) {
                HorizonBadge(
                    title: "Scalp",
                    action: decision.scalp.action,
                    confidence: decision.scalp.confidence,
                    isPrimary: decision.primaryRecommendation.timeframe == .scalp
                )
                HorizonBadge(
                    title: "Swing",
                    action: decision.swing.action,
                    confidence: decision.swing.confidence,
                    isPrimary: decision.primaryRecommendation.timeframe == .swing
                )
                HorizonBadge(
                    title: "Position",
                    action: decision.position.action,
                    confidence: decision.position.confidence,
                    isPrimary: decision.primaryRecommendation.timeframe == .position
                )
            }
            
            Text(decision.primaryRecommendation.reasoning)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(3)
            
            ConfidenceBar(
                rawConfidence: decision.overallConfidence,
                calibratedConfidence: decision.calibratedConfidence,
                showLabel: true
            )
            
            HStack {
                Text(decision.primaryRecommendation.timeframe.displayTitle)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text(decision.timestamp.formatted(.dateTime.hour().minute()))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .padding(InstitutionalCardScale.standard.padding)
        .institutionalCard(scale: .standard, elevated: true)
    }
}

struct HorizonBadge: View {
    let title: String
    let action: ArgusAction
    let confidence: Double
    let isPrimary: Bool
    
    private var actionColor: Color {
        switch action {
        case .aggressiveBuy, .accumulate: return InstitutionalTheme.Colors.positive
        case .neutral: return InstitutionalTheme.Colors.neutral
        case .trim, .liquidate: return InstitutionalTheme.Colors.negative
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(isPrimary ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textTertiary)
            
            Text(action.rawValue.prefix(1))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isPrimary ? actionColor : InstitutionalTheme.Colors.textSecondary)
            
            Text("%\(Int(confidence * 100))")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(isPrimary ? actionColor.opacity(0.15) : InstitutionalTheme.Colors.surface3.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(isPrimary ? actionColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

struct HorizonIndicatorRow: View {
    let timeframe: TimeFrame
    let indicators: [String: String]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(indicators.prefix(4)), id: \.key) { key, value in
                VStack(spacing: 2) {
                    Text(key)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(value)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3.opacity(0.6))
                )
            }
        }
    }
}

#Preview {
    VStack {
        MultiHorizonDecisionCard(
            decision: MultiHorizonDecision(
                symbol: "AAPL",
                scalp: HorizonDecision(
                    timeframe: .scalp,
                    action: .trim,
                    reasoning: "RSI overbought",
                    confidence: 0.65,
                    indicators: ["RSI": "72", "Trend": "down"],
                    timestamp: Date()
                ),
                swing: HorizonDecision(
                    timeframe: .swing,
                    action: .accumulate,
                    reasoning: "Strong technical setup",
                    confidence: 0.72,
                    indicators: ["Orion": "68", "Atlas": "75"],
                    timestamp: Date()
                ),
                position: HorizonDecision(
                    timeframe: .position,
                    action: .accumulate,
                    reasoning: "Good fundamentals",
                    confidence: 0.78,
                    indicators: ["Atlas": "75", "Rejim": "Risk On"],
                    timestamp: Date()
                ),
                primaryRecommendation: HorizonDecision(
                    timeframe: .swing,
                    action: .accumulate,
                    reasoning: "Swing timeframe best aligned",
                    confidence: 0.72,
                    indicators: [:],
                    timestamp: Date()
                ),
                overallConfidence: 0.72,
                calibratedConfidence: 0.65,
                timestamp: Date()
            )
        )
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
