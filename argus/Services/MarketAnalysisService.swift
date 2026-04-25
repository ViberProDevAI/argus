import Foundation

// MARK: - Models

struct MarketAnalysisReport: Codable {
    let timestamp: Date
    // Strategy-Based Categories
    let trendOpportunities: [AnalysisSignal] // Best for MACD/SMA
    let reversalOpportunities: [AnalysisSignal] // Best for RSI/Bollinger
    let breakoutOpportunities: [AnalysisSignal] // High Volume / Volatility
}

struct AnalysisSignal: Codable, Identifiable {
    var id: UUID { UUID() }
    let symbol: String
    let score: Double
    let timeHorizon: String
    let reason: String
    let keyFactors: [String]
}

class MarketAnalysisService {
    static let shared = MarketAnalysisService()
    private init() {}
    
    func generateReport(quotes: [String: Quote], candles: [String: [Candle]], signals: [String: [Signal]]) -> MarketAnalysisReport {
        var trends: [AnalysisSignal] = []
        var reversals: [AnalysisSignal] = []
        var breakouts: [AnalysisSignal] = []
        
        for (symbol, quote) in quotes {
            guard let symbolCandles = candles[symbol], !symbolCandles.isEmpty else { continue }
            
            // 1. Detect Regime
            let regime = AnalysisService.shared.detectMarketRegime(candles: symbolCandles)
            let score = AnalysisService.shared.calculateCompositeScore(candles: symbolCandles).totalScore
            
            // 2. Filter & Match Strategy
            let signalList = signals[symbol] ?? []
            let reason = generateReason(symbol: symbol, score: score, quote: quote, signals: signalList)
            let factors = generateKeyFactors(symbol: symbol, score: score, quote: quote, signals: signalList)
            
            let analysisSignal = AnalysisSignal(
                symbol: symbol,
                score: abs(score),
                timeHorizon: "Kısa Vade",
                reason: reason,
                keyFactors: factors
            )
            
            // 3. Categorize based on Regime & Score
            switch regime {
            case .trending:
                // If trending strongly, it's a Trend Opportunity
                if abs(score) > 50 {
                    trends.append(analysisSignal)
                }
            case .ranging:
                // If ranging but has high score (oversold/overbought), it's a Reversal Opportunity
                if abs(score) > 50 {
                    reversals.append(analysisSignal)
                }
            case .unknown:
                break
            }
            
            // Check for Breakout (High Volume + Price Move)
            // Real Logic: Today's Volume > 1.5x Avg(20) Volume AND Price Move > 3%
            let recentVolumes = symbolCandles.suffix(20).map { $0.volume }
            let avgVol = recentVolumes.reduce(0, +) / Double(max(1, recentVolumes.count))
            let lastVol = symbolCandles.last?.volume ?? 0
            
            if lastVol > (avgVol * 1.5) && abs(quote.percentChange) > 3.0 {
                breakouts.append(analysisSignal)
            }
        }
        
        // Sort
        trends.sort { $0.score > $1.score }
        reversals.sort { $0.score > $1.score }
        breakouts.sort { $0.score > $1.score }
        
        return MarketAnalysisReport(
            timestamp: Date(),
            trendOpportunities: Array(trends.prefix(5)),
            reversalOpportunities: Array(reversals.prefix(5)),
            breakoutOpportunities: Array(breakouts.prefix(5))
        )
    }
    
    // ... (Helper Logic remains similar)
    
    private func generateReason(symbol: String, score: Double, quote: Quote, signals: [Signal]) -> String {
        // Mimic AI reasoning by combining factors
        var reason = ""
        
        if score >= 80 {
            reason = "Güçlü yükseliş trendi ve pozitif momentum. "
        } else if score <= -80 {
            reason = "Güçlü düşüş trendi ve negatif momentum. "
        } else if score >= 60 {
            reason = "Yükseliş potansiyeli var ancak teyit bekliyor. "
        } else if score <= -60 {
            reason = "Zayıf görünüm sürüyor, satış baskısı hakim. "
        } else {
            reason = "Yatay seyir, belirgin bir trend yok. "
        }
        
        // Add specific indicator context
        if let rsiSignal = signals.first(where: { $0.strategyName.contains("RSI") }) {
            if rsiSignal.action == .buy { reason += "RSI aşırı satım bölgesinden tepki veriyor. " }
            if rsiSignal.action == .sell { reason += "RSI aşırı alım bölgesinde, düzeltme riski. " }
        }
        
        return reason
    }
    
    private func generateKeyFactors(symbol: String, score: Double, quote: Quote, signals: [Signal]) -> [String] {
        var factors: [String] = []
        
        // Price Change
        if quote.percentChange > 2.0 { factors.append("Günlük artış > %2") }
        else if quote.percentChange < -2.0 { factors.append("Günlük düşüş > %2") }
        
        // Signals
        for signal in signals {
            if signal.action != .hold {
                // Simplify strategy names for factors
                let name = signal.strategyName.components(separatedBy: " ").first ?? signal.strategyName
                factors.append("\(name): \(signal.action.rawValue)")
            }
        }
        
        return factors
    }
}
