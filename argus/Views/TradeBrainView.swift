import SwiftUI

struct TradeBrainView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var planStore = PositionPlanStore.shared
    @StateObject private var executor = TradeBrainExecutor.shared
    @StateObject private var executionState = ExecutionStateViewModel.shared

    @State private var selectedPlan: PositionPlan?
    @State private var selectedPlanCurrentPrice: Double = 0
    @State private var selectedPlanDecision: ArgusGrandDecision?
    @State private var selectedPlanCandles: [Candle] = []
    @State private var selectedPlanEventRisk: EventCalendarService.EventRiskAssessment?
    @State private var showPlanDetail = false
    @State private var marketMode: MarketFilter = .all
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    enum MarketFilter: String, CaseIterable {
        case all = "Tümü"
        case global = "Global"
        case bist = "BIST"
    }

    private var filteredPortfolio: [Trade] {
        switch marketMode {
        case .all:
            return viewModel.portfolio
        case .global:
            return viewModel.portfolio.filter { !SymbolResolver.shared.isBistSymbol($0.symbol) }
        case .bist:
            return viewModel.portfolio.filter { SymbolResolver.shared.isBistSymbol($0.symbol) }
        }
    }

    private var filteredOpenTrades: [Trade] {
        filteredPortfolio.filter { $0.isOpen }
    }

    private var filteredBalance: Double {
        switch marketMode {
        case .all: return viewModel.balance + viewModel.bistBalance
        case .global: return viewModel.balance
        case .bist: return viewModel.bistBalance
        }
    }

    private var filteredEquity: Double {
        let portfolioValue = filteredOpenTrades.reduce(0.0) { sum, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (trade.quantity * price)
        }
        return filteredBalance + portfolioValue
    }

    private var filteredAlerts: [TradeBrainAlert] {
        switch marketMode {
        case .all:
            return viewModel.planAlerts
        case .global:
            return viewModel.planAlerts.filter { !SymbolResolver.shared.isBistSymbol($0.symbol) }
        case .bist:
            return viewModel.planAlerts.filter { SymbolResolver.shared.isBistSymbol($0.symbol) }
        }
    }

    private var healthSnapshot: PortfolioRiskManager.PortfolioHealth {
        PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: filteredPortfolio,
            cashBalance: filteredBalance,
            totalEquity: max(filteredEquity, 1),
            quotes: viewModel.quotes
        )
    }

    private var sortedExecutionLogs: [String] {
        executor.executionLogs.prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topNav

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            marketTabs
                            autopilotStatus
                            statRow
                            sectionDivider
                            riskBreakdownSection
                            sectionDivider
                            openPositionsSection
                            sectionDivider
                            pendingActionsSection
                            if hasContradictions {
                                sectionDivider
                                contradictionSection
                            }
                            sectionDivider
                            upcomingEventsSection
                            sectionDivider
                            recentExecutionsSection
                            sectionDivider
                            learnLink
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 100)
                    }
                }

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(120)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPlanDetail) {
                if let plan = selectedPlan {
                    PositionPlanDetailView(
                        plan: plan,
                        currentPrice: selectedPlanCurrentPrice,
                        decision: selectedPlanDecision,
                        candles: selectedPlanCandles,
                        eventRisk: selectedPlanEventRisk
                    )
                }
            }
        }
    }

    // MARK: - 2026-04-30 H-48 sade yapı

    private var topNav: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Trade Brain")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("Otomatik karar merkezi")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
            Button(action: { showDrawer = true }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(InstitutionalTheme.Colors.borderSubtle)
            .frame(height: 0.5)
    }

    /// Caps capsule pill yerine underline tab — drawer / portfolio dili.
    private var marketTabs: some View {
        HStack(spacing: 4) {
            ForEach(MarketFilter.allCases, id: \.self) { mode in
                marketTab(label: mode.rawValue, selected: marketMode == mode) {
                    withAnimation(.easeInOut(duration: 0.2)) { marketMode = mode }
                }
            }
            Spacer()
        }
    }

    private func marketTab(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundColor(selected
                                     ? InstitutionalTheme.Colors.textPrimary
                                     : InstitutionalTheme.Colors.textSecondary)
                Rectangle()
                    .fill(selected ? InstitutionalTheme.Colors.textPrimary : Color.clear)
                    .frame(height: 1.5)
            }
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Otopilot durumu — yeşil/sarı dot + "Otopilot aktif/pasif" + iOS
    /// switch + alt satır 1 cümle özet.
    private var autopilotStatus: some View {
        let active = isAutoPilotActive
        let dotColor: Color = active
            ? InstitutionalTheme.Colors.positive
            : InstitutionalTheme.Colors.textTertiary
        let summary = "\(openPositionsCount) pozisyon · sağlık \(Int(healthSnapshot.score))"
        return HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(active ? "Otopilot aktif" : "Otopilot pasif")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { executionState.isAutoPilotEnabled },
                set: { executionState.isAutoPilotEnabled = $0 }
            ))
            .labelsHidden()
            .tint(InstitutionalTheme.Colors.positive)
        }
    }

    /// 3 sütun dikey-ayraçlı stat (LiquidDashboardHeader / tradeBrainBand
    /// dili). Açık · Nakit · Risk.
    private var statRow: some View {
        HStack(spacing: 0) {
            statColumn(title: "Açık",
                       value: "\(openPositionsCount)",
                       tone: InstitutionalTheme.Colors.textPrimary,
                       leadingDivider: false)
            statColumn(title: "Nakit",
                       value: "\(Int(cashRatio * 100))%",
                       tone: cashRatio >= 0.20
                            ? InstitutionalTheme.Colors.textPrimary
                            : InstitutionalTheme.Colors.warning,
                       leadingDivider: true)
            statColumn(title: "Risk",
                       value: humanRiskStatus,
                       tone: statusColor(for: healthSnapshot.status),
                       leadingDivider: true)
        }
    }

    private func statColumn(title: String, value: String, tone: Color, leadingDivider: Bool) -> some View {
        HStack(spacing: 0) {
            if leadingDivider {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(width: 0.5)
                    .padding(.vertical, 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Caps "NORMAL/İZLE/YÜKSEK" yerine sentence case.
    private var humanRiskStatus: String {
        switch healthSnapshot.status {
        case .healthy:  return "İyi"
        case .warning:  return "İzle"
        case .critical: return "Yüksek"
        }
    }

    // MARK: - Bekleyen aksiyonlar

    private var pendingActionsSection: some View {
        let alerts = filteredAlerts
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bekleyen aksiyonlar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                if !alerts.isEmpty {
                    Text("\(alerts.count)")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
            }
            if alerts.isEmpty {
                Text("Şu an aktif uyarı yok. Plan tetiklenmeleri ve konsey değişiklikleri burada görünür.")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(alerts) { alert in
                        pendingActionRow(alert)
                        if alert.id != alerts.last?.id {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func pendingActionRow(_ alert: TradeBrainAlert) -> some View {
        let accent = alertColor(for: alert.priority)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(alert.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(humanAlertType(alert.type))
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Text(alert.actionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.trailing, 11)
        }
    }

    private func humanAlertType(_ type: TradeBrainAlert.AlertType) -> String {
        switch type {
        case .planTriggered:    return "plan tetiklendi"
        case .targetReached:    return "hedef yaklaştı"
        case .stopApproaching:  return "stop yaklaştı"
        case .councilChanged:   return "konsey değişti"
        }
    }

    // MARK: - Yakın olaylar

    private var upcomingEventsSection: some View {
        let events = EventCalendarService.shared.getUpcomingEvents(days: 7)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Yakın olaylar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("7 gün")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
            }
            if events.isEmpty {
                Text("Önümüzdeki 7 günde planlı bilanço, faiz kararı ya da makro veri yok.")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    let preview = Array(events.prefix(5))
                    ForEach(Array(preview.enumerated()), id: \.offset) { idx, event in
                        eventRow(event)
                        if idx < preview.count - 1 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func eventRow(_ event: EventCalendarService.MarketEvent) -> some View {
        let isPosition: Bool = {
            guard let sym = event.symbol else { return false }
            return filteredOpenTrades.contains { $0.symbol == sym }
        }()
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(eventDay(event.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isPosition
                                     ? InstitutionalTheme.Colors.warning
                                     : InstitutionalTheme.Colors.textPrimary)
                Text(eventMonth(event.date))
                    .font(.system(size: 9))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(eventSubtitle(event))
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if isPosition {
                Text("Pozisyon")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.warning)
            } else if event.symbol == nil {
                Text("Makro")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private func eventDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f.string(from: date)
    }

    private func eventMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "MMM"
        return f.string(from: date).capitalized
    }

    private func eventSubtitle(_ event: EventCalendarService.MarketEvent) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE · HH:mm"
        return f.string(from: event.date).capitalized
    }

    // MARK: - Son işlemler

    private var recentExecutionsSection: some View {
        let logs = sortedExecutionLogs
        return VStack(alignment: .leading, spacing: 10) {
            Text("Son işlemler")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            if logs.isEmpty {
                Text("Henüz otomatik işlem yok.")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { idx, log in
                        Text(log)
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                        if idx < logs.count - 1 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Öğren linki

    private var learnLink: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trade Brain'i öğren")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("Otopilot nasıl çalışır, plan adımları ve risk eşikleri →")
                .font(.system(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.holo)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Risk dağılımı

    private var riskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Risk dağılımı")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            VStack(spacing: 0) {
                riskRow(label: "Nakit oranı",
                        valueText: "%\(Int(cashRatio * 100))",
                        progress: cashRatio / 0.20,
                        healthy: cashRatio >= 0.20,
                        hint: "min %20")
                rowDivider
                riskRow(label: "Açık pozisyon",
                        valueText: "\(openPositionsCount)/15",
                        progress: Double(openPositionsCount) / 15.0,
                        healthy: openPositionsCount <= 15,
                        hint: "max 15")
                rowDivider
                riskRow(label: "En büyük pozisyon",
                        valueText: "%\(Int(maxPositionWeight * 100))",
                        progress: maxPositionWeight / 0.15,
                        healthy: maxPositionWeight <= 0.15,
                        hint: "max %15")
            }
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(InstitutionalTheme.Colors.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, 11)
    }

    private func riskRow(label: String, valueText: String, progress: Double, healthy: Bool, hint: String) -> some View {
        let tone: Color = healthy
            ? InstitutionalTheme.Colors.textPrimary
            : InstitutionalTheme.Colors.warning
        let clamped = max(0, min(progress, 1))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(valueText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(tone)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                    Rectangle()
                        .fill(tone.opacity(0.7))
                        .frame(width: max(2, geo.size.width * clamped))
                }
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    // MARK: - Açık pozisyonlar

    private var openPositionsSection: some View {
        let positions = filteredOpenTrades
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Açık pozisyonlar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                if !positions.isEmpty {
                    Text("\(positions.count)")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
            }
            if positions.isEmpty {
                Text("Açık pozisyon yok. Yeni alım yapıldığında plan burada görünür.")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(positions) { trade in
                        openPositionRow(trade)
                        if trade.id != positions.last?.id {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func openPositionRow(_ trade: Trade) -> some View {
        let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
        let pnlPct = (price - trade.entryPrice) / trade.entryPrice * 100
        let pnlPositive = pnlPct >= 0
        let pnlColor: Color = pnlPositive
            ? InstitutionalTheme.Colors.positive
            : InstitutionalTheme.Colors.negative
        let plan = planStore.getPlan(for: trade.id)
        let nextStep = plan?.nextPendingStep?.description ?? "Plan tanımlı değil"
        let decision = viewModel.grandDecisions[trade.symbol]
        let actionLabel = decision.map { humanAction($0.action) } ?? ""

        return Button(action: {
            guard let plan = plan else { return }
            selectedPlan = plan
            selectedPlanCurrentPrice = price
            selectedPlanDecision = decision
            selectedPlanCandles = viewModel.candles[trade.symbol] ?? []
            selectedPlanEventRisk = EventCalendarService.shared.assessPositionRisk(symbol: trade.symbol)
            showPlanDetail = true
        }) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(pnlColor)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(trade.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        if !actionLabel.isEmpty {
                            Text(actionLabel)
                                .font(.system(size: 11))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text("\(pnlPositive ? "+" : "")\(String(format: "%.2f", pnlPct))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(pnlColor)
                            .monospacedDigit()
                    }
                    Text(nextStep)
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.trailing, 11)
            }
        }
        .buttonStyle(.plain)
        .disabled(plan == nil)
    }

    private func humanAction(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "hücum"
        case .accumulate: return "biriktir"
        case .neutral: return "gözle"
        case .trim: return "azalt"
        case .liquidate: return "çık"
        }
    }

    // MARK: - Konsey çelişkisi

    private var hasContradictions: Bool {
        executor.lastContradictionAnalyses.values.contains { $0.hasContradictions }
    }

    private var contradictionSection: some View {
        let items = executor.lastContradictionAnalyses
            .filter { $0.value.hasContradictions }
            .sorted { contradictionPriority($0.value.severity) > contradictionPriority($1.value.severity) }
            .prefix(3)
        let array = Array(items)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Konsey çelişkisi")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("\(array.count)")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
            }
            VStack(spacing: 0) {
                ForEach(Array(array.enumerated()), id: \.offset) { idx, item in
                    contradictionRow(symbol: item.key, analysis: item.value)
                    if idx < array.count - 1 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, 14)
                    }
                }
            }
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func contradictionRow(symbol: String, analysis: ContradictionAnalysis) -> some View {
        let tone = severityColor(analysis.severity)
        let modules = analysis.contradictions
            .map { "\($0.module1) ↔ \($0.module2)" }
            .joined(separator: " · ")
        return HStack(spacing: 0) {
            Rectangle()
                .fill(tone)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(modules)
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text("güven −%\(Int(analysis.suggestedConfidenceDrop * 100))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tone)
                        .monospacedDigit()
                }
                Text(analysis.recommendation)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func contradictionPriority(_ severity: Severity) -> Int {
        switch severity {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .high: return InstitutionalTheme.Colors.negative
        case .medium: return InstitutionalTheme.Colors.warning
        case .low: return InstitutionalTheme.Colors.textSecondary
        }
    }

    private var isAutoPilotActive: Bool { executionState.isAutoPilotEnabled }

    private var openPositionsCount: Int {
        filteredOpenTrades.count
    }

    private var cashRatio: Double {
        let equity = max(filteredEquity, 1)
        return filteredBalance / equity
    }

    private var maxPositionWeight: Double {
        let equity = max(filteredEquity, 1)
        let maxWeight = filteredOpenTrades.reduce(0.0) { currentMax, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let weight = (trade.quantity * price) / equity
            return max(currentMax, weight)
        }
        return maxWeight
    }

    private func statusColor(for status: PortfolioRiskManager.HealthStatus) -> Color {
        switch status {
        case .healthy: return InstitutionalTheme.Colors.positive
        case .warning: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    private func alertColor(for priority: TradeBrainAlert.AlertPriority) -> Color {
        switch priority {
        case .low: return InstitutionalTheme.Colors.textSecondary
        case .medium: return InstitutionalTheme.Colors.primary
        case .high: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akışı", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkezi", icon: "brain.head.profile") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAlkindusDashboard"), object: nil)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portföy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Trade Brain",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Pazar: Tümü", subtitle: "Bütün portföy", icon: "circle.grid.2x2") {
                        marketMode = .all
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: Global", subtitle: "ABD/Global", icon: "globe") {
                        marketMode = .global
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: BIST", subtitle: "Türkiye", icon: "chart.bar") {
                        marketMode = .bist
                        showDrawer = false
                    }
                ]
            )
        )

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Araçlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gerçek takvim", icon: "calendar") {
                        openSheet(.calendar)
                    },
                    ArgusDrawerView.DrawerItem(title: "Finans Sözlüğü", subtitle: "Terimler", icon: "character.book.closed") {
                        openSheet(.dictionary)
                    },
                    ArgusDrawerView.DrawerItem(title: "Finans Sözleri", subtitle: "Kısa alıntılar", icon: "quote.opening") {
                        openSheet(.financeWisdom)
                    },
                    ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sağlığı", icon: "waveform.path.ecg") {
                        openSheet(.systemHealth)
                    },
                    ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                        openSheet(.feedback)
                    }
                ]
            )
        )

        return sections
    }
}
