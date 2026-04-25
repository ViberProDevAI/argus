import Foundation

// MARK: - Trade Brain Conductor
/// Farklı zaman dilimlerinden gelen sinyalleri yöneten akıllı beyin.
/// "Orkestra Şefi" - Scalp, Swing, Position stratejilerini koordine eder.

@MainActor
final class TradeBrainConductor {
    static let shared = TradeBrainConductor()
    
    private init() {}
    
    // MARK: - Strategy Configuration
    
    struct StrategyConfig: Codable {
        var scalp: BucketConfig
        var swing: BucketConfig
        var position: BucketConfig
        
        static var standard: StrategyConfig {
            StrategyConfig(
                scalp: BucketConfig(
                    enabled: true,
                    allocationPercent: 0.10,
                    maxPositionPercent: 0.02,
                    stopLossPercent: 0.01,
                    takeProfitPercent: 0.02,
                    maxHoldingHours: 4
                ),
                swing: BucketConfig(
                    enabled: true,
                    allocationPercent: 0.30,
                    maxPositionPercent: 0.05,
                    stopLossPercent: 0.03,
                    takeProfitPercent: 0.08,
                    maxHoldingHours: 168
                ),
                position: BucketConfig(
                    enabled: true,
                    allocationPercent: 0.60,
                    maxPositionPercent: 0.10,
                    stopLossPercent: 0.07,
                    takeProfitPercent: 0.20,
                    maxHoldingHours: 720
                )
            )
        }
    }
    
    struct BucketConfig: Codable {
        var enabled: Bool
        var allocationPercent: Double
        var maxPositionPercent: Double
        var stopLossPercent: Double
        var takeProfitPercent: Double
        var maxHoldingHours: Int
    }
    
    // MARK: - Decision Models
    
    struct ConductorDecision {
        let symbol: String
        let timestamp: Date
        let bucketDecisions: [BucketDecision]
        let overallRecommendation: OverallRecommendation
        let alkindusAdvice: AlkindusAdvice?
    }
    
    struct BucketDecision {
        let bucket: OrionMultiFrameEngine.StrategyBucket
        let action: Action
        let confidence: Double
        let reasoning: String
        let suggestedSize: Double
        let stopLoss: Double?
        let takeProfit: Double?
        
        enum Action: String {
            case buy = "AL"
            case sell = "SAT"
            case hold = "TUT"
            case close = "KAPAT"
            case avoid = "KAÇIN"
        }
    }
    
    struct OverallRecommendation {
        let action: String
        let reasoning: String
        let confidenceLevel: ConfidenceLevel
        let priorityBucket: OrionMultiFrameEngine.StrategyBucket?
        
        enum ConfidenceLevel: String {
            case high = "YÜKSEK"
            case medium = "ORTA"
            case low = "DÜŞÜK"
            case conflict = "ÇATIŞMA"
        }
    }
    
    struct AlkindusAdvice {
        let indicatorAdvice: String?
        let symbolAdvice: String?
        let temporalAdvice: String?
        let historicalSuccess: Double?
    }
    
    // MARK: - API
    
    func makeDecision(
        symbol: String,
        multiFrameReport: OrionMultiFrameEngine.MultiFrameReport,
        config: StrategyConfig = .standard
    ) async -> ConductorDecision {
        var bucketDecisions: [BucketDecision] = []
        
        let alkindusAdvice = await getAlkindusAdvice(symbol: symbol)
        
        if config.scalp.enabled {
            let decision = processBucket(
                bucket: .scalp,
                config: config.scalp,
                report: multiFrameReport,
                alkindusAdvice: alkindusAdvice
            )
            bucketDecisions.append(decision)
        }
        
        if config.swing.enabled {
            let decision = processBucket(
                bucket: .swing,
                config: config.swing,
                report: multiFrameReport,
                alkindusAdvice: alkindusAdvice
            )
            bucketDecisions.append(decision)
        }
        
        if config.position.enabled {
            let decision = processBucket(
                bucket: .position,
                config: config.position,
                report: multiFrameReport,
                alkindusAdvice: alkindusAdvice
            )
            bucketDecisions.append(decision)
        }
        
        let overall = generateOverallRecommendation(
            bucketDecisions: bucketDecisions,
            consensus: multiFrameReport.consensus
        )
        
        return ConductorDecision(
            symbol: symbol,
            timestamp: Date(),
            bucketDecisions: bucketDecisions,
            overallRecommendation: overall,
            alkindusAdvice: alkindusAdvice
        )
    }
    
    // MARK: - Private Helpers
    
    private func processBucket(
        bucket: OrionMultiFrameEngine.StrategyBucket,
        config: BucketConfig,
        report: OrionMultiFrameEngine.MultiFrameReport,
        alkindusAdvice: AlkindusAdvice?
    ) -> BucketDecision {
        guard let bucketRec = report.bucketRecommendations[bucket] else {
            return BucketDecision(
                bucket: bucket,
                action: .hold,
                confidence: 0,
                reasoning: "Bu strateji için veri yok",
                suggestedSize: 0,
                stopLoss: nil,
                takeProfit: nil
            )
        }
        
        var confidenceAdjustment: Double = 0
        var additionalReasoning = ""
        
        if let historical = alkindusAdvice?.historicalSuccess {
            if historical < 0.4 {
                confidenceAdjustment = -0.2
                additionalReasoning = " ⚠️ Alkindus: Bu hissede tarihsel başarı düşük (\(Int(historical * 100))%)"
            } else if historical > 0.7 {
                confidenceAdjustment = 0.1
                additionalReasoning = " ✅ Alkindus: Tarihsel başarı yüksek (\(Int(historical * 100))%)"
            }
        }
        
        let action: BucketDecision.Action
        let adjustedConfidence = max(0, min(1, bucketRec.confidence + confidenceAdjustment))
        
        switch bucketRec.signal {
        case .strongBuy where adjustedConfidence > 0.6:
            action = .buy
        case .buy where adjustedConfidence > 0.5:
            action = .buy
        case .strongSell where adjustedConfidence > 0.6:
            action = .sell
        case .sell where adjustedConfidence > 0.5:
            action = .sell
        case .strongSell, .sell where adjustedConfidence <= 0.5:
            action = .avoid
        default:
            action = .hold
        }
        
        let suggestedSize = action == .buy ? min(1.0, adjustedConfidence * 1.2) : 0
        
        let relevantAnalysis = report.analyses.first { $0.timeframe.strategyBucket == bucket }
        let stopLoss = relevantAnalysis?.keyLevels.support
        let takeProfit = relevantAnalysis?.keyLevels.resistance
        
        return BucketDecision(
            bucket: bucket,
            action: action,
            confidence: adjustedConfidence,
            reasoning: bucketRec.reasoning + additionalReasoning,
            suggestedSize: suggestedSize,
            stopLoss: stopLoss,
            takeProfit: takeProfit
        )
    }
    
    private func generateOverallRecommendation(
        bucketDecisions: [BucketDecision],
        consensus: OrionMultiFrameEngine.ConsensusResult
    ) -> OverallRecommendation {
        let buyCount = bucketDecisions.filter { $0.action == .buy }.count
        let sellCount = bucketDecisions.filter { $0.action == .sell || $0.action == .close }.count
        let avoidCount = bucketDecisions.filter { $0.action == .avoid }.count
        
        let action: String
        let confidenceLevel: OverallRecommendation.ConfidenceLevel
        let reasoning: String
        var priorityBucket: OrionMultiFrameEngine.StrategyBucket? = nil
        
        if buyCount >= 2 && avoidCount == 0 {
            action = "AL"
            confidenceLevel = consensus.alignment == .fullAlignment ? .high : .medium
            reasoning = "\(buyCount) strateji alım sinyali veriyor"
            priorityBucket = bucketDecisions.filter { $0.action == .buy }.max { $0.confidence < $1.confidence }?.bucket
        } else if sellCount >= 2 {
            action = "SAT"
            confidenceLevel = consensus.alignment == .fullAlignment ? .high : .medium
            reasoning = "\(sellCount) strateji satış sinyali veriyor"
        } else if avoidCount >= 2 {
            action = "KAÇIN"
            confidenceLevel = .low
            reasoning = "Çoğu strateji riskli buluyor"
        } else if buyCount > 0 && sellCount > 0 {
            action = "DİKKATLİ OL"
            confidenceLevel = .conflict
            reasoning = "Stratejiler arasında çatışma var"
        } else {
            action = "BEKLE"
            confidenceLevel = .low
            reasoning = "Net sinyal yok"
        }
        
        return OverallRecommendation(
            action: action,
            reasoning: reasoning,
            confidenceLevel: confidenceLevel,
            priorityBucket: priorityBucket
        )
    }
    
    private func getAlkindusAdvice(symbol: String) async -> AlkindusAdvice? {
        let symbolInsight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: symbol)
        let temporalAdvice = await AlkindusTemporalAnalyzer.shared.getCurrentTimeAdvice()
        
        let bestIndicators = AlkindusBacktestLearner.shared.getBestIndicators(for: symbol, timeframe: "1d")
        let indicatorAdvice = bestIndicators.isEmpty ? nil : "En iyi: \(bestIndicators.first?.indicator.capitalized ?? "") (\(Int((bestIndicators.first?.hitRate ?? 0) * 100))%)"
        
        let historicalSuccess = symbolInsight?.bestHitRate
        
        return AlkindusAdvice(
            indicatorAdvice: indicatorAdvice,
            symbolAdvice: symbolInsight?.message,
            temporalAdvice: temporalAdvice,
            historicalSuccess: historicalSuccess
        )
    }
}

// MARK: - Quick Access Extension

extension TradeBrainConductor {
    func quickDecision(symbol: String, candles: [String: [Candle]]) async -> String {
        let report = await OrionMultiFrameEngine.shared.analyzeMultiFrame(symbol: symbol) { sym, tf in
            candles[tf]
        }
        
        let decision = await makeDecision(symbol: symbol, multiFrameReport: report)
        
        return """
        📊 \(symbol) Trade Brain Kararı:
        ➡️ \(decision.overallRecommendation.action) (\(decision.overallRecommendation.confidenceLevel.rawValue))
        💡 \(decision.overallRecommendation.reasoning)
        """
    }
}
