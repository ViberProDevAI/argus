import SwiftUI

struct TradeDetailSheet: View {
    let trade: Trade
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var plan: PositionPlan?
    @State private var eventRisk: EventCalendarService.EventRiskAssessment?

    private struct SymbolBehaviorProfile {
        let title: String
        let color: Color
        let note: String
        let volatilityText: String
    }

    private var quote: Quote? {
        viewModel.quotes[trade.symbol]
    }

    private var currentPrice: Double {
        quote?.currentPrice ?? trade.entryPrice
    }

    private var pnlValue: Double {
        (currentPrice - trade.entryPrice) * trade.quantity
    }

    private var pnlPercent: Double {
        guard trade.entryPrice > 0 else { return 0 }
        return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }

    private var pnlColor: Color {
        pnlValue >= 0 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson
    }

    private var holdingDays: Int {
        Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
    }

    private var scenarios: [Scenario] {
        plan?.orderedScenarios ?? []
    }

    private var activeScenario: Scenario? {
        plan?.activeScenario
    }

    private var nextStep: PlannedAction? {
        plan?.nextPendingStep
    }

    private var suggestedStop: Double? {
        guard let plan else { return nil }
        let bearishSteps = plan.bearishScenario.steps.sorted { $0.priority < $1.priority }
        for step in bearishSteps {
            if let price = triggerPrice(step.trigger) {
                return price
            }
        }
        return nil
    }

    private var suggestedTarget: Double? {
        guard let plan else { return nil }
        let bullishSteps = plan.bullishScenario.steps.sorted { $0.priority < $1.priority }
        for step in bullishSteps {
            if let price = triggerPrice(step.trigger) {
                return price
            }
        }
        return nil
    }

    private var riskRewardText: String? {
        guard
            let stop = suggestedStop,
            let target = suggestedTarget,
            trade.entryPrice > stop
        else {
            return nil
        }

        let risk = trade.entryPrice - stop
        guard risk > 0 else { return nil }
        let reward = target - trade.entryPrice
        guard reward > 0 else { return nil }
        return String(format: "1 : %.2f", reward / risk)
    }

    private var decisionSnapshot: EntrySnapshot? {
        plan?.originalSnapshot
    }

    private var symbolProfile: SymbolBehaviorProfile {
        let vol = estimateVolatility()
        let avoid = eventRisk?.shouldAvoidNewPosition ?? false
        let reduce = eventRisk?.shouldReducePosition ?? false

        if avoid || vol > 0.05 {
            return SymbolBehaviorProfile(
                title: "Savunmacı Yönetim",
                color: InstitutionalTheme.Colors.crimson,
                note: "Küçük lot, sıkı stop ve daha uzun bekleme döngüsü uygun.",
                volatilityText: "Volatilite: Yüksek"
            )
        }

        if !reduce && vol < 0.02 && pnlPercent >= 0 {
            return SymbolBehaviorProfile(
                title: "Atak Yönetim",
                color: InstitutionalTheme.Colors.aurora,
                note: "Kademeli ekleme ve trailing-stop ile trend takibi yapılabilir.",
                volatilityText: "Volatilite: Düşük"
            )
        }

        return SymbolBehaviorProfile(
            title: "Dengeli Yönetim",
            color: InstitutionalTheme.Colors.titan,
            note: "Plan adımlarına sadık kalıp yeni girişlerde seçici kalınmalı.",
            volatilityText: "Volatilite: Orta"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroSection
                        pnlSection
                        planSection
                        decisionSection
                        scenarioSection
                        riskSection

                        Button(action: closePosition) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Pozisyonu Kapat")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(InstitutionalTheme.Colors.crimson)
                            .cornerRadius(16)
                            .shadow(color: InstitutionalTheme.Colors.crimson.opacity(0.36), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(trade.symbol)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .font(.title3)
                    }
                }
            }
            .onAppear(perform: loadContext)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            CompanyLogoView(symbol: trade.symbol, size: 72)
            Text(trade.symbol)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text(formatCurrency(currentPrice))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            HStack(spacing: 8) {
                detailPill(trade.source == .autoPilot ? "OTOPİLOT" : "MANUEL", color: trade.source == .autoPilot ? InstitutionalTheme.Colors.holo : .gray)
                detailPill("\(holdingDays) gün", color: InstitutionalTheme.Colors.textSecondary)
                if let intent = plan?.intent, intent != .undefined {
                    detailPill(intent.rawValue, color: Color(intent.colorName))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pnlSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Net Kâr/Zarar")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(formatCurrency(pnlValue))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(pnlColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%@%.2f%%", pnlPercent >= 0 ? "+" : "", pnlPercent))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(pnlColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(pnlColor.opacity(0.15))
                    .cornerRadius(12)

                Text("Giriş \(formatCurrency(trade.entryPrice))")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Plan Operasyonu", icon: "waveform.path.ecg", color: InstitutionalTheme.Colors.holo)

            if let plan {
                HStack {
                    Text("Plan ilerleme")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(plan.completedStepCount)/\(plan.totalStepCount)")
                        .font(.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(InstitutionalTheme.Colors.surface1)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(InstitutionalTheme.Colors.holo)
                            .frame(width: geo.size.width * plan.completionRatio)
                    }
                }
                .frame(height: 10)

                if let nextStep {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sıradaki adım")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("\(nextStep.trigger.displayText) → \(nextStep.action.displayText)")
                            .font(.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    .padding(10)
                    .background(InstitutionalTheme.Colors.surface1)
                    .cornerRadius(12)
                }

                HStack(spacing: 10) {
                    metricBox(title: "Stop", value: suggestedStop.map(formatCurrency) ?? "—", color: InstitutionalTheme.Colors.crimson)
                    metricBox(title: "Hedef", value: suggestedTarget.map(formatCurrency) ?? "—", color: InstitutionalTheme.Colors.aurora)
                    metricBox(title: "R/R", value: riskRewardText ?? "—", color: InstitutionalTheme.Colors.titan)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tez")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(plan.thesis)
                        .font(.subheadline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Divider().background(InstitutionalTheme.Colors.surface1)
                    Text("Geçersizlik: \(plan.invalidation)")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            } else {
                Text("Bu pozisyon için plan henüz oluşturulmadı.")
                    .font(.subheadline)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Button {
                    viewModel.triggerSmartPlan(for: trade)
                    loadContext()
                } label: {
                    Text("Plan Oluştur")
                        .font(.headline)
                        .foregroundColor(InstitutionalTheme.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(InstitutionalTheme.Colors.holo)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(InstitutionalTheme.Colors.holo.opacity(0.22), lineWidth: 1)
        )
    }

    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Karar Omurgası", icon: "brain.head.profile", color: InstitutionalTheme.Colors.titan)

            HStack(spacing: 10) {
                if let snapshot = decisionSnapshot {
                    metricBox(
                        title: "Konsey",
                        value: snapshot.councilAction.rawValue,
                        color: colorForAction(snapshot.councilAction)
                    )
                    metricBox(
                        title: "Güven",
                        value: "%\(Int(snapshot.councilConfidence * 100))",
                        color: InstitutionalTheme.Colors.holo
                    )
                    metricBox(
                        title: "Aether",
                        value: snapshot.aetherStance.rawValue,
                        color: InstitutionalTheme.Colors.titan
                    )
                } else {
                    metricBox(title: "Konsey", value: "—", color: InstitutionalTheme.Colors.textSecondary)
                    metricBox(title: "Güven", value: "—", color: InstitutionalTheme.Colors.textSecondary)
                    metricBox(title: "Aether", value: "—", color: InstitutionalTheme.Colors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Neden bu pozisyon?")
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(trade.rationale ?? decisionSnapshot?.councilReasoning ?? "Gerekçe kaydı bulunmuyor.")
                    .font(.subheadline)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }

            if let context = trade.decisionContext {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modül güvenleri")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                    if let atlas = context.moduleVotes.atlas {
                        ModuleConfidenceRow(name: "Atlas", score: atlas.confidence * 100, color: InstitutionalTheme.Colors.titan)
                    }
                    if let orion = context.moduleVotes.orion {
                        ModuleConfidenceRow(name: "Orion", score: orion.confidence * 100, color: InstitutionalTheme.Colors.holo)
                    }
                    if let aether = context.moduleVotes.aether {
                        ModuleConfidenceRow(name: "Aether", score: aether.confidence * 100, color: InstitutionalTheme.Colors.holo)
                    }
                    if let hermes = context.moduleVotes.hermes {
                        ModuleConfidenceRow(name: "Hermes", score: hermes.confidence * 100, color: InstitutionalTheme.Colors.aurora)
                    }
                }
            }
        }
        .padding(16)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var scenarioSection: some View {
        if !scenarios.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Senaryo Yol Haritası", icon: "point.3.connected.trianglepath.dotted", color: InstitutionalTheme.Colors.holo)

                if let activeScenario {
                    detailPill("Aktif: \(activeScenario.type.rawValue)", color: scenarioColor(activeScenario.type))
                }

                ForEach(scenarios.prefix(3)) { scenario in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(scenario.type.rawValue)
                                .font(.caption)
                                .foregroundColor(scenarioColor(scenario.type))
                            Spacer()
                            Text(scenario.isActive ? "AKTİF" : "PASİF")
                                .font(.caption2)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }

                        ForEach(scenario.steps.sorted(by: { $0.priority < $1.priority }).prefix(2)) { step in
                            let done = plan?.executedSteps.contains(step.id) ?? false
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(done ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.textSecondary)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.trigger.displayText)
                                        .font(.caption)
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        .strikethrough(done)
                                    Text(step.action.displayText)
                                        .font(.caption2)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(InstitutionalTheme.Colors.surface1)
                    .cornerRadius(10)
                }
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .cornerRadius(16)
        }
    }

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Hisseye Özel Yönetim", icon: "shield.lefthalf.filled", color: symbolProfile.color)

            VStack(alignment: .leading, spacing: 6) {
                Text(symbolProfile.title)
                    .font(.headline)
                    .foregroundColor(symbolProfile.color)
                Text(symbolProfile.note)
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(symbolProfile.volatilityText)
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            if let eventRisk, !eventRisk.warnings.isEmpty {
                Divider().background(InstitutionalTheme.Colors.surface1)
                Text("Takvim Uyarıları")
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                ForEach(eventRisk.warnings.prefix(3), id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.titan)
                }
            }

            HStack(spacing: 10) {
                metricBox(title: "Pazar", value: trade.symbol.hasSuffix(".IS") ? "BIST" : "GLOBAL", color: InstitutionalTheme.Colors.textSecondary)
                metricBox(title: "Miktar", value: String(format: "%.2f", trade.quantity), color: InstitutionalTheme.Colors.textPrimary)
                metricBox(title: "Gün", value: "\(holdingDays)", color: InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(16)
    }

    private func loadContext() {
        plan = PositionPlanStore.shared.getPlan(for: trade.id)
        eventRisk = EventCalendarService.shared.assessPositionRisk(symbol: trade.symbol)
    }

    func closePosition() {
        if let price = viewModel.quotes[trade.symbol]?.currentPrice {
            viewModel.sell(tradeId: trade.id, currentPrice: price)
            dismiss()
        }
    }

    private func detailPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color == InstitutionalTheme.Colors.textSecondary ? InstitutionalTheme.Colors.textSecondary : InstitutionalTheme.Colors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18))
            .cornerRadius(10)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
        }
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(10)
    }

    private func formatCurrency(_ value: Double) -> String {
        let prefix = trade.currency.symbol
        return "\(prefix)\(String(format: "%.2f", value))"
    }

    private func triggerPrice(_ trigger: ActionTrigger) -> Double? {
        switch trigger {
        case .priceAbove(let price): return price
        case .priceBelow(let price): return price
        default: return nil
        }
    }

    private func scenarioColor(_ type: ScenarioType) -> Color {
        switch type {
        case .bullish: return InstitutionalTheme.Colors.aurora
        case .neutral: return InstitutionalTheme.Colors.titan
        case .bearish: return InstitutionalTheme.Colors.crimson
        }
    }

    private func colorForAction(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.aurora
        case .accumulate: return InstitutionalTheme.Colors.holo
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.titan
        case .liquidate: return InstitutionalTheme.Colors.crimson
        }
    }

    private func estimateVolatility() -> Double {
        let candles = viewModel.candles[trade.symbol] ?? []
        guard candles.count >= 8, currentPrice > 0 else { return 0.03 }

        let sample = Array(candles.suffix(24))
        guard sample.count >= 2 else { return 0.03 }

        var ranges: [Double] = []
        for index in 1..<sample.count {
            let high = sample[index].high
            let low = sample[index].low
            let previousClose = sample[index - 1].close
            let trueRange = max(high - low, abs(high - previousClose), abs(low - previousClose))
            ranges.append(trueRange)
        }

        guard !ranges.isEmpty else { return 0.03 }
        let atr = ranges.reduce(0, +) / Double(ranges.count)
        return atr / currentPrice
    }
}

struct ModuleConfidenceRow: View {
    let name: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text("%\(Int(score))")
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface1)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.9))
                        .frame(width: geo.size.width * max(0, min(1, score / 100)))
                }
            }
            .frame(height: 7)
        }
    }
}
