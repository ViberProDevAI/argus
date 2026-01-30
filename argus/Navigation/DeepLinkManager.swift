import SwiftUI
import Combine

enum TabItem: String, CaseIterable {
    case home = "Ana Sayfa"
    case markets = "Piyasalar"
    case alkindus = "Alkindus"
    case portfolio = "Portföy"
    case settings = "Ayarlar"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .markets: return "chart.bar.fill"
        case .alkindus: return "brain.head.profile"
        case .portfolio: return "briefcase.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var selectedTab: TabItem = .alkindus // Varsayılan olarak Alkindus
    
    // Sayfa içi navigasyon için kullanılabilir (örn. belirli bir hisseye git)
    @Published var selectedStockSymbol: String?
    
    private init() {}
    
    func navigate(to tab: TabItem) {
        self.selectedTab = tab
    }
    
    func openStockDetail(symbol: String) {
        self.selectedTab = .markets
        self.selectedStockSymbol = symbol
    }
}
