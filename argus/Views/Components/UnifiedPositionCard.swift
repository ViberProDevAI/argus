import SwiftUI

// MARK: - Unified Position Card
/// Portföy kartı: konsey kararı, plan adımları ve chimera sinyalini tek akışta gösterir.

struct UnifiedPositionCard: View {
    let trade: Trade
    let currentPrice: Double
    let market: TradeMarket
    var onEdit: (() -> Void)?
    var onSell: (() -> Void)?
    /// Bu pozisyona ait inline alert'ler. PortfolioView, planAlerts'i
    /// symbol bazında filtreleyip geçer. Boş ise alert satırı çizilmez.
    /// (2026-04-30 H-46)
    var alerts: [TradeBrainAlert] = []
    /// Inline alert kullanıcı dismiss ettiğinde çağrılır.
    var onAlertDismiss: ((TradeBrainAlert) -> Void)? = nil

    @State private var plan: PositionPlan?
    @State private var delta: PositionDeltaTracker.PositionDelta?
    @State private var decision: ArgusGrandDecision?

    private var isBist: Bool { market == .bist }

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

    // 2026-04-30 H-46 — sade. Devasa multi-section kart (header + progress
    // + decision/signal + plan + delta + actionButtons) yerine 3-satır
    // kompakt yapı. Sol 3px renk şeridi konsey aksiyonunun renk özeti,
    // satır 1: sembol + miktar + fiyat, satır 2: giriş + süre + K/Z,
    // satır 3: konsey rozeti + plan durum rozeti.
    // Detay (chimera, conviction, plan adımları, action butonları) artık
    // TradeDetailSheet'te. Pozisyona ait alert varsa kart altında inline
    // hairline'la ayrılıp gösterilir.
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    rowOne
                    rowTwo
                    rowThree
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(stripeColor.opacity(hasCriticalAlert ? 0.04 : 0))

            ForEach(alerts) { alert in
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)
                alertRow(alert)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .onAppear(perform: refreshCardData)
        .onChange(of: currentPrice) { _, _ in
            refreshCardData()
        }
    }

    // MARK: - 3-satır yapı

    private var rowOne: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(displaySymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text("\(formatQuantity(trade.quantity)) hisse")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            if hasCriticalAlert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
            }
            Spacer(minLength: 8)
            Text(formatPrice(currentPrice))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
        }
    }

    private var rowTwo: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Giriş \(formatPrice(trade.entryPrice)) · \(holdingDays) gün")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer(minLength: 6)
            Text("\(pnlValue >= 0 ? "+" : "")\(formatPrice(pnlValue)) · \(pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(pnlColor)
                .monospacedDigit()
        }
    }

    private var rowThree: some View {
        HStack(spacing: 5) {
            councilBadge
            planBadge
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var councilBadge: some View {
        if let decision {
            badge(text: "Konsey: \(humanAction(decision.action)) · \(Int(decision.confidence * 100))",
                  color: actionColor(decision.action),
                  filled: true)
        } else {
            badge(text: "Konsey: bekleme",
                  color: InstitutionalTheme.Colors.textSecondary,
                  filled: false)
        }
    }

    @ViewBuilder
    private var planBadge: some View {
        if let plan {
            let stop = stopPrice(from: plan)
            let executed = plan.executedSteps.count
            let stopText = stop.map { "SL \(formatPrice($0))" } ?? "SL —"
            let prefix = executed > 0 ? "Adım \(executed)/\(plan.totalStepCount) · " : ""
            badge(text: "\(prefix)\(stopText)",
                  color: InstitutionalTheme.Colors.textSecondary,
                  filled: false)
        } else {
            badge(text: "Plan yok",
                  color: InstitutionalTheme.Colors.textSecondary,
                  filled: false)
        }
    }

    private func badge(text: String, color: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(filled
                        ? color.opacity(0.14)
                        : InstitutionalTheme.Colors.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    // MARK: - Inline alert satırı

    private func alertRow(_ alert: TradeBrainAlert) -> some View {
        let dotColor = priorityColor(alert.priority)
        return HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(alertTypeLabel(alert.type))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(relativeTime(alert.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                Text(alert.message)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(alert.actionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(dotColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button(action: { onAlertDismiss?(alert) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// AlertType.rawValue caps-snake ("STOP_YAKIN") → sentence case.
    private func alertTypeLabel(_ type: TradeBrainAlert.AlertType) -> String {
        switch type {
        case .planTriggered:    return "Plan tetiklendi"
        case .targetReached:    return "Hedef yaklaştı"
        case .stopApproaching:  return "Stop yaklaştı"
        case .councilChanged:   return "Konsey değişti"
        }
    }

    // MARK: - Sade helper'lar

    /// Sol 3px şeridin rengi — konsey aksiyonu varsa onu, yoksa nötr.
    private var stripeColor: Color {
        if let decision {
            return actionColor(decision.action)
        }
        return InstitutionalTheme.Colors.textTertiary
    }

    /// High/critical priority alert var mı?
    private var hasCriticalAlert: Bool {
        alerts.contains { $0.priority == .high || $0.priority == .critical }
    }

    private func priorityColor(_ priority: TradeBrainAlert.AlertPriority) -> Color {
        switch priority {
        case .low:      return InstitutionalTheme.Colors.textSecondary
        case .medium:   return InstitutionalTheme.Colors.holo
        case .high:     return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.crimson
        }
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty == qty.rounded() {
            return String(format: "%.0f", qty)
        }
        return String(format: "%.2f", qty)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60     { return "az önce" }
        if seconds < 3600   { return "\(seconds / 60) dk önce" }
        if seconds < 86400  { return "\(seconds / 3600) sa önce" }
        return "\(seconds / 86400) gün önce"
    }

    // 2026-04-30 H-46: headerSection / priceProgressSection /
    // decisionAndSignalSection / noPlanSection / planStatusSection /
    // deltaBadgeSection / actionButtonsSection / metricTag / tagPill /
    // humanStance / humanChimeraSignal / aetherColor / chimeraColor /
    // significanceColor / convictionMeterView temizlendi. Yeni 3-satır
    // kompakt yapı body'de inline tutuluyor; detay (chimera, conviction,
    // plan adımları, action butonları) artık TradeDetailSheet'in
    // sorumluluğunda.

    private var displaySymbol: String {
        isBist ? trade.symbol.replacingOccurrences(of: ".IS", with: "") : trade.symbol
    }

    private func formatPrice(_ value: Double) -> String {
        if isBist {
            return String(format: "₺%.2f", value)
        }
        return String(format: "$%.2f", value)
    }

    // MARK: - Konsey aksiyonu — sade Türkçe

    private func humanAction(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "Güçlü al"
        case .accumulate:    return "Kademeli al"
        case .neutral:       return "Tut"
        case .trim:          return "Kısmen sat"
        case .liquidate:     return "Çık"
        }
    }

    private func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate:    return InstitutionalTheme.Colors.primary
        case .neutral:       return InstitutionalTheme.Colors.textSecondary
        case .trim:          return InstitutionalTheme.Colors.warning
        case .liquidate:     return InstitutionalTheme.Colors.negative
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
