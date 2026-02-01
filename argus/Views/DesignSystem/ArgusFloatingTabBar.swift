import SwiftUI

struct ArgusFloatingTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showVoiceSheet: Bool
    
    // Tab Yapılandırması
    private let tabs = [
        "chart.bar.xaxis",   // 0: Piyasa (Market)
        "AlkindusIcon", // 1: Alkindus (Meta-Zeka)

        "terminal.fill",     // 2: Kokpit (Terminal)
        "mic.fill",          // 3: Sesli Asistan (Action)
        "briefcase.fill",    // 4: Portföy
        "gearshape.fill"     // 5: Ayarlar
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Spacer()
                
                Button(action: {
                    if index == 3 {
                        showVoiceSheet = true
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        // İkon - Custom asset veya SF Symbol
                        tabIcon(for: index)
                            .foregroundColor(
                                index == 3 ? Theme.primary : (selectedTab == index ? Theme.accent : .gray.opacity(0.6))
                            )
                            .scaleEffect(index == 3 ? 1.2 : (selectedTab == index ? 1.1 : 1.0))
                        
                        // Aktiflik Noktası
                        if selectedTab == index && index != 3 {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 4, height: 4)
                        } else {
                            Circle().fill(.clear).frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 50)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            // Daha sade ve minimal bir arka plan
            GlassCard(cornerRadius: 32) {
                Color.black.opacity(0.4) // Daha koyu, daha az transparan
            }
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Icon Helper
    @ViewBuilder
    private func tabIcon(for index: Int) -> some View {
        let iconName = tabs[index]
        let size: CGFloat = index == 3 ? 24 : 20

        if iconName.hasSuffix("Icon") {
            // Custom asset icon (AlkindusIcon, etc.)
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // SF Symbol
            Image(systemName: iconName)
                .font(.system(size: size, weight: selectedTab == index ? .semibold : .regular))
        }
    }
}
