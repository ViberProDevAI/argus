import SwiftUI

struct AppTabBar: View {
    @ObservedObject var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        HStack {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Spacer()

                Button(action: {
                    withAnimation(.spring()) {
                        deepLinkManager.navigate(to: tab)
                        // Also clear navigation stack when switching tabs
                        router.popToRoot()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))

                        Text(tab.rawValue)
                            .font(DesignTokens.Fonts.caption)
                    }
                    .foregroundColor(deepLinkManager.selectedTab == tab ? DesignTokens.Colors.primary : DesignTokens.Colors.textSecondary)
                    .scaleEffect(deepLinkManager.selectedTab == tab ? 1.1 : 1.0)
                }

                Spacer()
            }
        }
        .padding(.vertical, 10)
        .padding(.bottom, 20) // Home indicator için
        .background(
            GeometryReader { geo in
                Color.clear
                    .frame(height: geo.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        )
        .background(DesignTokens.Colors.secondaryBackground.opacity(0.9))
        .cornerRadius(DesignTokens.Radius.large, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}



#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            AppTabBar()
        }
    }
}
