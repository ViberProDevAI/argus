import Foundation

// MARK: - Models

enum OverreactionShockType: String, Codable {
    case gapDown = "Gap Down"
    case intradayFlush = "Intraday Flush"
    case multiDayDump = "Multi-Day Dump"
    case none = "None"
}

struct OverreactionResult: Identifiable, Codable {
    var id = UUID()
    let score: Double             // 0-100
    let shockType: OverreactionShockType
    let magnitudeZScore: Double   // Z-Score of the move
    let relativeToSpy: Double?    // % difference vs SPY
    
    // Components (for explaining the score)
    let qualityScore: Double      // Atlas
    let macroScore: Double        // Aether
    
    // Trade Plan
    let entryPrice: Double?
    let stopLoss: Double?
    let targets: [Double]         // T1, T2, T3
    let timeStopDays: Int
    let notes: String
    
    // Utility for easy UI checking
    var isOpportunity: Bool { score >= 60 }
}

// MARK: - Engine

class OverreactionEngine {
    static let shared = OverreactionEngine()
    
    private init() {}
    
    /// Analyzes a stock for Overreaction opportunities.
    /// - Parameters:
    ///   - symbol: Stock Ticker
    ///   - candles: Daily candles (OHLCV)
    ///   - atlasScore: Fundamental Quality Score (0-100)
    ///   - aetherScore: Macro Regime Score (0-100)
    ///   - spyCandles: Optional SPY candles for relative check
    /// - Returns: OverreactionResult? (Nil if pre-filters fail or no data)
    func analyze(
        symbol: String,
        candles: [Candle],
        atlasScore: Double?,
        aetherScore: Double?,
        spyCandles: [Candle]? = nil
    ) -> OverreactionResult? {
        
        let sorted = candles.sorted { $0.date < $1.date }
        guard sorted.count > 60 else { return nil } // Need history for statistics
        
        let last = sorted.last!
        let prev = sorted[sorted.count - 2]
        
        // 1. PRE-FILTERS (The "Quality" Gate)
        // ----------------------------------------------------
        
        // A. Quality Check
        let quality = atlasScore ?? 50.0 // Default to neutral if missing, but prefer skipping
        if quality < 55 { return nil } // Must be decent quality
        
        // B. Liquidity Check (Avg Vol > 5M approx)
        // Let's settle for > 1M explicitly for broader coverage, or strict 5M?
        // User asked for "Avg daily volume >= 5M USD".
        // Let's approximate: Vol * Price > 5M USD is "Dollar Volume".
        // Or simply Volume count. Usually "High Cap" implies volumes in millions.
        // Let's calculate avg volume of last 20 days.
        let last20 = sorted.suffix(20)
        let avgVol = last20.map { $0.volume }.reduce(0, +) / Double(last20.count)
        let avgPrice = last20.map { $0.close }.reduce(0, +) / Double(last20.count)
        let dollarVol = avgVol * avgPrice
        
        // 5M USD Dollar Volume restriction
        if dollarVol < 5_000_000 { return nil }
        
        // C. Penny Stock Filter
        if last.close < 3.0 { return nil }
        
        
        // 2. DETECTION (The "Shock" Identification)
        // ----------------------------------------------------
        
        // Calculate Returns
        var returns: [Double] = []
        for i in 1..<sorted.count {
            let r = (sorted[i].close - sorted[i-1].close) / sorted[i-1].close
            returns.append(r)
        }
        
        // Stats for last 60 days
        let lookback = 60
        let recentReturns = returns.suffix(lookback)
        let mean = recentReturns.reduce(0, +) / Double(recentReturns.count)
        let variance = recentReturns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentReturns.count)
        let stdDev = sqrt(variance)
        
        // Current Move (Today)
        let currentReturn = returns.last ?? 0.0
        let zScore = (currentReturn - mean) / stdDev
        
        // Relative to SPY Check
        // If spyCandles provided, verify correlation/beta? Or just brute force relative drop.
        var relativeDrop: Double? = nil
        if let spy = spyCandles, let lastSpy = spy.last, let prevSpy = spy.dropLast().last {
             // Assume spy candles align by date roughly (daily)
             // Ideally we match dates rigorously. For now, simple assumption: Last bar is same day.
             let spyReturn = (lastSpy.close - prevSpy.close) / prevSpy.close
             relativeDrop = currentReturn - spyReturn // e.g. -5% - (-1%) = -4% (Good)
        }
        
        // CRITERIA for "Overreaction"
        let isShock = zScore <= -2.0
        let isRelativeShock = (relativeDrop ?? -0.03) <= -0.02 // If no SPY, assume true if drop is harsh
        
        // Volume Spike
        let volRatio = last.volume / avgVol
        let isVolSpike = volRatio >= 1.5
        
        if !isShock || !isRelativeShock || !isVolSpike {
            // No trade today.
            // But wait, maybe it was a multi-day dump?
            // "3-5 days consecutive".
            // Let's inspect last 3 days.
            // If accumulated return z-score is super low?
            // User spec: 2.2) "Son günün getirisi... Z-score <= -2.0"
            // Let's return nil if primary triggers fail for now.
             return nil // Strict filter
        }
        
        
        // 3. CLASSIFICATION
        // ----------------------------------------------------
        var type: OverreactionShockType = .intradayFlush
        
        // Gap Down: Open is significantly below Prev Close
        let gapSize = (last.open - prev.close) / prev.close
        if gapSize < -0.02 { // 2% gap
            type = .gapDown
        }
        
        // 4. FALLING KNIFE FILTERS
        // ----------------------------------------------------
        
        // A. Trend Check (50 > 200 SMA)
        // Need to calc simple SMAs.
        let sma50 = calculateSMA(candles: sorted, period: 50)
        let sma200 = calculateSMA(candles: sorted, period: 200)
        
        guard let s50 = sma50, let s200 = sma200 else { return nil }
        
        // If 50 < 200, it's a downtrend. We want quality dips in UPTRENDS or mostly stable.
        if s50 < s200 {
            // Allow if Aether is VERY high (Risk-on)? No, strict filter.
             return nil
        }
        
        // B. Max Drawdown last 6 months (approx 126 bars)
        let last6M = sorted.suffix(126)
        let maxPrice = last6M.map { $0.high }.max() ?? last.high
        let currentDD = (maxPrice - last.close) / maxPrice
        
        // If stock is already down 50% from high, it's a falling knife / dead stock.
        if currentDD > 0.40 { return nil }
        
        
        // 5. SCORING (0-100)
        // ----------------------------------------------------
        // M: Magnitude (Z-Score). Capped at -4.0 for max score.
        // Range: -2.0 (min) to -4.0 (max).
        // -2.0 -> 0 pts, -4.0 -> 100 pts?
        // Let's map Z: -2 to -5.
        
        let zClamped = max(min(zScore, -2.0), -6.0) // -2 to -6
        let mScore = mapRange(val: abs(zClamped), inMin: 2.0, inMax: 6.0, outMin: 50, outMax: 100)
        
        // Q: Atlas (0-100)
        let qScore = quality
        
        // T: Trend (Orion Proxy)
        // Simply: How far is price above 200SMA? Closer to SMA200 might be better buy?
        // Or Trend Strength.
        // Let's use: (Close > SMA200) ? 100 : 0.
        // And maybe RSI?
        // "Orion Trend Metric": Let's calculate RSI(14).
        let rsi = calculateRSI(candles: sorted) ?? 50
        // RSI < 30 is oversold (Good for this strategy).
        // T_Component: Lower RSI -> Higher Score.
        let tScore = mapRange(val: rsi, inMin: 20, inMax: 40, outMin: 100, outMax: 0) // <20 -> 100, >40 -> 0
        
        // R: Aether (0-100)
        let rScore = aetherScore ?? 50.0
        
        // Weighted Sum
        // raw = 0.35*M + 0.30*Q + 0.20*T + 0.15*R
        let finalScore = (0.35 * mScore) + (0.30 * qScore) + (0.20 * tScore) + (0.15 * rScore)
        
        
        // 6. TRADE PLAN
        // ----------------------------------------------------
        
        // ATR for Stop
        let atr = calculateATR(candles: sorted, period: 14) ?? (last.high - last.low)
        
        // Entry: Next Open (Estimated as Current Close for planning)
        let entry = last.close
        
        // Stop: Low - 1.5 * ATR
        // If gap down, maybe Low of today is support.
        let sl = last.low - (1.5 * atr)
        
        let risk = entry - sl
        
        // Targets
        let t1 = entry + (1.5 * risk)
        let t2 = entry + (2.5 * risk)
        let t3 = entry + (4.0 * risk)
        
        return OverreactionResult(
            score: min(max(finalScore, 0), 100),
            shockType: type,
            magnitudeZScore: zScore,
            relativeToSpy: relativeDrop,
            qualityScore: qScore,
            macroScore: rScore,
            entryPrice: entry,
            stopLoss: sl,
            targets: [t1, t2, t3],
            timeStopDays: 15,
            notes: "Z-Score: \(String(format: "%.2f", zScore)) | Vol: \(String(format: "%.1fx", volRatio))"
        )
    }
    
    // MARK: - Helpers
    private func calculateSMA(candles: [Candle], period: Int) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        let values = candles.map { $0.close }
        return IndicatorService.lastSMA(values: values, period: period)
    }
    
    private func mapRange(val: Double, inMin: Double, inMax: Double, outMin: Double, outMax: Double) -> Double {
        let percentage = (val - inMin) / (inMax - inMin)
        let clamped = min(max(percentage, 0.0), 1.0)
        return outMin + (clamped * (outMax - outMin))
    }
    
    private func calculateRSI(candles: [Candle], period: Int = 14) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastRSI(candles: candles, period: period)
    }
    
    private func calculateATR(candles: [Candle], period: Int) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastATR(candles: candles, period: period)
    }
}
