import Foundation

// MARK: - Alkindus Calibration Engine
/// The brain of Alkindus. Observes decisions, waits for maturation, and updates calibration.
/// Phase 1: Shadow Mode - Observes only, does not influence decisions.

actor AlkindusCalibrationEngine {
    static let shared = AlkindusCalibrationEngine()
    
    private let memoryStore = AlkindusMemoryStore.shared
    
    private init() {}
    
    // MARK: - Observe Decision (Called by ArgusDecisionEngine)
    
    /// Called when a new decision is made. Records it for future evaluation.
    /// Faz 2.3: Artık HOLD ve VETOED kararları da kaydedilir (kaçırılan fırsat tespiti için).
    /// Tek taraflı öğrenme (sadece BUY/SELL'den) önyargılıdır — HOLD'da fiyat patladıysa
    /// bu bilgi de Chiron'un "ne zaman tetik çekmiyorum" pattern'ini öğrenmesine yardım eder.
    func observe(
        symbol: String,
        action: String,
        moduleScores: [String: Double],
        regime: String,
        currentPrice: Double,
        reasoning: String = ""
    ) async {
        // Skip ancak gerçekten actionable olmayan veya snapshot yapılmaması gereken
        // durumlar için. BUY/SELL/HOLD/VETOED kabul; SKIP/WAIT geçilir.
        let acceptedActions: Set<String> = ["BUY", "SELL", "HOLD", "VETOED"]
        guard acceptedActions.contains(action) else { return }

        let observation = PendingObservation(
            symbol: symbol,
            decisionDate: Date(),
            action: action,
            moduleScores: moduleScores,
            regime: regime,
            priceAtDecision: currentPrice,
            horizons: [7, 15],
            reasoning: reasoning
        )

        // 2026-05-09: Sembol-başı-tek-slot.
        // Aynı sembol için zaten aktif test (henüz T+15'i tamamlamamış
        // pending observation) varsa yenisini açmıyoruz. Bu kuralla:
        //   - Pending kuyruğu watchlist boyutuyla doğal sınırlanır
        //     (eski 500 hard cap pratikte gereksizleşir)
        //   - Her sembolün 15 günlük öğrenme döngüsü kesintisiz tamamlanır
        //   - Verdict üretildiği an pending'den temizlenir → bir sonraki
        //     `observe()` çağrısı otomatik olarak yeni testi başlatır
        let added = await memoryStore.appendPendingObservationIfAbsent(observation)
        if added {
            print("Alkindus: Yeni test başlatıldı — \(symbol) \(action)")
        } else {
            print("Alkindus: \(symbol) zaten test ediliyor, atlandı")
        }
    }

    // MARK: - Periodic Maturation Check

    /// Periyodik maturation kontrolü - App başlangıcında ve saatlik tetiklenir
    func periodicMatureCheck() async {
        // Load pending observations
        let pending = await memoryStore.loadPendingObservations()

        guard !pending.isEmpty else {
            print("⚠️ Alkindus: Bekleyen gözlem yok, maturation atlanıyor")
            return
        }

        // Olgunlaşmış horizon'u olan sembolleri derle — sadece bunların fiyatına ihtiyaç var.
        // Henüz olgunlaşmamış observation'lar için API çağrısı israf olur.
        let maturedSymbols: Set<String> = Set(pending.compactMap { obs in
            let hasMature = obs.horizons.contains { obs.isHorizonMature($0) }
            return hasMature ? obs.symbol : nil
        })

        // 1. Cache'den fiyat topla (MainActor context'inde)
        var currentPrices: [String: Double] = await MainActor.run {
            let store = MarketDataStore.shared
            var prices: [String: Double] = [:]
            for symbol in maturedSymbols {
                if let quote = store.quotes[symbol]?.value, quote.currentPrice > 0 {
                    prices[symbol] = quote.currentPrice
                }
            }
            return prices
        }

        // 2. Cache'de olmayan olgun semboller için API'dan çek (ensureQuote SWR pattern'i kullanır).
        // Eski sürümde bu fallback yoktu → uzun süre quote'u sorgulanmamış semboller (örn. detay
        // ekranı hiç açılmamışsa) için maturation sonsuza dek pending kalıyordu.
        let missingSymbols = maturedSymbols.subtracting(currentPrices.keys)
        if !missingSymbols.isEmpty {
            print("👁️ Alkindus: \(missingSymbols.count) olgun sembol için fiyat cache'de yok, API'dan çekiliyor...")
            for symbol in missingSymbols {
                let dataValue = await MarketDataStore.shared.ensureQuote(symbol: symbol)
                if let price = dataValue.value?.currentPrice, price > 0 {
                    currentPrices[symbol] = price
                    print("👁️ Alkindus: \(symbol) fiyat API'dan alındı: \(price)")
                } else {
                    print("⚠️ Alkindus: \(symbol) için fiyat alınamadı, karar sonraki turda değerlendirilecek")
                }
            }
        }

        // Fiyatı olan kararlar değerlendirilir, olmayanlar atlanır — processMaturedDecisions her
        // sembol için ayrı kontrol yapıyor. Eski guard burada HİÇBİR kararın değerlendirilmesini
        // engelliyordu; kaldırıldı.
        if currentPrices.isEmpty && !maturedSymbols.isEmpty {
            print("⚠️ Alkindus: Olgun semboller var (\(maturedSymbols.count)) ama hiçbiri için fiyat alınamadı")
        }

        let evaluatedCount = await processMaturedDecisions(currentPrices: currentPrices)
        let remainingCount = await memoryStore.loadPendingObservations().count
        print("✅ Alkindus: Maturation check tamamlandı — \(evaluatedCount) değerlendirildi, \(remainingCount) bekliyor")
    }

    // MARK: - Process Matured Decisions (Called periodically)
    
    /// Checks all pending observations and evaluates those that have matured.
    func processMaturedDecisions(currentPrices: [String: Double]) async -> Int {
        var pending = await memoryStore.loadPendingObservations()
        var evaluatedCount = 0
        
        for i in pending.indices {
            var observation = pending[i]
            
            // Check each horizon
            for horizon in observation.horizons {
                guard observation.isHorizonMature(horizon) else { continue }
                guard !observation.evaluatedHorizons.contains(horizon) else { continue }
                
                // Get current price
                guard let currentPrice = currentPrices[observation.symbol] else { continue }
                
                // Evaluate outcome — R-multiple grade ile (Faz 2.1)
                let outcome = evaluateOutcomeDetailed(
                    action: observation.action,
                    entryPrice: observation.priceAtDecision,
                    currentPrice: currentPrice
                )
                let wasCorrect = outcome.wasCorrect
                if outcome.grade == .excellent || outcome.grade == .stopped {
                    print("📊 Alkindus: \(observation.symbol) \(observation.action) horizon=\(horizon)d → \(outcome.grade.rawValue.uppercased()) (entry=\(String(format: "%.2f", observation.priceAtDecision)), now=\(String(format: "%.2f", currentPrice)))")
                }
                
                // Update calibration for each module that voted (with weighted brackets)
                for (module, score) in observation.moduleScores {
                    // Use weighted brackets to reduce edge effects at boundaries
                    let weightedBrackets = scoreToBracketsWeighted(score)
                    for (bracket, weight) in weightedBrackets {
                        await memoryStore.recordOutcomeWeighted(
                            module: module,
                            scoreBracket: bracket,
                            wasCorrect: wasCorrect,
                            weight: weight,
                            regime: observation.regime
                        )
                    }

                    // Phase 2: Track anomaly detection data
                    await AlkindusAnomalyDetector.shared.recordModulePerformance(
                        module: module,
                        score: score,
                        wasCorrect: wasCorrect
                    )
                }
                
                // Phase 2: Track correlation data
                await AlkindusCorrelationTracker.shared.recordCorrelation(
                    modules: observation.moduleScores,
                    wasCorrect: wasCorrect
                )
                
                // Phase 3: Track symbol-specific performance
                let isBist = observation.symbol.uppercased().hasSuffix(".IS")
                for (module, _) in observation.moduleScores {
                    await AlkindusSymbolLearner.shared.recordOutcome(
                        symbol: observation.symbol,
                        module: module,
                        wasCorrect: wasCorrect,
                        isBist: isBist
                    )
                    
                    // Phase 3: Track temporal patterns
                    await AlkindusTemporalAnalyzer.shared.recordOutcome(
                        module: module,
                        wasCorrect: wasCorrect,
                        timestamp: observation.decisionDate,
                        symbol: observation.symbol
                    )
                }
                
                // Mark this horizon as evaluated
                observation.evaluatedHorizons.append(horizon)
                evaluatedCount += 1

                let result = wasCorrect ? "✅ DOĞRU" : "❌ YANLIŞ"
                print("👁️ Alkindus: T+\(horizon) değerlendirme - \(observation.symbol) \(result)")

                // Faz 2.2: Alkindus → Chiron köprüsü.
                // Sadece BUY observation'ları + non-breakeven sonuçlar için anlamlı.
                // Trade kapatma çok seyrek; horizon eval daha hızlı. Bu köprü
                // olmadan Chiron sadece kapatılan trade'lerden öğreniyordu — şimdi
                // 7-15 günlük horizon outcome'lar da öğrenmeye katkı sağlıyor.
                if observation.action == "BUY" && outcome.grade != .breakeven {
                    let chironOutcome: ChironLearningSystem.TradeExperience.TradeOutcome
                    switch outcome.grade {
                    case .excellent, .good: chironOutcome = .winner
                    case .loss, .stopped:   chironOutcome = .loser
                    case .breakeven:        chironOutcome = .scratch
                    }
                    let symbol = observation.symbol
                    let priceChangePct = ((currentPrice - observation.priceAtDecision) / max(observation.priceAtDecision, 0.0001)) * 100
                    let durationSec = TimeInterval(horizon * 86400)
                    Task.detached(priority: .background) {
                        let weights = await ChironLearningSystem.shared.getCurrentState().weights
                        await ChironLearningSystem.shared.recordTrade(
                            symbol: symbol,
                            weights: weights,
                            outcome: chironOutcome,
                            duration: durationSec,
                            profitPercent: priceChangePct
                        )
                    }
                }

                // Post-mortem: her modülün tezi tutup tutmadığını belirle ve RAG'e kaydet
                let priceChange = ((currentPrice - observation.priceAtDecision) / max(observation.priceAtDecision, 0.0001)) * 100
                var moduleVerdictStructs: [ModuleVerdict] = []
                var moduleVerdictStrings: [String] = []
                for (module, score) in observation.moduleScores.sorted(by: { $0.key < $1.key }) {
                    let moduleBullish = score >= 50
                    let moduleCorrect = (moduleBullish && priceChange > 0) || (!moduleBullish && priceChange < 0)
                    moduleVerdictStructs.append(ModuleVerdict(module: module, score: score, wasCorrect: moduleCorrect))
                    moduleVerdictStrings.append("\(module.uppercased()) \(Int(score)) \(moduleCorrect ? "✓" : "✗")")
                }

                // Save structured verdict for UI display
                let verdict = AlkindusVerdict(
                    symbol: observation.symbol,
                    action: observation.action,
                    decisionDate: observation.decisionDate,
                    evaluationDate: Date(),
                    horizon: horizon,
                    wasCorrect: wasCorrect,
                    priceChange: priceChange,
                    regime: observation.regime,
                    moduleVerdicts: moduleVerdictStructs,
                    originalReasoning: observation.reasoning.isEmpty ? "Gerekçe kaydedilmemiş" : observation.reasoning
                )
                await memoryStore.saveVerdict(verdict)

                let outcomeText = """
                T+\(horizon) gün sonuç: \(String(format: "%+.1f", priceChange))% | Tez \(wasCorrect ? "DOĞRU" : "YANLIŞ")
                Rejim: \(observation.regime)
                Modüller: \(moduleVerdictStrings.joined(separator: " · "))
                """
                let obsReasoning = observation.reasoning.isEmpty ? "Gerekçe kaydedilmemiş" : observation.reasoning
                let obsConfidence = (observation.moduleScores.values.reduce(0, +) / Double(max(observation.moduleScores.count, 1))) / 100
                Task.detached(priority: .background) {
                    await AlkindusRAGEngine.shared.syncDecision(
                        symbol: observation.symbol,
                        action: observation.action,
                        confidence: obsConfidence,
                        reasoning: obsReasoning,
                        outcome: outcomeText
                    )
                }
            }
            
            pending[i] = observation
        }
        
        // Remove fully evaluated observations
        pending = pending.filter { !$0.isFullyEvaluated }

        // KRİTİK TEMİZLİK: 30+ günden eski henüz değerlendirilmemiş gözlemler çöpe.
        // Max horizon 15 gün — 30 günden eski hâlâ pending ise fiyat verisi artık
        // alınamayacak demektir (sembol delisted, feed bozuk, etc.). Bunları sonsuza
        // dek tutmak memory şişmesine yol açıyordu (gözlenen: 856 bekleyen).
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let beforeCleanup = pending.count
        pending = pending.filter { $0.decisionDate >= thirtyDaysAgo }
        let cleaned = beforeCleanup - pending.count
        if cleaned > 0 {
            print("🧹 Alkindus: \(cleaned) eski (30+ gün) gözlem temizlendi, kalan \(pending.count)")
        }

        // 2026-05-09: 500 hard cap kaldırıldı.
        // Sembol-başı-tek-slot kuralı (`appendPendingObservationIfAbsent`)
        // pending kuyruğunu watchlist boyutuyla doğal sınırlıyor. 30 günlük
        // yaş filtresi güvenlik ağı olarak yeterli. Eski cap T+15 dolmadan
        // gözlemleri buduyordu — öğrenme döngüsü hiç kapanmıyordu.

        await memoryStore.savePendingObservations(pending)

        return evaluatedCount
    }
    
    // MARK: - Outcome Evaluation

    /// Trade outcome derecelendirmesi — R-multiple bazlı (Faz 2.1).
    /// Eski sistem sadece "fiyat yukarı/aşağı" diye bool döndürüyordu;
    /// %0.5'lik artış ile %20'lik artış aynı sayılıyordu. Bu, Alkindus'un
    /// "iyi karar" vs "harika karar"ı ayırt etmesini engelliyordu.
    enum TradeOutcomeGrade: String, Codable {
        case excellent  // 2R+ kazanç (sinyal mükemmel)
        case good       // 1-2R kazanç (sinyal iyi)
        case breakeven  // 0-1R hareket (nötr)
        case loss       // 0-1R kayıp (sinyal zayıf)
        case stopped    // 1R+ kayıp (sinyal kötü)

        var isPositive: Bool { self == .excellent || self == .good }
    }

    private func evaluateOutcome(action: String, entryPrice: Double, currentPrice: Double) -> Bool {
        evaluateOutcomeDetailed(action: action, entryPrice: entryPrice, currentPrice: currentPrice).wasCorrect
    }

    /// Detaylı sonuç değerlendirmesi: hem boolean (geriye uyumlu) hem grade.
    /// 1R = %3 standart risk birimi (ATR-tipi varsayım).
    /// Faz 2.3: HOLD/VETOED için kaçırılan fırsat tespiti.
    private func evaluateOutcomeDetailed(action: String, entryPrice: Double, currentPrice: Double)
        -> (wasCorrect: Bool, grade: TradeOutcomeGrade) {
        let change = (currentPrice - entryPrice) / entryPrice
        let assumedRiskUnit = 0.03

        let basicCorrect: Bool
        let directionalChange: Double

        switch action {
        case "BUY":
            basicCorrect = change > 0
            directionalChange = change
        case "SELL":
            basicCorrect = change < 0
            directionalChange = -change
        case "HOLD":
            // HOLD doğru karardır eğer fiyat 1R'den fazla SAPMAMIŞSA (sakin kalmak iyi).
            // Yanlış karardır eğer 2R+ kaçırılan fırsat varsa.
            basicCorrect = abs(change) < assumedRiskUnit
            // HOLD'da grade tersine: az hareket = good, büyük hareket = stopped (kaçırıldı)
            let absChange = abs(change) / assumedRiskUnit
            let grade: TradeOutcomeGrade
            switch absChange {
            case 0..<0.5:  grade = .excellent  // %1.5 altı: HOLD mükemmel
            case 0.5..<1:  grade = .good       // %1.5-3: HOLD iyi
            case 1..<2:    grade = .breakeven  // %3-6: ortalama
            case 2..<3:    grade = .loss       // %6-9: kaçırılan fırsat
            default:       grade = .stopped    // %9+: ciddi kaçırılan fırsat
            }
            return (basicCorrect, grade)
        case "VETOED":
            // VETO doğru karardır eğer veto edilen yönde fiyat KÖTÜ gitseydi.
            // Şu anki bilgiyle veto'nun yönünü bilmiyoruz (BUY veto mu, SELL veto mu).
            // Pragmatik: VETO sonrası fiyat sakin kaldıysa veya düştüyse veto doğru.
            basicCorrect = change <= assumedRiskUnit
            let absChange = abs(change) / assumedRiskUnit
            let grade: TradeOutcomeGrade = absChange < 1 ? .good : .loss
            return (basicCorrect, grade)
        default:
            return (false, .breakeven)
        }

        // BUY/SELL için R-multiple grade — 1R = %3 (standart risk birimi varsayımı)
        let rMultiple = directionalChange / assumedRiskUnit
        let grade: TradeOutcomeGrade
        switch rMultiple {
        case 2...:        grade = .excellent
        case 1..<2:       grade = .good
        case 0..<1:       grade = .breakeven
        case -1..<0:      grade = .loss
        default:          grade = .stopped
        }
        return (basicCorrect, grade)
    }
    
    // MARK: - Score to Bracket Mapping

    /// Soft boundaries: scores near thresholds get shifted slightly
    /// This reduces edge effects where 79.9 and 80.0 fall in different buckets
    private func scoreToBracket(_ score: Double) -> String {
        // Soft boundaries: ±2 point tolerance
        switch score {
        case 78...: return "80-100"  // 78+ goes to upper bracket
        case 58..<78: return "60-80"
        case 38..<58: return "40-60"
        case 18..<38: return "20-40"
        default: return "0-20"
        }
    }

    /// Weighted bracket contribution for boundary regions
    /// Scores near thresholds contribute to both adjacent brackets
    private func scoreToBracketsWeighted(_ score: Double) -> [(bracket: String, weight: Double)] {
        // Boundary regions: scores within ±2 of threshold contribute to both brackets
        let boundaries: [(threshold: Double, brackets: (lower: String, upper: String))] = [
            (80, ("60-80", "80-100")),
            (60, ("40-60", "60-80")),
            (40, ("20-40", "40-60")),
            (20, ("0-20", "20-40"))
        ]

        for (threshold, brackets) in boundaries {
            if score >= threshold - 2 && score <= threshold + 2 {
                // Interpolate: e.g., score=78 -> 0.5 lower, 0.5 upper
                // score=76 -> 1.0 lower, 0.0 upper
                // score=82 -> 0.0 lower, 1.0 upper
                let ratio = (score - (threshold - 2)) / 4.0
                return [(brackets.lower, 1 - ratio), (brackets.upper, ratio)]
            }
        }

        // Normal single bracket (outside boundary regions)
        return [(scoreToBracket(score), 1.0)]
    }
    
    // MARK: - Get Current Stats (For UI)
    
    func getCurrentStats() async -> AlkindusStats {
        let calibration = await memoryStore.loadCalibration()
        let pending = await memoryStore.loadPendingObservations()
        
        return AlkindusStats(
            calibration: calibration,
            pendingCount: pending.count,
            lastUpdated: calibration.lastUpdated
        )
    }
}

// MARK: - Stats Model for UI

struct AlkindusStats {
    let calibration: CalibrationData
    let pendingCount: Int
    let lastUpdated: Date

    // Get top performing module
    var topModule: (name: String, hitRate: Double)? {
        var best: (String, Double)? = nil

        for (module, cal) in calibration.modules {
            // Consider only 60+ brackets
            let highBrackets = cal.brackets.filter { $0.key == "60-80" || $0.key == "80-100" }
            let totalAttempts = highBrackets.values.reduce(0.0) { $0 + $1.attempts }
            let totalCorrect = highBrackets.values.reduce(0.0) { $0 + $1.correct }

            guard totalAttempts >= 5 else { continue } // Minimum sample size

            let rate = totalCorrect / totalAttempts
            if best == nil || rate > best!.1 {
                best = (module, rate)
            }
        }

        return best
    }

    // Get weakest module
    var weakestModule: (name: String, hitRate: Double)? {
        var worst: (String, Double)? = nil

        for (module, cal) in calibration.modules {
            let totalAttempts = cal.brackets.values.reduce(0.0) { $0 + $1.attempts }
            let totalCorrect = cal.brackets.values.reduce(0.0) { $0 + $1.correct }

            guard totalAttempts >= 5 else { continue }

            let rate = totalCorrect / totalAttempts
            if worst == nil || rate < worst!.1 {
                worst = (module, rate)
            }
        }

        return worst
    }
}

// MARK: - Test Helper Methods (DEBUG only)
#if DEBUG
extension AlkindusCalibrationEngine {
    /// Test helper: Expose scoreToBracket for testing (calls actual private implementation)
    func testScoreToBracket(_ score: Double) async -> String {
        return scoreToBracket(score)
    }

    /// Test helper: Expose scoreToBracketsWeighted for testing (calls actual private implementation)
    func testScoreToBracketsWeighted(_ score: Double) async -> [(bracket: String, weight: Double)] {
        return scoreToBracketsWeighted(score)
    }

    /// Test helper: Get pending observation count
    func getPendingCount() async -> Int {
        return await memoryStore.loadPendingObservations().count
    }
}
#endif
