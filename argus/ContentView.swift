import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var router = NavigationRouter.shared
    @StateObject private var settingsViewModel = SettingsViewModel()

    // Voice Sheet State
    @State private var showVoiceSheet = false

    var body: some View {
        ZStack {
            // Global Living Background (Design System Base)
            DesignTokens.Colors.background
                .ignoresSafeArea()

            // Background Animation Layer
            ArgusGlobalBackground()
                .opacity(0.3)
                .zIndex(0)


                ZStack(alignment: .topLeading) {
                    // Main Content Area with Navigation Stack
                    NavigationStack(path: $router.navigationStack) {
                        Group {
                            switch deepLinkManager.selectedTab {
                            case .home:
                                MarketView()
                                    .environmentObject(viewModel)
                            case .alkindus:
                                AlkindusDashboardView()
                            case .markets: // Using Cockpit as Markets/Terminal view
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Hamburger Button REMOVED (Moved to individual views)

                    Spacer()

                    // Custom Tab Bar (Bottom)
                    VStack {
                        Spacer()

                        AppTabBar()
                            .environmentObject(router)
                            .zIndex(1)
                    }
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
            VoiceAssistantView()
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
            deepLinkManager.navigate(to: .alkindus)
        }
        .environmentObject(router)
    }
}

#Preview {
    ContentView()
}
