import SwiftUI
import Combine

enum NavigationRoute: Hashable, Identifiable {
    var id: Self { self }
    // MARK: - Main Tabs
    case home
    case kokpit
    case portfolio
    case settings

    // MARK: - Market Views
    case stockDetail(symbol: String)
    case etfDetail(symbol: String)
    case bistMarket
    case bistPortfolio
    case tahta(symbol: String)
    case kasa(symbol: String)
    case kulis(symbol: String)
    case rejim(symbol: String)

    // MARK: - Market Tools
    case sectorDetail(sector: String)
    case atlasDashboard
    case atlasDetail(symbol: String)
    case poseidon
    case phoenix
    case phoenixDetail(id: String)
    case chiron
    case chironDetail(id: String)
    case chironPerformance

    // MARK: - Analysis Views
    case backtest
    case backtestResults(id: String)
    case marketReport
    case analystReport(symbol: String)
    case reports
    case debateSimulator

    // MARK: - Discovery & Signals
    case discover
    case notifications
    case tradeBrain
    case signals
    case hermesFeed
    case journalSignals

    // MARK: - Labs (Previously Orphaned)
    case argusLab
    case chronosLab
    case orionLab
    case athenaLab
    case atlasLab
    case strategyLab
    case observatory
    case observatoryContainer
    case observatoryHealth
    case observatoryLearning
    case observatoryTimeline
    case tradeHistory

    // MARK: - Admin/Debug
    case flightRecorder
    case dataHealth
    case algorithmTest
    case debugPersistence

    // MARK: - Settings Sub-views
    case settingsSignals
    case priceAlerts
    case guide
    case simulator
    case voice
    case widgetSettings
    case serviceHealth

    // MARK: - Portfolio Management
    case portfolioReports
    case chronosDetail(id: String)

    // MARK: - Watchlist & Aether
    case aetherDetail(id: String)
    case aetherDashboard

    // MARK: - Voice & Assistant
    case voiceAssistant

    // MARK: - Council & Debate
    case symbolDebate(symbol: String)

    // MARK: - Legacy/Specialty Views
    case splash
    case intro
    case disclaimer
    case argusSanctum(symbol: String)
    case expectationsEntry
    case estrategyCenter
    case proDashboard
    case roadmap
    case oracleChamber
    case immersiveChart(symbol: String)

    // MARK: - Components/Detail Sheets
    case intelligenceCards(symbol: String)
    case fundDetail(id: String)
    case fundList
    case expectationsList

    // MARK: - Heimdall/Admin Views
    case heimdallDashboard
    case heimdallKeys
    case mimir

    // MARK: - Sirkiye Views
    case sirkiyeDashboard
    case sirkiyeAether

    // MARK: - Radar/Cockpit
    case cockpit

    // MARK: - Utility
    case unifiedError(error: String)
    case unifiedLoading
}

@MainActor
class NavigationRouter: ObservableObject {
    @Published var navigationStack: [NavigationRoute] = []
    @Published var presentedSheet: NavigationRoute?
    @Published var presentedFullScreen: NavigationRoute?

    static let shared = NavigationRouter()

    private init() {}

    func navigate(to route: NavigationRoute) {
        navigationStack.append(route)
    }

    func pop() {
        if !navigationStack.isEmpty {
            navigationStack.removeLast()
        }
    }

    func popToRoot() {
        navigationStack.removeAll()
    }

    func presentSheet(_ route: NavigationRoute) {
        presentedSheet = route
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func presentFullScreen(_ route: NavigationRoute) {
        presentedFullScreen = route
    }

    func dismissFullScreen() {
        presentedFullScreen = nil
    }

    func replace(with route: NavigationRoute) {
        navigationStack.removeLast()
        navigationStack.append(route)
    }
}
