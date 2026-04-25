import Foundation

/// Athena Factor Engine (Smart Beta)
/// Reuses data from Atlas (Fundamentals) and Orion (Price History)
/// to generate factor-based scores (Value, Quality, Momentum, Size, Risk).
final class AthenaFactorService {
    static let shared = AthenaFactorService()
    
    private init() {}
    
    /// Calculate all factor scores for a given symbol
    /// - Note: Uses AthenaInferenceEngine for final scoring
    func calculateFactors(
        symbol: String,
        financials: FinancialsData?,
        atlasResult: FundamentalScoreResult?,
        candles: [Candle],
        orionScore: OrionScoreResult? = nil
    ) -> AthenaFactorResult {
        
        // 1. Extract Features (Rule-Based Feature Engineering)
        let valueScore = calculateValueFactor(financials: financials)
        let qualityScore = calculateQualityFactor(atlasResult: atlasResult)
        let momentumScore = calculateMomentumFactor(orionScore: orionScore, candles: candles)
        let sizeScore = calculateSizeFactor(marketCap: financials?.marketCap)
        let riskScore = calculateRiskFactor(financials: financials, candles: candles)
        
        // 2. Create Feature Vector
        let features = AthenaFeatureVector(
            valueScore: valueScore,
            qualityScore: qualityScore,
            momentumScore: momentumScore,
            sizeScore: sizeScore,
            riskScore: riskScore
        )
        
        // 3. AI Inference (Predict)
        let prediction = AthenaInferenceEngine.shared.predict(features: features)
        
        // 4. Generate Human-Readable Label (Explainability)
        let styleLabel = generateStyleLabel(features: features, prediction: prediction)
        
        return AthenaFactorResult(
            symbol: symbol,
            date: Date(),
            valueFactorScore: valueScore,
            qualityFactorScore: qualityScore,
            momentumFactorScore: momentumScore,
            sizeFactorScore: sizeScore,
            riskFactorScore: riskScore,
            factorScore: prediction.predictedScore, // AI Output
            styleLabel: styleLabel
        )
    }
    
    // MARK: - 1. Value Factor
    private func calculateValueFactor(financials: FinancialsData?) -> Double {
        guard let fin = financials else { return 50.0 }
        
        var scores: [Double] = []
        
        // A. P/E Ratio
        if let pe = fin.peRatio ?? fin.forwardPERatio {
            // Lower is Better
            if pe <= 0 { scores.append(20.0) } // Loss making or error
            else if pe < 10 { scores.append(95.0) }
            else if pe < 20 { scores.append(80.0) }
            else if pe < 40 { scores.append(50.0) }
            else { scores.append(20.0) }
        }
        
        // B. P/B Ratio
        if let pb = fin.priceToBook {
            // Lower is Better
            if pb < 1.0 { scores.append(90.0) }
            else if pb < 3.0 { scores.append(70.0) }
            else if pb < 6.0 { scores.append(40.0) }
            else { scores.append(20.0) }
        }
        
        // C. FCF Yield (Need Market Cap)
        if let mcap = fin.marketCap, mcap > 0,
           let ocf = fin.operatingCashflow {
            
            let capEx = abs(fin.capitalExpenditures ?? 0.0)
            let fcf = ocf - capEx
            let yield = (fcf / mcap) * 100.0
            
            // Higher is Better
            if yield > 8.0 { scores.append(95.0) }
            else if yield > 4.0 { scores.append(80.0) }
            else if yield > 0.0 { scores.append(60.0) }
            else { scores.append(30.0) }
        }
        
        if scores.isEmpty { return 50.0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    // MARK: - 2. Quality Factor
    private func calculateQualityFactor(atlasResult: FundamentalScoreResult?) -> Double {
        guard let atlas = atlasResult else { return 50.0 }
        
        // Use Atlas sub-scores if available, otherwise fallback to total totalScore
        let prof = atlas.profitabilityScore ?? atlas.totalScore
        let cash = atlas.cashQualityScore ?? atlas.totalScore
        let lev = atlas.leverageScore ?? atlas.totalScore // Higher leverage score usually means "Better" (less risk) in Atlas? need to verify.
        // Assuming Atlas scores are always "Higher is Better".
        
        return (prof * 0.50) + (cash * 0.30) + (lev * 0.20)
    }
    
    // MARK: - 3. Momentum Factor (Delegated to Orion to avoid double counting)
    private func calculateMomentumFactor(orionScore: OrionScoreResult?, candles: [Candle]) -> Double {
        // PRIORITY 1: Use Orion's momentum component if available
        if let orion = orionScore {
            // Orion momentum is max 25 points, normalize to 0-100
            let normalizedMomentum = (orion.components.momentum / 25.0) * 100.0
            return min(100.0, max(0.0, normalizedMomentum))
        }
        
        // FALLBACK: Calculate independently if Orion not available
        guard candles.count > 20 else { return 50.0 }
        
        let sorted = candles.sorted { $0.date < $1.date }
        let currentPrice = sorted.last?.close ?? 0.0
        
        func getReturn(months: Int) -> Double? {
            let lookback = months * 21
            guard sorted.count > lookback else { return nil }
            let pastPrice = sorted[sorted.count - 1 - lookback].close
            return (currentPrice - pastPrice) / pastPrice
        }
        
        // Jegadeesh-Titman Style: 12-1 Momentum (skip last month)
        let r12 = getReturn(months: 12)
        let r1 = getReturn(months: 1)
        
        var score = 50.0
        
        if let yr = r12, let mo = r1 {
            let momentum12_1 = yr - mo // 12 month return minus last month
            if momentum12_1 > 0.30 { score = 90.0 }
            else if momentum12_1 > 0.15 { score = 75.0 }
            else if momentum12_1 > 0.0 { score = 60.0 }
            else if momentum12_1 > -0.15 { score = 40.0 }
            else { score = 25.0 }
        }
        
        return score
    }
    
    // MARK: - 4. Size Factor (NEW - Fama-French SMB)
    private func calculateSizeFactor(marketCap: Double?) -> Double {
        guard let cap = marketCap else { return 50.0 }
        
        // Fama-French SMB: Historically small caps outperform
        // But higher risk, so we balance
        // Sweet spot: Mid-cap (good alpha potential, reasonable risk)
        
        switch cap {
        case 200_000_000_000...:  // > $200B Mega Cap
            return 35.0  // Low alpha expectation (too efficient)
        case 50_000_000_000..<200_000_000_000:  // $50B-$200B Large Cap
            return 50.0
        case 10_000_000_000..<50_000_000_000:  // $10B-$50B Large-Mid
            return 65.0
        case 2_000_000_000..<10_000_000_000:  // $2B-$10B Mid Cap (Sweet Spot)
            return 80.0
        case 300_000_000..<2_000_000_000:  // $300M-$2B Small Cap
            return 75.0  // Good potential but higher risk
        default:  // < $300M Micro Cap
            return 60.0  // High alpha but very risky
        }
    }
    
    // MARK: - 5. Risk Factor (Volatility + Liquidity only - Size moved to separate factor)
    private func calculateRiskFactor(financials: FinancialsData?, candles: [Candle]) -> Double {
        var scores: [Double] = []
        
        // A. Volatility (ATR)
        // Lower Volatility -> Higher Score (for "Low Vol" factor)
        if !candles.isEmpty {
            let atr = OrionAnalysisService.shared.calculateATR(candles: candles, period: 14)
            let price = candles.last?.close ?? 1.0
            let atrPct = (atr / price) * 100.0
            
            if atrPct < 1.5 { scores.append(95.0) }
            else if atrPct < 2.5 { scores.append(80.0) }
            else if atrPct < 4.0 { scores.append(50.0) }
            else { scores.append(20.0) } // Highly volatile
        }
        
        // C. Liquidity (Avg Dollar Volume)
         if candles.count > 5 {
             let last5 = candles.suffix(5)
             let avgVol = last5.map(\.volume).reduce(0, +) / Double(last5.count)
             let price = candles.last?.close ?? 1.0
             let dollarVol = avgVol * price
             
             if dollarVol > 50_000_000 { scores.append(100.0) }
             else if dollarVol > 10_000_000 { scores.append(80.0) }
             else if dollarVol > 1_000_000 { scores.append(50.0) }
             else { scores.append(20.0) }
         }
        
        if scores.isEmpty { return 50.0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    // MARK: - Label Generation
    private func generateStyleLabel(features: AthenaFeatureVector, prediction: AthenaPrediction) -> String {
        func getWord(score: Double, low: String, mid: String, high: String) -> String {
            if score >= 70 { return high }
            else if score >= 40 { return mid }
            else { return low }
        }
        
        let vWord = getWord(score: features.valueScore, low: "Pahalı", mid: "Makul", high: "Ucuz")
        let qWord = getWord(score: features.qualityScore, low: "Spekülatif", mid: "Solid", high: "Kaliteli")
        let sWord = features.sizeScore >= 70 ? "Mid-Cap" : (features.sizeScore >= 50 ? "Large-Cap" : "Mega-Cap")
        
        // Add Dominant Factor info
        return "Athena (\(prediction.dominantFactor)): \(vWord) \(qWord) \(sWord)"
    }
}
