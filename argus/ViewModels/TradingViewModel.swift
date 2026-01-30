import Foundation
import Combine
import SwiftUI

class TradingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var watchlist: [String] = [] 
    
    // Discovery Lists
    // MARK: - Market Proxy (Refactored Phase 2)
    let market = MarketViewModel()
    let risk = RiskViewModel()
    let analysis = AnalysisViewModel()
    
    var quotes: [String: Quote] {
        get { market.quotes }
        set { 
            market.quotes = newValue
            PositionPlanStore.shared.updatePriceQuotes(newValue)
        }
    }
    var candles: [String: [Candle]] {
        get { market.candles }
        set { 
            market.candles = newValue 
            PositionPlanStore.shared.updateCandles(newValue)
        }
    }
    
    // Discovery Lists Proxy
    var topGainers: [Quote] {
        get { market.topGainers }
        set { market.topGainers = newValue }
    }
    var topLosers: [Quote] {
        get { market.topLosers }
        set { market.topLosers = newValue }
    }
    var mostActive: [Quote] {
        get { market.mostActive }
        set { market.mostActive = newValue }
    }
    
    // BIST Data Proxy
    var tcmbData: TCMBDataService.TCMBMacroSnapshot? { market.tcmbData }
    var foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData] { market.foreignFlowData }
    
    // Live Mode Bridge
    var isLiveMode: Bool {
        get { market.isLiveMode }
        set { market.isLiveMode = newValue }
    }
    
    // MARK: - Signal Facade (Refactored Phase 2.2)
    // Delegated to SignalStateViewModel
    
    var orionAnalysis: [String: MultiTimeframeAnalysis] { analysis.orionAnalysis }
    var isOrionLoading: Bool { analysis.isOrionLoading }
    var patterns: [String: [OrionChartPattern]] { analysis.patterns }
    
    var grandDecisions: [String: ArgusGrandDecision] {
        get { analysis.grandDecisions }
        set { analysis.grandDecisions = newValue }
    }
    
    var chimeraSignals: [String: ChimeraSignal] {
        get { analysis.chimeraSignals }
        set { analysis.chimeraSignals = newValue }
    }
    
    // Legacy Support (Mapped to Daily analysis)
    var orionScores: [String: OrionScoreResult] {
        return orionAnalysis.mapValues { $0.daily }
    }
    
    // Terminal Optimized Data Source
    @Published var terminalItems: [TerminalItem] = []
    
    func refreshTerminal() {
        let regime = market.marketRegime // Use market's regime
        
        // ... (rest of refreshTerminal logic remains same, but uses properties that are now proxies)
        let newItems = watchlist.map { symbol -> TerminalItem in
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            let quote = quotes[symbol] // Uses proxy
            let decision = grandDecisions[symbol]
            
            // Chimera Signal Computation
            // Use legacy accessor for now to keep logic simple
            let orion = orionScores[symbol]
            // ... (rest of computation)
            let hermesImpact = newsInsightsBySymbol[symbol]?.first?.impactScore
            let fundScore = getFundamentalScore(for: symbol)?.totalScore
            
            let chimeraResult = ChimeraSynergyEngine.shared.fuse(
                symbol: symbol,
                orion: orion,
                hermesImpactScore: hermesImpact,
                titanScore: fundScore,
                currentPrice: quote?.currentPrice ?? 0,
                marketRegime: regime
            )
            
            return TerminalItem(
                id: symbol,
                symbol: symbol,
                market: isBist ? .bist : .global,
                currency: isBist ? .TRY : .USD,
                price: quote?.currentPrice ?? 0.0,
                dayChangePercent: quote?.percentChange,
                orionScore: orion?.score,
                atlasScore: getFundamentalScore(for: symbol)?.totalScore,
                councilScore: decision?.confidence,
                action: decision?.action ?? .neutral,
                dataQuality: dataHealthBySymbol[symbol]?.qualityScore ?? 0,
                forecast: prometheusForecastBySymbol[symbol],
                chimeraSignal: chimeraResult.signals.first
            )
        }
        
        if newItems != terminalItems {
            terminalItems = newItems
        }
    }
    


    
    var portfolio: [Trade] {
        get { risk.portfolio }
        set { risk.portfolio = newValue }
    }
    var balance: Double {
        get { risk.balance }
        set { risk.balance = newValue }
    }
    var bistBalance: Double {
        get { risk.bistBalance }
        set { risk.bistBalance = newValue }
    }
    var usdTryRate: Double {
        get { risk.usdTryRate }
        set { risk.usdTryRate = newValue }
    }
    
    var aiSignals: [AISignal] {
        get { analysis.aiSignals }
        set { analysis.aiSignals = newValue }
    }
    var macroRating: MacroEnvironmentRating? {
        get { analysis.macroRating }
        set { analysis.macroRating = newValue }
    }
    var poseidonWhaleScores: [String: WhaleScore] {
        get { risk.poseidonWhaleScores }
        set { risk.poseidonWhaleScores = newValue }
    }
    
    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Argus ETF State
    // Argus ETF State (RiskVM)
    var etfSummaries: [String: ArgusEtfSummary] {
        get { risk.etfSummaries }
        set { risk.etfSummaries = newValue }
    }
    var isLoadingEtf: Bool {
        get { risk.isLoadingEtf }
        set { risk.isLoadingEtf = newValue }
    }
    
    // Reports
    // Reports (AnalysisVM)
    var dailyReport: String? {
        get { analysis.dailyReport }
        set { analysis.dailyReport = newValue }
    }
    var weeklyReport: String? {
        get { analysis.weeklyReport }
        set { analysis.weeklyReport = newValue }
    }
    
    var activeBacktestResult: BacktestResult? {
        get { risk.activeBacktestResult }
        set { risk.activeBacktestResult = newValue }
    }
    var kapDisclosures: [String: [KAPDataService.KAPNews]] {
        get { analysis.kapDisclosures }
        set { analysis.kapDisclosures = newValue }
    }
    
    // Smart Plan (Restored)
    @Published var generatedSmartPlan: PositionPlan?

    
    // BIST Reports
    // BIST Reports (AnalysisVM)
    var bistDailyReport: String? {
        get { analysis.bistDailyReport }
        set { analysis.bistDailyReport = newValue }
    }
    var bistWeeklyReport: String? {
        get { analysis.bistWeeklyReport }
        set { analysis.bistWeeklyReport = newValue }
    }
    
    // Sirkiye Engine State (AnalysisVM)
    var bistAtmosphere: AetherDecision? {
        get { analysis.bistAtmosphere }
        set { analysis.bistAtmosphere = newValue }
    }
    var bistAtmosphereLastUpdated: Date? {
        get { analysis.bistAtmosphereLastUpdated }
        set { analysis.bistAtmosphereLastUpdated = newValue }
    }
    
    // MARK: - Execution Facade (Refactored Phase 4)
    var isAutoPilotEnabled: Bool {
        get { ExecutionStateViewModel.shared.isAutoPilotEnabled }
        set { ExecutionStateViewModel.shared.isAutoPilotEnabled = newValue }
    }
    // autoPilotTimer REMOVED (Handled by ExecVM)
    var autoPilotLogs: [String] { ExecutionStateViewModel.shared.autoPilotLogs }
    @Published var lastAction: String = "" // Keep local for now? Or move? Keep for UI feedback.

    
    // Navigation State
    @Published var selectedSymbolForDetail: String? = nil
    
    func addToWatchlist(symbol: String) {
        WatchlistStore.shared.add(symbol)
    }
    @Published var transactionHistory: [Transaction] = []
    
    // MARK: - Smart Plan & Trade Brain
    
    func triggerSmartPlan(for trade: Trade) {
        Task {
            // SmartPlanService delegate
            let plan = await SmartPlanService.shared.createPlan(
                for: trade,
                quotes: self.quotes,
                grandDecisions: self.grandDecisions
            )
            
            // UI Delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.generatedSmartPlan = plan
            }
        }
    }
    // AutoPilot & Scout delegated to AutoPilotStore
    var scoutingCandidates: [TradeSignal] { AutoPilotStore.shared.scoutingCandidates }
    var scoutLogs: [ScoutLog] { AutoPilotStore.shared.scoutLogs }
    
    // Trade Brain Plan Execution Alerts
    @Published var planAlerts: [TradeBrainAlert] = []
    
    // AGORA (Execution Governor V2)
    @Published var agoraSnapshots: [DecisionSnapshot] = []

    // Last Trade Times delegated to ExecutionStateViewModel
    @Published var lastTradeTimes: [String: Date] = [:]
    
    // Universe Cache
    @Published var universeCache: [String: UniverseItem] = [:]

    @MainActor
    func fetchUniverseDetails(for symbol: String) async {
        // Access MainActor property on UniverseEngine
        // Since both are MainActor, this should work.
        if let item = UniverseEngine.shared.universe[symbol] {
            self.universeCache[symbol] = item
        }
    }
    
    // Orion SAR+TSI Lab State
    // Orion SAR+TSI Lab State (RiskVM)
    var sarTsiBacktestResult: OrionSarTsiBacktestResult? {
        get { risk.sarTsiBacktestResult }
        set { risk.sarTsiBacktestResult = newValue }
    }
    var isLoadingSarTsiBacktest: Bool {
        get { risk.isLoadingSarTsiBacktest }
        set { risk.isLoadingSarTsiBacktest = newValue }
    }
    var sarTsiErrorMessage: String? {
        get { risk.sarTsiErrorMessage }
        set { risk.sarTsiErrorMessage = newValue }
    }
    
    // Overreaction Hunter Lab
    // Overreaction Hunter Lab (AnalysisVM)
    var overreactionResult: OverreactionResult? {
        get { analysis.overreactionResult }
        set { analysis.overreactionResult = newValue }
    }
    
    // DEMETER (AnalysisVM)
    var demeterScores: [DemeterScore] {
        get { analysis.demeterScores }
        set { analysis.demeterScores = newValue }
    }
    var demeterMatrix: CorrelationMatrix? {
        get { analysis.demeterMatrix }
        set { analysis.demeterMatrix = newValue }
    }
    var isRunningDemeter: Bool {
        get { analysis.isRunningDemeter }
        set { analysis.isRunningDemeter = newValue }
    }
    var activeShocks: [ShockFlag] {
        get { analysis.activeShocks }
        set { analysis.activeShocks = newValue }
    }
    
    // Argus Scout (Pre-Cognition)
    // Internal timer removed - handled by AutoPilotStore
    
    // Hermes / News State
    @Published var hermesSummaries: [String: [HermesSummary]] = [:] // Symbol -> Summaries
    @Published var hermesMode: HermesMode = .full 
    
    // Generic Backtest State

    @Published var isBacktesting: Bool = false 
    
    // Smart Data Fetching State (Deprecated - Managed by Store)
    
    var discoverSymbols: Set<String> = [] // Track symbols active in Discover View
    var failedFundamentals: Set<String> = [] // Circuit Breaker for Atlas Fetches
    
    // Services
    let marketDataProvider = MarketDataProvider.shared
    let fundamentalScoreStore = FundamentalScoreStore.shared
    let aiSignalService = AISignalService.shared
    // private let tvSocket = TradingViewSocketService.shared // REMOVED
    // private var tvSubscription: AnyCancellable? // REMOVED
    
    // Sınırsız Pozisyon Modu (Limit Yok)
    @Published var isUnlimitedPositions = false {
        didSet {
            PortfolioRiskManager.shared.isUnlimitedPositionsEnabled = isUnlimitedPositions
            print("⚡️ Sınırsız Pozisyon Modu: \(isUnlimitedPositions ? "AÇIK" : "KAPALI")")
        }
    }
    

    

    
    // Search State
    // Search State

    
    // MARK: - Demeter Integration
    
    @MainActor
    func runDemeterAnalysis() async {
        self.isRunningDemeter = true
        await DemeterEngine.shared.analyze()
        
        let scores = await DemeterEngine.shared.sectorScores
        let matrix = await DemeterEngine.shared.correlationMatrix
        let shocks = await DemeterEngine.shared.activeShocks
        
        self.demeterScores = scores
        self.demeterMatrix = matrix
        self.activeShocks = shocks
        self.isRunningDemeter = false
    }
    
    func getDemeterMultipliers(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        return await DemeterEngine.shared.getMultipliers(for: symbol)
    }
    
    func getDemeterScore(for symbol: String) -> DemeterScore? {
        // Synchronous lookup from cached scores
        guard let sector = SectorMap.getSector(for: symbol) else { return nil }
        return demeterScores.first(where: { $0.sector == sector })
    }
    @Published var searchResults: [SearchResult] = []

    var athenaResults: [String: AthenaFactorResult] { SignalStateViewModel.shared.athenaResults }
    var searchTask: Task<Void, Never>?
    var isBootstrapped = false // Prevent double-work
    private var isBootstrapping = false
    
    // MARK: - Diagnostics Facade (Refactored Phase 4)
    var dataHealthBySymbol: [String: DataHealth] {
        get { DiagnosticsViewModel.shared.dataHealthBySymbol }
        set { DiagnosticsViewModel.shared.dataHealthBySymbol = newValue }
    }
    var cancellables = Set<AnyCancellable>() // Combine Subscriptions

    // Performance Metrics (Freeze Detective)
    var bootstrapDuration: Double { DiagnosticsViewModel.shared.bootstrapDuration }
    var lastBatchFetchDuration: Double { DiagnosticsViewModel.shared.lastBatchFetchDuration }
    
    init() {
        // Init is now lightweight.
        // Init is now lightweight.

        
        setupViewModelLinking()
        
        // MIGRATION: PortfolioStore'dan veri çek (Artık tek kaynak PortfolioStore)
        setupPortfolioStoreBridge()
        
        setupStreamingObservation()
        
        // Orion 2.0 Multi-Timeframe Bindings
        setupOrionBindings()
        
        // Ekonomik takvim beklenti hatırlatması kontrolü
        Task { @MainActor in
            EconomicCalendarService.shared.checkAndNotifyMissingExpectations()
        }
        
        setupTradeBrainObservers()
        
        // Alkindus: Bekleyen gözlemleri kontrol et (T+7/T+15)
        Task {
            await runAlkindusMaturation()
        }
    }
    
    // MARK: - Alkindus Maturation Job
    private func runAlkindusMaturation() async {
        // Gather current prices
        var currentPrices: [String: Double] = [:]
        for (symbol, quote) in quotes {
            currentPrices[symbol] = quote.currentPrice
        }
        
        // Also check portfolio symbols
        for trade in portfolio {
            if let quote = quotes[trade.symbol] {
                currentPrices[trade.symbol] = quote.currentPrice
            }
        }
        
        // Process matured decisions
        let evaluated = await AlkindusCalibrationEngine.shared.processMaturedDecisions(currentPrices: currentPrices)
        if evaluated > 0 {
            print("👁️ Alkindus: \(evaluated) bekleyen karar değerlendirildi")
        }
    }
    
    private func setupViewModelLinking() {
        // MARK: - DiagnosticsViewModel Bridge
        DiagnosticsViewModel.shared.$dataHealthBySymbol
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        DiagnosticsViewModel.shared.$bootstrapDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        SignalStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // MARK: - ExecutionStateViewModel Bridge
        ExecutionStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // MARK: - WatchlistStore Bridge
        WatchlistStore.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.watchlist = items
            }
            .store(in: &cancellables)
            

            
        // MARK: - MarketViewModel Bridge (Quotes/Candles/Data)
        market.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // MARK: - RiskViewModel Bridge (Portfolio/Balance)
        risk.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // MARK: - AnalysisViewModel Bridge (Signals/Reports)
        analysis.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // Legacy Candle Logic (Backwards compatibility if needed)
        // Orion logic handled by reactive components now.

    }


    
    /// PortfolioStore ile senkronizasyon - Tek Kaynak köprüsü
    private func setupPortfolioStoreBridge() {
        // Portfolio senkronizasyonu
        PortfolioStore.shared.$trades
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trades in
                self?.portfolio = trades
            }
            .store(in: &cancellables)
        
        // Global Balance senkronizasyonu
        PortfolioStore.shared.$globalBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                // didSet tetiklenmemesi için direkt atama
                if self?.balance != newBalance {
                    self?.balance = newBalance
                }
            }
            .store(in: &cancellables)
        
        // BIST Balance senkronizasyonu
        PortfolioStore.shared.$bistBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                if self?.bistBalance != newBalance {
                    self?.bistBalance = newBalance
                }
            }
            .store(in: &cancellables)
        
        // Transaction History senkronizasyonu (Raporlar için kritik!)
        PortfolioStore.shared.$transactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.transactionHistory = transactions
            }
            .store(in: &cancellables)
    }
    
    private func setupStreamingObservation() {
        // SINGLE SOURCE OF TRUTH: Quote subscription handled by setupViewModelLinking() with throttle
        // DO NOT add another subscription here - it causes duplicate updates and UI thrashing
        
        // PortfolioStore now handles SL/TP checks via its own subscription
        // AutoPilot handled by AutoPilotStore
        
        // ORION STORE BINDING REMOVED (Handled by SignalStateViewModel Facade)
    }
    
    // MARK: - Trade Brain Execution Handlers
    
    private func setupTradeBrainObservers() {
        // Handled by ExecutionStateViewModel
    }
    
    /// Call this once on App launch. Idempotent.


// MARK: - Chart Data Management
    // loadCandles moved to TradingViewModel+MarketData.swift
    
    // Helper for ETF Detection (SSoT Aware)
    // isETF moved to TradingViewModel+MarketData.swift
// MARK: - Hermes Integration
    
    func loadHermes(for symbol: String) async {
        await HermesStateViewModel.shared.loadHermes(for: symbol)
    }
    
    // fetchRawNews moved to HermesStateViewModel
    
    deinit {
        // Timer cleanup - memory leak prevention
        stopAutoPilotTimer()

        
        // Combine subscriptions cleanup
        cancellables.removeAll()
        
        print("🧹 TradingViewModel deinit - all resources cleaned up")
    }
    

    
    func stopAutoPilotTimer() {
        // AutoPilot is now handled by AutoPilotStore
        AutoPilotStore.shared.stopAutoPilotLoop()
    }
    
    // MARK: - Data Export (For AI Analysis)
    func exportTransactionHistoryJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(transactionHistory)
            return String(data: data, encoding: .utf8) ?? "Hata: Veri kodlanamadı."
        } catch {
            return "Hata: \(error.localizedDescription)"
        }
    }
    
    // methods moved to extensions
    
    // MARK: - Safe Universe Fetching
    // Removed redundant fetchSafeAssets() as fetchQuotes() handles all relevant symbols including Safe Universe.
    

    
    // Market Data methods moved to TradingViewModel+MarketData.swift
    
    // MARK: - Widget Integration (New)
    

    
    private func calculateUnrealizedPnLPercent() -> Double {
        // Real implementation requires tracking "Equity at midnight"
        // For now, returning Total Unrealized PnL %
        guard balance > 0 else { return 0.0 }
        return getUnrealizedPnL() / balance * 100
    }
    

    
    private func calculateWinRate() -> Double {
        let closedTrades = portfolio.filter { !$0.isOpen && $0.source == .autoPilot }
        guard !closedTrades.isEmpty else { return 0.0 }
        let wins = closedTrades.filter { $0.profit > 0 }.count
        return Double(wins) / Double(closedTrades.count) * 100.0
    }
    
    // MARK: - Orion Score Integration
    
    // MARK: - Orion Score Integration (Orion 2.0 Multi-Timeframe)
    @Published var prometheusForecastBySymbol: [String: PrometheusForecast] = [:]

    func ensureOrionAnalysis(for symbol: String) async {
        await OrionStore.shared.ensureAnalysis(for: symbol)
    }

    private func setupOrionBindings() {
        // Handled by SignalStateViewModel Facade
    }

    
    // MARK: - Fundamental Score
    
    func getFundamentalScore(for symbol: String) -> FundamentalScoreResult? {
        return fundamentalScoreStore.getScore(for: symbol)
    }
    
    /// Helper to create FinancialSnapshot for Atlas Council from Cached Scores
    // DEPRECATED: Use FinancialSnapshotService.shared.fetchSnapshot instead or access AnalysisViewModel.snapshots
    func getFinancialSnapshot(for symbol: String) -> FinancialSnapshot? {
        return analysis.snapshots[symbol]
    }
    var argusDecisions: [String: ArgusDecisionResult] {
        get { SignalStateViewModel.shared.argusDecisions }
        set { SignalStateViewModel.shared.argusDecisions = newValue }
    }
    
    var agoraTraces: [String: AgoraTrace] {
        get { ExecutionStateViewModel.shared.agoraTraces }
        set { ExecutionStateViewModel.shared.agoraTraces = newValue }
    }
    
    var argusExplanations: [String: ArgusExplanation] {
        get { SignalStateViewModel.shared.argusExplanations }
        set { SignalStateViewModel.shared.argusExplanations = newValue }
    }
    
    // MARK: - Argus Voice (New Reporting Layer)
    @Published var voiceReports: [String: String] = [:] // Symbol -> Report Text
    @Published var isGeneratingVoiceReport: Bool = false
    
    // Voice Report Logic moved to TradingViewModel+Argus.swift
    
    // MARK: - ETF Logic
    
    // MARK: - AGORA Execution Logic (Protected Trading)
    
    /// Merkezi işlem yürütücü. Sadece burası AutoPilot tarafından çağrılmalı.
    // MARK: - AGORA Execution Logic (Protected Trading)
    
    /// Merkezi işlem yürütücü. Sadece burası AutoPilot tarafından çağrılmalı.
    /// Amount: Notional Value ($) intended for the trade.
    // AutoPilot & Etf Methods moved to extensions

    @Published var isLoadingArgus: Bool = false
    
    // Argus Lab (Performance Tracking)
    @Published var argusLabStats: UnifiedAlgoStats?

    
    // MARK: - Smart Asset Detection
    // Argus Helpers moved to TradingViewModel+Argus.swift

    @MainActor
    // loadArgusData moved to TradingViewModel+Argus.swift
    
    // Retry AI Explanation (for 429 errors)

    
    // MARK: - Widget Integration
    
    // persistToWidget moved to TradingViewModel+Argus.swift
    

    

    
    func getTopPicks() -> [FundamentalScoreResult] {
        // Store'daki tüm skorları tara ve 70 üzeri olanları döndür
        // FundamentalScoreStore'a erişim lazım, o da private dictionary tutuyor olabilir.
        // Store'a getAllScores eklemek gerekebilir ama şimdilik watchlist üzerinden gidelim.
        
        var picks: [FundamentalScoreResult] = []
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol), score.totalScore >= 70 {
                picks.append(score)
            }
        }
        return picks.sorted { $0.totalScore > $1.totalScore }
    }
    
    // MARK: - Data Health Helper (Pillar 1)
    
    func updateDataHealth(for symbol: String, update: (inout DataHealth) -> Void) {
        var health = dataHealthBySymbol[symbol] ?? DataHealth(symbol: symbol)
        update(&health)
        dataHealthBySymbol[symbol] = health
    }
    
    // MARK: - Terminal Bootstrap (Refactored w/ TerminalService)
    func bootstrapTerminalData() async {
        guard !isBootstrapping else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }
        
        ArgusLogger.header("📦 Terminal Bootstrap Başlatılıyor (TerminalService)")
        
        await TerminalService.shared.bootstrapTerminal(
            symbols: watchlist,
            batchSize: 10,
            onProgress: { processed, total in
                 Task { await ArgusLogger.shared.log("Bootstrap Progress: \(processed)/\(total)", level: .info, category: "Terminal") }
            },
            onBatchComplete: { results in
                // Gelen veriyi MainActor üzerinde uygula
                for data in results {
                    if let q = data.quote { self.quotes[data.symbol] = q }
                    if let c = data.candles { self.candles[data.symbol] = c }
                    if let f = data.forecast { self.prometheusForecastBySymbol[data.symbol] = f }
                    self.dataHealthBySymbol[data.symbol] = data.health
                }
                self.refreshTerminal()
            }
        )
        
        ArgusLogger.complete("Terminal Bootstrap Tamamlandı")
    }
    
    // MARK: - Portfolio Management Helpers
    
    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        if WatchlistStore.shared.add(upper) {
            Task {
                await fetchSingleSymbolData(symbol: upper)
            }
        }
    }
    
    private func fetchSingleSymbolData(symbol: String) async {
        await MainActor.run { self.isLoading = true }
        
        // TerminalService kullanarak tekil veri çek
        let data = await TerminalService.shared.fetchFullData(for: symbol)
        
        await MainActor.run {
            if let q = data.quote { self.quotes[symbol] = q }
            if let c = data.candles { self.candles[symbol] = c }
            if let f = data.forecast { self.prometheusForecastBySymbol[symbol] = f }
            self.dataHealthBySymbol[symbol] = data.health
            self.isLoading = false
            
            // Trigger check
            Task { await self.checkPlanTriggers() }
        }
    }
    
    func deleteFromWatchlist(at offsets: IndexSet) {
        WatchlistStore.shared.remove(at: offsets)
    }
    

    
    // MARK: - Search
    
    func search(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce (0.5 sn bekle)
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            print("🔍 ViewModel: Searching for '\(query)'")
            
            do {
                let results = try await marketDataProvider.searchSymbols(query: query)
                await MainActor.run {
                    print("🔍 ViewModel: Found \(results.count) results")
                    self.searchResults = results
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    // MARK: - Trading Logic
    
    /// BIST Piyasa Açıklık Kontrolü (Hafta içi 10:00 - 18:10)
    func isBistMarketOpen() -> Bool {
        // Eğer manuel override varsa (test için) buraya eklenebilir.
        let calendar = Calendar.current
        let now = Date()
        
        // TimeZone ayarı (Türkiye Saati - GMT+3)
        // Eğer sunucu saati zaten doğruysa gerek yok, ama garanti olsun
        // Basitlik için yerel saat kullanıyoruz (Kullanıcı TR'de varsayılıyor)
        
        // 1. Gün Kontrolü (Pazar=1, Cmt=7)
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 {
            // print("🛑 BIST Kapalı: Haftasonu")
            return false
        }
        
        // 2. Saat Kontrolü (10:00 - 18:10)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute
        
        let startMinutes = 10 * 60 // 10:00
        let endMinutes = 18 * 60 + 10 // 18:10
        
        if totalMinutes >= startMinutes && totalMinutes < endMinutes {
            return true
        } else {
            // print("🛑 BIST Kapalı: Seans Dışı (\(hour):\(minute))")
            return false
        }
    }
        
    @MainActor
    func buy(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, stopLoss: Double? = nil, takeProfit: Double? = nil, rationale: String? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil) {
        if let trade = ExecutionStateViewModel.shared.buy(
            symbol: symbol,
            quantity: quantity,
            source: source,
            engine: engine,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale,
            decisionTrace: decisionTrace,
            marketSnapshot: marketSnapshot
        ) {
            // ✅ Trigger Smart Plan Generator immediately
            self.triggerSmartPlan(for: trade)
        }
    }
    
    @MainActor
    func sell(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil, reason: String? = nil) {
        ExecutionStateViewModel.shared.sell(
            symbol: symbol,
            quantity: quantity,
            source: source,
            engine: engine,
            reason: reason
        )
    }
    
    
    func closeAllPositions(for symbol: String) {
        let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
        let totalQty = openTrades.reduce(0.0) { $0 + $1.quantity }
        
        if totalQty > 0 {
            sell(symbol: symbol, quantity: totalQty, source: .user)
        }
    }
    

    
    // MARK: - Portfolio Calculations (Legacy - Use PortfolioStore)
    // Removed local calculations (getEquity etc) - use PortfolioStore.shared.totalEquity instead if needed.
    // Keeping only essential bridges if views still bind to them.
    // ... verified that getTotalPortfolioValue is only used by getEquity.
    // If we delete getEquity, we break views using it.
    // Will refactor views later. For now, we keep getEquity but IMPLEMENT it via PortfolioStore to save lines.
    
    func getTotalPortfolioValue() -> Double {
        return getEquity() - balance
    }
    
    func getEquity() -> Double {
        return PortfolioStore.shared.getGlobalEquity(quotes: self.quotes)
    }
    
    /// Global (USD) henüz gerçekleşmemiş kar/zarar
    func getUnrealizedPnL() -> Double {
        return PortfolioStore.shared.getGlobalUnrealizedPnL(quotes: self.quotes)
    }
    
    // MARK: - BIST Helpers (Restored for View Compatibility)
    func getBistPortfolioValue() -> Double {
        return getBistEquity() - PortfolioStore.shared.bistBalance
    }

    func getBistEquity() -> Double {
        return PortfolioStore.shared.getBistEquity(quotes: self.quotes)
    }
    
    func getBistUnrealizedPnL() -> Double {
        return PortfolioStore.shared.getBistUnrealizedPnL(quotes: self.quotes)
    }
    
    func getRealizedPnL() -> Double {
        return PortfolioStore.shared.getRealizedPnL(currency: nil) // Total
    }
    
    // MARK: - Discover & Helpers (Legacy)
    // discoverCategories removed (Logic moved to MarketViewModel / Store)
    
    // Discover sembollerini de yüklemek için yardımcı fonksiyon
    // Discover sembollerini de yüklemek için yardımcı fonksiyon (DEPRECATED - Moved to new implementation below)
    // Removed old loadDiscoverData to avoid redeclaration error.
    

    
    // Eski Composite Score desteği (DiscoverView için mock veya boş)
    // DiscoverView'da 'compositeScores' kullanılıyor.
    // Yeni sistemde 'FundamentalScoreResult' var.
    // DiscoverView'ı kırmamak için boş bir dictionary veya uyumlu bir yapı dönelim.
    // Ancak DiscoverView eski 'CompositeScore' tipini bekliyor olabilir.
    // En iyisi DiscoverView'ı güncellemek ama şimdilik ViewModel'i onaralım.
    // DiscoverView satır 48: if let score = viewModel.compositeScores[symbol]
    // Bu 'score' objesinin 'totalScore' özelliği var.
    // Bizim FundamentalScoreResult da 'totalScore'a sahip.
    // O yüzden tip uyuşmazlığı olabilir ama isim benzerliği kurtarabilir.
    // Swift type-safe olduğu için DiscoverView'ın beklediği tipi bilmem lazım.
    // Muhtemelen eski bir struct vardı.
    // Şimdilik DiscoverView'daki hatayı çözmek için:
    // compositeScores'u FundamentalScoreResult olarak tanımlayalım (Store'dan çekip).
    
    var compositeScores: [String: FundamentalScoreResult] {
        var scores: [String: FundamentalScoreResult] = [:]
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol) {
                scores[symbol] = score
            }
        }
        // Discover'daki semboller watchlist'te olmayabilir, onlar için de store'a bakmak lazım ama
        // store sadece hesaplananları tutuyor.
        return scores
    }
    
    func refreshSymbol(_ symbol: String) {
        Task {
            // SSoT Fetch
            await MarketDataStore.shared.ensureQuote(symbol: symbol)
        }
    }
    
    // PortfolioView için overload
    // PortfolioView için overload
    func sell(tradeId: UUID, currentPrice: Double, quantity: Double? = nil, reason: String? = nil, source: TradeSource = .user) {
        if let index = portfolio.firstIndex(where: { $0.id == tradeId }) {
            let trade = portfolio[index]
            let qtyToSell = quantity ?? trade.quantity // Default to full
            sell(symbol: trade.symbol, quantity: qtyToSell, source: source, reason: reason)
        }
    }
    
    // updateTradeHighWaterMark removed - handled by PortfolioStore handledQuoteUpdates


    // MARK: - Discovery Data Fetching
    
    // MARK: - Market Pulse (Discover)
    
    // refreshMarketPulse moved to TradingViewModel+MarketData.swift
    
    // MARK: - SSoT Binding
    func setupStoreBindings() {
        // Sync Quotes from Store to ViewModel to support legacy Views
        MarketDataStore.shared.$quotes
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] storeQuotes in
                // Efficiently update local cache. 
                // In a pure SSoT app, views would read Store directly.
                // Here we bridge for compatibility.
                // We only copy VALUES to keep struct simple for UI.
                var cleanQuotes: [String: Quote] = [:]
                for (sym, dv) in storeQuotes {
                    if let val = dv.value {
                        cleanQuotes[sym] = val
                    }
                }
                self?.quotes = cleanQuotes
            }
            .store(in: &cancellables)
            

            
        // Sync Portfolio & Balances (SSoT from PortfolioStore)
        PortfolioStore.shared.$trades
            .receive(on: RunLoop.main)
            .assign(to: \.portfolio, on: self)
            .store(in: &cancellables)
            
        PortfolioStore.shared.$globalBalance
            .receive(on: RunLoop.main)
            .assign(to: \.balance, on: self)
            .store(in: &cancellables)
            
        PortfolioStore.shared.$bistBalance
            .receive(on: RunLoop.main)
            .assign(to: \.bistBalance, on: self)
            .store(in: &cancellables)
            
        PortfolioStore.shared.$transactions
            .receive(on: RunLoop.main)
            .assign(to: \.transactionHistory, on: self)
            .store(in: &cancellables)
            
        // Sync Execution State
        ExecutionStateViewModel.shared.$planAlerts
            .receive(on: RunLoop.main)
            .assign(to: \.planAlerts, on: self)
            .store(in: &cancellables)
            
        ExecutionStateViewModel.shared.$agoraSnapshots
            .receive(on: RunLoop.main)
            .assign(to: \.agoraSnapshots, on: self)
            .store(in: &cancellables)
            
        ExecutionStateViewModel.shared.$lastTradeTimes
            .receive(on: RunLoop.main)
            .assign(to: \.lastTradeTimes, on: self)
            .store(in: &cancellables)
            
        // Sync Hermes State (News)
        HermesStateViewModel.shared.$newsBySymbol
            .receive(on: RunLoop.main)
            .assign(to: \.newsBySymbol, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$newsInsightsBySymbol
            .receive(on: RunLoop.main)
            .assign(to: \.newsInsightsBySymbol, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$hermesEventsBySymbol
            .receive(on: RunLoop.main)
            .assign(to: \.hermesEventsBySymbol, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$kulisEventsBySymbol
            .receive(on: RunLoop.main)
            .assign(to: \.kulisEventsBySymbol, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$watchlistNewsInsights
            .receive(on: RunLoop.main)
            .assign(to: \.watchlistNewsInsights, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$generalNewsInsights
            .receive(on: RunLoop.main)
            .assign(to: \.generalNewsInsights, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$isLoadingNews
            .receive(on: RunLoop.main)
            .assign(to: \.isLoadingNews, on: self)
            .store(in: &cancellables)
            
        HermesStateViewModel.shared.$newsErrorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.newsErrorMessage, on: self)
            .store(in: &cancellables)
    }

    
    // RadarStrategy and getRadarPicks moved to TradingViewModel+MarketData.swift
    
    // getHermesHighlights moved to TradingViewModel+Hermes.swift
    
    // MARK: - Discovery Data Loading
    
    // Discovery methods moved to TradingViewModel+MarketData.swift

    // MARK: - News & Insights (Gemini)
    
    @Published var newsBySymbol: [String: [NewsArticle]] = [:]
    @Published var newsInsightsBySymbol: [String: [NewsInsight]] = [:]
    @Published var hermesEventsBySymbol: [String: [HermesEvent]] = [:]
    @Published var kulisEventsBySymbol: [String: [HermesEvent]] = [:]
    
    // Hermes Feeds
    @Published var watchlistNewsInsights: [NewsInsight] = [] // Tab 1: "Takip Listem"
    @Published var generalNewsInsights: [NewsInsight] = []   // Tab 2: "Genel Piyasa"
    
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil
    
    @MainActor
    // Hermes methods moved to TradingViewModel+Hermes.swift
    
    // MARK: - Passive AutoPilot Scanner (NVDA Fix)
    // Scan high-scoring assets in Watchlist/Portfolio that might NOT have news but are Technical/Fundamental screaming buys.
    
    // AutoPilot methods moved to TradingViewModel+AutoPilot.swift
    

    // MARK: - Simulation / Debug
    // simulateOverreactionTest removed (Debug code)
    
    // MARK: - Live Mode (TradingView Bridge) (Experimental)
    
    // MARK: - Live Mode Logic
    
    private func startLiveSession() {
        print("🚀 Argus: Live Session Logic Activated")
        // In a real implementation, this might connect a socket or increase poll rate.
        // Currently, MarketDataStore handles the stream centrally.
    }

    private func stopLiveSession() {
        print("🛑 Argus: Live Session Logic Deactivated")
    }

    
    // Stub for safety if missing in this file (usually exists in AutoPilot section)
    // checkAutoPilotTriggers moved to TradingViewModel+AutoPilot.swift
}

// MARK: - Export Helpers (Argus Enriched)
extension TradingViewModel {
    
    
    func makeDecisionTraceSnapshot(from snapshot: DecisionSnapshot, mode: String) -> DecisionTraceSnapshot {
        return DecisionTraceSnapshot(
            mode: mode,
            overallScore: 50.0, // Simplified mapping
            scores: DecisionTraceSnapshot.ScoresSnapshot(
                atlas: (snapshot.evidence.first(where: { $0.module == "Atlas" })?.confidence ?? 0.0) * 100,
                orion: (snapshot.evidence.first(where: { $0.module == "Orion" })?.confidence ?? 0.0) * 100,
                aether: snapshot.riskContext?.aetherScore ?? 50.0,
                hermes: 50.0,
                demeter: 50.0
            ),
            thresholds: DecisionTraceSnapshot.ThresholdsSnapshot(
                buyOverallMin: 0, sellOverallMin: 0, orionMin: 0, atlasMin: 0, aetherMin: 0, hermesMin: 0
            ),
            reasonsTop3: snapshot.dominantSignals.map {
                DecisionTraceSnapshot.ReasonSnapshot(key: "Signal", value: nil, note: $0)
            },
            guards: DecisionTraceSnapshot.GuardsSnapshot(
                cooldownActive: snapshot.locks.cooldownUntil != nil,
                minHoldBlocked: snapshot.locks.minHoldUntil != nil,
                minMoveBlocked: false,
                costGateBlocked: false,
                rebalanceBandBlocked: false,
                rateLimitBlocked: snapshot.locks.isLocked,
                otherBlocked: snapshot.locks.isLocked
            ),
            blockReason: snapshot.locks.isLocked ? snapshot.reasonOneLiner : nil,
            phoenix: snapshot.phoenix,
            standardizedOutputs: snapshot.standardizedOutputs
        )
    }
    

    
    func makeMarketSnapshot(for symbol: String, currentPrice: Double) -> MarketSnapshot {
        // Simplified Snapshot
        return MarketSnapshot(
            bid: currentPrice, ask: currentPrice, spreadPct: 0.0, atr: nil,
            returns: MarketSnapshot.ReturnsSnapshot(r1m: nil, r5m: nil, r1h: nil, r1d: nil, rangePct: nil, gapPct: nil),
            barsSummary: MarketSnapshot.BarsSummarySnapshot(lookback: 20, high: nil, low: nil, close: currentPrice),
            barTimestamp: Date(), // Current Bar Time
            signalPrice: currentPrice,
            volatilityHint: nil // Can plug in ATR or VIX later
        )
    }
    
    func makeDecisionContext(fromTrace trace: DecisionTraceSnapshot) -> DecisionContext {
        // Map Scores to Votes ( Simplified )
        return DecisionContext(
            decisionId: UUID().uuidString, // Trace doesn't always have ID, gen new
            overallAction: "BUY", // Assumed from context
            dominantSignals: trace.reasonsTop3.compactMap { $0.note },
            conflicts: [],
            moduleVotes: ModuleVotes(
                atlas: ModuleVote(score: trace.scores.atlas ?? 0.0, direction: "BUY", confidence: (trace.scores.atlas ?? 0.0) / 100.0),
                orion: ModuleVote(score: trace.scores.orion ?? 0.0, direction: "BUY", confidence: (trace.scores.orion ?? 0.0) / 100.0),
                aether: ModuleVote(score: trace.scores.aether ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                hermes: ModuleVote(score: trace.scores.hermes ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                chiron: nil
            )
        )
    }

    func makeDecisionContext(from snapshot: DecisionSnapshot) -> DecisionContext {
        // Map Evidence to Votes
        // We iterate evidence and pick matching modules
        let findVote = { (module: String) -> ModuleVote? in
            guard let ev = snapshot.evidence.first(where: { $0.module == module }) else { return nil }
            return ModuleVote(score: ev.confidence, direction: ev.direction, confidence: ev.confidence) // FIXED: direction
        }
        
        let votes = ModuleVotes(
            atlas: findVote("Atlas"),
            orion: findVote("Orion"),
            aether: findVote("Aether"),
            hermes: findVote("Hermes"),
            chiron: findVote("Chiron")
        )
        
        let conflicts = snapshot.conflicts.map { c in
            DecisionConflict(moduleA: c.moduleA, moduleB: c.moduleB, topic: c.topic, severity: 0.5) // FIXED: topic
        }
        
        return DecisionContext(
            decisionId: snapshot.id.uuidString,
            overallAction: snapshot.action.rawValue,
            dominantSignals: snapshot.dominantSignals,
            conflicts: conflicts,
            moduleVotes: votes
        )
    }
    
    func recordAttempt(symbol: String, action: TradeAction, price: Double, decisionTrace: DecisionTraceSnapshot, marketSnapshot: MarketSnapshot, blockReason: String, decisionSnapshot: DecisionSnapshot? = nil) {
        // Try to get DecisionContext if snapshot provided
        var dContext: DecisionContext? = nil
        if let ds = decisionSnapshot {
            dContext = makeDecisionContext(from: ds)
        }
    
        let attempt = Transaction(
            id: UUID(),
            type: .attempt,
            symbol: symbol,
            amount: 0,
            price: price,
            date: Date(),
            fee: 0,
            pnl: nil,
            pnlPercent: nil,
            decisionTrace: decisionTrace,
            marketSnapshot: marketSnapshot,
            positionSnapshot: nil,
            execution: nil,
            outcome: nil,
            schemaVersion: 2,
            source: "SYSTEM_GUARD",
            strategy: "UNKNOWN",
            reasonCode: blockReason,
            decisionContext: dContext,
            cooldownUntil: decisionSnapshot?.locks.cooldownUntil,
            minHoldUntil: decisionSnapshot?.locks.minHoldUntil,
            guardrailHit: true,
            guardrailReason: blockReason
        )
        PortfolioStore.shared.addTransaction(attempt)
    }    

    var bistPortfolio: [Trade] {
        portfolio.filter { $0.currency == .TRY }
    }

    /// BIST portföyündeki SADECE AÇIK pozisyonlar
    var bistOpenPortfolio: [Trade] {
        portfolio.filter { $0.currency == .TRY && $0.isOpen }
    }

    var globalPortfolio: [Trade] {
        portfolio.filter { $0.currency == .USD }
    }

    /// Global portföydeki SADECE AÇIK pozisyonlar
    var globalOpenPortfolio: [Trade] {
        portfolio.filter { $0.currency == .USD && $0.isOpen }
    }
    
    
    // Logları filtrele: Sadece Global semboller (BIST olmayanlar) - Loglarda currency alanı yoksa symbol kontrolüne devam etmek zorunda kalabiliriz ama trade üzerinden gidiyorsak currency kullanırız. ScoutLog içinde currency yok, o yüzden burada symbol check kalmalı ya da ScoutLog güncellenmeli. Ancak ScoutLog trade değil. Burada symbol check mecburen kalacak veya ScoutLog'a da eklemeliyiz. Şimdilik symbol check devam etsin ama SymbolResolver ile destekli.
    var globalScoutLogs: [ScoutLog] {
        scoutLogs.filter { !($0.symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0.symbol)) }
    }

    // MARK: - BIST Tam Reset Functions
    func resetBistPortfolio() {
        PortfolioStore.shared.resetBistPortfolio()
    }

    
    // MARK: - Smart Rebalancing (Portföy Dengesi Analizi - GLOBAL ONLY)
    
    /// Her pozisyonun portföy içindeki yüzde ağırlığı (Sadece Global/USD)
    /// NOT: BIST için ayrı bir allocation hesabı yapılmalı
    var portfolioAllocation: [String: PortfolioAllocationItem] {
        let totalEquity = getEquity() // Sadece Global Equity
        guard totalEquity > 0 else { return [:] }
        
        var allocation: [String: PortfolioAllocationItem] = [:]
        
        for trade in portfolio where trade.isOpen && trade.currency == .USD {
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let positionValue = currentPrice * trade.quantity
            let percentage = (positionValue / totalEquity) * 100
            
            allocation[trade.symbol] = PortfolioAllocationItem(
                symbol: trade.symbol,
                value: positionValue,
                percentage: percentage,
                quantity: trade.quantity
            )
        }
        
        return allocation
    }
    
    /// Konsantrasyon uyarıları (basit string formatında)
    var concentrationWarnings: [String] {
        var warnings: [String] = []
        
        for (symbol, item) in portfolioAllocation {
            // Tek pozisyon > %25 uyarısı
            if item.percentage > 25 {
                let emoji = item.percentage > 35 ? "🚨" : "⚠️"
                warnings.append("\(emoji) \(symbol) portföyün %\(Int(item.percentage))'ini oluşturuyor. Max önerilen: %25")
            }
        }
        
        return warnings.sorted()
    }
    
    /// En büyük pozisyonlar (Top N)
    func topPositions(count: Int = 5) -> [PortfolioAllocationItem] {
        return portfolioAllocation.values.sorted { $0.percentage > $1.percentage }.prefix(count).map { $0 }
    }

}

// MARK: - Portfolio Allocation Models

struct PortfolioAllocationItem: Identifiable {
    var id: String { symbol }
    let symbol: String
    let value: Double
    let percentage: Double
    let quantity: Double
}

// MARK: - Manual Execution Facade (Sanctum Restoration)
extension TradingViewModel {
    func executeBuy(symbol: String, quantity: Double, price: Double) {
        Task { @MainActor in
            self.buy(
                symbol: symbol,
                quantity: quantity,
                source: .user,
                rationale: "Sanctum Alış Emri @ \(price)"
            )
            
            // FAZE 1.2: Alım sonrası otomatik plan oluştur
            Task {
                await PositionPlanStore.shared.syncWithPortfolio(
                    trades: self.portfolio,
                    grandDecisions: self.grandDecisions
                )
            }
        }
    }
    
    func executeSell(symbol: String, quantity: Double, price: Double) {
        Task { @MainActor in
            self.sell(
                symbol: symbol,
                quantity: quantity,
                source: .user,
                reason: "Sanctum Satış Emri @ \(price)"
            )
            
            // FAZE 1.2: Satış sonrası planları güncelle
            Task {
                await PositionPlanStore.shared.syncWithPortfolio(
                    trades: self.portfolio,
                    grandDecisions: self.grandDecisions
                )
            }
        }
    }
}
