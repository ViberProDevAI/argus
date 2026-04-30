import SwiftUI

/// Alt tab bar + merkez Argus Voice butonu.
///
/// 2026-04-25 H-41 — sade refactor:
///   • Pill: glass blur + gradient + drop shadow → sade `surface1`
///     fill, 0.5px borderSubtle stroke, radius 24.
///   • Tab item: ALL CAPS mono tracking → sentence case (TabItem.rawValue
///     zaten "Ana Sayfa" / "Kokpit" / "Portföy" / "Ayarlar" — uppercase
///     dönüştürmesi kaldırıldı).
///   • Merkez FAB: `PulsingFABView` (pulse + holo glow) → sade dairesel
///     `ArgusAppIcon` PNG butonu. Pulse ve glow yok; tap davranışı
///     (NotificationCenter "OpenArgusVoice" post) aynen.
///
/// `PulsingFABView` kodu projede kalmaya devam ediyor; başka bir yerden
/// referanslanma ihtimaline karşı silinmedi.
struct PremiumGlassmorphicTabBar: View {
    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    private var allTabs: [TabItem] {
        TabItem.allCases
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Tab bar pill — sade
            HStack(spacing: 0) {
                ForEach(Array(allTabs.prefix(2)), id: \.self) { tab in
                    PremiumTabBarButton(
                        tab: tab,
                        isSelected: deepLinkManager.selectedTab == tab,
                        action: { selectTab(tab) }
                    )
                }

                // Merkez FAB için boşluk
                Spacer().frame(width: 64)

                ForEach(Array(allTabs.suffix(2)), id: \.self) { tab in
                    PremiumTabBarButton(
                        tab: tab,
                        isSelected: deepLinkManager.selectedTab == tab,
                        action: { selectTab(tab) }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Merkez FAB — sade dairesel ArgusAppIcon, pulse/glow yok
            argusVoiceButton
                .offset(y: -16)
        }
    }

    private var argusVoiceButton: some View {
        Button(action: {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            NotificationCenter.default.post(name: NSNotification.Name("OpenArgusVoice"), object: nil)
        }) {
            Image("ArgusAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(InstitutionalTheme.Colors.holo.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Argus sesli komut")
    }

    private func selectTab(_ tab: TabItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            deepLinkManager.navigate(to: tab)
            router.popToRoot()
        }
    }
}

// MARK: - TabBarButton
//
// 2026-04-25 H-41: Sentence case label, mono caps tracking gitti.
// Seçili: holo (mavi), seçili olmayan: textSecondary. Scale animasyonu
// yok — opacity hover/selected geçişi için 0.6 → 1.0.

struct PremiumTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected
                             ? InstitutionalTheme.Colors.holo
                             : InstitutionalTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
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
