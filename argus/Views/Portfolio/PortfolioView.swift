import SwiftUI

struct PortfolioView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var selectedEngine: AutoPilotEngineFilter = .all
    @State private var showNewTradeSheet = false
    @State private var showHistory = false
    @State private var selectedTrade: Trade? // For Detail View
    @State private var selectedMarket: TradeMarket = .global // Market Switcher State
    
    // Model Info State
    @State private var showModelInfo = false
    @State private var selectedEntityForInfo: ArgusSystemEntity = .corse // Default
    @State private var showTradeBrain = false // Trade Brain UI State
    @State private var showDrawer = false // Contextual Drawer State
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Sell Logic
    @State private var showSellConfirmation = false
    @State private var tradeToSell: Trade?
    
    // Plan Editor Logic
    @State private var tradeToEdit: Trade?
    
    // TradeMarket artık Models/TradeMarket.swift içinde tanımlı
    
    enum AutoPilotEngineFilter: String, CaseIterable {
        case all = "Genel Bakış"
        case corse = "Corse (Swing)"
        case pulse = "Pulse (Scalp)"
        case scouting = "Gözcü (Canlı)"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                
                // Contextual Drawer
                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                        .zIndex(100)
                }
                
                VStack(spacing: 0) {
                // 2. CONTENT SCROLL
                    ScrollView {
                        VStack(spacing: 20) {
                             // 1. HEADER (Artık ScrollView içinde)
                            LiquidDashboardHeader(
                                viewModel: viewModel,
                                selectedMarket: $selectedMarket,
                                onBrainTap: { showTradeBrain = true },
                                onHistoryTap: { showHistory = true },
                                onDrawerTap: { withAnimation { showDrawer = true } }
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            TradeBrainStatusBand(
                                viewModel: viewModel,
                                market: selectedMarket,
                                openTradeBrain: { showTradeBrain = true }
                            )
                            .padding(.horizontal)

                            PortfolioPlanBoard(
                                viewModel: viewModel,
                                market: selectedMarket,
                                openTradeBrain: { showTradeBrain = true }
                            )
                            .padding(.horizontal)
                            
                            // A. REPORTS & SELECTOR
                            PortfolioReportsView(viewModel: viewModel, mode: selectedMarket)
                            
                            if selectedMarket == .global {
                                EngineSelector(selected: $selectedEngine)
                            }
                            
                            // B. TRADE LIST
                            LazyVStack(spacing: 16) {
                                if selectedMarket == .global {
                                    // GLOBAL LIST
                                    if selectedEngine == .all {
                                        if !viewModel.globalPortfolio.isEmpty {
                                            ForEach(viewModel.globalPortfolio.filter { $0.isOpen }) { trade in
                                                UnifiedPositionCard(
                                                    trade: trade,
                                                    currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                                                    market: .global,
                                                    onEdit: {
                                                        openPlanEditor(for: trade)
                                                    },
                                                    onSell: {
                                                        tradeToSell = trade
                                                        showSellConfirmation = true
                                                    }
                                                )
                                                .onTapGesture {
                                                    selectedTrade = trade
                                                }
                                            }
                                        } else {
                                            EmptyPortfolioState()
                                        }
                                    } else if selectedEngine == .scouting {
                                        // Scouting View (Placeholder for Radar)
                                        // Scouting View (Placeholder for Radar)
                                        // Filter logs by market (Using VM helper)
                                        if !viewModel.globalScoutLogs.isEmpty {
                                            ForEach(viewModel.globalScoutLogs.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { log in
                                                ScoutHistoryRow(log: log)
                                            }
                                        } else {
                                            VStack(spacing: 16) {
                                                Image(systemName: "binoculars.fill")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary.opacity(0.5))
                                                Text("Gözcü Taraması Bekleniyor...")
                                                    .font(.headline)
                                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            }
                                            .padding(.top, 40)
                                        }
                                    } else {
                                        // Filtered View
                                        let targetEngine: AutoPilotEngine? = (selectedEngine == .corse) ? .corse : .pulse
                                        let filtered = viewModel.globalPortfolio.filter { $0.isOpen && $0.engine == targetEngine }
                                        
                                        if !filtered.isEmpty {
                                            ForEach(filtered) { trade in
                                                UnifiedPositionCard(
                                                    trade: trade,
                                                    currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                                                    market: .global,
                                                    onEdit: {
                                                        openPlanEditor(for: trade)
                                                    },
                                                    onSell: {
                                                        tradeToSell = trade
                                                        showSellConfirmation = true
                                                    }
                                                )
                                                .onTapGesture {
                                                    selectedTrade = trade
                                                }
                                            }
                                        } else {
                                            Text("\(selectedEngine.rawValue) motorunda açık işlem yok.")
                                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                                .padding(.top, 40)
                                        }
                                    }
                                } else {
                                    // BIST LIST
                                    if !viewModel.bistOpenPortfolio.isEmpty {
                                        ForEach(viewModel.bistOpenPortfolio) { trade in
                                            UnifiedPositionCard(
                                                trade: trade,
                                                currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                                                market: .bist,
                                                onEdit: {
                                                    openPlanEditor(for: trade)
                                                },
                                                onSell: {
                                                    tradeToSell = trade
                                                    showSellConfirmation = true
                                                }
                                            )
                                            .onTapGesture {
                                                selectedTrade = trade
                                            }
                                        }
                                    } else {
                                        VStack(spacing: 16) {
                                            Image(systemName: "case.fill")
                                                .font(.system(size: 48))
                                                .foregroundColor(InstitutionalTheme.Colors.warning.opacity(0.45))
                                            Text("BIST Portföyün Boş")
                                                .font(.headline)
                                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                            Text("Piyasa ekranından BIST hissesi al.")
                                                .font(.caption)
                                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                        }
                                        .padding(.top, 40)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showNewTradeSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(InstitutionalTheme.Colors.primary)
                                .clipShape(Circle())
                                .shadow(color: InstitutionalTheme.Colors.primary.opacity(0.35), radius: 10, x: 0, y: 5)
                            }
                        .padding()
                    }
                }
                // Model Info Card Overlay
                if showModelInfo {
                    SystemInfoCard(entity: selectedEntityForInfo, isPresented: $showModelInfo)
                        .zIndex(100)
                }
                
                // Trade Brain Alert Banner
                if let latestAlert = viewModel.planAlerts.first {
                    VStack {
                        TradeBrainAlertBanner(
                            alert: latestAlert,
                            onDismiss: {
                                ExecutionStateViewModel.shared.planAlerts.removeFirst()
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 60)
                        
                        Spacer()
                    }
                    .zIndex(99)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: viewModel.planAlerts.count)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewTradeSheet) {
                NewTradeSheet(viewModel: viewModel)
                    .presentationDetents([.fraction(0.6)]) // Manage height better
            }
            .sheet(item: $selectedTrade) { trade in
                TradeDetailSheet(trade: trade, viewModel: viewModel)
            }
            .sheet(isPresented: $showHistory) {
                TransactionHistorySheet(viewModel: viewModel, marketMode: selectedMarket)
            }
            .sheet(isPresented: $showTradeBrain) {
                TradeBrainView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $tradeToEdit) { trade in
                 if let plan = PositionPlanStore.shared.getPlan(for: trade.id) {
                     PlanEditorSheet(trade: trade, currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice, plan: plan)
//                         .presentationDetents([.medium, .large])
                 } else {
                     Text("Plan yüklenemedi.")
                 }
            }
            .alert("Satış Emri", isPresented: $showSellConfirmation) {
                Button("Sat", role: .destructive) {
                    if let trade = tradeToSell {
                        viewModel.sell(tradeId: trade.id, currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice, reason: "Portfolio User manual sell")
                    }
                }
                Button("İptal", role: .cancel) { }
            } message: {
                if let trade = tradeToSell {
                    Text("\(trade.symbol) pozisyonunu kapatmak istiyor musunuz?")
                } else {
                    Text("Pozisyon satılsın mı?")
                }
            }
            // PERFORMANS: Gereksiz Aether yüklemesi kaldırıldı
            // MacroRegimeService zaten Bootstrap'ta çağrılıyor (Phase 4)
            // .onAppear { } // Artık boş - ağır işlem yok
        }
    }

    private func openPlanEditor(for trade: Trade) {
        if PositionPlanStore.shared.getPlan(for: trade.id) == nil {
            PositionPlanStore.shared.syncWithPortfolio(
                trades: [trade],
                grandDecisions: viewModel.grandDecisions
            )
        }
        tradeToEdit = trade
    }
    
    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "EKRANLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )
        
        var portfolioItems: [ArgusDrawerView.DrawerItem] = [
            ArgusDrawerView.DrawerItem(title: "Yeni Islem", subtitle: "Pozisyon ac", icon: "plus.circle") {
                showNewTradeSheet = true
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Islem Gecmisi", subtitle: "Kapanan islemler", icon: "clock.arrow.circlepath") {
                showHistory = true
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Trade Brain", subtitle: "Yonetim paneli", icon: "brain") {
                showTradeBrain = true
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Global Portfoy", subtitle: "Pazar degistir", icon: "globe") {
                selectedMarket = .global
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "BIST Portfoy", subtitle: "Pazar degistir", icon: "chart.bar") {
                selectedMarket = .bist
                showDrawer = false
            }
        ]
        
        if selectedMarket == .global {
            portfolioItems.append(contentsOf: [
                ArgusDrawerView.DrawerItem(title: "Motor: Genel", subtitle: "Tum islemler", icon: "circle.grid.2x2") {
                    selectedEngine = .all
                    showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Corse", subtitle: "Swing", icon: "chart.line.uptrend.xyaxis") {
                    selectedEngine = .corse
                    showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Pulse", subtitle: "Scalp", icon: "bolt") {
                    selectedEngine = .pulse
                    showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Gozcu", subtitle: "Canli tarama", icon: "binoculars") {
                    selectedEngine = .scouting
                    showDrawer = false
                }
            ])
        }
        
        sections.append(ArgusDrawerView.DrawerSection(title: "PORTFOY", items: portfolioItems))
        sections.append(commonToolsSection(openSheet: openSheet))
        
        return sections
    }
    
    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "ARACLAR",
            items: [
                ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                    openSheet(.calendar)
                },
                ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                    openSheet(.dictionary)
                },
                ArgusDrawerView.DrawerItem(title: "Unlu Finans Sozleri", subtitle: "Finans alintilari", icon: "quote.opening") {
                    openSheet(.financeWisdom)
                },
                ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sagligi", icon: "waveform.path.ecg") {
                    openSheet(.systemHealth)
                },
                ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                    openSheet(.feedback)
                }
            ]
        )
    }
    private func mapAndShowInfo(_ engine: AutoPilotEngine) {
        switch engine {
        case .corse: selectedEntityForInfo = .corse
        case .pulse: selectedEntityForInfo = .pulse
        case .shield: selectedEntityForInfo = .shield
        case .hermes: selectedEntityForInfo = .hermes
        case .manual: selectedEntityForInfo = .corse // Fallback
        }
        withAnimation { showModelInfo = true }
    }
}

struct PortfolioPlanBoard: View {
    @ObservedObject var viewModel: TradingViewModel
    let market: TradeMarket
    let openTradeBrain: () -> Void

    private var filteredOpenTrades: [Trade] {
        switch market {
        case .global:
            return viewModel.globalPortfolio.filter { $0.isOpen }
        case .bist:
            return viewModel.bistOpenPortfolio.filter { $0.isOpen }
        }
    }

    private var plansByTrade: [UUID: PositionPlan] {
        var plans: [UUID: PositionPlan] = [:]
        for trade in filteredOpenTrades {
            if let plan = PositionPlanStore.shared.getPlan(for: trade.id) {
                plans[trade.id] = plan
            }
        }
        return plans
    }

    private var coveredCount: Int {
        plansByTrade.count
    }

    private var coverageRatio: Double {
        guard !filteredOpenTrades.isEmpty else { return 0 }
        return Double(coveredCount) / Double(filteredOpenTrades.count)
    }

    private var pendingActionCount: Int {
        plansByTrade.values.filter { $0.nextPendingStep != nil }.count
    }

    private var nearRiskCount: Int {
        filteredOpenTrades.filter { trade in
            guard let plan = plansByTrade[trade.id], let riskStep = plan.primaryRiskStep else { return false }
            return isTriggerNear(riskStep.trigger, for: trade, plan: plan)
        }.count
    }

    private var topSignal: ChimeraSignal? {
        filteredOpenTrades
            .compactMap { SignalStateViewModel.shared.chimeraSignals[$0.symbol] }
            .max(by: { $0.severity < $1.severity })
    }

    private var focusText: String? {
        var best: (trade: Trade, step: PlannedAction)?
        for trade in filteredOpenTrades {
            guard let plan = plansByTrade[trade.id], let next = plan.nextPendingStep else { continue }
            if best == nil || next.priority < best!.step.priority {
                best = (trade, next)
            }
        }
        guard let best else { return nil }
        return "\(best.trade.symbol) • \(best.step.trigger.displayText)"
    }

    var body: some View {
        Button(action: openTradeBrain) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PLAN PANOSU")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .tracking(1.0)
                    Spacer()
                    Text("%\(Int(coverageRatio * 100)) kapsama")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(InstitutionalTheme.Colors.primary.opacity(0.14))
                        )
                }

                HStack(spacing: 8) {
                    metricCell(title: "Planlı", value: "\(coveredCount)/\(filteredOpenTrades.count)", color: InstitutionalTheme.Colors.primary)
                    metricCell(title: "Hazır Aksiyon", value: "\(pendingActionCount)", color: InstitutionalTheme.Colors.positive)
                    metricCell(title: "Risk Yakın", value: "\(nearRiskCount)", color: nearRiskCount > 0 ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.textSecondary)
                }

                if let topSignal {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(chimeraColor(topSignal.type))
                        Text("Premium Sinyal: \(topSignal.title)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(chimeraColor(topSignal.type))
                        Spacer()
                    }
                }

                if let focusText {
                    Text("Odak adım: \(focusText)")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(InstitutionalTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.primary.opacity(0.20), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func metricCell(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.75))
        )
    }

    private func isTriggerNear(_ trigger: ActionTrigger, for trade: Trade, plan: PositionPlan) -> Bool {
        let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
        let pnl = ((price - trade.entryPrice) / max(trade.entryPrice, 0.0001)) * 100

        switch trigger {
        case .priceAbove(let target):
            let remaining = ((target - price) / max(price, 0.0001)) * 100
            return remaining <= 2.0
        case .priceBelow(let stop):
            let remaining = ((price - stop) / max(price, 0.0001)) * 100
            return remaining <= 2.0
        case .gainPercent(let target):
            return (target - pnl) <= 3.0
        case .lossPercent(let target):
            return (pnl + target) <= 3.0
        case .daysElapsed(let days):
            return (days - plan.ageInDays) <= 1
        default:
            return false
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
}

// MARK: - Trade Brain Status Band
struct TradeBrainStatusBand: View {
    @ObservedObject var viewModel: TradingViewModel
    let market: TradeMarket
    let openTradeBrain: () -> Void

    private var filteredOpenTrades: [Trade] {
        switch market {
        case .global:
            return viewModel.globalPortfolio.filter { $0.isOpen }
        case .bist:
            return viewModel.bistOpenPortfolio.filter { $0.isOpen }
        }
    }

    private var filteredBalance: Double {
        market == .bist ? viewModel.bistBalance : viewModel.balance
    }

    private var filteredEquity: Double {
        let value = filteredOpenTrades.reduce(0.0) { total, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return total + trade.quantity * price
        }
        return filteredBalance + value
    }

    private var filteredPlans: [PositionPlan] {
        filteredOpenTrades.compactMap { PositionPlanStore.shared.getPlan(for: $0.id) }
    }

    private var health: PortfolioRiskManager.PortfolioHealth {
        PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: filteredOpenTrades,
            cashBalance: filteredBalance,
            totalEquity: max(filteredEquity, 1),
            quotes: viewModel.quotes
        )
    }

    private var dominantDecision: ArgusGrandDecision? {
        filteredOpenTrades
            .compactMap { viewModel.grandDecisions[$0.symbol] }
            .max(by: { $0.confidence < $1.confidence })
    }

    private var topSignal: ChimeraSignal? {
        filteredOpenTrades
            .compactMap { SignalStateViewModel.shared.chimeraSignals[$0.symbol] }
            .max(by: { $0.severity < $1.severity })
    }

    private var planCoverage: Double {
        guard !filteredOpenTrades.isEmpty else { return 0 }
        return Double(filteredPlans.count) / Double(filteredOpenTrades.count)
    }

    private var pendingStepCount: Int {
        filteredPlans.filter { $0.nextPendingStep != nil }.count
    }

    private var actionColor: Color {
        guard let decision = dominantDecision else { return InstitutionalTheme.Colors.textSecondary }
        switch decision.action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }

    private var healthColor: Color {
        switch health.status {
        case .healthy: return InstitutionalTheme.Colors.positive
        case .warning: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    var body: some View {
        Button(action: openTradeBrain) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRADE BRAIN DURUMU")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .tracking(1.0)

                    if let decision = dominantDecision {
                        Text("\(decision.symbol) • \(decision.action.rawValue) • %\(Int(decision.confidence * 100)) güven")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Açık pozisyon yok, yeni plan oluşmadı")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text("%\(Int(planCoverage * 100)) plan")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.primary)
                        Text("•")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("\(pendingStepCount) bekleyen adım")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    if let topSignal {
                        Text("Sinyal: \(topSignal.title)")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(chimeraColor(topSignal.type))
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text("Skor \(Int(health.score))")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(healthColor)
                    Text("\(filteredOpenTrades.count) pozisyon")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(actionColor)
            }
            .padding(InstitutionalTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(actionColor.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
}

// MARK: - History Sheet
struct TransactionHistorySheet: View {
    @ObservedObject var viewModel: TradingViewModel
    var marketMode: TradeMarket // Global or BIST
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTxn: Transaction? // State for tapping
    
    // Filtered Transactions
    var filteredTransactions: [Transaction] {
        viewModel.transactionHistory.filter { txn in
            if marketMode == .bist {
                return txn.currency == .TRY
            } else {
                return txn.currency == .USD
            }
        }.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if filteredTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "terminal")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary.opacity(0.3))
                        Text(marketMode == .bist ? "BIST Geçmişi Boş" : "Global Geçmiş Boş")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(filteredTransactions) { txn in
                            Button(action: {
                                selectedTxn = txn
                            }) {
                                TransactionConsoleCard(txn: txn)
                            }
                            .listRowInsets(EdgeInsets()) // Full width look
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("İşlem Konsolu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Theme.tint)
                }
            }
            .sheet(item: $selectedTxn) { txn in
                // Look up full snapshot if available
                let snapshot = viewModel.agoraSnapshots.first(where: { $0.id.uuidString == txn.decisionId })
                TransactionDetailView(transaction: txn, snapshot: snapshot)
            }
        }
    }
}

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: Transaction
    let snapshot: DecisionSnapshot?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Transaction Summary
                    VStack(spacing: 8) {
                        Text(transaction.type == .buy ? "ALIŞ İŞLEMİ" : "SATIŞ İŞLEMİ")
                            .font(.headline)
                            .bold()
                            .foregroundColor(transaction.type == .buy ? Theme.positive : Theme.negative)
                        
                        Text(transaction.symbol)
                            .font(.system(size: 32, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(transaction.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // 2. Decision Rationale (The "Why")
                    // Handle MANUAL logic explicitly
                    if transaction.source == "MANUAL" {
                         VStack(alignment: .leading, spacing: 12) {
                             HStack {
                                 Image(systemName: "person.fill.checkmark")
                                     .foregroundColor(Theme.tint)
                                 Text("Manuel İşlem (Kullanıcı Kararı)")
                                     .font(.headline)
                                     .bold()
                                     .foregroundColor(.white)
                             }
                             
                             Text("Bu işlem kullanıcı tarafından manuel olarak girilmiştir. Sistem sinyallerinden bağımsızdır.")
                                 .font(.body)
                                 .foregroundColor(.gray)
                                 .padding()
                                 .background(Theme.secondaryBackground)
                                 .cornerRadius(8)
                             
                             // Optional: Show what the system THOUGHT at that time
                             if let s = snapshot {
                                  DisclosureGroup("O Sırada Argus Ne Düşünüyordu?") {
                                      AgoraDetailPanel(
                                          symbol: transaction.symbol,
                                          snapshot: s,
                                          trace: nil
                                      )
                                      .padding(.top, 8)
                                  }
                                  .foregroundColor(Theme.textSecondary)
                             }
                         }
                         .padding(.horizontal)
                    } else if let s = snapshot {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(Theme.tint)
                                Text("Karar Mekanizması (Argus/Agora)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            
                            AgoraDetailPanel(
                                symbol: transaction.symbol,
                                snapshot: s,
                                trace: nil // If we had trace we could pass it
                            )
                        }
                        .padding(.horizontal)
                    } else {
                        // Fallback
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Karar Notları")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let reason = transaction.reasonCode {
                                Text(reason)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(8)
                            } else {
                                Text("Bu işlem için detaylı karar kaydı bulunamadı.")
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 3. Execution Detail
                    VStack(alignment: .leading, spacing: 16) {
                        Text("İşlem Detayları")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 0) {
                            let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                            DetailRow(text: "Fiyat: \(currencySymbol)\(String(format: "%.2f", transaction.price))")
                            Divider().background(Theme.secondaryBackground)
                            
                            // Highlighted Amount
                            HStack {
                                Text("Toplam Tutar")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", transaction.amount))")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Theme.tint)
                            }
                            .padding()
                            
                            Divider().background(Theme.secondaryBackground)
                            DetailRow(text: "Kaynak: \(transaction.source ?? "N/A")")
                            if let fee = transaction.fee {
                                Divider().background(Theme.secondaryBackground)
                                let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                                DetailRow(text: "Komisyon: \(currencySymbol)\(String(format: "%.2f", fee))")
                            }
                        }
                        .background(Theme.secondaryBackground.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("İşlem Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Console Style History Row
struct TransactionConsoleCard: View {
    let txn: Transaction
    
    var isProfitable: Bool {
        guard let pnl = txn.pnl else { return false }
        return pnl >= 0
    }
    
    var statusColor: Color {
        if txn.type == .buy { return .blue }
        return isProfitable ? Theme.positive : Theme.negative
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Symbol + Date
            HStack {
                Text(txn.symbol)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text(txn.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .monospacedDigit()
            }
            .padding(.bottom, 8)
            
            Divider().background(Theme.textSecondary.opacity(0.2)).padding(.bottom, 8)
            
            // Detail Grid
            HStack(alignment: .top, spacing: 16) {
                // Left: Type & Amount
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(txn.type == .buy ? "[GİRİŞ]" : "[ÇIKIŞ]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(statusColor)
                        
                        if txn.type == .sell, let pnl = txn.pnl {
                            Text(pnl >= 0 ? "KAR" : "ZARAR")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(statusColor.opacity(0.2))
                                .foregroundColor(statusColor)
                                .cornerRadius(4)
                        }
                    }
                    
                    let currencySymbol = txn.symbol.hasSuffix(".IS") ? "₺" : "$"
                    Text("Vol: \(currencySymbol)\(String(format: "%.2f", txn.amount))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Right: Price & PnL
                VStack(alignment: .trailing, spacing: 4) {
                    let currencySymbol = txn.symbol.hasSuffix(".IS") ? "₺" : "$"
                    Text("@ \(currencySymbol)\(String(format: "%.2f", txn.price))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    
                    if txn.type == .sell {
                        if let pnl = txn.pnl, let pct = txn.pnlPercent {
                            HStack(spacing: 4) {
                                let currencySymbol = txn.symbol.hasSuffix(".IS") ? "₺" : "$"
                                Text("\(pnl >= 0 ? "+" : "")\(currencySymbol)\(String(format: "%.2f", pnl))")
                                
                                Text("(\(String(format: "%.1f", pct))%)")
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(statusColor)
                        } else {
                            Text("--") // Legacy Data
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    } else {
                        // Buy Entry
                        Image(systemName: "arrow.down.to.line")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.7))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Components

struct EngineSelector: View {
    @Binding var selected: PortfolioView.AutoPilotEngineFilter
    @Namespace private var animationNamespace
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(PortfolioView.AutoPilotEngineFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selected = filter
                    }
                }) {
                    HStack(spacing: 4) {
                        // Icon
                        Image(systemName: engineIcon(filter))
                            .font(.system(size: 12, weight: selected == filter ? .bold : .regular))
                            .foregroundColor(selected == filter ? engineColor(filter) : Theme.textSecondary)
                        
                        // Label
                        Text(engineLabel(filter))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(selected == filter ? engineColor(filter) : Theme.textSecondary.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if selected == filter {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(engineColor(filter).opacity(0.2))
                                    .matchedGeometryEffect(id: "selector", in: animationNamespace)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Theme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }
    
    func engineIcon(_ filter: PortfolioView.AutoPilotEngineFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2.fill"
        case .corse: return "clock.arrow.2.circlepath"
        case .pulse: return "waveform.path.ecg"
        case .scouting: return "eye.circle.fill"
        }
    }
    
    func engineLabel(_ filter: PortfolioView.AutoPilotEngineFilter) -> String {
        switch filter {
        case .all: return "GENEL"
        case .corse: return "CORSE"
        case .pulse: return "PULSE"
        case .scouting: return "GÖZCÜ"
        }
    }
    
    func engineColor(_ filter: PortfolioView.AutoPilotEngineFilter) -> Color {
        switch filter {
        case .all: return Theme.tint
        case .corse: return .blue
        case .pulse: return .purple
        case .scouting: return .orange
        }
    }
}

struct ScoutCandidateCard: View {
    let signal: TradeSignal
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Engine Color (Orange for Scout)
            Rectangle()
                .fill(Color.orange)
                .frame(width: 4)
                .cornerRadius(2)
            
            // Symbol Icon
            CompanyLogoView(symbol: signal.symbol, size: 44)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(signal.symbol)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("GÖZCÜ ONALI")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Text(signal.reason)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action Button (Manuel Giriş)
            Button(action: {
                // Trigger Manual Buy via ViewModel
                // Logic to buy with calculated quantity?
                // For now, simple standard buy call for user to adjust
                viewModel.buy(symbol: signal.symbol, quantity: 10) // Mock default
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.positive)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
}

struct PortfolioHeader: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        HolographicBalanceCard(viewModel: viewModel)
            .padding(.horizontal)
            .padding(.top, 10)
    }
}

// BIST Portfolio Header - Red Theme
struct BistPortfolioHeader: View {
    @ObservedObject var viewModel: TradingViewModel
    
    // BIST filtered data (No need to re-filter, use ViewModel)
    
    private var totalValue: Double {
        viewModel.getBistPortfolioValue()
    }
    
    private var totalPL: Double {
        viewModel.getBistUnrealizedPnL()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Balance Card
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BIST Portföy Değeri")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("₺\(String(format: "%.0f", totalValue))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    // P/L Badge
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Kar/Zarar")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(totalPL >= 0 ? "+" : "")₺\(totalPL, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(totalPL >= 0 ? .green : .red)
                    }
                }
                
                // Bakiye ve Pozisyon Sayısı
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kullanılabilir Bakiye")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        Text("₺\(viewModel.bistBalance, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Text("\(viewModel.bistPortfolio.filter { $0.isOpen }.count) açık pozisyon")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("🇹🇷")
                        .font(.caption)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}


struct PortfolioCard: View {
    let trade: Trade
    @Binding var selectedTrade: Trade?
    @ObservedObject var viewModel: TradingViewModel
    
    // Callbacks for Info
    var onInfoTap: ((AutoPilotEngine) -> Void)?
    
    var body: some View {
        Button(action: { selectedTrade = trade }) {
            ZStack(alignment: .topLeading) {
                AssetChipView(
                    symbol: trade.symbol,
                    quantity: trade.quantity,
                    currentPrice: viewModel.quotes[trade.symbol]?.currentPrice,
                    entryPrice: trade.entryPrice,
                    engine: trade.engine
                )
                
                // Invisible Hit Area for Info Icon (Approximate location)
                // Since AssetChipView is internal, we can't easily add a button there without refactoring it to take closure.
                // Alternative: Add a clear button on top of the area where the badge is.
                // Or better: Let's refactor AssetChipView to accept an action.
                // START SHORTCUT: Just pass the action to AssetChipView.
                // Modifying PortfolioCard to just wrap AssetChipView.
            }
            .contextMenu {
                Button(role: .destructive) {
                    if let price = viewModel.quotes[trade.symbol]?.currentPrice {
                        viewModel.sell(tradeId: trade.id, currentPrice: price)
                    }
                } label: {
                    Label("Pozisyonu Kapat", systemImage: "xmark.circle")
                }
                
                Button {
                    if let engine = trade.engine {
                        onInfoTap?(engine)
                    }
                } label: {
                    Label("Model Bilgisi", systemImage: "info.circle")
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyPortfolioState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.3))
            Text("Portföyün Boş")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            
            // Motivasyon sözü
            EmptyPortfolioQuote()
                .padding(.top, 8)
        }
        .padding(.top, 40)
    }
}

struct NewTradeSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var symbol: String = ""
    @State private var quantity: Double = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Symbol Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hisse Sembolü")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.textSecondary)
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.textSecondary)
                            TextField("Örn: AAPL", text: $symbol)
                                .foregroundColor(Theme.textPrimary)
                                .font(.headline)
                                .onChange(of: symbol) { _, newValue in
                                    viewModel.search(query: newValue)
                                }
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        
                        if !viewModel.searchResults.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.searchResults, id: \.symbol) { result in
                                        Button(action: {
                                            self.symbol = result.symbol
                                            viewModel.searchResults = []
                                        }) {
                                            HStack {
                                                Text(result.symbol)
                                                    .bold()
                                                    .foregroundColor(Theme.textPrimary)
                                                Spacer()
                                                Text(result.description)
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            .padding()
                                            .background(Theme.cardBackground)
                                        }
                                        Divider()
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        }
                    }
                    
                    // Quantity Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adet")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.textSecondary)
                        HStack {
                            Button(action: { if quantity > 1.0 { quantity -= 1.0 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            Text(String(format: "%.2f", quantity))
                                .font(.title)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            
                            Button(action: { quantity += 1.0 }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.tint)
                            }
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                    }
                    
                    // Summary
                    if let quote = viewModel.quotes[symbol.uppercased()] {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Birim Fiyat")
                                Spacer()
                                let currencySymbol = symbol.uppercased().hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", quote.currentPrice))")
                            }
                            .foregroundColor(Theme.textSecondary)
                            
                            Divider().background(Theme.textSecondary.opacity(0.2))
                            
                            HStack {
                                Text("Toplam")
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                let currencySymbol = symbol.uppercased().hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", quote.currentPrice * quantity))")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.tint)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // Action Button
                    Button(action: executeTrade) {
                        Text("SATIN AL")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(symbol.isEmpty ? Color.gray : Theme.positive)
                            .cornerRadius(16)
                    }
                    .disabled(symbol.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Yeni İşlem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    func executeTrade() {
        guard !symbol.isEmpty else { return }
        viewModel.buy(symbol: symbol.uppercased(), quantity: quantity)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - New Scout Row
struct ScoutHistoryRow: View {
    let log: ScoutLog
    
    var statusColor: Color {
        switch log.status {
        case "ONAYLI": return Theme.positive
        case "RED": return Theme.negative
        case "BEKLE": return .orange
        case "SATIŞ": return .blue
        case "TUT": return .gray
        default: return Theme.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
             // Status Indicator
             Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .cornerRadius(2)
            
             // Symbol
            Text(log.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 60, alignment: .leading)
            
             // Reason & Status
             VStack(alignment: .leading, spacing: 2) {
                 HStack {
                     Text(log.status)
                         .font(.system(size: 10, weight: .bold))
                         .foregroundColor(statusColor)
                         .padding(.horizontal, 4)
                         .padding(.vertical, 2)
                         .background(statusColor.opacity(0.1))
                         .cornerRadius(4)
                     
                     Spacer()
                     
                     Text("Puan: \(Int(log.score))")
                         .font(.caption2)
                         .foregroundColor(Theme.textSecondary)
                 }
                 
                 Text(log.reason)
                     .font(.system(size: 13))
                     .foregroundColor(Theme.textSecondary)
                     .lineLimit(2)
             }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }
}
