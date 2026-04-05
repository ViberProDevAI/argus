import SwiftUI

// MARK: - Unified Position Card
/// Portföy kartı: konsey kararı, plan adımları ve chimera sinyalini tek akışta gösterir.

struct UnifiedPositionCard: View {
    let trade: Trade
    let currentPrice: Double
    let market: TradeMarket
    var onEdit: (() -> Void)?
    var onSell: (() -> Void)?

    @State private var plan: PositionPlan?
    @State private var delta: PositionDeltaTracker.PositionDelta?
    @State private var decision: ArgusGrandDecision?
    @State private var chimeraSignal: ChimeraSignal?

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

    private var holdingDays: Int {
        Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
    }

    private var conviction: ConvictionState? {
        guard let decision else { return nil }
        return ConvictionDecayEngine.compute(
            councilConfidence: decision.confidence,
            daysHeld: holdingDays,
            pnlPercent: pnlPercent,
            action: decision.action,
            regime: ChironRegimeEngine.shared.lastResult.regime
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
            priceProgressSection

            if decision != nil || chimeraSignal != nil {
                Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
                decisionAndSignalSection
            }

            Divider().overlay(InstitutionalTheme.Colors.borderSubtle)

            if let plan {
                planStatusSection(plan)
            } else {
                noPlanSection
            }

            if let delta, delta.significance != .low {
                deltaBadgeSection(delta)
            }

            actionButtonsSection
        }
        .institutionalCard(scale: .insight, elevated: false)
        .onAppear(perform: refreshCardData)
        .onChange(of: currentPrice) { _, _ in
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

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(displaySymbol)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    tagPill(
                        text: isBist ? "BIST" : "GLOBAL",
                        color: accentColor
                    )
                }

                HStack(spacing: 6) {
                    Text("\(String(format: "%.2f", trade.quantity)) adet")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                    Text("•")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)

                    Text("\(holdingDays) gün")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }

                if let intent = plan?.intent, intent != .undefined {
                    tagPill(
                        text: intent.rawValue,
                        color: Color(intent.colorName)
                    )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatPrice(currentPrice))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

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
        let stop = stopPrice(from: plan) ?? (trade.entryPrice * 0.90)
        let target = targetPrice(from: plan) ?? (trade.entryPrice * 1.12)
        let span = max(target - stop, 0.0001)
        let entryPosition = max(0, min(1, (trade.entryPrice - stop) / span))
        let currentPosition = max(0, min(1, (currentPrice - stop) / span))

        return VStack(spacing: 10) {
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(pnlColor.opacity(0.45))
                        .frame(width: width * currentPosition, height: 8)

                    Circle()
                        .fill(InstitutionalTheme.Colors.textSecondary)
                        .frame(width: 8, height: 8)
                        .position(x: width * entryPosition, y: 4)

                    Circle()
                        .fill(pnlColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(InstitutionalTheme.Colors.textPrimary, lineWidth: 1))
                        .position(x: width * currentPosition, y: 4)
                }
            }
            .frame(height: 12)

            HStack {
                Text("Stop \(formatPrice(stop))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.negative.opacity(0.9))
                Spacer()
                Text("Giriş \(formatPrice(trade.entryPrice))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("Hedef \(formatPrice(target))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.positive.opacity(0.9))
            }
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, InstitutionalTheme.Spacing.sm)
    }

    private var decisionAndSignalSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Argus görüşü — aksiyon + piyasa durumu, sade Türkçe
            if let decision {
                HStack(spacing: 6) {
                    tagPill(text: humanAction(decision.action), color: actionColor(decision.action))
                    tagPill(
                        text: humanStance(decision.aetherDecision.stance),
                        color: aetherColor(decision.aetherDecision.stance)
                    )
                    Spacer()
                }
            }

            // Conviction — güven çürümesi göstergesi
            if let cv = conviction {
                ConvictionMeterView(conviction: cv)
            }

            // Chimera sinyali — yalnızca belirgin olunca, düz Türkçe
            if let cs = chimeraSignal, cs.severity >= 0.45 {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(chimeraColor(cs.type))
                    Text(humanChimeraSignal(cs))
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(chimeraColor(cs.type))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(chimeraColor(cs.type).opacity(0.10))
                )
            }
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, InstitutionalTheme.Spacing.sm)
    }

    private var noPlanSection: some View {
        HStack {
            Image(systemName: "doc.badge.plus")
                .foregroundColor(accentColor)
            Text("Bu pozisyon için plan henüz oluşturulmadı")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            Button("Plan Oluştur") { onEdit?() }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(accentColor)
        }
        .padding(InstitutionalTheme.Spacing.md)
        .background(InstitutionalTheme.Colors.surface3.opacity(0.45))
    }

    private func planStatusSection(_ plan: PositionPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundColor(accentColor)
                Text("Plan")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text("\(plan.completedStepCount)/\(plan.totalStepCount)")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface2)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accentColor.opacity(0.85))
                        .frame(width: geo.size.width * plan.completionRatio)
                }
            }
            .frame(height: 8)

            if let nextStep = plan.nextPendingStep {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nextStep.trigger.displayText)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(nextStep.action.displayText)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if let distance = triggerDistanceText(nextStep.trigger, plan: plan) {
                        Text(distance)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(accentColor)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(accentColor.opacity(0.10))
                )
            }

            if let riskStep = plan.primaryRiskStep {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.warning)
                    Text("Risk adımı: \(riskStep.trigger.displayText)")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(InstitutionalTheme.Spacing.md)
        .background(InstitutionalTheme.Colors.surface3.opacity(0.55))
    }

    private func deltaBadgeSection(_ delta: PositionDeltaTracker.PositionDelta) -> some View {
        HStack(spacing: 8) {
            Image(systemName: delta.significance == .critical ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
                .foregroundColor(significanceColor(delta.significance))
            Text(delta.summaryText)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, InstitutionalTheme.Spacing.md)
        .padding(.vertical, 8)
        .background(significanceColor(delta.significance).opacity(0.07))
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 10) {
            Button(action: { onEdit?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Planla")
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

    private func tagPill(text: String, color: Color) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.16))
            )
            .lineLimit(1)
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

    // MARK: - Human-readable translations (no internal jargon in UI)

    private func humanAction(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "Güçlü al"
        case .accumulate:    return "Kademeli al"
        case .neutral:       return "Tut"
        case .trim:          return "Bir kısmını sat"
        case .liquidate:     return "Çık"
        }
    }

    private func humanStance(_ stance: MacroStance) -> String {
        switch stance {
        case .riskOn:    return "Piyasa olumlu"
        case .cautious:  return "Temkinli"
        case .defensive: return "Savunmacı"
        case .riskOff:   return "Piyasa olumsuz"
        }
    }

    private func humanChimeraSignal(_ cs: ChimeraSignal) -> String {
        switch cs.type {
        case .deepValueBuy:        return "Değer fırsatı görülüyor"
        case .bullTrap:            return "Boğa tuzağı riski"
        case .momentumBreakout:    return "Momentum kırılımı"
        case .fallingKnife:        return "Düşen bıçak — dikkat"
        case .sentimentDivergence: return "Duygu-fiyat ayrışması"
        case .perfectStorm:        return "Çoklu sinyal çakışması"
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

    private func chimeraColor(_ type: ChimeraSignalType) -> Color {
        switch type {
        case .deepValueBuy: return Color.purple
        case .bullTrap: return InstitutionalTheme.Colors.warning
        case .momentumBreakout: return InstitutionalTheme.Colors.positive
        case .fallingKnife: return InstitutionalTheme.Colors.negative
        case .sentimentDivergence: return InstitutionalTheme.Colors.primary
        case .perfectStorm: return InstitutionalTheme.Colors.warning
        }
    }

    private func stopPrice(from plan: PositionPlan?) -> Double? {
        guard let plan else { return nil }
        for step in plan.bearishScenario.steps.sorted(by: { $0.priority < $1.priority }) where !plan.executedSteps.contains(step.id) {
            if case .priceBelow(let price) = step.trigger {
                return price
            }
        }
        return nil
    }

    private func targetPrice(from plan: PositionPlan?) -> Double? {
        guard let plan else { return nil }
        for step in plan.bullishScenario.steps.sorted(by: { $0.priority < $1.priority }) where !plan.executedSteps.contains(step.id) {
            if case .priceAbove(let price) = step.trigger {
                return price
            }
        }
        return nil
    }

    // MARK: - Conviction Meter (inline helper)

    private func convictionMeterView(_ cv: ConvictionState) -> some View {
        ConvictionMeterView(conviction: cv)
    }

    private func triggerDistanceText(_ trigger: ActionTrigger, plan: PositionPlan) -> String? {
        switch trigger {
        case .priceAbove(let target):
            let remaining = ((target - currentPrice) / max(currentPrice, 0.0001)) * 100
            return remaining <= 0 ? "Tetikte" : String(format: "+%.1f%%", remaining)
        case .priceBelow(let stop):
            let remaining = ((currentPrice - stop) / max(currentPrice, 0.0001)) * 100
            return remaining <= 0 ? "Tetikte" : String(format: "-%.1f%%", remaining)
        case .gainPercent(let targetPct):
            let remaining = targetPct - pnlPercent
            return remaining <= 0 ? "Tetikte" : String(format: "+%.1f%%", remaining)
        case .lossPercent(let targetPct):
            let triggerLevel = -targetPct
            let remaining = pnlPercent - triggerLevel
            return remaining <= 0 ? "Tetikte" : String(format: "-%.1f%%", remaining)
        case .daysElapsed(let days):
            let remainingDays = max(days - plan.ageInDays, 0)
            return remainingDays == 0 ? "Bugün" : "\(remainingDays) gün"
        default:
            return nil
        }
    }

    private func refreshCardData() {
        plan = PositionPlanStore.shared.getPlan(for: trade.id)
        decision = SignalStateViewModel.shared.grandDecisions[trade.symbol]
        chimeraSignal = SignalStateViewModel.shared.chimeraSignals[trade.symbol]

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
