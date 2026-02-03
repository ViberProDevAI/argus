import Foundation
import Combine
import SwiftUI

/// Market Data Manager
/// Extracted from TradingViewModel to reduce complexity.
/// Handles: Quotes, Candles, Discovery Lists, Macro Data (TCMB/Flow)
@MainActor
final class MarketViewModel: ObservableObject {
    // MARK: - Market Data State
    @Published var quotes: [String: Quote] = [:]
    @Published var candles: [String: [Candle]] = [:]
    
    // Discovery Lists
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    
    // BIST Macro & Flow Data
    @Published var tcmbData: TCMBDataService.TCMBMacroSnapshot?
    @Published var foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData] = [:]
    
    // Market Regime
    @Published var marketRegime: MarketRegime = .neutral
    @Published var isLiveMode: Bool = false {
        didSet {
            handleLiveModeChange()
        }
    }
    
    // Services
    private let marketDataProvider = MarketDataProvider.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 1. Bind Quotes
        MarketDataStore.shared.$quotes
            .throttle(for: .seconds(1.0), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] storeQuotes in
                guard let self = self else { return }
                var newQuotes: [String: Quote] = [:]
                for (key, val) in storeQuotes {
                    if let q = val.value {
                        newQuotes[key] = q
                    }
                }
                if self.quotes != newQuotes {
                    self.quotes = newQuotes
                    self.updateDiscoveryLists()
                }
            }
            .store(in: &cancellables)
            
        // 2. Bind Candles
        MarketDataStore.shared.$candles
            .throttle(for: .seconds(1.0), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] storeCandles in
                guard let self = self else { return }
                var newCandles: [String: [Candle]] = [:]
                for (key, val) in storeCandles {
                    if let c = val.value {
                        // Store with original key (e.g. "ABT_1G")
                        newCandles[key] = c

                        // Also store with symbol-only key for UI compatibility
                        let symbol = key.components(separatedBy: "_").first ?? key
                        if newCandles[symbol] == nil || key.contains("1day") || key.contains("1G") {
                            newCandles[symbol] = c
                        }
                    }
                }
                if self.candles != newCandles {
                    self.candles = newCandles
                }
            }
            .store(in: &cancellables)
            
        // 3. Bind Regime
        // Assuming Chiron has a publisher or we pull it? 
        // For now, let's just expose the property or bind if available.
        // ChironRegimeEngine.shared is a singleton.
    }
    
    private func updateDiscoveryLists() {
        let allQuotes = Array(quotes.values)
        guard !allQuotes.isEmpty else { return }
        
        self.topGainers = allQuotes
            .sorted { ($0.percentChange ?? 0) > ($1.percentChange ?? 0) }
            .prefix(10)
            .map { $0 }
            
        self.topLosers = allQuotes
            .sorted { ($0.percentChange ?? 0) < ($1.percentChange ?? 0) }
            .prefix(10)
            .map { $0 }
            
        // Volume logic if available?
    }
    
    // MARK: - Live Mode Logic
    private func handleLiveModeChange() {
        if isLiveMode {
            MarketSessionManager.shared.startSession()
        } else {
            MarketSessionManager.shared.stopSession()
        }
    }
    
    // MARK: - Watchlist & Search State
    @Published var watchlist: [String] = [] {
        didSet {
            updateDiscoveryLists()
        }
    }
    @Published var searchResults: [SearchResult] = []

    private let watchlistStore = WatchlistStore.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - Public Methods

    func refreshMarketRegime() {
        self.marketRegime = ChironRegimeEngine.shared.globalResult.regime
    }

    func fetchTCMBData() {
        Task {
            self.tcmbData = await TCMBDataService.shared.getSnapshot()
        }
    }

    // MARK: - Watchlist Operations

    func addToWatchlist(symbol: String) {
        watchlistStore.add(symbol)
        watchlist = watchlistStore.items
    }

    func removeFromWatchlist(symbol: String) {
        watchlistStore.remove(symbol)
        watchlist = watchlistStore.items
    }

    func deleteFromWatchlist(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let symbolToRemove = watchlist[index]
            removeFromWatchlist(symbol: symbolToRemove)
        }
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

    // MARK: - Composite Scores

    var compositeScores: [String: FundamentalScoreResult] {
        var scores: [String: FundamentalScoreResult] = [:]
        for symbol in watchlistStore.items {
            if let score = FundamentalScoreStore.shared.getScore(for: symbol) {
                scores[symbol] = score
            }
        }
        return scores
    }

    func getTopPicks() -> [FundamentalScoreResult] {
        var picks: [FundamentalScoreResult] = []
        for symbol in watchlistStore.items {
            if let score = FundamentalScoreStore.shared.getScore(for: symbol),
               score.totalScore >= 70 {
                picks.append(score)
            }
        }
        return picks.sorted { $0.totalScore > $1.totalScore }
    }

    // MARK: - Chart Data Loading (Migrated from TradingViewModel+MarketData)

    func loadCandles(for symbol: String, timeframe: String) async {
        // Load candles via Store (SSoT)
        _ = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: timeframe)
    }

    // Helper for ETF Detection
    func isETF(symbol: String) -> Bool {
        // 1. Known Major ETFs
        let knownETFs = Set([
            // US Market
            "SPY", "QQQ", "IWM", "DIA", "VOO", "VTI", "VEA", "VWO", "EFA", "EEM",
            "ARKK", "ARKG", "ARKW", "ARKF", "ARKQ",
            // Sector
            "XLK", "XLF", "XLE", "XLV", "XLI", "XLP", "XLY", "XLU", "XLB", "XLRE", "XLC",
            // Bond
            "BND", "TLT", "IEF", "SHY", "LQD", "HYG", "JNK", "AGG",
            // Commodity
            "GLD", "SLV", "IAU", "USO", "UNG", "DBC", "GSG",
            // Leveraged
            "TQQQ", "SQQQ", "SPXL", "SPXS", "UPRO", "SDS", "SSO",
            // International
            "EWZ", "EWJ", "EWG", "EWU", "EWC", "EWY", "FXI", "INDA", "MCHI",
            // Dividend
            "SCHD", "DVY", "VYM", "HDV", "VIG",
            // Thematic
            "SMH", "SOXX", "XBI", "IBB", "KWEB", "CIBR", "ICLN", "TAN", "JETS", "BITO",
            // Turkey
            "TUR"
        ])

        if knownETFs.contains(symbol) { return true }

        // 2. Check Fundamentals Store
        if let fund = MarketDataStore.shared.fundamentals[symbol]?.value, fund.isETF { return true }

        // 3. Check Quote Sector
        if let quote = MarketDataStore.shared.getQuote(for: symbol), let sec = quote.sector, sec.contains("ETF") { return true }

        // 4. Pattern match
        let etfPatterns = ["-USD", "ETF"]
        for pattern in etfPatterns {
            if symbol.contains(pattern) { return true }
        }

        return false
    }

    // Watchlist Refresh
    func refreshWatchlistQuotes() async {
        await fetchQuotes()
    }

    func fetchQuotes() async {
        let startTime = Date()
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.quotes, name: "BatchFetchQuotes")
        defer {
            SignpostLogger.shared.end(log: SignpostLogger.shared.quotes, name: "BatchFetchQuotes", id: spanId)
            let duration = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async { DiagnosticsViewModel.shared.recordBatchFetchDuration(duration) }
        }

        // Gather symbols from multiple sources
        let portfolioSymbols = PortfolioViewModel.shared.portfolio.filter { $0.isOpen }.map { $0.symbol }
        let safeSymbols = SafeUniverseService.shared.universe.map { $0.symbol }
        let allSymbols = Array(Set(watchlist + portfolioSymbols + safeSymbols))

        guard !allSymbols.isEmpty else { return }

        do {
            try await MarketDataStore.shared.refreshQuotes(symbols: allSymbols)
        } catch {
            print("Watchlist Refresh Failed: \(error)")
        }
    }

    // Single quote fetch for UI
    func fetchQuote(for symbol: String) async {
        do {
            let quote = try await ArgusDataService.shared.fetchQuote(symbol: symbol)
            await MainActor.run {
                self.quotes[symbol] = quote
                MarketDataStore.shared.injectLiveQuote(quote, source: "ArgusDataService")
            }
        } catch {
            print("Single Fetch Failed for \(symbol): \(error)")
        }
    }

    // Watchlist Loop Management
    func startWatchlistLoop() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchQuotes()
            }
        }
        // Run once immediately
        Task {
            await fetchQuotes()
            await fetchCandles()
        }

        // Schedule Candle Refresh (Every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchCandles() }
        }
    }

    internal func fetchCandles() async {
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.candles, name: "FetchCandles")
        defer { SignpostLogger.shared.end(log: SignpostLogger.shared.candles, name: "FetchCandles", id: spanId) }

        // Optimize: Prioritize Portfolio & Top 20 Watchlist
        let portfolioSymbols = PortfolioViewModel.shared.portfolio.map { $0.symbol }
        let prioritySymbols = Set(portfolioSymbols + watchlist.prefix(20))

        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for symbol in prioritySymbols {
                    group.addTask {
                        await Task.yield()
                        _ = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1D")
                    }
                }
            }
        }
    }

    // MARK: - Macro Environment

    var lastMacroUpdate: Date? {
        return MacroRegimeService.shared.getLastUpdate()
    }

    func checkAndRefreshMacro() {
        let service = MacroRegimeService.shared
        let now = Date()

        let maxAgeHours = 12.0
        let shouldRefresh: Bool
        if let lastUpdate = service.getLastUpdate() {
            shouldRefresh = now.timeIntervalSince(lastUpdate) > (maxAgeHours * 3600)
        } else {
            shouldRefresh = true
        }

        if shouldRefresh {
            print("🔄 Macro Data Stale (>12h). Refreshing...")
            loadMacroEnvironment()
        } else {
            print("✅ Macro Data Fresh. Using cache.")
        }
    }

    func loadMacroEnvironment() {
        Task {
            let rating = await MacroRegimeService.shared.computeMacroEnvironment(forceRefresh: true)
            await MainActor.run {
                let context = ChironContext(
                    atlasScore: nil,
                    orionScore: nil,
                    aetherScore: rating.numericScore,
                    demeterScore: nil,
                    phoenixScore: nil,
                    hermesScore: nil,
                    athenaScore: nil,
                    symbol: "GLOBAL",
                    orionTrendStrength: nil,
                    chopIndex: nil,
                    volatilityHint: nil,
                    isHermesAvailable: false
                )
                _ = ChironRegimeEngine.shared.evaluateGlobal(context: context)
            }
        }
    }

    // MARK: - Discovery & Screener

    func refreshMarketPulse() async {
        // 1. Fetch Parallel
        async let gainers = ArgusDataService.shared.fetchScreener(type: .gainers, limit: 10)
        async let losers = ArgusDataService.shared.fetchScreener(type: .losers, limit: 10)
        async let active = ArgusDataService.shared.fetchScreener(type: .mostActive, limit: 10)

        let (g, l, a) = await (try? gainers, try? losers, try? active) as? ([Quote]?, [Quote]?, [Quote]?) ?? (nil, nil, nil)

        await MainActor.run {
            var newQuotes = self.quotes

            if let gainers = g {
                self.topGainers = gainers.compactMap { q in
                    guard let s = q.symbol else { return nil }
                    var mQ = q; mQ.symbol = s
                    newQuotes[s] = mQ
                    return mQ
                }
            }

            if let losers = l {
                self.topLosers = losers.compactMap { q in
                    guard let s = q.symbol else { return nil }
                    var mQ = q; mQ.symbol = s
                    newQuotes[s] = mQ
                    return mQ
                }
            }

            if let active = a {
                self.mostActive = active.compactMap { q in
                    guard let s = q.symbol else { return nil }
                    var mQ = q; mQ.symbol = s
                    newQuotes[s] = mQ
                    return mQ
                }
            }

            self.quotes = newQuotes
        }
    }

    func loadDiscoverData() {
        Task {
            await refreshMarketPulse()
        }
    }

    func fetchTopLosers() async {
        print("📉 Fetching Top Losers...")
        do {
            let losers = try await ArgusDataService.shared.fetchScreener(type: .losers, limit: 10)
            await MainActor.run {
                self.topLosers = losers
            }
        } catch {
            print("⚠️ Fetch Top Losers Failed: \(error)")
        }
    }

    // Radar Strategies
    enum ArgusRadarStrategy: String, CaseIterable {
        case highQualityMomentum = "Yüksek Kalite & Trend"
        case aggressiveGrowth = "Agresif Büyüme"
        case qualityPullback = "Fırsat Bölgesi"
    }

    func getRadarPicks(strategy: ArgusRadarStrategy) -> [String] {
        let allSymbols = quotes.keys
        let signalVM = SignalViewModel.shared

        return allSymbols.filter { symbol in
            guard let quote = quotes[symbol] else { return false }
            let atlas = FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore ?? 50
            let orion = signalVM.orionScores[symbol]?.score ?? 50

            switch strategy {
            case .highQualityMomentum:
                return atlas >= 75 && orion >= 70
            case .aggressiveGrowth:
                return orion >= 80 && (atlas >= 50 && atlas < 80)
            case .qualityPullback:
                return atlas >= 80 && quote.percentChange ?? 0 < -2.0 && quote.percentChange ?? 0 > -15.0
            }
        }.sorted { s1, s2 in
            let sc1 = FundamentalScoreStore.shared.getScore(for: s1)?.totalScore ?? 0
            let sc2 = FundamentalScoreStore.shared.getScore(for: s2)?.totalScore ?? 0
            return sc1 > sc2
        }
    }

    struct ThemeBasket: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let symbols: [String]
    }

    func getThematicLists() -> [ThemeBasket] {
        return [
            ThemeBasket(name: "Yapay Zeka Liderleri", description: "Sektörü domine eden AI devleri.", symbols: ["NVDA", "MSFT", "GOOGL", "AMD", "SMH"]),
            ThemeBasket(name: "Savunma Sanayii", description: "Jeopolitik risk hedge'i.", symbols: ["LMT", "RTX", "NOC", "GD", "ITA"]),
            ThemeBasket(name: "Temettü Kralları", description: "Düzenli nakit akışı.", symbols: ["KO", "PG", "JNJ", "PEP", "SCHD"]),
            ThemeBasket(name: "Kripto & Blockchain", description: "Yüksek riskli dijital varlıklar.", symbols: ["COIN", "MSTR", "MARA", "RIOT", "BITO"])
        ]
    }
}
