import Foundation
import Combine

@MainActor
class MarketDataViewModel: ObservableObject {
    static let shared = MarketDataViewModel()
    
    @Published var quotes: [String: Quote] = [:]
    @Published var candles: [String: [Candle]] = [:]
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    @Published var isLoadingQuotes = false
    @Published var isLoadingCandles = false
    @Published var isLoadingDiscovery = false
    @Published var errorMessage: String?
    
    private let marketDataStore = MarketDataStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupDataSubscriptions()
    }
    
    private func setupDataSubscriptions() {
        // Placeholder - gerçek implementasyon sonradan
    }
    
    func getQuote(for symbol: String) -> Quote? {
        return quotes[symbol]
    }
    
    func clearAll() {
        quotes.removeAll()
        candles.removeAll()
        topGainers.removeAll()
        topLosers.removeAll()
        mostActive.removeAll()
        errorMessage = nil
    }
}
