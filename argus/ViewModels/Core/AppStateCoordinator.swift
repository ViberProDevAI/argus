import Foundation
import Combine
import SwiftUI

/// FAZ 2: AppStateCoordinator
/// Tüm alt ViewModel'leri koordine eden merkezi orchestrator.
/// TradingViewModel'den ayrılmış modüler yapı için köprü görevi görür.
@MainActor
final class AppStateCoordinator: ObservableObject {
    
    // MARK: - Singleton (Geçiş döneminde backward compatibility için)
    static let shared = AppStateCoordinator()
    
    // MARK: - Sub ViewModels
    let watchlist: WatchlistViewModel
    
    // MARK: - Legacy Accessor for Views (Backward Compatibility)
    // Views that access `coordinator.portfolio` will now get the Store directly.
    var portfolio: PortfolioStore {
        PortfolioStore.shared
    }
    
    // MARK: - Shared State (Alt ViewModel'ler arası paylaşım)
    @Published var selectedSymbol: String?
    @Published var isGlobalLoading: Bool = false
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    private init() {
        // Alt ViewModel'leri oluştur
        self.watchlist = WatchlistViewModel()
        
        // Koordinasyon: Watchlist ve MarketData değişikliklerini dinle
        setupCoordination()
    }
    
    private func setupCoordination() {
        // Watchlist'e eklenen sembol için quote yükle
        watchlist.$watchlist
            .dropFirst() // İlk yayını atla
            .sink { [weak self] symbols in
                Task { @MainActor in
                    // Yeni semboller için veri çek
                    for symbol in symbols {
                        if self?.watchlist.quotes[symbol] == nil {
                            await self?.watchlist.loadQuote(for: symbol)
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Portfolio'daki açık pozisyonlar için quote güncellemelerini dinle
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                // PortfolioStore'a quote güncellemelerini ilet (SL/TP kontrolü için)
                self?.portfolio.handleQuoteUpdates(storeQuotes)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Convenience Methods
    
    /// Sembol detay görünümüne geçiş
    func selectSymbol(_ symbol: String) {
        selectedSymbol = symbol
    }
    
    /// Global yükleme durumu
    // PortfolioStore doesn't expose isLoading, so we remove it from the OR chain or assume false
    var isLoading: Bool {
        watchlist.isLoading || isGlobalLoading
    }
}
