import Foundation

// MARK: - Prometheus: Price Forecasting Engine
// Holt's Linear (Double Exponential Smoothing) — short-horizon trend projection.
// No seasonality; damping uygulanır (PR-2 sonrası `phi` ile sönümlenmiş trend).
// Tuning: rolling one-step walk-forward; composite skor (MAPE + yön isabeti).

actor PrometheusEngine {
    static let shared = PrometheusEngine()
    
    // Cache anahtarı yalnızca symbol değil, en güncel fiyatı da içerir.
    // Yeni bar geldiğinde latestPrice değişir → cache otomatik invalidate olur.
    // Süre tabanı: intra-day max 15 dk (haber/flash hareketler için yastık).
    private var forecastCache: [String: (forecast: PrometheusForecast, timestamp: Date, latestPrice: Double)] = [:]
    private let cacheExpiry: TimeInterval = 900 // 15 dk
    
    // MARK: - Public API
    
    /// Kısa vadeli fiyat tahmini üretir.
    /// - Parameters:
    ///   - symbol: Sembol kodu
    ///   - historicalPrices: Kapanış fiyatları, **oldest-first** (eskiden yeniye, kronolojik).
    ///     Codebase'in geri kalan konvansiyonu (`sorted { $0.date < $1.date }`) ile aynı yön.
    ///     Minimum 120 bar; altında insufficient forecast döner.
    /// - Returns: PrometheusForecast
    func forecast(symbol: String, historicalPrices: [Double]) async -> PrometheusForecast {
        let latestPrice = historicalPrices.last ?? 0

        // Cache hit: süresi dolmamış VE en güncel fiyat aynı.
        // Fiyat değiştiğinde (yeni bar / intra-day tick) cache otomatik invalidate olur.
        if let cached = forecastCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry,
           cached.latestPrice == latestPrice {
            return cached.forecast
        }

        // 120 bar = trend tahmini için savunulabilir minimum (yaklaşık 6 ay günlük veri).
        // Daha azı walk-forward MAPE'sini istatistiksel olarak gürültüden ayırt edemez.
        guard historicalPrices.count >= 120 else {
            return PrometheusForecast.insufficient(symbol: symbol)
        }

        let prices = historicalPrices
        let horizon = horizonDays(for: prices.count)
        let tuning = tuneParameters(prices: prices)
        let forecast = dampedHoltForecast(
            prices: prices,
            daysAhead: horizon,
            alpha: tuning.alpha,
            beta: tuning.beta,
            phi: tuning.phi
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
        
        // Volatilite ölçeği — recommendation eşikleri ve trend kategorileri için.
        let stdDevPct = recentVolatilityPct(prices: prices)

        let trend = determineTrend(
            prices: prices,
            forecast: forecast,
            stdDevPct: stdDevPct,
            horizon: horizon
        )

        // Oldest-first dizide en güncel fiyat son eleman.
        let currentPrice = latestPrice
        let predictedPrice = forecast.last ?? currentPrice
        let changePercent = currentPrice > 0 ? ((predictedPrice - currentPrice) / currentPrice) * 100 : 0
        let decision = recommendAction(
            symbol: symbol,
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            lowerBound: intervals.lower.last ?? predictedPrice,
            upperBound: intervals.upper.last ?? predictedPrice,
            confidence: confidence,
            stdDevPct: stdDevPct
        )
        let recommendation = decision.action
        let rationale = buildRationale(
            horizon: horizon,
            dataPoints: prices.count,
            alpha: tuning.alpha,
            beta: tuning.beta,
            phi: tuning.phi,
            mape: tuning.mape,
            directionalAccuracy: tuning.directionalAccuracy,
            intervalWidthPct: intervals.intervalWidthPct,
            recommendation: recommendation,
            holdReasons: decision.holdReasons
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
            modelVersion: "Damped-Holt-V3",
            validationMAPE: tuning.mape,
            directionalAccuracy: tuning.directionalAccuracy,
            generatedAt: Date()
        )
        
        // Cache result — latestPrice ile birlikte sakla.
        forecastCache[symbol] = (result, Date(), latestPrice)
        
        // Forward Test Logging (Black Box) — actor sınırının dışına çıkarıyoruz.
        // ArgusLedger MainActor-izoleli olabiliyor; detached task ile çağırmak
        // engine'in dönüş yolunu bloklamadan loglamayı kuyruğa alıyor.
        let logSymbol = symbol
        let logCurrent = currentPrice
        let logPredicted = predictedPrice
        let logForecast = forecast
        let logConfidence = confidence
        Task.detached {
            await ArgusLedger.shared.logForecast(
                symbol: logSymbol,
                currentPrice: logCurrent,
                predictedPrice: logPredicted,
                predictions: logForecast,
                confidence: logConfidence
            )
        }
        
        return result
    }
    
    // MARK: - Damped Holt's Linear Algorithm

    /// Damped Holt's Linear (Gardner & McKenzie 1985).
    /// `phi ∈ (0, 1]`: 1.0 = klasik Holt's Linear, < 1.0 = trend uzun ufukta sönümlenir.
    /// Standart pratik: kısa-vadeli hisse senedi tahminlerinde phi ≈ 0.85-0.98.
    /// Forecast formülü: ŷ_{t+h} = level + Σ_{i=1..h} phi^i * trend
    private func dampedHoltForecast(
        prices: [Double],
        daysAhead: Int,
        alpha: Double,
        beta: Double,
        phi: Double
    ) -> [Double] {
        guard prices.count >= 2 else { return [] }

        var level = prices[0]
        var trend = prices[1] - prices[0]

        for i in 1..<prices.count {
            let previousLevel = level
            level = alpha * prices[i] + (1 - alpha) * (previousLevel + phi * trend)
            trend = beta * (level - previousLevel) + (1 - beta) * phi * trend
        }

        var forecasts: [Double] = []
        var cumulative: Double = 0
        for h in 1...daysAhead {
            cumulative += pow(phi, Double(h))
            let prediction = level + cumulative * trend
            forecasts.append(max(0, prediction))
        }

        return forecasts
    }
    
    // MARK: - Confidence Calculation
    
    /// Walk-forward diagnostics + volatiliteden composite güven puanı.
    /// Tasarım kararları:
    ///   • Floor 0 — düşük model performansı kullanıcıdan saklanmaz.
    ///   • MAPE cap 70 — kötü/felaket model arasında geniş aralık bırakır.
    ///   • Directional boost yalnızca 0.5 üstü (coin-flip altı anti-skill kabul edilir).
    ///   • Yetersiz veri → 0 (orta-güven varsayımı yok).
    private func calculateConfidence(
        prices: [Double],
        mape: Double,
        directionalAccuracy: Double,
        intervalWidthPct: Double
    ) -> Double {
        guard prices.count >= 10 else { return 0.0 }
        let recentPrices = Array(prices.suffix(10))
        let mean = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let variance = recentPrices.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recentPrices.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0

        let mapePenalty = min(70.0, mape * 1.8)
        let widthPenalty = min(25.0, intervalWidthPct * 1.6)
        let volPenalty = min(20.0, cv * 220.0)
        // 0.5 yön isabeti = coin-flip → 0 boost. 1.0 = +18 boost.
        let directionalBoost = max(0.0, directionalAccuracy - 0.5) * 36.0

        let raw = 85.0 - mapePenalty - widthPenalty - volPenalty + directionalBoost
        let confidence = max(0.0, min(95.0, raw))

        return confidence
    }
    
    // MARK: - Trend Detection
    
    /// Trend kategorisi **volatilite + horizon** ölçeğine göre normalize edilir.
    /// Sabit eşik (`%5` gibi) volatil sembolde her tahmin için "güçlü" üretir;
    /// burada eşik = `stdDevPct * sqrt(horizon)`. 1σ üzeri yumuşak, 2σ üzeri güçlü.
    private func determineTrend(
        prices: [Double],
        forecast: [Double],
        stdDevPct: Double,
        horizon: Int
    ) -> PrometheusTrend {
        guard let lastPrice = prices.last, lastPrice > 0, let predictedPrice = forecast.last else {
            return .neutral
        }
        let changePercent = ((predictedPrice - lastPrice) / lastPrice) * 100

        // Volatilite-horizon ölçeği. Min 1.0 — düşük volatil sembolde aşırı hassas olmasın.
        let scale = max(1.0, stdDevPct * sqrt(Double(max(1, horizon))))
        let normalized = changePercent / scale

        switch normalized {
        case 2.0...: return .strongBullish
        case 0.8..<2.0: return .bullish
        case -0.8..<0.8: return .neutral
        case -2.0..<(-0.8): return .bearish
        default: return .strongBearish
        }
    }

    /// Son 20 barın günlük getirilerinin std sapması, % cinsinden.
    /// Recommendation eşikleri ve trend kategorileri için ölçek sağlar.
    private func recentVolatilityPct(prices: [Double]) -> Double {
        let window = min(20, prices.count - 1)
        guard window >= 2 else { return 0 }
        let tail = Array(prices.suffix(window + 1))
        var returns: [Double] = []
        for i in 1..<tail.count where tail[i - 1] > 0 {
            returns.append((tail[i] - tail[i - 1]) / tail[i - 1])
        }
        guard returns.count >= 2 else { return 0 }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { $0 + pow($1 - mean, 2) } / Double(returns.count - 1)
        return sqrt(variance) * 100.0
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
        let phiCandidates: [Double] = [0.85, 0.92, 0.98]
        let validationWindow = min(60, max(20, prices.count / 5))

        // Composite skor — yön isabeti coin-flip üstüne ödüllendirilir; tek başına MAPE
        // bias'lı modelleri seçebiliyordu (yön ters ama level yakın).
        // score = -mape + 60 * max(0, dirAcc - 0.5)
        // Daha yüksek skor daha iyi. -∞ ile başlatıyoruz.
        var bestScore = -Double.greatestFiniteMagnitude
        var best = PrometheusTuningResult(
            alpha: 0.3,
            beta: 0.1,
            phi: 0.92,
            mape: 100.0,
            directionalAccuracy: 0.0,
            absErrors: []
        )

        // Tie-breaker: lexicographic (alpha, beta, phi) — deterministik test için.
        for alpha in alphaCandidates {
            for beta in betaCandidates {
                for phi in phiCandidates {
                    let diagnostics = rollingOneStepDiagnostics(
                        prices: prices,
                        validationWindow: validationWindow,
                        alpha: alpha,
                        beta: beta,
                        phi: phi
                    )
                    guard diagnostics.count > 0 else { continue }

                    let mape = diagnostics.map(\.ape).reduce(0, +) / Double(diagnostics.count)
                    let directionHits = diagnostics.filter { $0.directionCorrect }.count
                    let directionAccuracy = Double(directionHits) / Double(diagnostics.count)

                    let dirSkill = max(0, directionAccuracy - 0.5)
                    let score = -mape + 60.0 * dirSkill

                    if score > bestScore {
                        bestScore = score
                        best = PrometheusTuningResult(
                            alpha: alpha,
                            beta: beta,
                            phi: phi,
                            mape: mape,
                            directionalAccuracy: directionAccuracy,
                            absErrors: diagnostics.map(\.absError)
                        )
                    }
                }
            }
        }

        return best
    }

    private func rollingOneStepDiagnostics(
        prices: [Double],
        validationWindow: Int,
        alpha: Double,
        beta: Double,
        phi: Double
    ) -> [PrometheusPointDiagnostic] {
        guard prices.count >= (validationWindow + 10) else { return [] }

        var out: [PrometheusPointDiagnostic] = []
        let start = prices.count - validationWindow

        for i in start..<prices.count {
            guard i >= 5 else { continue }
            let train = Array(prices[0..<i])
            let actual = prices[i]
            let prediction = dampedHoltForecast(
                prices: train, daysAhead: 1,
                alpha: alpha, beta: beta, phi: phi
            ).first ?? actual

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
        // OOS inflasyon: in-sample residual quantile'ı OOS varyansını az tahmin eder.
        // 1.5 başlangıç değeri; PR sonrası 30+ sembol backtest ile kalibre edilecek.
        let oosInflation = 1.5
        let baseError = max(q90 * oosInflation, fallbackError)

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

    /// Cost-aware recommendation: işlem maliyeti ve volatilite-ölçekli minimum edge ile.
    /// BIST için tipik round-trip maliyet ≈ %0.5 (BSMV + komisyon + spread); US ≈ %0.1.
    /// Minimum edge = max(2 × txCost, 0.5 × stdDevPct) — düşük volatil sembolde maliyet,
    /// yüksek volatil sembolde gürültü zemini eşiği belirler.
    private func recommendAction(
        symbol: String,
        currentPrice: Double,
        predictedPrice: Double,
        lowerBound: Double,
        upperBound: Double,
        confidence: Double,
        stdDevPct: Double
    ) -> PrometheusRecommendationDecision {
        guard currentPrice > 0 else {
            return PrometheusRecommendationDecision(
                action: .hold,
                holdReasons: ["Geçerli fiyat yok"]
            )
        }

        let txCost = symbol.uppercased().hasSuffix(".IS") ? 0.5 : 0.1
        let minEdge = max(2.0 * txCost, 0.5 * stdDevPct)
        let confidenceFloor = 65.0

        let expectedReturn = (predictedPrice - currentPrice) / currentPrice * 100.0
        let conservativeReturn = (lowerBound - currentPrice) / currentPrice * 100.0
        let optimisticReturn = (upperBound - currentPrice) / currentPrice * 100.0

        // BUY: güven yüksek + alt bant maliyetin üstünde + beklenen getiri minEdge'i geçer
        let buyConfidenceOK = confidence >= confidenceFloor
        let buyConservativeOK = conservativeReturn >= txCost
        let buyEdgeOK = expectedReturn >= minEdge

        if buyConfidenceOK && buyConservativeOK && buyEdgeOK {
            return PrometheusRecommendationDecision(action: .buy, holdReasons: [])
        }

        // SELL: simetrik
        let sellConfidenceOK = confidence >= confidenceFloor
        let sellOptimisticOK = optimisticReturn <= -txCost
        let sellEdgeOK = expectedReturn <= -minEdge

        if sellConfidenceOK && sellOptimisticOK && sellEdgeOK {
            return PrometheusRecommendationDecision(action: .sell, holdReasons: [])
        }

        // HOLD — hangi koşulun karşılanmadığını topla.
        var reasons: [String] = []
        if !buyConfidenceOK && !sellConfidenceOK {
            reasons.append(String(format: "güven %%%.0f < %%%.0f", confidence, confidenceFloor))
        }
        if abs(expectedReturn) < minEdge {
            reasons.append(String(format: "beklenen getiri %%%.2f, minimum edge %%%.2f", expectedReturn, minEdge))
        }
        if expectedReturn > 0 && !buyConservativeOK {
            reasons.append(String(format: "alt bant getirisi %%%.2f, maliyet %%%.2f", conservativeReturn, txCost))
        }
        if expectedReturn < 0 && !sellOptimisticOK {
            reasons.append(String(format: "üst bant getirisi %%%.2f, -maliyet %%%.2f", optimisticReturn, -txCost))
        }
        if reasons.isEmpty {
            reasons.append("Tüm koşullar marjda; net sinyal yok")
        }
        return PrometheusRecommendationDecision(action: .hold, holdReasons: reasons)
    }

    private func buildRationale(
        horizon: Int,
        dataPoints: Int,
        alpha: Double,
        beta: Double,
        phi: Double,
        mape: Double,
        directionalAccuracy: Double,
        intervalWidthPct: Double,
        recommendation: PrometheusRecommendation,
        holdReasons: [String]
    ) -> [String] {
        let recText: String
        switch recommendation {
        case .buy: recText = "Beklenen getiri işlem maliyeti eşiğini aşıyor ve alt bant pozitif: AL."
        case .sell: recText = "Tahmin bandı ağırlıklı negatif ve üst bant da maliyet eşiğinin altında: SAT."
        case .hold:
            // "Neden BUY/SELL değil?" — somut sebepleri rationale'a yaz.
            if holdReasons.isEmpty {
                recText = "BEKLE — getiri/belirsizlik dengesi net değil."
            } else {
                recText = "BEKLE — " + holdReasons.joined(separator: "; ") + "."
            }
        }

        return [
            "Veri derinliği: \(dataPoints) bar, ufuk: \(horizon) gün.",
            String(format: "Kalibrasyon: alpha=%.2f, beta=%.2f, phi=%.2f (sönümleme).", alpha, beta, phi),
            String(format: "Walk-forward MAPE: %.2f%%, yön isabeti: %.1f%%.", mape, directionalAccuracy * 100),
            String(format: "Tahmin aralığı genişliği: %.2f%% (OOS inflasyonu uygulanmış).", intervalWidthPct),
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
        case 70...100: return "Yüksek"
        case 50..<70: return "Orta"
        case 30..<50: return "Düşük"
        default: return "Çok Düşük"
        }
    }
    
    /// Creates an "insufficient data" forecast
    /// Actor (PrometheusEngine) içinden çağrılabilmesi için `nonisolated`.
    nonisolated static func insufficient(symbol: String) -> PrometheusForecast {
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
            modelVersion: "Damped-Holt-V3",
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

private struct PrometheusRecommendationDecision {
    let action: PrometheusRecommendation
    let holdReasons: [String]
}

private struct PrometheusTuningResult {
    let alpha: Double
    let beta: Double
    let phi: Double
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
