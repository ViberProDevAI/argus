import SwiftUI

 struct ContentView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var settingsViewModel = SettingsViewModel()

    
    // Voice Sheet State
    @State private var showVoiceSheet = false
    
    // Drawer State
    @State private var showDrawer = false
    
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
                    // Main Content Area
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Hamburger Button (Top Left) - Safe Area Aware
                    VStack {
                        Button {
                            withAnimation {
                                showDrawer = true
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Theme.secondaryBackground)
                                        .overlay(
                                            Circle()
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    Spacer()
                    
                    // Custom Tab Bar (Bottom)
                    VStack {
                        Spacer()
                        
                        if !showDrawer {
                            AppTabBar()
                                .zIndex(1)
                        }
                    }
                }
                
                // Drawer Overlay
                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer, onNavigateToTab: { drawerTab in
                        withAnimation {
                            showDrawer = false
                            switch drawerTab {
                            case .home:
                                deepLinkManager.navigate(to: .home)
                            case .markets:
                                deepLinkManager.navigate(to: .markets)
                            case .alkindus:
                                deepLinkManager.navigate(to: .alkindus)
                            case .portfolio:
                                deepLinkManager.navigate(to: .portfolio)
                            case .settings:
                                deepLinkManager.navigate(to: .settings)
                            }
                        }
                    })
                    .zIndex(100)
                }

        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceAssistantView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArgusNotificationTapped"))) { notification in
            // Handle Deep Links
            if let id = notification.userInfo?["notificationId"] as? String {
                print("🔔 Argus Deep Link: ID found \(id)")
            }
            deepLinkManager.navigate(to: .alkindus)
        }
    }
}

#Preview {
    ContentView()
}
