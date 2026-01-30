import Foundation

// MARK: - Orion Brain (Logic Layer) 🧠
/// The central nervous system of Argus. Coordinates specific subsystems to produce a final Score.
struct OrionBrain {
    let trendSystem = OrionTrendSystem()
    let momentumSystem = OrionMomentumSystem()
    let volatilitySystem = OrionVolatilitySystem()
    let consensusSystem = OrionConsensusSystem()
    let bistSystem = OrionBistEngine.shared // Uses existing engine
    
    // MARK: - Main Analysis Function
    func analyze(symbol: String, candles: [Candle], spyCandles: [Candle]?) -> OrionScoreResult? {
        // Need decent history
        guard candles.count > 50 else { return nil }
        let sorted = candles.sorted { $0.date < $1.date }
        
        // 1. Get Weights (Chiron > Deep Tune > Default)
        let weights = getWeights(symbol: symbol)
        
        // 2. Subsystem Analysis
        // Structure
        let structRes = OrionStructureService.shared.analyzeStructure(candles: sorted) // Still external for now
        let structScore = structRes?.score ?? 50.0
        let structWeighted = (structScore / 100.0) * weights.structure
        
        // Trend
        let trendResult = trendSystem.analyze(candles: sorted, spyCandles: spyCandles, maxScore: weights.trend)
        
        // Momentum
        let momResult = momentumSystem.analyze(candles: sorted, maxScore: weights.momentum)
        
        // Pattern
        let patternRes = OrionPatternService.shared.analyzePatterns(candles: sorted, context: structRes?.activeZone)
        let patternWeighted = (patternRes.score / 100.0) * weights.pattern
        
        // Volatility
        let volResult = volatilitySystem.analyze(candles: sorted, maxScore: weights.volatility)
        
        // 3. Aggregation
        var finalScore = structWeighted + trendResult.weightedScore + momResult.weightedScore + patternWeighted + volResult.weightedScore
        
        // Synergy Bonus
        if let s = structRes, s.trendState == .uptrend, s.activeZone != nil {
            finalScore *= 1.08
        }
        
        // BIST Modifier
        var bistDesc: String? = nil
        if SymbolResolver.shared.isBistSymbol(symbol) || symbol.uppercased().hasSuffix(".IS") {
            let decisions = bistSystem.analyze(symbol: symbol, candles: sorted)
            let mod: Double
            switch decisions.action {
            case .buy: mod = 10.0
            case .sell: mod = -10.0
            case .hold: mod = 0.0
            }
            finalScore += mod
            bistDesc = "🇹🇷 BIST: \(decisions.action.rawValue) | \(decisions.winningProposal?.reasoning ?? "")"
        }
        
        finalScore = min(100.0, max(0.0, finalScore))
        
        // 4. Construct Result
        let components = OrionComponentScores(
            trend: trendResult.weightedScore,
            momentum: momResult.weightedScore,
            relativeStrength: trendResult.rsScore,
            structure: structWeighted,
            pattern: patternWeighted,
            volatility: volResult.volRawScore,
            
            rsi: momResult.rsiValue,
            macdHistogram: trendResult.macdHist,
            
            trendAge: trendSystem.calculateTrendAge(candles: sorted),
            trendStrength: IndicatorService.lastADX(candles: sorted),
            aroon: IndicatorService.lastAroon(candles: sorted),
            
            isRsAvailable: trendResult.rsAvailable,
            trendDesc: trendResult.description,
            momentumDesc: momResult.description,
            structureDesc: structRes?.description ?? "Yapı Nötr",
            patternDesc: bistDesc ?? patternRes.description,
            rsDesc: trendResult.rsDesc,
            volDesc: volResult.description
        )
        
        // 5. Consensus
        let consensus = consensusSystem.analyze(candles: sorted)
        
        return OrionScoreResult(
            symbol: symbol,
            score: finalScore,
            components: components,
            signalBreakdown: consensus,
            verdict: getVerdict(score: finalScore),
            generatedAt: Date()
        )
    }
    
    // MARK: - Helpers
    private func getWeights(symbol: String) -> (structure: Double, trend: Double, momentum: Double, pattern: Double, volatility: Double) {
        if let learned = ChironRegimeEngine.shared.getLearnedOrionWeights(symbol: symbol) {
            print("🧠 Orion[\(symbol)]: Chiron öğrenilmiş ağırlıklar aktif")
            return (learned.structure * 100, learned.trend * 100, learned.momentum * 100, learned.pattern * 100, learned.volatility * 100)
        }
        let config = OrionV2TuningStore.shared.getConfig(symbol: symbol)
        return (config.structureWeight * 100, config.trendWeight * 100, config.momentumWeight * 100, config.patternWeight * 100, config.volatilityWeight * 100)
    }
    
    private func getVerdict(score: Double) -> String {
        switch score {
        case 85...100: return "A+ Fırsat (Nadir)"
        case 70..<85: return "Güçlü Alım"
        case 50..<70: return "Nötr / Tut"
        case 30..<50: return "Zayıf / İzle"
        default: return "Uzak Dur"
        }
    }
}

// MARK: - Subsystems

struct OrionTrendSystem {
    struct Result {
        let weightedScore: Double
        let rawScore: Double
        let description: String
        let rsScore: Double
        let rsDesc: String
        let rsAvailable: Bool
        let macdHist: Double?
    }
    
    func analyze(candles: [Candle], spyCandles: [Candle]?, maxScore: Double) -> Result {
        let (tRaw, tDesc) = calculateTrendLeg(candles: candles)
        let (rsRaw, rsDescStr, rsAvail) = calculateRSLeg(stock: candles, spy: spyCandles)
        let (macdRaw, _, macdHistVal) = calculateMACDForTrend(candles: candles)
        
        let weighted: Double
        if rsAvail {
            // Trend(30) + RS(15) + MACD(10) = 55
            let total = tRaw + rsRaw + macdRaw
            weighted = (total / 55.0) * maxScore
        } else {
            // Trend(30) + MACD(10) = 40
            let total = tRaw + macdRaw
            weighted = (total / 40.0) * maxScore
        }
        
        return Result(
            weightedScore: weighted,
            rawScore: tRaw,
            description: "\(tDesc) | \(rsDescStr)",
            rsScore: rsRaw,
            rsDesc: rsDescStr,
            rsAvailable: rsAvail,
            macdHist: macdHistVal
        )
    }
    
    // Logic from original calculateTrendLeg
    private func calculateTrendLeg(candles: [Candle]) -> (Double, String) {
        let closes = candles.map { $0.close }
        let current = closes.last ?? 0
        
        guard let sma20 = IndicatorService.lastSMA(values: closes, period: 20),
              let sma50 = IndicatorService.lastSMA(values: closes, period: 50),
              let sma200 = IndicatorService.lastSMA(values: closes, period: 200) else {
            return (0.0, "Yetersiz Veri (SMA)")
        }
        
        var rawScore = 0.0
        
        // 1. Bias
        if current > sma200 {
            rawScore += 10.0
        } else {
            let distTo200 = (sma200 - current) / sma200
            if distTo200 < 0.02 { rawScore += 5.0 }
        }
        
        // 2. Alignment
        if sma20 > sma50 && sma50 > sma200 { rawScore += 10.0 }
        else if sma20 > sma50 { rawScore += 7.0 }
        else if sma20 > sma200 { rawScore += 3.0 }
        
        // 3. Positioning
        let dist20 = (current - sma20) / sma20
        if dist20 > 0 {
            let momentumFactor = min(1.0, dist20 / 0.05)
            rawScore += 5.0 + (5.0 * momentumFactor)
        } else {
            if sma20 > sma50 {
                let depth = abs(dist20)
                if depth < 0.03 { rawScore += 6.0 }
                else if depth < 0.07 { rawScore += 3.0 }
            }
        }
        
        // 4. Penalty
        let dist50 = (current - sma50) / sma50
        if dist50 > 0.20 {
            let excess = (dist50 - 0.20) * 100.0
            rawScore -= min(5.0, excess)
        }
        
        let final = max(0, min(30, rawScore))
        return (final, String(format: "Trend: %.1f/30", final))
    }
    
    private func calculateRSLeg(stock: [Candle], spy: [Candle]?) -> (Double, String, Bool) {
        guard let spy = spy, !spy.isEmpty, stock.count > 30, spy.count > 30 else {
            return (0.0, "Kıyaslama verisi yok", false)
        }
        
        let sNow = stock.last!.close
        let sOld = stock[stock.count - 30].close
        let sRet = (sNow - sOld) / sOld
        
        let mNow = spy.last!.close
        let mOld = spy[spy.count - 30].close
        let mRet = (mNow - mOld) / mOld
        
        let deltaPct = (sRet - mRet) * 100.0
        
        if deltaPct >= 5.0 { return (15.0, "Endeks Üstü Performans", true) }
        else if deltaPct >= 0.0 { return (10.0, "Endekse Paralel", true) }
        else if deltaPct > -5.0 { return (7.0, "Hafif Negatif", true) }
        return (3.0, "Endeks Altı", true)
    }
    
    private func calculateMACDForTrend(candles: [Candle]) -> (Double, String, Double?) {
        let (macdLine, signal, hist) = IndicatorService.lastMACD(candles: candles)
        guard let h = hist, let sig = signal, let _ = macdLine else { return (5.0, "Veri Yok", nil) }
        
        var score = 0.0
        var desc = ""
        
        if h > 0 {
            score += 6.0
            if sig > 0 { score += 4.0; desc = "MACD Güçlü" }
            else { score += 2.0; desc = "MACD Erken" }
        } else {
            if h > sig { score += 5.0; desc = "MACD Toparlanıyor" }
            else { score += 2.0; desc = "MACD Zayıf" }
        }
        return (min(10.0, score), desc, h)
    }
    
    func calculateTrendAge(candles: [Candle]) -> Int {
        let closes = candles.map { $0.close }
        let sma20s = IndicatorService.calculateSMA(values: closes, period: 20)
        let sma50s = IndicatorService.calculateSMA(values: closes, period: 50)
        
        var age = 0
        for i in 0..<closes.count {
            let idx = closes.count - 1 - i
            guard let s20 = sma20s[idx], let s50 = sma50s[idx] else { break }
            if s20 > s50 { age += 1 } else { break }
        }
        return age
    }
}

struct OrionMomentumSystem {
    struct Result {
        let weightedScore: Double
        let rawScore: Double
        let description: String
        let rsiValue: Double?
    }
    
    func analyze(candles: [Candle], maxScore: Double) -> Result {
        let (momRaw, momDesc, rsiVal) = calculateMomentumLeg(candles: candles)
        let (volLiqRaw, volDesc) = calculateVolLiquidity(candles: candles)
        
        // RSI(15) + Vol(15) = 30
        let total = momRaw + volLiqRaw
        let weighted = (total / 30.0) * maxScore
        
        return Result(
            weightedScore: weighted,
            rawScore: total,
            description: "\(momDesc) | \(volDesc)",
            rsiValue: rsiVal
        )
    }
    
    private func calculateMomentumLeg(candles: [Candle]) -> (Double, String, Double?) {
        guard let rsiVal = IndicatorService.lastRSI(candles: candles) else { return (7.5, "Veri Yok", nil) }
        var score = 0.0
        var notes: [String] = []
        
        if rsiVal >= 50 && rsiVal <= 70 {
            let strength = (rsiVal - 50) / 20.0
            score += 8.0 + (7.0 * strength)
            notes.append("RSI Güçlü")
        } else if rsiVal > 70 {
            if rsiVal > 80 { score += 6.0; notes.append("RSI Şişkin") }
            else { score += 12.0; notes.append("RSI Yüksek") }
        } else if rsiVal >= 40 {
            score += 5.0 + (3.0 * (rsiVal - 40) / 10.0)
            notes.append("RSI Nötr")
        } else {
            if rsiVal < 30 { score += 8.0; notes.append("RSI Dip") }
            else { score += 5.0; notes.append("RSI Zayıf") }
        }
        return (min(15.0, score), notes.joined(separator: ","), rsiVal)
    }
    
    private func calculateVolLiquidity(candles: [Candle]) -> (Double, String) {
        // Liquidity
        let suffix = candles.suffix(20)
        let avgVol = suffix.map { Double($0.volume) }.reduce(0, +) / Double(suffix.count)
        let price = candles.last?.close ?? 0
        let dollarVol = avgVol * price
        
        var scoreLiq = 0.0
        if dollarVol > 1_000_000 {
            let logVal = log10(dollarVol)
            let norm = (logVal - 6.0) / 2.0
            scoreLiq = 2.0 + (6.0 * min(1.0, max(0.0, norm)))
        } else { scoreLiq = 1.0 }
        
        let desc = "Hacim: $\(Int(dollarVol/1000))k"
        return (scoreLiq, desc)
    }
}

struct OrionVolatilitySystem {
    struct Result {
        let weightedScore: Double
        let volRawScore: Double
        let description: String
    }
    
    func analyze(candles: [Candle], maxScore: Double) -> Result {
        let (score, isSqueeze) = calculate(candles: candles)
        let weighted = (score / 100.0) * maxScore
        return Result(weightedScore: weighted, volRawScore: score, description: isSqueeze ? "Squeeze (Sıkışma)" : "Normal Volatilite")
    }
    
    private func calculate(candles: [Candle]) -> (Double, Bool) {
        let closes = candles.map { $0.close }
        guard closes.count >= 20, let sma20 = IndicatorService.lastSMA(values: closes, period: 20) else {
            return (50.0, false)
        }
        
        let recent = Array(closes.suffix(20))
        let variance = recent.map { pow($0 - sma20, 2) }.reduce(0, +) / 20.0
        let stdDev = sqrt(variance)
        let bbWidth = (stdDev * 2) / sma20 * 100.0
        
        // Historical check for squeeze would go here (simplified for refactor)
        let isSqueeze = bbWidth < 2.0 // Simple threshold for now to save complexity
        
        var score = 50.0
        if isSqueeze { score += 30.0 }
        
        let atr = IndicatorService.lastATR(candles: candles) ?? 0
        let atrPct = (atr / (candles.last?.close ?? 1)) * 100
        
        if atrPct > 1.5 && atrPct < 4.0 { score += 20.0 }
        else if atrPct < 1.0 { score += 10.0 }
        else if atrPct > 6.0 { score -= 20.0 }
        
        return (min(100.0, max(0.0, score)), isSqueeze)
    }
}

struct OrionConsensusSystem {
    func analyze(candles: [Candle]) -> OrionSignalBreakdown {
        var indicators: [OrionSignalBreakdown.SignalItem] = []
        var osc = VoteCount(buy: 0, sell: 0, neutral: 0)
        var ma = VoteCount(buy: 0, sell: 0, neutral: 0)
        
        let price = candles.last?.close ?? 0
        
        // RSI
        if let rsi = IndicatorService.lastRSI(candles: candles) {
            let act = rsi < 30 ? "AL" : (rsi > 70 ? "SAT" : "NÖTR")
            addVote(act, to: &osc)
            indicators.append(.init(name: "RSI", value: String(format: "%.0f", rsi), action: act))
        }
        
        // MACD
        let macd = IndicatorService.lastMACD(candles: candles)
        if let line = macd.macd, let sig = macd.signal {
            let act = line > sig ? "AL" : "SAT"
            addVote(act, to: &osc)
            indicators.append(.init(name: "MACD", value: String(format: "%.2f", line), action: act))
        }
        
        // CCI
        if let cci = IndicatorService.lastCCI(candles: candles) {
            let act = cci < -100 ? "AL" : (cci > 100 ? "SAT" : "NÖTR")
            addVote(act, to: &osc)
            indicators.append(.init(name: "CCI", value: String(format: "%.0f", cci), action: act))
        }
        
        // SMAs
        let smas = [20, 50, 200]
        for p in smas {
            if let v = IndicatorService.lastSMA(values: candles.map { $0.close }, period: p) {
                let act = price > v ? "AL" : "SAT"
                addVote(act, to: &ma)
                indicators.append(.init(name: "SMA \(p)", value: String(format: "%.2f", v), action: act))
            }
        }
        
        let summary = VoteCount(buy: osc.buy + ma.buy, sell: osc.sell + ma.sell, neutral: osc.neutral + ma.neutral)
        return OrionSignalBreakdown(oscillators: osc, movingAverages: ma, summary: summary, indicators: indicators)
    }
    
    private func addVote(_ action: String, to vote: inout VoteCount) {
        if action == "AL" { vote.buy += 1 }
        else if action == "SAT" { vote.sell += 1 }
        else { vote.neutral += 1 }
    }
}

// MARK: - Legacy Service (Facade)
final class OrionAnalysisService: @unchecked Sendable {
    static let shared = OrionAnalysisService()
    private let brain = OrionBrain()
    
    // Caching
    private let lock = NSLock()
    private var cache: [String: (result: OrionScoreResult, candleCount: Int, timestamp: Date)] = [:]
    
    private init() {}
    
    func calculateOrionScore(symbol: String, candles: [Candle], spyCandles: [Candle]? = nil) -> OrionScoreResult? {
        lock.lock()
        if let c = cache[symbol], c.candleCount == candles.count, Date().timeIntervalSince(c.timestamp) < 300 {
            lock.unlock()
            return c.result
        }
        lock.unlock()
        
        let result = brain.analyze(symbol: symbol, candles: candles, spyCandles: spyCandles)
        
        if let r = result {
            lock.lock()
            cache[symbol] = (r, candles.count, Date())
            lock.unlock()
        }
        
        return result
    }
    
    // MARK: - Shared Helpers (Restored for Athena/Scout)
    func calculateVWAP(candles: [Candle]) -> Double? {
        guard !candles.isEmpty else { return nil }
        var cumPV = 0.0
        var cumVol = 0.0
        for candle in candles {
            let typicalPrice = (candle.high + candle.low + candle.close) / 3.0
            cumPV += typicalPrice * Double(candle.volume)
            cumVol += Double(candle.volume)
        }
        return cumVol == 0 ? nil : cumPV / cumVol
    }
    
    struct PivotPoints {
        let p: Double, r1: Double, s1: Double
    }
    
    func calculatePivots(candles: [Candle]) -> PivotPoints? {
        guard candles.count >= 2 else { return nil }
        let prev = candles[candles.count - 2]
        let p = (prev.high + prev.low + prev.close) / 3.0
        return PivotPoints(p: p, r1: (2 * p) - prev.low, s1: (2 * p) - prev.high)
    }
    
    func calculateATR(candles: [Candle], period: Int = 14) -> Double {
        // Simple Average TR for helpers (different from Wilder's in Engine but consistent with old Athena logic)
        guard candles.count >= period + 1 else { return 0.0 }
        let sorted = candles.sorted { $0.date < $1.date }
        var trueRanges: [Double] = []
        
        for i in 1..<sorted.count {
            let h = sorted[i].high
            let l = sorted[i].low
            let pc = sorted[i-1].close
            trueRanges.append(max(h - l, max(abs(h - pc), abs(l - pc))))
        }
        
        let recentTRs = trueRanges.suffix(period)
        return recentTRs.isEmpty ? 0.0 : recentTRs.reduce(0, +) / Double(recentTRs.count)
    }
    
    func calculateOrionScoreAsync(symbol: String, candles: [Candle], spyCandles: [Candle]? = nil) async -> OrionScoreResult? {
        // Offload to background thread
        return await Task.detached(priority: .userInitiated) {
            return self.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: spyCandles)
        }.value
    }
}
