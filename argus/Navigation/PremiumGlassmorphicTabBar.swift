import SwiftUI

struct PremiumGlassmorphicTabBar: View {
    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    // Tabs excluding any FAB (all 4 visible tabs)
    private var allTabs: [TabItem] {
        TabItem.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(InstitutionalTheme.Colors.borderSubtle)

            // Glassmorphic bar with tabs
            ZStack {
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                InstitutionalTheme.Colors.surface2.opacity(0.95),
                                InstitutionalTheme.Colors.surface1.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.xl, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                    )

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
                .padding(.vertical, 12)

                // Centered FAB - Argus Voice
                VStack {
                    HStack {
                        Spacer()
                        PulsingFABView {
                            // Voice button action - open ArgusVoiceView sheet
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                            NotificationCenter.default.post(name: NSNotification.Name("OpenArgusVoice"), object: nil)
                        }
                        Spacer()
                    }
                    .offset(y: -24)

                    Spacer()
                }
            }
            .frame(height: 74)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
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
                    .font(.system(size: 19, weight: .semibold))

                Text(tab.rawValue)
                    .font(InstitutionalTheme.Typography.micro)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? InstitutionalTheme.Colors.primary : InstitutionalTheme.Colors.textSecondary)
            .opacity(isSelected ? 1.0 : 0.72)
        }
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
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
