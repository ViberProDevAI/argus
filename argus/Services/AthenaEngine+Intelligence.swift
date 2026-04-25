import Foundation

/// Extension to AthenaFactorService for "Smart Money" Scoring
extension AthenaFactorService {
    
    /// Calculate the "Smart Money" score based on Analyst and Insider data.
    /// - Parameters:
    ///   - snapshot: The intelligence data.
    ///   - currentPrice: Current market price of the asset.
    ///   - isETF: Guard to ensure we don't score ETFs.
    /// - Returns: A partial score (e.g. +10, -10, +15) to be added to the total Athena score.
    func calculateSmartMoneyScore(snapshot: MarketIntelligenceSnapshot?, currentPrice: Double, isETF: Bool) -> Double {
        // 1. ETF/Fund Guard
        // Insiders don't trade ETFs like corporate stocks. Analysts don't set price targets for ETFs usually.
        if isETF { return 0.0 }
        
        guard let data = snapshot else { return 0.0 }
        
        var smartScore = 0.0
        
        // 2. Analyst Score (Wall St)
        if let target = data.targetMeanPrice, currentPrice > 0 {
            let upside = (target - currentPrice) / currentPrice
            
            if upside > 0.20 { // > +20% Upside
                smartScore += 10.0
            } else if upside < -0.10 { // < -10% Downside
                smartScore -= 10.0
            }
        }
        
        // 3. Insider Score (Corporate)
        // We only care about positive buying signals.
        // Selling is noisy (taxes, buying a house, diversification). Buying is pure signal.
        if data.netInsiderBuySentiment > 0 {
            smartScore += 15.0
        }
        
        return smartScore
    }
}
