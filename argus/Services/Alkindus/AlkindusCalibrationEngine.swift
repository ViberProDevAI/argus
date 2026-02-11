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
    func observe(
        symbol: String,
        action: String,
        moduleScores: [String: Double],
        regime: String,
        currentPrice: Double
    ) async {
        // Skip HOLD/ABSTAIN - only track actionable decisions
        guard action == "BUY" || action == "SELL" else { return }
        
        let observation = PendingObservation(
            symbol: symbol,
            decisionDate: Date(),
            action: action,
            moduleScores: moduleScores,
            regime: regime,
            priceAtDecision: currentPrice,
            horizons: [7, 15]
        )

        // Use atomic append to prevent race conditions between observe() calls
        await memoryStore.appendPendingObservation(observation)

        print("Alkindus: Yeni gozlem kaydedildi - \(symbol) \(action)")
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

        // Güncel fiyatları al (MainActor context'inde)
        let currentPrices: [String: Double] = await MainActor.run {
            let store = MarketDataStore.shared
            var prices: [String: Double] = [:]

            for observation in pending {
                if let quote = store.quotes[observation.symbol]?.value {
                    prices[observation.symbol] = quote.currentPrice
                }
            }

            return prices
        }

        guard !currentPrices.isEmpty else {
            print("Alkindus: Fiyat verisi henuz yok, 5 dakika sonra tekrar denenecek - maturation atlanıyor")
            // Note: Could optionally schedule a retry here in the future
            return
        }

        let evaluatedCount = await processMaturedDecisions(currentPrices: currentPrices)
        let remainingCount = await memoryStore.loadPendingObservations().count
        print("✅ Alkindus: Maturation check tamamlandı - \(evaluatedCount) değerlendirildi, \(remainingCount) pending")
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
                
                // Evaluate outcome
                let wasCorrect = evaluateOutcome(
                    action: observation.action,
                    entryPrice: observation.priceAtDecision,
                    currentPrice: currentPrice
                )
                
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
            }
            
            pending[i] = observation
        }
        
        // Remove fully evaluated observations
        pending = pending.filter { !$0.isFullyEvaluated }
        await memoryStore.savePendingObservations(pending)
        
        return evaluatedCount
    }
    
    // MARK: - Outcome Evaluation
    
    private func evaluateOutcome(action: String, entryPrice: Double, currentPrice: Double) -> Bool {
        let change = (currentPrice - entryPrice) / entryPrice
        
        switch action {
        case "BUY":
            // BUY is correct if price went up
            return change > 0
        case "SELL":
            // SELL is correct if price went down (or we avoided loss)
            return change < 0
        default:
            return false
        }
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
