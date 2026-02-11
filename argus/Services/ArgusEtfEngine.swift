import Foundation

/// Titan Lite Engine: Pure Technical & Macro Analysis for Non-Equity Assets
/// Ignores messy fundamentals/holdings data to ensure robustness.
class ArgusEtfEngine: Sendable {
    static let shared = ArgusEtfEngine()
    
    struct TitanResult: Sendable {
        let score: Double // 0-100
        let log: TitanSignalLog
    }
    
    // Config
    private let techWeight = 0.70
    private let macroWeight = 0.30
    
    func analyze(symbol: String, quotes: [Candle], macro: MacroEnvironmentRating?, profile: ETFProfile?) -> TitanResult {
        // 1. Data Validation
        guard !quotes.isEmpty else {
            return TitanResult(score: 0, log: TitanSignalLog(
                date: Date(),
                symbol: symbol,
                totalScore: 0,
                techScore: 0,
                macroScore: 0,
                qualityScore: 0,
                technicalContext: "Veri Yok",
                macroContext: "Veri Yok",
                qualityContext: "Veri Yok"
            ))
        }
        
        // 2. Technical Analysis (70%)
        let techAnalysis = analyzeTechnicals(quotes: quotes)
        let techScore = techAnalysis.score
        
        // 3. Macro Analysis (30%)
        let macroScoreValue = calculateMacroScore(macro: macro)
        
        // 4. Quality/Profile (0% -- Just Context)
        // We do not score quality to avoid reliance on broken APIs, but we log context.
        let qualityScoreValue = 50.0
        let costContext = (profile?.expenseRatio != nil) ? String(format: "%.2f%%", profile!.expenseRatio!) : "N/A"
        let qualityContext = "Titan Lite (Cost: \(costContext))"
        
        // 5. Total Score
        let totalScore = (techScore * techWeight) + (macroScoreValue * macroWeight)
        
        // 6. Log
        let log = TitanSignalLog(
            date: Date(),
            symbol: symbol,
            totalScore: totalScore,
            techScore: techScore,
            macroScore: macroScoreValue,
            qualityScore: qualityScoreValue,
            technicalContext: techAnalysis.context,
            macroContext: macro?.regime.rawValue ?? "Bilinmiyor",
            qualityContext: qualityContext
        )
        
        return TitanResult(score: totalScore, log: log)
    }
    
    // MARK: - Compatibility Layer (TradingViewModel)
    
    func analyzeETF(
        symbol: String,
        currentPrice: Double,
        orionScore: Double?,
        hermesScore: Double?,
        holdingScoreProvider: ((String) -> (Double?, Double?))?
    ) async -> ArgusEtfSummary {
        
        // In "Lite" mode, we don't analyze holdings.
        // We use Orion Score (Technical) directly as the main driver if available,
        // or default to Neutral (50) if missing.
        
        let techScore = orionScore ?? 50.0
        
        // Map Score to Letter Grade
        let grade: String
        switch techScore {
        case 90...100: grade = "A+"
        case 80..<90: grade = "A"
        case 70..<80: grade = "B"
        case 60..<70: grade = "C"
        case 40..<60: grade = "Nötr"
        default: grade = "Zayıf"
        }
        
        return ArgusEtfSummary(
            symbol: symbol,
            lastPrice: currentPrice,
            currency: "USD", // Default
            strategyType: .standard,
            leverageAmount: nil,
            weightedAtlasScore: techScore, // Proxy: Use Technical Score as "Atlas" for Lite
            weightedHermesScore: hermesScore,
            orionScore: techScore,
            orionLetterGrade: grade,
            riskProfile: "Standart",
            topSectors: [],
            topHoldingsPreview: [],
            summaryText: "Titan Lite Analizi: Bu ETF için temel analiz verileri (Hisse Dağılımı) kullanılmadı. Sadece teknik ve genel Orion skoru baz alındı."
        )
    }
    
    // MARK: - Helpers
    
    private struct TechAnalysis {
        let score: Double
        let context: String
    }
    
    private func analyzeTechnicals(quotes: [Candle]) -> TechAnalysis {
        guard quotes.count > 50 else {
            return TechAnalysis(score: 50, context: "Yetersiz Veri")
        }
        
        let prices = quotes.map { $0.close }
        let current = prices.last!
        
        // SMA Calculation (Simple)
        let sma50 = prices.suffix(50).reduce(0, +) / 50.0
        // SMA200 requires more data
        let sma200 = quotes.count >= 200 ? prices.suffix(200).reduce(0, +) / 200.0 : sma50
        
        // RSI (Simplistic 14-period approximation or reuse library if available)
        // For Titan Lite, we'll use simple Trend Strength
        
        var score = 50.0
        var reasons: [String] = []
        
        // Trend
        if current > sma50 {
            score += 20
            if sma50 > sma200 {
                score += 10
                reasons.append("Güçlü Trend")
            } else {
                reasons.append("Yükseliş")
            }
        } else {
            score -= 20
            reasons.append("Düşüş")
        }
        
        // Momentum (Recent 10 days)
        let momentum = (current - prices[max(0, prices.count - 10)]) / prices[max(0, prices.count - 10)]
        if momentum > 0.05 {
            score += 10
            reasons.append("Momentum (+)")
        } else if momentum < -0.05 {
            score -= 10
            reasons.append("Momentum (-)")
        }
        
        // Clamp
        score = min(max(score, 0), 100)
        
        return TechAnalysis(score: score, context: reasons.joined(separator: ", "))
    }
    
    private func calculateMacroScore(macro: MacroEnvironmentRating?) -> Double {
        guard let m = macro else { return 50.0 }
        
        // If Risk On -> Bullish for most equities, but this is generic
        // Titan normally customizes per asset class, but for Lite we use global sentiment
        switch m.regime {
        case .riskOn:
            return 80.0
        case .neutral:
            return 50.0
        case .riskOff:
            return 30.0
        }
    }
}
