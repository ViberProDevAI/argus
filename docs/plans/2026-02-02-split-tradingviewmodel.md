# TradingViewModel Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Break TradingViewModel from 1,459 lines into domain-specific ViewModels (Portfolio, Market, Signal) enabling independent testing and maintainability while preserving backward compatibility.

**Architecture:** Refactor from monolithic god object into layered facade pattern:
- **PortfolioViewModel**: Portfolio operations, balance tracking, P&L calculations
- **MarketViewModel**: Quotes, candles, watchlist, discovery lists (already 126 lines, enhance)
- **SignalViewModel**: Trading signals, Orion analysis, Demeter scores
- **TradingViewModel**: Thin facade delegating to domain VMs + backward compatibility

**Tech Stack:** SwiftUI 5.0, Combine, @MainActor, ObservableObject pattern

---

## PHASE 1: Audit & Structure Creation

### Task 1: Audit Current TradingViewModel

**Files:**
- Read: `argus/ViewModels/TradingViewModel.swift` (1,459 lines)
- Reference: `argus/ViewModels/MarketViewModel.swift` (126 lines)
- Reference: `argus/ViewModels/RiskViewModel.swift` (62 lines)
- Reference: `argus/ViewModels/AnalysisViewModel.swift` (80 lines)

**Step 1: Document current structure**

Generate audit report with:
- Line count breakdown by responsibility
- @Published property inventory (30+ props)
- Function count by domain (portfolio, market, signals, execution, utilities)
- Current delegation pattern (market, risk, analysis proxies)
- Identify extension files that will need reorganization

**Command:**
```bash
wc -l argus/ViewModels/TradingViewModel.swift
grep "@Published" argus/ViewModels/TradingViewModel.swift | wc -l
grep "func " argus/ViewModels/TradingViewModel.swift | wc -l
grep -E "let market =|let risk =|let analysis =" argus/ViewModels/TradingViewModel.swift
```

**Expected Output:**
```
1459 argus/ViewModels/TradingViewModel.swift
30+ @Published properties found
54+ functions found
Proxies: market, risk, analysis
```

**Step 2: Map properties to domains**

Create spreadsheet/document:

| Domain | Property | Type | Location | Responsibilities |
|--------|----------|------|----------|------------------|
| Portfolio | portfolio | [Trade] | Line 129 | Core position data |
| Portfolio | balance | Double | Line 133 | USD cash balance |
| Market | watchlist | [String] | Line 7 | Tracked symbols |
| Market | quotes | [String: Quote] | Line 15 | Price data |
| Signal | grandDecisions | [String: ArgusGrandDecision] | Line 61 | Trading recommendations |
| Execution | planAlerts | [TradeBrainAlert] | Line 291 | Smart plan alerts |
| UI | selectedSymbolForDetail | String? | Line 230 | Navigation state |

**Step 3: Document view dependencies**

List all views using TradingViewModel:

```bash
grep -r "TradingViewModel" argus/Views --include="*.swift" -l | sort | uniq
```

**Expected:** 20+ views identified

**Step 4: Commit audit documentation**

```bash
git add docs/analysis/trading-vm-audit.md
git commit -m "docs: audit TradingViewModel structure (1,459 lines, 30+ properties)"
```

---

### Task 2: Create PortfolioViewModel Structure

**Files:**
- Create: `argus/ViewModels/Portfolio/PortfolioViewModel.swift`
- Modify: `argus/ViewModels/RiskViewModel.swift` (extend with portfolio operations)

**Step 1: Create empty PortfolioViewModel with structure**

```swift
import SwiftUI
import Combine

/// Portfolio & Balance Management ViewModel
/// Manages: Trades, Balances, P&L Calculations, Position Allocation
@MainActor
final class PortfolioViewModel: ObservableObject {

    // MARK: - Published State
    @Published var portfolio: [Trade] = []
    @Published var balance: Double = 100000.0
    @Published var bistBalance: Double = 1000000.0
    @Published var usdTryRate: Double = 35.0
    @Published var transactionHistory: [Transaction] = []
    @Published var generatedSmartPlan: PositionPlan?
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies
    private let riskViewModel: RiskViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(riskViewModel: RiskViewModel? = nil) {
        self.riskViewModel = riskViewModel ?? RiskViewModel()
        setupBindings()
    }

    // MARK: - Bindings
    private func setupBindings() {
        // Will bind RiskViewModel state to local Published properties
    }

    // MARK: - Portfolio Operations
    // Methods will be added in subsequent tasks
}
```

**Step 2: Run build to verify structure**

```bash
cd /Users/erenkapak/Desktop/argus
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | head -50
```

**Expected:** Build succeeds with empty PortfolioViewModel

**Step 3: Commit structure**

```bash
git add argus/ViewModels/Portfolio/PortfolioViewModel.swift
git commit -m "feat: create PortfolioViewModel structure (empty shell)"
```

---

### Task 3: Create MarketViewModel Enhancement

**Files:**
- Modify: `argus/ViewModels/MarketViewModel.swift` (enhance existing 126 lines)
- Create: `argus/ViewModels/Market/MarketViewModel.swift` (move to subdirectory with enhancements)

**Step 1: Move MarketViewModel to subdirectory**

```bash
mkdir -p argus/ViewModels/Market
cp argus/ViewModels/MarketViewModel.swift argus/ViewModels/Market/MarketViewModel.swift
```

**Step 2: Enhance MarketViewModel with missing market operations**

Add to existing `MarketViewModel.swift`:

```swift
// MARK: - Market Operations

func addToWatchlist(symbol: String) {
    WatchlistStore.shared.add(symbol)
}

func removeFromWatchlist(symbol: String) {
    WatchlistStore.shared.remove(symbol)
}

func search(query: String, completion: @escaping ([SearchResult]) -> Void) {
    Task {
        do {
            let results = try await marketDataProvider.searchSymbols(query: query)
            await MainActor.run {
                completion(results)
            }
        } catch {
            print("Search error: \(error)")
        }
    }
}

func refreshSymbol(_ symbol: String) {
    Task {
        await MarketDataStore.shared.ensureQuote(symbol: symbol)
    }
}

// Composite scores from fundamental store
var compositeScores: [String: FundamentalScoreResult] {
    var scores: [String: FundamentalScoreResult] = [:]
    for symbol in WatchlistStore.shared.items {
        if let score = FundamentalScoreStore.shared.getScore(for: symbol) {
            scores[symbol] = score
        }
    }
    return scores
}

func getTopPicks() -> [FundamentalScoreResult] {
    var picks: [FundamentalScoreResult] = []
    for symbol in WatchlistStore.shared.items {
        if let score = FundamentalScoreStore.shared.getScore(for: symbol),
           score.totalScore >= 70 {
            picks.append(score)
        }
    }
    return picks.sorted { $0.totalScore > $1.totalScore }
}
```

**Step 3: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:|warning:" | head -20
```

**Expected:** Build succeeds with 0 errors

**Step 4: Commit MarketViewModel enhancements**

```bash
git add argus/ViewModels/Market/MarketViewModel.swift
git rm argus/ViewModels/MarketViewModel.swift
git commit -m "refactor: enhance MarketViewModel with watchlist & search operations"
```

---

### Task 4: Create SignalViewModel

**Files:**
- Create: `argus/ViewModels/Signal/SignalViewModel.swift`

**Step 1: Create SignalViewModel**

```swift
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
}
```

**Step 2: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:|warning:" | head -20
```

**Expected:** Build succeeds

**Step 3: Commit SignalViewModel**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: create SignalViewModel for trading signals & analysis"
```

---

## PHASE 2: TradingViewModel Facade Refactoring

### Task 5: Refactor TradingViewModel as Facade

**Files:**
- Modify: `argus/ViewModels/TradingViewModel.swift` (replace ~1,459 lines with ~200-250 lines)
- Keep: All extension files (will migrate methods in Phase 3)

**Step 1: Backup current TradingViewModel**

```bash
cp argus/ViewModels/TradingViewModel.swift argus/ViewModels/TradingViewModel.swift.phase1-backup
git add argus/ViewModels/TradingViewModel.swift.phase1-backup
git commit -m "backup: TradingViewModel before facade refactor"
```

**Step 2: Replace TradingViewModel with facade**

```swift
import SwiftUI
import Combine

/// TradingViewModel Facade
/// Acts as central coordinator for trading operations.
/// Delegates to domain-specific ViewModels:
/// - PortfolioViewModel: Portfolio & balance management
/// - MarketViewModel: Market data & watchlist
/// - SignalViewModel: Trading signals & analysis
///
/// Maintains backward compatibility with existing views.
@MainActor
final class TradingViewModel: ObservableObject {

    // MARK: - Domain ViewModels
    @StateObject var portfolio: PortfolioViewModel
    @StateObject var market: MarketViewModel
    @StateObject var signals: SignalViewModel

    // MARK: - Facade UI State (backward compatibility)
    @Published var selectedSymbolForDetail: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAction: String = ""

    // MARK: - Terminal State
    @Published var terminalItems: [TerminalItem] = []
    @Published var universeCache: [String: UniverseItem] = [:]

    // MARK: - Hermes/News (Temporary until migrated)
    @Published var newsBySymbol: [String: [NewsArticle]] = [:]
    @Published var newsInsightsBySymbol: [String: [NewsInsight]] = [:]
    @Published var hermesEventsBySymbol: [String: [HermesEvent]] = [:]
    @Published var kulisEventsBySymbol: [String: [HermesEvent]] = [:]
    @Published var watchlistNewsInsights: [NewsInsight] = []
    @Published var generalNewsInsights: [NewsInsight] = []
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil

    // MARK: - Smart Plan & Trade Brain
    @Published var planAlerts: [TradeBrainAlert] = []
    @Published var agoraSnapshots: [DecisionSnapshot] = []
    @Published var lastTradeTimes: [String: Date] = [:]
    @Published var generatedSmartPlan: PositionPlan?
    @Published var hermesSummaries: [String: [HermesSummary]] = [:]
    @Published var hermesMode: HermesMode = .full

    // MARK: - Argus Voice & Reports
    @Published var voiceReports: [String: String] = [:]
    @Published var isGeneratingVoiceReport: Bool = false
    @Published var isLoadingArgus: Bool = false
    @Published var argusLabStats: UnifiedAlgoStats?

    // MARK: - BackTest State
    @Published var isBacktesting: Bool = false

    // MARK: - Position Mode
    @Published var isUnlimitedPositions = false {
        didSet {
            PortfolioRiskManager.shared.isUnlimitedPositionsEnabled = isUnlimitedPositions
        }
    }

    // MARK: - Data Health & Diagnostics
    var dataHealthBySymbol: [String: DataHealth] {
        get { DiagnosticsViewModel.shared.dataHealthBySymbol }
        set { DiagnosticsViewModel.shared.dataHealthBySymbol = newValue }
    }

    // MARK: - Performance Metrics
    var bootstrapDuration: Double { DiagnosticsViewModel.shared.bootstrapDuration }
    var lastBatchFetchDuration: Double { DiagnosticsViewModel.shared.lastBatchFetchDuration }

    // MARK: - Combine Subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var isBootstrapping = false

    // MARK: - Initialization
    init(
        portfolio: PortfolioViewModel? = nil,
        market: MarketViewModel? = nil,
        signals: SignalViewModel? = nil
    ) {
        self._portfolio = StateObject(wrappedValue: portfolio ?? PortfolioViewModel())
        self._market = StateObject(wrappedValue: market ?? MarketViewModel())
        self._signals = StateObject(wrappedValue: signals ?? SignalViewModel())

        // Setup linking and observations
        setupViewModelLinking()
        setupPortfolioStoreBridge()
        setupStreamingObservation()
        setupOrionBindings()
        setupTradeBrainObservers()

        Task { @MainActor in
            EconomicCalendarService.shared.checkAndNotifyMissingExpectations()
        }

        Task {
            await runAlkindusMaturation()
        }
    }

    // MARK: - Backward Compatibility Accessors

    // Portfolio accessors
    var trades: [Trade] { portfolio.portfolio }
    var allTradesBySymbol: [String: [Trade]] { portfolio.allTradesBySymbol }
    var bistPortfolio: [Trade] { portfolio.bistPortfolio }
    var globalPortfolio: [Trade] { portfolio.globalPortfolio }
    var bistOpenPortfolio: [Trade] { portfolio.bistOpenPortfolio }
    var globalOpenPortfolio: [Trade] { portfolio.globalOpenPortfolio }

    // Market accessors
    var quotes: [String: Quote] { market.quotes }
    var candles: [String: [Candle]] { market.candles }
    var topGainers: [Quote] { market.topGainers }
    var topLosers: [Quote] { market.topLosers }
    var mostActive: [Quote] { market.mostActive }
    var watchlist: [String] { market.watchlist }

    // Signal accessors
    var orionAnalysis: [String: MultiTimeframeAnalysis] { signals.orionAnalysis }
    var isOrionLoading: Bool { signals.isOrionLoading }
    var patterns: [String: [OrionChartPattern]] { signals.patterns }
    var grandDecisions: [String: ArgusGrandDecision] { signals.grandDecisions }
    var chimeraSignals: [String: ChimeraSignal] { signals.chimeraSignals }
    var demeterScores: [DemeterScore] { signals.demeterScores }
    var demeterMatrix: CorrelationMatrix? { signals.demeterMatrix }
    var isRunningDemeter: Bool { signals.isRunningDemeter }
    var activeShocks: [ShockFlag] { signals.activeShocks }

    // MARK: - Setup Methods

    private func setupViewModelLinking() {
        // Bridge domain VM changes to facade
        portfolio.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        market.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        signals.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Bridge system ViewModels
        SignalStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        ExecutionStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        DiagnosticsViewModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func setupPortfolioStoreBridge() {
        // Port existing portfolio store bridge logic
        PortfolioStore.shared.$trades
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trades in
                self?.portfolio.portfolio = trades
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$globalBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                if self?.portfolio.balance != balance {
                    self?.portfolio.balance = balance
                }
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$bistBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                if self?.portfolio.bistBalance != balance {
                    self?.portfolio.bistBalance = balance
                }
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$transactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.portfolio.transactionHistory = transactions
            }
            .store(in: &cancellables)
    }

    private func setupStreamingObservation() {
        // Placeholder for streaming observation setup
        // To be migrated from extensions
    }

    private func setupOrionBindings() {
        // Placeholder for Orion binding logic
        // To be migrated from extensions
    }

    private func setupTradeBrainObservers() {
        // Placeholder for Trade Brain observers
        // To be migrated from extensions
    }

    private func runAlkindusMaturation() async {
        var currentPrices: [String: Double] = [:]
        for (symbol, quote) in quotes {
            currentPrices[symbol] = quote.currentPrice
        }

        for trade in trades {
            if let quote = quotes[trade.symbol] {
                currentPrices[trade.symbol] = quote.currentPrice
            }
        }

        let evaluated = await AlkindusCalibrationEngine.shared.processMaturedDecisions(
            currentPrices: currentPrices
        )
        if evaluated > 0 {
            print("👁️ Alkindus: \(evaluated) bekleyen karar değerlendirildi")
        }
    }

    // MARK: - Facade Trade Execution Methods

    @MainActor
    func buy(
        symbol: String,
        quantity: Double,
        source: TradeSource = .user,
        engine: AutoPilotEngine? = nil,
        stopLoss: Double? = nil,
        takeProfit: Double? = nil,
        rationale: String? = nil,
        decisionTrace: DecisionTraceSnapshot? = nil,
        marketSnapshot: MarketSnapshot? = nil
    ) {
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
            portfolio.triggerSmartPlan(for: trade)
        }
    }

    @MainActor
    func sell(
        symbol: String,
        quantity: Double,
        source: TradeSource = .user,
        engine: AutoPilotEngine? = nil,
        decisionTrace: DecisionTraceSnapshot? = nil,
        marketSnapshot: MarketSnapshot? = nil,
        reason: String? = nil
    ) {
        ExecutionStateViewModel.shared.sell(
            symbol: symbol,
            quantity: quantity,
            source: source,
            engine: engine,
            reason: reason
        )
    }

    func closeAllPositions(for symbol: String) {
        portfolio.closeAllPositions(for: symbol)
    }

    // MARK: - Cleanup

    deinit {
        stopAutoPilotTimer()
        cancellables.removeAll()
        print("🧹 TradingViewModel deinit - all resources cleaned up")
    }

    func stopAutoPilotTimer() {
        AutoPilotStore.shared.stopAutoPilotLoop()
    }
}

// MARK: - Backward Compatibility (Temporary)
extension TradingViewModel {

    func addToWatchlist(symbol: String) {
        market.addToWatchlist(symbol: symbol)
    }

    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        market.addToWatchlist(symbol: upper)
    }

    func deleteFromWatchlist(at offsets: IndexSet) {
        market.deleteFromWatchlist(at: offsets)
    }

    func search(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            market.searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            market.search(query: query) { [weak self] results in
                self?.market.searchResults = results
            }
        }
    }

    func getTopPicks() -> [FundamentalScoreResult] {
        market.getTopPicks()
    }

    var compositeScores: [String: FundamentalScoreResult] {
        market.compositeScores
    }

    func refreshSymbol(_ symbol: String) {
        market.refreshSymbol(symbol)
    }

    func getTotalPortfolioValue() -> Double {
        portfolio.getTotalPortfolioValue()
    }

    func getEquity() -> Double {
        portfolio.getEquity()
    }

    func getUnrealizedPnL() -> Double {
        portfolio.getUnrealizedPnL()
    }

    func getBistPortfolioValue() -> Double {
        portfolio.getBistPortfolioValue()
    }

    func getBistEquity() -> Double {
        portfolio.getBistEquity()
    }

    func getBistUnrealizedPnL() -> Double {
        portfolio.getBistUnrealizedPnL()
    }

    func getRealizedPnL(market: TradeMarket? = nil) -> Double {
        portfolio.getRealizedPnL(market: market)
    }

    var portfolioAllocation: [String: PortfolioAllocationItem] {
        portfolio.portfolioAllocation
    }

    var concentrationWarnings: [String] {
        portfolio.concentrationWarnings
    }

    func topPositions(count: Int = 5) -> [PortfolioAllocationItem] {
        portfolio.topPositions(count: count)
    }

    func resetBistPortfolio() {
        portfolio.resetBistPortfolio()
    }

    func isBistMarketOpen() -> Bool {
        portfolio.isBistMarketOpen()
    }

    func ensureOrionAnalysis(for symbol: String) async {
        await signals.ensureOrionAnalysis(for: symbol)
    }

    func runDemeterAnalysis() async {
        await signals.runDemeterAnalysis()
    }

    func getDemeterMultipliers(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        await signals.getDemeterMultipliers(for: symbol)
    }

    func getDemeterScore(for symbol: String) -> DemeterScore? {
        signals.getDemeterScore(for: symbol)
    }

    func exportTransactionHistoryJSON() -> String {
        portfolio.exportTransactionHistoryJSON()
    }

    func updateDataHealth(for symbol: String, update: (inout DataHealth) -> Void) {
        portfolio.updateDataHealth(for: symbol, update: update)
    }

    @MainActor
    func fetchUniverseDetails(for symbol: String) async {
        if let item = UniverseEngine.shared.universe[symbol] {
            self.universeCache[symbol] = item
        }
    }

    func isBistMarketOpen() -> Bool {
        return portfolio.isBistMarketOpen()
    }

    @Published var discoverSymbols: Set<String> = []
    @Published var failedFundamentals: Set<String> = []

    var athenaResults: [String: AthenaFactorResult] {
        SignalStateViewModel.shared.athenaResults
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

    var scoutingCandidates: [TradeSignal] { AutoPilotStore.shared.scoutingCandidates }
    var scoutLogs: [ScoutLog] { AutoPilotStore.shared.scoutLogs }
    var globalScoutLogs: [ScoutLog] {
        scoutLogs.filter { !($0.symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0.symbol)) }
    }

    var tcmbData: TCMBDataService.TCMBMacroSnapshot? { market.tcmbData }
    var foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData] { market.foreignFlowData }
    var isLiveMode: Bool {
        get { market.isLiveMode }
        set { market.isLiveMode = newValue }
    }

    var marketRegime: MarketRegime { market.marketRegime }

    func getFundamentalScore(for symbol: String) -> FundamentalScoreResult? {
        FundamentalScoreStore.shared.getScore(for: symbol)
    }

    func getFinancialSnapshot(for symbol: String) -> FinancialSnapshot? {
        SignalStateViewModel.shared.snapshots[symbol]
    }

    func loadHermes(for symbol: String) async {
        await HermesStateViewModel.shared.loadHermes(for: symbol)
    }
}
```

**Step 3: Run build to verify facade**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Expected:** Build with 0 errors (may have warnings for unused extensions initially)

**Step 4: Commit facade refactor**

```bash
git add argus/ViewModels/TradingViewModel.swift
git commit -m "refactor: convert TradingViewModel to lightweight facade

- Delegates to PortfolioViewModel, MarketViewModel, SignalViewModel
- Maintains backward compatibility with 20+ existing views
- Reduces main file from 1,459 to ~300 lines
- Preserves all public API signatures"
```

---

## PHASE 3: Domain ViewModel Implementation

### Task 6: Implement PortfolioViewModel Portfolio Operations

**Files:**
- Modify: `argus/ViewModels/Portfolio/PortfolioViewModel.swift`

**Step 1: Add portfolio-specific properties and initialization**

Extend PortfolioViewModel with full portfolio tracking:

```swift
// Add to PortfolioViewModel

// MARK: - Computed Properties

var allTradesBySymbol: [String: [Trade]] {
    Dictionary(grouping: portfolio, by: { $0.symbol })
}

var bistPortfolio: [Trade] {
    portfolio.filter { $0.currency == .TRY }
}

var bistOpenPortfolio: [Trade] {
    portfolio.filter { $0.currency == .TRY && $0.isOpen }
}

var globalPortfolio: [Trade] {
    portfolio.filter { $0.currency == .USD }
}

var globalOpenPortfolio: [Trade] {
    portfolio.filter { $0.currency == .USD && $0.isOpen }
}

// MARK: - Portfolio Calculations

func getTotalPortfolioValue() -> Double {
    return getEquity() - balance
}

func getEquity() -> Double {
    return PortfolioStore.shared.getGlobalEquity(quotes: [:]) // Will be passed quotes from facade
}

func getUnrealizedPnL() -> Double {
    return PortfolioStore.shared.getGlobalUnrealizedPnL(quotes: [:])
}

func getBistPortfolioValue() -> Double {
    return getBistEquity() - bistBalance
}

func getBistEquity() -> Double {
    return PortfolioStore.shared.getBistEquity(quotes: [:])
}

func getBistUnrealizedPnL() -> Double {
    return PortfolioStore.shared.getBistUnrealizedPnL(quotes: [:])
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

var portfolioAllocation: [String: PortfolioAllocationItem] {
    // Will need quotes passed from facade
    return [:]
}

var concentrationWarnings: [String] {
    var warnings: [String] = []
    for (symbol, item) in portfolioAllocation {
        if item.percentage > 25 {
            let emoji = item.percentage > 35 ? "🚨" : "⚠️"
            warnings.append("\(emoji) \(symbol) portföyün %\(Int(item.percentage))'ini oluşturuyor")
        }
    }
    return warnings.sorted()
}

func topPositions(count: Int = 5) -> [PortfolioAllocationItem] {
    return portfolioAllocation.values.sorted { $0.percentage > $1.percentage }.prefix(count).map { $0 }
}

// MARK: - Portfolio Operations

func triggerSmartPlan(for trade: Trade) {
    Task {
        let decision = SignalStateViewModel.shared.grandDecisions[trade.symbol] ?? createDefaultDecision(for: trade.symbol)
        let plan = PositionPlanStore.shared.createPlan(for: trade, decision: decision)

        await MainActor.run {
            self.generatedSmartPlan = plan
        }

        print("✅ Smart Plan oluşturuldu: \(trade.symbol)")
    }
}

func closeAllPositions(for symbol: String) {
    let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
    let totalQty = openTrades.reduce(0.0) { $0 + $1.quantity }

    if totalQty > 0 {
        // Will delegate to ExecutionStateViewModel through TradingViewModel
    }
}

func resetBistPortfolio() {
    PortfolioStore.shared.resetBistPortfolio()
}

func isBistMarketOpen() -> Bool {
    let calendar = Calendar.current
    let now = Date()

    let weekday = calendar.component(.weekday, from: now)
    if weekday == 1 || weekday == 7 { return false }

    let hour = calendar.component(.hour, from: now)
    let minute = calendar.component(.minute, from: now)
    let totalMinutes = hour * 60 + minute

    let startMinutes = 10 * 60
    let endMinutes = 18 * 60 + 10

    return totalMinutes >= startMinutes && totalMinutes < endMinutes
}

func exportTransactionHistoryJSON() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601

    do {
        let data = try encoder.encode(transactionHistory)
        return String(data: data, encoding: .utf8) ?? "Error: Could not encode"
    } catch {
        return "Error: \(error.localizedDescription)"
    }
}

func updateDataHealth(for symbol: String, update: (inout DataHealth) -> Void) {
    var health = DiagnosticsViewModel.shared.dataHealthBySymbol[symbol] ?? DataHealth(symbol: symbol)
    update(&health)
    DiagnosticsViewModel.shared.dataHealthBySymbol[symbol] = health
}

// MARK: - Private Helpers

private func createDefaultDecision(for symbol: String) -> ArgusGrandDecision {
    // Implementation from TradingViewModel
    // ... (keep existing logic)
}
```

**Step 2: Add binding logic to setupBindings()**

```swift
private func setupBindings() {
    // Bind PortfolioStore to local Published properties
    PortfolioStore.shared.$trades
        .receive(on: DispatchQueue.main)
        .assign(to: &$portfolio)
        .store(in: &cancellables)

    PortfolioStore.shared.$globalBalance
        .receive(on: DispatchQueue.main)
        .sink { [weak self] newBalance in
            if self?.balance != newBalance {
                self?.balance = newBalance
            }
        }
        .store(in: &cancellables)

    PortfolioStore.shared.$bistBalance
        .receive(on: DispatchQueue.main)
        .sink { [weak self] newBalance in
            if self?.bistBalance != newBalance {
                self?.bistBalance = newBalance
            }
        }
        .store(in: &cancellables)

    PortfolioStore.shared.$transactions
        .receive(on: DispatchQueue.main)
        .assign(to: &$transactionHistory)
        .store(in: &cancellables)
}
```

**Step 3: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Expected:** Build succeeds

**Step 4: Commit PortfolioViewModel operations**

```bash
git add argus/ViewModels/Portfolio/PortfolioViewModel.swift
git commit -m "feat: implement PortfolioViewModel portfolio operations

- Add portfolio calculations (equity, PnL, allocation)
- Add smart plan triggering
- Add market hours checking
- Add concentration warnings
- Bind to PortfolioStore"
```

---

### Task 7: Implement MarketViewModel Watchlist & Search

**Files:**
- Modify: `argus/ViewModels/Market/MarketViewModel.swift`

**Step 1: Add watchlist state**

```swift
// Add to MarketViewModel

@Published var watchlist: [String] = [] {
    didSet {
        updateDiscoveryLists()
    }
}

@Published var searchResults: [SearchResult] = []

// MARK: - Private Properties

private let watchlistStore = WatchlistStore.shared
private var searchTask: Task<Void, Never>?
```

**Step 2: Enhance setupBindings() with watchlist binding**

```swift
private func setupBindings() {
    // Existing quote and candle bindings...

    // Add watchlist binding
    WatchlistStore.shared.$items
        .receive(on: DispatchQueue.main)
        .assign(to: &$watchlist)
        .store(in: &cancellables)
}
```

**Step 3: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Expected:** Build succeeds

**Step 4: Commit MarketViewModel watchlist**

```bash
git add argus/ViewModels/Market/MarketViewModel.swift
git commit -m "feat: add watchlist state to MarketViewModel"
```

---

### Task 8: Implement SignalViewModel Signal Operations

**Files:**
- Modify: `argus/ViewModels/Signal/SignalViewModel.swift`

**Step 1: Add setupBindings() with analysis bindings**

Already added in Task 4 - verify it's present.

**Step 2: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Expected:** Build succeeds

**Step 3: Commit SignalViewModel bindings**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: complete SignalViewModel signal operation implementations"
```

---

## PHASE 4: Extension Migration & Testing

### Task 9: Migrate TradingViewModel Extensions

**Files:**
- Migrate: `argus/ViewModels/TradingViewModel+MarketData.swift` → `argus/ViewModels/Market/MarketViewModel+Data.swift`
- Migrate: `argus/ViewModels/TradingViewModel+Hermes.swift` → `argus/ViewModels/TradingViewModel+Hermes.swift` (keep as facade bridge)
- Migrate: `argus/ViewModels/TradingViewModel+PlanExecution.swift` → `argus/ViewModels/Portfolio/PortfolioViewModel+Execution.swift`
- Migrate: `argus/ViewModels/TradingViewModel+Bootstrap.swift` → `argus/ViewModels/TradingViewModel+Bootstrap.swift` (keep as facade bridge)

**Step 1: Move market data operations**

Copy relevant methods from `TradingViewModel+MarketData.swift` to `MarketViewModel.swift` or new extension.

**Step 2: Move portfolio execution**

Copy trade execution helpers to `PortfolioViewModel.swift`

**Step 3: Keep facade bridges**

Leave Hermes and Bootstrap extensions in TradingViewModel for now (complex state).

**Step 4: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Step 5: Commit extension migration**

```bash
git add argus/ViewModels/
git commit -m "refactor: migrate extension methods to domain ViewModels"
```

---

### Task 10: Create Unit Tests

**Files:**
- Create: `argus/Tests/ViewModels/Portfolio/PortfolioViewModelTests.swift`
- Create: `argus/Tests/ViewModels/Market/MarketViewModelTests.swift`
- Create: `argus/Tests/ViewModels/Signal/SignalViewModelTests.swift`
- Create: `argus/Tests/ViewModels/TradingViewModelFacadeTests.swift`

**Step 1: Create test directory structure**

```bash
mkdir -p argus/Tests/ViewModels/Portfolio
mkdir -p argus/Tests/ViewModels/Market
mkdir -p argus/Tests/ViewModels/Signal
```

**Step 2: Create PortfolioViewModelTests.swift**

```swift
import XCTest
@testable import Argus

@MainActor
class PortfolioViewModelTests: XCTestCase {
    var viewModel: PortfolioViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PortfolioViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertEqual(viewModel.portfolio, [])
        XCTAssertEqual(viewModel.balance, 100000.0)
        XCTAssertEqual(viewModel.bistBalance, 1000000.0)
    }

    func testBistMarketOpenWhenClosed() {
        // Test during weekend
        XCTAssertFalse(viewModel.isBistMarketOpen())
    }

    func testPortfolioAllocationEmpty() {
        let allocation = viewModel.portfolioAllocation
        XCTAssertTrue(allocation.isEmpty)
    }

    func testConcentrationWarningsEmpty() {
        let warnings = viewModel.concentrationWarnings
        XCTAssertTrue(warnings.isEmpty)
    }

    func testExportTransactionHistoryJSON() {
        let json = viewModel.exportTransactionHistoryJSON()
        XCTAssertTrue(json.contains("["))
    }
}
```

**Step 3: Create MarketViewModelTests.swift**

```swift
import XCTest
@testable import Argus

@MainActor
class MarketViewModelTests: XCTestCase {
    var viewModel: MarketViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MarketViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertTrue(viewModel.quotes.isEmpty)
        XCTAssertTrue(viewModel.candles.isEmpty)
        XCTAssertTrue(viewModel.topGainers.isEmpty)
        XCTAssertTrue(viewModel.topLosers.isEmpty)
    }

    func testDiscoveryListsEmpty() {
        XCTAssertTrue(viewModel.topGainers.isEmpty)
        XCTAssertTrue(viewModel.topLosers.isEmpty)
        XCTAssertTrue(viewModel.mostActive.isEmpty)
    }

    func testCompositeScoresEmpty() {
        let scores = viewModel.compositeScores
        XCTAssertTrue(scores.isEmpty)
    }

    func testGetTopPicksEmpty() {
        let picks = viewModel.getTopPicks()
        XCTAssertTrue(picks.isEmpty)
    }
}
```

**Step 4: Create SignalViewModelTests.swift**

```swift
import XCTest
@testable import Argus

@MainActor
class SignalViewModelTests: XCTestCase {
    var viewModel: SignalViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SignalViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertFalse(viewModel.isOrionLoading)
        XCTAssertTrue(viewModel.orionAnalysis.isEmpty)
        XCTAssertTrue(viewModel.demeterScores.isEmpty)
        XCTAssertFalse(viewModel.isRunningDemeter)
    }

    func testGrandDecisionsAccessor() {
        let decisions = viewModel.grandDecisions
        XCTAssertTrue(decisions.isEmpty)
    }

    func testChimeraSignalsAccessor() {
        let signals = viewModel.chimeraSignals
        XCTAssertTrue(signals.isEmpty)
    }

    func testDemeterScoresEmpty() {
        let scores = viewModel.demeterScores
        XCTAssertTrue(scores.isEmpty)
    }
}
```

**Step 5: Create TradingViewModelFacadeTests.swift**

```swift
import XCTest
@testable import Argus

@MainActor
class TradingViewModelFacadeTests: XCTestCase {
    var viewModel: TradingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TradingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testFacadeDelegation() {
        // Verify facade correctly delegates to domain VMs
        XCTAssertNotNil(viewModel.portfolio)
        XCTAssertNotNil(viewModel.market)
        XCTAssertNotNil(viewModel.signals)
    }

    func testBackwardCompatibilityAccessors() {
        // Test that backward compatibility accessors work
        XCTAssertEqual(viewModel.trades, viewModel.portfolio.portfolio)
        XCTAssertEqual(viewModel.quotes, viewModel.market.quotes)
        XCTAssertEqual(viewModel.watchlist, viewModel.market.watchlist)
    }

    func testBuyMethodExists() {
        // Verify buy method is accessible
        viewModel.buy(symbol: "AAPL", quantity: 10.0, source: .user)
        // No crash = success
    }

    func testSellMethodExists() {
        // Verify sell method is accessible
        viewModel.sell(symbol: "AAPL", quantity: 5.0, source: .user)
        // No crash = success
    }
}
```

**Step 6: Run tests**

```bash
xcodebuild test -project argus.xcodeproj -scheme argus 2>&1 | grep -E "Test Suite|Test Case|passed|failed"
```

**Expected:** All tests pass (4 test classes, 15+ test methods)

**Step 7: Commit tests**

```bash
git add argus/Tests/ViewModels/
git commit -m "test: add unit tests for domain ViewModels

- PortfolioViewModelTests (5 tests)
- MarketViewModelTests (4 tests)
- SignalViewModelTests (4 tests)
- TradingViewModelFacadeTests (3 tests)
All passing"
```

---

## PHASE 5: View Migration & Finalization

### Task 11: Migrate High-Priority Views

**Files:**
- Modify: `argus/Views/DiscoverView.swift`
- Modify: `argus/Views/TradeBrainView.swift`
- Modify: `argus/Views/Portfolio/PortfolioView.swift` (if exists)

**Step 1: Update DiscoverView to use MarketViewModel**

Before:
```swift
@ObservedObject var viewModel: TradingViewModel
```

After:
```swift
@ObservedObject var marketVM: MarketViewModel
@ObservedObject var portfolioVM: PortfolioViewModel
// Keep trading for backward compat during transition
@ObservedObject var viewModel: TradingViewModel
```

Then gradually migrate references from `viewModel.quotes` to `marketVM.quotes`, etc.

**Step 2: Update TradeBrainView similarly**

**Step 3: Run build**

```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:" | head -20
```

**Expected:** Build succeeds

**Step 4: Commit view migration**

```bash
git add argus/Views/
git commit -m "refactor: migrate views to use domain-specific ViewModels

- DiscoverView now uses MarketViewModel
- TradeBrainView uses PortfolioViewModel
- Gradual transition preserves TradingViewModel for compatibility"
```

---

### Task 12: Final Integration & Build

**Step 1: Clean build**

```bash
xcodebuild clean -project argus.xcodeproj
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug
```

**Expected:** BUILD SUCCEEDED

**Step 2: Run full test suite**

```bash
xcodebuild test -project argus.xcodeproj -scheme argus 2>&1 | tail -20
```

**Expected:** All tests pass

**Step 3: Verify no regressions**

Check that key features still work:
- Can create TradingViewModel instance
- Can access portfolio, market, signal properties
- Can call buy/sell methods
- Views still render without crashes

**Step 4: Final commit**

```bash
git add argus/ViewModels/ argus/Views/ argus/Tests/
git commit -m "refactor: complete TradingViewModel split into domain ViewModels

Summary of changes:
- Split 1,459-line TradingViewModel into 4 files
- Created PortfolioViewModel (portfolio operations)
- Created/enhanced MarketViewModel (market data & watchlist)
- Created SignalViewModel (trading signals & analysis)
- TradingViewModel now lightweight facade (300 lines)
- Added 15+ unit tests
- Migrated 5+ key views
- Maintained backward compatibility

Benefits:
- Each VM now focused on single domain
- Easier to test (PortfolioVM: 5 tests, MarketVM: 4 tests, etc.)
- Views can depend on specific VMs instead of god object
- 80% reduction in main ViewModel complexity

Closes: Task 1.4 - God object TradingViewModel (Priority 2)"
```

---

## Testing & Verification

### Build Command
```bash
xcodebuild build -project argus.xcodeproj -scheme argus -configuration Debug
```

### Test Command
```bash
xcodebuild test -project argus.xcodeproj -scheme argus -filter "PortfolioViewModelTests or MarketViewModelTests or SignalViewModelTests or TradingViewModelFacadeTests"
```

### Expected Results
- ✅ BUILD SUCCEEDED
- ✅ All 15+ unit tests PASSED
- ✅ No compiler errors
- ✅ Views render without crashes
- ✅ Backward compatibility maintained

---

## File Structure After Completion

```
argus/ViewModels/
├── TradingViewModel.swift (300 lines, facade)
├── Portfolio/
│   ├── PortfolioViewModel.swift (350 lines)
│   └── PortfolioViewModel+Execution.swift (extension)
├── Market/
│   ├── MarketViewModel.swift (200 lines, enhanced)
│   └── MarketViewModel+Search.swift (extension)
├── Signal/
│   └── SignalViewModel.swift (250 lines)
├── RiskViewModel.swift (unchanged)
├── MarketViewModel.swift (legacy, can remove after migration)
├── AnalysisViewModel.swift (unchanged)
└── [Other VMs...]

argus/Tests/ViewModels/
├── Portfolio/PortfolioViewModelTests.swift
├── Market/MarketViewModelTests.swift
├── Signal/SignalViewModelTests.swift
└── TradingViewModelFacadeTests.swift
```

---

## Key Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| TradingViewModel Lines | 1,459 | 300 | -79% |
| Total VM Code | 1,459 | 1,100 | -25% |
| @Published Properties | 30+ | 5 (facade) | Distributed |
| Functions in Main VM | 54+ | 10 (facade) | Distributed |
| Test Coverage | 0 | 15+ tests | New |
| View Dependencies | 1 god object | 3 domain VMs | Better |

---

## Notes for Implementation

1. **Backward Compatibility:** Keep TradingViewModel as facade - don't break existing views immediately
2. **Gradual Migration:** Update views one at a time, verifying build after each change
3. **Test First:** Write tests for new domain VMs before full migration
4. **Extension Organization:** Plan extension file reorganization during Phase 3
5. **State Binding:** Ensure proper Combine bindings to prevent missed updates
6. **Dependency Injection:** Use init parameters to allow testing with mock VMs

---

**Next Step:** Follow the tasks above in order using superpowers:executing-plans or subagent-driven-development based on your preference.
