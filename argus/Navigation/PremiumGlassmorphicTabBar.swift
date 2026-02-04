import SwiftUI

struct PremiumGlassmorphicTabBar: View {
    @ObservedObject var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    // Tabs excluding any FAB (all 4 visible tabs)
    private var allTabs: [TabItem] {
        TabItem.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(Color.white.opacity(0.1))

            // Glassmorphic bar with tabs
            ZStack {
                // Glassmorphic background
                VisualEffectView(effect: UIBlurEffect(style: .dark))
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left two tabs
                    ForEach(Array(allTabs.prefix(2)), id: \.self) { tab in
                        PremiumTabBarButton(
                            tab: tab,
                            isSelected: deepLinkManager.selectedTab == tab,
                            action: {
                                selectTab(tab)
                            }
                        )
                    }

                    // Center spacer for potential FAB (keeping 80pt space for future)
                    Spacer()
                        .frame(width: 80)

                    // Right two tabs
                    ForEach(Array(allTabs.suffix(2)), id: \.self) { tab in
                        PremiumTabBarButton(
                            tab: tab,
                            isSelected: deepLinkManager.selectedTab == tab,
                            action: {
                                selectTab(tab)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)

                // Optional: Centered FAB Argus Voice (comment out if not using)
                VStack {
                    HStack {
                        Spacer()
                        PulsingFABView {
                            // Voice button action - navigate to Kokpit for now
                            selectTab(.kokpit)
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                        }
                        Spacer()
                    }
                    .offset(y: -30)

                    Spacer()
                }
            }
            .frame(height: 80)
            .padding(.bottom, max(UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0, 16))
        }
    }

    private func selectTab(_ tab: TabItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            deepLinkManager.navigate(to: tab)
            router.popToRoot()
        }
    }
}

// MARK: - TabBarButton Component

struct PremiumTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))

                Text(tab.rawValue)
                    .font(DesignTokens.Fonts.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? DesignTokens.Colors.primary : DesignTokens.Colors.textSecondary)
            .opacity(isSelected ? 1.0 : 0.6)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            PremiumGlassmorphicTabBar()
                .environmentObject(NavigationRouter.shared)
        }
    }
}
