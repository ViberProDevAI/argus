import Foundation
import Combine
import SwiftUI

/// AppStateCoordinator+Data
/// Computed properties that provide unified access to child stores without data duplication.
/// All @Published properties are defined in the main AppStateCoordinator class.
extension AppStateCoordinator {

    // MARK: - Portfolio Domain (from PortfolioStore)
    /// Portfolio trades from PortfolioStore
    var portfolioTrades: [Trade] {
        PortfolioStore.shared.trades
    }

    /// Global (USD) balance from PortfolioStore
    var globalBalance: Double {
        PortfolioStore.shared.globalBalance
    }

    /// BIST (TRY) balance from PortfolioStore
    var bistBalance: Double {
        PortfolioStore.shared.bistBalance
    }

    /// Portfolio transactions from PortfolioStore
    var portfolioTransactions: [Transaction] {
        PortfolioStore.shared.transactions
    }

    // MARK: - Market Data Domain (from MarketDataStore)
    /// Live quotes from MarketDataStore
    var liveQuotes: [String: Quote] {
        var result: [String: Quote] = [:]
        for (symbol, dataValue) in MarketDataStore.shared.quotes {
            if let quote = dataValue.value {
                result[symbol] = quote
            }
        }
        return result
    }

    /// Candles from MarketDataStore
    var marketCandles: [String: [Candle]] {
        var result: [String: [Candle]] = [:]
        for (symbol, dataValue) in MarketDataStore.shared.candles {
            if let candles = dataValue.value {
                result[symbol] = candles
            }
        }
        return result
    }

    // MARK: - Watchlist Domain (from WatchlistViewModel)
    /// Watchlist symbols from WatchlistViewModel
    var watchlistSymbols: [String] {
        WatchlistViewModel.shared.watchlist
    }

    /// Watchlist quotes from WatchlistViewModel
    var watchlistQuotes: [String: Quote] {
        WatchlistViewModel.shared.quotes
    }

    /// Watchlist loading state from WatchlistViewModel
    var isWatchlistLoading: Bool {
        WatchlistViewModel.shared.isLoading
    }

    /// Search results from WatchlistViewModel
    var searchResults: [SearchResult] {
        WatchlistViewModel.shared.searchResults
    }

    // MARK: - Signal/Analysis Domain (from SignalStateViewModel)
    /// Orion analysis from SignalStateViewModel
    var orionAnalysis: [String: MultiTimeframeAnalysis] {
        SignalStateViewModel.shared.orionAnalysis
    }

    /// Orion loading state from SignalStateViewModel
    var isOrionLoading: Bool {
        SignalStateViewModel.shared.isOrionLoading
    }

    /// Chart patterns from SignalStateViewModel
    var chartPatterns: [String: [OrionChartPattern]] {
        SignalStateViewModel.shared.patterns
    }

    /// Grand decisions from SignalStateViewModel
    var grandDecisions: [String: ArgusGrandDecision] {
        SignalStateViewModel.shared.grandDecisions
    }

    /// Chimera signals from SignalStateViewModel
    var chimeraSignals: [String: ChimeraSignal] {
        SignalStateViewModel.shared.chimeraSignals
    }

    /// Athena results from SignalStateViewModel
    var athenaResults: [String: AthenaFactorResult] {
        SignalStateViewModel.shared.athenaResults
    }

    // MARK: - Execution Domain (from ExecutionStateViewModel)
    /// AutoPilot enabled state from ExecutionStateViewModel
    var isAutoPilotEnabled: Bool {
        ExecutionStateViewModel.shared.isAutoPilotEnabled
    }

    /// AutoPilot logs from ExecutionStateViewModel
    var autoPilotLogs: [String] {
        ExecutionStateViewModel.shared.autoPilotLogs
    }

    // MARK: - Diagnostics Domain (from DiagnosticsViewModel)
    /// Data health by symbol from DiagnosticsViewModel
    var dataHealthBySymbol: [String: DataHealth] {
        DiagnosticsViewModel.shared.dataHealthBySymbol
    }

    /// Bootstrap duration from DiagnosticsViewModel
    var bootstrapDuration: Double {
        DiagnosticsViewModel.shared.bootstrapDuration
    }

    /// Last batch fetch duration from DiagnosticsViewModel
    var lastBatchFetchDuration: Double {
        DiagnosticsViewModel.shared.lastBatchFetchDuration
    }

    // MARK: - Combined Computed Properties

    /// Combined loading state from all sources
    var isLoading: Bool {
        isGlobalLoading || isWatchlistLoading || isOrionLoading || isLoadingEtf || isLoadingSarTsiBacktest || isRunningDemeter
    }
}
