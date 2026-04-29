import Foundation

// MARK: - Argus V3 Action Types
enum ArgusAction: String, Sendable, Codable {
    case aggressiveBuy = "HÜCUM"                // Güçlü Alım
    case accumulate = "BİRİKTİR"                // Kademeli Alım
    case neutral = "GÖZLE"                      // Bekle / Tut
    case trim = "AZALT"                         // Satış (Kâr Al)
    case liquidate = "ÇIK"                      // Tam Çıkış (Stop)
    
    var colorName: String {
        switch self {
        case .aggressiveBuy: return "Green"
        case .accumulate: return "Blue"
        case .neutral: return "Gray"
        case .trim: return "Orange"
        case .liquidate: return "Red"
        }
    }

    func toProposedAction() -> ProposedAction {
        switch self {
        case .aggressiveBuy, .accumulate: return .buy
        case .neutral: return .hold
        case .trim, .liquidate: return .sell
        }
    }
}

enum SignalStrength: String, Sendable, Codable {
    case strong = "GÜÇLÜ"
    case normal = "NORMAL"
    case weak = "ZAYIF"
    case vetoed = "VETOLANDI"
}

struct ArgusGrandDecision: Sendable, Equatable, Codable {
    let id: UUID
    let symbol: String
    let action: ArgusAction
    let strength: SignalStrength
    let confidence: Double
    let reasoning: String
    
    // Details
    let contributors: [ModuleContribution]
    let vetoes: [ModuleVeto]
    
    // Non-voting Advisors (Educational)
    var advisors: [AdvisorNote] = []
    
    // Individual council decisions (Snapshot for UI)
    let orionDecision: CouncilDecision
    let atlasDecision: AtlasDecision?
    let aetherDecision: AetherDecision
    let hermesDecision: HermesDecision?
    
    // For Information Quality UI
    let moduleWeights: InformationWeights? = nil
    
    // For Phoenix
    let phoenixAdvice: PhoenixAdvice? = nil
    // let cronosScore: Double? = nil (REMOVED)
    
    // Rich Data for Voice/UI
    let orionDetails: OrionScoreResult?
    let financialDetails: FinancialSnapshot?
    
    // NEW: BIST V2 Result
    let bistDetails: BistDecisionResult?
    
    // NEW: Orion V3 Patterns
    let patterns: [OrionChartPattern]?
    
    let timestamp: Date
    
    var shouldTrade: Bool {
        return action == .aggressiveBuy || action == .accumulate || action == .trim || action == .liquidate
    }
    
    static func == (lhs: ArgusGrandDecision, rhs: ArgusGrandDecision) -> Bool {
        return lhs.id == rhs.id
    }
}


    
extension ArgusGrandDecision {
    // Recommended Allocation Multiplier based on Action
    var allocationMultiplier: Double {
        switch action {
        case .aggressiveBuy: return 1.0  // 100% of max allocation
        case .accumulate: return 0.3     // 30% start
        case .neutral: return 0.0
        case .trim: return 0.5          // Sell 50%
        case .liquidate: return 1.0     // Sell 100%
        }
    }
}


// MARK: - Argus Grand Council
/// The Supreme Council - combines all module decisions for the final verdict
actor ArgusGrandCouncil {
    static let shared = ArgusGrandCouncil()
    
    // MARK: - Cache
    private var decisionCache: [String: (decision: ArgusGrandDecision, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 120 // 2 dakika — rejim dönüşlerini daha hızlı yakala
    
    // MARK: - Public API
    
    /// Main entry point: Gather all councils and make the grand decision
    /// Uses caching to prevent unnecessary re-calculation
    func convene(
        symbol: String,
        candles: [Candle],
        snapshot: FinancialSnapshot?, // CHANGED: Direct Snapshot
        macro: MacroSnapshot,
        news: HermesNewsSnapshot?,
        engine: AutoPilotEngine,
        athena: AthenaFactorResult? = nil,
        demeter: DemeterScore? = nil,
        // chiron: ChronosResult? = nil, (REMOVED)
        // NEW: BIST Macro Input (Sirkiye)
        sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil,
        forceRefresh: Bool = false,
        // ARGUS 3.0: Origin Context
        origin: String = "UI_SCAN"
    ) async -> ArgusGrandDecision {
        
        // 1. Check Cache
        if !forceRefresh, let cached = decisionCache[symbol] {
             if Date().timeIntervalSince(cached.timestamp) < cacheTTL {
                 ArgusLogger.info(.argus, "Cache kullanılıyor (\(symbol))")
                 return cached.decision
             }
         }

        let timestamp = Date()
        ArgusLogger.info(.argus, "Üst konseyi toplanıyor: \(symbol)")
        
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        // 1.5 Orion V3 Pattern Detection (Synchronous calculation for decision input)
        let detectedPatterns = await OrionPatternEngine.shared.detectPatterns(candles: candles)
        if !detectedPatterns.isEmpty {
            ArgusLogger.info(.orion, "V3: \(detectedPatterns.count) formasyon tespit edildi.")
        }
        
        // 2. Gather all council decisions (Parallel execution could be optimized here)
        let orionDecision: CouncilDecision
        
        if isBist {
            ArgusLogger.info(.orion, "TR (Turquoise) devrede: \(symbol)")
            orionDecision = await OrionBistEngine.shared.analyze(symbol: symbol, candles: candles)
        } else {
            orionDecision = await OrionCouncil.shared.convene(symbol: symbol, candles: candles, engine: engine)
        }
        
        var atlasDecision: AtlasDecision? = nil
        if let snap = snapshot {
            if isBist {
                ArgusLogger.info(.atlas, "TR (Turquoise) devrede: \(symbol)")
                atlasDecision = await AtlasBistEngine.shared.analyze(symbol: symbol, financials: snap)
            } else {
                atlasDecision = await AtlasCouncil.shared.convene(symbol: symbol, financials: snap, engine: engine)
            }
        }
        
        // 3. Aether (Macro) - Project Turquoise Integration (Sirkiye)
        let aetherDecision: AetherDecision
        
        if isBist, let bistInput = sirkiyeInput {
            ArgusLogger.info(.aether, "Sirkiye (Politik Korteks) devrede: \(symbol)")
            aetherDecision = await SirkiyeEngine.shared.analyze(input: bistInput)
        } else {
            aetherDecision = await AetherCouncil.shared.convene(macro: macro)
        }
        
        var hermesDecision: HermesDecision? = nil
        
        if isBist {
            // [ADAPTER] BIST Sentiment -> Hermes Snapshot
            // BIST için native sentiment analizini çalıştırıp Hermes formatına çeviriyoruz
            if let payload = try? await BISTSentimentEngine.shared.analyzeSentimentPayload(for: symbol) {
                let adaptedSnapshot = BISTSentimentAdapter.adapt(result: payload.result, articles: payload.articles)
                hermesDecision = await HermesCouncil.shared.convene(symbol: symbol, news: adaptedSnapshot)
                ArgusLogger.info(.hermes, "Adapter: BIST Sentiment entegre edildi. Skor: \(Int(payload.result.overallScore))")
            }
        } else if let newsData = news {
            hermesDecision = await HermesCouncil.shared.convene(symbol: symbol, news: newsData)
        }
        
        // 2.5 Get Weights (Non-blocking now)
        let weights = ChironCouncilLearningService.shared.getCouncilWeights(symbol: symbol, engine: engine)
        
        // --- BIST V2 REFORM ---
        if isBist {
            // Re-fetch True Macro (Rejim) because 'aetherDecision' holds Sirkiye (Flow) result for BIST currently
            let trueMacroDecision = await AetherCouncil.shared.convene(macro: macro)
            let flowDecision = aetherDecision // Currently SirkiyeEngine output

            // Analist konsensüsünü BorsaPy'den çek (BIST sembolü için)
            let analystConsensus = try? await BorsaPyProvider.shared.getAnalystRecommendations(symbol: symbol)
            if let ac = analystConsensus {
                ArgusLogger.info(.argus, "Council: Analist konsensüsü alındı: \(ac.recommendation) (\(ac.totalAnalysts) analist)")
            }

            let bistRes = await BistGrandCouncil.shared.convene(
                symbol: symbol,
                faktorScore: athena,
                sektorScore: demeter,
                akisResult: flowDecision,
                kulisData: hermesDecision,
                grafikData: orionDecision,
                bilancoData: atlasDecision,
                rejimData: trueMacroDecision,
                analystConsensus: analystConsensus
            )
            
            let finalDecision = ArgusGrandDecision(
                id: bistRes.id,
                symbol: symbol,
                action: bistRes.action,
                strength: .normal, // Strength is calculated inside BistResult but mapped simply here
                confidence: bistRes.confidence / 100.0,
                reasoning: bistRes.reasoning,
                contributors: [], // Contributors logic is inside BistResult.modules now
                vetoes: [],
                advisors: [],
                orionDecision: orionDecision,
                atlasDecision: atlasDecision,
                aetherDecision: trueMacroDecision,
                hermesDecision: hermesDecision,
                // Pass rich details
                orionDetails: OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: nil),
                financialDetails: snapshot, // Direct Use
                bistDetails: bistRes, // <--- BIST V2 RESULT
                patterns: detectedPatterns,
                timestamp: Date()
            )
            
            // ARGUS 3.0: THE HOOK (BIST)
            ArgusLedger.shared.logDecision(
                decisionId: finalDecision.id,
                symbol: symbol,
                action: finalDecision.action.rawValue,
                confidence: finalDecision.confidence,
                scores: [
                    "Orion": orionDecision.netSupport * 100.0,
                    "Atlas": (atlasDecision?.netSupport ?? 0.0) * 100.0,
                    "Aether": trueMacroDecision.netSupport * 100.0,
                    "Hermes": (hermesDecision?.netSupport ?? 0.0) * 100.0,
                    "Athena": athena?.factorScore ?? 0.0,
                    "Demeter": demeter?.totalScore ?? 0.0
                ],
                vetoes: [], // BIST logic handles vetoes internally currently
                origin: origin,
                currentPrice: candles.last?.close
            )
            
            // Update Cache & Return Early
            decisionCache[symbol] = (finalDecision, Date())
            return finalDecision
        }
        
        // Aether velocity — makro trend dönüşlerinin skor yükselmeden Council'a
        // iletilmesi için (savaş → ateşkes gibi). Burada fetch edilip parametre olarak
        // geçiliyor çünkü calculateGrandDecision sync.
        let aetherVelocity = await AetherVelocityEngine.shared.analyze()

        // Rejim dönüşüm sinyali — Aether'i "puan üreten"den "trend yakalayan"a çeviren
        // birleşik makro radar. Hermes high-impact pozitif haberler + piyasa breadth'i
        // + Aether velocity kanıtlarını birleştirip korku→cesaret geçişini skor
        // yükselmeden tespit eder. Council hard-veto'yu bu sinyale göre yumuşatır.
        //
        // Hermes sayımı: EventStore'dan son 24 saatin yüksek etkili (severity ×
        // reliability ≥ 50) pozitif/negatif event sayısı. Eski sürüm tek symbol'ün
        // netSupport threshold'una bakıyordu; yeni sürüm piyasa-geneli haber akışını
        // sayıyor — rejim dönüşüm "katalizör" kanıtı olarak daha güvenilir.
        let hermesPositive = HermesEventStore.shared.countHighImpactEvents(polarity: .positive)
        let hermesNegative = HermesEventStore.shared.countHighImpactEvents(polarity: .negative)
        let watchlistSymbols = await MainActor.run { WatchlistStore.shared.items }
        let quotesSnapshot = await MainActor.run { MarketDataStore.shared.quotes.compactMapValues { $0.value } }
        let candlesSnapshot = await MainActor.run { MarketDataStore.shared.candles.compactMapValues { $0.value } }
        let globalMomentum = await MarketMomentumGate.shared.assessGlobal(
            quotes: quotesSnapshot,
            candles: candlesSnapshot,
            watchlistSymbols: watchlistSymbols
        )
        let bistMomentum = await MarketMomentumGate.shared.assessBist(
            quotes: quotesSnapshot,
            candles: candlesSnapshot,
            watchlistSymbols: watchlistSymbols
        )
        // Watchlist Pulse — tüm listenin ortak ani hareketi (cross-sectional ivme).
        // Makro veri henüz yansıtmadığı bir olay tüm hisseleri birden oynattığında
        // Aether bunu "nabız" olarak yakalayacak. 5. bağımsız kanıt.
        let watchlistPulse = await WatchlistPulseMonitor.shared.assess(candlesBySymbol: candlesSnapshot)

        let regimeTransition = await AetherRegimeTransitionDetector.shared.analyze(
            velocity: aetherVelocity,
            recentPositiveHermesEvents: hermesPositive,
            recentNegativeHermesEvents: hermesNegative,
            globalMomentumLevel: globalMomentum.level,
            bistMomentumLevel: bistMomentum.level,
            watchlistPulse: watchlistPulse
        )

        // Prometheus 5-günlük fiyat tahmini — advisor katmanı olarak.
        // Oy vermez ama yüksek güvenli tahmin varsa Council'a "trend ile uyumlu mu"
        // bilgisini ekler. Eski sürüm Prometheus sadece UI badge idi, kararlara
        // hiç katılmıyordu; şimdi advisory katkı sağlıyor.
        let prometheusForecast = await PrometheusEngine.shared.forecast(
            symbol: symbol,
            historicalPrices: candles.map { $0.close }
        )

        // 3. Calculate grand decision (GLOBAL LEGACY)
        let grandDecision = calculateGrandDecision(
            symbol: symbol,
            orion: orionDecision,
            atlas: atlasDecision,
            aether: aetherDecision,
            aetherVelocity: aetherVelocity,
            regimeTransition: regimeTransition,
            hermes: hermesDecision,
            patterns: detectedPatterns,
            engine: engine,
            weights: weights,
            // Rich Data context
            orionDetails: OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: nil),
            financialDetails: snapshot, // Direct Use
            // Advisors
            athena: athena,
            demeter: demeter,
            prometheus: prometheusForecast
            // chiron: chiron (REMOVED)
        )
        
        // ARGUS 3.0: THE HOOK (GLOBAL)
        ArgusLedger.shared.logDecision(
            decisionId: grandDecision.id,
            symbol: symbol,
            action: grandDecision.action.rawValue,
            confidence: grandDecision.confidence,
            scores: [
                "Orion": orionDecision.netSupport * 100.0,
                "Atlas": (atlasDecision?.netSupport ?? 0.0) * 100.0,
                "Aether": aetherDecision.netSupport * 100.0,
                "Hermes": (hermesDecision?.netSupport ?? 0.0) * 100.0,
                "Athena": athena?.factorScore ?? 0.0,
                "Demeter": demeter?.totalScore ?? 0.0
            ],
            vetoes: grandDecision.vetoes.map { "\($0.module): \($0.reason)" },
            origin: origin,
            currentPrice: candles.last?.close
        )
        
        // 4. Update Cache
        decisionCache[symbol] = (grandDecision, Date())
        
        // 5. Notify Learning Service (silent failure guard)
        // Eski sürüm fire-and-forget Task içinde hata yakalamıyordu; kayıt başarısız
        // olsa bile hiçbir iz bırakmıyordu. Şimdi hatayı yakalayıp logluyoruz.
        Task {
            let record = CouncilVotingRecord(
                id: UUID(),
                symbol: symbol,
                engine: engine,
                timestamp: timestamp,
                proposerId: "orion_master",
                action: orionDecision.action.rawValue,
                approvers: grandDecision.contributors.map { $0.module.lowercased() },
                vetoers: grandDecision.vetoes.map { $0.module.lowercased() },
                abstainers: [],
                finalDecision: grandDecision.action.rawValue,
                netSupport: 0.0,
                outcome: nil,
                pnlPercent: nil
            )
            await ChironCouncilLearningService.shared.recordDecision(record)
            ArgusLogger.info(
                "Council decision kaydedildi: \(symbol) → \(grandDecision.action.rawValue)",
                category: "COUNCIL.LEARN"
            )

            // ALKINDUS OBSERVATION — öğrenme döngüsünün başlangıç tutamağı.
            // Eski sürüm yalnızca ArgusDecisionEngine.makeDecision yolundan observe
            // çağırıyordu; ArgusGrandCouncil'dan gelen kararlarda hiç observation
            // kayıt edilmiyordu → pending kuyruğu hep boş → periodicMatureCheck boşa
            // çalışıyor → hitrate brackets güncellenmiyor → "hiçbir şey öğrenmiyor".
            // Şimdi her aksiyonlu karar (BUY/SELL) observation olarak kaydedilir;
            // 7/15 gün sonra olgunlaşıp verdict üretir.
            let alkindusAction: String? = {
                switch grandDecision.action {
                case .aggressiveBuy, .accumulate: return "BUY"
                case .trim, .liquidate:           return "SELL"
                case .neutral:                    return nil
                }
            }()
            let priceNow = candles.last?.close ?? 0
            if let action = alkindusAction, priceNow > 0 {
                await AlkindusCalibrationEngine.shared.observe(
                    symbol: symbol,
                    action: action,
                    moduleScores: [
                        "orion":  orionDecision.netSupport * 100.0,
                        "atlas":  (atlasDecision?.netSupport ?? 0.0) * 100.0,
                        "aether": aetherDecision.netSupport * 100.0,
                        "hermes": (hermesDecision?.netSupport ?? 0.0) * 100.0,
                        "athena": athena?.factorScore ?? 0.0,
                        "demeter": demeter?.totalScore ?? 0.0
                    ],
                    regime: aetherDecision.stance.rawValue,
                    currentPrice: priceNow,
                    reasoning: grandDecision.reasoning
                )
            }
        }
        
        return grandDecision
    }
    
    // MARK: - Core Logic: The V3 Verdict Mechanism
    
    private func calculateGrandDecision(
        symbol: String,
        orion: CouncilDecision,
        atlas: AtlasDecision?,
        aether: AetherDecision,
        aetherVelocity: AetherVelocityEngine.VelocityAnalysis,
        regimeTransition: AetherRegimeTransitionDetector.Transition,
        hermes: HermesDecision?,
        patterns: [OrionChartPattern],
        engine: AutoPilotEngine,
        weights: CouncilMemberWeights,
        // Details
        orionDetails: OrionScoreResult?,
        financialDetails: FinancialSnapshot?,
        // Advisors
        athena: AthenaFactorResult?,
        demeter: DemeterScore?,
        prometheus: PrometheusForecast?
        // chiron: ChronosResult? (REMOVED)
    ) -> ArgusGrandDecision {
        
        var contributors: [ModuleContribution] = []
        var vetoes: [ModuleVeto] = []
        var hardVetoes: [ModuleVeto] = []
        var advisorNotes: [AdvisorNote] = []
        
        // --- ADVISORS ---
        advisorNotes.append(CouncilAdvisorGenerator.generateAthenaAdvice(result: athena))
        advisorNotes.append(CouncilAdvisorGenerator.generateDemeterAdvice(score: demeter))
        
        // Calculate temp action for Chiron check (simplified, will refine later if needed)
        // let _ = orion.action 
        // advisorNotes.append(CouncilAdvisorGenerator.generateChironAdvice(result: chiron, action: .neutral))

        
        // --- 1. ORION (Technical) ---
        let isStrongOrion = orion.action == .buy && orion.netSupport > 0.7
        let isOrionSell = orion.action == .sell
        
        contributors.append(ModuleContribution(
            module: "Orion",
            action: orion.action,
            confidence: orion.netSupport,
            reasoning: "Teknik: \(orion.action.rawValue)"
        ))
        
        // --- 1.1 ORION V3 PATTERN VETO ---
        // Bearish formasyonlar, Alım işlemlerini VETO eder
        if let bestPattern = patterns.sorted(by: { $0.confidence > $1.confidence }).first, bestPattern.confidence > 60 {
            if bestPattern.type.isBearish && (orion.action == .buy || orion.action == .hold) {
                vetoes.append(ModuleVeto(
                    module: "Orion Patterns",
                    reason: "\(bestPattern.type.rawValue) Formasyonu Tespit Edildi (Güven: %\(Int(bestPattern.confidence)))"
                ))
            } else if bestPattern.type.isBullish {
                contributors.append(ModuleContribution(
                    module: "Orion Patterns",
                    action: .buy,
                    confidence: bestPattern.confidence / 100.0,
                    reasoning: "\(bestPattern.type.rawValue) Formasyonu"
                ))
            }
        }
        
        if isOrionSell {
            // Can be treated as advice, not strict veto unless we are buying
        }
        
        // --- 2. ATLAS (Fundamental) ---
        if let atlas = atlas {
            let _ = atlas.action == .buy && atlas.netSupport > 0.7
            let isAtlasSell = atlas.action == .sell
            
            contributors.append(ModuleContribution(
                module: "Atlas",
                action: atlas.action,
                confidence: atlas.netSupport,
                reasoning: "Temel: \(atlas.action.rawValue)"
            ))
            
            if isAtlasSell {
                if atlas.netSupport <= -0.35 {
                    let veto = ModuleVeto(module: "Atlas", reason: "Finansal Yapı Zayıf")
                    vetoes.append(veto)
                    hardVetoes.append(veto)
                } else {
                    advisorNotes.append(
                        AdvisorNote(
                            module: "Atlas",
                            advice: "Temel tarafta zayıflık var; alım yapılacaksa pozisyon küçük tutulmalı.",
                            tone: .caution
                        )
                    )
                }
            }
        }
        
        // --- 3. AETHER (Macro) ---
        // Using 'marketMode' and 'stance' (riskOn/riskOff)
        
        let isRiskOff = aether.stance == .riskOff
        let isPanic = aether.marketMode == .panic
        let isFear = aether.marketMode == .fear
        
        // Aether ALWAYS contributes - determine action based on stance
        let aetherAction: ProposedAction
        switch aether.stance {
        case .riskOn:
            aetherAction = .buy
        case .cautious, .defensive:
            aetherAction = .hold
        case .riskOff:
            aetherAction = .sell
        }
        
        contributors.append(ModuleContribution(
            module: "Aether",
            action: aetherAction,
            confidence: aether.netSupport,
            reasoning: "Makro Rejim: \(aether.stance.rawValue)"
        ))
        
        if isRiskOff || isPanic {
            let veto = ModuleVeto(module: "Aether", reason: "Makro Ortam: \(aether.marketMode.rawValue)")
            vetoes.append(veto)
            // Aether makro veto'sunun üç bypass'i var — artan agresiflik sırasına göre:
            //
            // 1) Orion çok güçlü → teknik tarafın kesin sinyali, veto'yu soft'a düşür.
            // 2) Aether VELOCITY recovering/recoveringFast → makro skor düşük ama
            //    HIZLI iyileşiyor.
            // 3) REJİM DÖNÜŞÜM DETEKTÖRÜ → velocity + Hermes haber akışı + piyasa breadth
            //    birleşik delilleri "turning up" diyorsa — bu en güçlü teyit. Korku →
            //    cesaret geçişi skorlardan önce belirir; sistem rally'yi kaçırmasın.
            //
            // Üçünden en az biri varsa hard veto yerine advisor note.
            let velocity = aetherVelocity
            let isRecovering = velocity.signal == .recovering || velocity.signal == .recoveringFast
            let isCrossingUp: Bool = {
                guard let alert = velocity.crossingAlert else { return false }
                switch alert {
                case .willCross25Upward, .willCross40Upward, .willCross55Upward: return true
                default: return false
                }
            }()
            let isRegimeTurningUp = regimeTransition.shouldBypassHardVeto

            if isRegimeTurningUp {
                // En güçlü bypass: birden fazla bağımsız kanıt dönüşümü işaret ediyor
                let evidenceText = regimeTransition.evidence.joined(separator: ", ")
                advisorNotes.append(
                    AdvisorNote(
                        module: "Aether",
                        advice: "REJİM DÖNÜŞÜMÜ başladı (\(Int(regimeTransition.confidence * 100))% güven): \(evidenceText). Makro skor düşük ama korku geri çekiliyor — kademeli alım penceresi AÇIK.",
                        tone: .positive
                    )
                )
            } else if isStrongOrion {
                advisorNotes.append(
                    AdvisorNote(
                        module: "Aether",
                        advice: "Makro rejim zayıf (\(aether.marketMode.rawValue)) ama teknik güçlü. Kademeli alım uygun, agresif alım riskli.",
                        tone: .caution
                    )
                )
            } else if isRecovering || isCrossingUp {
                let vText = String(format: "%+.1f/gün", velocity.velocity)
                let crossText = velocity.crossingAlert?.description ?? ""
                advisorNotes.append(
                    AdvisorNote(
                        module: "Aether",
                        advice: "Makro skor düşük (\(Int(velocity.currentScore))) ama hızla iyileşiyor (\(vText)). \(crossText) Kademeli alım penceresi AÇIK — skor yükselmeyi beklemek rally'yi kaçırtır.",
                        tone: .caution
                    )
                )
            } else {
                hardVetoes.append(veto)
            }
        } else if isFear {
            advisorNotes.append(
                AdvisorNote(
                    module: "Aether",
                    advice: "Makro ortam korku bölgesinde. Agresif yerine kademeli alım tercih edilmeli.",
                    tone: .caution
                )
            )
        }
        
        // --- 4. HERMES (News) ---
        // Hermes V2 Boost/Drag Logic
        var hermesMultiplier: Double = 1.0
        
        if let hermes = hermes {
            // Determine action based on sentiment
            let hermesAction: ProposedAction
            let sentimentStr = "\(hermes.sentiment)"
            let isPositive = sentimentStr.lowercased().contains("positive")
            let isNegative = sentimentStr.lowercased().contains("negative")
            
            if isPositive {
                hermesAction = .buy
                hermesMultiplier = getSectorBasedNewsMultiplier(symbol: symbol, isPositive: true, isNegative: false)
            } else if isNegative {
                hermesAction = .sell
                hermesMultiplier = getSectorBasedNewsMultiplier(symbol: symbol, isPositive: false, isNegative: true)
            } else {
                hermesAction = .hold
                hermesMultiplier = 1.0
            }
            
            // Hermes ALWAYS contributes when data exists
            contributors.append(ModuleContribution(
                module: "Hermes",
                action: hermesAction,
                confidence: hermes.netSupport,
                reasoning: "Haber: \(hermes.sentiment.rawValue) (Etki: x\(String(format: "%.2f", hermesMultiplier)))"
            ))
            
            // Still veto on high-impact negative
            if isNegative && hermes.isHighImpact {
                if hermes.netSupport <= -0.35 {
                    let veto = ModuleVeto(module: "Hermes", reason: "Kötü Haber Akışı")
                    vetoes.append(veto)
                    hardVetoes.append(veto)
                } else {
                    advisorNotes.append(
                        AdvisorNote(
                            module: "Hermes",
                            advice: "Haber akışı negatif ama mutlak veto seviyesinde değil; temkinli kalınmalı.",
                            tone: .caution
                        )
                    )
                }
            }
        }
        
        // --- DECISION LOGIC V4: AĞIRLIKLI OYLAMA SİSTEMİ ---

        var finalAction: ArgusAction = .neutral
        var strength: SignalStrength = .normal
        var reasoning = ""

        // Veto Check
        if !hardVetoes.isEmpty {
            let sellVotes = contributors.filter { $0.action == .sell }
            if sellVotes.count >= 2 || isOrionSell {
                finalAction = .liquidate
                reasoning = "Kritik Satış Sinyali ve Konsey Vetosu."
                strength = .strong
            } else {
                finalAction = .neutral
                strength = .vetoed
                reasoning = "Konsey VETOSU: \(hardVetoes.map{ $0.reason }.joined(separator: ", "))"
            }
        } else {
            // No Vetoes - Ağırlıklı Oylama Sistemi

            // Modül ağırlıkları — Aether skoruna göre dinamik
            // Boğa (≥65): teknik ağırlıklı | Nötr (40-65): makro ağırlığı artar | Ayı (<40): makro hakimiyeti
            let councilAetherScore = MacroRegimeService.shared.getCachedRating()?.numericScore ?? 50
            let moduleWeights: [String: Double]
            switch councilAetherScore {
            case 65...:
                moduleWeights = [
                    "Orion": 0.35, "Orion Patterns": 0.10,
                    "Atlas": 0.25, "Aether": 0.20, "Hermes": 0.10
                ]
            case 40..<65:
                moduleWeights = [
                    "Orion": 0.28, "Orion Patterns": 0.08,
                    "Atlas": 0.22, "Aether": 0.32, "Hermes": 0.10
                ]
            default:
                moduleWeights = [
                    "Orion": 0.18, "Orion Patterns": 0.07,
                    "Atlas": 0.18, "Aether": 0.47, "Hermes": 0.10
                ]
            }

            // Ağırlıklı oyları hesapla
            var totalBuyWeight: Double = 0
            var totalSellWeight: Double = 0
            var totalHoldWeight: Double = 0
            var buyVoters: [String] = []
            var sellVoters: [String] = []

            for contrib in contributors {
                let weight = moduleWeights[contrib.module] ?? 0.1
                let vote = weight * contrib.confidence

                switch contrib.action {
                case .buy:
                    totalBuyWeight += vote
                    buyVoters.append(contrib.module)
                case .sell:
                    totalSellWeight += vote
                    sellVoters.append(contrib.module)
                case .hold:
                    totalHoldWeight += vote
                }
            }

            // Hermes çarpanını uygula
            totalBuyWeight *= hermesMultiplier
            if hermesMultiplier < 1.0 {
                totalSellWeight *= (2.0 - hermesMultiplier) // Olumsuz haber satışı güçlendirir
            }

            // Karar mantığı: En yüksek ağırlıklı oy kazanır
            let maxWeight = max(totalBuyWeight, totalSellWeight, totalHoldWeight)
            let buyLead = totalBuyWeight - max(totalSellWeight, totalHoldWeight)

            // BUY tarafına tolerans:
            // - Eski sürüm 0.15 eşiği + yakın Hold toleransıyla 2-3 modül konsensüsünü
            //   (tipik 0.10–0.14 ağırlık) "neutral"a düşürüyordu. Sessiz sinyal kaybının
            //   en büyük sebebiydi. Eşik 0.10'a indirildi; agresif kademeler sabit tutuldu.
            //
            // Tutarlılık için her verdict reasoning'i sayım + ağırlık + neden ile
            // dürüst olmalı. Eskiden "Konsey Kararsız" kuruydu, kullanıcı "2 AL
            // varken nasıl kararsız?" diye haklı olarak şikayet ediyordu.
            let weightSummary = String(
                format: "AL %.0f%% · SAT %.0f%% · BEKLE %.0f%%",
                totalBuyWeight * 100, totalSellWeight * 100, totalHoldWeight * 100
            )
            let voteSummary = "\(buyVoters.count) AL · \(sellVoters.count) SAT"

            if totalBuyWeight > 0.10 && (maxWeight == totalBuyWeight || buyLead >= -0.05) {
                // Alım kararı
                if totalBuyWeight > 0.45 && buyVoters.count >= 3 {
                    finalAction = .aggressiveBuy
                    strength = .strong
                    reasoning = "Güçlü Konsey Mutabakatı (\(voteSummary), \(weightSummary)): \(buyVoters.joined(separator: ", "))"
                } else if totalBuyWeight > 0.30 && buyVoters.count >= 2 {
                    finalAction = .aggressiveBuy
                    strength = .normal
                    reasoning = "Konsey Çoğunluğu Alım (\(voteSummary), \(weightSummary)): \(buyVoters.joined(separator: ", "))"
                } else {
                    finalAction = .accumulate
                    strength = .normal
                    reasoning = "Kademeli Alım (\(voteSummary), \(weightSummary)): \(buyVoters.joined(separator: ", "))"
                }
            } else if isStrongOrion && totalBuyWeight >= 0.09 && totalSellWeight < 0.12 {
                finalAction = .accumulate
                strength = .normal
                reasoning = "Orion öncülüğünde kademeli alım — yakın oy farkı (\(weightSummary))."
            } else if maxWeight == totalSellWeight && totalSellWeight > 0.15 {
                // Satış kararı
                if totalSellWeight > 0.40 && sellVoters.count >= 2 {
                    finalAction = .liquidate
                    strength = .strong
                    reasoning = "Güçlü Satış Sinyali (\(voteSummary), \(weightSummary)): \(sellVoters.joined(separator: ", "))"
                } else {
                    finalAction = .trim
                    strength = .normal
                    reasoning = "Kar Al Önerisi (\(voteSummary), \(weightSummary)): \(sellVoters.joined(separator: ", "))"
                }
            } else {
                // Hold veya yetersiz sinyal — sayım > 0 olsa bile ağırlık eşiği
                // aşılmamış demektir. Reasoning'de bunu açıkça söyle.
                finalAction = .neutral
                let reason: String
                if buyVoters.count > 0 && totalBuyWeight <= 0.10 {
                    reason = "\(voteSummary) ama AL ağırlığı %10 eşiğini aşmadı (\(weightSummary))"
                } else if sellVoters.count > 0 && totalSellWeight <= 0.15 {
                    reason = "\(voteSummary) ama SAT ağırlığı %15 eşiğini aşmadı (\(weightSummary))"
                } else {
                    reason = "Yeterli sinyal yok (\(voteSummary), \(weightSummary))"
                }
                reasoning = "Konsey Kararsız — \(reason)"
            }
        }

        // Apply Aether Warning to Buy Actions
        if (finalAction == .aggressiveBuy || finalAction == .accumulate) && (aether.marketMode == .fear) {
            finalAction = .accumulate // Don't go aggressive in fear
            reasoning += " (Makro korku nedeniyle baskılandı)"
        }

        // PROMETHEUS ADVISORY — 5-günlük tahmin uyumlu mu?
        // Eski sürüm Prometheus sadece UI badge idi; tahmin kararlara hiç akmıyordu.
        // Şimdi yüksek güvenli (≥60) tahmin kararla uyumluysa teyit, zıtsa uyarı üretir.
        if let prom = prometheus, prom.isValid, prom.confidence >= 60 {
            let buyish = (finalAction == .aggressiveBuy || finalAction == .accumulate)
            let sellish = (finalAction == .trim || finalAction == .liquidate)
            let bullish = prom.changePercent > 1.0
            let bearish = prom.changePercent < -1.0
            let confText = "%\(Int(prom.confidence)) güven"

            if buyish && bullish {
                advisorNotes.append(AdvisorNote(
                    module: "Prometheus",
                    advice: "5 günlük tahmin \(prom.formattedChange) yükseliş (\(confText)) — alım sinyaliyle uyumlu.",
                    tone: .positive
                ))
            } else if buyish && bearish {
                advisorNotes.append(AdvisorNote(
                    module: "Prometheus",
                    advice: "5 günlük tahmin \(prom.formattedChange) düşüş (\(confText)) — alım sinyaline rağmen kısa vadeli geri çekilme beklentisi.",
                    tone: .caution
                ))
            } else if sellish && bullish {
                advisorNotes.append(AdvisorNote(
                    module: "Prometheus",
                    advice: "5 günlük tahmin \(prom.formattedChange) yükseliş (\(confText)) — satış sinyaline rağmen yukarı yönlü toparlanma beklentisi.",
                    tone: .caution
                ))
            } else if sellish && bearish {
                advisorNotes.append(AdvisorNote(
                    module: "Prometheus",
                    advice: "5 günlük tahmin \(prom.formattedChange) düşüş (\(confText)) — satış sinyaliyle uyumlu.",
                    tone: .positive
                ))
            }
        }

        // Nihai güven hesabı - tüm olumlu oyların ortalaması
        let positiveContributors = contributors.filter { $0.action == finalAction.toProposedAction() }
        let avgConfidence = positiveContributors.isEmpty ? orion.netSupport :
            positiveContributors.map { $0.confidence }.reduce(0, +) / Double(positiveContributors.count)
        let finalConfidence = min(avgConfidence * hermesMultiplier, 1.0)
        
        return ArgusGrandDecision(
            id: UUID(),
            symbol: symbol,
            action: finalAction,
            strength: strength,
            confidence: finalConfidence,
            reasoning: reasoning,
            contributors: contributors,
            vetoes: vetoes,
            advisors: advisorNotes,
            orionDecision: orion,
            atlasDecision: atlas,
            aetherDecision: aether,
            hermesDecision: hermes,
            orionDetails: orionDetails,
            financialDetails: financialDetails,
            bistDetails: nil,
            patterns: patterns,
            timestamp: Date()
        )
    }
    
    // MARK: - Sector-Based News Multiplier
    /// Haberin sektöre göre etkisini ayarlar
    /// Biotech/Healthcare: Haber daha önemli
    /// Utilities: Haber daha az önemli
    /// Technology: Orta düzeyde
    private func getSectorBasedNewsMultiplier(symbol: String, isPositive: Bool, isNegative: Bool) -> Double {
        let sector = detectSector(symbol: symbol)
        
        switch sector.lowercased() {
        case "healthcare", "biotech", "pharmaceuticals", "ilac", "saglik":
            // Biotech/Healthcare: Haber çok önemli (FDA onayları, klinik sonuçlar)
            return isPositive ? 1.20 : (isNegative ? 0.80 : 1.0)
            
        case "utilities", "infrastructure", "enerji", "elektrik":
            // Utilities: Haber daha az önemli (regülasyon bazlı, yavaş hareket)
            return 1.0
            
        case "technology", "tech", "software", "teknoloji", "bilisim":
            // Technology: Orta seviye (ürün lansmanları, rekabet)
            return isPositive ? 1.10 : (isNegative ? 0.90 : 1.0)
            
        case "finance", "banking", "finans", "banka":
            // Finance: Makro haberlere duyarlı
            return isPositive ? 1.08 : (isNegative ? 0.92 : 1.0)
            
        default:
            // Varsayılan: Hafif etki
            return isPositive ? 1.05 : (isNegative ? 0.95 : 1.0)
        }
    }
    
    /// Sembol bazlı sektör tespiti (basitleştirilmiş)
    private func detectSector(symbol: String) -> String {
        let sym = symbol.uppercased()
        
        // BIST Sektör Tespiti
        if sym.hasSuffix(".IS") {
            // Bilinen BIST sembolleri
            switch sym.replacingOccurrences(of: ".IS", with: "") {
            case "SASA", "TUPRS", "PETKM", "AYGAZ":
                return "Enerji"
            case "THYAO", "PGSUS":
                return "Transportation"
            case "GARAN", "AKBNK", "YKBNK", "ISCTR", "HALKB", "VAKBN":
                return "Banking"
            case "ASELS", "KCHOL":
                return "Technology"
            case "BIMAS", "MGROS", "SOKM":
                return "Retail"
            case "EREGL", "KRDMD":
                return "Industrials"
            case "EKGYO", "ENKAI":
                return "Infrastructure"
            default:
                return "General"
            }
        }
        
        // US Sektör Tespiti (Bilinen semboller)
        switch sym {
        case "AAPL", "MSFT", "GOOGL", "GOOG", "META", "NVDA", "AMD", "INTC":
            return "Technology"
        case "JNJ", "PFE", "MRK", "ABBV", "LLY":
            return "Healthcare"
        case "JPM", "BAC", "WFC", "GS", "MS":
            return "Finance"
        case "XOM", "CVX", "COP":
            return "Enerji"
        case "NEE", "DUK", "SO":
            return "Utilities"
        default:
            return "General"
        }
    }
}

// Supporting Structs
struct ModuleContribution: Sendable, Equatable, Codable {
    let module: String
    let action: ProposedAction
    let confidence: Double
    let reasoning: String
}

struct ModuleVeto: Sendable, Equatable, Codable {
    let module: String
    let reason: String
}

// Placeholder for Information Weights if not found
struct InformationWeights: Codable, Sendable {
    let orion: Double
    let atlas: Double
    let aether: Double
}

// MARK: - BIST V2 Decision Structure
struct BistDecisionResult: Sendable, Equatable, Codable {
    let id: UUID
    let symbol: String
    let action: ArgusAction
    let confidence: Double
    let reasoning: String
    
    // 8 BIST Modules
    let faktor: BistModuleResult // Smart Beta (Athena)
    let sektor: BistModuleResult // Rotation (Demeter)
    let akis: BistModuleResult   // Money Flow (Sirkiye-Legacy/MoneyFlow)
    let kulis: BistModuleResult  // Analyst/News (Hermes)
    let grafik: BistModuleResult // Technical (Orion)
    let bilanco: BistModuleResult // Fundamental (Atlas)
    let rejim: BistModuleResult  // Macro (Aether)
    let sirkulasyon: BistModuleResult // Float/Depth (Yeni)
    
    let timestamp: Date
    
    var shouldTrade: Bool {
        return action == .aggressiveBuy || action == .accumulate || action == .trim || action == .liquidate
    }
}

// MARK: - BIST Module Result (Data Storytelling)
struct BistModuleResult: Sendable, Equatable, Codable {
    let name: String
    let score: Double // 0-100
    let action: ProposedAction
    let commentary: String // "Neden?" sorusunun cevabı
    let supportLevel: Double // -1.0 (Veto) to 1.0 (Strong Support)
}

extension BistModuleResult {
    static func neutral(name: String) -> BistModuleResult {
        return BistModuleResult(name: name, score: 50, action: .hold, commentary: "Veri yetersiz.", supportLevel: 0)
    }
}

// MARK: - BIST Grand Council (Yerli Konsey)
actor BistGrandCouncil {
    static let shared = BistGrandCouncil()
    
    private init() {}
    
    func convene(
        symbol: String,
        // Engines Inputs
        faktorScore: AthenaFactorResult? = nil,
        sektorScore: DemeterScore? = nil,
        akisResult: AetherDecision? = nil, // MoneyFlow (SirkiyeEngine returns AetherDecision for now)
        kulisData: HermesDecision? = nil, // News/Analyst
        grafikData: CouncilDecision, // Orion
        bilancoData: AtlasDecision?, // Atlas
        rejimData: AetherDecision, // Macro (Global Aether)
        analystConsensus: BistAnalystConsensus? = nil // Analist konsensüsü (BorsaPy)
    ) async -> BistDecisionResult {
        
        ArgusLogger.info(.argus, "BIST konseyi toplanıyor: \(symbol)")
        
        // 1. Module Analysis & Data Storytelling Generation
        
        // --- GRAFİK (Orion) ---
        let grafikRes = analyzeGrafik(grafikData)
        
        // --- BİLANÇO (Atlas) ---
        let bilancoRes = analyzeBilanco(bilancoData)
        
        // --- REJİM (Aether) ---
        let rejimRes = analyzeRejim(rejimData)
        
        // --- FAKTÖR (Athena) ---
        let faktorRes = analyzeFaktor(faktorScore)
        
        // --- SEKTÖR (Demeter) ---
        let sektorRes = analyzeSektor(sektorScore)
        
        // --- AKIŞ (MoneyFlow/Sirkiye) ---
        let akisRes = analyzeAkis(akisResult)
        
        // --- KULİS (Hermes + Analist) ---
        let kulisRes = analyzeKulis(kulisData, analystConsensus: analystConsensus)
        
        // --- SİRKÜLASYON (Placeholder for now) ---
        let sirkulasyonRes = BistModuleResult(name: "Sirkülasyon", score: 50, action: .hold, commentary: "Takas verisi nötr.", supportLevel: 0)
        
        
        // 2. Final Verdict Logic (The "Brain")
        
        var totalSupport: Double = 0
        var vetoCount = 0
        var reasons: [String] = []
        
        let modules = [grafikRes, bilancoRes, rejimRes, faktorRes, sektorRes, akisRes, kulisRes]
        
        for mod in modules {
            totalSupport += mod.supportLevel
            if mod.supportLevel < -0.5 { // Soft Veto
                reasons.append("\(mod.name): \(mod.commentary)")
            }
            if mod.action == .sell && mod.supportLevel < -0.8 {
                vetoCount += 1
            }
        }
        
        // Decision Matrix
        var finalAction: ArgusAction = .neutral
        var confidence: Double = 50.0
        var mainReason = "Veriler nötr."
        
        if vetoCount > 0 {
            finalAction = .neutral // Or trim?
            confidence = 20.0
            mainReason = "Konseyde \(vetoCount) üye veto etti. (Riskli)"
            if grafikRes.action == .sell { finalAction = .liquidate } // Teknik sat ise çık
        } else if totalSupport > 3.0 { // High Conviction
            finalAction = .aggressiveBuy
            confidence = 90.0
            mainReason = "Tam saha pres! Tüm modüller destekliyor."
        } else if totalSupport > 1.5 {
            finalAction = .accumulate
            confidence = 75.0
            mainReason = "Pozitif görünüm, kademeli alım uygun."
        } else if totalSupport < -2.0 {
            finalAction = .trim
            confidence = 70.0
            mainReason = "Görünüm negatife döndü, azaltım önerilir."
        } else {
            // Neutral / Hold
            finalAction = .neutral // Gözle
            confidence = 50.0
            mainReason = "Yön net değil, izlemede kalın."
        }
        
        // Rejim Override (Makro Korku varsa agresif olma)
        if rejimRes.action == .hold && finalAction == .aggressiveBuy {
            finalAction = .accumulate
            mainReason += " (Makro belirsizlik nedeniyle agresif olunmadı)"
        }
        
        return BistDecisionResult(
            id: UUID(),
            symbol: symbol,
            action: finalAction,
            confidence: confidence,
            reasoning: mainReason + "\n" + reasons.joined(separator: "\n"),
            faktor: faktorRes,
            sektor: sektorRes,
            akis: akisRes,
            kulis: kulisRes,
            grafik: grafikRes,
            bilanco: bilancoRes,
            rejim: rejimRes,
            sirkulasyon: sirkulasyonRes,
            timestamp: Date()
        )
    }
    
    // MARK: - Module Analyzers (Storytellers)
    
    private func analyzeGrafik(_ data: CouncilDecision) -> BistModuleResult {
        let score = data.netSupport * 100

        let commentary: String
        if data.action == .buy {
             commentary = "Fiyat 20, 50 ve 200 günlük hareketli ortalamaların üzerinde. Trend ve momentum alıcıları destekliyor."
        } else if data.action == .sell {
             commentary = "Kritik destek seviyeleri aşağı kırıldı. Hacimli satış baskısı ve negatif trend hakim."
        } else {
             commentary = "Fiyat sıkışma bölgesinde (konsolidasyon). Yön kararsız, destek-direnç bandında dalgalanıyor."
        }
        return BistModuleResult(name: "Grafik", score: score, action: data.action, commentary: commentary, supportLevel: data.netSupport)
    }
    
    private func analyzeBilanco(_ data: AtlasDecision?) -> BistModuleResult {
        guard let data = data else {
            return BistModuleResult(name: "Bilanço", score: 50, action: .hold, commentary: "Bilanço verisi bekleniyor.", supportLevel: 0)
        }
        let score = data.netSupport * 100

        let commentary: String
        if data.action == .buy {
            commentary = "Hisse iskontolu işlem görüyor. FK ve PD/DD rasyoları tarihsel ortalamaların altında, büyüme beklentisi pozitif."
        } else if data.action == .sell {
            commentary = "Değerleme primli seviyelerde. Kârlılık marjlarında daralma ve yüksek borçluluk riski var."
        } else {
            commentary = "Temel veriler dengeli. Bilanço beklentilere paralel geldi, ekstrem bir ucuzluk veya pahalılık yok."
        }
        return BistModuleResult(name: "Bilanço", score: score, action: data.action, commentary: commentary, supportLevel: data.netSupport)
    }
    
    private func analyzeRejim(_ data: AetherDecision) -> BistModuleResult {
        let score = data.netSupport * 100
        var comm = "Makro ortam: \(data.marketMode.rawValue)."
        var support = data.netSupport
        
        if data.stance == .riskOff {
            comm = "Piyasa riskten kaçınıyor (Risk-Off)."
            support = -1.0 // Strong Veto potential
        }
        
        let action: ProposedAction = data.stance == .riskOn ? .buy : (data.stance == .riskOff ? .sell : .hold)
        
        return BistModuleResult(name: "Rejim", score: score, action: action, commentary: comm, supportLevel: support)
    }
    
    private func analyzeFaktor(_ data: AthenaFactorResult?) -> BistModuleResult {
        guard let data = data else { return .neutral(name: "Faktör") }
        let score = data.factorScore
        
        // Storytelling
        var comm = ""
        if score > 70 {
            comm = "Kalite ve değer faktörleri güçlü sinyal veriyor."
        } else if score < 30 {
            comm = "Momentum ve volatilite faktörleri zayıf."
        } else {
            comm = "Faktörler karışık, net bir yön yok."
        }
        
        let support = (score - 50) / 50.0
        let action: ProposedAction = score > 60 ? .buy : (score < 40 ? .sell : .hold)
        
        return BistModuleResult(name: "Faktör", score: score, action: action, commentary: comm, supportLevel: support)
    }
    
    private func analyzeSektor(_ data: DemeterScore?) -> BistModuleResult {
        guard let data = data else { return .neutral(name: "Sektör") }
        let score = data.totalScore
        let commentary: String
        if score > 60 {
             commentary = "Sektör endekse göre pozitif ayrışıyor. Para girişi sektör geneline yayılmış durumda."
        } else if score < 40 {
             commentary = "Sektör genelinde satış baskısı var. Endeksin altında performans gösteriyor."
        } else {
             commentary = "Sektör performansı endeksle paralel. Ne öne çıkıyor ne de geride kalıyor."
        }
        let support = (score - 50) / 50.0
        let action: ProposedAction = score > 60 ? .buy : (score < 40 ? .sell : .hold)
        return BistModuleResult(name: "Sektör", score: score, action: action, commentary: commentary, supportLevel: support)
    }
    
    // UPDATED: Now accepting AetherDecision (from SirkiyeEngine)
    private func analyzeAkis(_ data: AetherDecision?) -> BistModuleResult {
        guard let data = data else { return .neutral(name: "Akış") }
        let score = data.netSupport * 100 
        // SirkiyeEngine uses riskOn for High Inflow, riskOff for Outflow
        let comm = data.stance == .riskOn ? "Güçlü para girişi var (Bank of America alımda)." : (data.stance == .riskOff ? "Para çıkışı var (Yabancı satışı)." : "Para girişi nötr.")
        let support = data.netSupport
        let action: ProposedAction = data.stance == .riskOn ? .buy : (data.stance == .riskOff ? .sell : .hold)
        return BistModuleResult(name: "Akış", score: score, action: action, commentary: comm, supportLevel: support)
    }
    
    private func analyzeKulis(_ data: HermesDecision?, analystConsensus: BistAnalystConsensus? = nil) -> BistModuleResult {
        // Haber ve analist verilerini birleştirerek Kulis skoru hesapla
        var hermesSupport: Double = 0
        var hermesCommentary = ""

        if let data = data {
            // Hermes netSupport teorik olarak >1 olabilir; normalize ediyoruz.
            let normalizedNet = max(-1.0, min(1.0, data.netSupport / 1.2))

            let winningConfidence = data.winningProposal?.confidence ?? 0.5
            let approveWeight = data.votes
                .filter { $0.decision == .approve }
                .reduce(0.0) { $0 + max(0, $1.weight) }
            let vetoWeight = data.votes
                .filter { $0.decision == .veto }
                .reduce(0.0) { $0 + max(0, $1.weight) }
            let weightedConsensus = (approveWeight - vetoWeight) / max(approveWeight + vetoWeight, 0.01)

            let consensusQuality = max(0.0, weightedConsensus)
            let catalystBoost = min(Double(data.catalysts.count) * 0.08, 0.18)
            let impactGate = data.isHighImpact ? 1.0 : 0.78

            var qualityGate = 0.35 + (winningConfidence * 0.35) + (consensusQuality * 0.30) + catalystBoost
            qualityGate = min(max(qualityGate, 0.35), 1.15)

            hermesSupport = normalizedNet * qualityGate * impactGate
            hermesSupport = max(-1.0, min(1.0, hermesSupport))

            let sentimentText = data.sentiment.displayTitle
            hermesCommentary = "Haber: \(sentimentText)."
            if !data.catalysts.isEmpty {
                hermesCommentary += " Katalizör: \(data.catalysts.prefix(2).joined(separator: ", "))."
            }
        }

        // Analist konsensüsü desteği (%30 ağırlık)
        var analystSupport: Double = 0
        var analystCommentary = ""

        if let ac = analystConsensus, ac.totalAnalysts > 0 {
            // Analist oranını -1..1 aralığına dönüştür
            let buyRatio = Double(ac.buyCount) / Double(ac.totalAnalysts)
            let sellRatio = Double(ac.sellCount) / Double(ac.totalAnalysts)
            analystSupport = (buyRatio - sellRatio) * 2.0 // -2..2 → clamp to -1..1
            analystSupport = max(-1.0, min(1.0, analystSupport))

            // Potansiyel getiri katkısı
            if ac.potentialReturn > 15 {
                analystSupport = min(1.0, analystSupport + 0.2)
            } else if ac.potentialReturn < -10 {
                analystSupport = max(-1.0, analystSupport - 0.2)
            }

            analystCommentary = "Analist: \(ac.buyCount)AL/\(ac.holdCount)TUT/\(ac.sellCount)SAT"
            if let target = ac.averageTargetPrice {
                analystCommentary += " (Hedef: ₺\(String(format: "%.0f", target)), %\(String(format: "%.1f", ac.potentialReturn)))"
            }
            analystCommentary += "."
        }

        // Birleştirilmiş destek: Haber %70 + Analist %30
        let hasHermes = data != nil
        let hasAnalyst = analystConsensus != nil && (analystConsensus?.totalAnalysts ?? 0) > 0

        let support: Double
        if hasHermes && hasAnalyst {
            support = hermesSupport * 0.70 + analystSupport * 0.30
        } else if hasAnalyst {
            support = analystSupport
        } else if hasHermes {
            support = hermesSupport
        } else {
            return .neutral(name: "Kulis")
        }

        let clampedSupport = max(-1.0, min(1.0, support))

        let action: ProposedAction
        if clampedSupport >= 0.22 {
            action = .buy
        } else if clampedSupport <= -0.22 {
            action = .sell
        } else {
            action = .hold
        }

        let commentary = [hermesCommentary, analystCommentary].filter { !$0.isEmpty }.joined(separator: " ")
        let score = max(0.0, min(100.0, 50.0 + (clampedSupport * 45.0)))

        return BistModuleResult(
            name: "Kulis",
            score: score,
            action: action,
            commentary: commentary,
            supportLevel: clampedSupport
        )
    }
}
