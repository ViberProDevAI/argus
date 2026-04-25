import SwiftUI
import Combine

enum TabItem: String, CaseIterable {
    case home = "Ana Sayfa"
    case kokpit = "Kokpit"
    case portfolio = "Portföy"
    case settings = "Ayarlar"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .kokpit: return "gauge.with.dots.needle.bottom.50percent"  // Terminal gauge
        case .portfolio: return "briefcase.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var selectedTab: TabItem = .home // Default to Home view
    
    // Sayfa içi navigasyon için kullanılabilir (örn. belirli bir hisseye git)
    @Published var selectedStockSymbol: String?
    
    private init() {}
    
    func navigate(to tab: TabItem) {
        self.selectedTab = tab
    }
    
    func openStockDetail(symbol: String) {
        self.selectedTab = .home
        self.selectedStockSymbol = symbol
    }
}
