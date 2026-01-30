import Foundation

// MARK: - Orion V3 Pattern Engine Model

enum OrionChartPatternType: String, Codable {
    case doubleTop = "Double Top (İkili Tepe)"
    case doubleBottom = "Double Bottom (İkili Dip)"
    case headAndShoulders = "Head & Shoulders (OBO)"
    case inverseHeadAndShoulders = "Inv. Head & Shoulders (TOBO)"
    case bullFlag = "Bull Flag (Boğa Bayrağı)"
    case bearFlag = "Bear Flag (Ayı Bayrağı)"
    case none = "Formasyon Yok"
    
    var isBullish: Bool {
        switch self {
        case .doubleBottom, .inverseHeadAndShoulders, .bullFlag: return true
        default: return false
        }
    }
    
    var isBearish: Bool {
        switch self {
        case .doubleTop, .headAndShoulders, .bearFlag: return true
        default: return false
        }
    }
    
    var icon: String {
        switch self {
        case .doubleTop: return "m.square"
        case .doubleBottom: return "w.square"
        case .headAndShoulders: return "person.3.sequence.fill"
        case .inverseHeadAndShoulders: return "person.3.sequence"
        case .bullFlag: return "flag.fill"
        case .bearFlag: return "flag.slash.fill"
        case .none: return "minus"
        }
    }
}

struct OrionChartPattern: Identifiable, Codable {
    let id: UUID
    let type: OrionChartPatternType
    let confidence: Double // 0-100
    let targetPrice: Double?
    let detectedAt: Date
    let description: String
    
    // Explicit init to support default UUID
    init(id: UUID = UUID(), type: OrionChartPatternType, confidence: Double, targetPrice: Double?, detectedAt: Date, description: String) {
        self.id = id
        self.type = type
        self.confidence = confidence
        self.targetPrice = targetPrice
        self.detectedAt = detectedAt
        self.description = description
    }
}

// MARK: - Engine

final class OrionPatternEngine {
    static let shared = OrionPatternEngine()
    
    private init() {}
    
    // ZigZag Point Structure
    private struct SwingPoint {
        let index: Int
        let price: Double
        let isHigh: Bool
    }
    
    /// Detects chart patterns from candle data
    /// - Parameter candles: Array of historical candles (min 50 recommended)
    func detectPatterns(candles: [Candle]) -> [OrionChartPattern] {
        guard candles.count >= 30 else { return [] }
        
        // 1. Calculate ZigZag Swing Points
        let swings = calculateZigZag(candles: candles, deviation: 2.0)
        
        var detectedPatterns: [OrionChartPattern] = []
        
        // 2. Scan for Double Top/Bottom
        if let dt = checkDoubleTop(swings: swings, candles: candles) {
            detectedPatterns.append(dt)
        }
        
        if let db = checkDoubleBottom(swings: swings, candles: candles) {
            detectedPatterns.append(db)
        }
        
        // 3. Scan for Head & Shoulders
        if let hns = checkHeadAndShoulders(swings: swings, candles: candles) {
            detectedPatterns.append(hns)
        }
        
        return detectedPatterns
    }
    
    // MARK: - ZigZag Algorithm
    
    private func calculateZigZag(candles: [Candle], deviation: Double) -> [SwingPoint] {
        guard let firstCandle = candles.first else { return [] }

        var swings: [SwingPoint] = []
        var trend = 0 // 1 = up, -1 = down
        var lastHigh = firstCandle.high
        var lastLow = firstCandle.low
        var lastHighIndex = 0
        var lastLowIndex = 0
        
        for i in 1..<candles.count {
            let close = candles[i].close
            let high = candles[i].high
            let low = candles[i].low
            
            if trend == 0 {
                if high > lastHigh * (1 + deviation/100) {
                    trend = 1
                    lastHigh = high
                    lastHighIndex = i
                } else if low < lastLow * (1 - deviation/100) {
                    trend = -1
                    lastLow = low
                    lastLowIndex = i
                }
            } else if trend == 1 { // Uptrend
                if high > lastHigh {
                    lastHigh = high
                    lastHighIndex = i
                } else if low < lastHigh * (1 - deviation/100) {
                    // Reversal -> Add previous High
                    swings.append(SwingPoint(index: lastHighIndex, price: lastHigh, isHigh: true))
                    trend = -1
                    lastLow = low
                    lastLowIndex = i
                }
            } else if trend == -1 { // Downtrend
                if low < lastLow {
                    lastLow = low
                    lastLowIndex = i
                } else if high > lastLow * (1 + deviation/100) {
                    // Reversal -> Add previous Low
                    swings.append(SwingPoint(index: lastLowIndex, price: lastLow, isHigh: false))
                    trend = 1
                    lastHigh = high
                    lastHighIndex = i
                }
            }
        }
        
        // Add pending last point
        if trend == 1 {
            swings.append(SwingPoint(index: lastHighIndex, price: lastHigh, isHigh: true))
        } else if trend == -1 {
            swings.append(SwingPoint(index: lastLowIndex, price: lastLow, isHigh: false))
        }
        
        return swings
    }
    
    // MARK: - Pattern Logic
    
    private func checkDoubleTop(swings: [SwingPoint], candles: [Candle]) -> OrionChartPattern? {
        // Need at least High-Low-High sequence
        let highs = swings.filter { $0.isHigh }
        guard highs.count >= 2,
              let peek2 = highs.last,
              let peek1 = highs.dropLast().last else {
            return nil
        }
        
        // Check if peeks are roughly equal (within 2%)
        let priceDiff = abs(peek1.price - peek2.price)
        let tolerance = peek1.price * 0.02
        
        if priceDiff <= tolerance {
            // Check for a Low between them
            if let valley = swings.first(where: { !$0.isHigh && $0.index > peek1.index && $0.index < peek2.index }) {
                // Calculate target (Neckline projection)
                let height = ((peek1.price + peek2.price) / 2) - valley.price
                let target = valley.price - height
                let current = candles.last?.close ?? 0
                
                // Confirm strictly: CURRENT PRICE must be below neckline for breakout, 
                // OR forming second top (reversal warning)
                
                // Let's create a "Potential" Double Top
                return OrionChartPattern(
                    type: .doubleTop,
                    confidence: 75,
                    targetPrice: target,
                    detectedAt: Date(),
                    description: "İkili Tepe Formasyonu: \(String(format: "%.2f", valley.price)) kırılırsa hedef \(String(format: "%.2f", target))"
                )
            }
        }
        return nil
    }
    
    private func checkDoubleBottom(swings: [SwingPoint], candles: [Candle]) -> OrionChartPattern? {
        let lows = swings.filter { !$0.isHigh }
        guard lows.count >= 2,
              let dip2 = lows.last,
              let dip1 = lows.dropLast().last else {
            return nil
        }
        
        let priceDiff = abs(dip1.price - dip2.price)
        let tolerance = dip1.price * 0.02
        
        if priceDiff <= tolerance {
            if let peak = swings.first(where: { $0.isHigh && $0.index > dip1.index && $0.index < dip2.index }) {
                let height = peak.price - ((dip1.price + dip2.price) / 2)
                let target = peak.price + height
                
                return OrionChartPattern(
                    type: .doubleBottom,
                    confidence: 75,
                    targetPrice: target,
                    detectedAt: Date(),
                    description: "İkili Dip (W) Formasyonu: \(String(format: "%.2f", peak.price)) aşılırsa hedef \(String(format: "%.2f", target))"
                )
            }
        }
        return nil
    }
    
    private func checkHeadAndShoulders(swings: [SwingPoint], candles: [Candle]) -> OrionChartPattern? {
        // H&S requires High(Left) - High(Head) - High(Right) with Head > Shoulders
        let highs = swings.filter { $0.isHigh }
        guard highs.count >= 3 else { return nil }

        // Güvenli erişim
        let highsArray = Array(highs.suffix(3))
        guard highsArray.count == 3 else { return nil }
        let left = highsArray[0]
        let head = highsArray[1]
        let right = highsArray[2]
        
        // Rule 1: Head must be higher than both shoulders
        if head.price > left.price && head.price > right.price {
            // Rule 2: Shoulders roughly equal (optional but nice, use 5% tolerance)
            let shoulderDiff = abs(left.price - right.price)
            if shoulderDiff < head.price * 0.05 {
                // Rule 3: Neckline (Low between Left-Head and Head-Right)
                // Simplified: Average of valleys
                if let valley1 = swings.first(where: { !$0.isHigh && $0.index > left.index && $0.index < head.index }),
                   let valley2 = swings.first(where: { !$0.isHigh && $0.index > head.index && $0.index < right.index }) {
                    
                    let neckline = (valley1.price + valley2.price) / 2
                    let height = head.price - neckline
                    let target = neckline - height
                    
                    return OrionChartPattern(
                        type: .headAndShoulders,
                        confidence: 85,
                        targetPrice: target,
                        detectedAt: Date(),
                        description: "OBO (Omuz Baş Omuz): \(String(format: "%.2f", neckline)) altı kapanışta hedef \(String(format: "%.2f", target))"
                    )
                }
            }
        }
        return nil
    }
}
