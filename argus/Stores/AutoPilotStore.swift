
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

    /// Son tarama özeti — "Trade neden olmuyor?" sorusuna somut cevap.
    /// Durum Panosu bu snapshot'ı okuyup "SON TARAMA" kartında gösterir.
    struct ScanSummary {
        let timestamp: Date
        let scannedCount: Int
        let signalCount: Int
        let skippedCount: Int
        let topSkipReasons: [String]  // Örn: "12x düşük güven", "8x cooldown", "4x likidite"
        let globalBalance: Double
        let bistBalance: Double
        let openPositions: Int

        static let empty = ScanSummary(
            timestamp: Date.distantPast,
            scannedCount: 0, signalCount: 0, skippedCount: 0,
            topSkipReasons: [],
            globalBalance: 0, bistBalance: 0, openPositions: 0
        )

        var hasRun: Bool { timestamp != Date.distantPast }
        var ageSeconds: TimeInterval { Date().timeIntervalSince(timestamp) }
    }
    @Published var lastScanSummary: ScanSummary = .empty
    
    // Internal Loop State
    private var autoPilotTimer: Timer?
    
    // Dependencies
    private let portfolioStore = PortfolioStore.shared
    // Accessing MarketDataStore via shared instance in logic
    
    // HARMONY — Otopilot piyasa bağlamına göre pozisyon çarpanı okur.
    // Kullanıcı toggle kapalıysa kapalı kalır, AÇIKKEN bu çarpan agresif/temkinli
    // ayarlar (0.40–1.20). Coordinator otopilotun enabled durumuna ASLA dokunmaz.
    private var contextMultiplier: Double = 1.0
    private var contextCancellable: AnyCancellable?
    private var balanceCancellable: AnyCancellable?
    private var lastKnownGlobalBalance: Double = 0
    private var lastKnownBistBalance: Double = 0

    private init() {
        // Restore state if persisted (Optional)
        self.isAutoPilotEnabled = ExecutionStateViewModel.shared.isAutoPilotEnabled

        // Coordinator'ı başlat ve dinle
        MarketContextCoordinator.shared.start()
        contextCancellable = MarketContextCoordinator.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.handleMarketContextUpdate(snapshot)
            }

        // FİX #2 (irtibat): PortfolioStore.globalBalance değişimlerini
        // dinle. Önceki mimaride AutoPilot bakiye değişikliğinden habersizdi —
        // kullanıcı para yatırdığında/çektiğinde pozisyon sizing eski balance
        // üzerinden hesaplanmaya devam ediyordu. Artık anlamlı değişimde
        // (> $500 veya ₺10k) log + gerekli state invalidation.
        balanceCancellable = Publishers.CombineLatest(
            PortfolioStore.shared.$globalBalance,
            PortfolioStore.shared.$bistBalance
        )
        .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
        .sink { [weak self] (usd, tl) in
            self?.handleBalanceChange(usd: usd, tl: tl)
        }
    }

    private func handleBalanceChange(usd: Double, tl: Double) {
        let usdDelta = Swift.abs(usd - lastKnownGlobalBalance)
        let tlDelta = Swift.abs(tl - lastKnownBistBalance)
        guard usdDelta > 500 || tlDelta > 10_000 else {
            lastKnownGlobalBalance = usd
            lastKnownBistBalance = tl
            return
        }
        ArgusLogger.info(
            "💰 AutoPilot↔Portfolio: Balance değişti — USD \(Int(lastKnownGlobalBalance))→\(Int(usd)) (Δ\(Int(usdDelta))) | TRY \(Int(lastKnownBistBalance))→\(Int(tl)) (Δ\(Int(tlDelta)))",
            category: "OTOPİLOT"
        )
        lastKnownGlobalBalance = usd
        lastKnownBistBalance = tl
        // Bakiye değişimi — context re-evaluate (opportunity mode re-check)
        let snapshot = MarketContextCoordinator.shared.snapshot
        handleMarketContextUpdate(snapshot)
    }

    /// Piyasa bağlamı değiştiğinde otopilot davranışını ayarlar.
    /// Prensip: kullanıcı yetkisine (isAutoPilotEnabled) dokunma, sadece çarpanla davran.
    private func handleMarketContextUpdate(_ snapshot: MarketContextCoordinator.Snapshot) {
        let prev = contextMultiplier
        contextMultiplier = snapshot.positionMultiplier

        // Anlamlı değişim → log + (gelecekte notify). Kullanıcının "harmony" isteği:
        // sistem ne gördüğünü haber versin.
        if Swift.abs(prev - contextMultiplier) >= 0.10 {
            ArgusLogger.info(
                "AutoPilot↔Context uyumu: \(snapshot.humanSummary)",
                category: "OTOPİLOT.CONTEXT"
            )
        }

        // Fırsat modunda loop interval'ini hızlandır (120sn = 2 dk), diğerlerinde 180sn.
        // Scan süresinden (1-2 dk) kısa interval isScanning guard'ına takılır, boşa döner.
        if snapshot.opportunityMode, let timer = autoPilotTimer, timer.timeInterval > 150 {
            restartTimer(interval: 120)
        } else if !snapshot.opportunityMode, let timer = autoPilotTimer, timer.timeInterval < 150 {
            restartTimer(interval: 180)
        }
    }

    /// Otopilot'un pozisyon boyutu hesabında kullanacağı çarpan (0.4-1.2).
    /// Hiçbir zaman 0 dönmez — açıksa taban seviyede de olsa trade yapabilsin.
    public func currentContextMultiplier() -> Double {
        return contextMultiplier
    }

    /// Koruyucu mod aktif mi? Pozisyon açmadan önce context check.
    public func isProtectiveModeActive() -> Bool {
        return MarketContextCoordinator.shared.snapshot.protectiveMode
    }

    /// Fırsat penceresi mi? Daha agresif giriş için.
    public func isOpportunityModeActive() -> Bool {
        return MarketContextCoordinator.shared.snapshot.opportunityMode
    }

    private func restartTimer(interval: TimeInterval) {
        guard isAutoPilotEnabled else { return }
        autoPilotTimer?.invalidate()
        autoPilotTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.runAutoPilot()
            }
        }
        ArgusLogger.info("AutoPilotStore: Timer interval güncellendi → \(Int(interval))sn", category: "OTOPİLOT")
    }
    
    // MARK: - Loop Management
    
    func startAutoPilotLoop() {
        ArgusLogger.info("AutoPilotStore: Starting Loop...", category: "OTOPİLOT")
        // Not: `isAutoPilotEnabled = true` didSet → handleAutoPilotStateChange →
        // startTimer zaten çağrılıyor. Burada ekstra startTimer() çağırmak
        // üçlü immediate-run tetiklemesine (triple trigger bug) yol açıyordu.
        // isScanning guard'ı ikincil/üçüncül scan'leri "Önceki tarama hâlâ
        // çalışıyor" ATLA'sı ile bitiriyor, sonuç: signals=0, alım yok.
        if isAutoPilotEnabled {
            // Zaten açıksa didSet tetiklenmez — timer yoksa elle başlat.
            if autoPilotTimer == nil { startTimer() }
        } else {
            self.isAutoPilotEnabled = true // didSet → startTimer()
        }
    }
    
    func stopAutoPilotLoop() {
        ArgusLogger.info("AutoPilotStore: Stopping Loop...", category: "OTOPİLOT")
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
    
    /// Son immediate-run zamanı. Kısa pencerede ard arda startTimer çağrılsa
    /// bile immediate-run sadece bir kez yapılır → triple trigger bug'ına karşı.
    private var lastImmediateRunAt: Date?

    /// Son günlük öğrenme döngüsü zamanı. runAutoPilot her tetiklendiğinde
    /// 24h+ geçtiyse runDailyLearningCycle çağrılır (rate-limit). Eskiden
    /// runDailyLearningCycle hiçbir yerden çağrılmıyordu — TradeBrain Learning
    /// + RegimeMemory cache ölü kalıyordu. Bu hook learning zincirini canlı
    /// scan döngüsüne bağlar.
    private var lastDailyLearningRunAt: Date?

    private func startTimer() {
        autoPilotTimer?.invalidate()

        ArgusLogger.info("AutoPilotStore: Timer başlatılıyor...", category: "OTOPİLOT")
        ArgusLogger.info("AutoPilotStore: isAutoPilotEnabled = \(isAutoPilotEnabled)", category: "OTOPİLOT")
        ArgusLogger.info("AutoPilotStore: Watchlist count = \(WatchlistStore.shared.items.count)", category: "OTOPİLOT")

        // 171 sembol taraması + BorsaPy yavaşlığı + Gemini 429 retry'leri toplamda
        // 1-2 dk sürüyor. Timer 60sn ise ikinci/üçüncü loop isScanning guard'ı ile
        // boşa dönüyordu. 180sn (3 dk) interval ile her tur gerçekten çalışıyor.
        autoPilotTimer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.runAutoPilot()
            }
        }

        // Immediate run — aynı pencerede (2sn) birden çok startTimer çağrılırsa
        // sadece ilkinde tetikle. Bu guard olmadan init-didSet + bootstrap
        // aynı saniyede üçlü scan başlatıyordu.
        let now = Date()
        if let last = lastImmediateRunAt, now.timeIntervalSince(last) < 2.0 {
            ArgusLogger.warn("AutoPilotStore: startTimer re-entry (<2s), immediate-run atlandı", category: "OTOPİLOT")
            return
        }
        lastImmediateRunAt = now
        Task {
            await runAutoPilot()
        }
    }
    
    // MARK: - Core Execution Logic
    
    func runAutoPilot() async {
        print("🚨🚨🚨 runAutoPilot ENTERED — enabled=\(isAutoPilotEnabled)")
        guard isAutoPilotEnabled else {
            print("🚨 runAutoPilot ATLANDI — Otopilot kapalı")
            return
        }

        ArgusLogger.info("AutoPilotStore: runAutoPilot başlatılıyor...", category: "OTOPİLOT")
        ArgusLogger.warn("🚨 runAutoPilot TRIGGERED @ \(Date())", category: "OTOPİLOT")

        // Onarım 4: Günlük öğrenme döngüsü hook'u. 24h+ geçtiyse veya hiç
        // çalışmadıysa background'da tetikle. Mevcut scan loop'u beklemiyor.
        let needsLearning: Bool = {
            guard let last = lastDailyLearningRunAt else { return true }
            return Date().timeIntervalSince(last) >= (24 * 3600)
        }()
        if needsLearning {
            lastDailyLearningRunAt = Date()
            Task.detached(priority: .background) { [weak self] in
                await self?.runDailyLearningCycle()
            }
        }

        // FİX G (observability): Piyasa durumu her turda loglansın.
        // Önceki davranışta BIST/Global piyasa kapalı olunca sessizce atlanıyordu.
        // Kullanıcı "neden BIST alımı yok?" sorusuna yanıt bulamıyordu.
        let globalOpen = MarketStatusService.shared.canTrade(for: .global)
        let bistOpen = MarketStatusService.shared.canTrade(for: .bist)
        ArgusLogger.info(
            "📍 Piyasa durumu: Global=\(globalOpen ? "AÇIK" : "KAPALI") | BIST=\(bistOpen ? "AÇIK" : "KAPALI")",
            category: "OTOPİLOT"
        )
        if !bistOpen {
            let bistCount = WatchlistStore.shared.items.filter { $0.hasSuffix(".IS") }.count
            ArgusLogger.info("  ⏱️ BIST kapalı — \(bistCount) BIST sembolü bu turda atlanacak", category: "OTOPİLOT")
        }
        
        let symbols = WatchlistStore.shared.items
        
        // Prepare Quotes Map
        let simpleQuotes = MarketDataStore.shared.liveQuotes
        
        // Snapshot Portfolio State safely
        let portfolio = portfolioStore.trades
        let balance = portfolioStore.globalBalance
        let bistBalance = portfolioStore.bistBalance
        let equity = portfolioStore.getGlobalEquity(quotes: simpleQuotes)
        let bistEquity = portfolioStore.getBistEquity(quotes: simpleQuotes)
        
        ArgusLogger.info("AutoPilotStore: Bakiye - Global: $\(balance), BIST: ₺\(bistBalance)", category: "OTOPİLOT")
        ArgusLogger.info("AutoPilotStore: Equity - Global: $\(equity), BIST: ₺\(bistEquity)", category: "OTOPİLOT")
        ArgusLogger.info("AutoPilotStore: \(symbols.count) sembol taranacak...", category: "OTOPİLOT")
        
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
            let buyList = signals.filter { $0.action == .buy }.map { $0.symbol }
            let sellList = signals.filter { $0.action == .sell }.map { $0.symbol }
            ArgusLogger.info(.autopilot, "📌 BUY sinyalleri (\(buyList.count)): \(buyList.prefix(10).joined(separator: ", "))")
            if !sellList.isEmpty {
                ArgusLogger.info(.autopilot, "📌 SELL sinyalleri (\(sellList.count)): \(sellList.prefix(10).joined(separator: ", "))")
            }
        } else {
            ArgusLogger.info(.autopilot, "Yeni sinyal bulunamadı.")
        }
        
        // Skip özet — UI'da göstermek için
        let skipLogs = logs.filter { $0.status == "ATLA" || $0.status == "RED" || $0.status == "COOLDOWN" }
        let topReasonsArray: [String] = {
            guard !skipLogs.isEmpty else { return [] }
            let grouped = Dictionary(grouping: skipLogs, by: { $0.reason })
            return grouped
                .map { "\($0.value.count)x \($0.key)" }
                .sorted()
                .prefix(5)
                .map { $0 }
        }()

        // Tarama özetini her iterasyonda güncelle (boş sonuçta da — "hiç sinyal yok" bilgisi bile değerli)
        let summary = ScanSummary(
            timestamp: Date(),
            scannedCount: symbols.count,
            signalCount: signals.count,
            skippedCount: skipLogs.count,
            topSkipReasons: topReasonsArray,
            globalBalance: balance,
            bistBalance: bistBalance,
            openPositions: portfolioMap.count
        )
        await MainActor.run {
            self.lastScanSummary = summary
        }

        // 🚨 TRACE: scan return edildi, processSignals'a geçilecek
        print("🚨🚨🚨 SCAN RETURNED — signals=\(signals.count), logs=\(logs.count)")
        ArgusLogger.warn("🚨 SCAN RETURNED — signals=\(signals.count), logs=\(logs.count)", category: "OTOPİLOT")
        // 🔬 FORENSIC: İlk 20 log'u tek tek dök — stuck/skip tespiti için
        for (idx, l) in logs.prefix(20).enumerated() {
            print("🔬 LOG[\(idx)]: \(l.symbol) [\(l.status)] \(l.reason)")
            ArgusLogger.warn("🔬 LOG[\(idx)]: \(l.symbol) [\(l.status)] \(l.reason)", category: "OTOPİLOT")
        }

        if !signals.isEmpty || !logs.isEmpty {
            await MainActor.run {
                self.scoutingCandidates = signals
                let combinedLogs = logs + self.scoutLogs
                self.scoutLogs = Array(combinedLogs.prefix(100))
                ArgusLogger.info("AutoPilotStore: Updated with \(logs.count) new logs.", category: "OTOPİLOT")
                print("🚨🚨🚨 CALLING processSignals with \(signals.count) signals")
                ArgusLogger.warn("🚨 CALLING processSignals (\(signals.count) sinyal)", category: "OTOPİLOT")
                self.processSignals(signals)
            }
            if !skipLogs.isEmpty {
                ArgusLogger.warn("AUTOPILOT-SKIP-SUMMARY: \(topReasonsArray.joined(separator: " | "))", category: "OTOPİLOT")
                for item in skipLogs.prefix(12) {
                    ArgusLogger.warn("AUTOPILOT-SKIP-DETAIL: \(item.symbol) -> [\(item.status)] \(item.reason)", category: "OTOPİLOT")
                }
            }
        } else {
            ArgusLogger.warn("AutoPilotStore: Hiç sinyal veya log yok!", category: "OTOPİLOT")
        }
    }
    
    // MARK: - Intent and Discovery Handling
    
    func analyzeDiscoveryCandidates(_ tickers: [String], source: NewsInsight) async {
        // Simple forward pass to logic if needed, or implement full logic here.
        // For now, we print to show connected.
        ArgusLogger.info("AutoPilotStore: Discovery Analysis for \(tickers.count) candidates from \(source.headline)", category: "OTOPİLOT")
        // Implementation Todo: Move full logic from TVM if complex, or keep shim.
        // Given Phase C requires extraction, we should implement logic eventually.
        // For now, implementing basic loop to satisfy compilation of call from TVM
    }

    func handleAutoPilotIntent(_ notification: Notification) {
        // Basic Intent Handling (Stub)
        ArgusLogger.info("AutoPilotStore: Intent Received", category: "OTOPİLOT")
    }

    @MainActor
    private func processSignals(_ signals: [TradeSignal]) {
        print("🚨🚨🚨 processSignals ENTERED with \(signals.count) signals")
        ArgusLogger.warn("🚨 processSignals ENTERED (\(signals.count))", category: "OTOPİLOT")
        ArgusLogger.info("AutoPilotStore: Toplam \(signals.count) sinyal işleniyor...", category: "OTOPİLOT")
        ArgusLogger.info("Sinyal detayları: \(signals.map { "\($0.symbol): \($0.action)" })", category: "OTOPİLOT")

        Task {
            print("🚨🚨🚨 processSignals Task STARTED")
            var decisionsForExecution: [String: ArgusGrandDecision] = [:]
            var buyCount = 0
            for signal in signals {
                if signal.action == .sell {
                    if let openTrade = self.portfolioStore.trades.first(where: { $0.isOpen && $0.symbol == signal.symbol }),
                       let currentPrice = MarketDataStore.shared.liveQuotes[signal.symbol]?.currentPrice {
                        if let trim = signal.trimPercentage, trim > 0, trim < 1 {
                            let trimPercent = max(1, min(trim * 100, 99))
                            _ = self.portfolioStore.trim(
                                tradeId: openTrade.id,
                                percentage: trimPercent,
                                currentPrice: currentPrice,
                                reason: "AUTOPILOT_SIGNAL_TRIM_\(Int(trimPercent))"
                            )
                            ArgusLogger.warn(
                                "AutoPilotStore: SELL sinyali trim uyguladı -> \(signal.symbol) %\(Int(trimPercent))",
                                category: "OTOPİLOT"
                            )
                        } else {
                            _ = self.portfolioStore.sell(
                                tradeId: openTrade.id,
                                currentPrice: currentPrice,
                                reason: "AUTOPILOT_SIGNAL_LIQUIDATE"
                            )
                            ArgusLogger.warn("AutoPilotStore: SELL sinyali tam çıkış uyguladı -> \(signal.symbol)", category: "OTOPİLOT")
                        }
                    } else {
                        ArgusLogger.info("AutoPilotStore: SELL sinyali açık pozisyon bulamadı -> \(signal.symbol)", category: "OTOPİLOT")
                    }
                    continue
                }

                guard signal.action == .buy else { continue }
                buyCount += 1
                ArgusLogger.info(.autopilot, "💡 BUY sinyali bulundu: \(signal.symbol) - \(signal.reason)")

                // BIST Check
                if SymbolResolver.shared.isBistSymbol(signal.symbol) {
                    if !isBistMarketOpen() {
                        ArgusLogger.warn("AutoPilotStore: BIST kapalı, \(signal.symbol) atlandı", category: "OTOPİLOT")
                        continue
                    }
                }

                // Get Data — candle yoksa signal hâlâ değerli (scout'un kararı var), cache'den devam et
                let candlesOpt = await MarketDataStore.shared.ensureCandles(symbol: signal.symbol, timeframe: "1day").value
                let candles = candlesOpt ?? []
                if candles.isEmpty {
                    ArgusLogger.warn("AutoPilotStore: \(signal.symbol) mum yok, convene cache denenecek", category: "OTOPİLOT")
                }

                // Convene Grand Council — scout zaten çağırdı, 60sn cache'den dönmeli.
                let macro = await MacroSnapshotService.shared.getSnapshot()

                var sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil
                if SymbolResolver.shared.isBistSymbol(signal.symbol) {
                     sirkiyeInput = await prepareSirkiyeInput(macro: macro)
                }

                let snapshot = try? await FinancialSnapshotService.shared.fetchSnapshot(symbol: signal.symbol)

                let decision = await ArgusGrandCouncil.shared.convene(
                    symbol: signal.symbol,
                    candles: candles,
                    snapshot: snapshot,
                    macro: macro,
                    news: nil,
                    engine: .pulse,
                    sirkiyeInput: sirkiyeInput,
                    origin: "AUTOPILOT_STORE"
                )

                SignalStateViewModel.shared.grandDecisions[signal.symbol] = decision
                decisionsForExecution[signal.symbol] = decision
                ArgusLogger.info("AutoPilotStore: Grand Council Decision for \(signal.symbol): \(decision.action.rawValue) · conf=\(String(format: "%.2f", decision.confidence))", category: "OTOPİLOT")
            }

            if buyCount == 0 {
                ArgusLogger.warn("AutoPilotStore: Bu turda BUY sinyali çıkmadı.", category: "OTOPİLOT")
            }

            // Açık pozisyonlardaki acil likidasyon kararlarını da yürütücüye taşı
            let openSymbols = Set(self.portfolioStore.trades.filter { $0.isOpen }.map { $0.symbol })
            for symbol in openSymbols {
                if let cachedDecision = SignalStateViewModel.shared.grandDecisions[symbol] {
                    decisionsForExecution[symbol] = cachedDecision
                }
            }

            if decisionsForExecution.isEmpty {
                ArgusLogger.warn("AutoPilotStore: Yürütülecek güncel karar yok (signals/open positions).", category: "OTOPİLOT")
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
              
              print("🚨🚨🚨 CALLING TradeBrainExecutor.evaluateDecisions with \(decisionsForExecution.count) kararlar")
              ArgusLogger.warn("🚨 evaluateDecisions ÇAĞRILIYOR (\(decisionsForExecution.count) karar)", category: "OTOPİLOT")
              await TradeBrainExecutor.shared.evaluateDecisions(
                  decisions: decisionsForExecution,
                  portfolio: self.portfolioStore.trades,
                  quotes: simpleQuotes,
                  balance: self.portfolioStore.globalBalance,
                  bistBalance: self.portfolioStore.bistBalance,
                  macroScore: MacroRegimeService.shared.getCachedRating()?.numericScore,
                  orionScores: orionScoresMap,
                  candles: candlesMap
              )
              print("🚨🚨🚨 evaluateDecisions RETURNED")
              ArgusLogger.warn("🚨 evaluateDecisions RETURNED", category: "OTOPİLOT")
             
             // Check Plan Triggers
             await self.checkPlanTriggers()
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Helpers
    
    private func prepareSirkiyeInput(macro: MacroSnapshot) async -> SirkiyeEngine.SirkiyeInput? {
        let quotes = MarketDataStore.shared.liveQuotes
        // USD/TRY birden fazla sembol adıyla gelebilir: "USD/TRY", "USDTRY=X" (Yahoo), "USDTRY"
        var usdQuoteResolved = quotes["USD/TRY"] ?? quotes["USDTRY=X"] ?? quotes["USDTRY"]

        // 2026-04-22: MarketDataStore'da genelde USD/TRY yok (watchlist'te
        // değil). BorsaPy'den direct çek — hızlı + güvenilir. Fallback'e
        // geçmeden önce bu yolu dene.
        if usdQuoteResolved == nil {
            if let fx = try? await BorsaPyProvider.shared.getFXRate(asset: "USDTRY") {
                ArgusLogger.info("💱 USD/TRY BorsaPy'den alındı: ₺\(String(format: "%.2f", fx.last))", category: "OTOPİLOT")
                return SirkiyeEngine.SirkiyeInput(
                    usdTry: fx.last,
                    usdTryPrevious: fx.open > 0 ? fx.open : fx.last,
                    dxy: macro.dxy,
                    brentOil: macro.brent,
                    globalVix: macro.vix,
                    newsSnapshot: nil,
                    currentInflation: 45.0,
                    policyRate: 50.0,
                    xu100Change: nil,
                    xu100Value: nil,
                    goldPrice: nil
                )
            }
        }

        guard let usdQuote = usdQuoteResolved else {
            // Fallback: bilinen sabit kur ile devam et (Sirkiye analizi degraded ama çalışır)
            print("⚠️ AutoPilotStore: USD/TRY kuru bulunamadı, varsayılan kur ile devam ediliyor")
            return SirkiyeEngine.SirkiyeInput(
                usdTry: 35.0,
                usdTryPrevious: 35.0,
                dxy: macro.dxy,
                brentOil: macro.brent,
                globalVix: macro.vix,
                newsSnapshot: nil,
                currentInflation: 45.0,
                policyRate: 50.0,
                xu100Change: nil,
                xu100Value: nil,
                goldPrice: nil
            )
        }

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

        // FIX #3 (tetikleme): Makro rejim transition tepkisi.
        // Önceki mimaride rejim değişimi MarketContextCoordinator'da
        // tespit ediliyor ama AutoPilot/PositionPlanStore habersiz kalıyordu.
        // Aether skoru aniden riskOff eşiğine düşerse (< 40) açık
        // pozisyonlara %30 koruyucu trim uygula — likide kalma tepkisi.
        // Trim bir kez tetiklensin diye son trim zamanı tutulur.
        let aether = MacroRegimeService.shared.getCachedRating()?.numericScore ?? 50
        let velocitySignal = await AetherVelocityEngine.shared.analyze()
        let isCrashMode = aether < 40 && (velocitySignal.signal == .deterioratingFast || velocitySignal.signal == .deteriorating)
        if isCrashMode {
            let lastProtectiveTrim = UserDefaults.standard.object(forKey: "Argus_LastProtectiveTrim") as? Date
            let cooledDown = lastProtectiveTrim == nil || Date().timeIntervalSince(lastProtectiveTrim!) > 3600 // 1 saat
            if cooledDown {
                ArgusLogger.warn("🛡️ Makro rejim transition — Aether:\(Int(aether)) velocity:\(velocitySignal.signal.rawValue). Koruyucu trim %30 uygulanıyor.", category: "OTOPİLOT")
                print("🛡️🛡️🛡️ CRASH MODE — %30 trim tüm açık pozisyonlara")
                for trade in openTrades {
                    guard let currentPrice = quotes[trade.symbol]?.currentPrice, currentPrice > 0 else { continue }
                    _ = portfolioStore.trim(
                        tradeId: trade.id,
                        percentage: 30,
                        currentPrice: currentPrice,
                        reason: "MACRO_CRASH_TRIM_30: Aether<\(Int(aether)) + velocity=\(velocitySignal.signal.rawValue)"
                    )
                    triggeredCount += 1
                }
                UserDefaults.standard.set(Date(), forKey: "Argus_LastProtectiveTrim")
            }
        }

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
                ArgusLogger.info("AutoPilotStore: Plan aksiyonu loglandı, icra edilmedi -> \(trade.symbol): \(action.description)", category: "OTOPİLOT")
            }
        }

        if triggeredCount > 0 {
            ArgusLogger.info("AutoPilotStore: \(triggeredCount) plan tetikleyicisi işlendi.", category: "OTOPİLOT")
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
        ArgusLogger.info("Trade Brain 3.0: Gunluk ogrenme dongusu baslatiliyor...", category: "OTOPİLOT")
        
        let learningService = TradeBrainLearningService.shared
        let confidenceCalibration = ConfidenceCalibrationService.shared
        
        let currentPrices = await getCurrentPricesForLearning()
        
        let processed = await learningService.processMaturedObservations(currentPrices: currentPrices)
        
        let stats = await learningService.getLearningStats()
        
        let calibrationStats = await confidenceCalibration.getOverallStats()
        
        ArgusLogger.info("Trade Brain 3.0: \(processed) karar degerlendirildi, \(stats.pendingCount) bekleyen", category: "OTOPİLOT")
        ArgusLogger.info("Trade Brain 3.0: Genel basari: %\(Int(calibrationStats.overallWinRate * 100))", category: "OTOPİLOT")
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
        
        ArgusLogger.info("Trade Brain 3.0: Kapali islem ogrenmesi - \(symbol) \(wasCorrect ? "KAR" : "ZARAR")", category: "OTOPİLOT")
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
