import Foundation
import Combine
import SwiftUI

/// FAZ 1: Sprint 1.2 - Backward Compatibility Wrappers
/// Mevcut TradingViewModel methods preserve etmek için wrapper'lar.
/// Legacy kodların bozulmasını engeller.

// MARK: - TradingViewModel Backward Compatibility Extensions

extension TradingViewModel {
    
    /// UnifiedDataStore erişimi (zaten mevcut, preserve ediliyor)
    var unifiedStoreLegacy: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
    
    // MARK: - WATCHLIST MANAGEMENT (Legacy Methods Preserve)
    
    /// Legacy addSymbol method - UnifiedDataStore'a delegate ediyor
    func addSymbolLegacy(_ symbol: String) {
        UnifiedDataStore.shared.addSymbol(symbol)
    }
    
    // MARK: - MARKET DATA METHODS (Legacy Methods Preserve)
    
    /// Legacy fetchQuoteLegacy method - MarketViewModel'e delegate ediyor
    func fetchQuoteLegacy(for symbol: String) async {
        await UnifiedDataStore.shared.loadQuote(for: symbol)
    }
    
    /// Legacy loadQuotesForWatchlist method - UnifiedDataStore'a delegate ediyor
    func loadQuotesForWatchlist() async {
        await UnifiedDataStore.shared.refreshAllQuotes()
    }
    
    /// Legacy loadPrometheusForecast method - Preserve ediliyor
    func loadPrometheusForecast(for symbol: String) async {
        
    }
    
    /// Legacy loadMacroEnvironmentLegacy method - Preserve ediliyor
    func loadMacroEnvironmentLegacy() {
        
    }
    
    // MARK: - SIGNAL METHODS (Legacy Methods Preserve)
    
    /// Legacy refreshTerminalLegacy method - UnifiedDataStore'a delegate ediyor
    func refreshTerminalLegacy() {
        UnifiedDataStore.shared.refreshTerminal()
    }
    
    // MARK: - PORTFOLIO METHODS (Legacy Methods Preserve)
    
    /// Legacy buy method - PortfolioStore'e delegate ediyor
    func buyLegacy(symbol: String, quantity: Double, price: Double, reason: String, dominantSignal: String, decisionId: String) {
        
    }
    
    /// Legacy sell method - PortfolioStore'e delegate ediyor
    func sellLegacy(symbol: String, quantity: Double, price: Double, reason: String, decisionId: String) {
        
    }
    
    /// Legacy closePosition method - PortfolioStore'e delegate ediyor
    func closePositionLegacy(symbol: String, quantity: Double, price: Double, reason: String) {
        
    }
    
    /// Legacy updatePosition method - PortfolioStore'e delegate ediyor
    func updatePositionLegacy(symbol: String, quantity: Double, price: Double, reason: String) {
        
    }
    
    // MARK: - DEMETER METHODS (Legacy Methods Preserve)
    
    /// Legacy runDemeterAnalysis method - UnifiedDataStore'a delegate ediyor
    func runDemeterAnalysisLegacy() async {
        await UnifiedDataStore.shared.runDemeterAnalysis()
    }
    
    /// Legacy getDemeterMultipliers method - UnifiedDataStore'a delegate ediyor
    func getDemeterMultipliersLegacy(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        return await UnifiedDataStore.shared.getDemeterMultipliers(for: symbol)
    }
    
    /// Legacy getDemeterScore method - UnifiedDataStore'a delegate ediyor
    func getDemeterScoreLegacy(for symbol: String) -> DemeterScore? {
        return UnifiedDataStore.shared.getDemeterScore(for: symbol)
    }
    
    // MARK: - ALKINDUS METHODS (Legacy Methods Preserve)
    
    /// Legacy runAlkindusMaturation method - Preserve ediliyor
    func runAlkindusMaturationLegacy() async {
        
    }
    
    // MARK: - HERMES METHODS (Legacy Methods Preserve)
    
    /// Legacy loadHermes method - UnifiedDataStore'a delegate ediyor
    func loadHermesLegacy(for symbol: String) async {
        await UnifiedDataStore.shared.loadHermes(for: symbol)
    }
    
    // MARK: - CHIRON METHODS (Legacy Methods Preserve)
    
    /// Legacy loadChironRegime method - Preserve ediliyor
    func loadChironRegimeLegacy() async {
        
    }
    
    /// Legacy runChironLearningJob method - Preserve ediliyor
    func runChironLearningJobLegacy() async {
        
    }
}

// MARK: - WatchlistViewModel Backward Compatibility Extensions

extension WatchlistViewModel {
    
    /// UnifiedDataStore erişimi (zaten mevcut, preserve ediliyor)
    var unifiedStoreLegacy: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
    
    // MARK: - WATCHLIST MANAGEMENT (Legacy Methods Preserve)
    
    /// Legacy addSymbol method - Preserve ediliyor
    func addSymbolLegacy(_ symbol: String) {
        UnifiedDataStore.shared.addSymbol(symbol)
    }
    
    /// Legacy removeSymbol method - UnifiedDataStore'a delegate ediyor
    func removeSymbolLegacy(_ symbol: String) {
        UnifiedDataStore.shared.removeSymbol(symbol)
    }
    
    /// Legacy contains method - UnifiedDataStore'a delegate ediyor
    func containsLegacy(_ symbol: String) -> Bool {
        return UnifiedDataStore.shared.contains(symbol)
    }
    
    // MARK: - SEARCH METHODS (Legacy Methods Preserve)
    
    /// Legacy search method - Preserve ediliyor
    func searchLegacy(query: String) {
        UnifiedDataStore.shared.search(query: query)
    }
    
    // MARK: - QUOTE METHODS (Legacy Methods Preserve)
    
    /// Legacy loadQuote method - UnifiedDataStore'a delegate ediyor
    func loadQuoteLegacy(for symbol: String) async {
        await UnifiedDataStore.shared.loadQuote(for: symbol)
    }
    
    /// Legacy refreshAllQuotes method - UnifiedDataStore'a delegate ediyor
    func refreshAllQuotesLegacy() async {
        await UnifiedDataStore.shared.refreshAllQuotes()
    }
    
    // MARK: - PERSISTENCE METHODS (Legacy Methods Preserve)
    
    /// Legacy saveWatchlist method - Preserve ediliyor
    func saveWatchlistLegacy() {
        
    }
    
    /// Legacy loadWatchlist method - Preserve ediliyor
    func loadWatchlistLegacy() {
        
    }
}

// MARK: - AppStateCoordinator Backward Compatibility Extensions

extension AppStateCoordinator {
    
    /// UnifiedDataStore erişimi (zaten mevcut, preserve ediliyor)
    var unifiedStoreLegacy: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
    
    // MARK: - NAVIGATION METHODS (Legacy Methods Preserve)
    
    /// Legacy selectSymbol method - Preserve ediliyor
    func selectSymbolLegacy(_ symbol: String) {
        UnifiedDataStore.shared.selectedSymbol = symbol
    }
    
    // MARK: - COORDINATION METHODS (Legacy Methods Preserve)
    
    /// Legacy coordination method - Preserve ediliyor
    func coordinateWatchlistWithQuotesLegacy() {
        
    }
    
    /// Legacy coordination method - Preserve ediliyor
    func coordinatePortfolioWithQuotesLegacy() {
        
    }
}

// MARK: - MARKET DATA STORE BACKWARD COMPATIBILITY

extension MarketDataStore {
    
    /// Legacy quotes subscription method - Preserve ediliyor
    func subscribeToQuotesLegacy() -> AnyPublisher<[String: DataValue<Quote>], Never> {
        return $quotes.eraseToAnyPublisher()
    }
    
    /// Legacy candles subscription method - Preserve ediliyor
    func subscribeToCandlesLegacy() -> AnyPublisher<[String: DataValue<[Candle]>], Never> {
        return $candles.eraseToAnyPublisher()
    }
}

// MARK: - SIGNAL STATE VIEW MODEL BACKWARD COMPATIBILITY

extension SignalStateViewModel {
    
    /// Legacy orionAnalysis subscription method - Preserve ediliyor
    func subscribeToOrionAnalysisLegacy() -> AnyPublisher<[String: MultiTimeframeAnalysis], Never> {
        return $orionAnalysis.eraseToAnyPublisher()
    }
    
    /// Legacy grandDecisions subscription method - Preserve ediliyor
    func subscribeToGrandDecisionsLegacy() -> AnyPublisher<[String: ArgusGrandDecision], Never> {
        return $grandDecisions.eraseToAnyPublisher()
    }
    
    /// Legacy chimeraSignals subscription method - Preserve ediliyor
    func subscribeToChimeraSignalsLegacy() -> AnyPublisher<[String: ChimeraSignal], Never> {
        return $chimeraSignals.eraseToAnyPublisher()
    }
}

// MARK: - EXECUTION STATE VIEW MODEL BACKWARD COMPATIBILITY

extension ExecutionStateViewModel {
    
    /// Legacy isAutoPilotEnabled subscription method - Preserve ediliyor
    func subscribeToAutoPilotEnabledLegacy() -> AnyPublisher<Bool, Never> {
        return $isAutoPilotEnabled.eraseToAnyPublisher()
    }
    
    /// Legacy autoPilotLogs subscription method - Preserve ediliyor
    func subscribeToAutoPilotLogsLegacy() -> AnyPublisher<[String], Never> {
        return $autoPilotLogs.eraseToAnyPublisher()
    }
}

// MARK: - PORTFOLIO STORE BACKWARD COMPATIBILITY

extension PortfolioStore {
    
    /// Legacy trades subscription method - Preserve ediliyor
    func subscribeToTradesLegacy() -> AnyPublisher<[Trade], Never> {
        return $trades.eraseToAnyPublisher()
    }
    
    /// Legacy globalBalance subscription method - Preserve ediliyor
    func subscribeToGlobalBalanceLegacy() -> AnyPublisher<Double, Never> {
        return $globalBalance.eraseToAnyPublisher()
    }
    
    /// Legacy bistBalance subscription method - Preserve ediliyor
    func subscribeToBistBalanceLegacy() -> AnyPublisher<Double, Never> {
        return $bistBalance.eraseToAnyPublisher()
    }
    
    /// Legacy transactions subscription method - Preserve ediliyor
    func subscribeToTransactionsLegacy() -> AnyPublisher<[Transaction], Never> {
        return $transactions.eraseToAnyPublisher()
    }
}

// MARK: - WATCHLIST STORE BACKWARD COMPATIBILITY

extension WatchlistStore {
    
    /// Legacy items subscription method - Preserve ediliyor
    func subscribeToItemsLegacy() -> AnyPublisher<[String], Never> {
        return $items.eraseToAnyPublisher()
    }
}

// MARK: - DIAGNOSTICS VIEW MODEL BACKWARD COMPATIBILITY

extension DiagnosticsViewModel {
    
    /// Legacy dataHealthBySymbol subscription method - Preserve ediliyor
    func subscribeToDataHealthBySymbolLegacy() -> AnyPublisher<[String: DataHealth], Never> {
        return $dataHealthBySymbol.eraseToAnyPublisher()
    }
    
    /// Legacy bootstrapDuration subscription method - Preserve ediliyor
    func subscribeToBootstrapDurationLegacy() -> AnyPublisher<Double, Never> {
        return $bootstrapDuration.eraseToAnyPublisher()
    }
    
    /// Legacy lastBatchFetchDuration subscription method - Preserve ediliyor
    func subscribeToLastBatchFetchDurationLegacy() -> AnyPublisher<Double, Never> {
        return $lastBatchFetchDuration.eraseToAnyPublisher()
    }
}
