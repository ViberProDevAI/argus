import SwiftUI

/// Alt tab bar + merkez Argus Voice FAB.
///
/// 2026-04-22 Sprint 2: V5 mockup (`Argus_Mockup_V5.html` .tabbar) hizalaması.
/// - Pill corner radius `32` (V5 `.tabbar { border-radius: 32px }`)
/// - Yoğun V5 renk tonları (surface2→surface1 opak) + borderStrong stroke
/// - Tab etiketleri mono + upper-case + holo accent seçili
/// - Merkez FAB ArgusEye (PulsingFABView V5 versiyonu)
///
/// Davranış değişmedi: 4 tab + merkez FAB → `OpenArgusVoice` notification.
struct PremiumGlassmorphicTabBar: View {
    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    private var allTabs: [TabItem] {
        TabItem.allCases
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Tab bar container — V5 .tabbar
            ZStack {
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.tabbar, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                InstitutionalTheme.Colors.surface2.opacity(0.96),
                                InstitutionalTheme.Colors.surface1.opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.tabbar, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                    )
                    .background(
                        // backdrop blur effect
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.tabbar, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)

                // Tab row — 2 sol, center spacer, 2 sağ (V5 layout)
                HStack(spacing: 0) {
                    ForEach(Array(allTabs.prefix(2)), id: \.self) { tab in
                        PremiumTabBarButton(
                            tab: tab,
                            isSelected: deepLinkManager.selectedTab == tab,
                            action: { selectTab(tab) }
                        )
                    }

                    // Merkez FAB için 76pt boşluk (FAB 64 + 6 pad her yan)
                    Spacer().frame(width: 76)

                    ForEach(Array(allTabs.suffix(2)), id: \.self) { tab in
                        PremiumTabBarButton(
                            tab: tab,
                            isSelected: deepLinkManager.selectedTab == tab,
                            action: { selectTab(tab) }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 74)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Merkez FAB — V5 margin-top -22 ile yarı çıkıntılı
            PulsingFABView {
                let haptic = UIImpactFeedbackGenerator(style: .medium)
                haptic.impactOccurred()
                NotificationCenter.default.post(name: NSNotification.Name("OpenArgusVoice"), object: nil)
            }
            .offset(y: -22)
        }
    }

    private func selectTab(_ tab: TabItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            deepLinkManager.navigate(to: tab)
            router.popToRoot()
        }
    }
}

// MARK: - TabBarButton

/// V5 .tabitem: dikey ikon + upper mono etiket, seçili holo accent.
struct PremiumTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))

                Text(tab.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected
                             ? InstitutionalTheme.Colors.holo
                             : InstitutionalTheme.Colors.textSecondary)
            .opacity(isSelected ? 1.0 : 0.72)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.backgroundDeep.ignoresSafeArea()
        VStack {
            Spacer()
            PremiumGlassmorphicTabBar()
                .environmentObject(NavigationRouter.shared)
        }
    }
}
