import Foundation
import Combine
import SwiftUI

// MARK: - Watchlist Manager
// TradingViewModel'dan extract edilmiş watchlist yönetim modülü

@MainActor
final class WatchlistManager: ObservableObject, WatchlistManaging {
    
    // MARK: - Singleton (Legacy Support)
    static let shared = WatchlistManager()
    
    // MARK: - Published Properties
    
    @Published var watchlist: [String] = [] {
        didSet {
            saveWatchlist()
            objectWillChange.send()
        }
    }
    
    // MARK: - Private
    
    private let watchlistKey = "watchlist"
    
    // MARK: - Initialization
    
    private init() {
        loadWatchlist()
    }
    
    // MARK: - WatchlistManaging Protocol
    
    func add(_ symbol: String) {
        guard !watchlist.contains(symbol) else { return }
        watchlist.append(symbol)
        print("📋 Watchlist: \(symbol) eklendi")
    }
    
    func remove(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
        print("📋 Watchlist: \(symbol) kaldırıldı")
    }
    
    func contains(_ symbol: String) -> Bool {
        watchlist.contains(symbol)
    }
    
    // MARK: - Convenience Methods
    
    func toggle(_ symbol: String) {
        if contains(symbol) {
            remove(symbol)
        } else {
            add(symbol)
        }
    }
    
    func clear() {
        watchlist.removeAll()
    }
    
    func reorder(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Persistence
    
    private func loadWatchlist() {
        if let saved = UserDefaults.standard.stringArray(forKey: watchlistKey) {
            self.watchlist = saved
        } else {
            // Default watchlist for new users
            self.watchlist = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA"]
        }
    }
    
    private func saveWatchlist() {
        UserDefaults.standard.set(watchlist, forKey: watchlistKey)
    }
}
