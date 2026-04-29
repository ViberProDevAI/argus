import SwiftUI

extension NavigationRouter {
    @ViewBuilder
    func destinationView(for route: NavigationRoute, viewModel: TradingViewModel) -> some View {
        switch route {
        // MARK: - Main Tabs
        case .home:
            AlkindusDashboardView()

        case .kokpit:
            ArgusCockpitView()

        case .portfolio:
            PortfolioView(viewModel: viewModel)

        case .settings:
            SettingsView(settingsViewModel: SettingsViewModel())

        // MARK: - Market Views
        case .stockDetail(let symbol):
            ArgusSanctumView(symbol: symbol, viewModel: viewModel)

        case .etfDetail(let symbol):
            ArgusEtfDetailView(symbol: symbol, viewModel: viewModel)

        case .bistMarket:
            BistMarketView()

        case .bistPortfolio:
            BistPortfolioView()

        case .tahta(let symbol):
            TahtaView(symbol: symbol)

        case .kasa(let symbol):
            BISTBilancoDetailView(sembol: symbol)

        case .kulis(let symbol):
            // Hermes view for news/sentiment
            HermesFeedView(viewModel: viewModel)

        case .rejim(let symbol):
            RejimView(symbol: symbol)

        // MARK: - Market Tools
        case .sectorDetail(let sector):
            SectorDetailRouterView(sectorName: sector)

        case .atlasDetail(let symbol):
            AtlasV2DetailView(symbol: symbol)

        case .poseidon:
            PoseidonRouterView()

        case .phoenix:
            // 2026-04-22: V5 redesign — legacy PhoenixView kaldırıldı,
            // Sanctum/Drawer'dan gelen `.phoenix` V5 görünümüne çıkıyor.
            PhoenixV5View()

        case .phoenixDetail(let id):
            PhoenixDetailRouterView(symbol: id)

        case .chiron:
            // 2026-04-22: V5 redesign — ChironInsightsView (V5 body) tercih edildi.
            // Eski ChironDetailView (NavigationView + SF brain ikonu) geride kaldı.
            NavigationStack {
                ChironInsightsView()
            }

        case .chironDetail(let id):
            NavigationStack {
                ChironInsightsView(symbol: id)
            }

        case .chironPerformance:
            ChironPerformanceView()

        // MARK: - Analysis Views
        case .marketReport:
            MarketReportRouterView()

        case .analystReport(let symbol):
            ArgusAnalystReportView(symbol: symbol, viewModel: viewModel)

        case .reports:
            PortfolioReportsView(viewModel: viewModel)

        case .debateSimulator:
            DebateSimulatorRouterView()

        // MARK: - Discovery & Signals
        case .discover:
            DiscoverView(viewModel: viewModel)

        case .notifications:
            NotificationsView(viewModel: viewModel)

        case .tradeBrain:
            TradeBrainView()
                .environmentObject(viewModel)

        case .signals:
            SignalsView(viewModel: viewModel)

        case .hermesFeed:
            HermesFeedView(viewModel: viewModel)

        case .journalSignals:
            SignalJournalView()

        // MARK: - Observatory
        case .observatory:
            ObservatoryContainerView()

        case .observatoryContainer:
            ObservatoryContainerView()

        case .observatoryHealth:
            ObservatoryHealthView()

        case .tradeHistory:
            TradeHistoryView()

        // MARK: - Admin/Debug
        case .debugPersistence:
            DebugPersistenceView()

        // MARK: - Settings Sub-views
        case .settingsSignals:
            SettingsView(settingsViewModel: SettingsViewModel())

        case .priceAlerts:
            PriceAlertSettingsView()

        case .guide:
            ArgusGuideView()

        case .voice:
            ArgusVoiceView()

        case .widgetSettings:
            SettingsView(settingsViewModel: SettingsViewModel())

        case .serviceHealth:
            ServiceHealthView()

        // MARK: - Portfolio Management
        case .portfolioReports:
            PortfolioReportsView(viewModel: viewModel)

        case .chronosDetail(let id):
            ChronosDetailView(symbol: id)

        // MARK: - Watchlist & Aether
        case .aetherDetail(let id):
            AetherDetailRouterView(id: id)

        case .aetherDashboard:
            AetherDetailRouterView(id: "GLOBAL")

        // MARK: - Voice & Assistant
        case .voiceAssistant:
            VoiceAssistantView()

        // MARK: - Council & Debate
        case .symbolDebate(let symbol):
            SymbolDebateRouterView(symbol: symbol, viewModel: viewModel)

        // MARK: - Legacy/Specialty Views
        case .splash:
            SplashScreenView(onFinished: {})

        case .intro:
            ArgusIntroView(onFinished: {})

        case .disclaimer:
            DisclaimerView()

        case .argusSanctum(let symbol):
            ArgusSanctumView(symbol: symbol, viewModel: viewModel)

        case .expectationsEntry:
            ExpectationsEntryView()

        case .roadmap:
            RoadmapView()

        case .immersiveChart(let symbol):
            ArgusImmersiveChartView(viewModel: viewModel, symbol: symbol)

        // MARK: - Components/Detail Sheets
        case .intelligenceCards(let symbol):
            IntelligenceCardsRouterView(symbol: symbol)

        case .fundList:
            FundListView()

        case .expectationsList:
            ExpectationsEntryView() // List alternative

        // MARK: - Heimdall/Admin Views
        case .heimdallDashboard:
            HeimdallDashboardView()

        case .heimdallKeys:
            HeimdallKeysView()

        case .mimir:
            MimirView()

        // MARK: - Sirkiye Views
        case .sirkiyeDashboard:
            SirkiyeDashboardView(viewModel: viewModel)

        case .sirkiyeAether:
            SirkiyeAetherView()

        // MARK: - Radar/Cockpit
        case .cockpit:
            ArgusCockpitView()
        }
    }
}
