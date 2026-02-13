
import Foundation
import Combine
import SwiftUI

/// AutoPilot Store
/// Otonom ticaret döngüsünü (Loop), durumunu ve lojistiğini yöneten Singleton Store.
/// TradingViewModel'den tamamen ayrıştırılmış execution katmanı.
final class AutoPilotStore: ObservableObject {
    static let shared = AutoPilotStore()
    
    // MARK: - State
    @Published var isAutoPilotEnabled: Bool = true {
        didSet {
            handleAutoPilotStateChange()
            // Sync with Legacy ViewModel if needed, or UI binds to this directly
            ExecutionStateViewModel.shared.isAutoPilotEnabled = isAutoPilotEnabled
        }
    }
    
    @Published var scoutingCandidates: [TradeSignal] = []
    @Published var scoutLogs: [ScoutLog] = []
    
    // Internal Loop State
    private var autoPilotTimer: Timer?
    
    // Dependencies
    private let portfolioStore = PortfolioStore.shared
    // Accessing MarketDataStore via shared instance in logic
    
    private init() {
        // Restore state if persisted (Optional)
        self.isAutoPilotEnabled = ExecutionStateViewModel.shared.isAutoPilotEnabled
    }
    
    // MARK: - Loop Management
    
    func startAutoPilotLoop() {
        print("🤖 AutoPilotStore: Starting Loop...")
        self.isAutoPilotEnabled = true // Force enable explicitly
        startTimer()
    }
    
    func stopAutoPilotLoop() {
        print("🤖 AutoPilotStore: Stopping Loop...")
        autoPilotTimer?.invalidate()
        autoPilotTimer = nil
    }
    
    private func handleAutoPilotStateChange() {
        if isAutoPilotEnabled {
            startTimer()
        } else {
            stopAutoPilotLoop()
        }
    }
    
    private func startTimer() {
        autoPilotTimer?.invalidate()
        
        print("🚀 AutoPilotStore: Timer başlatılıyor...")
        print("📊 AutoPilotStore: isAutoPilotEnabled = \(isAutoPilotEnabled)")
        print("📋 AutoPilotStore: Watchlist count = \(WatchlistStore.shared.items.count)")
        
        autoPilotTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.runAutoPilot()
            }
        }
        // Run immediately once
        Task {
            await runAutoPilot()
        }
    }
    
    // MARK: - Core Execution Logic
    
    func runAutoPilot() async {
        guard isAutoPilotEnabled else { return }
        
        print("🔄 AutoPilotStore: runAutoPilot başlatılıyor...")
        
        let symbols = WatchlistStore.shared.items
        
        // Prepare Quotes Map
        let simpleQuotes = MarketDataStore.shared.liveQuotes
        
        // Snapshot Portfolio State safely
        let portfolio = portfolioStore.trades
        let balance = portfolioStore.globalBalance
        let bistBalance = portfolioStore.bistBalance
        let equity = portfolioStore.getGlobalEquity(quotes: simpleQuotes)
        let bistEquity = portfolioStore.getBistEquity(quotes: simpleQuotes)
        
        print("💰 AutoPilotStore: Bakiye - Global: $\(balance), BIST: ₺\(bistBalance)")
        print("💎 AutoPilotStore: Equity - Global: $\(equity), BIST: ₺\(bistEquity)")
        print("📋 AutoPilotStore: \(symbols.count) sembol taranacak...")
        
        // Build Portfolio Map
        var portfolioMap: [String: Trade] = [:]
        for trade in portfolio where trade.isOpen {
            if portfolioMap[trade.symbol] == nil {
                portfolioMap[trade.symbol] = trade
            }
        }
        if portfolioMap.isEmpty {
            ArgusLogger.warning(.autopilot, "Hiç açık pozisyon yok, portföy boş.")
        } else {
             ArgusLogger.info(.autopilot, "Açık pozisyon sayısı: \(portfolioMap.count)")
        }
        
        // 1. Get Signals (Argus Engine) - Offload to Background
        let results = await Task.detached(priority: .userInitiated) {
            return await AutoPilotService.shared.scanMarket(
                symbols: symbols,
                equity: equity,
                bistEquity: bistEquity,
                buyingPower: balance,
                bistBuyingPower: bistBalance,
                portfolio: portfolioMap
            )
        }.value
        
        let signals = results.signals
        let logs = results.logs
        
        if !signals.isEmpty {
            ArgusLogger.success(.autopilot, "Tespit edilen sinyal sayısı: \(signals.count)")
        } else {
            ArgusLogger.info(.autopilot, "Yeni sinyal bulunamadı.")
        }
        
        if !signals.isEmpty || !logs.isEmpty {
            await MainActor.run {
                // Update UI State
                self.scoutingCandidates = signals
                
                let combinedLogs = logs + self.scoutLogs
                self.scoutLogs = Array(combinedLogs.prefix(100))
                
                print("♻️ AutoPilotStore: Updated with \(logs.count) new logs.")
                
                // Process Buy Signals -> Grand Council -> Executor
                self.processSignals(signals)
            }
            let skipLogs = logs.filter { $0.status == "ATLA" || $0.status == "RED" || $0.status == "COOLDOWN" }
            if !skipLogs.isEmpty {
                let grouped = Dictionary(grouping: skipLogs, by: { $0.reason })
                let topReasons = grouped
                    .map { "\($0.value.count)x \($0.key)" }
                    .sorted()
                    .prefix(5)
                    .joined(separator: " | ")
                print("🟡 AUTOPILOT-SKIP-SUMMARY: \(topReasons)")
                
                for item in skipLogs.prefix(12) {
                    print("🟡 AUTOPILOT-SKIP-DETAIL: \(item.symbol) -> [\(item.status)] \(item.reason)")
                }
            }
        } else {
            print("⚠️ AutoPilotStore: Hiç sinyal veya log yok!")
        }
    }
    
    // MARK: - Intent and Discovery Handling
    
    func analyzeDiscoveryCandidates(_ tickers: [String], source: NewsInsight) async {
        // Simple forward pass to logic if needed, or implement full logic here.
        // For now, we print to show connected.
        print("🤖 AutoPilotStore: Discovery Analysis for \(tickers.count) candidates from \(source.headline)")
        // Implementation Todo: Move full logic from TVM if complex, or keep shim.
        // Given Phase C requires extraction, we should implement logic eventually.
        // For now, implementing basic loop to satisfy compilation of call from TVM
    }

    func handleAutoPilotIntent(_ notification: Notification) {
        // Basic Intent Handling (Stub)
        print("🤖 AutoPilotStore: Intent Received")
    }

    @MainActor
    private func processSignals(_ signals: [TradeSignal]) {
        print("🔍 AutoPilotStore: Toplam \(signals.count) sinyal işleniyor...")
        print("📊 Sinyal detayları: \(signals.map { "\($0.symbol): \($0.action)" })")
        
        Task {
            var decisionsForExecution: [String: ArgusGrandDecision] = [:]
            var buyCount = 0
            for signal in signals where signal.action == .buy {
                buyCount += 1
                ArgusLogger.info(.autopilot, "💡 BUY sinyali bulundu: \(signal.symbol) - \(signal.reason)")
                
                // BIST Check
                if SymbolResolver.shared.isBistSymbol(signal.symbol) {
                    if !isBistMarketOpen() { continue }
                }
                
                // Get Data
                guard let candles = await MarketDataStore.shared.ensureCandles(symbol: signal.symbol, timeframe: "1day").value, !candles.isEmpty else {
                    continue
                }
                
                // Convene Grand Council
                let macro = await MacroSnapshotService.shared.getSnapshot()
                
                // Prepare BIST Input if needed
                var sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil
                if SymbolResolver.shared.isBistSymbol(signal.symbol) {
                     sirkiyeInput = await prepareSirkiyeInput(macro: macro)
                }
                
                // Fetch Snapshot for Argus 3.0
                let snapshot = try? await FinancialSnapshotService.shared.fetchSnapshot(symbol: signal.symbol)

                let decision = await ArgusGrandCouncil.shared.convene(
                    symbol: signal.symbol,
                    candles: candles,
                    snapshot: snapshot, // CHANGED: Pass Real Snapshot
                    macro: macro,
                    news: nil,
                    engine: .pulse,
                    sirkiyeInput: sirkiyeInput,
                    origin: "AUTOPILOT_STORE"
                )
                
                SignalStateViewModel.shared.grandDecisions[signal.symbol] = decision
                decisionsForExecution[signal.symbol] = decision
                print("🏛️ AutoPilotStore: Grand Council Decision for \(signal.symbol): \(decision.action.rawValue)")
            }

            if buyCount == 0 {
                print("🟡 AutoPilotStore: Bu turda BUY sinyali çıkmadı.")
            }

            // Açık pozisyonlardaki acil likidasyon kararlarını da yürütücüye taşı
            let openSymbols = Set(self.portfolioStore.trades.filter { $0.isOpen }.map { $0.symbol })
            for symbol in openSymbols {
                if let cachedDecision = SignalStateViewModel.shared.grandDecisions[symbol] {
                    decisionsForExecution[symbol] = cachedDecision
                }
            }

            if decisionsForExecution.isEmpty {
                print("⚠️ AutoPilotStore: Yürütülecek güncel karar yok (signals/open positions).")
            }
            
             // Execute Decisions (Trade Brain)
             // Note: We need to access 'quotes'. MarketDataStore has them but TradeBrain might need a map.
              let simpleQuotes = MarketDataStore.shared.liveQuotes
              
              // Prepare Orion Scores & Candles for Governance
              var orionScoresMap: [String: OrionScoreResult] = [:]
              var candlesMap: [String: [Candle]] = [:]
              
              for (symbol, _) in decisionsForExecution {
                  if let score = SignalStateViewModel.shared.orionScores[symbol] {
                      orionScoresMap[symbol] = score
                  } else {
                      // Attempt lazy calculate if missing? Or rely on defaults
                      // For now, let TradeExecutor default to 50 if missing
                  }
                  
                  if let cVal = MarketDataStore.shared.candles[symbol], let candles = cVal.value {
                      candlesMap[symbol] = candles
                  }
              }
              
              await TradeBrainExecutor.shared.evaluateDecisions(
                  decisions: decisionsForExecution,
                  portfolio: self.portfolioStore.trades,
                  quotes: simpleQuotes,
                  balance: self.portfolioStore.globalBalance,
                  bistBalance: self.portfolioStore.bistBalance,
                  orionScores: orionScoresMap,
                  candles: candlesMap
              )
             
             // Check Plan Triggers
             await self.checkPlanTriggers()
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Helpers
    
    private func prepareSirkiyeInput(macro: MacroSnapshot) async -> SirkiyeEngine.SirkiyeInput? {
        let quotes = MarketDataStore.shared.liveQuotes
        guard let usdQuote = quotes["USD/TRY"] else { return nil }

        // BorsaPy'den canlı makro verileri paralel çek
        async let brentTask = { try? await BorsaPyProvider.shared.getBrentPrice() }()
        async let inflationTask = { try? await BorsaPyProvider.shared.getInflationData() }()
        async let policyRateTask = { try? await BorsaPyProvider.shared.getPolicyRate() }()
        async let xu100Task = { try? await BorsaPyProvider.shared.getXU100() }()
        async let goldTask = { try? await BorsaPyProvider.shared.getGoldPrice() }()

        let (brent, inflation, policyRate, xu100, gold) = await (brentTask, inflationTask, policyRateTask, xu100Task, goldTask)

        var xu100Change: Double? = nil
        var xu100Value: Double? = nil
        if let xu = xu100 {
            xu100Value = xu.last
            if xu.open > 0 {
                xu100Change = ((xu.last - xu.open) / xu.open) * 100
            }
        }

        return SirkiyeEngine.SirkiyeInput(
            usdTry: usdQuote.currentPrice,
            usdTryPrevious: usdQuote.previousClose ?? usdQuote.currentPrice,
            dxy: macro.dxy,
            brentOil: brent?.last ?? macro.brent,
            globalVix: macro.vix,
            newsSnapshot: nil,
            currentInflation: inflation?.yearlyInflation ?? 45.0,
            policyRate: policyRate ?? 50.0,
            xu100Change: xu100Change,
            xu100Value: xu100Value,
            goldPrice: gold?.last
        )
    }
    
    private func isBistMarketOpen() -> Bool {
        MarketStatusService.shared.isBistOpen()
    }
    
    private func checkPlanTriggers() async {
        let openTrades = portfolioStore.trades.filter { $0.isOpen }
        guard !openTrades.isEmpty else { return }

        let quotes = MarketDataStore.shared.liveQuotes
        var triggeredCount = 0

        for trade in openTrades {
            guard let currentPrice = quotes[trade.symbol]?.currentPrice, currentPrice > 0 else {
                continue
            }

            let grandDecision = SignalStateViewModel.shared.grandDecisions[trade.symbol]
            guard let action = PositionPlanStore.shared.checkTriggers(
                trade: trade,
                currentPrice: currentPrice,
                grandDecision: grandDecision
            ) else {
                continue
            }

            triggeredCount += 1
            PositionPlanStore.shared.markStepCompleted(tradeId: trade.id, stepId: action.id)

            switch action.action {
            case .sellAll:
                _ = portfolioStore.sell(
                    tradeId: trade.id,
                    currentPrice: currentPrice,
                    reason: "PLAN_SELL_ALL: \(action.description)"
                )
                PositionPlanStore.shared.completePlan(tradeId: trade.id)

            case .sellPercent(let percent):
                let clampedPercent = max(1, min(percent, 100))
                if clampedPercent >= 100 {
                    _ = portfolioStore.sell(
                        tradeId: trade.id,
                        currentPrice: currentPrice,
                        reason: "PLAN_SELL_100: \(action.description)"
                    )
                    PositionPlanStore.shared.completePlan(tradeId: trade.id)
                } else {
                    _ = portfolioStore.trim(
                        tradeId: trade.id,
                        percentage: clampedPercent,
                        currentPrice: currentPrice,
                        reason: "PLAN_TRIM_\(Int(clampedPercent)): \(action.description)"
                    )
                }

            case .reduceAndHold(let percent):
                let clampedPercent = max(1, min(percent, 100))
                if clampedPercent >= 100 {
                    _ = portfolioStore.sell(
                        tradeId: trade.id,
                        currentPrice: currentPrice,
                        reason: "PLAN_REDUCE_100: \(action.description)"
                    )
                    PositionPlanStore.shared.completePlan(tradeId: trade.id)
                } else {
                    _ = portfolioStore.trim(
                        tradeId: trade.id,
                        percentage: clampedPercent,
                        currentPrice: currentPrice,
                        reason: "PLAN_REDUCE_\(Int(clampedPercent)): \(action.description)"
                    )
                }

            case .alert(let message):
                let alert = TradeBrainAlert(
                    type: .planTriggered,
                    symbol: trade.symbol,
                    message: message,
                    actionDescription: action.description,
                    priority: .medium
                )
                NotificationCenter.default.post(
                    name: .tradeBrainAlert,
                    object: nil,
                    userInfo: ["alert": alert]
                )

            case .moveStopTo(_), .moveStopByPercent(_), .activateTrailingStop(_), .setBreakeven, .addPercent(_), .addFixed(_), .reevaluate, .doNothing:
                // Bu aksiyonlar için Store tarafında güvenli mutasyon API'si eksik.
                // Şimdilik adım işaretlenir, yalnızca bilgilendirme logu bırakılır.
                print("ℹ️ AutoPilotStore: Plan aksiyonu loglandı, icra edilmedi -> \(trade.symbol): \(action.description)")
            }
        }

        if triggeredCount > 0 {
            print("🧠 AutoPilotStore: \(triggeredCount) plan tetikleyicisi işlendi.")
        }
    }
    
    // MARK: - Passive Scanner
    func processHighConvictionCandidate(symbol: String, score: Double) async {
         // Logic from TVM+AutoPilot
         guard isAutoPilotEnabled else { return }
         // ... (Logic to be migrated)
    }
    
    // MARK: - Trade Brain 3.0 Learning Loop
    
    func runDailyLearningCycle() async {
        print("Trade Brain 3.0: Gunluk ogrenme dongusu baslatiliyor...")
        
        let learningService = TradeBrainLearningService.shared
        let confidenceCalibration = ConfidenceCalibrationService.shared
        
        let currentPrices = await getCurrentPricesForLearning()
        
        let processed = await learningService.processMaturedObservations(currentPrices: currentPrices)
        
        let stats = await learningService.getLearningStats()
        
        let calibrationStats = await confidenceCalibration.getOverallStats()
        
        print("Trade Brain 3.0: \(processed) karar degerlendirildi, \(stats.pendingCount) bekleyen")
        print("Trade Brain 3.0: Genel basari: %\(Int(calibrationStats.overallWinRate * 100))")
    }
    
    func triggerLearningForClosedTrade(
        symbol: String,
        entryPrice: Double,
        exitPrice: Double,
        holdingDays: Int
    ) async {
        let pnlPercent = ((exitPrice - entryPrice) / entryPrice) * 100
        let wasCorrect = pnlPercent > 0
        
        await TradeBrainExecutor.shared.recordTradeOutcome(
            symbol: symbol,
            wasCorrect: wasCorrect,
            pnlPercent: pnlPercent,
            holdingDays: holdingDays
        )
        
        print("Trade Brain 3.0: Kapali islem ogrenmesi - \(symbol) \(wasCorrect ? "KAR" : "ZARAR")")
    }
    
    private func getCurrentPricesForLearning() async -> [String: Double] {
        let quotes = MarketDataStore.shared.liveQuotes
        var prices: [String: Double] = [:]
        
        for (symbol, quote) in quotes {
            prices[symbol] = quote.currentPrice
        }
        
        return prices
    }
    
    // MARK: - Enhanced Decision with Trade Brain 3.0
    
    func makeEnhancedDecision(
        symbol: String,
        candles: [Candle],
        grandDecision: ArgusGrandDecision,
        orionScore: OrionScoreResult?,
        atlasScore: Double?
    ) async -> EnhancedTradeBrainDecision? {
        return await TradeBrainExecutor.shared.makeEnhancedDecision(
            symbol: symbol,
            grandDecision: grandDecision,
            candles: candles,
            orionScore: orionScore,
            atlasScore: atlasScore
        )
    }
}
