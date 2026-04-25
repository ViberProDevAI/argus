import Foundation

// MARK: - Auto-Pilot Service
/// The Engine for Automated Trading (Paper Mode).
/// STRICTLY uses REAL Data. NO Simulations.
final class AutoPilotService: Sendable {
    static let shared = AutoPilotService()
    
    // State
    private let tradeHistoryKey = "Argus_PaperTrades_v1"
    private var isScanning = false
    /// Scan başlangıç zamanı — `isScanning` stuck kalırsa timeout ile reset için.
    private var scanStartedAt: Date?
    /// Scan 3 dakikadan uzun sürerse flag'i zorla reset et (güvenlik).
    private let scanMaxDuration: TimeInterval = 180
    
    // Dependencies
    private let market = MarketDataProvider.shared
    private let analysis = OrionAnalysisService.shared
    private let cache = HermesCacheStore.shared // For news context if needed later
    
    private init() {}
    
    // MARK: - Public API
    
    /// Scans the provided list of symbols for high-conviction setups.
    /// Returns a list of Signals. Execution happens in ViewModel.
    /// Scans the provided list of symbols for high-conviction setups.
    /// Returns a list of Signals. Execution happens in ViewModel.
    func scanMarket(
        symbols: [String], 
        equity: Double, 
        bistEquity: Double, // NEW: TL Equity for BIST
        buyingPower: Double, 
        bistBuyingPower: Double,
        portfolio: [String: Trade]
    ) async -> (signals: [TradeSignal], logs: [ScoutLog]) {
        // KRİTİK: Stuck isScanning flag'ı tespiti + otomatik reset.
        //
        // Eski sürümde bir scan async closure içinde çökerse (task cancel, exception,
        // async suspend timeout) `defer { isScanning = false }` çalışmıyor, flag
        // sonsuza dek `true` kalıyordu. Bu yüzden RISK-OFF (Aether 0) döneminde
        // scan başladıysa, Aether normale dönse bile ASLA yeni scan çalışamıyordu.
        // Kullanıcı gözlemi: "risk dönemi alım satımı kesti ama bir daha açılmadı".
        //
        // Fix: scan başlangıç zamanı tutuluyor. Yeni scan geldiğinde önceki 180
        // saniyeden uzun sürmüş ise flag'i zorla reset et. Async deadlock stuck'ı kırılır.
        if isScanning {
            if let startedAt = scanStartedAt, Date().timeIntervalSince(startedAt) > scanMaxDuration {
                ArgusLogger.warning(.autopilot, "scanMarket: stuck isScanning tespit edildi (\(Int(Date().timeIntervalSince(startedAt)))s), zorla reset")
                print("🔓 AutoPilotService: isScanning stuck, reset ediliyor")
                isScanning = false
                scanStartedAt = nil
            } else {
                ArgusLogger.warning(.autopilot, "scanMarket ATLANDI: önceki tarama hâlâ çalışıyor (isScanning=true)")
                print("⏳ AutoPilotService: Önceki tarama devam ediyor — bu tur atlandı")
                let skipLog = ScoutLog(symbol: "—", status: "ATLA", reason: "Önceki tarama hâlâ çalışıyor (loop yetişemiyor)", score: 0)
                return ([], [skipLog])
            }
        }
        isScanning = true
        scanStartedAt = Date()
        defer {
            isScanning = false
            scanStartedAt = nil
        }

        var signals: [TradeSignal] = []
        var logs: [ScoutLog] = []
        // V5.H-21 (2026-04-24): Scan sonunda UI'a akıtılacak hafif per-symbol
        // ArgusDecisionResult buffer'ı.
        //
        // Kök neden: `SignalStateViewModel.argusDecisions` hiçbir yerde yazılmıyordu
        // (yalnızca `= nil` temizlik ve kullanılmayan passthrough setter). UI Sanctum
        // orb + motor chip fallback yolu `grandDecisions ?? argusDecisions` olarak
        // çalıştığı için `argusDecisions` ölü kaldıkça 300 sembolün ~295'inde orb
        // "BEKLİYOR" / Prometheus "KANAL ARANIYOR" takılı kalıyordu — grandDecisions
        // sadece BUY sinyali üreten birkaç sembolde doluyor.
        //
        // Çözüm: scan sırasında zaten hesaplanan orion/atlas/aether skorlarına
        // ek olarak lokal (network-free) PhoenixLogic.analyze çağrısı ile phoenixAdvice
        // üret, minimal bir ArgusDecisionResult topla, scan sonunda MainActor'da
        // tek seferde yaz. Konsey kararı (grandDecisions) bu path'in üstünde kalır —
        // burası UI için "gün sonu özet" katmanı.
        var pendingArgusDecisions: [String: ArgusDecisionResult] = [:]

        print("🤖 AutoPilotService: Tarama başlatılıyor - \(symbols.count) sembol")
        print("💰 AutoPilotService: Global Equity: $\(equity), BIST Equity: ₺\(bistEquity)")
        print("💰 AutoPilotService: Global Balance: $\(buyingPower), BIST Balance: ₺\(bistBuyingPower)")

        // Ensure Aether Freshness
        var aether = MacroRegimeService.shared.getCachedRating()
        if aether == nil {
            ArgusLogger.warning(.autopilot, "Aether verisi eski. Makro ortam yenileniyor...")
            aether = await MacroRegimeService.shared.computeMacroEnvironment()
        }

        // Safe Haven Router'ı her tarama başında değerlendir — eskiden yalnız
        // SmartTickerStrip görünürken hesaplanıyordu, ekran kapalıyken kriz
        // tespiti dönmüyor, ExecutionGovernor (F1-6) hep "isActive=false" görüyordu.
        // Şimdi MainActor.run içinde liveQuotes + aetherScore ile bir kere besleniyor.
        let aetherForRouter = aether?.numericScore
        await MainActor.run {
            let quotes = MarketDataStore.shared.liveQuotes
            SafeHavenRouter.shared.evaluate(quotes: quotes, aetherScore: aetherForRouter)
        }

        // Heimdall sistem sağlığı — KRİTİK ise tarama iptal, ancak sessiz değil.
        let health = await HeimdallOrchestrator.shared.checkSystemHealth()
        ArgusLogger.info(.autopilot, "Heimdall sağlık: \(health)")
        if health == .critical {
            ArgusLogger.error(.autopilot, "Sistem Sağlığı KRİTİK. Tarama iptal ediliyor.")
            print("🛑 AutoPilotService: Sistem sağlığı KRİTİK")
            let critLog = ScoutLog(symbol: "—", status: "RED", reason: "Heimdall sistem sağlığı KRİTİK — veri akışı sorunlu", score: 0)
            return ([], [critLog])
        }
        
        ArgusLogger.phase(.autopilot, "Piyasa taranıyor: \(symbols.count) sembol (Rejim: \(aether?.regime.displayName ?? "Bilinmiyor"))")
        
        // GLOBAL MARKET: Hafta sonu ve piyasa kapalıyken işlem yapma
        let canTradeGlobal = MarketStatusService.shared.canTrade()
        if !canTradeGlobal {
            let status = MarketStatusService.shared.getMarketStatus()
            let reason: String
            switch status {
            case .closed(let r): reason = r
            case .preMarket: reason = "Pre-Market"
            case .afterHours: reason = "After-Hours"
            default: reason = "Piyasa Kapalı"
            }
            print("STOP Auto-Pilot: Global piyasa kapalı (\(reason)). Sadece BIST taraması yapılacak.")
            ArgusLogger.warning(.autopilot, "Global piyasa kapalı (\(reason)). Sadece BIST taranacak.")
        }
        
        // Y3-HOTFIX Phase 3 (2026-04-24): Batch boyutu 30 → 10, bekleme 500ms → 1s.
        //
        // Gerekçe: 304 sembol × 2 Yahoo endpoint = 608 çağrı. Yahoo cap 300/min (5/s).
        // Eski batch=30/500ms 30 eşzamanlı waiter üretip `acquireSlot` queue'sunda
        // uzun kuyruklar (25+ waiter/batch) oluşturuyordu — rate limiter 5/s serviste
        // olduğundan geç gelen waiter'lar deadline'a yaklaşıyor ve timeout riski artıyor.
        //
        // batch=10/1s: her anda ≤10 waiter → kuyruk sığ, timeout marjı bol.
        // Toplam süre rate limiter tavanıyla sınırlı (608/5 ≈ 2 dk), batch boyutu
        // ikincil. Asıl kazanım: waiter çöplenmesi ve self-induced congestion kalkıyor.
        let batchSize = 10
        let chunks = stride(from: 0, to: symbols.count, by: batchSize).map {
            Array(symbols[$0..<min($0 + batchSize, symbols.count)])
        }

        for (index, batch) in chunks.enumerated() {
            // ArgusLogger.verbose(.autopilot, "Paket işleniyor: \(index + 1)/\(chunks.count) (\(batch.count) sembol)")

            // Y3-HOTFIX Phase 3: Batch'ler arası bekleme 1s — wait-and-serve
            // rate limiter'a soluklanma payı. Art arda batch'ler aynı 60s pencerede
            // tavanı doldurursa sonraki batch'in ilk waiter'ı bekler (doğru).
            if index > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            // Process Batch concurrently for speed
            // V5.H-21: Tuple'a opsiyonel ArgusDecisionResult eklendi — erken dönüş
            // yollarında (market closed, candle yok, quote hata) nil, başarılı
            // skorlama bittikten sonra dolu.
             await withTaskGroup(of: (TradeSignal?, ScoutLog?, ArgusDecisionResult?).self) { group in
                for symbol in batch {
                    group.addTask {
                        // 1. Determine Correct Context
                        let isBist = SymbolResolver.shared.isBistSymbol(symbol)
                        let effectiveBuyingPower = isBist ? bistBuyingPower : buyingPower
                        let effectiveEquity = isBist ? bistEquity : equity
                        
                        // GLOBAL MARKET CLOSED CHECK
                        if !isBist && !canTradeGlobal {
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "Global piyasa kapalı", score: 0), nil)
                        }

                        // BIST MARKET CLOSED CHECK
                        if isBist && !MarketStatusService.shared.isBistOpen() {
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "BIST piyasası kapalı", score: 0), nil)
                        }
                        
                        // 1. Fetch Data (Prices & Candles)
                        // try? sessizce yutuyordu — kullanıcı "kimisi boş" dediğinde
                        // sebebini görmek mümkün değildi. Şimdi do/catch ile error
                        // tipini log'a + ScoutLog'a açıkça yansıtıyoruz; rate-limit
                        // ile "geçici hata", invalid symbol ile "kalıcı hata" UI'da
                        // ayırt edilebilir.
                        var currentPrice: Double = 0.0
                        let candles: [Candle]?
                        do {
                            candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 200)
                        } catch {
                            let msg = error.localizedDescription
                            ArgusLogger.warning(.autopilot, "Candle fetch hatası (\(msg)), \(symbol) atlandı")
                            return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Mum verisi alınamadı: \(msg)", score: 0), nil)
                        }

                        guard let lastCandle = candles?.last else {
                            return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Mum verisi boş (Heimdall sembolü tanımıyor olabilir)", score: 0), nil)
                        }
                        
                        // Fetch Realtime Price
                        //
                        // K3 fix: Quote fetch başarısız olursa SEMBOLÜ ATLA.
                        // Eskiden `currentPrice = lastCandle.close` fallback'i vardı —
                        // dünkü (hatta hafta sonu 3 gün önceki) kapanış fiyatı ile
                        // "canlı" trade kararı alınıyor, SL/TP bu sahte fiyata göre
                        // hesaplanıyor ve pozisyon zamanla kaçınılmaz slippage'la açılıyordu.
                        // Artık: quote yok → signal yok (explicit hata log'u).
                        do {
                            let quote = try await HeimdallOrchestrator.shared.requestQuote(symbol: symbol)
                            currentPrice = quote.currentPrice
                        } catch {
                            ArgusLogger.warning(.autopilot, "Quote fetch hatası (\(error.localizedDescription)), \(symbol) atlandı (stale-price koruması)")
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "Canlı fiyat hatası: \(error.localizedDescription)", score: 0), nil)
                        }

                        // Freshness guard: Quote 15 saniyeden eskiyse güvenli tarafta kal.
                        if currentPrice <= 0 {
                            ArgusLogger.warning(.autopilot, "Quote currentPrice ≤ 0 (\(currentPrice)), \(symbol) atlandı")
                            return (nil, ScoutLog(symbol: symbol, status: "ATLA", reason: "Geçersiz fiyat (≤0)", score: 0), nil)
                        }
                        
                        // 2. Scores
                        let orion = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles ?? [], spyCandles: nil)
                        let atlas = FundamentalScoreStore.shared.getScore(for: symbol)
                        
                        // 3. Evaluate via Argus Engine
                        let decision = await ArgusAutoPilotEngine.shared.evaluate(
                            symbol: symbol,
                            currentPrice: currentPrice,
                            equity: effectiveEquity,
                            buyingPower: effectiveBuyingPower,
                            portfolioState: portfolio,
                            candles: candles,
                            atlasScore: atlas?.totalScore,
                            orionScore: orion?.score,
                            orionDetails: orion?.components,
                            aetherRating: aether,
                            hermesInsight: nil,
                            argusFinalScore: nil,
                            demeterScore: 50.0
                        )
                        
                        var signal: TradeSignal? = nil
                        if let sig = decision.signal {
                            signal = TradeSignal(
                                symbol: symbol,
                                action: sig.action,
                                reason: sig.reason,
                                confidence: 80.0,
                                timestamp: Date(),
                                stopLoss: sig.stopLoss,
                                takeProfit: sig.takeProfit,
                                trimPercentage: sig.trimPercentage
                            )
                        }

                        // V5.H-21: UI fallback için minimal ArgusDecisionResult.
                        //
                        // Önemli: bu ArgusGrandCouncil.convene'nin yerine geçmiyor —
                        // Konsey yalnızca BUY sinyali üreten sembollerde açılıyor, bu
                        // ise her taranan sembol için yazılıyor. UI `grandDecisions`
                        // yoksa buraya düşüyor ve "BEKLİYOR"/"KANAL ARANIYOR" yerine
                        // gerçek skorları gösteriyor.
                        //
                        // phoenixAdvice: `PhoenixLogic.analyze` pure + network-free,
                        // zaten elimizde olan candle array'inden `d1` kanalını çıkarır.
                        // Candle sayısı < 60 olduğunda `.insufficient()` döner (UI
                        // Prometheus branch'i "VERİ KISITLI" gösterir — çizgi değil).
                        var phoenixAdvice: PhoenixAdvice? = nil
                        if let c = candles, c.count >= 60 {
                            phoenixAdvice = PhoenixLogic.analyze(
                                candles: c,
                                symbol: symbol,
                                timeframe: .d1,
                                config: PhoenixConfig()
                            )
                        }

                        let orionValue = orion?.score ?? 0
                        let atlasValue = atlas?.totalScore ?? 0
                        let aetherValue = aether?.numericScore ?? 0
                        let finalAction = decision.signal?.action ?? .hold

                        let argusDecision = ArgusDecisionResult(
                            id: UUID(),
                            symbol: symbol,
                            assetType: isBist ? .stock : .stock, // BIST de .stock tier'ında
                            atlasScore: atlasValue,
                            aetherScore: aetherValue,
                            orionScore: orionValue,
                            athenaScore: 0,    // Bu scan path'inde üretilmiyor
                            hermesScore: 0,    // News scan path'inde yok; UI newsInsights fallback'ine düşer
                            demeterScore: 50,  // Nötr varsayılan
                            orionDetails: orion,
                            chironResult: nil,
                            phoenixAdvice: phoenixAdvice,
                            bistDetails: nil,
                            standardizedOutputs: nil,
                            moduleWeights: nil,
                            // finalScoreCore: Orion/Atlas/Aether ağırlıklı ortalama (Chiron default pulse)
                            finalScoreCore: (orionValue * 0.45) + (atlasValue * 0.30) + (aetherValue * 0.25),
                            // finalScorePulse: Orion ağırlıklı (technical-first)
                            finalScorePulse: (orionValue * 0.60) + (aetherValue * 0.20) + 50.0 * 0.20,
                            letterGradeCore: "—",
                            letterGradePulse: "—",
                            finalActionCore: finalAction,
                            finalActionPulse: finalAction,
                            isNewsBacked: false,
                            isRegimeGood: aetherValue >= 40.0,
                            isFundamentallyStrong: atlasValue >= 50.0,
                            isDemeterStrong: false,
                            generatedAt: Date()
                        )

                        return (signal, decision.log, argusDecision)
                    }
                }

                // Collect results from group
                for await (sig, log, argus) in group {
                    if let s = sig {
                        signals.append(s)
                        ArgusLogger.success(.autopilot, "Sinyal Tespit Edildi: \(s.symbol) -> \(s.action.rawValue.uppercased())")
                        print("✅ AutoPilotService: Sinyal - \(s.symbol) -> \(s.action.rawValue) (\(s.reason))")

                        // D — Decision Engine audit. Sinyal üretilen sembolün
                        // skorları + action + reason kayda geçer; trade gerçekten
                        // açılsa da açılmasa da (governor reject vs) decision
                        // patikası geri-izlenebilir.
                        let signalAction: SignalAction = {
                            switch s.action {
                            case .buy:  return .buy
                            case .sell: return .sell
                            default:    return .hold
                            }
                        }()
                        var moduleScores: [String: Double] = [:]
                        if let ad = argus {
                            moduleScores["Orion"]  = ad.orionScore
                            moduleScores["Atlas"]  = ad.atlasScore
                            moduleScores["Aether"] = ad.aetherScore
                        }
                        let auditSymbol = s.symbol
                        let auditReason = s.reason
                        let auditScore  = argus?.finalScoreCore ?? 0.0
                        Task { @MainActor in
                            await AuditLogService.shared.recordDecision(
                                symbol: auditSymbol,
                                candidateSource: "AutoPilot",
                                moduleScores: moduleScores,
                                moduleOpinions: [:],
                                chironWeights: nil,
                                debateSummary: auditReason,
                                riskApproved: true,
                                riskReason: nil,
                                finalAction: signalAction,
                                finalScore: auditScore,
                                executionPlan: nil
                            )
                        }
                    }
                    if let l = log {
                        logs.append(l)
                    }
                    if let ad = argus {
                        pendingArgusDecisions[ad.symbol] = ad
                    }
                }
            }
        }

        print("📊 AutoPilotService: Tarama tamamlandı - \(signals.count) sinyal, \(logs.count) log, \(pendingArgusDecisions.count) argusDecision")

        // Onarım 1: MissedOpportunityLog. Eskiden ArgusAutoPilot.attemptEntry'de
        // yazılıyordu ama o path dead — log boş kalıyordu. Şimdi aktif scan
        // yolunda RED rejection'ları + kayda değer skoru olanlar (>= 50)
        // kaydediliyor. 24h+ sonra subsequentPriceChange doldurulup gerçekten
        // fırsat mıydı analiz edilebilir.
        let missedCandidates = logs.filter { $0.score >= 50 && $0.status == "RED" }
        if !missedCandidates.isEmpty {
            let snapshot = missedCandidates
            Task { @MainActor in
                for log in snapshot {
                    LearningPersistenceManager.shared.logMissedOpportunity(
                        symbol: log.symbol,
                        score: log.score,
                        reason: log.reason
                    )
                }
            }
        }

        // V5.H-21: Topladığımız kararları MainActor'da tek seferde UI store'a bas.
        // Böylece her başarılı sembol için Sanctum orb + motor chip canlanır;
        // BUY sinyali üretmeyenler de artık "BEKLİYOR" yerine gerçek skor gösterir.
        if !pendingArgusDecisions.isEmpty {
            let snapshot = pendingArgusDecisions
            await MainActor.run {
                for (symbol, decision) in snapshot {
                    SignalStateViewModel.shared.argusDecisions[symbol] = decision
                }
                ArgusLogger.info(.autopilot, "argusDecisions güncellendi: \(snapshot.count) sembol (UI fallback path aktif)")
            }
        }

        return (signals, logs)
    }
}
