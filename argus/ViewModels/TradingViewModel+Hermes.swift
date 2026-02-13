import Foundation
import SwiftUI
import Combine

// MARK: - Hermes News Integration (Delegated to HermesNewsViewModel)
/// All Hermes methods are now delegated to HermesNewsViewModel.
/// This extension provides backward compatibility for existing code.
extension TradingViewModel {

    // MARK: - Delegated Methods

    @MainActor
    func loadNewsAndInsights(for symbol: String, isGeneral: Bool = false) {
        HermesNewsViewModel.shared.loadNewsAndInsights(for: symbol, isGeneral: isGeneral)
    }

    @MainActor
    func loadWatchlistFeed() {
        HermesNewsViewModel.shared.loadWatchlistFeed()
    }

    func loadGeneralFeed() {
        HermesNewsViewModel.shared.loadGeneralFeed()
    }

    @MainActor
    func refreshBistAtmosphere() async {
        await HermesNewsViewModel.shared.refreshBistAtmosphere()
        let state = HermesNewsViewModel.shared.currentBistAtmosphereState()
        self.bistAtmosphere = state.decision
        self.bistAtmosphereLastUpdated = state.lastUpdated
    }

    func getHermesHighlights() -> [NewsInsight] {
        return HermesNewsViewModel.shared.getHermesHighlights()
    }

    @MainActor
    func analyzeOnDemand(symbol: String) async {
        await HermesNewsViewModel.shared.analyzeOnDemand(symbol: symbol)
    }
}
