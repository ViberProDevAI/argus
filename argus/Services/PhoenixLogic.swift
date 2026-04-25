import Foundation

/// Pure functional logic for Phoenix (Channel Reversion Strategy).
/// Decoupled from Actor state for use in Backtesting and Live Trading.
struct PhoenixLogic {
    
    /// Analyzes the provided candles to generate Phoenix Advice.
    /// - Parameters:
    ///   - candles: Array of candles (must be sufficient length, typically > lookback).
    ///   - symbol: The asset symbol.
    ///   - timeframe: Timeframe of the data.
    ///   - config: Configuration parameters.
    /// - Returns: Calculated PhoenixAdvice or insufficient state.
    static func analyze(
        candles: [Candle],
        symbol: String,
        timeframe: PhoenixTimeframe,
        config: PhoenixConfig
    ) -> PhoenixAdvice {
        
        let n = candles.count
        let N = min(config.lookback, n)
        
        // Ensure enough data for minimal calculation (e.g. 60 bars)
        guard n >= 60 else {
            return PhoenixAdvice.insufficient(symbol: symbol, timeframe: timeframe)
        }
        
        // Analyze last N bars
        let analysisSlice = Array(candles.suffix(N))
        
        // 1. Linear Regression Channel
        let closes = analysisSlice.map { $0.close }
        let (slope, intercept, sigma, mid, upper, lower) = calculateLinRegChannel(closes: closes, k: config.regressionMultiplier)
        
        // 2. ATR
        let atr = calculateATR(candles: analysisSlice, period: config.atrPeriod)
        
        // 3. Buffers & Zones
        let bufferBase: Double
        if let val = atr {
            bufferBase = max(config.bufferAtrFraction * val, config.bufferSigmaFraction * sigma)
        } else {
            bufferBase = 0.15 * sigma
        }
        
        let entryZoneLow = lower - (0.10 * bufferBase)
        let entryZoneHigh = lower + (0.90 * bufferBase)
        
        let invalidation: Double
        if let val = atr {
            invalidation = lower - (0.75 * val)
        } else {
            invalidation = lower - (1.25 * sigma)
        }
        
        // 4. Targets
        let t1 = mid
        // Dynamic T2: Conservative if downtrend
        let isDowntrend = slope < -(mid * 0.0005)
        let t2 = isDowntrend ? mid + (upper - mid) * 0.5 : upper
        
        // 4.5. R-SQUARED CHECK (Statistical Validity)
        // SOFTENED: 0.5 was too strict, lowered to 0.25
        let rSquared = calculateRSquared(closes: analysisSlice.map { $0.close }, slope: slope, intercept: intercept)
        let channelReliable = rSquared > 0.25  // Was 0.5 - too strict
        
        // 5. Triggers
        guard let latest = analysisSlice.last else {
             return PhoenixAdvice.insufficient(symbol: symbol, timeframe: timeframe)
        }
        
        let touchLowerBand = latest.low <= (lower + 0.10 * bufferBase)
        
        // RSI
        let rsiPeriod = 14
        let rsiValues = calculateRSI(candles: analysisSlice, period: rsiPeriod)
        let currentRSI = rsiValues.last ?? 50
        let prevRSI = rsiValues.dropLast().last ?? 50
        
        let rsiReversal = (currentRSI >= 40 && prevRSI < 40 && currentRSI > prevRSI)
        
        // Divergence
        let divergence = checkBullishDivergence(candles: analysisSlice, rsi: rsiValues, lookback: 30)
        
        // Trend Check
        let trendOk = slope >= 0 || slope > -(mid * 0.0002)
        
        // Detect market mode
        let isUptrend = slope > 0 && latest.close > mid
        
        // 6. SCORING - Both reversion and trend-following
        var score = 50.0
        
        // MEAN REVERSION SCORING (Primary)
        if touchLowerBand { score += 20 }
        if rsiReversal { score += 15 }
        if divergence { score += 15 }
        if currentRSI < 35 { score += 10 }  // Deeply oversold
        if trendOk { score += 5 }  // Not in strong downtrend
        
        // TREND FOLLOWING (Reduced scoring for uptrend, not blocked)
        if isUptrend && !touchLowerBand {
            // In uptrend but not at lower band - reduce Phoenix confidence
            // But still give a score if trend is strong
            score = 40 + (slope > 0 ? 10 : 0)  // Base 40-50 for uptrend
        }
        
        // Channel reliability penalty
        if !channelReliable {
            score *= 0.7  // 30% penalty for unreliable channel
        }
        
        // Volume Spike (confirmation)
        let vol = latest.volume
        let avgVol = analysisSlice.suffix(21).prefix(20).map { $0.volume }.reduce(0, +) / 20.0
        if avgVol > 0 && vol > 1.5 * avgVol {
            score += 10  // Volume confirmation is important for reversals
        }
        
        // Penalties
        if slope < -(mid * 0.0005) { score -= 20 }  // Strong downtrend penalty
        if (sigma / mid) > 0.08 { score -= 10 }  // High volatility penalty
        if currentRSI > 50 { score -= 15 }  // Not oversold
        
        score = min(max(score, 0), 100)
        
        // 7. Reason
        let reason = generateReason(score: score, touch: touchLowerBand, rsi: rsiReversal, div: divergence, slope: slope)
        
        return PhoenixAdvice(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            timeframe: timeframe,
            status: .active,
            lookback: N,
            regressionSlope: slope,
            channelUpper: upper,
            channelMid: mid,
            channelLower: lower,
            sigma: sigma,
            entryZoneLow: entryZoneLow,
            entryZoneHigh: min(entryZoneHigh, mid),
            invalidationLevel: invalidation,
            targets: [t1, t2],
            triggers: PhoenixAdvice.Triggers(
                touchLowerBand: touchLowerBand,
                rsiReversal: rsiReversal,
                bullishDivergence: divergence,
                trendOk: trendOk
            ),
            confidence: score,
            reasonShort: reason,
            atr: atr,
            rSquared: rSquared  // NEW: Channel reliability
        )
    }
    
    // MARK: - Mathematical Helpers (Originally Private in Engine)
    
    static func calculateLinRegChannel(closes: [Double], k: Double) -> (Double, Double, Double, Double, Double, Double) {
        let n = Double(closes.count)
        guard n > 1 else { return (0,0,0,0,0,0) }
        
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        
        for (i, y) in closes.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Sigma
        var sumSqResid = 0.0
        for (i, y) in closes.enumerated() {
            let x = Double(i)
            let predicted = intercept + slope * x
            let resid = y - predicted
            sumSqResid += resid * resid
        }
        
        let sigma = sqrt(sumSqResid / n)
        
        // Final Values (at x = N-1)
        let finalX = n - 1
        let mid = intercept + slope * finalX
        let upper = mid + (k * sigma)
        let lower = mid - (k * sigma)
        
        return (slope, intercept, sigma, mid, upper, lower)
    }
    
    /// Calculate R-squared (Coefficient of Determination) for linear regression
    /// - Returns: Value between 0 and 1, where 1 = perfect fit
    static func calculateRSquared(closes: [Double], slope: Double, intercept: Double) -> Double {
        guard closes.count > 1 else { return 0.0 }
        
        let mean = closes.reduce(0, +) / Double(closes.count)
        
        var ssRes = 0.0  // Sum of squared residuals
        var ssTot = 0.0  // Total sum of squares
        
        for (i, y) in closes.enumerated() {
            let x = Double(i)
            let predicted = intercept + slope * x
            let residual = y - predicted
            ssRes += residual * residual
            ssTot += (y - mean) * (y - mean)
        }
        
        guard ssTot > 0 else { return 0.0 }
        return 1.0 - (ssRes / ssTot)
    }
    
    static func calculateATR(candles: [Candle], period: Int) -> Double? {
        guard candles.count > period else { return nil }
        
        // Optimization: Calculate only needed TRs? No, need MA.
        var trs: [Double] = []
        for i in 1..<candles.count {
            let h = candles[i].high
            let l = candles[i].low
            let cp = candles[i-1].close
            let tr = max(h - l, max(abs(h - cp), abs(l - cp)))
            trs.append(tr)
        }
        
        let suffix = trs.suffix(period)
        let sum = suffix.reduce(0, +)
        return sum / Double(period)
    }
    
    static func calculateRSI(candles: [Candle], period: Int) -> [Double] {
        // SSoT: IndicatorService kullanılıyor
        let values = candles.map { $0.close }
        let rsiArray = IndicatorService.calculateRSI(values: values, period: period)
        // nil değerleri 50.0 ile değiştir (nötr)
        return rsiArray.map { $0 ?? 50.0 }
    }
    
    static func checkBullishDivergence(candles: [Candle], rsi: [Double], lookback: Int) -> Bool {
        let rsiCount = rsi.count
        let candleCount = candles.count
        guard rsiCount >= 20 else { return false }
        
        let checkSize = min(lookback, rsiCount)
        let rsiSlice = Array(rsi.suffix(checkSize))
        
        var dips: [(Int, Double)] = []
        
        for i in 1..<(rsiSlice.count - 1) {
            let prev = rsiSlice[i-1]
            let curr = rsiSlice[i]
            let next = rsiSlice[i+1]
            
            if curr < prev && curr < next && curr < 45 {
                dips.append((i, curr))
            }
        }
        
        guard dips.count >= 2 else { return false }
        
        let lastDip = dips.last!
        let lastDipRSI = lastDip.1
        
        // Helper to get price low for a relative slice index
        func getPriceLow(sliceIndex: Int) -> Double {
            let offsetFromEnd = rsiSlice.count - 1 - sliceIndex
            let candleIndex = candleCount - 1 - offsetFromEnd
            return candles[candleIndex].low
        }
        
        let lastDipPrice = getPriceLow(sliceIndex: lastDip.0)
        
        for i in 0..<(dips.count - 1) {
            let priorDip = dips[i]
            let priorDipRSI = priorDip.1
            let priorDipPrice = getPriceLow(sliceIndex: priorDip.0)
            
            if lastDipPrice < priorDipPrice && lastDipRSI > priorDipRSI {
                return true
            }
        }
        
        return false
    }
    
    static func generateReason(score: Double, touch: Bool, rsi: Bool, div: Bool, slope: Double) -> String {
        if score >= 70 {
            return "Fiyat kanal dibine yakın; toparlanma sinyali (RSI/Div) ve hacim desteği var."
        } else if score >= 40 {
            var reasons: [String] = []
            if touch { reasons.append("Kanal teması") }
            if rsi { reasons.append("RSI dönüşü") }
            if div { reasons.append("Uyumsuzluk") }
            let detail = reasons.isEmpty ? "bekleme" : reasons.joined(separator: ", ")
            return "Kanal dibine yakınlık var ancak teyit nispeten zayıf (\(detail))."
        } else {
            if slope < 0 {
                return "Negatif trend eğimi nedeniyle senaryo devre dışı veya yüksek riskli."
            } else {
                return "Trend/teyit çok zayıf; Phoenix senaryosu için koşullar oluşmadı."
            }
        }
    }
}
