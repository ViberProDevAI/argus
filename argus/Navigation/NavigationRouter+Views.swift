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
            StockDetailView(symbol: symbol, viewModel: viewModel)

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

        case .atlasDashboard:
            AtlasLabView()

        case .atlasDetail(let symbol):
            AtlasV2DetailView(symbol: symbol)

        case .poseidon:
            PoseidonRouterView()

        case .phoenix:
            PhoenixView()

        case .phoenixDetail(let id):
            PhoenixDetailRouterView(symbol: id)

        case .chiron:
            ChironDetailView()

        case .chironDetail(let id):
            ChironDetailView()

        case .chironPerformance:
            ChironPerformanceView()

        // MARK: - Analysis Views
        case .backtest:
            BacktestRouterView()

        case .backtestResults(let id):
            BacktestResultsRouterView(resultId: id)

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

        // MARK: - Labs
        case .argusLab:
            ArgusLabView()

        case .chronosLab:
            ChronosLabView(viewModel: ChronosLabViewModel())

        case .orionLab:
            OrionLabView()

        case .athenaLab:
            AthenaLabView()

        case .atlasLab:
            AtlasLabView()

        case .strategyLab:
            StrategyLabView()

        case .observatory:
            ObservatoryContainerView()

        case .observatoryContainer:
            ObservatoryContainerView()

        case .observatoryHealth:
            ObservatoryHealthView()

        case .observatoryLearning:
            ObservatoryLearningView()

        case .observatoryTimeline:
            ObservatoryTimelineView()

        case .tradeHistory:
            TradeHistoryView()

        // MARK: - Admin/Debug
        case .flightRecorder:
            ArgusFlightRecorderView()

        case .dataHealth:
            ArgusDataHealthView()
                .environmentObject(viewModel)

        case .algorithmTest:
            AlgorithmTestView()

        case .debugPersistence:
            DebugPersistenceView()

        // MARK: - Settings Sub-views
        case .settingsSignals:
            SettingsSignalsView()

        case .priceAlerts:
            PriceAlertSettingsView()

        case .guide:
            ArgusGuideView()

        case .simulator:
            ArgusSimulatorView()

        case .voice:
            ArgusVoiceView()

        case .widgetSettings:
            WidgetListSettingsView()

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

        case .estrategyCenter:
            ArgusStrategyCenterView(viewModel: viewModel)

        case .proDashboard:
            ArgusProDashboardView(symbol: "", viewModel: viewModel)

        case .roadmap:
            RoadmapView()

        case .oracleChamber:
            OracleChamberView()

        case .immersiveChart(let symbol):
            ArgusImmersiveChartView(viewModel: viewModel, symbol: symbol)

        // MARK: - Components/Detail Sheets
        case .intelligenceCards(let symbol):
            IntelligenceCardsRouterView(symbol: symbol)

        case .fundDetail(let id):
            FundDetailView(fundCode: id)

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

        // MARK: - Utility
        case .unifiedError(let error):
            UnifiedErrorView(message: error)

        case .unifiedLoading:
            UnifiedLoadingView()
        }
    }
}
