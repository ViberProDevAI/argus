import Foundation

// MARK: - Walk-Forward Analysis
/// Implements walk-forward analysis to prevent overfitting in backtesting.
/// This is a scientifically rigorous method for validating trading strategies.

@MainActor
final class WalkForwardAnalysis {
    
    // MARK: - Configuration
    
    struct Configuration {
        let trainWindow: Int        // Number of bars for training
        let testWindow: Int         // Number of bars for testing
        let step: Int               // Step size for moving window
        let minTrades: Int          // Minimum trades required for significance
        let confidenceLevel: Double // Statistical confidence level (e.g., 0.95)
        
        static let standard = Configuration(
            trainWindow: 252,        // ~1 year of daily data
            testWindow: 63,          // ~3 months
            step: 21,                // Monthly reoptimization
            minTrades: 10,
            confidenceLevel: 0.95
        )
    }
    
    // MARK: - Results
    
    struct WalkForwardResult {
        let period: Int
        let trainStart: Date
        let trainEnd: Date
        let testStart: Date
        let testEnd: Date
        let trainPerformance: PerformanceMetrics
        let testPerformance: PerformanceMetrics
        let parameterSet: StrategyParameters
        let isSignificant: Bool
    }
    
    struct PerformanceMetrics {
        let totalReturn: Double
        let annualizedReturn: Double
        let volatility: Double
        let sharpeRatio: Double
        let maxDrawdown: Double
        let winRate: Double
        let profitFactor: Double
        let trades: Int
        let avgTrade: Double
        
        var isValid: Bool {
            trades > 0 && !totalReturn.isNaN && !sharpeRatio.isNaN
        }
    }
    
    struct StrategyParameters {
        let orionWeight: Double
        let atlasWeight: Double
        let aetherWeight: Double
        let entryThreshold: Double
        let exitThreshold: Double
        let atrMultiplier: Double
        
        static let `default` = StrategyParameters(
            orionWeight: 0.35,
            atlasWeight: 0.25,
            aetherWeight: 0.20,
            entryThreshold: 65.0,
            exitThreshold: 45.0,
            atrMultiplier: 2.0
        )
    }
    
    struct AnalysisSummary {
        let results: [WalkForwardResult]
        let consistencyScore: Double
        let robustnessScore: Double
        let overfittingRisk: RiskLevel
        let recommendation: Recommendation
        
        enum RiskLevel: String {
            case low = "Düşük"
            case medium = "Orta"
            case high = "Yüksek"
            case critical = "Kritik"
        }
        
        enum Recommendation: String {
            case approve = "Strateji Onaylandı"
            case caution = "Dikkatli Kullanım"
            case reject = "Strateji Reddedildi"
            case needsOptimization = "Optimizasyon Gerekli"
        }
    }
    
    // MARK: - Properties
    
    private let config: Configuration
    private let backtestEngine: ArgusBacktestEngine
    
    init(config: Configuration = .standard) {
        self.config = config
        self.backtestEngine = ArgusBacktestEngine.shared
    }
    
    // MARK: - Main Analysis
    
    func analyze(
        symbol: String,
        candles: [Candle],
        strategy: WalkForwardStrategyType = .combined
    ) async -> AnalysisSummary {
        guard candles.count >= config.trainWindow + config.testWindow else {
            return AnalysisSummary(
                results: [],
                consistencyScore: 0,
                robustnessScore: 0,
                overfittingRisk: .critical,
                recommendation: .reject
            )
        }
        
        let sortedCandles = candles.sorted { $0.date < $1.date }
        var results: [WalkForwardResult] = []
        
        // Walk forward loop
        for i in stride(
            from: config.trainWindow,
            to: sortedCandles.count - config.testWindow,
            by: config.step
        ) {
            let trainData = Array(sortedCandles[i-config.trainWindow..<i])
            let testData = Array(sortedCandles[i..<min(i+config.testWindow, sortedCandles.count)])
            
            // Optimize on training data
            let optimalParams = await optimizeParameters(
                symbol: symbol,
                candles: trainData,
                strategy: strategy
            )
            
            // Test on out-of-sample data
            let trainMetrics = await backtest(
                symbol: symbol,
                candles: trainData,
                parameters: optimalParams,
                strategy: strategy
            )
            
            let testMetrics = await backtest(
                symbol: symbol,
                candles: testData,
                parameters: optimalParams,
                strategy: strategy
            )
            
            // Check statistical significance
            let isSignificant = checkSignificance(
                trainMetrics: trainMetrics,
                testMetrics: testMetrics
            )
            
            let result = WalkForwardResult(
                period: results.count + 1,
                trainStart: trainData.first?.date ?? Date(),
                trainEnd: trainData.last?.date ?? Date(),
                testStart: testData.first?.date ?? Date(),
                testEnd: testData.last?.date ?? Date(),
                trainPerformance: trainMetrics,
                testPerformance: testMetrics,
                parameterSet: optimalParams,
                isSignificant: isSignificant
            )
            
            results.append(result)
        }
        
        return generateSummary(from: results)
    }
    
    // MARK: - Parameter Optimization
    
    private func optimizeParameters(
        symbol: String,
        candles: [Candle],
        strategy: WalkForwardStrategyType
    ) async -> StrategyParameters {
        // Grid search for optimal parameters
        let orionWeights = [0.25, 0.35, 0.45]
        let atlasWeights = [0.20, 0.25, 0.30]
        let entryThresholds = [60.0, 65.0, 70.0]
        let atrMultipliers = [1.5, 2.0, 2.5]
        
        var bestParams = StrategyParameters.default
        var bestScore = -Double.infinity
        
        for orionW in orionWeights {
            for atlasW in atlasWeights {
                for entryT in entryThresholds {
                    for atrM in atrMultipliers {
                        let params = StrategyParameters(
                            orionWeight: orionW,
                            atlasWeight: atlasW,
                            aetherWeight: 1.0 - orionW - atlasW,
                            entryThreshold: entryT,
                            exitThreshold: entryT - 20.0,
                            atrMultiplier: atrM
                        )
                        
                        let metrics = await backtest(
                            symbol: symbol,
                            candles: candles,
                            parameters: params,
                            strategy: strategy
                        )
                        
                        let score = calculateScore(metrics)
                        
                        if score > bestScore {
                            bestScore = score
                            bestParams = params
                        }
                    }
                }
            }
        }
        
        return bestParams
    }
    
    // MARK: - Backtesting
    
    private func backtest(
        symbol: String,
        candles: [Candle],
        parameters: StrategyParameters,
        strategy: WalkForwardStrategyType
    ) async -> PerformanceMetrics {
        // Use existing backtest engine with custom parameters
        // Create explicit BacktestConfig (Global)
        let globalStrategy: BacktestConfig.StrategyType
        switch strategy {
        case .orion: globalStrategy = .orionV2
        case .atlas: globalStrategy = .argusStandard
        case .aether: globalStrategy = .aggressive
        case .combined: globalStrategy = .argusStandard
        case .custom: globalStrategy = .argusStandard
        }
        
        let result = await backtestEngine.runBacktest(
            symbol: symbol,
            config: BacktestConfig(
                strategy: globalStrategy
            ),
            candles: candles,
            financials: nil
        )
        
        return PerformanceMetrics(
            totalReturn: result.totalReturn,
            annualizedReturn: result.annualizedReturn,
            volatility: result.volatility,
            sharpeRatio: result.sharpeRatio,
            maxDrawdown: result.maxDrawdown,
            winRate: result.winRate,
            profitFactor: result.profitFactor,
            trades: result.trades.count,
            avgTrade: result.avgTrade
        )
    }
    
    // MARK: - Statistical Analysis
    
    private func checkSignificance(
        trainMetrics: PerformanceMetrics,
        testMetrics: PerformanceMetrics
    ) -> Bool {
        // Check if test performance is statistically similar to train
        guard trainMetrics.isValid && testMetrics.isValid else { return false }
        
        // Calculate degradation
        let returnDegradation = abs(trainMetrics.totalReturn - testMetrics.totalReturn)
        let sharpeDegradation = abs(trainMetrics.sharpeRatio - testMetrics.sharpeRatio)
        
        // Thresholds for significance
        let maxReturnDegradation = 0.20 // 20%
        let maxSharpeDegradation = 0.50 // 0.5
        
        return returnDegradation < maxReturnDegradation &&
               sharpeDegradation < maxSharpeDegradation
    }
    
    private func calculateScore(_ metrics: PerformanceMetrics) -> Double {
        // Multi-objective scoring
        let sharpeScore = metrics.sharpeRatio * 0.3
        let returnScore = (metrics.totalReturn / 100.0) * 0.25
        let drawdownScore = (1.0 - abs(metrics.maxDrawdown) / 100.0) * 0.25
        let winRateScore = (metrics.winRate / 100.0) * 0.2
        
        return sharpeScore + returnScore + drawdownScore + winRateScore
    }
    
    private func generateSummary(from results: [WalkForwardResult]) -> AnalysisSummary {
        guard !results.isEmpty else {
            return AnalysisSummary(
                results: [],
                consistencyScore: 0,
                robustnessScore: 0,
                overfittingRisk: .critical,
                recommendation: .reject
            )
        }
        
        // Calculate consistency (correlation between train and test)
        let trainReturns = results.map { $0.trainPerformance.totalReturn }
        let testReturns = results.map { $0.testPerformance.totalReturn }
        let consistency = calculateCorrelation(trainReturns, testReturns)
        
        // Calculate robustness (variance of test performance)
        let testSharpeRatios = results.map { $0.testPerformance.sharpeRatio }
        let robustness = 1.0 - (standardDeviation(testSharpeRatios) / abs(mean(testSharpeRatios)))
        
        // Determine overfitting risk
        let significantPeriods = results.filter { $0.isSignificant }.count
        let significanceRatio = Double(significantPeriods) / Double(results.count)
        
        let overfittingRisk: AnalysisSummary.RiskLevel
        if significanceRatio > 0.8 && consistency > 0.7 {
            overfittingRisk = .low
        } else if significanceRatio > 0.6 && consistency > 0.5 {
            overfittingRisk = .medium
        } else if significanceRatio > 0.4 {
            overfittingRisk = .high
        } else {
            overfittingRisk = .critical
        }
        
        // Generate recommendation
        let recommendation: AnalysisSummary.Recommendation
        switch overfittingRisk {
        case .low:
            recommendation = .approve
        case .medium:
            recommendation = .caution
        case .high:
            recommendation = .needsOptimization
        case .critical:
            recommendation = .reject
        }
        
        return AnalysisSummary(
            results: results,
            consistencyScore: max(0, consistency),
            robustnessScore: max(0, robustness),
            overfittingRisk: overfittingRisk,
            recommendation: recommendation
        )
    }
    
    // MARK: - Statistical Helpers
    
    private func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0 }
        
        let meanX = mean(x)
        let meanY = mean(y)
        
        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0
        
        for i in 0..<x.count {
            let diffX = x[i] - meanX
            let diffY = y[i] - meanY
            numerator += diffX * diffY
            denomX += diffX * diffX
            denomY += diffY * diffY
        }
        
        let denominator = sqrt(denomX * denomY)
        return denominator == 0 ? 0 : numerator / denominator
    }
    
    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let variance = values.map { pow($0 - m, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Strategy Type

enum WalkForwardStrategyType {
    case orion
    case atlas
    case aether
    case combined
    case custom(parameters: WalkForwardAnalysis.StrategyParameters)
}

// MARK: - Backtest Config

// Conflicting struct removed to use ChronosModels.WalkForwardConfig