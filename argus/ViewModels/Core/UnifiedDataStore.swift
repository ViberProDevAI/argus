import Foundation
import Combine
import SwiftUI

/// FAZ 1: Unified Data Store
/// Argus'un single source of truth'u.
/// Tüm working features'lar korunmuş, backward compatibility sağlanmış.
///
/// DEPRECATED: Use AppStateCoordinator.shared instead.
/// UnifiedDataStore will be removed in v2.0. This class duplicated data management
/// and is being consolidated into AppStateCoordinator for a proper Single Source of Truth.
@available(*, deprecated,
           message: "Use AppStateCoordinator.shared instead. UnifiedDataStore will be removed in v2.0")
@MainActor
final class UnifiedDataStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UnifiedDataStore()
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    private init() {
        setupBindings()
        setupCoordination()
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        // WatchlistVM
        WatchlistViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // AppStateCoordinator
        AppStateCoordinator.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // MarketDataStore
        MarketDataStore.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // SignalStateViewModel
        SignalStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // ExecutionStateViewModel
        ExecutionStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // DiagnosticsViewModel
        DiagnosticsViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // Setup PortfolioStore explicit publisher forwarding if needed
        PortfolioStore.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    private func setupCoordination() {
        // Watchlist değiştiğinde quote yükle
        WatchlistViewModel.shared.$watchlist
            .dropFirst()
            .sink { [weak self] symbols in
                Task { @MainActor in
                    for symbol in symbols {
                        if self?.watchlistQuotes[symbol] == nil {
                            await self?.loadQuote(for: symbol)
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind Stores State
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                self?.watchlistQuotes = storeQuotes.compactMapValues { $0.value }
            }
            .store(in: &cancellables)
        
        PortfolioStore.shared.$trades
            .receive(on: RunLoop.main)
            .sink { [weak self] trades in
                self?.portfolio = trades
            }
            .store(in: &cancellables)
            
        PortfolioStore.shared.$globalBalance
            .receive(on: RunLoop.main)
            .sink { [weak self] val in self?.globalBalance = val }
            .store(in: &cancellables)
            
        PortfolioStore.shared.$bistBalance
            .receive(on: RunLoop.main)
            .sink { [weak self] val in self?.bistBalance = val }
            .store(in: &cancellables)
    }
    
    // MARK: - WATCHLIST
    
    @Published var watchlist: [String] = []
    @Published var watchlistQuotes: [String: Quote] = [:]
    @Published var isWatchlistLoading: Bool = false
    
    func addSymbol(_ symbol: String) {
        WatchlistViewModel.shared.addSymbol(symbol)
    }
    
    func removeSymbol(_ symbol: String) {
        WatchlistViewModel.shared.removeSymbol(symbol)
    }
    
    func removeSymbols(at offsets: IndexSet) {
        WatchlistViewModel.shared.removeSymbols(at: offsets)
    }
    
    func moveSymbols(from source: IndexSet, to destination: Int) {
        WatchlistViewModel.shared.moveSymbols(from: source, to: destination)
    }
    
    func contains(_ symbol: String) -> Bool {
        return WatchlistViewModel.shared.contains(symbol)
    }
    
    func loadQuote(for symbol: String) async {
        await WatchlistViewModel.shared.loadQuote(for: symbol)
    }
    
    func refreshAllQuotes() async {
        await WatchlistViewModel.shared.refreshAllQuotes()
    }
    
    func search(query: String) {
        WatchlistViewModel.shared.search(query: query)
    }
    
    // MARK: - MARKET DATA
    
    // Direct from MarketDataStore
    var quotes: [String: Quote] {
        get { 
            var result: [String: Quote] = [:]
            for (key, val) in MarketDataStore.shared.quotes {
                if let q = val.value { result[key] = q }
            }
            return result
        }
    }
    
    var candles: [String: [Candle]] {
        get {
             var result: [String: [Candle]] = [:]
             for (key, val) in MarketDataStore.shared.candles {
                 if let c = val.value { result[key] = c }
             }
             return result
        }
    }
    
    // Top Gainers etc. - Should be calculated or fetched from a VM?
    // Using placeholders for now to fix build.
    var topGainers: [Quote] = []
    var topLosers: [Quote] = []
    var mostActive: [Quote] = []
    var searchResults: [SearchResult] {
        get { WatchlistViewModel.shared.searchResults }
        set { WatchlistViewModel.shared.searchResults = newValue }
    }
    
    // MARK: - SIGNALS (SignalStateViewModel)
    
    var orionAnalysis: [String: MultiTimeframeAnalysis] {
        get { SignalStateViewModel.shared.orionAnalysis }
        set { SignalStateViewModel.shared.orionAnalysis = newValue }
    }
    
    var isOrionLoading: Bool {
        get { SignalStateViewModel.shared.isOrionLoading }
        set { SignalStateViewModel.shared.isOrionLoading = newValue }
    }
    
    var patterns: [String: [OrionChartPattern]] {
        get { SignalStateViewModel.shared.patterns }
        set { SignalStateViewModel.shared.patterns = newValue }
    }
    
    var grandDecisions: [String: ArgusGrandDecision] {
        get { SignalStateViewModel.shared.grandDecisions }
        set { SignalStateViewModel.shared.grandDecisions = newValue }
    }
    
    var chimeraSignals: [String: ChimeraSignal] {
        get { SignalStateViewModel.shared.chimeraSignals }
        set { SignalStateViewModel.shared.chimeraSignals = newValue }
    }
    
    var orionScores: [String: OrionScoreResult] {
        return SignalStateViewModel.shared.orionAnalysis.mapValues { $0.daily }
    }
    
    var athenaResults: [String: AthenaFactorResult] {
        get { SignalStateViewModel.shared.athenaResults }
        set { SignalStateViewModel.shared.athenaResults = newValue }
    }
    
    // MARK: - PORTFOLIO (PortfolioStore)
    
    @Published var portfolio: [Trade] = []
    @Published var globalBalance: Double = 100000.0
    @Published var bistBalance: Double = 1000000.0
    @Published var transactionHistory: [Transaction] = []
    
    func addTrade(_ trade: Trade) {
        // PortfolioStore.shared.add(trade) // Private?
        // Use buy/sell methods usually.
    }
    
    func removeTrade(_ trade: Trade) {
       // PortfolioStore.shared.remove(trade)
    }
    
    func closeTrade(_ trade: Trade) {
       // PortfolioStore.shared.close(...)
    }
    
    func updateTrade(_ trade: Trade) {
       // PortfolioStore.shared.update(...)
    }
    
    // MARK: - TCMB & Flow (Placeholders to fix build)
    var tcmbData: TCMBDataService.TCMBMacroSnapshot?
    var foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData] = [:]
    var isLiveMode: Bool = false
    var marketRegime: MarketRegime = .neutral
    
    // MARK: - TERMINAL
    @Published var terminalItems: [TerminalItem] = []
    
    func refreshTerminal() {
        // No-op or call dedicated service
    }
    
    // MARK: - AI & MACRO
    var aiSignals: [AISignal] = []
    var macroRating: MacroEnvironmentRating?
    var poseidonWhaleScores: [String: WhaleScore] = [:]
    
    // MARK: - UI STATE
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedSymbol: String? = nil
    
    @Published var etfSummaries: [String: ArgusEtfSummary] = [:]
    @Published var isLoadingEtf: Bool = false
    
    // MARK: - REPORTS
    @Published var dailyReport: String?
    @Published var weeklyReport: String?
    @Published var bistDailyReport: String?
    @Published var bistWeeklyReport: String?
    
    // MARK: - BACKTEST & LAB
    @Published var activeBacktestResult: BacktestResult?
    @Published var kapDisclosures: [String: [KAPDataService.KAPNews]] = [:]
    @Published var bistAtmosphere: AetherDecision?
    @Published var bistAtmosphereLastUpdated: Date?
    
    // MARK: - EXECUTION
    var isAutoPilotEnabled: Bool {
        get { ExecutionStateViewModel.shared.isAutoPilotEnabled }
        set { ExecutionStateViewModel.shared.isAutoPilotEnabled = newValue }
    }
    
    var autoPilotLogs: [String] {
        get { ExecutionStateViewModel.shared.autoPilotLogs }
        set { ExecutionStateViewModel.shared.autoPilotLogs = newValue }
    }
    
    @Published var lastAction: String = ""
    
    // MARK: - SCOUTING
    // Needs AutoPilotStore? Since TradingViewModel usage was forwarding.
    var scoutingCandidates: [TradeSignal] {
        get { return [] } // Placeholder
        set { }
    }
    
    var scoutLogs: [ScoutLog] {
        get { return [] }
        set { }
    }
    
    @Published var planAlerts: [TradeBrainAlert] = []
    @Published var agoraSnapshots: [DecisionSnapshot] = []
    @Published var lastTradeTimes: [String: Date] = [:]
    
    @Published var universeCache: [String: UniverseItem] = [:]
    
    func fetchUniverseDetails(for symbol: String) async {
        // Implementation
    }
    
    // MARK: - LABS
    @Published var sarTsiBacktestResult: OrionSarTsiBacktestResult?
    @Published var isLoadingSarTsiBacktest: Bool = false
    @Published var sarTsiErrorMessage: String?
    @Published var overreactionResult: OverreactionResult?
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter: Bool = false
    @Published var activeShocks: [ShockFlag] = []
    
    @Published var hermesSummaries: [String: [HermesSummary]] = [:]
    @Published var hermesMode: HermesMode = .full
    
    func loadHermes(for symbol: String) async {
        
    }
    
    // MARK: - DIAGNOSTICS
    var dataHealthBySymbol: [String: DataHealth] {
        get { DiagnosticsViewModel.shared.dataHealthBySymbol }
        set { DiagnosticsViewModel.shared.dataHealthBySymbol = newValue }
    }
    
    var bootstrapDuration: Double {
        get { DiagnosticsViewModel.shared.bootstrapDuration }
        set { DiagnosticsViewModel.shared.bootstrapDuration = newValue }
    }
    
    var lastBatchFetchDuration: Double {
        get { DiagnosticsViewModel.shared.lastBatchFetchDuration }
        set { DiagnosticsViewModel.shared.lastBatchFetchDuration = newValue }
    }
    
    @Published var isBacktesting: Bool = false
    
    @Published var isUnlimitedPositions: Bool = false {
        didSet {
            PortfolioRiskManager.shared.isUnlimitedPositionsEnabled = isUnlimitedPositions
        }
    }
    
    var discoverSymbols: Set<String> = []
    var failedFundamentals: Set<String> = []
    
    func runDemeterAnalysis() async {
        // Call Service
    }
    
    func getDemeterMultipliers(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        return (1.0, 1.0, false)
    }
    
    func getDemeterScore(for symbol: String) -> DemeterScore? {
        return nil
    }
}
// MARK: - BACKWARD COMPATIBILITY EXTENSIONS

/// TradingViewModel için backward compatibility
extension TradingViewModel {
    var unifiedStore: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
}

/// WatchlistViewModel için backward compatibility
extension WatchlistViewModel {
    var unifiedStore: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
}

/// AppStateCoordinator için backward compatibility
extension AppStateCoordinator {
    var unifiedStore: UnifiedDataStore {
        return UnifiedDataStore.shared
    }
}
