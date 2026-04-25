import Foundation
import Combine
import SwiftUI

/// AppStateCoordinator+Bindings
/// Sets up proper Combine bindings between AppStateCoordinator and child stores/ViewModels
/// Uses `.assign(to:)` pattern to create proper data binding without duplication.
extension AppStateCoordinator {

    /// Sets up all data bindings from child stores to coordinator properties
    /// This implements the Single Source of Truth pattern using Combine's assign(to:)
    ///
    /// The key principle: Rather than copying data with `.sink { self.property = $0 }`,
    /// we use `.assign(to: &$property)` which creates a direct binding that doesn't
    /// duplicate data - it just connects the publisher to the published property.
    func setupDataBindings() {
        setupWatchlistBindings()
        setupMarketBindings()
        setupExecutionBindings()
        setupLoadingAggregation()
    }

    // MARK: - Watchlist

    private func setupWatchlistBindings() {
        WatchlistViewModel.shared.$watchlist
            .dropFirst()
            .sink { [weak self] symbols in
                Task { @MainActor in
                    for symbol in symbols {
                        if self?.watchlistQuotes[symbol] == nil {
                            await self?.watchlist.loadQuote(for: symbol)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Market Data

    private func setupMarketBindings() {
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                self?.portfolio.handleQuoteUpdates(storeQuotes)
            }
            .store(in: &cancellables)
    }

    // MARK: - Execution State
    // AppStateCoordinator is the SINGLE SUBSCRIBER to ExecutionStateViewModel.
    // TradingViewModel reads these from coordinator (not directly from ExecutionStateViewModel).

    private func setupExecutionBindings() {
        ExecutionStateViewModel.shared.$planAlerts
            .receive(on: RunLoop.main)
            .assign(to: &$planAlerts)

        ExecutionStateViewModel.shared.$agoraSnapshots
            .receive(on: RunLoop.main)
            .assign(to: &$agoraSnapshots)

        ExecutionStateViewModel.shared.$lastTradeTimes
            .receive(on: RunLoop.main)
            .assign(to: &$lastTradeTimes)

        // lastAction not published by ExecutionStateViewModel; managed locally
    }

    // MARK: - Loading State Aggregation

    private func setupLoadingAggregation() {
        Publishers.CombineLatest4(
            WatchlistViewModel.shared.$isLoading,
            SignalStateViewModel.shared.$isOrionLoading,
            $isLoadingEtf,
            $isLoadingSarTsiBacktest
        )
        .map { $0 || $1 || $2 || $3 }
        .receive(on: RunLoop.main)
        .assign(to: &$isGlobalLoading)
    }
}
