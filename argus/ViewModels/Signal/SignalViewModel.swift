import SwiftUI
import Combine

/// Signal Analysis & Trading Signals ViewModel
/// Manages: Orion Analysis, Trading Signals, Technical Patterns, Demeter Scores
@MainActor
final class SignalViewModel: ObservableObject {

    // MARK: - Orion Analysis State
    @Published var isOrionLoading = false
    @Published var prometheusForecastBySymbol: [String: PrometheusForecast] = [:]

    // MARK: - Decision & Signal State
    @Published var searchResults: [SearchResult] = []

    // MARK: - Scout Loop Management
    @Published var scoutCandidates: [String: Double] = [:]
    @Published var isScoutRunning: Bool = false
    private var scoutTimer: Timer?

    // MARK: - Argus Data Loading
    @Published var isLoadingArgus: Bool = false
    @Published var loadedAssetTypes: [String: SafeAssetType] = [:]
    @Published var loadingProgress: Double = 0.0

    // MARK: - Voice Report Generation
    @Published var voiceReports: [String: String] = [:]
    @Published var isGeneratingVoiceReport: Bool = false

    // Scout universe for scanning
    let scoutUniverse = ScoutUniverse.dailyRotation(count: 20)

    // MARK: - Demeter (Sector) State
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter = false
    @Published var activeShocks: [ShockFlag] = []

    // MARK: - Dependencies
    private let analysisViewModel: AnalysisViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(analysisViewModel: AnalysisViewModel? = nil) {
        self.analysisViewModel = analysisViewModel ?? AnalysisViewModel()
        setupBindings()
    }

    // MARK: - Bindings
    private func setupBindings() {
        analysisViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Accessors (Facade to AnalysisViewModel)

    var orionAnalysis: [String: MultiTimeframeAnalysis] {
        analysisViewModel.orionAnalysis
    }

    var patterns: [String: [OrionChartPattern]] {
        analysisViewModel.patterns
    }

    var grandDecisions: [String: ArgusGrandDecision] {
        get { analysisViewModel.grandDecisions }
        set { analysisViewModel.grandDecisions = newValue }
    }

    var chimeraSignals: [String: ChimeraSignal] {
        get { analysisViewModel.chimeraSignals }
        set { analysisViewModel.chimeraSignals = newValue }
    }

    var orionScores: [String: OrionScoreResult] {
        analysisViewModel.orionScores
    }

    // MARK: - Signal Operations

    func ensureOrionAnalysis(for symbol: String) async {
        await OrionStore.shared.ensureAnalysis(for: symbol)
    }

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
        guard let sector = SectorMap.getSector(for: symbol) else { return nil }
        return demeterScores.first(where: { $0.sector == sector })
    }

    // MARK: - Scout Loop Management

    func startScoutLoop() {
        guard !isScoutRunning else { return }
        isScoutRunning = true

        // Run immediately
        Task {
            await runScout()
        }

        // Then every 5 minutes
        scoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.runScout()
            }
        }
    }

    func stopScoutLoop() {
        scoutTimer?.invalidate()
        scoutTimer = nil
        isScoutRunning = false
    }

    func runScout() async {
        // 1. Refresh market pulse
        let marketVM = MarketViewModel()
        await marketVM.refreshMarketPulse()

        // 2. Gather symbols from multiple sources
        let discoverySymbols = (marketVM.topGainers + marketVM.topLosers + marketVM.mostActive)
            .compactMap { $0.symbol }
        let universeSymbols = ScoutUniverse.dailyRotation(count: 20)
        let allSymbols = Array(Set(marketVM.watchlist + discoverySymbols + universeSymbols))

        guard !allSymbols.isEmpty else { return }

        // 3. Scout for opportunities
        let candidates = await ArgusScoutService.shared.scoutOpportunities(
            watchlist: allSymbols,
            currentQuotes: marketVM.quotes
        )

        // 4. Store results and handover to execution
        await MainActor.run {
            self.scoutCandidates = Dictionary(uniqueKeysWithValues: candidates)
        }

        if !candidates.isEmpty {
            // Handover to ExecutionStateViewModel if available
            for (symbol, score) in candidates {
                await processScoutCandidate(symbol: symbol, score: score)
            }
        }
    }

    private func processScoutCandidate(symbol: String, score: Double) async {
        // This would delegate to ExecutionStateViewModel for high-conviction trading
        // For now, just log
        print("🔭 Scout found \(symbol) with score \(score)")
    }

    // MARK: - Argus Data Loading

    @MainActor
    func loadArgusData(for symbol: String) async {
        isLoadingArgus = true
        defer { isLoadingArgus = false }

        // 1. Detect asset type
        let assetType = await detectAssetType(for: symbol)

        // 2. Load candles if missing
        let marketVM = MarketViewModel()
        if marketVM.candles[symbol]?.isEmpty ?? true {
            await marketVM.loadCandles(for: symbol, timeframe: "1D")
        }

        // 3. Load Orion score
        if orionScores[symbol] == nil {
            await loadOrionScore(for: symbol, assetType: assetType)
        }

        // 4. Load fundamental score (for stocks/ETFs only)
        if assetType == .stock || assetType == .etf {
            if FundamentalScoreStore.shared.getScore(for: symbol) == nil {
                _ = await calculateFundamentalScore(for: symbol, assetType: assetType)
            }
        }

        // 5. Update asset type cache
        await updateAssetType(for: symbol, to: assetType)
    }

    private func detectAssetType(for symbol: String) async -> SafeAssetType {
        // Check cache first
        if let cached = loadedAssetTypes[symbol] {
            return cached
        }

        // Check if ETF
        let isEtf = await checkIsEtf(symbol: symbol)
        if isEtf { return .etf }

        // Default to stock for US symbols
        return .stock
    }

    private func checkIsEtf(symbol: String) async -> Bool {
        let marketVM = MarketViewModel()
        return marketVM.isETF(symbol: symbol)
    }

    private func updateAssetType(for symbol: String, to type: SafeAssetType) async {
        await MainActor.run {
            self.loadedAssetTypes[symbol] = type
        }
    }

    func calculateFundamentalScore(for symbol: String, assetType: SafeAssetType = .stock) async -> FundamentalScoreResult? {
        // Fetch financials data for the symbol
        if let financialsData = FundamentalScoreStore.shared.getRawData(for: symbol) {
            // Calculate score using FundamentalScoreEngine
            let score = FundamentalScoreEngine.shared.calculate(data: financialsData)
            if let score = score {
                FundamentalScoreStore.shared.setScore(score)
            }
            return score
        }
        return nil
    }

    func loadOrionScore(for symbol: String, assetType: SafeAssetType = .stock) async {
        // Load via OrionStore
        await OrionStore.shared.ensureAnalysis(for: symbol)
    }

    // MARK: - Voice Report Generation

    @MainActor
    func generateVoiceReport(for symbol: String, tradeId: UUID? = nil) async {
        isGeneratingVoiceReport = true
        defer { isGeneratingVoiceReport = false }

        do {
            let marketVM = MarketViewModel()
            let quote = marketVM.quotes[symbol]
            let atlas = FundamentalScoreStore.shared.getScore(for: symbol)
            let orion = orionScores[symbol]

            var reportParts: [String] = []

            if let q = quote {
                reportParts.append("📊 \(symbol): \(q.c) - \(q.dp ?? 0)%")
            }

            if let a = atlas {
                reportParts.append("📈 Atlas: \(a.totalScore)")
            }

            if let o = orion {
                reportParts.append("🔮 Orion: \(o.score)")
            }

            let report = reportParts.joined(separator: " | ")
            self.voiceReports[symbol] = report

            print("🎙️ Voice Report for \(symbol): \(report)")
        } catch {
            print("⚠️ Voice report generation failed: \(error)")
        }
    }

    // MARK: - Specialized Analysis

    func loadSarTsiLab(symbol: String) async {
        // SAR + TSI technical analysis
        let marketVM = MarketViewModel()
        if let candles = marketVM.candles[symbol] {
            print("📊 SAR TSI Lab analysis for \(symbol): \(candles.count) candles")
        }
    }

    func analyzeOverreaction(symbol: String, atlas: Double?, aether: Double?) {
        // Check if stock is oversold (overreaction)
        let marketVM = MarketViewModel()
        if let quote = marketVM.quotes[symbol] {
            let isOversold = (quote.percentChange ?? 0) < -5.0 && (atlas ?? 0) > 75
            if isOversold {
                print("⚠️ Overreaction detected in \(symbol)")
            }
        }
    }

    func loadEtfData(for symbol: String) async {
        // Load ETF composition and sector breakdown
        print("📦 Loading ETF data for \(symbol)")
    }

    func hydrateAtlas() async {
        // Pre-load fundamental data for watchlist
        let marketVM = MarketViewModel()
        for symbol in marketVM.watchlist.prefix(10) {
            _ = await calculateFundamentalScore(for: symbol, assetType: .stock)
        }
    }

    func generateAISignals() async {
        // Generate AI-powered trading signals
        print("🤖 Generating AI signals...")
    }
}
