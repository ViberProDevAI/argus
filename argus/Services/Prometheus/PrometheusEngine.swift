import Foundation

// MARK: - Prometheus: Price Forecasting Engine
// Uses Holt-Winters Exponential Smoothing for 5-day price predictions
// Academic Reference: ESWA 2022 Literature Review recommends time-series models

actor PrometheusEngine {
    static let shared = PrometheusEngine()
    
    // Cache: Symbol -> Forecast
    private var forecastCache: [String: (forecast: PrometheusForecast, timestamp: Date)] = [:]
    private let cacheExpiry: TimeInterval = 3600 // 1 hour
    
    // MARK: - Public API
    
    /// Generates a 5-day price forecast for the given symbol
    /// - Parameters:
    ///   - symbol: Stock symbol
    ///   - historicalPrices: Array of closing prices (newest first, minimum 30 days)
    /// - Returns: PrometheusForecast with predictions
    func forecast(symbol: String, historicalPrices: [Double]) async -> PrometheusForecast {
        // Check cache
        if let cached = forecastCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
            return cached.forecast
        }
        
        // Need at least 30 data points for meaningful forecast
        guard historicalPrices.count >= 30 else {
            return PrometheusForecast.insufficient(symbol: symbol)
        }
        
        // Reverse to oldest-first for time series analysis
        let prices = Array(historicalPrices.reversed())
        let horizon = horizonDays(for: prices.count)
        let tuning = tuneParameters(prices: prices)
        let forecast = holtWintersForecast(
            prices: prices,
            daysAhead: horizon,
            alpha: tuning.alpha,
            beta: tuning.beta
        )
        
        let intervals = buildPredictionIntervals(
            forecast: forecast,
            residualAbsErrors: tuning.absErrors,
            lastPrice: prices.last ?? 0
        )
        
        // Calculate confidence from model diagnostics + volatility.
        let confidence = calculateConfidence(
            prices: prices,
            mape: tuning.mape,
            directionalAccuracy: tuning.directionalAccuracy,
            intervalWidthPct: intervals.intervalWidthPct
        )
        
        // Determine trend direction
        let trend = determineTrend(prices: prices, forecast: forecast)
        
        let currentPrice = historicalPrices.first ?? 0
        let predictedPrice = forecast.last ?? currentPrice
        let changePercent = currentPrice > 0 ? ((predictedPrice - currentPrice) / currentPrice) * 100 : 0
        let recommendation = recommendAction(
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            lowerBound: intervals.lower.last ?? predictedPrice,
            upperBound: intervals.upper.last ?? predictedPrice,
            confidence: confidence
        )
        let rationale = buildRationale(
            horizon: horizon,
            dataPoints: prices.count,
            alpha: tuning.alpha,
            beta: tuning.beta,
            mape: tuning.mape,
            directionalAccuracy: tuning.directionalAccuracy,
            intervalWidthPct: intervals.intervalWidthPct,
            recommendation: recommendation
        )
        
        let result = PrometheusForecast(
            symbol: symbol,
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            predictions: forecast,
            lowerBand: intervals.lower,
            upperBand: intervals.upper,
            changePercent: changePercent,
            confidence: confidence,
            trend: trend,
            horizonDays: horizon,
            recommendation: recommendation,
            rationale: rationale,
            dataPointsUsed: prices.count,
            modelVersion: "Holt-Linear-V2",
            validationMAPE: tuning.mape,
            directionalAccuracy: tuning.directionalAccuracy,
            generatedAt: Date()
        )
        
        // Cache result
        forecastCache[symbol] = (result, Date())
        
        // Forward Test Logging (Black Box)
        ArgusLedger.shared.logForecast(
            symbol: symbol,
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            predictions: forecast,
            confidence: confidence
        )
        
        return result
    }
    
    // MARK: - Holt-Winters Algorithm
    
    /// Double Exponential Smoothing (Holt-Winters without seasonality).
    /// Data-aware usage: parameters are tuned via rolling one-step validation.
    private func holtWintersForecast(prices: [Double], daysAhead: Int, alpha: Double, beta: Double) -> [Double] {
        guard prices.count >= 2 else { return [] }

        // Initialize
        var level = prices[0]
        var trend = prices[1] - prices[0]
        
        // Smooth through historical data
        for i in 1..<prices.count {
            let previousLevel = level
            
            // Update level
            level = alpha * prices[i] + (1 - alpha) * (previousLevel + trend)
            
            // Update trend
            trend = beta * (level - previousLevel) + (1 - beta) * trend
        }
        
        // Generate forecasts
        var forecasts: [Double] = []
        for day in 1...daysAhead {
            let prediction = level + (Double(day) * trend)
            // Ensure non-negative price
            forecasts.append(max(0, prediction))
        }
        
        return forecasts
    }
    
    // MARK: - Confidence Calculation
    
    /// Scientific confidence from diagnostics + volatility:
    /// lower MAPE, higher directional accuracy and tighter intervals produce higher confidence.
    private func calculateConfidence(
        prices: [Double],
        mape: Double,
        directionalAccuracy: Double,
        intervalWidthPct: Double
    ) -> Double {
        guard prices.count >= 10 else { return 50.0 }
        let recentPrices = Array(prices.suffix(10))
        let mean = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let variance = recentPrices.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recentPrices.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        let mapePenalty = min(45.0, mape * 2.2)
        let widthPenalty = min(25.0, intervalWidthPct * 1.6)
        let volPenalty = min(20.0, cv * 220.0)
        let directionalBoost = directionalAccuracy * 18.0

        let raw = 85.0 - mapePenalty - widthPenalty - volPenalty + directionalBoost
        let confidence = max(35.0, min(95.0, raw))

        return confidence
    }
    
    // MARK: - Trend Detection
    
    private func determineTrend(prices: [Double], forecast: [Double]) -> PrometheusTrend {
        guard let lastPrice = prices.last, let predictedPrice = forecast.last else {
            return .neutral
        }
        
        let changePercent = ((predictedPrice - lastPrice) / lastPrice) * 100
        
        switch changePercent {
        case 5...: return .strongBullish
        case 2..<5: return .bullish
        case -2..<2: return .neutral
        case -5..<(-2): return .bearish
        default: return .strongBearish
        }
    }

    // MARK: - Scientific Tuning

    private func horizonDays(for barCount: Int) -> Int {
        switch barCount {
        case 500...: return 5
        case 200...: return 4
        case 120...: return 3
        case 60...: return 2
        default: return 1
        }
    }

    private func tuneParameters(prices: [Double]) -> PrometheusTuningResult {
        let alphaCandidates: [Double] = [0.2, 0.3, 0.4, 0.6]
        let betaCandidates: [Double] = [0.05, 0.1, 0.2, 0.3]
        let validationWindow = min(60, max(20, prices.count / 5))

        var best = PrometheusTuningResult(
            alpha: 0.3,
            beta: 0.1,
            mape: 100.0,
            directionalAccuracy: 0.0,
            absErrors: []
        )

        for alpha in alphaCandidates {
            for beta in betaCandidates {
                let diagnostics = rollingOneStepDiagnostics(
                    prices: prices,
                    validationWindow: validationWindow,
                    alpha: alpha,
                    beta: beta
                )
                guard diagnostics.count > 0 else { continue }

                let mape = diagnostics.map(\.ape).reduce(0, +) / Double(diagnostics.count)
                let directionHits = diagnostics.filter { $0.directionCorrect }.count
                let directionAccuracy = Double(directionHits) / Double(diagnostics.count)

                if mape < best.mape {
                    best = PrometheusTuningResult(
                        alpha: alpha,
                        beta: beta,
                        mape: mape,
                        directionalAccuracy: directionAccuracy,
                        absErrors: diagnostics.map(\.absError)
                    )
                }
            }
        }

        return best
    }

    private func rollingOneStepDiagnostics(
        prices: [Double],
        validationWindow: Int,
        alpha: Double,
        beta: Double
    ) -> [PrometheusPointDiagnostic] {
        guard prices.count >= (validationWindow + 10) else { return [] }

        var out: [PrometheusPointDiagnostic] = []
        let start = prices.count - validationWindow

        for i in start..<prices.count {
            guard i >= 5 else { continue }
            let train = Array(prices[0..<i])
            let actual = prices[i]
            let prediction = holtWintersForecast(prices: train, daysAhead: 1, alpha: alpha, beta: beta).first ?? actual

            let absError = abs(actual - prediction)
            let ape = actual > 0 ? absError / actual * 100.0 : 100.0
            let previous = train.last ?? actual
            let predictedChange = prediction - previous
            let actualChange = actual - previous
            let directionCorrect = (predictedChange == 0 && actualChange == 0) || (predictedChange * actualChange > 0)

            out.append(
                PrometheusPointDiagnostic(
                    absError: absError,
                    ape: ape,
                    directionCorrect: directionCorrect
                )
            )
        }
        return out
    }

    private func buildPredictionIntervals(
        forecast: [Double],
        residualAbsErrors: [Double],
        lastPrice: Double
    ) -> PrometheusIntervals {
        guard !forecast.isEmpty else {
            return PrometheusIntervals(lower: [], upper: [], intervalWidthPct: 0)
        }

        let fallbackError = max(0.01, lastPrice * 0.02)
        let q90 = quantile(residualAbsErrors, q: 0.90) ?? fallbackError
        let baseError = max(q90, fallbackError)

        var lower: [Double] = []
        var upper: [Double] = []

        for (idx, pred) in forecast.enumerated() {
            let step = Double(idx + 1)
            let scaled = baseError * sqrt(step)
            lower.append(max(0.0, pred - scaled))
            upper.append(pred + scaled)
        }

        let meanPred = max(0.01, forecast.reduce(0, +) / Double(forecast.count))
        let width = zip(lower, upper).map { $1 - $0 }.reduce(0, +) / Double(forecast.count)
        let widthPct = width / meanPred * 100.0

        return PrometheusIntervals(lower: lower, upper: upper, intervalWidthPct: widthPct)
    }

    private func quantile(_ values: [Double], q: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * max(0, min(1, q)))
        return sorted[index]
    }

    private func recommendAction(
        currentPrice: Double,
        predictedPrice: Double,
        lowerBound: Double,
        upperBound: Double,
        confidence: Double
    ) -> PrometheusRecommendation {
        guard currentPrice > 0 else { return .hold }
        let expectedReturn = (predictedPrice - currentPrice) / currentPrice * 100.0
        let conservativeReturn = (lowerBound - currentPrice) / currentPrice * 100.0
        let optimisticReturn = (upperBound - currentPrice) / currentPrice * 100.0

        if confidence >= 60, conservativeReturn >= 1.0, expectedReturn > 1.5 {
            return .buy
        }
        if confidence >= 60, optimisticReturn <= -1.0, expectedReturn < -1.5 {
            return .sell
        }
        return .hold
    }

    private func buildRationale(
        horizon: Int,
        dataPoints: Int,
        alpha: Double,
        beta: Double,
        mape: Double,
        directionalAccuracy: Double,
        intervalWidthPct: Double,
        recommendation: PrometheusRecommendation
    ) -> [String] {
        let recText: String
        switch recommendation {
        case .buy: recText = "Beklenen getiri ve alt bant pozitif olduğu için AL önerisi üretildi."
        case .sell: recText = "Tahmin bandı ağırlıklı negatif olduğu için SAT önerisi üretildi."
        case .hold: recText = "Belirsizlik / getiri dengesi net olmadığı için BEKLE önerisi üretildi."
        }

        return [
            "Veri derinliği: \(dataPoints) bar, ufuk: \(horizon) gün.",
            String(format: "Kalibrasyon parametreleri: alpha=%.2f, beta=%.2f.", alpha, beta),
            String(format: "Walk-forward MAPE: %.2f%%, yön isabeti: %.1f%%.", mape, directionalAccuracy * 100),
            String(format: "Tahmin aralığı genişliği: %.2f%%.", intervalWidthPct),
            recText
        ]
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        forecastCache.removeAll()
    }
    
    func clearCache(for symbol: String) {
        forecastCache.removeValue(forKey: symbol)
    }
}

// MARK: - Models

struct PrometheusForecast: Equatable {
    let symbol: String
    let currentPrice: Double
    let predictedPrice: Double
    let predictions: [Double]  // Day 1, 2, 3, 4, 5
    let lowerBand: [Double]
    let upperBand: [Double]
    let changePercent: Double
    let confidence: Double     // 0-100
    let trend: PrometheusTrend
    let horizonDays: Int
    let recommendation: PrometheusRecommendation
    let rationale: [String]
    let dataPointsUsed: Int
    let modelVersion: String
    let validationMAPE: Double
    let directionalAccuracy: Double
    let generatedAt: Date
    
    var isValid: Bool {
        !predictions.isEmpty
    }
    
    var formattedChange: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", changePercent))%"
    }
    
    var confidenceLevel: String {
        switch confidence {
        case 80...100: return "Yüksek"
        case 60..<80: return "Orta"
        default: return "Düşük"
        }
    }
    
    /// Creates an "insufficient data" forecast
    static func insufficient(symbol: String) -> PrometheusForecast {
        PrometheusForecast(
            symbol: symbol,
            currentPrice: 0,
            predictedPrice: 0,
            predictions: [],
            lowerBand: [],
            upperBand: [],
            changePercent: 0,
            confidence: 0,
            trend: .neutral,
            horizonDays: 0,
            recommendation: .hold,
            rationale: [],
            dataPointsUsed: 0,
            modelVersion: "Holt-Linear-V2",
            validationMAPE: 0,
            directionalAccuracy: 0,
            generatedAt: Date()
        )
    }
}

enum PrometheusRecommendation: String {
    case buy = "AL"
    case hold = "BEKLE"
    case sell = "SAT"
}

private struct PrometheusPointDiagnostic {
    let absError: Double
    let ape: Double
    let directionCorrect: Bool
}

private struct PrometheusTuningResult {
    let alpha: Double
    let beta: Double
    let mape: Double
    let directionalAccuracy: Double
    let absErrors: [Double]
}

private struct PrometheusIntervals {
    let lower: [Double]
    let upper: [Double]
    let intervalWidthPct: Double
}

enum PrometheusTrend: String {
    case strongBullish = "Güçlü Yükseliş"
    case bullish = "Yükseliş"
    case neutral = "Yatay"
    case bearish = "Düşüş"
    case strongBearish = "Güçlü Düşüş"
    
    var icon: String {
        switch self {
        case .strongBullish: return "arrow.up.forward.circle.fill"
        case .bullish: return "arrow.up.right"
        case .neutral: return "arrow.left.arrow.right"
        case .bearish: return "arrow.down.right"
        case .strongBearish: return "arrow.down.forward.circle.fill"
        }
    }
    
    var colorName: String {
        switch self {
        case .strongBullish, .bullish: return "green"
        case .neutral: return "gray"
        case .bearish, .strongBearish: return "red"
        }
    }
}
