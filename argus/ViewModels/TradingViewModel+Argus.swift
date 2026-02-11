import Foundation
import SwiftUI
import Combine

// MARK: - Argus Integration (The Brain)
extension TradingViewModel {
    
    // Argus ETF State (Moved usage from main file if needed, properties stay in main for Storage)
    
    // Loading Argus Data
    // MARK: - Scout Logic
    func startScoutLoop() {
        Task {
            await SignalViewModel.shared.startScoutLoop()
        }
    }

    func stopScoutLoop() {
        SignalViewModel.shared.stopScoutLoop()
    }

    func runScout() async {
        // print("🔭 Scout: runScout() ÇAĞRILDI")
        
        // 1. Refresh Discovery Lists (Yahoo Gainers/Losers)
        await refreshMarketPulse()
        
        // 2. Combine Watchlist + Discovery + ScoutUniverse
        let discoverySymbols = (topGainers + topLosers + mostActive).compactMap { $0.symbol }
        
        // ADD SCOUT UNIVERSE (Top 50 US Stocks)
        let universeSymbols = ScoutUniverse.dailyRotation(count: 20) // 20 random from top 50
        
        let allSymbolsToScout = Array(Set(watchlist + discoverySymbols + universeSymbols))
        
        // 3. Debug log
        // print("🔭 Scout: Watchlist=\(watchlist.count), Discovery=\(discoverySymbols.count), Universe=\(universeSymbols.count)")
        // print("🔭 Scout: Toplam \(allSymbolsToScout.count) sembol taranacak: \(allSymbolsToScout.prefix(5).joined(separator: ", "))...")
        
        if allSymbolsToScout.isEmpty {
            // print("⚠️ Scout: Taranacak sembol YOK! Lütfen watchlist'e hisse ekleyin.")
            return
        }
        
        let candidates = await ArgusScoutService.shared.scoutOpportunities(watchlist: allSymbolsToScout, currentQuotes: quotes)
        
        // print("🔭 Scout: Tarama tamamlandı. \(candidates.count) aday bulundu.")
        
        // HANDOVER TO CORSE (AutoPilot)
        if !candidates.isEmpty {
            // print("🔭 Scout Handover: \(candidates.count) candidates passed to Corse Engine.")
            for (symbol, score) in candidates {
                await AutoPilotStore.shared.processHighConvictionCandidate(symbol: symbol, score: score)
            }
        }
    }

    // MARK: - Argus Core Data Loading
    
    @MainActor
    func loadArgusData(for symbol: String) async {
        await SignalViewModel.shared.loadArgusData(for: symbol)
    }

    func calculateFundamentalScore(for symbol: String, assetType: AssetType = .stock, preloadedData: FinancialsData? = nil) async {
        // print("⚡️ CORE DEBUG: calculateFundamentalScore START for \(symbol)")
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // BIST Check - BIST için BISTBilancoEngine kullan
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        if isBist {
            // BIST YOLU: BorsaPy + BISTBilancoEngine
            await calculateBistFundamentalScore(for: symbol)
            return
        }
        
        // GLOBAL YOLU: Yahoo Finance + FundamentalScoreEngine
        do {
            // 1. API'den Veri Çek - Yahoo Finance (TwelveData Pro plan gerekli)
            // print("⚡️ ATLAS: Fetching Fundamentals from Yahoo for \(symbol)...")
            
            // Rate Limit Guard
            if preloadedData == nil {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // Use Preloaded OR Fetch
            let financials: FinancialsData
            if let pre = preloadedData {
                financials = pre
            } else {
                financials = try await YahooFinanceProvider.shared.fetchFundamentals(symbol: symbol)
            }
            
            // Explicit Cache
            FundamentalsCache.shared.set(symbol: symbol, data: financials)

            // print("⚡️ ATLAS: Yahoo returned: Rev=\(financials.totalRevenue ?? -1), PE=\(financials.peRatio ?? -1), MC=\(financials.marketCap ?? -1)")
            
            // 2. Risk Skoru için Candle Verisi
            var symbolCandles = candles[symbol]
            if symbolCandles == nil || symbolCandles!.isEmpty {
                if let fetched = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 365) {
                     await MainActor.run {
                        self.candles[symbol] = fetched
                    }
                    symbolCandles = fetched
                }
            }
            
            // 3. Risk Skoru Hesapla
            var riskScore: Double? = nil
            if let c = symbolCandles {
                riskScore = RiskMetricService.shared.calculateVolatilityScore(candles: c)
            }
            
            // 4. Skor Hesapla
            if let result = FundamentalScoreEngine.shared.calculate(data: financials, riskScore: riskScore) {
                await MainActor.run {
                    self.fundamentalScoreStore.saveScore(result)
                    
                    // --- ATLAS LOGGING ---
                    let currentPrice = self.quotes[symbol]?.currentPrice ?? symbolCandles?.last?.close ?? 0.0
                    if currentPrice > 0 {
                        let fundCoverage = CoverageComponent(available: true, quality: result.dataCoverage / 100.0)
                        
                        // Technical: If we have candles, data is good (0.8 or higher based on count)
                        let candleCount = symbolCandles?.count ?? 0
                        let techQuality = candleCount >= 100 ? 1.0 : (candleCount >= 50 ? 0.8 : (candleCount > 0 ? 0.6 : 0.0))
                        let techCoverage = CoverageComponent(available: candleCount > 0, quality: techQuality)
                        
                        // Macro: We always have some macro context from Aether, mark as present
                        let macroCoverage = CoverageComponent.present(quality: 0.7)
                        
                        // News: If no explicit news service, still count as partially covered
                        let newsCoverage = CoverageComponent.present(quality: 0.5)
                        
                        let health = DataHealth(
                             symbol: symbol,
                             lastUpdated: Date(),
                             fundamental: fundCoverage,
                             technical: techCoverage,
                             macro: macroCoverage,
                             news: newsCoverage
                        )
                        self.dataHealthBySymbol[symbol] = health
                    }
                    // ---------------------
                    
                    self.objectWillChange.send() // UI Update
                    self.isLoading = false
                }
            } else {
                 // print("⚠️ Atlas Engine returned NIL for \(symbol) (Insufficient Data)")
                 await MainActor.run {
                     self.failedFundamentals.insert(symbol)
                     self.isLoading = false
                 }
            }
        } catch {
            // print("❌ Fundamental Data Fetch Failed: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.failedFundamentals.insert(symbol)
            }
        }
    }
    
    // MARK: - BIST Fundamental Score (BorsaPy + BISTBilancoEngine)
    
    private func calculateBistFundamentalScore(for symbol: String) async {
        // print("🏛️ BIST ATLAS: Calculating fundamental score for \(symbol) via BorsaPy...")
        
        do {
            // 1. BISTBilancoEngine'den analiz çek
            let bistSonuc = try await BISTBilancoEngine.shared.analiz(sembol: symbol)
            
            // print("✅ BIST ATLAS: \(symbol) - Toplam Skor: \(bistSonuc.toplamSkor), F/K: \(bistSonuc.degerlemeVerisi.fk.deger ?? -1)")
            
            // 2. BISTBilancoSonuc'u FundamentalScoreResult'a dönüştür
            // Böylece mevcut Argus altyapısıyla uyumlu olur
            let result = convertBistToFundamentalResult(bistSonuc: bistSonuc, symbol: symbol)
            
            await MainActor.run {
                // 3. Store'a kaydet
                self.fundamentalScoreStore.saveScore(result)
                
                // 4. DataHealth güncelle
                let health = DataHealth(
                    symbol: symbol,
                    lastUpdated: Date(),
                    fundamental: CoverageComponent(available: true, quality: 0.6), // BorsaPy sınırlı veri
                    technical: CoverageComponent(available: true, quality: 0.8),
                    macro: CoverageComponent.present(quality: 0.7),
                    news: CoverageComponent.present(quality: 0.5)
                )
                self.dataHealthBySymbol[symbol] = health
                
                self.objectWillChange.send()
                self.isLoading = false
            }
        } catch {
            // print("❌ BIST ATLAS Failed: \(error)")
            await MainActor.run {
                self.failedFundamentals.insert(symbol)
                self.isLoading = false
            }
        }
    }
    
    /// BISTBilancoSonuc -> FundamentalScoreResult dönüşümü
    private func convertBistToFundamentalResult(bistSonuc: BISTBilancoSonuc, symbol: String) -> FundamentalScoreResult {
        // Değerleme verilerini FinancialsData'ya çevir
        let financials = FinancialsData(
            symbol: symbol,
            currency: "TRY",
            lastUpdated: Date(),
            totalRevenue: nil,
            netIncome: nil,
            totalShareholderEquity: nil,
            marketCap: bistSonuc.profil.piyasaDegeri,
            revenueHistory: [],
            netIncomeHistory: [],
            ebitda: nil,
            shortTermDebt: nil,
            longTermDebt: nil,
            operatingCashflow: nil,
            capitalExpenditures: nil,
            cashAndCashEquivalents: nil,
            peRatio: bistSonuc.degerlemeVerisi.fk.deger,
            forwardPERatio: nil,
            priceToBook: bistSonuc.degerlemeVerisi.pddd.deger,
            evToEbitda: bistSonuc.degerlemeVerisi.fdFavok.deger,
            dividendYield: nil,
            forwardGrowthEstimate: nil,
            isETF: false,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
        
        // Değerleme grade'i belirle
        let valuationGrade: String
        let degerleme = bistSonuc.degerleme
        if degerleme >= 75 { valuationGrade = "Ucuz" }
        else if degerleme >= 50 { valuationGrade = "Makul" }
        else { valuationGrade = "Pahalı" }
        
        // Özet ve highlights oluştur
        let summary = bistSonuc.ozet
        var highlights: [String] = []
        if let fk = bistSonuc.degerlemeVerisi.fk.deger {
            highlights.append("F/K: \(String(format: "%.1f", fk))x")
        }
        if let pddd = bistSonuc.degerlemeVerisi.pddd.deger {
            highlights.append("PD/DD: \(String(format: "%.2f", pddd))x")
        }
        highlights.append(contentsOf: bistSonuc.oneCikanlar)
        
        // FundamentalScoreResult oluştur (doğru init parametreleri)
        return FundamentalScoreResult(
            symbol: symbol,
            date: Date(),
            totalScore: bistSonuc.toplamSkor,
            realizedScore: bistSonuc.degerleme, // Kullanılabilir tek veri: değerleme
            forwardScore: nil,
            profitabilityScore: nil, // Veri yok
            growthScore: nil,        // Veri yok
            leverageScore: nil,      // Veri yok
            cashQualityScore: nil,   // Veri yok
            dataCoverage: 40,        // BorsaPy sınırlı veri sağlıyor
            summary: summary,
            highlights: highlights,
            proInsights: bistSonuc.uyarilar,
            calculationDetails: "BIST verileri İş Yatırım HTML scraping ile alınmaktadır. Sadece F/K ve PD/DD metrikleri mevcut.",
            valuationGrade: valuationGrade,
            riskScore: nil,
            isETF: false,
            financials: financials
        )
    }
    
    // MARK: - Voice & Explanations (Gemini)

    @MainActor
    func generateVoiceReport(for symbol: String, tradeId: UUID? = nil, existingTrace: ArgusVoiceTrace? = nil, depth: Int = 1) async {
        isGeneratingVoiceReport = true
        defer { isGeneratingVoiceReport = false }
        
        // V3 REFORM: Use ArgusGrandDecision as the Single Source of Truth
        // We prioritizing the latest Council Decision over legacy traces for now to ensure quality.
        // If we are viewing a historical trade, we might need to map it later, but for now assuming live view.
        
        var decision = grandDecisions[symbol]
        
        // If no decision exists (e.g. fresh launch), try to load it first
        if decision == nil {
            // print("🎙️ Argus Voice: No decision found for \(symbol), triggering load...")
            await loadArgusData(for: symbol) // This will populate argusDecisions
            decision = grandDecisions[symbol]
        }
        
        guard let grandDecision = decision else {
            // print("⚠️ Argus Voice: Could not obtain Grand Decision for \(symbol). Aborting report.")
            voiceReports[symbol] = "⚠️ Rapor oluşturulamadı: Konsey kararı bulunamadı."
            return
        }
        
        // Generate via Gemini (Omniscient) - V3
        let report = await ArgusVoiceService.shared.generateReport(decision: grandDecision)
        
        // Update Local State for UI
        voiceReports[symbol] = report
        
        // Persist to Trade if ID provided
        if let tid = tradeId {
            attachVoiceReport(tradeId: tid, report: report)
        }
    }
    
    private func attachVoiceReport(tradeId: UUID, report: String) {
        if let index = portfolio.firstIndex(where: { $0.id == tradeId }) {
            portfolio[index].voiceReport = report
            // didSet on portfolio triggers savePortfolio()
            print("🎙️ Argus Voice: Report attached to Trade \(tradeId). Saved.")
        }
    }
    
    func retryArgusExplanation(for symbol: String) async {
        guard let decision = argusDecisions[symbol] else { return }
        
        self.isLoadingArgus = true
        // Delay slightly to allow UI to update state
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        do {
            // Force fetch
            let explanation = try await ArgusExplanationService.shared.generateExplanation(for: decision)
            self.argusExplanations[symbol] = explanation
        } catch {
             print("⚠️ Argus Retry Failed: \(error)")
             self.argusExplanations[symbol] = ArgusExplanationService.shared.generateOfflineExplanation(
                for: decision,
                reason: error.localizedDescription
            )
        }
        self.isLoadingArgus = false
    }

    // MARK: - Orion Score Integration
    
    func loadOrionScore(for symbol: String, assetType: AssetType = .stock) async {
        // Phase 4: Delegate to OrionStore (Orion 2.0 MTF)
        // Store handles Multi-Timeframe Analysis now.
        await OrionStore.shared.ensureAnalysis(for: symbol)
        
        // Sync Widget (Legacy Side Effect)
        await MainActor.run {
             self.syncWidgetData()
        }
    }
    
    // MARK: - Experimental Lab
    @MainActor
    func loadSarTsiLab(symbol: String) async {
        // Reset State
        self.isLoadingSarTsiBacktest = true
        self.sarTsiErrorMessage = nil
        self.sarTsiBacktestResult = nil
        
        do {
            // Fetch 5 Years (approx 1260 trading days)
            let limit = 1260
            let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1day", limit: limit)
            let result = try await OrionSarTsiBacktester.shared.runBacktest(symbol: symbol, candles: candles)
            self.sarTsiBacktestResult = result
        } catch {
            self.sarTsiErrorMessage = error.localizedDescription
            self.sarTsiBacktestResult = nil
        }
        
        self.isLoadingSarTsiBacktest = false
    }

    // MARK: - Overreaction Hunter
    func analyzeOverreaction(symbol: String, candles: [Candle], atlas: Double?, aether: Double?) {
        Task {
            let result = OverreactionEngine.shared.analyze(
                symbol: symbol,
                candles: candles,
                atlasScore: atlas,
                aetherScore: aether
            )
            
            await MainActor.run {
                self.overreactionResult = result
            }
        }
    }
    
    // MARK: - Safe and Smart Asset Type Detection
    
    func detectAssetType(for symbol: String) async -> SafeAssetType {
        // 0. Check User Manual Override (Highest Priority)
        if let userOverride = SafeUniverseService.shared.getUserOverride(for: symbol) {
            return userOverride
        }
        
        // 1. Check SafeUniverse Overrides (System Defaults)
        if let type = SafeUniverseService.shared.getUniverseType(for: symbol) {
            return type
        }
        
        // 2. Check Known ETFs (MarketDataProvider)
        if isETF(symbol: symbol) {
            return .etf
        }
        
        // 3. Pattern Matching
        if symbol.hasSuffix("=F") { return .commodity } // Futures (Crude, Gold, Corn)
        if symbol.hasPrefix("^") { return .index } // Indices (^GSPC, ^IXIC)
        if symbol.contains("-USD") { return .crypto } // Crypto (BTC-USD)
        
        // 4. Common Keyword Heuristics -- skipped
        
        // 5. Hardcoded Common Commodities/ETFs check
        let commodityEtfs = ["GLD", "IAU", "SLV", "USO", "UNG", "DBC", "GSG", "PALL", "PPLT"]
        if commodityEtfs.contains(symbol) { return .commodity } // Or Gold
        
        // Default to Stock if unknown
        return .stock
    }

    // Manual Override Trigger
    @MainActor
    func updateAssetType(for symbol: String, to type: SafeAssetType) async {
        // 1. Save Preference
        SafeUniverseService.shared.setUserOverride(for: symbol, type: type)
        
        // 2. Clear relevant caches to force fresh calculation
        self.argusDecisions[symbol] = nil
        self.etfSummaries[symbol] = nil
        
        // 3. Reload Data with new Context
        await loadArgusData(for: symbol)
    }
    
    func checkIsEtf(_ symbol: String) async -> Bool {
        return isETF(symbol: symbol)
    }
    
    func loadEtfData(for symbol: String) async {
        await MainActor.run { isLoadingEtf = true }
        
        let isEtf = isETF(symbol: symbol)
        guard isEtf else {
             await MainActor.run { isLoadingEtf = false }
             return 
        }
        
        // Ensure price is up to date
        if quotes[symbol] == nil {
             let val = await MarketDataStore.shared.ensureQuote(symbol: symbol)
             if let q = val.value {
                 await MainActor.run { quotes[symbol] = q }
             }
        }
        
        let currentPrice = quotes[symbol]?.currentPrice ?? 0.0
        let orionScore = orionScores[symbol]?.score // Uses existing Orion calculation if available
        
        let summary = await ArgusEtfEngine.shared.analyzeETF(
            symbol: symbol,
            currentPrice: currentPrice,
            orionScore: orionScore,
            hermesScore: nil,
            holdingScoreProvider: nil
        )
        
        await MainActor.run {
            self.etfSummaries[symbol] = summary
            self.isLoadingEtf = false
        }
    }
    
    func hydrateAtlas() async {
        ArgusLogger.phase(.atlas, "Temel Analiz: \(watchlist.count) sembol işleniyor...")
        
        let now = Date()
        var symbolsToHydrate: [String] = []
        
        // 1. Önce hangi sembollerin güncellenmesi gerektiğini belirle
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol) {
                let daysOld = Calendar.current.dateComponents([.day], from: score.date, to: now).day ?? 999
                if daysOld < 7 {
                    continue // Valid cache
                }
            }
            symbolsToHydrate.append(symbol)
        }
        
        if symbolsToHydrate.isEmpty {
            ArgusLogger.info(.atlas, "Tüm veriler güncel (önbellek valid)")
            return
        }
        
        ArgusLogger.info(.atlas, "\(symbolsToHydrate.count) sembol güncellenecek")
        
        // 2. Batch halinde işle (5'er sembol - Yahoo rate limit hassasiyeti)
        let batchSize = 5
        let batches = stride(from: 0, to: symbolsToHydrate.count, by: batchSize).map {
            Array(symbolsToHydrate[$0..<min($0 + batchSize, symbolsToHydrate.count)])
        }
        
        var hydratedCount = 0
        
        for (batchIndex, batch) in batches.enumerated() {
            // Paralel yükleme
            await withTaskGroup(of: Void.self) { group in
                for symbol in batch {
                    group.addTask { [weak self] in
                        await self?.calculateFundamentalScore(for: symbol)
                    }
                }
            }
            
            ArgusLogger.batchProgress(module: .atlas, batch: batchIndex + 1, totalBatches: batches.count, processed: hydratedCount, total: symbolsToHydrate.count)
            
            // Rate limit için kısa bekleme (Yahoo 429 önlemi)
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        ArgusLogger.complete("Atlas Temel Analiz tamamlandı (\(hydratedCount) sembol)")
    }
    
    // MARK: - Widget Integration
    
    func persistToWidget(symbol: String, quote: Quote, decision: ArgusDecisionResult) {
        var currentScores = ArgusStorage.shared.loadWidgetScores()
        
        let miniData = WidgetScoreData(
            symbol: symbol,
            price: quote.currentPrice,
            changePercent: quote.percentChange,
            signal: decision.finalActionCore,
            lastUpdated: Date()
        )
        
        currentScores[symbol] = miniData
        ArgusStorage.shared.saveWidgetScores(scores: currentScores)
    }
    
    func generateAISignals() async {
        let signals = await AISignalService.shared.generateSignals(quotes: quotes, candles: candles)
        await MainActor.run {
            self.aiSignals = signals
        }
    }
    
    func refreshArgusLabStats() {
        Task {
            // Update historical returns if needed
            await ArgusLabEngine.shared.resolveUnifiedEvents(using: MarketDataProvider.shared)
            
            // Compute fresh stats
            let stats = ArgusLabEngine.shared.getStats(for: ArgusAlgoId.argusCoreV1)
            
            await MainActor.run {
                self.argusLabStats = stats
            }
        }
    }
    
    // MARK: - Athena (Smart Money / Factor Analysis)
    
    /// Athena faktör analizini çalıştır ve sonucu kaydet
    func loadAthena(for symbol: String) async {
        guard let candles = self.candles[symbol], candles.count >= 50 else {
            ArgusLogger.warning(.argus, "Athena: Yetersiz veri - \(symbol)")
            return
        }
        
        // Get financial data from cache if available
        let financialsEntry = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol)
        let financials = financialsEntry.flatMap { try? JSONDecoder().decode(FinancialsData.self, from: $0.data) }
        
        // Get atlas result if available
        let atlasResult = self.fundamentalScoreStore.getScore(for: symbol)
        
        // Get orion score if available
        let orionScore = self.orionScores[symbol]
        
        let athenaResult = AthenaFactorService.shared.calculateFactors(
            symbol: symbol,
            financials: financials,
            atlasResult: atlasResult,
            candles: candles,
            orionScore: orionScore
        )
        
        await MainActor.run {
            SignalStateViewModel.shared.athenaResults[symbol] = athenaResult
        }
        
        ArgusLogger.success(.argus, "Athena: \(symbol) analizi tamamlandı - Skor: \(athenaResult.factorScore)")
    }
    
    // MARK: - Demeter (Sector Analysis)
    
    /// Global sektör analizini çalıştır
    func loadDemeterSectorAnalysis() async {
        ArgusLogger.phase(.argus, "Demeter: Sektör analizi başlatılıyor...")
        
        await DemeterEngine.shared.analyze()
        
        ArgusLogger.success(.argus, "Demeter: Sektör analizi tamamlandı")
    }
    
    /// Belirli bir sembol için Demeter skoru al (sektör bazlı)
    /// Not: getDemeterScore zaten başka yerde tanımlıysa bu fonksiyonu kaldırıyoruz
    // getDemeterScore fonksiyonu zaten loadArgusData içinde satır 621'de kullanılıyor
    // Bu duplicate tanımı kaldırıyoruz çünkü çakışma yarattı
}
