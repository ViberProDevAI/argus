import Foundation
import Combine

@MainActor
class TradingViewModel_FACADE: ObservableObject {
    static let shared = TradingViewModel_FACADE()
    
    // Published Properties (Keep UI Compatibility)
    @Published var watchlist: [String] = []
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    @Published var terminalItems: [TerminalItem] = []
    @Published var quotes: [String: Quote] = [:]
    @Published var candles: [String: [Candle]] = [:]
    @Published var portfolio: [Trade] = []
    @Published var balance: Double = 100000.0
    @Published var bistBalance: Double = 1000000.0
    @Published var usdTryRate: Double = 35.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Dependencies
    private let marketDataVM = MarketDataViewModel.shared
    private let portfolioVM = PortfolioViewModel.shared
    private let watchlistStore = WatchlistStore.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Simple bindings
        marketDataVM.$quotes.sink { [weak self] in self?.quotes = $0 }.store(in: &cancellables)
        marketDataVM.$candles.sink { [weak self] in self?.candles = $0 }.store(in: &cancellables)
        marketDataVM.$topGainers.sink { [weak self] in self?.topGainers = $0 }.store(in: &cancellables)
        marketDataVM.$topLosers.sink { [weak self] in self?.topLosers = $0 }.store(in: &cancellables)
        marketDataVM.$mostActive.sink { [weak self] in self?.mostActive = $0 }.store(in: &cancellables)
        
        portfolioVM.$portfolio.sink { [weak self] in self?.portfolio = $0 }.store(in: &cancellables)
        portfolioVM.$balance.sink { [weak self] in self?.balance = $0 }.store(in: &cancellables)
        portfolioVM.$bistBalance.sink { [weak self] in self?.bistBalance = $0 }.store(in: &cancellables)
        
        watchlistStore.$items.sink { [weak self] in self?.watchlist = $0 }.store(in: &cancellables)
    }
    
    // Convenience Methods
    func addToWatchlist(symbol: String) {
        watchlistStore.add(symbol)
    }
    
    func removeFromWatchlist(symbol: String) {
        watchlistStore.remove(symbol)
    }
    
    func getEquity() -> Double {
        return portfolioVM.getEquity()
    }
    
    func clearAll() {
        marketDataVM.clearAll()
        portfolioVM.clearAll()
        errorMessage = nil
    }
}
