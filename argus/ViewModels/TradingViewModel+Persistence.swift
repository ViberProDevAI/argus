import Foundation
import SwiftUI
import Combine

// MARK: - Persistence & Storage (Deprecated)
// Logic migrated to Stores (WatchlistStore, PortfolioStore)

extension TradingViewModel {

    // MARK: - Legacy methods removed to prevent conflicts
    // All persistence is now handled by Stores.

    // MARK: - Reset (Debug)
    func resetAllData() {
        print("🗑️ Resetting All Data (Delegating to Stores)...")
        
        // 1. Reset Watchlist
        let allSymbols = watchlist
        for symbol in allSymbols {
            WatchlistStore.shared.remove(symbol)
        }
        // Force default list if empty? WatchlistStore handles defaults on init usually.
        // Or we can add explicit reset method to WatchlistStore later.
        
        // 2. Reset Portfolio & Balance
        PortfolioStore.shared.resetPortfolio()
        
        // 3. Reset Local State (will be overwritten by Store sync anyway)
        self.watchlist = []
        
        print("✅ Data Reset Complete")
    }
}

