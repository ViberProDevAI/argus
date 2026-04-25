import Foundation

struct OrionStructureResult {
    let score: Double
    let description: String
    let activeZone: StructureZone? // Support, Resistance, FibLevel
    let trendState: TrendState
    
    // Debug info
    let fibLevels: [Double]
    let swingHigh: Double
    let swingLow: Double
}

enum StructureZone {
    case support(level: Double, strength: Double)
    case resistance(level: Double, strength: Double)
    case fibonacci(level: Double, ratio: Double) // e.g. 0.618
    case none
}

enum TrendState: String {
    case uptrend = "Yükseliş"
    case downtrend = "Düşüş"
    case range = "Yatay"
}

class OrionStructureService {
    static let shared = OrionStructureService()
    
    private init() {}
    
    /// Main entry point for Structural Analysis
    func analyzeStructure(candles: [Candle]) -> OrionStructureResult? {
        guard candles.count > 50 else { return nil }
        
        let closes = candles.map { $0.close }
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }
        let currentPrice = closes.last ?? 0.0
        
        // 1. Identify Trend (Market Structure) using Swing Points
        let swingPoints = calculateZigZag(highs: highs, lows: lows, deviation: 3.0) // 3% deviation
        guard swingPoints.count >= 2 else { return nil }
        
        // Determine Trend based on last 2 Highs and Lows
        let trend = determineTrend(points: swingPoints)
        
        // 2. Calculate Fibonacci Levels from the last major impulse
        // If Uptrend: Swing Low to Swing High
        // If Downtrend: Swing High to Swing Low
        let fibResult = calculateFibonacciLevels(currentPrice: currentPrice, points: swingPoints, trend: trend)
        
        // 3. Score the Position
        // Are we at a Golden Pocket (0.618)?
        // Are we at a Support?
        let scoreResult = scorePosition(price: currentPrice, fibResult: fibResult, trend: trend)
        
        return OrionStructureResult(
            score: scoreResult.score,
            description: scoreResult.description,
            activeZone: scoreResult.zone,
            trendState: trend,
            fibLevels: fibResult.levels,
            swingHigh: fibResult.high,
            swingLow: fibResult.low
        )
    }
    
    // MARK: - ZigZag Algorithm
    
    enum SwingPointType {
        case high
        case low
    }
    
    struct SwingPoint {
        let index: Int
        let price: Double
        let type: SwingPointType
    }
    
    /// Simplified ZigZag to find local pivots
    private func calculateZigZag(highs: [Double], lows: [Double], deviation: Double) -> [SwingPoint] {
        var points: [SwingPoint] = []
        var trend: Int = 0 // 1 = Up, -1 = Down
        var lastHigh = highs[0]
        var lastLow = lows[0]
        
        // Initial setup
        points.append(SwingPoint(index: 0, price: lows[0], type: .low)) // Start assumption
        
        for i in 0..<highs.count {
            let h = highs[i]
            let l = lows[i]
            
            if trend == 0 {
                // Initialize first move
                if h > lastHigh * (1 + deviation/100.0) {
                    trend = 1
                    lastHigh = h
                    points.append(SwingPoint(index: i, price: h, type: .high))
                } else if l < lastLow * (1 - deviation/100.0) {
                    trend = -1
                    lastLow = l
                    points.append(SwingPoint(index: i, price: l, type: .low))
                }
            } else if trend == 1 { // Uptrend looking for High
                if h > lastHigh {
                    lastHigh = h
                    // Update last point if it was a high
                    if let last = points.last, last.type == .high {
                        points.removeLast()
                    }
                    points.append(SwingPoint(index: i, price: h, type: .high))
                } else if l < lastHigh * (1 - deviation/100.0) {
                    // Reversal
                    trend = -1
                    lastLow = l
                    points.append(SwingPoint(index: i, price: l, type: .low))
                }
            } else if trend == -1 { // Downtrend looking for Low
                if l < lastLow {
                    lastLow = l
                    // Update last point if it was a low
                    if let last = points.last, last.type == .low {
                        points.removeLast()
                    }
                    points.append(SwingPoint(index: i, price: l, type: .low))
                } else if h > lastLow * (1 + deviation/100.0) {
                    // Reversal
                    trend = 1
                    lastHigh = h
                    points.append(SwingPoint(index: i, price: h, type: .high))
                }
            }
        }
        
        return points
    }
    
    // MARK: - Logic
    
    private func determineTrend(points: [SwingPoint]) -> TrendState {
        // Look at last 4 points ideally
        guard points.count >= 4 else { return .range }

        // Sequence: Low(p4) -> High(p3) -> Low(p2) -> High(p1) OR High(p4)->Low(p3)->High(p2)->Low(p1)

        let recentHighs = Array(points.filter { $0.type == .high }.suffix(2))
        let recentLows = Array(points.filter { $0.type == .low }.suffix(2))

        // Güvenli erişim kontrolü
        guard recentHighs.count >= 2, recentLows.count >= 2,
              let h1Point = recentHighs.last,
              let h2Point = recentHighs.dropLast().last,
              let l1Point = recentLows.last,
              let l2Point = recentLows.dropLast().last else {
            return .range
        }

        let h1 = h1Point.price
        let h2 = h2Point.price
        let l1 = l1Point.price
        let l2 = l2Point.price
        
        if h1 > h2 && l1 > l2 { return .uptrend }
        if h1 < h2 && l1 < l2 { return .downtrend }
        
        return .range
    }
    
    private func calculateFibonacciLevels(currentPrice: Double, points: [SwingPoint], trend: TrendState) -> (levels: [Double], high: Double, low: Double, anchorLow: Double, anchorHigh: Double) {
        // Find the "Anchor" swing points for the current move.
        // Usually the last significant High and Low.
        
        // For Retracements:
        // Ideally we want the range of the current "correction".
        // If Uptrend: We are looking for support. Anchor is previous Low to Peak High.
        // If Downtrend: Anchor is previous High to Peak Low.
        
        var anchorHigh = 0.0
        var anchorLow = 0.0
        
        // Simple Logic: Take the global Min/Max of the last N points?
        // Or better: The last fulfilled swing leg.

        let relevantPoints = points.suffix(3) // Last 3 swings
        guard !relevantPoints.isEmpty,
              let maxPoint = relevantPoints.max(by: { $0.price < $1.price }),
              let minPoint = relevantPoints.min(by: { $0.price < $1.price }) else {
            return ([], 0, 0, 0, 0)
        }
        
        anchorHigh = maxPoint.price
        anchorLow = minPoint.price
        
        var levels: [Double] = []
        let diff = anchorHigh - anchorLow
        
        // Standard Retracements
        // 0.236, 0.382, 0.5, 0.618 (Golden), 0.786
        // Drawn from Low to High implies levels are relative to High going down?
        // Price = High - (Diff * Ratio)
        
        let ratios = [0.236, 0.382, 0.5, 0.618, 0.786]
        
        // We always calculate levels 'inside' the range.
        // If price is correcting FROM High TO Low
        
        for r in ratios {
            let level = anchorHigh - (diff * r) // Retracement from top
            levels.append(level)
        }
        
        return (levels, anchorHigh, anchorLow, anchorLow, anchorHigh)
    }
    
    private func scorePosition(price: Double, fibResult: (levels: [Double], high: Double, low: Double, anchorLow: Double, anchorHigh: Double), trend: TrendState) -> (score: Double, description: String, zone: StructureZone?) {
        
        // Base Score
        var score = 50.0
        var desc = "Yapı Nötr"
        var activeZone: StructureZone? = nil
        
        let fibLevels = fibResult.levels
        let ratios = [0.236, 0.382, 0.5, 0.618, 0.786]
        
        // Check proximity to Fib Levels
        for (i, level) in fibLevels.enumerated() {
            let ratio = ratios[i]
            let threshold = level * 0.01 // 1% tolerance
            
            if abs(price - level) < threshold {
                // HIT!
                let isGoldenPosition = (ratio == 0.618 || ratio == 0.5)
                activeZone = .fibonacci(level: level, ratio: ratio)
                
                if trend == .uptrend {
                    // Pullback to Support in Uptrend -> BULLISH
                    if isGoldenPosition {
                        score += 35.0 // HUGE BOOST
                        desc = "Golden Pocket (0.618) Desteği - Mükemmel Alım Bölgesi"
                    } else {
                        score += 15.0
                        desc = "Fibonacci (\(ratio)) Desteği"
                    }
                } else if trend == .downtrend {
                    // Pullback to Resistance in Downtrend -> BEARISH (Short opportunity, or low score for Long)
                    // If we function is "Long Score", then this is bad.
                    if isGoldenPosition {
                        score -= 20.0
                        desc = "Düşüş Trendinde Direnç (0.618) - Satış Bölgesi"
                    } else {
                        score -= 10.0
                        desc = "Fibonacci Direnci (\(ratio))"
                    }
                }
                break // Found closest
            }
        }
        
        // Trend Bonus
        if trend == .uptrend {
            score += 10.0
            if activeZone == nil { desc += ", Yükseliş Trendi (Destek Aranıyor)" }
        } else if trend == .downtrend {
            score -= 10.0
            if activeZone == nil { desc += ", Düşüş Trendi" }
        }
        
        // Cap
        return (min(100.0, max(0.0, score)), desc, activeZone)
    }
}
