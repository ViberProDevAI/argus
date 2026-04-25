import SwiftUI

struct MarketMemoryBar: View {
    let regimeContext: RegimeDecisionContext
    let eventContext: EventDecisionContext
    
    private var overallRiskScore: Double {
        (regimeContext.riskScore + eventContext.riskScore) / 2
    }
    
    private var riskColor: Color {
        if overallRiskScore > 0.6 {
            return InstitutionalTheme.Colors.negative
        } else if overallRiskScore > 0.3 {
            return InstitutionalTheme.Colors.warning
        }
        return InstitutionalTheme.Colors.positive
    }
    
    private var regimeIcon: String {
        switch regimeContext.regime {
        case "Risk On": return "figure.run"
        case "Risk Off": return "shield.fill"
        default: return "equal.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Text("Pazar Hafizasi")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text("%\(Int(overallRiskScore * 100)) Risk")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(riskColor)
            }
            
            HStack(spacing: 12) {
                RegimeBadge(context: regimeContext)
                EventBadge(context: eventContext)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(riskColor)
                        .frame(width: geo.size.width * overallRiskScore)
                }
            }
            .frame(height: 6)
            
            Text(regimeContext.recommendation)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            if !eventContext.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(eventContext.warnings.prefix(2), id: \.self) { warning in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(InstitutionalTheme.Colors.warning)
                            Text(warning)
                                .font(InstitutionalTheme.Typography.micro)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(InstitutionalCardScale.standard.padding)
        .institutionalCard(scale: .standard)
    }
}

struct RegimeBadge: View {
    let context: RegimeDecisionContext
    
    private var regimeColor: Color {
        switch context.regime {
        case "Risk On": return InstitutionalTheme.Colors.positive
        case "Risk Off": return InstitutionalTheme.Colors.negative
        default: return InstitutionalTheme.Colors.neutral
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: context.regime == "Risk On" ? "figure.run" : (context.regime == "Risk Off" ? "shield.fill" : "equal.circle.fill"))
                    .font(.system(size: 12))
                Text(context.regime)
                    .font(InstitutionalTheme.Typography.caption)
            }
            .foregroundColor(regimeColor)
            
            HStack(spacing: 4) {
                Text("VIX")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(String(format: "%.1f", context.vix))
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            Text("Gecmis: %\(Int(context.historicalWinRate * 100))")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(regimeColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(regimeColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EventBadge: View {
    let context: EventDecisionContext
    
    private var eventColor: Color {
        if context.hasHighImpactEvent {
            return InstitutionalTheme.Colors.negative
        } else if context.eventCount > 0 {
            return InstitutionalTheme.Colors.warning
        }
        return InstitutionalTheme.Colors.positive
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: context.eventCount > 0 ? "calendar.badge.clock" : "calendar.badge.checkmark")
                    .font(.system(size: 12))
                Text(context.eventCount > 0 ? "\(context.eventCount) Olay" : "Temiz")
                    .font(InstitutionalTheme.Typography.caption)
            }
            .foregroundColor(eventColor)
            
            Text(context.hasHighImpactEvent ? "Yuksek Etkili" : "Normal")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(context.hasHighImpactEvent ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textTertiary)
            
            Text("Risk: %\(Int(context.riskScore * 100))")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(eventColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(eventColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct MemoryInsightCard: View {
    let title: String
    let value: String
    let trend: String?
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(value)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            Spacer()
            
            if let trend = trend {
                Text(trend)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(color)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.5))
        )
    }
}

#Preview {
    VStack {
        MarketMemoryBar(
            regimeContext: RegimeDecisionContext(
                regime: "Risk On",
                vix: 16.5,
                historicalWinRate: 0.62,
                riskScore: 0.25,
                recommendation: "Risk ortami elverisli"
            ),
            eventContext: EventDecisionContext(
                hasHighImpactEvent: false,
                riskScore: 0.15,
                warnings: ["FED Toplantisi 3 gun"],
                eventCount: 1
            )
        )
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
