import Foundation

/// Analyzes relationships between assets in the Universe.
/// Detects Similar Moves (High +Corr), Inverse Moves (High -Corr), and Lead/Lag effects.
actor CorrelationEngine {
    static let shared = CorrelationEngine()
    
    // Config
    private let minBars = 30
    private let correlationThreshold = 0.70 // Strong correlation
    private let inverseThreshold = -0.70 // Strong inverse
    
    // State
    // Storing calculated matrices or pair insights
    private var insights: [String: [CorrelationInsight]] = [:] // Key = Symbol
    
    struct CorrelationInsight: Codable, Identifiable {
        var id: String { "\(symbolA)_\(symbolB)_\(type.rawValue)" }
        let symbolA: String
        let symbolB: String
        let score: Double // -1.0 to 1.0
        let type: RelationType
        let timestamp: Date
        
        enum RelationType: String, Codable {
            case similar = "Benzer Hareket"
            case inverse = "Ters Hareket"
            case decoupled = "Ayrışma (Decoupling)" // Used to be correlated, now broken
        }
    }
    
    private init() {}
    
    // MARK: - Core Logic
    
    /// Main Entry Point: Analyze the entire Universe (Heavy!)
    /// Recommended to run in background periodically (e.g. hourly or end of session).
    func analyzeUniverse(universe: [String], candles: [String: [Candle]]) async -> [CorrelationInsight] {
        var newInsights: [CorrelationInsight] = []
        let symbols = universe
        
        // n*(n-1)/2 Loop
        for i in 0..<symbols.count {
            for j in (i+1)..<symbols.count {
                let symA = symbols[i]
                let symB = symbols[j]
                
                guard let candlesA = candles[symA], let candlesB = candles[symB] else { continue }
                
                if let insight = analyzePair(symA: symA, candlesA: candlesA, symB: symB, candlesB: candlesB) {
                    newInsights.append(insight)
                }
            }
        }
        
        // Index by Symbol for fast lookup
        var map: [String: [CorrelationInsight]] = [:]
        for ins in newInsights {
            map[ins.symbolA, default: []].append(ins)
            map[ins.symbolB, default: []].append(ins)
        }
        self.insights = map
        
        return newInsights
    }
    
    /// Analyzes a specific pair of assets
    private func analyzePair(symA: String, candlesA: [Candle], symB: String, candlesB: [Candle]) -> CorrelationInsight? {
        // 1. Align Data (Join on Date)
        let returns = alignReturns(candlesA, candlesB)
        
        guard returns.count >= minBars else { return nil }
        
        let (retsA, retsB) = unzip(returns)
        
        // 2. Calculate Pearson Correlation
        let corr = pearsonCorrelation(retsA, retsB)
        
        // 3. Classify
        if corr >= correlationThreshold {
            return CorrelationInsight(symbolA: symA, symbolB: symB, score: corr, type: .similar, timestamp: Date())
        } else if corr <= inverseThreshold {
            return CorrelationInsight(symbolA: symA, symbolB: symB, score: corr, type: .inverse, timestamp: Date())
        }
        
        return nil
    }
    
    // MARK: - Lead/Lag (Advanced)
    // Checks if A today correlates with B tomorrow (A leads B)
    func checkLeadLag(symA: String, candlesA: [Candle], symB: String, candlesB: [Candle]) -> Double {
        // Shift B back by 1 day
        // This effectively compares A[t] with B[t+1]
        // If high, then A predicts B.
        
        // Implementation TODO: Requires strict index alignment shifting.
        // For now, returning 0.0 placeholder.
        return 0.0
    }
    
    // MARK: - Math Helpers
    
    private func alignReturns(_ cA: [Candle], _ cB: [Candle]) -> [(Double, Double)] {
        // Convert to Dictionary for O(1) Lookup
        let mapB = Dictionary(uniqueKeysWithValues: cB.map { ($0.date.timeIntervalSince1970, $0) })
        
        var paired: [(Double, Double)] = []
        
        // Iterate A
        for i in 1..<cA.count {
            let todayA = cA[i]
            let prevA = cA[i-1]
            let dateKey = todayA.date.timeIntervalSince1970
            
            // Check if B has data for THIS day and PREVIOUS day (to calc return)
            // Ideally B should have matching dates. 
            // Simplifying: Just matched date is enough if we pre-calculated returns?
            // Calculating returns on fly:
            if let todayB = mapB[dateKey],
               let prevB = mapB[prevA.date.timeIntervalSince1970] { // Exact match on prev date required?
                
               // Strict alignment: A and B both traded on Day T and Day T-1.
               let retA = (todayA.close - prevA.close) / prevA.close
               let retB = (todayB.close - prevB.close) / prevB.close
               
               paired.append((retA, retB))
            }
        }
        return paired
    }
    
    private func unzip(_ array: [(Double, Double)]) -> ([Double], [Double]) {
        var a: [Double] = []
        var b: [Double] = []
        for (v1, v2) in array {
            a.append(v1)
            b.append(v2)
        }
        return (a, b)
    }
    
    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        if n == 0 { return 0 }
        
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        
        let numerator = (n * sumXY) - (sumX * sumY)
        let denominator = sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)))
        
        if denominator == 0 { return 0 }
        
        return numerator / denominator
    }
    
    // MARK: - Public Access
    func getInsights(for symbol: String) -> [CorrelationInsight] {
        return insights[symbol] ?? []
    }
}
