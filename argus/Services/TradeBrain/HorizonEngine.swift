import Foundation

enum TimeFrame: String, Codable, CaseIterable {
    case scalp = "SCALP"
    case swing = "SWING"
    case position = "POSITION"
    
    var displayTitle: String {
        switch self {
        case .scalp: return "Scalp (5M-15M)"
        case .swing: return "Swing (1H-4H)"
        case .position: return "Position (1D-1W)"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .scalp: return "Scalp"
        case .swing: return "Swing"
        case .position: return "Position"
        }
    }
}

struct HorizonDecision: Codable {
    let timeframe: TimeFrame
    let action: ArgusAction
    let reasoning: String
    let confidence: Double
    let indicators: [String: String]
    let timestamp: Date
    
    var summary: String {
        "\(timeframe.shortTitle): \(action.rawValue) - \(reasoning)"
    }
}

struct MultiHorizonDecision: Codable {
    let symbol: String
    let scalp: HorizonDecision
    let swing: HorizonDecision
    let position: HorizonDecision
    let primaryRecommendation: HorizonDecision
    let overallConfidence: Double
    let calibratedConfidence: Double
    let timestamp: Date
    
    func getDecision(for timeframe: TimeFrame) -> HorizonDecision {
        switch timeframe {
        case .scalp: return scalp
        case .swing: return swing
        case .position: return position
        }
    }
}

struct MacroContext: Codable {
    let vix: Double
    let regime: String
    let trend: String
    let fearGreedIndex: Int
}

actor HorizonEngine {
    static let shared = HorizonEngine()
    
    private init() {}
    
    // MARK: - Generate Multi-Horizon Decision
    
    func generateMultiHorizonDecision(
        symbol: String,
        candles: [Candle],
        orionScore: OrionScoreResult?,
        atlasScore: Double?,
        macroContext: MacroContext
    ) async -> MultiHorizonDecision {
        
        let scalp = await generateScalpDecision(
            symbol: symbol,
            candles: candles,
            orionScore: orionScore
        )
        
        let swing = await generateSwingDecision(
            symbol: symbol,
            candles: candles,
            orionScore: orionScore,
            atlasScore: atlasScore
        )
        
        let position = await generatePositionDecision(
            symbol: symbol,
            candles: candles,
            atlasScore: atlasScore,
            macroContext: macroContext
        )
        
        let primary = selectPrimaryHorizon(
            scalp: scalp,
            swing: swing,
            position: position,
            macroContext: macroContext
        )
        
        let overallConfidence = calculateOverallConfidence(
            scalp: scalp,
            swing: swing,
            position: position
        )
        
        let calibrated = await calibrateConfidence(
            raw: overallConfidence,
            symbol: symbol
        )
        
        return MultiHorizonDecision(
            symbol: symbol,
            scalp: scalp,
            swing: swing,
            position: position,
            primaryRecommendation: primary,
            overallConfidence: overallConfidence,
            calibratedConfidence: calibrated,
            timestamp: Date()
        )
    }
    
    // MARK: - Individual Horizon Decisions
    
    private func generateScalpDecision(
        symbol: String,
        candles: [Candle],
        orionScore: OrionScoreResult?
    ) async -> HorizonDecision {
        guard candles.count >= 20 else {
            return HorizonDecision(
                timeframe: .scalp,
                action: .neutral,
                reasoning: "Yetersiz veri",
                confidence: 0,
                indicators: [:],
                timestamp: Date()
            )
        }
        
        let recentCandles = Array(candles.suffix(20))
        let rsi = orionScore?.components.rsi ?? 50
        let macdHistogram = orionScore?.components.macdHistogram ?? 0
        let trend = analyzeShortTrend(recentCandles)
        
        var action: ArgusAction = .neutral
        var reasoning = ""
        var confidence = 0.0
        var indicators: [String: String] = [:]
        
        indicators["RSI"] = String(format: "%.1f", rsi)
        indicators["Trend"] = trend
        indicators["MACD"] = String(format: "%.2f", macdHistogram)
        
        if rsi > 70 && trend == "down" {
            action = .trim
            reasoning = "RSI overbought, kisa vadeli satis"
            confidence = 0.65
        } else if rsi < 30 && trend == "up" {
            action = .accumulate
            reasoning = "RSI oversold, kisa vadeli alim"
            confidence = 0.65
        } else if trend == "up" && rsi < 60 {
            action = .accumulate
            reasoning = "Kisa vadeli yukselis trendi"
            confidence = 0.55
        } else if trend == "down" && rsi > 40 {
            action = .trim
            reasoning = "Kisa vadeli dusus trendi"
            confidence = 0.55
        } else {
            action = .neutral
            reasoning = "Belirsiz kisa vadeli sinyal"
            confidence = 0.4
        }
        
        return HorizonDecision(
            timeframe: .scalp,
            action: action,
            reasoning: reasoning,
            confidence: confidence,
            indicators: indicators,
            timestamp: Date()
        )
    }
    
    private func generateSwingDecision(
        symbol: String,
        candles: [Candle],
        orionScore: OrionScoreResult?,
        atlasScore: Double?
    ) async -> HorizonDecision {
        guard candles.count >= 50 else {
            return HorizonDecision(
                timeframe: .swing,
                action: .neutral,
                reasoning: "Yetersiz veri",
                confidence: 0,
                indicators: [:],
                timestamp: Date()
            )
        }
        
        let recentCandles = Array(candles.suffix(50))
        let trend = analyzeMediumTrend(recentCandles)
        let orion = orionScore?.score ?? 50
        let atlas = atlasScore ?? 50
        
        var action: ArgusAction = .neutral
        var reasoning = ""
        var confidence = 0.0
        var indicators: [String: String] = [:]
        
        indicators["Orion"] = String(format: "%.0f", orion)
        indicators["Atlas"] = String(format: "%.0f", atlas)
        indicators["Trend"] = trend
        
        let technicalScore = orion / 100.0
        let fundamentalScore = atlas / 100.0
        let combinedScore = technicalScore * 0.6 + fundamentalScore * 0.4
        
        if combinedScore > 0.7 && trend == "up" {
            action = .aggressiveBuy
            reasoning = "Guclu teknik ve temel sinyal"
            confidence = 0.75
        } else if combinedScore > 0.55 && trend != "down" {
            action = .accumulate
            reasoning = "Olumlu teknik gorunum"
            confidence = 0.6
        } else if combinedScore < 0.35 || trend == "down" {
            action = .trim
            reasoning = "Zayif teknik gorunum"
            confidence = 0.55
        } else if combinedScore < 0.45 {
            action = .neutral
            reasoning = "Kararsiz teknik sinyal"
            confidence = 0.45
        } else {
            action = .neutral
            reasoning = "Notr swing sinyal"
            confidence = 0.5
        }
        
        return HorizonDecision(
            timeframe: .swing,
            action: action,
            reasoning: reasoning,
            confidence: confidence,
            indicators: indicators,
            timestamp: Date()
        )
    }
    
    private func generatePositionDecision(
        symbol: String,
        candles: [Candle],
        atlasScore: Double?,
        macroContext: MacroContext
    ) async -> HorizonDecision {
        guard candles.count >= 100 else {
            return HorizonDecision(
                timeframe: .position,
                action: .neutral,
                reasoning: "Yetersiz veri",
                confidence: 0,
                indicators: [:],
                timestamp: Date()
            )
        }
        
        let trend = analyzeLongTrend(Array(candles.suffix(100)))
        let atlas = atlasScore ?? 50
        let regime = macroContext.regime
        let vix = macroContext.vix
        
        var action: ArgusAction = .neutral
        var reasoning = ""
        var confidence = 0.0
        var indicators: [String: String] = [:]
        
        indicators["Atlas"] = String(format: "%.0f", atlas)
        indicators["Rejim"] = regime
        indicators["VIX"] = String(format: "%.1f", vix)
        indicators["Trend"] = trend
        
        let fundamentalScore = atlas / 100.0
        let macroScore = regime == "Risk On" ? 0.7 : (regime == "Risk Off" ? 0.3 : 0.5)
        let combinedScore = fundamentalScore * 0.6 + macroScore * 0.4
        
        if combinedScore > 0.7 && regime == "Risk On" && vix < 20 {
            action = .aggressiveBuy
            reasoning = "Guclu temel ve makro ortam"
            confidence = 0.8
        } else if combinedScore > 0.55 && regime != "Risk Off" {
            action = .accumulate
            reasoning = "Olumlu uzun vadeli gorunum"
            confidence = 0.65
        } else if regime == "Risk Off" || vix > 30 {
            action = .neutral
            reasoning = "Risk ortami nedeniyle temkinli"
            confidence = 0.4
        } else if combinedScore < 0.4 {
            action = .trim
            reasoning = "Zayif uzun vadeli gorunum"
            confidence = 0.5
        } else {
            action = .neutral
            reasoning = "Notr uzun vadeli sinyal"
            confidence = 0.5
        }
        
        return HorizonDecision(
            timeframe: .position,
            action: action,
            reasoning: reasoning,
            confidence: confidence,
            indicators: indicators,
            timestamp: Date()
        )
    }
    
    // MARK: - Trend Analysis
    
    private func analyzeShortTrend(_ candles: [Candle]) -> String {
        guard candles.count >= 10 else { return "notr" }
        
        let recent = Array(candles.suffix(10))
        let firstPrice = recent.first?.close ?? 0
        let lastPrice = recent.last?.close ?? 0
        
        let change = (lastPrice - firstPrice) / max(firstPrice, 0.01)
        
        if change > 0.02 { return "up" }
        if change < -0.02 { return "down" }
        return "notr"
    }
    
    private func analyzeMediumTrend(_ candles: [Candle]) -> String {
        guard candles.count >= 30 else { return "notr" }
        
        let recent = Array(candles.suffix(30))
        let sma = recent.map { $0.close }.reduce(0, +) / Double(recent.count)
        let lastPrice = recent.last?.close ?? 0
        
        let diff = (lastPrice - sma) / max(sma, 0.01)
        
        if diff > 0.03 { return "up" }
        if diff < -0.03 { return "down" }
        return "notr"
    }
    
    private func analyzeLongTrend(_ candles: [Candle]) -> String {
        guard candles.count >= 50 else { return "notr" }
        
        let recent = Array(candles.suffix(50))
        let sma20 = Array(recent.suffix(20)).map { $0.close }.reduce(0, +) / 20
        let sma50 = recent.map { $0.close }.reduce(0, +) / 50
        
        if sma20 > sma50 * 1.02 { return "up" }
        if sma20 < sma50 * 0.98 { return "down" }
        return "notr"
    }
    
    // MARK: - Primary Selection
    
    private func selectPrimaryHorizon(
        scalp: HorizonDecision,
        swing: HorizonDecision,
        position: HorizonDecision,
        macroContext: MacroContext
    ) -> HorizonDecision {
        if macroContext.vix > 30 {
            return scalp.confidence > 0 ? scalp : swing
        }
        
        if macroContext.regime == "Risk On" {
            let decisions = [swing, position].sorted { $0.confidence > $1.confidence }
            return decisions.first ?? swing
        } else if macroContext.regime == "Risk Off" {
            return scalp.confidence > swing.confidence ? scalp : swing
        }
        
        let allDecisions = [scalp, swing, position]
        return allDecisions.sorted { $0.confidence > $1.confidence }.first ?? swing
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateOverallConfidence(
        scalp: HorizonDecision,
        swing: HorizonDecision,
        position: HorizonDecision
    ) -> Double {
        let weights: [TimeFrame: Double] = [
            .scalp: 0.2,
            .swing: 0.4,
            .position: 0.4
        ]
        
        let weightedConfidence = 
            scalp.confidence * weights[.scalp]! +
            swing.confidence * weights[.swing]! +
            position.confidence * weights[.position]!
        
        return weightedConfidence
    }
    
    private func calibrateConfidence(raw: Double, symbol: String) async -> Double {
        guard let calibrated = await AlkindusRAGEngine.shared.getCalibrationForBucket(
            confidenceToBucket(raw)
        ) else {
            return raw
        }
        
        return calibrated.calibrated
    }
    
    private func confidenceToBucket(_ confidence: Double) -> String {
        let lower = Int(confidence * 10) * 10
        let upper = lower + 10
        return "\(Double(lower) / 100)-\(Double(upper) / 100)"
    }
    
    // MARK: - Record Outcome
    
    func recordOutcome(
        symbol: String,
        timeframe: TimeFrame,
        action: ArgusAction,
        confidence: Double,
        outcome: String,
        pnlPercent: Double
    ) async {
        await AlkindusRAGEngine.shared.syncHorizonOutcome(
            symbol: symbol,
            timeframe: timeframe.rawValue,
            action: action.rawValue,
            confidence: confidence,
            outcome: outcome,
            pnlPercent: pnlPercent
        )
        
        print("HorizonEngine: \(symbol) \(timeframe.rawValue) sonuc kaydedildi")
    }
}
