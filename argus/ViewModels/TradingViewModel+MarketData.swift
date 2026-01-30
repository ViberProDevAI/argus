import Foundation
import SwiftUI
import Combine

// MARK: - Market Data Management
extension TradingViewModel {
    
    // MARK: - Chart Data Management
    func loadCandles(for symbol: String, timeframe: String) async {
        await MainActor.run { self.isLoading = true }
        
        // Heimdall Routing via Store (SSoT)
        // Store handles coalescing
        // We just ensure data is fetched. The subscription in TradingViewModel.swift will update the UI.
        
        _ = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: timeframe)
        
        await MainActor.run {
             self.isLoading = false
            
            // Update Data Health
            self.updateDataHealth(for: symbol) { health in
                // Candles imply both quotes and intraday/history availability
                health.technical = CoverageComponent.present(quality: 0.8)
                health.lastUpdated = Date()
            }
        }
    }
    
    // Helper for ETF Detection (SSoT Aware)
    // Note: private in extension may be file-private, need internal access if used elsewhere?
    // TradingViewModel extensions can access private members of original class if in same module? No.
    // They must be 'internal' or 'open'.
    func isETF(symbol: String) -> Bool {
        // 1. Known Major ETFs (Hardcoded for reliability)
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
        
        // 4. Pattern match (symbols ending with common ETF patterns)
        let etfPatterns = ["-USD", "ETF"]
        for pattern in etfPatterns {
            if symbol.contains(pattern) { return true }
        }
        
        // Fallback: Not an ETF
        return false
    }
    
    // Watchlist Loop Logic
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
        
        let portfolioSymbols = portfolio.filter { $0.isOpen }.map { $0.symbol }
        let safeSymbols = SafeUniverseService.shared.universe.map { $0.symbol }
        // Include Discover Symbols in the loop
        let allSymbols = Array(Set(watchlist + portfolioSymbols + safeSymbols).union(discoverSymbols))
        
        guard !allSymbols.isEmpty else { return }
        
        // Don't set isLoading=true globally to avoid flickering if we have cached data
        // Only if empty quotes
        if quotes.isEmpty {
           await MainActor.run { self.isLoading = true }
        }
        
        do {
            print("📡 TradingViewModel: Delegating Batch Fetch of \(allSymbols.count) symbols to MarketDataStore...")
            
            // Delegate completely to Store
            // Store handles coalescing, caching (TTL), and updating via $quotes publisher
            try await MarketDataStore.shared.refreshQuotes(symbols: allSymbols)
            
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
             print("Watchlist Refresh Failed: \(error)")
             await MainActor.run { self.isLoading = false }
        }
    }
    
    // Helper for Single Fetch (UI View usage)
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
    
    // MARK: - Watchlist Loop
    func startWatchlistLoop() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchQuotes()
            }
        }
        // Run once immediately
        Task {
            await fetchQuotes()
            await fetchCandles() // Prime the pump for Orion
        }
        
        // Schedule Candle Refresh (Every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchCandles() }
        }
    }
    
    internal func fetchCandles() async {
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.candles, name: "FetchCandles")
        defer { SignpostLogger.shared.end(log: SignpostLogger.shared.candles, name: "FetchCandles", id: spanId) }

        // Optimize: Prioritize Portfolio & Top 20 Watchlist to avoid network congestion
        let prioritySymbols = Set(portfolio.map { $0.symbol } + watchlist.prefix(20))
        print("📡 TradingViewModel: Background Batch Candle Fetch for \(prioritySymbols.count) priority symbols (Optimization Active)")
        
        // Detached Task to avoid blocking Main Actor interaction
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for symbol in prioritySymbols {
                    group.addTask {
                        // Yield to allow other high-priority requests (like Detail View) to slip in
                        await Task.yield() 
                        _ = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1D")
                    }
                }
            }
        }
        
        // Note: Analysis is now triggered reactively via $candles subscription in TradingViewModel.swift
    }
    


    // MARK: - Macro Environment
    
    // UI için son güncelleme zamanı
    var lastMacroUpdate: Date? {
        return MacroRegimeService.shared.getLastUpdate()
    }
    
    func checkAndRefreshMacro() {
        let service = MacroRegimeService.shared
        let now = Date()
        
        // Helper logic: If > 12 hours or nil, refresh
        let last = service.getLastUpdate()
        let maxAgeHours = 12.0
        
        let shouldRefresh: Bool
        if let lastUpdate = last {
            shouldRefresh = now.timeIntervalSince(lastUpdate) > (maxAgeHours * 3600)
        } else {
            shouldRefresh = true
        }
        
        if shouldRefresh {
            print("🔄 Macro Data Stale (>12h). Refreshing...")
            loadMacroEnvironment()
        } else {
            print("✅ Macro Data Fresh. Using cache.")
            // Ensure we have the data in ViewModel even if we don't fetch new
            if macroRating == nil {
                if let cached = service.getCachedRating() {
                    self.macroRating = cached
                } else {
                    // Cache expired but service returned nil? Fetch.
                    loadMacroEnvironment()
                }
            }
        }
    }
    
    func loadMacroEnvironment() {
        print("DEBUG: loadMacroEnvironment called")
        Task {
            print("DEBUG: Starting computeMacroEnvironment (forceRefresh)...")
            // REFORM: Her zaman forceRefresh yap - eski 58 puan sorunu çözülsün
            let rating = await MacroRegimeService.shared.computeMacroEnvironment(forceRefresh: true)
            print("DEBUG: computeMacroEnvironment success: \(rating.letterGrade) (Score: \(Int(rating.numericScore)))")
            await MainActor.run {
                self.macroRating = rating
                self.syncWidgetData() // Update widget when macro data is ready
                self.objectWillChange.send() // Notify UI of update time change
                
                // CHIRON SYNC: Update Neural Link immediately
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
                    volatilityHint: nil, // TODO: Add Global VIX here later
                    isHermesAvailable: false
                )
                _ = ChironRegimeEngine.shared.evaluateGlobal(context: context)
            }
        }
    }
    
    func syncWidgetData() {
        // Widgets are currently disabled.
        // Logic removed to prevent background updates.
    }
    
    // MARK: - Discovery & Screener
    
    func refreshMarketPulse() async {
        self.isLoading = true
        
        // 1. Fetch Parallel via ArgusDataService
        async let gainers = ArgusDataService.shared.fetchScreener(type: .gainers, limit: 10)
        async let losers = ArgusDataService.shared.fetchScreener(type: .losers, limit: 10)
        async let active = ArgusDataService.shared.fetchScreener(type: .mostActive, limit: 10)
        
        let (g, l, a) = await (try? gainers, try? losers, try? active) as? ([Quote]?, [Quote]?, [Quote]?) ?? (nil, nil, nil)
        
        // PERFORMANS OPTİMİZASYONU: Tüm güncellemeleri topla, tek seferde uygula
        await MainActor.run {
            var newQuotes = self.quotes
            
           if let gainers = g {
               self.topGainers = gainers.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   newQuotes[s] = mQ // Batch'e ekle
                   return mQ
               }
           }
           
           if let losers = l {
               self.topLosers = losers.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   newQuotes[s] = mQ // Batch'e ekle
                   return mQ
               }
           }
           
           if let active = a {
               self.mostActive = active.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   newQuotes[s] = mQ // Batch'e ekle
                   return mQ
               }
           }
           
           // TEK ATAMA = DAHA AZ RE-RENDER
           self.quotes = newQuotes
           self.isLoading = false
        }
    }
    
    func loadDiscoverData() {
        Task {
            // Run Pulse
            await refreshMarketPulse()
        }
    }
    
    func fetchTopLosers() async {
        print("📉 Fetching Top Losers...")
        do {
            let losers = try await ArgusDataService.shared.fetchScreener(type: .losers, limit: 10)
            print("📉 Fetched \(losers.count) losers.")
            await MainActor.run {
                self.topLosers = losers
            }
        } catch {
            print("⚠️ Fetch Top Losers Failed: \(error)")
        }
    }
    
    enum ArgusRadarStrategy: String, CaseIterable {
         case highQualityMomentum = "Yüksek Kalite & Trend"
         case aggressiveGrowth = "Agresif Büyüme"
         case qualityPullback = "Fırsat Bölgesi"
     }
     
     func getRadarPicks(strategy: ArgusRadarStrategy) -> [String] {
         // Use existing quotes & scores. Do NOT fetch new API data here.
         let allSymbols = quotes.keys 
         
         return allSymbols.filter { symbol in
             guard let quote = quotes[symbol] else { return false }
             let atlas = fundamentalScoreStore.getScore(for: symbol)?.totalScore ?? 50
             let orion = orionScores[symbol]?.score ?? 50
             
             switch strategy {
             case .highQualityMomentum:
                 return atlas >= 75 && orion >= 70
             case .aggressiveGrowth:
                 return orion >= 80 && (atlas >= 50 && atlas < 80)
             case .qualityPullback:
                 return atlas >= 80 && quote.percentChange < -2.0 && quote.percentChange > -15.0
             }
         }.sorted { s1, s2 in
             let sc1 = fundamentalScoreStore.getScore(for: s1)?.totalScore ?? 0
             let sc2 = fundamentalScoreStore.getScore(for: s2)?.totalScore ?? 0
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
