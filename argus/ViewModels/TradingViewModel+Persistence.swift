import Foundation
import SwiftUI
import Combine

// MARK: - Persistence & Storage (Deprecated)
// Logic migrated to Stores (WatchlistStore, PortfolioStore)

extension TradingViewModel {

    // MARK: - Portfolio Persistence Facade

    func resetAllData() {
        PortfolioViewModel.shared.resetAllData()
    }

    // MARK: - Legacy methods removed to prevent conflicts
    // All persistence is now handled by Stores.
}

