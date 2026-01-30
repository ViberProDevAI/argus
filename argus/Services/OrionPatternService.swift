import Foundation

struct OrionPatternResult {
    let score: Double
    let matchedPatterns: [CandlePattern]
    let description: String
}

enum PatternType {
    case bullish
    case bearish
    case neutral
}

struct CandlePattern {
    let name: String
    let type: PatternType
    let significance: Double // 1-10
}

class OrionPatternService {
    static let shared = OrionPatternService()
    
    private init() {}
    
    func analyzePatterns(candles: [Candle], context: StructureZone?) -> OrionPatternResult {
        guard candles.count >= 3 else { 
            return OrionPatternResult(score: 50, matchedPatterns: [], description: "Yetersiz Veri") 
        }
        
        let c = candles.suffix(3).map { $0 } // Last 3 candles
        let last = c.last!
        let prev = c[c.count - 2]
        
        var patterns: [CandlePattern] = []
        var scoreBonus = 0.0
        
        // 1. Hammer / Doji (Single Candle)
        if isHammer(last) {
            patterns.append(CandlePattern(name: "Hammer", type: .bullish, significance: 5))
            scoreBonus += 5
        } else if isDoji(last) {
            patterns.append(CandlePattern(name: "Doji", type: .neutral, significance: 3))
            // Doji is indecision. If on support, positive. If in void, neutral.
        }
        
        // 2. Engulfing (Two Candles)
        if isBullishEngulfing(prev: prev, curr: last) {
            patterns.append(CandlePattern(name: "Bullish Engulfing", type: .bullish, significance: 8))
            scoreBonus += 10
        }
        
        // --- Context Multiplier ---
        // A Hammer is worth 2x if on Support/Fib
        if let zone = context {
            switch zone {
            case .support, .fibonacci:
                if patterns.contains(where: { $0.type == .bullish }) {
                    scoreBonus *= 1.5 // Synergy!
                }
            case .resistance:
                 if patterns.contains(where: { $0.type == .bearish }) {
                    scoreBonus -= 10 // Short signal
                }
            default: break
            }
        }
        
        let desc = patterns.map { $0.name }.joined(separator: ", ")
        
        // Base 50
        return OrionPatternResult(
            score: 50.0 + scoreBonus,
            matchedPatterns: patterns,
            description: desc.isEmpty ? "Formasyon Yok" : desc
        )
    }
    
    // MARK: - Detectors
    
    private func isDoji(_ c: Candle) -> Bool {
        let body = abs(c.close - c.open)
        let total = c.high - c.low
        return total > 0 && (body / total) < 0.1 // Body is less than 10% of range
    }
    
    private func isHammer(_ c: Candle) -> Bool {
        let body = abs(c.close - c.open)
        let lowerWick = min(c.open, c.close) - c.low
        let upperWick = c.high - max(c.open, c.close)
        
        // Small body, long lower wick, small upper wick
        return (lowerWick > 2 * body) && (upperWick < body)
    }
    
    private func isBullishEngulfing(prev: Candle, curr: Candle) -> Bool {
        // Prev is Red, Curr is Green
        let prevRed = prev.close < prev.open
        let currGreen = curr.close > curr.open
        
        // Curr body covers Prev body
        let currBodyHigh = max(curr.close, curr.open)
        let currBodyLow = min(curr.close, curr.open)
        let prevBodyHigh = max(prev.close, prev.open)
        let prevBodyLow = min(prev.close, prev.open)
        
        return prevRed && currGreen && (currBodyHigh > prevBodyHigh) && (currBodyLow < prevBodyLow)
    }
}
