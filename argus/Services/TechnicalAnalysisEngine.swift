import Foundation

/// A high-performance Technical Analysis engine designed to replace manual loops.
/// optimized for Swift Array operations.
enum TechnicalAnalysisEngine {
    
    // MARK: - RSI (Relative Strength Index)
    /// Calculates RSI with Wilder's Smoothing. Optimizes memory usage by pre-allocating.
    static func rsi(values: [Double], period: Int = 14) -> [Double?] {
        guard values.count > period else { return [Double?](repeating: nil, count: values.count) }
        
        var rsiValues = [Double?](repeating: nil, count: values.count)
        
        var gain: Double = 0.0
        var loss: Double = 0.0
        
        // 1. Initial Calculation (SMA method for first period)
        for i in 1...period {
            let diff = values[i] - values[i - 1]
            if diff > 0 {
                gain += diff
            } else {
                loss += abs(diff)
            }
        }
        
        var avgGain = gain / Double(period)
        var avgLoss = loss / Double(period)
        
        if avgLoss == 0 {
            rsiValues[period] = 100.0
        } else {
            let rs = avgGain / avgLoss
            rsiValues[period] = 100.0 - (100.0 / (1.0 + rs))
        }
        
        // 2. Smoothed Calculation (Wilder's Method) for subsequent values
        for i in (period + 1)..<values.count {
            let diff = values[i] - values[i - 1]
            let currentGain = max(diff, 0)
            let currentLoss = max(-diff, 0)
            
            // Previous Avg * (Period-1) + Current / Period
            avgGain = ((avgGain * Double(period - 1)) + currentGain) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + currentLoss) / Double(period)
            
            if avgLoss == 0 {
                rsiValues[i] = 100.0
            } else {
                let rs = avgGain / avgLoss
                rsiValues[i] = 100.0 - (100.0 / (1.0 + rs))
            }
        }
        
        return rsiValues
    }
    
    // MARK: - MACD
    static func macd(values: [Double], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {
        let fastEMA = ema(values: values, period: fastPeriod)
        let slowEMA = ema(values: values, period: slowPeriod)
        
        var macdLine = [Double?](repeating: nil, count: values.count)
        var validMacdValues: [Double] = []
        var validMacdIndices: [Int] = []
        
        // Calculate MACD Line
        for i in 0..<values.count {
            if let f = fastEMA[i], let s = slowEMA[i] {
                let val = f - s
                macdLine[i] = val
                validMacdValues.append(val)
                validMacdIndices.append(i)
            }
        }
        
        // Calculate Signal Line (EMA of MACD Line)
        var signalLine = [Double?](repeating: nil, count: values.count)
        var histogram = [Double?](repeating: nil, count: values.count)
        
        if !validMacdValues.isEmpty {
            let signalEmaValues = ema(values: validMacdValues, period: signalPeriod)
            
            // Map back to original indices
            for (idx, val) in signalEmaValues.enumerated() {
                let originalIndex = validMacdIndices[idx]
                signalLine[originalIndex] = val
                
                if let m = macdLine[originalIndex], let s = val {
                    histogram[originalIndex] = m - s
                }
            }
        }
        
        return (macdLine, signalLine, histogram)
    }
    
    // MARK: - Bollinger Bands
    static func bollingerBands(values: [Double], period: Int = 20, multiplier: Double = 2.0) -> (upper: [Double?], middle: [Double?], lower: [Double?]) {
        let smaValues = sma(values: values, period: period)
        var upper = [Double?](repeating: nil, count: values.count)
        var lower = [Double?](repeating: nil, count: values.count)
        
        for i in (period - 1)..<values.count {
            guard let mid = smaValues[i] else { continue }
            
            // Calculate Standard Deviation
            let slice = values[(i - period + 1)...i] // Optimization: Swift Arrays are smart about slices, but could be specific
            let sumSqDiff = slice.reduce(0) { $0 + pow($1 - mid, 2) }
            let stdDev = sqrt(sumSqDiff / Double(period))
            
            upper[i] = mid + (stdDev * multiplier)
            lower[i] = mid - (stdDev * multiplier)
        }
        
        return (upper, smaValues, lower)
    }
    
    // MARK: - Stochastic
    static func stochastic(candles: [Candle], kPeriod: Int = 14, dPeriod: Int = 3) -> (k: [Double?], d: [Double?]) {
        var kValues = [Double?](repeating: nil, count: candles.count)
        
        for i in (kPeriod - 1)..<candles.count {
            let slice = candles[(i - kPeriod + 1)...i]
            // Accessing properties directly is fast
            let highs = slice.map { $0.high }
            let lows = slice.map { $0.low }
            
            guard let highestHigh = highs.max(), let lowestLow = lows.min() else { continue }
            let currentClose = candles[i].close
            
            if highestHigh - lowestLow != 0 {
                kValues[i] = ((currentClose - lowestLow) / (highestHigh - lowestLow)) * 100.0
            } else {
                kValues[i] = 50.0 // Default
            }
        }
        
        // %D is SMA of %K
        // Extract valid numbers
        var dValues = [Double?](repeating: nil, count: candles.count)
        var validKs: [Double] = []
        var validIndices: [Int] = []
        
        for i in 0..<kValues.count {
            if let val = kValues[i] {
                validKs.append(val)
                validIndices.append(i)
            }
        }
        
        if !validKs.isEmpty {
            let smaK = sma(values: validKs, period: dPeriod)
            for (idx, val) in smaK.enumerated() {
                dValues[validIndices[idx]] = val
            }
        }
        
        return (kValues, dValues)
    }
    
    // MARK: - ATR (Average True Range)
    static func atr(candles: [Candle], period: Int = 14) -> [Double?] {
        guard candles.count > period else { return [Double?](repeating: nil, count: candles.count) }
        var atrValues = [Double?](repeating: nil, count: candles.count)
        
        var trValues = [Double]()
        trValues.reserveCapacity(candles.count)
        
        // 1. Calculate TR for all
        for i in 0..<candles.count {
            if i == 0 {
                trValues.append(candles[i].high - candles[i].low)
            } else {
                let high = candles[i].high
                let low = candles[i].low
                let prevClose = candles[i-1].close
                
                let tr = max(high - low, max(abs(high - prevClose), abs(low - prevClose)))
                trValues.append(tr)
            }
        }
        
        // 2. Initial ATR (Simple Average)
        let initialSlice = trValues.prefix(period)
        var currentATR = initialSlice.reduce(0, +) / Double(period)
        atrValues[period - 1] = currentATR
        
        // 3. Smoothed ATR
        for i in period..<candles.count {
            currentATR = ((currentATR * Double(period - 1)) + trValues[i]) / Double(period)
            atrValues[i] = currentATR
        }
        
        return atrValues
    }
    
    // MARK: - Helpers
    static func sma(values: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard values.count >= period else { return result }
        
        // Efficient SMA using sliding window sum
        var sum = values.prefix(period).reduce(0, +)
        result[period - 1] = sum / Double(period)
        
        for i in period..<values.count {
            sum += values[i]
            sum -= values[i - period]
            result[i] = sum / Double(period)
        }
        
        return result
    }
    
    static func ema(values: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard values.count >= period else { return result }
        
        let k = 2.0 / Double(period + 1)
        
        // Initial SMA
        let startSum = values.prefix(period).reduce(0, +)
        var currentEMA = startSum / Double(period)
        result[period - 1] = currentEMA
        
        for i in period..<values.count {
            currentEMA = (values[i] * k) + (currentEMA * (1.0 - k))
            result[i] = currentEMA
        }
        
        return result
    }
    
    // MARK: - CCI (Commodity Channel Index)
    static func cci(candles: [Candle], period: Int = 20) -> [Double?] {
        var cciValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count >= period else { return cciValues }
        
        let tpValues = candles.map { ($0.high + $0.low + $0.close) / 3.0 }
        let smaTP = sma(values: tpValues, period: period)
        
        for i in (period - 1)..<candles.count {
            guard let sma = smaTP[i] else { continue }
            
            let slice = tpValues[(i - period + 1)...i]
            let meanDeviation = slice.map { abs($0 - sma) }.reduce(0, +) / Double(period)
            
            if meanDeviation != 0 {
                cciValues[i] = (tpValues[i] - sma) / (0.015 * meanDeviation)
            } else {
                cciValues[i] = 0
            }
        }
        
        return cciValues
    }
    
    // MARK: - ADX (Average Directional Index)
    static func adx(candles: [Candle], period: Int = 14) -> [Double?] {
        var tr = [Double](repeating: 0.0, count: candles.count)
        var plusDM = [Double](repeating: 0.0, count: candles.count)
        var minusDM = [Double](repeating: 0.0, count: candles.count)
        
        for i in 1..<candles.count {
            let currentHigh = candles[i].high
            let currentLow = candles[i].low
            let prevClose = candles[i-1].close
            let prevHigh = candles[i-1].high
            let prevLow = candles[i-1].low
            
            tr[i] = max(currentHigh - currentLow, max(abs(currentHigh - prevClose), abs(currentLow - prevClose)))
            
            let upMove = currentHigh - prevHigh
            let downMove = prevLow - currentLow
            
            if upMove > downMove && upMove > 0 {
                plusDM[i] = upMove
            }
            if downMove > upMove && downMove > 0 {
                minusDM[i] = downMove
            }
        }
        
        func wilderSmooth(values: [Double]) -> [Double] {
            var smoothed = [Double](repeating: 0.0, count: values.count)
            guard values.count > period else { return smoothed }
            smoothed[period] = values[1...period].reduce(0, +)
            for i in (period + 1)..<values.count {
                smoothed[i] = smoothed[i-1] - (smoothed[i-1] / Double(period)) + values[i]
            }
            return smoothed
        }
        
        let trSmooth = wilderSmooth(values: tr)
        let plusDMSmooth = wilderSmooth(values: plusDM)
        let minusDMSmooth = wilderSmooth(values: minusDM)
        
        var adxValues = [Double?](repeating: nil, count: candles.count)
        var dxValues = [Double](repeating: 0.0, count: candles.count)
        
        for i in period..<candles.count {
            if trSmooth[i] != 0 {
                let plusDI = 100 * (plusDMSmooth[i] / trSmooth[i])
                let minusDI = 100 * (minusDMSmooth[i] / trSmooth[i])
                if (plusDI + minusDI) != 0 {
                    dxValues[i] = 100 * abs(plusDI - minusDI) / (plusDI + minusDI)
                }
            }
        }
        
        if candles.count > 2 * period {
            let firstADXIndex = 2 * period
            let slice = dxValues[(period + 1)...firstADXIndex]
            adxValues[firstADXIndex] = slice.reduce(0, +) / Double(period)
            
            for i in (firstADXIndex + 1)..<candles.count {
                if let prev = adxValues[i-1] {
                     adxValues[i] = ((prev * Double(period - 1)) + dxValues[i]) / Double(period)
                }
            }
        }
        
        return adxValues
    }
    
    // MARK: - Williams %R
    static func williamsR(candles: [Candle], period: Int = 14) -> [Double?] {
        var values = [Double?](repeating: nil, count: candles.count)
        guard candles.count >= period else { return values }
        
        for i in (period - 1)..<candles.count {
            let slice = candles[(i - period + 1)...i] 
            let highestHigh = slice.map { $0.high }.max() ?? 1
            let lowestLow = slice.map { $0.low }.min() ?? 0
            let close = candles[i].close
            
            if highestHigh - lowestLow != 0 {
                values[i] = ((highestHigh - close) / (highestHigh - lowestLow)) * -100.0
            } else {
                values[i] = -50.0 // Default center
            }
        }
        return values
    }
    
    // MARK: - Aroon Oscillator
    static func aroon(candles: [Candle], period: Int = 25) -> [Double?] {
        var values = [Double?](repeating: nil, count: candles.count)
        guard candles.count >= period + 1 else { return values }
        
        for i in period..<candles.count {
            let startIndex = i - period
            let slice = candles[startIndex...i]
            
            var highVal = -Double.infinity
            var lowVal = Double.infinity
            var daysSinceHigh = 0
            var daysSinceLow = 0
            
            for (offset, candle) in slice.enumerated() {
                let daysAgo = period - offset
                
                if candle.high >= highVal {
                    highVal = candle.high
                    daysSinceHigh = daysAgo
                }
                
                if candle.low <= lowVal {
                    lowVal = candle.low
                    daysSinceLow = daysAgo
                }
            }
            
            let up = ((Double(period) - Double(daysSinceHigh)) / Double(period)) * 100.0
            let down = ((Double(period) - Double(daysSinceLow)) / Double(period)) * 100.0
            
            values[i] = up - down
        }
        return values
    }
    
    // MARK: - Ichimoku Cloud
    struct IchimokuResult {
        let tenkanSen: [Double?]
        let kijunSen: [Double?]
        let senkouSpanA: [Double?]
        let senkouSpanB: [Double?]
        let chikouSpan: [Double?]
    }
    
    static func ichimoku(candles: [Candle]) -> IchimokuResult {
        let tenkanPeriod = 9
        let kijunPeriod = 26
        let senkouBPeriod = 52
        let displacement = 26
        
        let count = candles.count
        var tenkan = [Double?](repeating: nil, count: count)
        var kijun = [Double?](repeating: nil, count: count)
        var spanA = [Double?](repeating: nil, count: count)
        var spanB = [Double?](repeating: nil, count: count)
        var chikou = [Double?](repeating: nil, count: count)
        
        func getMid(period: Int, index: Int) -> Double? {
            guard index >= period - 1 else { return nil }
            let slice = candles[(index - period + 1)...index]
            let high = slice.map { $0.high }.max() ?? 0
            let low = slice.map { $0.low }.min() ?? 0
            return (high + low) / 2
        }
        
        for i in 0..<count {
            tenkan[i] = getMid(period: tenkanPeriod, index: i)
            kijun[i] = getMid(period: kijunPeriod, index: i)
            
            if i >= displacement, let t = tenkan[i - displacement], let k = kijun[i - displacement] {
                spanA[i] = (t + k) / 2
            }
            
            if i >= displacement, let midB = getMid(period: senkouBPeriod, index: i - displacement) {
                spanB[i] = midB
            }
            
            if i + displacement < count {
                chikou[i] = candles[i + displacement].close
            }
        }
        
        return IchimokuResult(tenkanSen: tenkan, kijunSen: kijun, senkouSpanA: spanA, senkouSpanB: spanB, chikouSpan: chikou)
    }
    
    // MARK: - TSI (True Strength Index)
    static func tsi(values: [Double], longPeriod: Int = 25, shortPeriod: Int = 13) -> [Double?] {
         var tsiValues = [Double?](repeating: nil, count: values.count)
         guard values.count > longPeriod + shortPeriod else { return tsiValues }
         
         var pc: [Double] = []
         for i in 1..<values.count {
             pc.append(values[i] - values[i-1])
         }
         
         // Helper: Raw EMA (non-optional)
         func emaRaw(data: [Double], period: Int) -> [Double] {
             guard !data.isEmpty else { return [] }
             let k = 2.0 / Double(period + 1)
             var result: [Double] = [data[0]]
             for i in 1..<data.count {
                 result.append((data[i] * k) + (result.last! * (1.0 - k)))
             }
             return result
         }
         
         let pcSmooth1 = emaRaw(data: pc, period: longPeriod)
         let pcSmooth2 = emaRaw(data: pcSmooth1, period: shortPeriod)
         
         let apc = pc.map { abs($0) }
         let apcSmooth1 = emaRaw(data: apc, period: longPeriod)
         let apcSmooth2 = emaRaw(data: apcSmooth1, period: shortPeriod)
         
         let offset = 1 
         for i in 0..<pcSmooth2.count {
             if apcSmooth2[i] != 0 {
                 let val = 100.0 * (pcSmooth2[i] / apcSmooth2[i])
                 let originalIndex = i + offset
                 if originalIndex < values.count {
                     tsiValues[originalIndex] = val
                 }
             }
         }
         
         return tsiValues
    }
    
    // MARK: - Parabolic SAR
    static func sar(candles: [Candle], acceleration: Double = 0.02, maximum: Double = 0.2) -> [Double?] {
        var sarValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count > 2 else { return sarValues }
        
        var af = acceleration
        var isLong = true
        var sar = candles[0].low
        var ep = candles[0].high
        
        sarValues[0] = sar
        
        for i in 1..<candles.count {
            sarValues[i] = sar
            
            if isLong {
                sar = sar + af * (ep - sar)
                sar = min(sar, candles[i-1].low)
                if i > 1 { sar = min(sar, candles[i-2].low) }
                
                if candles[i].low < sar {
                    isLong = false
                    sar = ep
                    ep = candles[i].low
                    af = acceleration
                } else {
                    if candles[i].high > ep {
                        ep = candles[i].high
                        af = min(af + acceleration, maximum)
                    }
                }
            } else {
                sar = sar + af * (ep - sar)
                sar = max(sar, candles[i-1].high)
                if i > 1 { sar = max(sar, candles[i-2].high) }
                
                if candles[i].high > sar {
                    isLong = true
                    sar = ep
                    ep = candles[i].high
                    af = acceleration
                } else {
                    if candles[i].low < ep {
                        ep = candles[i].low
                        af = min(af + acceleration, maximum)
                    }
                }
            }
        }
        return sarValues
    }
}
