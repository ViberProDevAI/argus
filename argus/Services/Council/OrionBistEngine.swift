import Foundation

/// Orion BIST Engine (Project Turquoise)
/// Specialized Technical Engine for Turkey Markets
/// Focuses on Momentum (TSI), Relative Strength, and Parabolic SAR.
/// Supports both Legacy BIST Architecture and New Council Architecture.

// MARK: - Legacy Types (Restored for Compatibility)
enum OrionBistSignal: String {
    case buy = "GÜÇLÜ AL"
    case sell = "GÜÇLÜ SAT"
    case hold = "NÖTR"
}

struct OrionBistResult {
    let score: Double
    let signal: OrionBistSignal
    let tsiValue: Double
    let sarStatus: String
    let description: String
}

class OrionBistEngine {
    static let shared = OrionBistEngine()
    
    // Pine Script Parameters
    private let tsiLong = 9
    private let tsiShort = 3
    private let linRegLength = 10
    private let sarStart = 0.02
    private let sarInc = 0.02
    private let sarMax = 0.2
    
    // MARK: - Legacy API (Used by SirkiyeViewModel)
    func analyze(candles: [BistCandle]) -> OrionBistResult {
        // Convert BistCandle to Double arrays for calculation
        let closes = candles.map { $0.close }
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }
        
        return performTechnicalAnalysis(closes: closes, highs: highs, lows: lows)
    }
    
    // MARK: - Council API (New Architecture)
    func analyze(symbol: String, candles: [Candle]) -> CouncilDecision {
        let timestamp = Date()
        
        let closes = candles.map { $0.close }
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }
        
        let result = performTechnicalAnalysis(closes: closes, highs: highs, lows: lows)
        
        // Convert OrionBistResult to CouncilDecision
        let action: ProposedAction
        switch result.signal {
        case .buy: action = .buy
        case .sell: action = .sell
        case .hold: action = .hold
        }
        
        let confidence = min(max(result.score / 100.0, 0.0), 1.0)
        
        let proposal = CouncilProposal(
            proposer: "OrionBist",
            proposerName: "Orion (Turquoise)",
            action: action,
            confidence: confidence,
            reasoning: result.description,
            entryPrice: nil,
            stopLoss: nil,
            target: nil
        )
        
        return CouncilDecision(
            symbol: symbol,
            action: action,
            netSupport: confidence,
            approveWeight: confidence,
            vetoWeight: 0.0,
            isStrongSignal: result.score >= 80,
            isWeakSignal: result.score >= 60 && result.score < 80,
            winningProposal: proposal,
            allProposals: [proposal],
            votes: [],
            vetoReasons: [],
            timestamp: timestamp
        )
    }
    
    // MARK: - Core Logic (Shared)
    private func performTechnicalAnalysis(closes: [Double], highs: [Double], lows: [Double]) -> OrionBistResult {
        guard closes.count > 50 else {
            return OrionBistResult(score: 0, signal: .hold, tsiValue: 0, sarStatus: "N/A", description: "Yetersiz Veri")
        }
        
        // 1. TSI
        let tsi = calculateTSI(closes: closes, long: tsiLong, short: tsiShort)
        let currentTSI = tsi.last ?? 0.0
        
        // 2. Slope
        let slope = calculateLinearSlope(data: tsi, length: linRegLength)
        
        // 3. SAR
        let sarValues = calculateSAR(highs: highs, lows: lows, afStart: sarStart, afInc: sarInc, afMax: sarMax)
        let currentSAR = sarValues.last ?? 0.0
        let currentClose = closes.last ?? 0.0
        let isSarUp = currentClose > currentSAR
        
        // 4. Scoring
        var score: Double = 50.0
        if currentTSI > 0 { score += 10 }
        if currentTSI > 20 { score += 10 }
        else if currentTSI < -20 { score -= 10 }
        
        if slope > 0 { score += 20 }
        else { score -= 20 }
        
        if isSarUp { score += 30 }
        else { score -= 30 }
        
        score = max(0, min(100, score))
        
        let signal: OrionBistSignal
        if score >= 80 { signal = .buy }
        else if score <= 20 { signal = .sell }
        else { signal = .hold }
        
        let sarStr = isSarUp ? "SAR AL" : "SAR SAT"
        let tsiStr = String(format: "TSI: %.1f", currentTSI)
        let slopeStr = slope > 0 ? "Momentum Artıyor" : "Momentum Zayıf"
        
        return OrionBistResult(
            score: score,
            signal: signal,
            tsiValue: currentTSI,
            sarStatus: sarStr,
            description: "\(sarStr) | \(tsiStr) | \(slopeStr)"
        )
    }
    
    // MARK: - Indicators
    private func calculateTSI(closes: [Double], long: Int, short: Int) -> [Double] {
        guard closes.count > long + short else { return [] }
        var pc: [Double] = []
        for i in 1..<closes.count { pc.append(closes[i] - closes[i-1]) }
        
        let pcs = ema(data: pc, period: long)
        let apcs = ema(data: pc.map { abs($0) }, period: long)
        
        let pcs2 = ema(data: pcs, period: short)
        let apcs2 = ema(data: apcs, period: short)
        
        var tsi: [Double] = []
        for i in 0..<pcs2.count {
            if apcs2[i] != 0 {
                tsi.append(100.0 * (pcs2[i] / apcs2[i]))
            } else { tsi.append(0.0) }
        }
        return tsi
    }
    
    private func ema(data: [Double], period: Int) -> [Double] {
        guard !data.isEmpty else { return [] }
        let k = 2.0 / Double(period + 1)
        var result: [Double] = [data[0]]
        for i in 1..<data.count {
            // Güvenli erişim - result her zaman en az 1 eleman içerir
            let lastResult = result.last ?? data[0]
            result.append((data[i] * k) + (lastResult * (1.0 - k)))
        }
        return result
    }
    
    private func calculateLinearSlope(data: [Double], length: Int) -> Double {
        guard data.count >= length else { return 0.0 }
        let subset = Array(data.suffix(length))
        let n = Double(length)
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0
        for i in 0..<length {
            let x = Double(i + 1)
            let y = subset[i]
            sumX += x; sumY += y; sumXY += (x*y); sumXX += (x*x)
        }
        return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
    }
    
    private func calculateSAR(highs: [Double], lows: [Double], afStart: Double, afInc: Double, afMax: Double) -> [Double] {
        guard highs.count > 1 else { return [] }
        var sar = Array(repeating: 0.0, count: highs.count)
        var isBullish = true
        var af = afStart
        var ep = highs[0]
        sar[0] = lows[0]
        
        for i in 1..<highs.count {
            let prevSar = sar[i-1]
            if isBullish {
                sar[i] = prevSar + af * (ep - prevSar)
                let prevLow = lows[i-1]
                let prevLow2 = (i > 1) ? lows[i-2] : prevLow
                sar[i] = min(sar[i], prevLow, prevLow2)
                
                if highs[i] > ep { ep = highs[i]; af = min(af + afInc, afMax) }
                if lows[i] < sar[i] { isBullish = false; sar[i] = ep; ep = lows[i]; af = afStart }
            } else {
                sar[i] = prevSar + af * (ep - prevSar)
                let prevHigh = highs[i-1]
                let prevHigh2 = (i > 1) ? highs[i-2] : prevHigh
                sar[i] = max(sar[i], prevHigh, prevHigh2)
                
                if lows[i] < ep { ep = lows[i]; af = min(af + afInc, afMax) }
                if highs[i] > sar[i] { isBullish = true; sar[i] = ep; ep = highs[i]; af = afStart }
            }
        }
        return sar
    }
}
