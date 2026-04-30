import Foundation
import Combine
import SwiftUI

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  LEGACY COMPATIBILITY FACADE — MIGRATION IN PROGRESS                   ║
// ║                                                                          ║
// ║  TradingViewModel artık gerçek state sahibi DEĞİL.                      ║
// ║  Tüm state AppStateCoordinator + domain stores'ta yaşıyor.              ║
// ║                                                                          ║
// ║  YENİ KOD YAZARKEN:                                                      ║
// ║  • State okuma  → AppStateCoordinator.shared.X                          ║
// ║  • State yazma  → ilgili store (PortfolioStore, ExecutionStateVM, vs.)  ║
// ║  • @EnvironmentObject olarak coordinator'ı kullan                        ║
// ║                                                                          ║
// ║  SORUMLULUK HARİTASI:                                                   ║
// ║  Quotes/Candles   → MarketDataStore.shared                              ║
// ║  Portfolio/Trades → PortfolioStore.shared                               ║
// ║  Signals/Orion    → SignalStateViewModel.shared                         ║
// ║  Execution/Alerts → ExecutionStateViewModel.shared                      ║
// ║  Watchlist        → WatchlistViewModel.shared                           ║
// ║  Koordinasyon     → AppStateCoordinator.shared (TEK GİRİŞ NOKTASI)     ║
// ║                                                                          ║
// ║  BU DOSYAYA YENİ @Published EKLEME. AppStateCoordinator'a ekle.        ║
// ╚══════════════════════════════════════════════════════════════════════════╝

@MainActor
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
        set { market.quotes = newValue }
    }
    var candles: [String: [Candle]] {
        get { market.candles }
        set { market.candles = newValue }
    }
    
    // MARK: - Explicit Update Functions (Side-effect free setters)
    /// Fiyat güncellemelerini hem market'e hem de plan store'a bildirir
    func updateQuotesAndNotifyPlans(_ newQuotes: [String: Quote]) {
        self.quotes = newQuotes
        PositionPlanStore.shared.updatePriceQuotes(newQuotes)
    }
    
    /// Mum verilerini hem market'e hem de plan store'a bildirir
    func updateCandlesAndNotifyPlans(_ newCandles: [String: [Candle]]) {
        self.candles = newCandles
        PositionPlanStore.shared.updateCandles(newCandles)
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

    // Scout Loop Facade
    var isScoutRunning: Bool {
        SignalViewModel.shared.isScoutRunning
    }

    var scoutCandidates: [String: Double] {
        SignalViewModel.shared.scoutCandidates
    }

    // Terminal Optimized Data Source
    // MIRROR: AppStateCoordinator.shared.$terminalItems
    @Published var terminalItems: [TerminalItem] = []

    /// Per-symbol input signature for incremental update.
    /// Eğer bir sembolün tüm input'ları aynıysa, o item'a `getFundamentalScore`,
    /// `ChimeraSynergyEngine.fuse` ve TerminalItem allocation'ı yapmadan direkt
    /// önceki item'ı kullanırız.
    private struct TerminalInputSignature: Equatable {
        let price: Double
        let percentChange: Double?
        let orionScore: Double?
        let councilScore: Double?
        let action: ArgusAction
        let hermesImpact: Double?
        let dataQuality: Int
        let regime: MarketRegime
        let forecastTrend: PrometheusTrend?
    }
    private var lastTerminalSignatures: [String: TerminalInputSignature] = [:]

    func refreshTerminal() {
        let regime = market.marketRegime // Use market's regime

        // ✅ PERFORMANCE FIX: Cache computed dictionaries to avoid O(N²) proxy lookups
        // Without this: 50 symbols × 2 proxy layers × 3 dictionaries = 300 lookups
        // With this: 3 dictionary copies = O(1) lookup per symbol
        let cachedQuotes = quotes
        let cachedDecisions = grandDecisions
        let cachedOrionScores = orionScores
        let cachedNewsInsights = newsInsightsBySymbol
        let cachedDataHealth = dataHealthBySymbol
        let cachedForecasts = prometheusForecastBySymbol

        // INCREMENTAL UPDATE: önceki TerminalItem'ları sembol→item map'ine çıkar.
        // Watchlist'teki sembollerden input signature'ı değişmeyenler için
        // ChimeraSynergyEngine.fuse + getFundamentalScore çağrılarını atlayıp
        // mevcut item'ı yeniden kullanırız. Önceden 50 sembolde her quote
        // güncellemesinde 50× chimera fuse + 50× fundamental score çağrılıyordu.
        let existingByID: [String: TerminalItem] = Dictionary(
            uniqueKeysWithValues: terminalItems.map { ($0.id, $0) }
        )

        var didChange = false
        let newItems = watchlist.map { symbol -> TerminalItem in
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            let quote = cachedQuotes[symbol]
            let decision = cachedDecisions[symbol]
            let orion = cachedOrionScores[symbol]
            let hermesImpact = cachedNewsInsights[symbol]?.first?.impactScore
            let dataQuality = cachedDataHealth[symbol]?.qualityScore ?? 0
            let forecast = cachedForecasts[symbol]

            let signature = TerminalInputSignature(
                price: quote?.currentPrice ?? 0,
                percentChange: quote?.percentChange,
                orionScore: orion?.score,
                councilScore: decision?.confidence,
                action: decision?.action ?? .neutral,
                hermesImpact: hermesImpact,
                dataQuality: dataQuality,
                regime: regime,
                forecastTrend: forecast?.trend
            )

            // Hızlı yol: signature aynı ve mevcut item varsa, yeniden hesaplama yapma
            if lastTerminalSignatures[symbol] == signature,
               let existing = existingByID[symbol] {
                return existing
            }

            // Yavaş yol: signature değişti veya ilk kez görülüyor
            didChange = true
            lastTerminalSignatures[symbol] = signature

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
                atlasScore: fundScore,
                councilScore: decision?.confidence,
                action: decision?.action ?? .neutral,
                dataQuality: dataQuality,
                forecast: forecast,
                chimeraSignal: chimeraResult.signals.first
            )
        }

        // Watchlist'ten çıkarılan sembolleri signature cache'den temizle
        let watchlistSet = Set(watchlist)
        if lastTerminalSignatures.count > watchlistSet.count {
            lastTerminalSignatures = lastTerminalSignatures.filter { watchlistSet.contains($0.key) }
        }

        // Sıra/içerik gerçekten değiştiyse yayınla
        if didChange || newItems.count != terminalItems.count {
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
    var macroRefreshTask: Task<Void, Never>?
    
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
    // MIRROR: AppStateCoordinator.shared.$lastAction (kaynak: ExecutionStateViewModel)
    @Published var lastAction: String = ""

    
    // PERFORMANCE: PortfolioStore'daki cache'lenmiş @Published alt kümelere forward et.
    // Önceden her erişimde portfolio.filter çalışıyordu; PortfolioView, DailyAgendaView,
    // PortfolioPlanBoard, TradeBrainStatusBand, BistMarketView gibi view'larda body
    // içinde 6+ noktada çağrıldığı için her render'da redundant filter maliyeti vardı.
    // Şimdi tek seviyeli forward — cache PortfolioStore.trades.didSet ile bir kez güncellenir.
    //
    // NOT: globalPortfolio (USD, açık+kapalı tümü) için cache yok; çoğu çağrı ya
    // .filter { $0.isOpen } ile birleşiyor ya da kapalı işlemleri de istiyor.
    // En sık kullanılan globalOpenTradesCache ve bistOpenTradesCache. Bunlardaki
    // O(N) filter kazancı en yüksek.
    var globalPortfolio: [Trade] { portfolio.filter { $0.currency == .USD } }
    var bistPortfolio: [Trade] { portfolio.filter { $0.currency == .TRY } }
    var bistOpenPortfolio: [Trade] { PortfolioStore.shared.bistOpenTradesCache }
    var globalScoutLogs: [ScoutLog] { scoutLogs.filter { !$0.symbol.contains(".E") } }

    // Navigation State
    @Published var selectedSymbolForDetail: String? = nil
    
    func addToWatchlist(symbol: String) {
        WatchlistStore.shared.add(symbol)
    }
    @Published var transactionHistory: [Transaction] = []
    
    // MARK: - Smart Plan & Trade Brain
    
    /// Smart Plan tetikle — karar yoksa veya NEUTRAL'sa plan üretilmez.
    ///
    /// O4: Eskiden `self.grandDecisions[symbol] ?? createDefaultDecision(for:)`
    /// yoluyla sentetik `.accumulate` karar üretilip plan yine yapılıyordu.
    /// Kullanıcı "plan oluştu" yanılsaması alıyor, ama altında gerçek sinyal yok.
    /// Artık karar yoksa kullanıcıya sessizce işlem yapmıyoruz — log bırakıp çıkıyoruz.
    /// UI tarafı "karar bekleniyor" state'i gösterebilir (ileride).
    func triggerSmartPlan(for trade: Trade) {
        Task {
            guard let decision = self.grandDecisions[trade.symbol] else {
                print("⚠️ Smart Plan atlandı: \(trade.symbol) için grand decision yok — sinyal bekleniyor.")
                return
            }
            guard let plan = PositionPlanStore.shared.createPlan(for: trade, decision: decision) else {
                print("⚠️ Smart Plan oluşturulmadı: \(trade.symbol) — karar NEUTRAL.")
                return
            }

            await MainActor.run {
                self.generatedSmartPlan = plan
            }

            print("✅ Smart Plan oluşturuldu ve kaydedildi: \(trade.symbol)")
        }
    }
    // AutoPilot & Scout delegated to AutoPilotStore
    var scoutingCandidates: [TradeSignal] { AutoPilotStore.shared.scoutingCandidates }
    var scoutLogs: [ScoutLog] { AutoPilotStore.shared.scoutLogs }
    
    // MIRROR: AppStateCoordinator.shared.$planAlerts (kaynak: ExecutionStateViewModel)
    @Published var planAlerts: [TradeBrainAlert] = []

    // MIRROR: AppStateCoordinator.shared.$agoraSnapshots (kaynak: ExecutionStateViewModel)
    @Published var agoraSnapshots: [DecisionSnapshot] = []

    // MIRROR: AppStateCoordinator.shared.$lastTradeTimes (kaynak: ExecutionStateViewModel)
    @Published var lastTradeTimes: [String: Date] = [:]

    // MIRROR: AppStateCoordinator.shared.$universeCache
    @Published var universeCache: [String: UniverseItem] = [:]

    @MainActor
    func fetchUniverseDetails(for symbol: String) async {
        if let item = UniverseEngine.shared.universe[symbol] {
            // Coordinator'a yaz — mirror subscription aşağıdaki binding aracılığıyla viewModel'e döner
            AppStateCoordinator.shared.universeCache[symbol] = item
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
    
    // Hermes / News State (Delegated to HermesNewsViewModel)
    private var hermesVM: HermesNewsViewModel { HermesNewsViewModel.shared }

    var hermesSummaries: [String: [HermesSummary]] {
        get { hermesVM.hermesSummaries }
        set { hermesVM.hermesSummaries = newValue }
    }
    var hermesMode: HermesMode {
        get { hermesVM.hermesMode }
        set { hermesVM.hermesMode = newValue }
    } 
    
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
    private var hasCleanedUp = false

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

        // Keep cockpit rows in sync with live quotes/decisions/quality
        setupTerminalObservation()
        
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
        // MARK: - WatchlistStore Bridge (ONLY specific data, not broadcast)
        WatchlistStore.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.watchlist = items
                self?.refreshTerminal()
            }
            .store(in: &cancellables)

        // ❌ REMOVED: 7 objectWillChange.send() broadcast chains
        // ✅ NEW: Views observe sub-ViewModels directly (@ObservedObject)
        //
        // Instead of broadcasting ALL changes through TradingViewModel,
        // Views now observe specific ViewModels:
        // - market: MarketViewModel (quotes, candles)
        // - risk: RiskViewModel (portfolio, balance)
        // - analysis: AnalysisViewModel (signals, reports)
        // - DiagnosticsViewModel.shared (data health)
        // - SignalStateViewModel.shared (argus decisions)
        // - ExecutionStateViewModel.shared (autopilot state)
        //
        // This eliminates Observer Hell:
        // - No cascading objectWillChange.send()
        // - Granular updates (only affected views re-render)
        // - 10x better performance for quote/candle updates
    }

    private func setupTerminalObservation() {
        market.$quotes
            .throttle(for: .seconds(0.7), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.refreshTerminal()
            }
            .store(in: &cancellables)

        SignalStateViewModel.shared.$grandDecisions
            .throttle(for: .seconds(0.7), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.refreshTerminal()
            }
            .store(in: &cancellables)

        DiagnosticsViewModel.shared.$dataHealthBySymbol
            .throttle(for: .seconds(1.0), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.refreshTerminal()
            }
            .store(in: &cancellables)
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
                self?.balance = newBalance
            }
            .store(in: &cancellables)
        
        // BIST Balance senkronizasyonu
        PortfolioStore.shared.$bistBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                self?.bistBalance = newBalance
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
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        // Stop AutoPilot loop (idempotent)
        Task {
            await MainActor.run {
                AutoPilotStore.shared.stopAutoPilotLoop()
            }
        }
        // Cancel Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        print("🧹 TradingViewModel deinit - resources cleaned up")
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

    // Argus Lab sistemi kaldırıldı (2026-04-21)

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
    
    /// BIST Piyasa Açıklık Kontrolü — Istanbul TZ + resmi tatil listesi.
    ///
    /// O3: Eskiden `Calendar.current` üzerinden cihaz saat dilimiyle
    /// hesaplanıyordu — yurt dışı kullanıcılarında hatalı "açık" üretiyor,
    /// tatil kontrolü de yoktu. Artık tek doğruluk kaynağı MarketStatusService:
    /// Istanbul TimeZone ile saat + hafta içi + sabit tarihli resmi tatiller.
    func isBistMarketOpen() -> Bool {
        MarketStatusService.shared.isBistOpen()
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
    
    func getRealizedPnL(market: TradeMarket? = nil) -> Double {
        let currency: Currency?
        if let m = market {
            currency = (m == .bist) ? .TRY : .USD
        } else {
            currency = nil
        }
        return PortfolioStore.shared.getRealizedPnL(currency: currency)
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
    

    
    // RadarStrategy and getRadarPicks moved to TradingViewModel+MarketData.swift
    
    // getHermesHighlights moved to TradingViewModel+Hermes.swift
    
    // MARK: - Discovery Data Loading
    
    // Discovery methods moved to TradingViewModel+MarketData.swift

    // MARK: - News & Insights (Delegated to HermesNewsViewModel)

    var newsBySymbol: [String: [NewsArticle]] {
        get { hermesVM.newsBySymbol }
        set { hermesVM.newsBySymbol = newValue }
    }
    var newsInsightsBySymbol: [String: [NewsInsight]] {
        get { hermesVM.newsInsightsBySymbol }
        set { hermesVM.newsInsightsBySymbol = newValue }
    }
    var hermesEventsBySymbol: [String: [HermesEvent]] {
        get { hermesVM.hermesEventsBySymbol }
        set { hermesVM.hermesEventsBySymbol = newValue }
    }
    var kulisEventsBySymbol: [String: [HermesEvent]] {
        get { hermesVM.kulisEventsBySymbol }
        set { hermesVM.kulisEventsBySymbol = newValue }
    }

    // Hermes Feeds
    var watchlistNewsInsights: [NewsInsight] {
        get { hermesVM.watchlistNewsInsights }
        set { hermesVM.watchlistNewsInsights = newValue }
    }
    var generalNewsInsights: [NewsInsight] {
        get { hermesVM.generalNewsInsights }
        set { hermesVM.generalNewsInsights = newValue }
    }

    var isLoadingNews: Bool {
        get { hermesVM.isLoadingNews }
        set { hermesVM.isLoadingNews = newValue }
    }
    var newsErrorMessage: String? {
        get { hermesVM.newsErrorMessage }
        set { hermesVM.newsErrorMessage = newValue }
    }

    // Hermes methods delegated to HermesNewsViewModel - see TradingViewModel+Hermes.swift
    
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
