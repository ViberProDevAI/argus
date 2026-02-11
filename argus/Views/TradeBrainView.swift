import SwiftUI

struct TradeBrainView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var planStore = PositionPlanStore.shared
    @StateObject private var executor = TradeBrainExecutor.shared
    @StateObject private var executionState = ExecutionStateViewModel.shared

    @State private var selectedTab: TradeBrainTab = .positions
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

    enum TradeBrainTab: Int, CaseIterable {
        case positions
        case risk
        case calendar
        case learn

        var title: String {
            switch self {
            case .positions: return "Pozisyon"
            case .risk: return "Risk"
            case .calendar: return "Takvim"
            case .learn: return "Öğren"
            }
        }

        var icon: String {
            switch self {
            case .positions: return "waveform.path.ecg"
            case .risk: return "shield.lefthalf.filled"
            case .calendar: return "calendar"
            case .learn: return "book.closed"
            }
        }
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

    private var filteredDecisions: [ArgusGrandDecision] {
        filteredOpenTrades.compactMap { viewModel.grandDecisions[$0.symbol] }
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

    private var dominantAetherStance: MacroStance? {
        guard !filteredDecisions.isEmpty else { return nil }
        var counter: [MacroStance: Int] = [:]
        for decision in filteredDecisions {
            counter[decision.aetherDecision.stance, default: 0] += 1
        }
        return counter.max(by: { $0.value < $1.value })?.key
    }

    private var actionCounts: [ArgusAction: Int] {
        var counts: [ArgusAction: Int] = [:]
        for decision in filteredDecisions {
            counts[decision.action, default: 0] += 1
        }
        return counts
    }

    private var sortedExecutionLogs: [String] {
        executor.executionLogs.prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: InstitutionalTheme.Spacing.md) {
                        marketSelector
                        headerSection
                        tabSelector
                        currentTabContent
                    }
                    .padding(.horizontal, InstitutionalTheme.Spacing.md)
                    .padding(.top, InstitutionalTheme.Spacing.sm)
                    .padding(.bottom, 28)
                }

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(120)
                }
            }
            .navigationTitle("Trade Brain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAutoPilotActive ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.warning)
                            .frame(width: 8, height: 8)
                        Text(isAutoPilotActive ? "Aktif" : "Pasif")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            }
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

    private var marketSelector: some View {
        HStack(spacing: 8) {
            ForEach(MarketFilter.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        marketMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(marketMode == mode ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .fill(marketMode == mode ? marketHighlightColor(mode) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .institutionalCard(scale: .micro, elevated: true)
    }

    private var headerSection: some View {
        VStack(spacing: InstitutionalTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Akıllı Yürütme Merkezi")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .tracking(1.2)

                    Text("Trade Brain")
                        .font(InstitutionalTheme.Typography.title)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Text("Plan + Konsey + Aether birlikte işler")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor(for: healthSnapshot.status).opacity(0.9), InstitutionalTheme.Colors.surface3],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)

                    VStack(spacing: 1) {
                        Text("\(Int(healthSnapshot.score))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("SKOR")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            }

            HStack(spacing: 10) {
                QuickStatBadge(
                    icon: "briefcase.fill",
                    value: "\(openPositionsCount)",
                    label: "Açık Pozisyon",
                    color: InstitutionalTheme.Colors.primary
                )
                QuickStatBadge(
                    icon: "banknote.fill",
                    value: "%\(Int(cashRatio * 100))",
                    label: "Nakit Oranı",
                    color: cashRatio >= 0.20 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.warning
                )
                QuickStatBadge(
                    icon: "calendar",
                    value: "\(upcomingEventsCount)",
                    label: "Yakın Olay",
                    color: upcomingEventsCount > 0 ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.textTertiary
                )
                QuickStatBadge(
                    icon: "shield.fill",
                    value: riskStatus,
                    label: "Risk",
                    color: statusColor(for: healthSnapshot.status)
                )
            }
        }
        .padding(InstitutionalCardScale.insight.padding)
        .institutionalCard(scale: .insight, elevated: true)
    }

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(TradeBrainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.title)
                            .font(InstitutionalTheme.Typography.micro)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedTab == tab ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .fill(selectedTab == tab ? InstitutionalTheme.Colors.surface3 : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .institutionalCard(scale: .micro)
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .positions:
            decisionPulseSection
            portfolioHealthSection
            activePositionsSection
            executionFeedSection
        case .risk:
            riskDashboardSection
        case .calendar:
            calendarSection
        case .learn:
            educationSection
        }
    }

    private var decisionPulseSection: some View {
        sectionCard {
            SectionHeader(title: "Karar Motoru Nabzı", icon: "cpu.fill", color: InstitutionalTheme.Colors.primary)

            if filteredOpenTrades.isEmpty {
                BrainEmptyCard(
                    icon: "tray",
                    title: "Açık pozisyon yok",
                    subtitle: "Trade Brain canlı kararlarını açık pozisyonlar üzerinden üretir."
                )
            } else {
                HStack(spacing: 10) {
                    DecisionStatPill(title: "HÜCUM", value: "\(actionCounts[.aggressiveBuy, default: 0])", color: InstitutionalTheme.Colors.positive)
                    DecisionStatPill(title: "BİRİKTİR", value: "\(actionCounts[.accumulate, default: 0])", color: InstitutionalTheme.Colors.primary)
                    DecisionStatPill(title: "AZALT/ÇIK", value: "\(actionCounts[.trim, default: 0] + actionCounts[.liquidate, default: 0])", color: InstitutionalTheme.Colors.warning)
                }

                if let stance = dominantAetherStance {
                    HStack(spacing: 10) {
                        Text("Aether Duruşu")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text(stance.rawValue)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(aetherColor(for: stance))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(aetherColor(for: stance).opacity(0.18))
                            )
                    }
                }

                if let topDecision = filteredDecisions.max(by: { $0.confidence < $1.confidence }) {
                    DecisionPulseCard(decision: topDecision)
                }
            }
        }
    }

    private var portfolioHealthSection: some View {
        sectionCard {
            SectionHeader(title: "Portföy Sağlığı", icon: "heart.text.square.fill", color: InstitutionalTheme.Colors.warning)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 10)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0, to: healthSnapshot.score / 100)
                        .stroke(
                            statusColor(for: healthSnapshot.status),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 84, height: 84)

                    VStack(spacing: 2) {
                        Text("\(Int(healthSnapshot.score))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("sağlık")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(healthSnapshot.status.rawValue)
                        .font(InstitutionalTheme.Typography.headline)
                        .foregroundColor(statusColor(for: healthSnapshot.status))

                    if healthSnapshot.issues.isEmpty {
                        Text("Tüm kritik eşikler güvenli aralıkta.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    } else {
                        ForEach(healthSnapshot.issues.prefix(2), id: \.self) { issue in
                            Text(issue)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                    }

                    Text("Risk-ayarlı getiri: \(String(format: "%.2f", healthSnapshot.riskAdjustedReturn))")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                Spacer()
            }

            if !healthSnapshot.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Önerilen aksiyonlar")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    ForEach(healthSnapshot.suggestions.prefix(3), id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3.opacity(0.65))
                )
            }
        }
    }

    private var activePositionsSection: some View {
        sectionCard {
            SectionHeader(title: "Pozisyon Planları", icon: "list.bullet.clipboard.fill", color: InstitutionalTheme.Colors.primary)

            if filteredOpenTrades.isEmpty {
                BrainEmptyCard(
                    icon: "rectangle.stack.badge.xmark",
                    title: "Açık pozisyon bulunmuyor",
                    subtitle: "Yeni bir pozisyon açıldığında Trade Brain planı burada görünür."
                )
            } else {
                ForEach(filteredOpenTrades) { trade in
                    PositionPlanCard(
                        trade: trade,
                        plan: planStore.getPlan(for: trade.id),
                        decision: viewModel.grandDecisions[trade.symbol],
                        currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
                    ) {
                        if let plan = planStore.getPlan(for: trade.id) {
                            selectedPlan = plan
                            selectedPlanCurrentPrice = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
                            selectedPlanDecision = viewModel.grandDecisions[trade.symbol]
                            selectedPlanCandles = viewModel.candles[trade.symbol] ?? []
                            selectedPlanEventRisk = EventCalendarService.shared.assessPositionRisk(symbol: trade.symbol)
                            showPlanDetail = true
                        }
                    }
                }
            }
        }
    }

    private var executionFeedSection: some View {
        sectionCard {
            SectionHeader(title: "Yürütme Akışı", icon: "waveform.and.magnifyingglass", color: InstitutionalTheme.Colors.positive)

            if filteredAlerts.isEmpty && sortedExecutionLogs.isEmpty {
                BrainEmptyCard(
                    icon: "clock.arrow.circlepath",
                    title: "Yeni tetik yok",
                    subtitle: "Plan tetiklendiğinde veya bir karar yürütüldüğünde burada görünür."
                )
            } else {
                if !filteredAlerts.isEmpty {
                    ForEach(filteredAlerts.prefix(4)) { alert in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(alertColor(for: alert.priority))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(alert.symbol)
                                        .font(InstitutionalTheme.Typography.bodyStrong)
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    Spacer()
                                    Text(alert.timestamp.formatted(.dateTime.hour().minute()))
                                        .font(InstitutionalTheme.Typography.micro)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                }
                                Text(alert.actionDescription)
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                Text(alert.message)
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .fill(InstitutionalTheme.Colors.surface3.opacity(0.58))
                        )
                    }
                }

                if !sortedExecutionLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Son yürütme günlükleri")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        ForEach(sortedExecutionLogs.prefix(4), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .fill(InstitutionalTheme.Colors.surface2.opacity(0.85))
                    )
                }
            }
        }
    }

    private var riskDashboardSection: some View {
        sectionCard {
            SectionHeader(title: "Risk Kontrol Paneli", icon: "shield.fill", color: InstitutionalTheme.Colors.warning)

            VStack(spacing: 10) {
                RiskLimitCard(
                    title: "Nakit Oranı",
                    current: cashRatio,
                    limit: 0.20,
                    isMinimum: true,
                    icon: "banknote.fill",
                    description: "Ani dalgalanmalarda pozisyon yönetimi için minimum %20 nakit korunur."
                )
                RiskLimitCard(
                    title: "Açık Pozisyon",
                    current: Double(openPositionsCount) / 15.0,
                    limit: 1.0,
                    isMinimum: false,
                    icon: "square.stack.3d.up.fill",
                    currentText: "\(openPositionsCount)/15",
                    description: "Portföy dağılımı bozulmasın diye eşik 15 pozisyon ile sınırlandırılır."
                )
                RiskLimitCard(
                    title: "En Büyük Pozisyon",
                    current: maxPositionWeight,
                    limit: 0.15,
                    isMinimum: false,
                    icon: "scalemass.fill",
                    description: "Tek varlık yoğunlaşması %15 üstüne çıkarsa sistem temkinli davranır."
                )
            }

            EducationCard(
                title: "Bu panel neyi korur?",
                content: "Trade Brain, getiri kovalamadan önce hayatta kalmayı hedefler. Bu üç sınır ihlal edildiğinde alım kararları zayıflar, satış veya azaltma planları öne çekilir.",
                icon: "lock.shield.fill"
            )
        }
    }

    private var calendarSection: some View {
        sectionCard {
            SectionHeader(title: "Yaklaşan Olaylar", icon: "calendar.badge.clock", color: InstitutionalTheme.Colors.primary)

            let events = EventCalendarService.shared.getUpcomingEvents(days: 14)

            if events.isEmpty {
                BrainEmptyCard(
                    icon: "calendar.badge.checkmark",
                    title: "Kritik olay görünmüyor",
                    subtitle: "Önümüzdeki 14 gün içinde planı bozacak bir takvim girdisi yok."
                )
            } else {
                ForEach(events) { event in
                    EventCard(event: event)
                }
            }

            EducationCard(
                title: "Takvim neden önemli?",
                content: "Bilanço, FED ve yüksek etkili veri günleri fiyatı rejim dışında hareket ettirebilir. Trade Brain bu dönemlerde yeni alımı kısmayı ve mevcut planı sıkılaştırmayı tercih eder.",
                icon: "clock.badge.exclamationmark.fill"
            )
        }
    }

    private var educationSection: some View {
        sectionCard {
            SectionHeader(title: "Trade Brain Öğretici Katman", icon: "book.closed.fill", color: InstitutionalTheme.Colors.primary)

            LessonCard(
                number: 1,
                title: "Önce tez, sonra işlem",
                content: "Pozisyona girişte plan yoksa sistem bunu eksik kabul eder. Tez, geçersizlik ve ilk üç adım tanımlanmadan sağlıklı yönetim başlamaz.",
                isCompleted: true
            )

            LessonCard(
                number: 2,
                title: "Aether adaptasyonu",
                content: "Makro duruş savunmaya geçtiğinde, satış/azaltma adımları öne çekilir. Bu yüzden aynı hisse farklı haftalarda farklı hızda yönetilir.",
                isCompleted: true
            )

            LessonCard(
                number: 3,
                title: "Konsey güven skoru",
                content: "Güven sert düşerse plan, kâr hedefini büyütmek yerine riski küçültmeye döner. Amaç tahmin etmek değil, zararı sınırlamaktır.",
                isCompleted: true
            )

            LessonCard(
                number: 4,
                title: "Yürütme kanıtı",
                content: "Her tetik loglanır: ne oldu, neden oldu, hangi adım çalıştı. Portföy ekranındaki durum bandı bu zinciri canlı olarak gösterir.",
                isCompleted: false
            )

            EducationCard(
                title: "Pratik kullanım",
                content: "Pozisyon kartlarında önce sonraki adımı, ardından Aether ve konsey yönünü kontrol edin. Çelişki varsa planı küçültüp tekrar dengeleyin.",
                icon: "graduationcap.fill"
            )
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: InstitutionalTheme.Spacing.sm) {
            content()
        }
        .padding(InstitutionalCardScale.standard.padding)
        .institutionalCard(scale: .standard, elevated: true)
    }

    private var isAutoPilotActive: Bool { executionState.isAutoPilotEnabled }

    private var openPositionsCount: Int {
        filteredOpenTrades.count
    }

    private var cashRatio: Double {
        let equity = max(filteredEquity, 1)
        return filteredBalance / equity
    }

    private var upcomingEventsCount: Int {
        EventCalendarService.shared.getUpcomingEvents(days: 7).count
    }

    private var riskStatus: String {
        switch healthSnapshot.status {
        case .healthy: return "NORMAL"
        case .warning: return "İZLE"
        case .critical: return "YÜKSEK"
        }
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

    private func marketHighlightColor(_ mode: MarketFilter) -> Color {
        switch mode {
        case .all: return InstitutionalTheme.Colors.surface3
        case .global: return InstitutionalTheme.Colors.primary.opacity(0.30)
        case .bist: return InstitutionalTheme.Colors.warning.opacity(0.30)
        }
    }

    private func statusColor(for status: PortfolioRiskManager.HealthStatus) -> Color {
        switch status {
        case .healthy: return InstitutionalTheme.Colors.positive
        case .warning: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    private func aetherColor(for stance: MacroStance) -> Color {
        switch stance {
        case .riskOn: return InstitutionalTheme.Colors.positive
        case .cautious: return InstitutionalTheme.Colors.warning
        case .defensive: return InstitutionalTheme.Colors.warning
        case .riskOff: return InstitutionalTheme.Colors.negative
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
                title: "EKRANLAR",
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
                        deepLinkManager.navigate(to: .home)
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
                title: "TRADE BRAIN",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Sekme: Pozisyon", subtitle: "Plan yönetimi", icon: "waveform.path.ecg") {
                        selectedTab = .positions
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sekme: Risk", subtitle: "Risk panosu", icon: "shield") {
                        selectedTab = .risk
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sekme: Takvim", subtitle: "Kritik tarihler", icon: "calendar") {
                        selectedTab = .calendar
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sekme: Öğren", subtitle: "Çalışma prensibi", icon: "book") {
                        selectedTab = .learn
                        showDrawer = false
                    },
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
                title: "ARAÇLAR",
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

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
        }
    }
}

struct QuickStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(color.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

struct DecisionStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(color.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(color.opacity(0.34), lineWidth: 1)
                )
        )
    }
}

struct DecisionPulseCard: View {
    let decision: ArgusGrandDecision

    private var actionColor: Color {
        switch decision.action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(decision.symbol)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text(decision.action.rawValue)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(actionColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(actionColor.opacity(0.18))
                    )
            }

            Text(decision.reasoning)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(2)

            HStack {
                Text("Konsey Güveni")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("%\(Int(decision.confidence * 100))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.64))
        )
    }
}

struct BrainEmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(title)
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(subtitle)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.46))
        )
    }
}

struct EducationCard: View {
    let title: String
    let content: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(content)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.primary.opacity(0.10))
        )
    }
}

struct LessonCard: View {
    let number: Int
    let title: String
    let content: String
    let isCompleted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isCompleted ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.surface3)
                    .frame(width: 28, height: 28)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                } else {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(content)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.55))
        )
    }
}

struct RiskLimitCard: View {
    let title: String
    let current: Double
    let limit: Double
    let isMinimum: Bool
    let icon: String
    var currentText: String? = nil
    let description: String

    private var isWithinLimit: Bool {
        isMinimum ? current >= limit : current <= limit
    }

    private var barProgress: Double {
        if isMinimum {
            return min(max(current / limit, 0.0), 1.6) / 1.6
        }
        return min(max(current / limit, 0.0), 1.0)
    }

    private var metricColor: Color {
        isWithinLimit ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(metricColor)
                Text(title)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text(currentText ?? "%\(Int(current * 100))")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(metricColor)
                Text(isMinimum ? "min %\(Int(limit * 100))" : "max %\(Int(limit * 100))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(metricColor.opacity(0.9))
                        .frame(width: geo.size.width * barProgress)
                }
            }
            .frame(height: 8)

            Text(description)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.6))
        )
    }
}

struct EventCard: View {
    let event: EventCalendarService.MarketEvent

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: event.date).day ?? 0
    }

    private var riskColor: Color {
        switch event.type.riskLevel {
        case .low: return InstitutionalTheme.Colors.positive
        case .medium: return InstitutionalTheme.Colors.warning
        case .high: return InstitutionalTheme.Colors.negative
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(event.date.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(event.date.formatted(.dateTime.month(.abbreviated)))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface3.opacity(0.65))
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.symbol ?? "MARKET")
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(event.type.rawValue)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(daysUntil == 0 ? "Bugün" : "\(daysUntil) gün")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(riskColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(riskColor.opacity(0.16)))
                }

                Text(event.title)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
                if let description = event.description {
                    Text(description)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.52))
        )
    }
}

struct PositionPlanCard: View {
    let trade: Trade
    let plan: PositionPlan?
    let decision: ArgusGrandDecision?
    let currentPrice: Double
    let onTap: () -> Void

    @State private var delta: PositionDeltaTracker.PositionDelta?

    private var pnlPercent: Double {
        guard trade.entryPrice > 0 else { return 0 }
        return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }

    private var pnlColor: Color {
        pnlPercent >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }

    private var completedStepsCount: Int {
        plan?.executedSteps.count ?? 0
    }

    private var totalStepsCount: Int {
        guard let plan else { return 0 }
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        return scenarios.reduce(0) { $0 + $1.steps.count }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trade.symbol)
                            .font(InstitutionalTheme.Typography.headline)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("\(String(format: "%.2f", trade.quantity)) adet")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Text("\(pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(pnlColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(pnlColor.opacity(0.18))
                        )
                }

                if let decision {
                    HStack {
                        Text("Konsey")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Spacer()
                        Text(decision.action.rawValue)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(actionColor(decision.action))
                        Text("%\(Int(decision.confidence * 100))")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    HStack {
                        Text("Aether")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Spacer()
                        Text(decision.aetherDecision.stance.rawValue)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(aetherColor(decision.aetherDecision.stance))
                    }
                }

                if let plan {
                    HStack {
                        Text("Plan ilerleme")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Spacer()
                        Text("\(completedStepsCount)/\(totalStepsCount)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    if let nextStep = findNextStep(in: plan) {
                        Text("\(nextStep.trigger.displayText) → \(nextStep.action.displayText)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("Plan oluşturulmadı")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.warning)
                }

                if let delta {
                    HStack {
                        Text("Delta")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Spacer()
                        Text(delta.significance.rawValue)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(deltaColor(delta.significance))
                    }
                    Text(delta.summaryText)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface3.opacity(0.54))
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(pnlColor.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear(perform: recalculateDelta)
        .onChange(of: currentPrice) { _ in
            recalculateDelta()
        }
    }

    private func findNextStep(in plan: PositionPlan) -> PlannedAction? {
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        for scenario in scenarios where scenario.isActive {
            for step in scenario.steps.sorted(by: { $0.priority < $1.priority }) where !plan.executedSteps.contains(step.id) {
                return step
            }
        }
        return nil
    }

    private func recalculateDelta() {
        guard let plan else {
            delta = nil
            return
        }
        let currentDecision = SignalStateViewModel.shared.grandDecisions[trade.symbol]
        let currentOrion = SignalStateViewModel.shared.orionScores[trade.symbol]?.score ?? plan.originalSnapshot.orionScore
        delta = PositionDeltaTracker.shared.calculateDelta(
            for: trade,
            entrySnapshot: plan.originalSnapshot,
            currentOrionScore: currentOrion,
            currentGrandDecision: currentDecision,
            currentPrice: currentPrice,
            currentRSI: currentDecision?.orionDetails?.components.rsi
        )
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

    private func deltaColor(_ significance: PositionDeltaTracker.ChangeSignificance) -> Color {
        switch significance {
        case .low: return InstitutionalTheme.Colors.textSecondary
        case .medium: return InstitutionalTheme.Colors.primary
        case .high: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }
}

struct PositionPlanDetailView: View {
    let plan: PositionPlan
    let currentPrice: Double
    let decision: ArgusGrandDecision?
    let candles: [Candle]
    let eventRisk: EventCalendarService.EventRiskAssessment?

    @Environment(\.dismiss) private var dismiss

    private var pnlPercent: Double {
        guard plan.originalSnapshot.entryPrice > 0 else { return 0 }
        return ((currentPrice - plan.originalSnapshot.entryPrice) / plan.originalSnapshot.entryPrice) * 100
    }

    private var pnlValue: Double {
        (currentPrice - plan.originalSnapshot.entryPrice) * plan.initialQuantity
    }

    private var pnlColor: Color {
        pnlPercent >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }

    private var nextStep: PlannedAction? {
        plan.nextPendingStep
    }

    private var profileColor: Color {
        if (eventRisk?.shouldAvoidNewPosition ?? false) || estimatedVolatility > 0.05 {
            return InstitutionalTheme.Colors.negative
        }
        if estimatedVolatility < 0.02 {
            return InstitutionalTheme.Colors.positive
        }
        return InstitutionalTheme.Colors.warning
    }

    private var profileTitle: String {
        if (eventRisk?.shouldAvoidNewPosition ?? false) || estimatedVolatility > 0.05 {
            return "Savunmacı Mod"
        }
        if estimatedVolatility < 0.02 {
            return "Atak Mod"
        }
        return "Dengeli Mod"
    }

    private var estimatedVolatility: Double {
        guard candles.count >= 8, currentPrice > 0 else { return 0.03 }
        let sample = Array(candles.suffix(24))
        guard sample.count >= 2 else { return 0.03 }

        var ranges: [Double] = []
        for index in 1..<sample.count {
            let current = sample[index]
            let prev = sample[index - 1]
            let tr = max(current.high - current.low, abs(current.high - prev.close), abs(current.low - prev.close))
            ranges.append(tr)
        }
        guard !ranges.isEmpty else { return 0.03 }
        let atr = ranges.reduce(0, +) / Double(ranges.count)
        return atr / currentPrice
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.originalSnapshot.symbol)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                                HStack(spacing: 8) {
                                    Text(plan.originalSnapshot.councilAction.rawValue)
                                        .font(InstitutionalTheme.Typography.micro)
                                        .foregroundColor(colorForAction(plan.originalSnapshot.councilAction))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(colorForAction(plan.originalSnapshot.councilAction).opacity(0.18))
                                        )
                                    Text("Kalite \(plan.originalSnapshot.entryQualityScore)/100")
                                        .font(InstitutionalTheme.Typography.micro)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "%.2f", currentPrice))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text("\(pnlPercent >= 0 ? "+" : "")\(String(format: "%.2f", pnlPercent))%")
                                    .font(InstitutionalTheme.Typography.bodyStrong)
                                    .foregroundColor(pnlColor)
                                Text("\(pnlValue >= 0 ? "+" : "")\(String(format: "%.2f", pnlValue))")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(pnlColor)
                            }
                        }
                    }

                    sectionCard {
                        SectionHeader(title: "Plan Özeti", icon: "list.bullet.clipboard.fill", color: InstitutionalTheme.Colors.primary)

                        HStack {
                            detailMetric("İlerleme", "\(plan.completedStepCount)/\(plan.totalStepCount)")
                            Spacer()
                            detailMetric("Miktar", String(format: "%.2f", plan.initialQuantity))
                            Spacer()
                            detailMetric("Yaş", "\(plan.ageInDays) gün")
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(InstitutionalTheme.Colors.surface3)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(InstitutionalTheme.Colors.primary)
                                    .frame(width: geo.size.width * plan.completionRatio)
                            }
                        }
                        .frame(height: 8)

                        if let nextStep {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sıradaki adım")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                Text(nextStep.trigger.displayText)
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text(nextStep.action.displayText)
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                    .fill(InstitutionalTheme.Colors.surface3.opacity(0.6))
                            )
                        }

                        Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
                        Text(plan.thesis)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("Geçersizlik: \(plan.invalidation)")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }

                    sectionCard {
                        SectionHeader(title: "Sembol Profili", icon: "shield.lefthalf.filled", color: profileColor)
                        HStack {
                            Text(profileTitle)
                                .font(InstitutionalTheme.Typography.bodyStrong)
                                .foregroundColor(profileColor)
                            Spacer()
                            Text("Volatilite \(Int(estimatedVolatility * 100))%")
                                .font(InstitutionalTheme.Typography.micro)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }

                        if let decision {
                            HStack {
                                detailMetric("Konsey", decision.action.rawValue)
                                Spacer()
                                detailMetric("Güven", "%\(Int(decision.confidence * 100))")
                                Spacer()
                                detailMetric("Aether", decision.aetherDecision.stance.rawValue)
                            }
                        }

                        if let warnings = eventRisk?.warnings, !warnings.isEmpty {
                            Divider().overlay(InstitutionalTheme.Colors.borderSubtle)
                            ForEach(warnings.prefix(3), id: \.self) { warning in
                                Text("• \(warning)")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.warning)
                            }
                        }
                    }

                    let scenarios = plan.orderedScenarios
                    ForEach(scenarios) { scenario in
                        ScenarioCard(
                            scenario: scenario,
                            executedSteps: plan.executedSteps,
                            nextStepID: nextStep?.id
                        )
                    }
                }
                .padding(InstitutionalTheme.Spacing.md)
            }
            .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(plan.originalSnapshot.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(12)
            .institutionalCard(scale: .standard, elevated: true)
    }

    private func detailMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    private func colorForAction(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }
}

struct ScenarioCard: View {
    let scenario: Scenario
    let executedSteps: [UUID]
    let nextStepID: UUID?

    private var scenarioColor: Color {
        switch scenario.type {
        case .bullish: return InstitutionalTheme.Colors.positive
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .bearish: return InstitutionalTheme.Colors.negative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(scenario.type.rawValue)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(scenarioColor)
                Spacer()
                if scenario.isActive {
                    Text("AKTİF")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(scenarioColor.opacity(0.30)))
                }
            }

            ForEach(scenario.steps.sorted(by: { $0.priority < $1.priority })) { step in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(executedSteps.contains(step.id) ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.textTertiary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(step.trigger.displayText)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .strikethrough(executedSteps.contains(step.id))
                            if step.id == nextStepID {
                                Text("SONRAKİ")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(InstitutionalTheme.Colors.primary.opacity(0.18))
                                    )
                            }
                        }
                        Text(step.action.displayText)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .institutionalCard(scale: .standard, elevated: true)
    }
}

#Preview {
    TradeBrainView()
        .environmentObject(TradingViewModel())
}
