import SwiftUI

// MİMARİ NOT:
// coordinator (@EnvironmentObject AppStateCoordinator) → yeni kod için TEK GİRİŞ NOKTASI
// viewModel  (@EnvironmentObject TradingViewModel)      → LEGACY, yalnızca geriye dönük uyumluluk
// Yeni view'lar: @EnvironmentObject var coordinator: AppStateCoordinator kullanır
// Eski view'lar: viewModel.X → zamanla coordinator.X'e migrate edilecek
struct ContentView: View {
    @EnvironmentObject var viewModel: TradingViewModel   // LEGACY — migrate to coordinator
    @EnvironmentObject var coordinator: AppStateCoordinator // PRIMARY
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var router = NavigationRouter.shared
    @StateObject private var settingsViewModel = SettingsViewModel()

    // Voice Sheet State
    @State private var showVoiceSheet = false

    var body: some View {
        ZStack {
            // Global Living Background (Design System Base)
            InstitutionalTheme.Colors.background
                .ignoresSafeArea()

            // Background Animation Layer
            ArgusGlobalBackground()
                .opacity(0.16)
                .zIndex(0)


            VStack(spacing: 0) {
                // Main Content Area with Navigation Stack
                NavigationStack(path: $router.navigationStack) {
                    Group {
                        switch deepLinkManager.selectedTab {
                        case .home:
                            MarketView()
                                .environmentObject(viewModel)
                        case .kokpit:
                            ArgusCockpitView()
                        case .portfolio:
                            PortfolioView(viewModel: viewModel)
                        case .settings:
                            SettingsView(settingsViewModel: settingsViewModel)
                        }
                    }
                    .navigationDestination(for: NavigationRoute.self) { route in
                        router.destinationView(for: route, viewModel: viewModel)
                    }
                    .environmentObject(viewModel)
                }
                .id(deepLinkManager.selectedTab)

                // Custom Tab Bar (Bottom)
                AppTabBar()
                    .environmentObject(router)
            }

        }
        .sheet(item: $viewModel.generatedSmartPlan) { plan in
            if let trade = viewModel.portfolio.first(where: { $0.id == plan.tradeId }) {
                PlanEditorSheet(
                    trade: trade,
                    currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                    plan: plan
                )
            } else {
                Text("Hata: Pozisyon bulunamadı")
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showVoiceSheet) {
            ArgusVoiceView()
                .environmentObject(viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenArgusVoice"))) { _ in
            showVoiceSheet = true
        }
        .sheet(item: $router.presentedSheet) { route in
            router.destinationView(for: route, viewModel: viewModel)
                .environmentObject(viewModel)
        }
        .fullScreenCover(item: $router.presentedFullScreen) { route in
            router.destinationView(for: route, viewModel: viewModel)
                .environmentObject(viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArgusNotificationTapped"))) { notification in
            // Handle Deep Links
            if let id = notification.userInfo?["notificationId"] as? String {
                print("🔔 Argus Deep Link: ID found \(id)")
            }
            deepLinkManager.navigate(to: .home)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAlkindusDashboard"))) { _ in
            deepLinkManager.navigate(to: .home)
            router.popToRoot()
        }
        .onAppear {
            applyLaunchTabOverrideIfNeeded()
        }
        .environmentObject(router)
    }

    private func applyLaunchTabOverrideIfNeeded() {
        guard
            let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--argus-tab=") })
        else {
            return
        }

        let tabValue = argument.replacingOccurrences(of: "--argus-tab=", with: "")
        switch tabValue {
        case "home":
            deepLinkManager.navigate(to: .home)
        case "kokpit":
            deepLinkManager.navigate(to: .kokpit)
        case "portfolio":
            deepLinkManager.navigate(to: .portfolio)
        case "settings":
            deepLinkManager.navigate(to: .settings)
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
