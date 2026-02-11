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
        // Note: We don't bind Portfolio, Market, Signal, Execution, or Diagnostics
        // because they are already published in their respective stores.
        // The coordinator provides convenient access to them via computed properties in AppStateCoordinator+Data.swift
        //
        // What we DO bind are the UI state properties that multiple sources can affect.

        // MARK: - Watchlist Coordination
        // When watchlist is updated, load quotes for new symbols
        WatchlistViewModel.shared.$watchlist
            .dropFirst() // Skip initial value
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

        // MARK: - Market Data Coordination
        // When quotes update, propagate to portfolio for SL/TP control
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                self?.portfolio.handleQuoteUpdates(storeQuotes)
            }
            .store(in: &cancellables)

        // MARK: - UI State Coordination
        // Sync unlimited positions setting to PortfolioRiskManager
        // (Already handled by didSet in @Published var)

        // MARK: - Loading State Aggregation
        // Monitor all loading states to update parent loading indicator
        Publishers.CombineLatest4(
            WatchlistViewModel.shared.$isLoading,
            SignalStateViewModel.shared.$isOrionLoading,
            $isLoadingEtf,
            $isLoadingSarTsiBacktest
        )
        .map { isWatchlistLoading, isOrionLoading, isLoadingEtf, isLoadingSarTsiBacktest in
            isWatchlistLoading || isOrionLoading || isLoadingEtf || isLoadingSarTsiBacktest
        }
        .receive(on: RunLoop.main)
        .sink { [weak self] isLoading in
            self?.isGlobalLoading = isLoading
        }
        .store(in: &cancellables)

    }
}
