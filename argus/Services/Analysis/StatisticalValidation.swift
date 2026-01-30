import Foundation

// MARK: - Statistical Validation
/// Provides statistical significance testing for trading strategies.
/// Ensures results are not due to random chance.

@MainActor
final class StatisticalValidation {
    
    // MARK: - Configuration
    
    struct Configuration {
        let confidenceLevel: Double
        let minSampleSize: Int
        let bootstrapIterations: Int
        
        static let `default` = Configuration(
            confidenceLevel: 0.95,
            minSampleSize: 30,
            bootstrapIterations: 10000
        )
    }
    
    // MARK: - Results
    
    struct ValidationResult {
        let isSignificant: Bool
        let pValue: Double
        let confidenceInterval: (lower: Double, upper: Double)
        let sharpeRatio: Double
        let sharpeConfidenceInterval: (lower: Double, upper: Double)
        let maxDrawdownConfidenceInterval: (lower: Double, upper: Double)
        let sortinoRatio: Double
        let calmarRatio: Double
        let informationRatio: Double?
        let skewness: Double
        let kurtosis: Double
        let var95: Double
        let var99: Double
        let expectedShortfall: Double
        let recommendation: Recommendation
        
        enum Recommendation: String {
            case strongBuy = "Güçlü AL"
            case buy = "AL"
            case hold = "BEKLE"
            case sell = "SAT"
            case strongSell = "Güçlü SAT"
            case insufficientData = "Yetersiz Veri"
        }
        
        var summary: String {
            """
            İstatistiksel Validasyon Sonuçları:
            - Anlamlılık: \(isSignificant ? "Evet" : "Hayır") (p = \(String(format: "%.4f", pValue)))
            - Güven Aralığı: [\(String(format: "%.2f", confidenceInterval.lower))%, \(String(format: "%.2f", confidenceInterval.upper))%]
            - Sharpe Oranı: \(String(format: "%.2f", sharpeRatio))
            - Sortino Oranı: \(String(format: "%.2f", sortinoRatio))
            - Calmar Oranı: \(String(format: "%.2f", calmarRatio))
            - VaR (95%): \(String(format: "%.2f", var95))%
            - Öneri: \(recommendation.rawValue)
            """
        }
    }
    
    struct TradeStatistics {
        let returns: [Double]
        let trades: Int
        let winRate: Double
        let avgWin: Double
        let avgLoss: Double
        let profitFactor: Double
        let expectancy: Double
        let consecutiveWins: Int
        let consecutiveLosses: Int
    }
    
    // MARK: - Properties
    
    private let config: Configuration
    
    init(config: Configuration = Configuration.default) {
        self.config = config
    }
    
    // MARK: - Main Validation
    
    func validate(trades: [Trade], benchmarkReturns: [Double]? = nil) -> ValidationResult {
        guard trades.count >= config.minSampleSize else {
            return ValidationResult(
                isSignificant: false,
                pValue: 1.0,
                confidenceInterval: (0, 0),
                sharpeRatio: 0,
                sharpeConfidenceInterval: (0, 0),
                maxDrawdownConfidenceInterval: (0, 0),
                sortinoRatio: 0,
                calmarRatio: 0,
                informationRatio: nil,
                skewness: 0,
                kurtosis: 0,
                var95: 0,
                var99: 0,
                expectedShortfall: 0,
                recommendation: .insufficientData
            )
        }
        
        let returns = trades.map { $0.profitPercentage }
        let stats = calculateStatistics(returns: returns)
        
        // T-test for significance
        let tTest = performTTest(returns: returns)
        
        // Bootstrap confidence intervals
        let returnCI = bootstrapConfidenceInterval(returns: returns)
        let sharpeCI = bootstrapSharpeRatio(returns: returns)
        let drawdownCI = bootstrapMaxDrawdown(returns: returns)
        
        // Calculate ratios
        let sharpe = calculateSharpeRatio(returns: returns)
        let sortino = calculateSortinoRatio(returns: returns)
        let calmar = calculateCalmarRatio(returns: returns)
        let infoRatio = benchmarkReturns.map { calculateInformationRatio(returns: returns, benchmark: $0) }
        
        // Risk metrics
        let var95 = calculateVaR(returns: returns, confidence: 0.95)
        let var99 = calculateVaR(returns: returns, confidence: 0.99)
        let es = calculateExpectedShortfall(returns: returns, confidence: 0.95)
        
        // Distribution metrics
        let skew = calculateSkewness(returns: returns)
        let kurt = calculateKurtosis(returns: returns)
        
        // Generate recommendation
        let recommendation = generateRecommendation(
            isSignificant: tTest.isSignificant,
            sharpeRatio: sharpe,
            sortinoRatio: sortino,
            var95: var95,
            winRate: stats.winRate
        )
        
        return ValidationResult(
            isSignificant: tTest.isSignificant,
            pValue: tTest.pValue,
            confidenceInterval: returnCI,
            sharpeRatio: sharpe,
            sharpeConfidenceInterval: sharpeCI,
            maxDrawdownConfidenceInterval: drawdownCI,
            sortinoRatio: sortino,
            calmarRatio: calmar,
            informationRatio: infoRatio,
            skewness: skew,
            kurtosis: kurt,
            var95: var95,
            var99: var99,
            expectedShortfall: es,
            recommendation: recommendation
        )
    }
    
    // MARK: - Statistical Tests
    
    private func performTTest(returns: [Double]) -> (isSignificant: Bool, pValue: Double) {
        let n = Double(returns.count)
        let mean = returns.reduce(0, +) / n
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / (n - 1)
        let stdError = sqrt(variance / n)
        
        guard stdError > 0 else { return (false, 1.0) }
        
        let tStatistic = mean / stdError
        let degreesOfFreedom = Int(n - 1)
        
        // Approximate p-value using t-distribution
        let pValue = approximatePValue(t: tStatistic, df: degreesOfFreedom)
        let isSignificant = pValue < (1 - config.confidenceLevel)
        
        return (isSignificant, pValue)
    }
    
    private func bootstrapConfidenceInterval(returns: [Double]) -> (lower: Double, upper: Double) {
        var bootstrapMeans: [Double] = []
        
        for _ in 0..<config.bootstrapIterations {
            var resampledSum = 0.0
            for _ in 0..<returns.count {
                let randomIndex = Int.random(in: 0..<returns.count)
                resampledSum += returns[randomIndex]
            }
            bootstrapMeans.append(resampledSum / Double(returns.count))
        }
        
        bootstrapMeans.sort()
        
        let lowerIndex = Int(Double(config.bootstrapIterations) * (1 - config.confidenceLevel) / 2)
        let upperIndex = Int(Double(config.bootstrapIterations) * (1 + config.confidenceLevel) / 2)
        
        return (
            lower: bootstrapMeans[max(0, lowerIndex)],
            upper: bootstrapMeans[min(config.bootstrapIterations - 1, upperIndex)]
        )
    }
    
    private func bootstrapSharpeRatio(returns: [Double]) -> (lower: Double, upper: Double) {
        var bootstrapSharpes: [Double] = []
        
        for _ in 0..<config.bootstrapIterations {
            var resampledReturns: [Double] = []
            for _ in 0..<returns.count {
                let randomIndex = Int.random(in: 0..<returns.count)
                resampledReturns.append(returns[randomIndex])
            }
            bootstrapSharpes.append(calculateSharpeRatio(returns: resampledReturns))
        }
        
        bootstrapSharpes.sort()
        
        let lowerIndex = Int(Double(config.bootstrapIterations) * (1 - config.confidenceLevel) / 2)
        let upperIndex = Int(Double(config.bootstrapIterations) * (1 + config.confidenceLevel) / 2)
        
        return (
            lower: bootstrapSharpes[max(0, lowerIndex)],
            upper: bootstrapSharpes[min(config.bootstrapIterations - 1, upperIndex)]
        )
    }
    
    private func bootstrapMaxDrawdown(returns: [Double]) -> (lower: Double, upper: Double) {
        var bootstrapDrawdowns: [Double] = []
        
        for _ in 0..<config.bootstrapIterations {
            var resampledReturns: [Double] = []
            for _ in 0..<returns.count {
                let randomIndex = Int.random(in: 0..<returns.count)
                resampledReturns.append(returns[randomIndex])
            }
            bootstrapDrawdowns.append(calculateMaxDrawdown(returns: resampledReturns))
        }
        
        bootstrapDrawdowns.sort()
        
        let lowerIndex = Int(Double(config.bootstrapIterations) * (1 - config.confidenceLevel) / 2)
        let upperIndex = Int(Double(config.bootstrapIterations) * (1 + config.confidenceLevel) / 2)
        
        return (
            lower: bootstrapDrawdowns[max(0, lowerIndex)],
            upper: bootstrapDrawdowns[min(config.bootstrapIterations - 1, upperIndex)]
        )
    }
    
    // MARK: - Ratio Calculations
    
    private func calculateSharpeRatio(returns: [Double], riskFreeRate: Double = 0.0) -> Double {
        let mean = returns.reduce(0, +) / Double(returns.count)
        let stdDev = standardDeviation(returns)
        guard stdDev > 0 else { return 0 }
        return (mean - riskFreeRate) / stdDev * sqrt(252) // Annualized
    }
    
    private func calculateSortinoRatio(returns: [Double], riskFreeRate: Double = 0.0) -> Double {
        let mean = returns.reduce(0, +) / Double(returns.count)
        let downsideReturns = returns.filter { $0 < riskFreeRate }
        let downsideDeviation = standardDeviation(downsideReturns)
        guard downsideDeviation > 0 else { return 0 }
        return (mean - riskFreeRate) / downsideDeviation * sqrt(252)
    }
    
    private func calculateCalmarRatio(returns: [Double]) -> Double {
        let annualizedReturn = returns.reduce(0, +) / Double(returns.count) * 252
        let maxDrawdown = calculateMaxDrawdown(returns: returns)
        guard maxDrawdown > 0 else { return 0 }
        return annualizedReturn / maxDrawdown
    }
    
    private func calculateInformationRatio(returns: [Double], benchmark: [Double]) -> Double {
        guard returns.count == benchmark.count else { return 0 }
        
        let excessReturns = zip(returns, benchmark).map { $0 - $1 }
        let meanExcess = excessReturns.reduce(0, +) / Double(excessReturns.count)
        let trackingError = standardDeviation(excessReturns)
        
        guard trackingError > 0 else { return 0 }
        return meanExcess / trackingError * sqrt(252)
    }
    
    // MARK: - Risk Metrics
    
    private func calculateVaR(returns: [Double], confidence: Double) -> Double {
        let sorted = returns.sorted()
        let index = Int(Double(sorted.count) * (1 - confidence))
        return sorted[max(0, index)]
    }
    
    private func calculateExpectedShortfall(returns: [Double], confidence: Double) -> Double {
        let sorted = returns.sorted()
        let cutoffIndex = Int(Double(sorted.count) * (1 - confidence))
        let tailReturns = Array(sorted[0..<max(1, cutoffIndex)])
        return tailReturns.reduce(0, +) / Double(tailReturns.count)
    }
    
    private func calculateMaxDrawdown(returns: [Double]) -> Double {
        var peak = 0.0
        var maxDrawdown = 0.0
        var cumulative = 0.0
        
        for ret in returns {
            cumulative += ret
            if cumulative > peak {
                peak = cumulative
            }
            let drawdown = peak - cumulative
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }
        
        return maxDrawdown
    }
    
    // MARK: - Distribution Metrics
    
    private func calculateSkewness(returns: [Double]) -> Double {
        let n = Double(returns.count)
        let mean = returns.reduce(0, +) / n
        let stdDev = standardDeviation(returns)
        
        guard stdDev > 0 else { return 0 }
        
        let sumCubedDeviations = returns.map { pow($0 - mean, 3) }.reduce(0, +)
        return (sumCubedDeviations / n) / pow(stdDev, 3)
    }
    
    private func calculateKurtosis(returns: [Double]) -> Double {
        let n = Double(returns.count)
        let mean = returns.reduce(0, +) / n
        let stdDev = standardDeviation(returns)
        
        guard stdDev > 0 else { return 0 }
        
        let sumFourthDeviations = returns.map { pow($0 - mean, 4) }.reduce(0, +)
        return (sumFourthDeviations / n) / pow(stdDev, 4) - 3 // Excess kurtosis
    }
    
    // MARK: - Trade Statistics
    
    func calculateTradeStatistics(trades: [Trade]) -> TradeStatistics {
        let returns = trades.map { $0.profitPercentage }
        let wins = returns.filter { $0 > 0 }
        let losses = returns.filter { $0 <= 0 }
        
        let winRate = Double(wins.count) / Double(trades.count)
        let avgWin = wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count)
        let avgLoss = losses.isEmpty ? 0 : losses.reduce(0, +) / Double(losses.count)
        
        let profitFactor = avgLoss == 0 ? 0 : (avgWin * Double(wins.count)) / abs(avgLoss * Double(losses.count))
        let expectancy = (winRate * avgWin) - ((1 - winRate) * abs(avgLoss))
        
        // Calculate consecutive wins/losses
        var maxConsecutiveWins = 0
        var maxConsecutiveLosses = 0
        var currentStreak = 0
        var currentType: Bool? = nil
        
        for ret in returns {
            let isWin = ret > 0
            if isWin == currentType {
                currentStreak += 1
            } else {
                currentStreak = 1
                currentType = isWin
            }
            
            if isWin {
                maxConsecutiveWins = max(maxConsecutiveWins, currentStreak)
            } else {
                maxConsecutiveLosses = max(maxConsecutiveLosses, currentStreak)
            }
        }
        
        return TradeStatistics(
            returns: returns,
            trades: trades.count,
            winRate: winRate,
            avgWin: avgWin,
            avgLoss: avgLoss,
            profitFactor: profitFactor,
            expectancy: expectancy,
            consecutiveWins: maxConsecutiveWins,
            consecutiveLosses: maxConsecutiveLosses
        )
    }
    
    // MARK: - Helpers
    
    private func calculateStatistics(returns: [Double]) -> (mean: Double, stdDev: Double, winRate: Double) {
        let mean = returns.reduce(0, +) / Double(returns.count)
        let stdDev = standardDeviation(returns)
        let winRate = Double(returns.filter { $0 > 0 }.count) / Double(returns.count)
        return (mean, stdDev, winRate)
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
    
    private func approximatePValue(t: Double, df: Int) -> Double {
        // Simplified approximation of t-distribution p-value
        // For production, use a proper statistical library
        let absT = abs(t)
        if absT < 1.0 {
            return 0.5
        } else if absT < 1.645 {
            return 0.1
        } else if absT < 1.96 {
            return 0.05
        } else if absT < 2.576 {
            return 0.01
        } else {
            return 0.001
        }
    }
    
    private func generateRecommendation(
        isSignificant: Bool,
        sharpeRatio: Double,
        sortinoRatio: Double,
        var95: Double,
        winRate: Double
    ) -> ValidationResult.Recommendation {
        guard isSignificant else { return .insufficientData }
        
        let score = sharpeRatio * 0.3 + sortinoRatio * 0.3 + (winRate - 0.5) * 0.2 + (var95 / 10) * 0.2
        
        if score > 1.5 {
            return .strongBuy
        } else if score > 0.8 {
            return .buy
        } else if score > 0.3 {
            return .hold
        } else if score > -0.5 {
            return .sell
        } else {
            return .strongSell
        }
    }
}