import SwiftUI

// MARK: - PortfolioView (in-place refactor — ArgusDesignKit v1)
//
// Veri: viewModel.globalPortfolio/bistOpenPortfolio/quotes/planAlerts + PositionPlanStore/ExecutionStateViewModel.
// Korunur: LiquidDashboardHeader, TradeBrainStatusBand, DailyAgendaView, PortfolioPlanBoard,
// PortfolioReportsView, UnifiedPositionCard, TradeBrainAlertBanner, SystemInfoCard, HolographicBalanceCard,
// AssetChipView, CompanyLogoView, NewTradeSheet+TradeDetailSheet+TransactionHistorySheet+TradeBrainView
// +PlanEditorSheet sheet'leri, drawer 3 bölümü ve tüm item'ları.
// Demo veri sıfır — boş durumlar ArgusEmptyState ile anlatılır.

struct PortfolioView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var selectedEngine: AutoPilotEngineFilter = .all
    @State private var showNewTradeSheet = false
    @State private var showHistory = false
    @State private var selectedTrade: Trade?
    @State private var selectedMarket: TradeMarket = .global

    // Model Info State
    @State private var showModelInfo = false
    @State private var selectedEntityForInfo: ArgusSystemEntity = .corse
    @State private var showTradeBrain = false
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    // Sell Logic
    @State private var showSellConfirmation = false
    @State private var tradeToSell: Trade?

    // Plan Editor Logic
    @State private var tradeToEdit: Trade?

    enum AutoPilotEngineFilter: String, CaseIterable {
        case all      = "Genel Bakış"
        case corse    = "Corse (Swing)"
        case pulse    = "Pulse (Scalp)"
        case scouting = "Gözcü (Canlı)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(100)
                }

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            LiquidDashboardHeader(
                                viewModel: viewModel,
                                selectedMarket: $selectedMarket,
                                onBrainTap:   { showTradeBrain = true },
                                onHistoryTap: { showHistory   = true },
                                onDrawerTap:  { withAnimation { showDrawer = true } }
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // 2026-04-30 H-46 — sade Trade Brain band.
                            // Eski TradeBrainStatusBand + DailyAgendaView +
                            // PortfolioPlanBoard kombinasyonu (devasa) →
                            // tek satır kompakt özet, ayrıntılar Trade Brain
                            // ekranında.
                            tradeBrainBand
                                .padding(.horizontal)

                            PortfolioReportsView(viewModel: viewModel, mode: selectedMarket)

                            if selectedMarket == .global {
                                EngineSelector(selected: $selectedEngine)
                            }

                            tradeList
                                .padding(.horizontal)
                                .padding(.bottom, 100)
                        }
                    }
                }

                // FAB: Yeni İşlem
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
                                .shadow(color: InstitutionalTheme.Colors.primary.opacity(0.35),
                                        radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Yeni işlem aç")
                        .padding()
                    }
                }

                if showModelInfo {
                    SystemInfoCard(entity: selectedEntityForInfo, isPresented: $showModelInfo)
                        .zIndex(100)
                }

                // 2026-04-30 H-46: Üstten düşen TradeBrainAlertBanner overlay
                // kaldırıldı. Aynı bilgiler şimdi iki yere yedirilmiş:
                // (1) ilgili pozisyon kartının altında inline alert satırı
                //     (UnifiedPositionCard'a alerts parametresi geçer)
                // (2) Trade Brain status band'inde toplam sayı + özet
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewTradeSheet) {
                NewTradeSheet(viewModel: viewModel)
                    .presentationDetents([.fraction(0.6)])
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $selectedTrade) { trade in
                TradeDetailSheet(trade: trade, viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showHistory) {
                TransactionHistorySheet(viewModel: viewModel, marketMode: selectedMarket)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showTradeBrain) {
                TradeBrainView()
                    .environmentObject(viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $tradeToEdit) { trade in
                if let plan = PositionPlanStore.shared.getPlan(for: trade.id) {
                    PlanEditorSheet(
                        trade: trade,
                        currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                        plan: plan
                    )
                    .preferredColorScheme(.dark)
                } else {
                    Text("Plan yüklenemedi.")
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .preferredColorScheme(.dark)
                }
            }
            .alert("Satış Emri", isPresented: $showSellConfirmation) {
                Button("Sat", role: .destructive) {
                    if let trade = tradeToSell {
                        viewModel.sell(
                            tradeId: trade.id,
                            currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                            reason: "Portfolio User manual sell"
                        )
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
        }
    }

    // MARK: - Trade List

    @ViewBuilder
    private var tradeList: some View {
        LazyVStack(spacing: 16) {
            if selectedMarket == .global {
                globalList
            } else {
                bistList
            }
        }
    }

    @ViewBuilder
    private var globalList: some View {
        if selectedEngine == .all {
            let openTrades = viewModel.globalPortfolio.filter { $0.isOpen }
            if !openTrades.isEmpty {
                ForEach(openTrades) { trade in
                    positionCard(for: trade, market: .global)
                }
            } else {
                EmptyPortfolioState()
            }
        } else if selectedEngine == .scouting {
            if !viewModel.globalScoutLogs.isEmpty {
                ForEach(viewModel.globalScoutLogs.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { log in
                    ScoutHistoryRow(log: log)
                }
            } else {
                ArgusEmptyState(
                    icon: "binoculars.fill",
                    title: "Gözcü Taraması Bekleniyor",
                    message: "Canlı tarama sonuçları burada listelenecek."
                )
                .padding(.top, 24)
            }
        } else {
            let targetEngine: AutoPilotEngine? = (selectedEngine == .corse) ? .corse : .pulse
            let filtered = viewModel.globalPortfolio.filter { $0.isOpen && $0.engine == targetEngine }
            if !filtered.isEmpty {
                ForEach(filtered) { trade in
                    positionCard(for: trade, market: .global)
                }
            } else {
                ArgusEmptyState(
                    icon: "gauge.medium",
                    title: "\(selectedEngine.rawValue)",
                    message: "Bu motorda şu an açık işlem yok."
                )
                .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var bistList: some View {
        if !viewModel.bistOpenPortfolio.isEmpty {
            ForEach(viewModel.bistOpenPortfolio) { trade in
                positionCard(for: trade, market: .bist)
            }
        } else {
            ArgusEmptyState(
                icon: "case.fill",
                title: "BIST portföyün boş",
                message: "Piyasa ekranından BIST hissesi alabilirsin."
            )
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func positionCard(for trade: Trade, market: TradeMarket) -> some View {
        let symbolAlerts = viewModel.planAlerts.filter { $0.symbol == trade.symbol }
        UnifiedPositionCard(
            trade: trade,
            currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
            market: market,
            onEdit: { openPlanEditor(for: trade) },
            onSell: {
                tradeToSell = trade
                showSellConfirmation = true
            },
            alerts: symbolAlerts,
            onAlertDismiss: { alert in
                ExecutionStateViewModel.shared.planAlerts.removeAll { $0.id == alert.id }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { selectedTrade = trade }
    }

    // MARK: - Trade Brain band (2026-04-30 H-46)
    //
    // Eski TradeBrainStatusBand + DailyAgendaView + PortfolioPlanBoard (3
    // dev component) yerine tek satır kompakt status band. Aktif uyarı
    // sayısı + ilk 2 özet + tıklayınca Trade Brain ekranı.

    @ViewBuilder
    private var tradeBrainBand: some View {
        let alerts = viewModel.planAlerts
        Button(action: { showTradeBrain = true }) {
            HStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image("TradeBrainIcon")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .frame(width: 22, height: 22)
                    if hasHighPriorityAlert(alerts) {
                        Circle()
                            .fill(InstitutionalTheme.Colors.crimson)
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle().stroke(InstitutionalTheme.Colors.surface1, lineWidth: 1.5)
                            )
                            .offset(x: 1, y: -1)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Trade Brain")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        if !alerts.isEmpty {
                            Text("\(alerts.count) bildirim")
                                .font(.system(size: 11))
                                .foregroundColor(hasHighPriorityAlert(alerts)
                                                 ? InstitutionalTheme.Colors.crimson
                                                 : InstitutionalTheme.Colors.textSecondary)
                        }
                    }
                    Text(tradeBrainSummary(alerts))
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hasHighPriorityAlert(_ alerts: [TradeBrainAlert]) -> Bool {
        alerts.contains { $0.priority == .high || $0.priority == .critical }
    }

    private func tradeBrainSummary(_ alerts: [TradeBrainAlert]) -> String {
        if alerts.isEmpty {
            return "Aktif uyarı yok · planları gör"
        }
        let symbols = Array(Set(alerts.map { $0.symbol })).prefix(2).joined(separator: " · ")
        let suffix = alerts.count > 2 ? " · …" : ""
        return "\(symbols)\(suffix)"
    }

    // MARK: - Plan Editor

    private func openPlanEditor(for trade: Trade) {
        if PositionPlanStore.shared.getPlan(for: trade.id) == nil {
            PositionPlanStore.shared.syncWithPortfolio(
                trades: [trade],
                grandDecisions: viewModel.grandDecisions
            )
        }
        tradeToEdit = trade
    }

    // MARK: - Drawer

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home); showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit); showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAlkindusDashboard"), object: nil)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings); showDrawer = false
                    }
                ]
            )
        )

        var portfolioItems: [ArgusDrawerView.DrawerItem] = [
            ArgusDrawerView.DrawerItem(title: "Yeni Islem", subtitle: "Pozisyon ac", icon: "plus.circle") {
                showNewTradeSheet = true; showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Islem Gecmisi", subtitle: "Kapanan islemler", icon: "clock.arrow.circlepath") {
                showHistory = true; showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Trade Brain", subtitle: "Yönetim paneli", icon: "TradeBrainIcon") {
                showTradeBrain = true; showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Global Portfoy", subtitle: "Pazar degistir", icon: "globe") {
                selectedMarket = .global; showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "BIST Portfoy", subtitle: "Pazar degistir", icon: "chart.bar") {
                selectedMarket = .bist; showDrawer = false
            }
        ]

        if selectedMarket == .global {
            portfolioItems.append(contentsOf: [
                ArgusDrawerView.DrawerItem(title: "Motor: Genel", subtitle: "Tum islemler", icon: "circle.grid.2x2") {
                    selectedEngine = .all; showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Corse", subtitle: "Swing", icon: "chart.line.uptrend.xyaxis") {
                    selectedEngine = .corse; showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Pulse", subtitle: "Scalp", icon: "bolt") {
                    selectedEngine = .pulse; showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Motor: Gozcu", subtitle: "Canli tarama", icon: "binoculars") {
                    selectedEngine = .scouting; showDrawer = false
                }
            ])
        }

        sections.append(ArgusDrawerView.DrawerSection(title: "Portföy", items: portfolioItems))
        sections.append(commonToolsSection(openSheet: openSheet))
        return sections
    }

    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "Araçlar",
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
        case .corse:  selectedEntityForInfo = .corse
        case .pulse:  selectedEntityForInfo = .pulse
        case .shield: selectedEntityForInfo = .shield
        case .hermes: selectedEntityForInfo = .hermes
        case .manual: selectedEntityForInfo = .corse
        }
        withAnimation { showModelInfo = true }
    }
}

// MARK: - TransactionConsoleCard

struct TransactionConsoleCard: View {
    let txn: Transaction

    var isProfitable: Bool {
        guard let pnl = txn.pnl else { return false }
        return pnl >= 0
    }

    var statusColor: Color {
        if txn.type == .buy { return InstitutionalTheme.Colors.primary }
        return isProfitable ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }

    var body: some View {
        ArgusCard(style: .flat, padding: 12, cornerRadius: InstitutionalTheme.Radius.sm) {
            VStack(spacing: 10) {
                HStack {
                    Text(txn.symbol)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Spacer()

                    Text(txn.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(txn.type == .buy ? "[GİRİŞ]" : "[ÇIKIŞ]")
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)

                            if txn.type == .sell, let pnl = txn.pnl {
                                Text(pnl >= 0 ? "KAR" : "ZARAR")
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(statusColor.opacity(0.18))
                                    .foregroundColor(statusColor)
                                    .clipShape(Capsule())
                            }
                        }

                        let currencySymbol = txn.symbol.hasSuffix(".IS") ? "₺" : "$"
                        Text("Vol: \(currencySymbol)\(String(format: "%.2f", txn.amount))")
                            .font(.system(.caption, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        let currencySymbol = txn.symbol.hasSuffix(".IS") ? "₺" : "$"
                        Text("@ \(currencySymbol)\(String(format: "%.2f", txn.price))")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                        if txn.type == .sell {
                            if let pnl = txn.pnl, let pct = txn.pnlPercent {
                                HStack(spacing: 4) {
                                    Text("\(pnl >= 0 ? "+" : "")\(currencySymbol)\(String(format: "%.2f", pnl))")
                                        .monospacedDigit()
                                    Text("(\(String(format: "%.1f", pct))%)")
                                        .opacity(0.85)
                                        .monospacedDigit()
                                }
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                            } else {
                                Text("—")
                                    .font(.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            }
                        } else {
                            Image(systemName: "arrow.down.to.line")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.primary.opacity(0.85))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - EngineSelector

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
                        Image(systemName: engineIcon(filter))
                            .font(.system(.caption, design: .default))
                            .fontWeight(selected == filter ? .bold : .regular)
                            .foregroundColor(
                                selected == filter
                                    ? engineColor(filter)
                                    : InstitutionalTheme.Colors.textSecondary
                            )
                        Text(engineLabel(filter))
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(0.8)
                            .foregroundColor(
                                selected == filter
                                    ? engineColor(filter)
                                    : InstitutionalTheme.Colors.textSecondary.opacity(0.7)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 36)
                    .background(
                        Group {
                            if selected == filter {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(engineColor(filter).opacity(0.18))
                                    .matchedGeometryEffect(id: "selector", in: animationNamespace)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(engineLabel(filter))
                .accessibilityAddTraits(selected == filter ? .isSelected : [])
            }
        }
        .padding(4)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }

    func engineIcon(_ filter: PortfolioView.AutoPilotEngineFilter) -> String {
        switch filter {
        case .all:      return "square.grid.2x2.fill"
        case .corse:    return "clock.arrow.2.circlepath"
        case .pulse:    return "waveform.path.ecg"
        case .scouting: return "eye.circle.fill"
        }
    }

    func engineLabel(_ filter: PortfolioView.AutoPilotEngineFilter) -> String {
        switch filter {
        case .all:      return "GENEL"
        case .corse:    return "CORSE"
        case .pulse:    return "PULSE"
        case .scouting: return "GÖZCÜ"
        }
    }

    func engineColor(_ filter: PortfolioView.AutoPilotEngineFilter) -> Color {
        switch filter {
        case .all:      return InstitutionalTheme.Colors.primary
        case .corse:    return InstitutionalTheme.Colors.primary
        case .pulse:    return InstitutionalTheme.Colors.positive
        case .scouting: return InstitutionalTheme.Colors.neutral
        }
    }
}

// MARK: - ScoutCandidateCard

struct ScoutCandidateCard: View {
    let signal: TradeSignal
    @ObservedObject var viewModel: TradingViewModel

    private let scoutTint = InstitutionalTheme.Colors.neutral

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(scoutTint)
                .frame(width: 4)
                .clipShape(Capsule())

            CompanyLogoView(symbol: signal.symbol, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(signal.symbol)
                        .font(.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Text("GÖZCÜ ONAYI")
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scoutTint.opacity(0.18))
                        .foregroundColor(scoutTint)
                        .clipShape(Capsule())
                }

                Text(signal.reason)
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                viewModel.buy(symbol: signal.symbol, quantity: 10)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(InstitutionalTheme.Colors.positive)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manuel alım")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - PortfolioHeader (legacy — HolographicBalanceCard sarmalayıcısı)

struct PortfolioHeader: View {
    @ObservedObject var viewModel: TradingViewModel

    var body: some View {
        HolographicBalanceCard(viewModel: viewModel)
            .padding(.horizontal)
            .padding(.top, 10)
    }
}

// MARK: - BistPortfolioHeader (kırmızı tema)

struct BistPortfolioHeader: View {
    @ObservedObject var viewModel: TradingViewModel

    private var totalValue: Double { viewModel.getBistPortfolioValue() }
    private var totalPL:    Double { viewModel.getBistUnrealizedPnL() }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BIST PORTFÖY DEĞERİ")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.7))
                        Text("₺\(String(format: "%.0f", totalValue))")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("KAR/ZARAR")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(totalPL >= 0 ? "+" : "")₺\(totalPL, specifier: "%.2f")")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(
                                totalPL >= 0
                                    ? InstitutionalTheme.Colors.positive
                                    : InstitutionalTheme.Colors.negative
                            )
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KULLANILABİLİR BAKİYE")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.55))
                        Text("₺\(viewModel.bistBalance, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Text("\(viewModel.bistPortfolio.filter { $0.isOpen }.count) açık pozisyon")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))
                    // V5 emojisiz — BIST rozeti küçük kapsülle
                    Text("BIST")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        InstitutionalTheme.Colors.negative.opacity(0.85),
                        InstitutionalTheme.Colors.negative.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - PortfolioCard (AssetChipView sarmalayıcısı)

struct PortfolioCard: View {
    let trade: Trade
    @Binding var selectedTrade: Trade?
    @ObservedObject var viewModel: TradingViewModel

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

// MARK: - EmptyPortfolioState

struct EmptyPortfolioState: View {
    var body: some View {
        VStack(spacing: 20) {
            ArgusEmptyState(
                icon: "shippingbox",
                title: "Portföyün boş",
                message: "Yeni pozisyon açmak için sağ alttaki + butonuna dokunabilirsin."
            )
            EmptyPortfolioQuote()
                .padding(.top, 4)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - NewTradeSheet

struct NewTradeSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var symbol: String = ""
    @State private var quantity: Double = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Symbol Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HİSSE SEMBOLÜ")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            TextField("Örn: AAPL", text: $symbol)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .onChange(of: symbol) { _, newValue in
                                    viewModel.search(query: newValue)
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .fill(InstitutionalTheme.Colors.surface1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )

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
                                                    .font(.system(.callout, design: .monospaced))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                                Spacer()
                                                Text(result.description)
                                                    .font(.caption)
                                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(12)
                                            .frame(minHeight: 44)
                                            .background(InstitutionalTheme.Colors.surface1)
                                        }
                                        Rectangle()
                                            .fill(InstitutionalTheme.Colors.borderSubtle)
                                            .frame(height: 0.5)
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
                        }
                    }

                    // Quantity Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADET")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)

                        HStack {
                            Button(action: { if quantity > 1.0 { quantity -= 1.0 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Adet azalt")

                            Spacer()
                            Text(String(format: "%.2f", quantity))
                                .font(.title)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()

                            Button(action: { quantity += 1.0 }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(InstitutionalTheme.Colors.primary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Adet artır")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .fill(InstitutionalTheme.Colors.surface1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                    }

                    // Summary
                    if let quote = viewModel.quotes[symbol.uppercased()] {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Birim Fiyat")
                                    .font(.callout)
                                Spacer()
                                let currencySymbol = symbol.uppercased().hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", quote.currentPrice))")
                                    .font(.system(.callout, design: .monospaced))
                                    .monospacedDigit()
                            }
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)

                            HStack {
                                Text("Toplam")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Spacer()
                                let currencySymbol = symbol.uppercased().hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", quote.currentPrice * quantity))")
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .foregroundColor(InstitutionalTheme.Colors.primary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .fill(InstitutionalTheme.Colors.surface1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                    }

                    Spacer()

                    // Action Button
                    Button(action: executeTrade) {
                        Text("SATIN AL")
                            .font(.headline)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .frame(minHeight: 48)
                            .background(
                                symbol.isEmpty
                                    ? InstitutionalTheme.Colors.neutral
                                    : InstitutionalTheme.Colors.positive
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(symbol.isEmpty)
                    .accessibilityLabel("Satın al")
                }
                .padding(16)
            }
            .navigationTitle("Yeni İşlem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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

// MARK: - ScoutHistoryRow

struct ScoutHistoryRow: View {
    let log: ScoutLog

    var statusColor: Color {
        switch log.status {
        case "ONAYLI": return InstitutionalTheme.Colors.positive
        case "RED":    return InstitutionalTheme.Colors.negative
        case "BEKLE":  return InstitutionalTheme.Colors.neutral
        case "SATIŞ":  return InstitutionalTheme.Colors.primary
        case "TUT":    return InstitutionalTheme.Colors.textSecondary
        default:       return InstitutionalTheme.Colors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .clipShape(Capsule())

            Text(log.symbol)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(log.status)
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(0.8)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.14))
                        .clipShape(Capsule())

                    Spacer()

                    Text("Puan: \(Int(log.score))")
                        .font(.system(.caption2, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Text(log.reason)
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
