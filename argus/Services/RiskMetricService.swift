import Foundation

class RiskMetricService {
    static let shared = RiskMetricService()
    
    private init() {}
    
    /// Calculates a 0-100 risk score based on the volatility of daily returns.
    /// - Parameter candles: Array of daily candles (sorted by date ascending or descending, handled internally).
    /// - Returns: A score between 0 (Low Risk) and 100 (High Risk), or nil if insufficient data.
    func calculateVolatilityScore(candles: [Candle]) -> Double? {
        // Need at least 30 days of data to calculate meaningful volatility
        guard candles.count >= 30 else { return nil }
        
        // Ensure candles are sorted by date ascending
        let sortedCandles = candles.sorted { $0.date < $1.date }
        
        // Calculate daily returns
        var returns: [Double] = []
        for i in 1..<sortedCandles.count {
            let prevClose = sortedCandles[i-1].close
            let currentClose = sortedCandles[i].close
            
            if prevClose > 0 {
                let dailyReturn = (currentClose - prevClose) / prevClose
                returns.append(dailyReturn)
            }
        }
        
        guard !returns.isEmpty else { return nil }
        
        // Calculate Standard Deviation (Volatility)
        let mean = returns.reduce(0, +) / Double(returns.count)
        let sumSquaredDiffs = returns.reduce(0) { $0 + pow($1 - mean, 2) }
        let variance = sumSquaredDiffs / Double(returns.count)
        let standardDeviation = sqrt(variance)
        
        // Map Standard Deviation to 0-100 Score
        // Rules:
        // Vol < 2% (0.02) -> Low Risk (~20)
        // Vol ~ 3% (0.03) -> Medium Risk (~50)
        // Vol > 4% (0.04) -> High Risk (~80+)
        
        // Linear mapping approach:
        // 0.00 -> 0
        // 0.02 -> 30
        // 0.04 -> 70
        // 0.06 -> 100
        
        let volatility = standardDeviation
        var score: Double = 0.0
        
        if volatility <= 0.02 {
            // 0.00 - 0.02 maps to 0 - 30
            score = (volatility / 0.02) * 30.0
        } else if volatility <= 0.04 {
            // 0.02 - 0.04 maps to 30 - 70
            score = 30.0 + ((volatility - 0.02) / 0.02) * 40.0
        } else {
            // 0.04+ maps to 70 - 100 (capped at 100)
            score = 70.0 + ((volatility - 0.04) / 0.02) * 30.0
        }
        
        return min(max(score, 0), 100)
    }
    
    /// Returns a text description for the risk score.
    func getRiskLabel(score: Double) -> String {
        switch score {
        case 0..<35: return "Düşük Volatilite"
        case 35..<70: return "Orta Volatilite"
        default: return "Yüksek Volatilite"
        }
    }
}
