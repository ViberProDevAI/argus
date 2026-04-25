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
        case brain
        case learn

        var title: String {
            switch self {
            case .positions: return "Pozisyon"
            case .risk: return "Risk"
            case .calendar: return "Takvim"
            case .brain: return "Beyin"
            case .learn: return "Ogren"
            }
        }

        var icon: String {
            switch self {
            case .positions: return "waveform.path.ecg"
            case .risk: return "shield.lefthalf.filled"
            case .calendar: return "calendar"
            case .brain: return "brain.head.profile"
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

                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "TRADE BRAIN",
                        subtitle: "POZİSYON · RİSK · KARAR",
                        leadingDeco: .bars3([.holo, .text, .text]),
                        actions: [.menu({ showDrawer = true })],
                        status: .custom(
                            dotColor: isAutoPilotActive
                                ? InstitutionalTheme.Colors.positive
                                : InstitutionalTheme.Colors.warning,
                            label: isAutoPilotActive ? "OTOPİLOT AKTİF" : "OTOPİLOT PASİF",
                            trailing: "\(filteredOpenTrades.count) POZİSYON"
                        )
                    )

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
        case .brain:
            brainMemorySection
            brainConfidenceSection
            brainMultiHorizonSection
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

    // MARK: - Trade Brain 3.0 Sections

    private var brainMemorySection: some View {
        sectionCard {
            SectionHeader(title: "Pazar Hafizasi", icon: "brain.head.profile", color: InstitutionalTheme.Colors.primary)
            
            if let multiHorizon = executor.lastMultiHorizonDecisions.first?.value {
                let regimeContext = RegimeDecisionContext(
                    regime: "Notr",
                    vix: 20,
                    historicalWinRate: 0.55,
                    riskScore: 0.25,
                    recommendation: "Normal piyasa kosullari"
                )
                let eventContext = EventDecisionContext(
                    hasHighImpactEvent: false,
                    riskScore: 0.15,
                    warnings: [],
                    eventCount: 0
                )
                
                MarketMemoryBar(
                    regimeContext: regimeContext,
                    eventContext: eventContext
                )
            } else {
                BrainEmptyCard(
                    icon: "brain",
                    title: "Hafiza bekleniyor",
                    subtitle: "Trade Brain 3.0 karar urettiginde pazar hafizasi burada gorunur."
                )
            }
            
            EducationCard(
                title: "Pazar Hafizasi nedir?",
                content: "Gecmis rejim ve olay verilerini kullanarak mevcut piyasa kosullarini degerlendirir. VIX, Fear/Greed ve olay riskini birlestirir.",
                icon: "lightbulb.fill"
            )
        }
    }
    
    private var brainConfidenceSection: some View {
        sectionCard {
            SectionHeader(title: "Guven Kalibrasyonu", icon: "chart.bar.xaxis", color: InstitutionalTheme.Colors.warning)
            
            if let contradiction = executor.lastContradictionAnalyses.first?.value {
                SelfQuestionAlertCard(analysis: contradiction)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                        Text("Celiski tespit edilmedi")
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    Text("Tum moduller ayni yonde oy veriyor. Guven skoru korunabilir.")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(InstitutionalTheme.Colors.positive.opacity(0.1))
                )
            }
            
            EducationCard(
                title: "Kendini Sorgulama",
                content: "Orion, Atlas, Aether ve Hermes modulleri arasindaki celiskileri tespit eder. Gecmis benzer celiskilerde ne oldugunu arastirir.",
                icon: "questionmark.circle.fill"
            )
        }
    }
    
    private var brainMultiHorizonSection: some View {
        sectionCard {
            SectionHeader(title: "Cok Zaman Dilimli Karar", icon: "clock.arrow.circlepath", color: InstitutionalTheme.Colors.primary)
            
            if let multiHorizon = executor.lastMultiHorizonDecisions.first?.value {
                MultiHorizonDecisionCard(decision: multiHorizon)
            } else {
                BrainEmptyCard(
                    icon: "clock",
                    title: "Karar bekleniyor",
                    subtitle: "Scalp, Swing ve Position zaman dilimleri icin kararlar uretiliyor."
                )
            }
            
            HStack(spacing: 8) {
                HorizonInfoBadge(
                    title: "Scalp",
                    description: "5-15 dk",
                    color: InstitutionalTheme.Colors.warning
                )
                HorizonInfoBadge(
                    title: "Swing",
                    description: "1-4 saat",
                    color: InstitutionalTheme.Colors.primary
                )
                HorizonInfoBadge(
                    title: "Position",
                    description: "1-7 gun",
                    color: InstitutionalTheme.Colors.positive
                )
            }
            
            EducationCard(
                title: "Cok Zaman Dilimi",
                content: "Ayni hisse icin farkli zaman dilimlerinde ayri kararlar uretilir. Makro ortama gore en uygun dilim secilir.",
                icon: "gauge.with.dots.needle.67percent"
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
