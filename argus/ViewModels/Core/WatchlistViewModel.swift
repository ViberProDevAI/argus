import Foundation
import Combine
import SwiftUI

/// FAZ 2: WatchlistViewModel
/// Watchlist yönetimi ve quote verilerini kontrol eden ViewModel.
/// TradingViewModel'den ayrıştırıldı.
@MainActor
final class WatchlistViewModel: ObservableObject {
    
    // MARK: - Singleton
    static let shared = WatchlistViewModel()
    
    // MARK: - Watchlist State
    @Published var watchlist: [String] = [] {
        didSet {
            saveWatchlist()
        }
    }
    
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Discovery Lists
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    
    // MARK: - Search State
    @Published var searchResults: [SearchResult] = []
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Services
    private let marketDataProvider = MarketDataProvider.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys

    
    // MARK: - Init
    init() {
        loadWatchlist()
        observeMarketDataStore()
    }
    
    // MARK: - Market Data Store Binding
    private func observeMarketDataStore() {
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                guard let self = self else { return }
                // DataValue<Quote> -> Quote dönüşümü
                self.quotes = storeQuotes.compactMapValues { $0.value }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Watchlist Management
    
    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        guard !watchlist.contains(upper) else { return }
        watchlist.append(upper)
        
        // Yeni sembol için veri çek
        Task {
            await loadQuote(for: upper)
        }
    }
    
    func removeSymbol(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
    }
    
    func removeSymbols(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
    }
    
    func moveSymbols(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
    }
    
    func contains(_ symbol: String) -> Bool {
        watchlist.contains(symbol.uppercased())
    }
    
    // MARK: - Quote Loading
    
    func loadQuote(for symbol: String) async {
        let dataValue = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        if let quote = dataValue.value {
            await MainActor.run {
                self.quotes[symbol] = quote
            }
        }
    }
    
    func refreshAllQuotes() async {
        isLoading = true
        defer { isLoading = false }
        
        for symbol in watchlist {
            await loadQuote(for: symbol)
        }
    }
    
    // MARK: - Search
    
    func search(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await marketDataProvider.searchSymbols(query: query)
                await MainActor.run {
                    self.searchResults = results
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    // MARK: - Persistence
    // TradingViewModel ile uyumlu olması için "watchlist_v2" ve JSON formatı kullanıyoruz.
    
    private let watchlistKey = "watchlist_v2"
    
    private func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(watchlist) {
            UserDefaults.standard.set(encoded, forKey: watchlistKey)
        }
    }
    
    private func loadWatchlist() {
        // Önce v2 key'ini dene (JSON Data)
        if let data = UserDefaults.standard.data(forKey: watchlistKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.watchlist = decoded
            print("✅ Watchlist loaded from \(watchlistKey) (\(decoded.count) symbols)")
            return
        }
        
        // Eğer v2 yoksa, belki eski "user_watchlist" vardır (Array)
        // Migration amaçlı kontrol
        if let savedOld = UserDefaults.standard.array(forKey: "user_watchlist") as? [String], !savedOld.isEmpty {
            self.watchlist = savedOld
            print("⚠️ Watchlist migrated from old key to v2")
            saveWatchlist() // Yeni formata taşı
            return
        }
           
        // Hiçbiri yoksa varsayılan
        print("ℹ️ No saved watchlist found. Using default.")
        watchlist = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "THYAO.IS", "GARAN.IS"]
    }
    
    // MARK: - Discovery
    
    func loadDiscoveryLists() async {
        // MarketDataProvider üzerinden gainers/losers çek
        // Bu fonksiyon TradingViewModel+MarketData'dan taşınacak
    }
}
