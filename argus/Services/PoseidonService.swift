actor PoseidonService {
    static let shared = PoseidonService()
    
    private init() {}
    
    /// Generates a complete Whale Score based on VOLUME ANALYSIS (Real Data).
    /// Detects Accumulation, Distribution, and Volume Anomalies.
    func analyzeSmartMoney(symbol: String, candles: [Candle]) async -> WhaleScore {
        guard candles.count >= 20 else {
            return WhaleScore(symbol: symbol, totalScore: 50, insiderScore: 50, institutionalScore: 50, darkPoolScore: 50, summary: "Yetersiz Veri")
        }
        
        let rsi = await MainActor.run {
             AnalysisService.shared.calculateRSIValue(candles: candles)
        }
        
        // 1. Volume Analysis
        let volAnalysis = analyzeVolumeProfile(candles: candles) // (Spike, Accumulation)
        
        // 2. Score Components
        var darkPoolScore = 50.0
        if volAnalysis.isSpiking { darkPoolScore = 80.0 } // Volume Spike suggests big players
        
        var instScore = 50.0
        if volAnalysis.isAccumulation { instScore = 85.0 } // Stealth accumulation
        else if volAnalysis.isDistribution { instScore = 20.0 } // Dumping
        
        // 3. Technical Context for "Smart Money"
        // Smart money buys fear (Low RSI accumulation) and sells greed (High RSI distribution)
        var smartMoneyContext = 50.0
        if rsi < 40 && volAnalysis.isAccumulation { smartMoneyContext = 90.0 } // Perfect Buy
        else if rsi > 70 && volAnalysis.isDistribution { smartMoneyContext = 10.0 } // Perfect Sell
        
        // 4. Composite
        let total = (instScore * 0.4) + (darkPoolScore * 0.3) + (smartMoneyContext * 0.3)
        
        // 5. Summary
        let summary = generateSummary(vol: volAnalysis, rsi: rsi)
        
        // We return empty list for insiders to avoid Fake Data
        return WhaleScore(
            symbol: symbol,
            totalScore: total,
            insiderScore: smartMoneyContext, // Mapping SmartContext to "Insider" slot for UI compatibility
            institutionalScore: instScore,
            darkPoolScore: darkPoolScore,
            summary: summary
        )
    }
    
    private struct VolumeProfile {
        let isSpiking: Bool
        let isAccumulation: Bool
        let isDistribution: Bool
        let avgVol: Double
        let lastVol: Double
    }
    
    private func analyzeVolumeProfile(candles: [Candle]) -> VolumeProfile {
        let sorted = candles.suffix(21) // 20 avg + 1 current
        guard sorted.count > 1 else { return VolumeProfile(isSpiking: false, isAccumulation: false, isDistribution: false, avgVol: 0, lastVol: 0) }
        
        let last = sorted.last!
        let window = sorted.dropLast()
        
        let avgVol = window.map { Double($0.volume) }.reduce(0, +) / Double(window.count)
        let lastVol = Double(last.volume)
        
        // 1. Spike Check
        let isSpiking = lastVol > (avgVol * 2.0)
        
        // 2. Price Action Analysis
        let open = last.open
        let close = last.close
        let high = last.high
        let low = last.low
        
        let bodySize = abs(close - open)
        let totalRange = high - low
        let isSmallBody = bodySize < (totalRange * 0.3) // Doji-like
        
        // Accumulation: High Volume + Small Body (Price held up) OR High Vol + Green Body at Lows
        let isAccumulation = isSpiking && (isSmallBody || close > open)
        
        // Distribution: High Volume + Small Body (Price capped) OR High Vol + Red Body at Highs
        let isDistribution = isSpiking && (isSmallBody || close < open)
        // Refinement: Ideally check trend location (Accu at lows, Dist at highs). Assumed generic for now.
        
        return VolumeProfile(
            isSpiking: isSpiking,
            isAccumulation: isAccumulation,
            isDistribution: isDistribution,
            avgVol: avgVol,
            lastVol: lastVol
        )
    }
    
    private func generateSummary(vol: VolumeProfile, rsi: Double) -> String {
        if vol.isSpiking {
            if vol.isAccumulation {
                return "Yüksek hacimli toplama (Accumulation) tespit edildi."
            } else if vol.isDistribution {
                 return "Yüksek hacimli dağıtım (Distribution) riski."
            }
            return "Anormal hacim artışı (% \(Int((vol.lastVol/vol.avgVol)*100)))."
        }
        
        if rsi < 35 { return "Hacimsiz düşüş, satış baskısı azalıyor olabilir." }
        return "Balina aktivitesi normal seviyede."
    }
}
