import SwiftUI

// MARK: - Unified Position Card
/// BIST ve Global piyasalar için tek, birleşik pozisyon kartı.
/// Görsel dili kurumsal tema ile sabitlenmiş ve Trade Brain karar katmanı ile zenginleştirilmiştir.

struct UnifiedPositionCard: View {
    let trade: Trade
    let currentPrice: Double
    let market: TradeMarket
    var onEdit: (() -> Void)?
    var onSell: (() -> Void)?

    @State private var plan: PositionPlan?
    @State private var delta: PositionDeltaTracker.PositionDelta?
    @State private var decision: ArgusGrandDecision?

    private var isBist: Bool { market == .bist }

    private var accentColor: Color {
        isBist ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.primary
    }

    private var positiveColor: Color {
        InstitutionalTheme.Colors.positive
    }

    private var negativeColor: Color {
        InstitutionalTheme.Colors.negative
    }

    private var pnlPercent: Double {
        guard trade.entryPrice > 0 else { return 0 }
        return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }

    private var pnlValue: Double {
        (currentPrice - trade.entryPrice) * trade.quantity
    }

    private var pnlColor: Color {
        pnlPercent >= 0 ? positiveColor : negativeColor
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
            priceProgressSection

            if let decision {
                Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
                decisionSection(decision)
            }

            Divider().overlay(InstitutionalTheme.Colors.borderSubtle)

            if let plan {
                planStatusSection(plan)
            } else {
                noPlanSection
            }

            if let delta {
                deltaBadgeSection(delta)
            }

            actionButtonsSection
        }
        .institutionalCard(scale: .insight, elevated: false)
        .onAppear(perform: refreshCardData)
        .onChange(of: currentPrice) { _ in
            refreshCardData()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(pnlColor.opacity(0.18))
                    .frame(width: 52, height: 52)

                Text(String(displaySymbol.prefix(4)))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displaySymbol)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Text(isBist ? "BIST" : "GLOBAL")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(InstitutionalTheme.Colors.surface3)
                        )
                }

                Text("\(String(format: "%.2f", trade.quantity)) adet @ \(formatPrice(trade.entryPrice))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(pnlColor)

                Text("\(pnlValue >= 0 ? "+" : "")\(formatPrice(pnlValue))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(pnlColor.opacity(0.9))
            }
        }
        .padding(InstitutionalTheme.Spacing.md)
    }

    private var priceProgressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let entryX = width / 2
                let offset = max(-width / 2 + 12, min(width / 2 - 12, CGFloat(pnlPercent) * 2.1))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                        .frame(height: 7)

                    Circle()
                        .fill(InstitutionalTheme.Colors.textSecondary)
                        .frame(width: 7, height: 7)
                        .position(x: entryX, y: 3.5)

                    Circle()
                        .fill(pnlColor)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(InstitutionalTheme.Colors.textPrimary, lineWidth: 1))
                        .position(x: entryX + offset, y: 3.5)
                }
            }
            .frame(height: 11)

            HStack {
                Text("Giriş \(formatPrice(trade.entryPrice))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("Anlık \(formatPrice(currentPrice))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(pnlColor)
            }
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, InstitutionalTheme.Spacing.sm)
    }

    private func decisionSection(_ decision: ArgusGrandDecision) -> some View {
        let education = decision.educationStage

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Konsey Kararı")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text(education.badgeText)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(education.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(education.color.opacity(0.17))
                    )
            }
            
            Text(education.title)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            HStack {
                metricTag(title: "Güven", value: "%\(Int(decision.confidence * 100))")
                metricTag(title: "Aether", value: decision.aetherDecision.stance.rawValue, valueColor: aetherColor(decision.aetherDecision.stance))
            }

            Text(education.disclaimer)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.warning)
                .lineLimit(1)
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, InstitutionalTheme.Spacing.sm)
    }

    private var noPlanSection: some View {
        HStack {
            Image(systemName: "doc.badge.plus")
                .foregroundColor(accentColor)
            Text("Akıllı plan oluşturulmadı")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            Button("Oluştur") { onEdit?() }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(accentColor)
        }
        .padding(InstitutionalTheme.Spacing.md)
        .background(InstitutionalTheme.Colors.surface3.opacity(0.45))
    }

    private func planStatusSection(_ plan: PositionPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(accentColor)
                Text("Plan: \(plan.intent.rawValue)")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                let executed = plan.executedSteps.count
                let total = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }.reduce(0) { $0 + $1.steps.count }
                Text("\(executed)/\(total)")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            if let activeScenario = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario]
                .compactMap({ $0 })
                .first(where: { $0.isActive }) {
                ForEach(activeScenario.steps.prefix(2)) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: plan.executedSteps.contains(step.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(plan.executedSteps.contains(step.id) ? positiveColor : InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 3)
                        Text(step.description)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(InstitutionalTheme.Spacing.md)
        .background(InstitutionalTheme.Colors.surface3.opacity(0.55))
    }

    private func deltaBadgeSection(_ delta: PositionDeltaTracker.PositionDelta) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Delta")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text(delta.significance.rawValue)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(significanceColor(delta.significance))
            }

            Text(delta.summaryText)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, InstitutionalTheme.Spacing.sm)
        .background(significanceColor(delta.significance).opacity(0.10))
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 10) {
            Button(action: { onEdit?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Yönet")
                }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: { onSell?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Kapat")
                }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(negativeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(negativeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(InstitutionalTheme.Spacing.md)
    }

    private func metricTag(title: String, value: String, valueColor: Color = InstitutionalTheme.Colors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.7))
        )
    }

    private var displaySymbol: String {
        isBist ? trade.symbol.replacingOccurrences(of: ".IS", with: "") : trade.symbol
    }

    private func formatPrice(_ value: Double) -> String {
        if isBist {
            return String(format: "₺%.2f", value)
        }
        return String(format: "$%.2f", value)
    }

    private func significanceColor(_ sig: PositionDeltaTracker.ChangeSignificance) -> Color {
        switch sig {
        case .low: return InstitutionalTheme.Colors.textSecondary
        case .medium: return InstitutionalTheme.Colors.primary
        case .high: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    private func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }

    private func aetherColor(_ stance: MacroStance) -> Color {
        switch stance {
        case .riskOn: return InstitutionalTheme.Colors.positive
        case .cautious: return InstitutionalTheme.Colors.warning
        case .defensive: return InstitutionalTheme.Colors.warning
        case .riskOff: return InstitutionalTheme.Colors.negative
        }
    }

    private func refreshCardData() {
        plan = PositionPlanStore.shared.getPlan(for: trade.id)
        decision = SignalStateViewModel.shared.grandDecisions[trade.symbol]

        guard let plan else {
            delta = nil
            return
        }

        let liveDecision = decision
        let liveOrionScore = SignalStateViewModel.shared.orionScores[trade.symbol]?.score ?? plan.originalSnapshot.orionScore
        delta = PositionDeltaTracker.shared.calculateDelta(
            for: trade,
            entrySnapshot: plan.originalSnapshot,
            currentOrionScore: liveOrionScore,
            currentGrandDecision: liveDecision,
            currentPrice: currentPrice,
            currentRSI: liveDecision?.orionDetails?.components.rsi
        )
    }
}
