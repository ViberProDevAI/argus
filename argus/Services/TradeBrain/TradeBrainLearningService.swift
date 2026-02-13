import Foundation

actor TradeBrainLearningService {
    static let shared = TradeBrainLearningService()
    
    private let eventMemory = EventMemoryService.shared
    private let regimeMemory = RegimeMemoryService.shared
    private let confidenceCalibration = ConfidenceCalibrationService.shared
    private let horizonEngine = HorizonEngine.shared
    private let selfQuestionEngine = SelfQuestionEngine.shared
    private let ragEngine = AlkindusRAGEngine.shared
    
    private var learningQueue: [LearningTask] = []
    private var isProcessing = false
    
    private init() {}
    
    struct LearningTask: Identifiable {
        let id: UUID
        let symbol: String
        let decision: TradeBrainDecision
        let createdAt: Date
        var evaluatedAt: [Int: Date] = [:]
        var outcomes: [Int: Outcome] = [:]
        var isComplete: Bool = false
        
        struct Outcome {
            let horizon: Int
            let wasCorrect: Bool
            let pnlPercent: Double
            let evaluatedAt: Date
        }
    }
    
    struct TradeBrainDecision: Codable {
        let symbol: String
        let timestamp: Date
        let multiHorizon: MultiHorizonDecision
        let contradictionAnalysis: ContradictionAnalysis?
        let macroContext: MacroContext
        let finalAction: String
        let finalConfidence: Double
    }
    
    func observeDecision(
        symbol: String,
        multiHorizon: MultiHorizonDecision,
        contradictionAnalysis: ContradictionAnalysis?,
        macroContext: MacroContext,
        finalAction: String,
        finalConfidence: Double
    ) async {
        let decision = TradeBrainDecision(
            symbol: symbol,
            timestamp: Date(),
            multiHorizon: multiHorizon,
            contradictionAnalysis: contradictionAnalysis,
            macroContext: macroContext,
            finalAction: finalAction,
            finalConfidence: finalConfidence
        )
        
        let task = LearningTask(
            id: UUID(),
            symbol: symbol,
            decision: decision,
            createdAt: Date()
        )
        
        learningQueue.append(task)
        print("TradeBrainLearning: \(symbol) karari izlenmeye alindi")
    }
    
    func processMaturedObservations(currentPrices: [String: Double]) async -> Int {
        var processedCount = 0
        let horizons = [1, 3, 7, 14, 30]
        
        for i in learningQueue.indices {
            var task = learningQueue[i]
            
            for horizon in horizons {
                if task.evaluatedAt[horizon] != nil { continue }
                
                let maturityDate = task.createdAt.addingTimeInterval(Double(horizon * 24 * 3600))
                guard Date() >= maturityDate else { continue }
                
                guard let currentPrice = currentPrices[task.symbol] else { continue }
                
                let outcome = evaluateOutcome(
                    decision: task.decision,
                    currentPrice: currentPrice,
                    horizon: horizon
                )
                
                task.outcomes[horizon] = LearningTask.Outcome(
                    horizon: horizon,
                    wasCorrect: outcome.wasCorrect,
                    pnlPercent: outcome.pnlPercent,
                    evaluatedAt: Date()
                )
                task.evaluatedAt[horizon] = Date()
                
                await recordLearning(task: task, horizon: horizon, outcome: outcome)
                
                processedCount += 1
                print("TradeBrainLearning: \(task.symbol) T+\(horizon) gun degerlendirildi - \(outcome.wasCorrect ? "BASARILI" : "BASARISIZ")")
            }
            
            if task.outcomes.count >= horizons.count {
                task.isComplete = true
            }
            
            learningQueue[i] = task
        }
        
        learningQueue.removeAll { $0.isComplete }
        
        return processedCount
    }
    
    private func evaluateOutcome(
        decision: TradeBrainDecision,
        currentPrice: Double,
        horizon: Int
    ) -> (wasCorrect: Bool, pnlPercent: Double) {
        let entryPrice = decision.multiHorizon.primaryRecommendation.indicators["entry_price"]
            .flatMap { Double($0) } ?? 0
        
        guard entryPrice > 0 else {
            return (wasCorrect: false, pnlPercent: 0)
        }
        
        let pnlPercent = (currentPrice - entryPrice) / entryPrice * 100
        let wasCorrect: Bool
        
        switch decision.finalAction {
        case "BUY", "ACCUMULATE", "AGGRESSIVE_BUY":
            wasCorrect = pnlPercent > 0
        case "SELL", "TRIM", "LIQUIDATE":
            wasCorrect = pnlPercent < 0
        default:
            wasCorrect = abs(pnlPercent) < 2
        }
        
        return (wasCorrect, pnlPercent)
    }
    
    private func recordLearning(
        task: LearningTask,
        horizon: Int,
        outcome: (wasCorrect: Bool, pnlPercent: Double)
    ) async {
        let decision = task.decision
        
        await confidenceCalibration.recordOutcome(
            confidence: decision.finalConfidence,
            wasCorrect: outcome.wasCorrect,
            pnlPercent: outcome.pnlPercent
        )
        
        await horizonEngine.recordOutcome(
            symbol: task.symbol,
            timeframe: decision.multiHorizon.primaryRecommendation.timeframe,
            action: ArgusAction(rawValue: decision.finalAction) ?? .neutral,
            confidence: decision.finalConfidence,
            outcome: outcome.wasCorrect ? "win" : "loss",
            pnlPercent: outcome.pnlPercent
        )
        
        if let contradiction = decision.contradictionAnalysis,
           let firstContradiction = contradiction.contradictions.first {
            await selfQuestionEngine.recordContradiction(
                symbol: task.symbol,
                module1: firstContradiction.module1,
                stance1: firstContradiction.stance1,
                module2: firstContradiction.module2,
                stance2: firstContradiction.stance2,
                finalDecision: decision.finalAction,
                outcome: outcome.wasCorrect ? "win" : "loss",
                pnlPercent: outcome.pnlPercent
            )
        }
        
        await regimeMemory.recordRegimeOutcome(
            symbol: task.symbol,
            action: decision.finalAction,
            pnlPercent: outcome.pnlPercent,
            holdingDays: horizon
        )
        
        print("TradeBrainLearning: \(task.symbol) ogrenme kaydedildi")
    }
    
    func getLearningStats() async -> LearningStats {
        let pendingCount = learningQueue.count
        let completedCount = learningQueue.filter { $0.isComplete }.count
        
        var horizonStats: [Int: HorizonStat] = [:]
        for horizon in [1, 3, 7, 14, 30] {
            let evaluated = learningQueue.filter { $0.evaluatedAt[horizon] != nil }
            let correct = evaluated.filter { task in
                task.outcomes[horizon]?.wasCorrect == true
            }.count
            
            horizonStats[horizon] = HorizonStat(
                horizon: horizon,
                evaluatedCount: evaluated.count,
                correctCount: correct,
                winRate: evaluated.count > 0 ? Double(correct) / Double(evaluated.count) : 0
            )
        }
        
        return LearningStats(
            pendingCount: pendingCount,
            completedCount: completedCount,
            horizonStats: horizonStats
        )
    }
    
    func triggerDailyLearning() async {
        let currentPrices = await getCurrentPrices()
        let processed = await processMaturedObservations(currentPrices: currentPrices)
        print("TradeBrainLearning: Gunluk ogrenme tamamlandi - \(processed) karar degerlendirildi")
    }
    
    private func getCurrentPrices() async -> [String: Double] {
        return [:]
    }
    
    private func vixToBucket(_ vix: Double) -> String {
        switch vix {
        case ..<15: return "low"
        case 15..<20: return "normal"
        case 20..<30: return "elevated"
        default: return "high"
        }
    }
}

struct LearningStats: Codable {
    let pendingCount: Int
    let completedCount: Int
    let horizonStats: [Int: HorizonStat]
    
    var summary: String {
        "\(pendingCount) bekleyen, \(completedCount) tamamlandi"
    }
}

struct HorizonStat: Codable {
    let horizon: Int
    let evaluatedCount: Int
    let correctCount: Int
    let winRate: Double
    
    var display: String {
        "T+\(horizon): %\(String(format: "%.0f", winRate * 100)) (\(evaluatedCount))"
    }
}
