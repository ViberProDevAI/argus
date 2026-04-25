import Foundation

// MARK: - Chiron Deep Tuner
/// Iterative optimization engine that finds the best Orion V2 configuration
/// through real backtests with different parameter combinations.
@MainActor
final class ChironDeepTuner {
    static let shared = ChironDeepTuner()
    
    private init() {}
    
    // MARK: - Configuration
    
    struct DeepTuneConfig {
        let maxIterations: Int           // How many parameter combinations to try
        let trainSplitRatio: Double      // 0.8 = 80% train, 20% test
        let convergenceThreshold: Double // Stop if improvement < this %
        let symbol: String
        let candles: [Candle]
        
        static func standard(symbol: String, candles: [Candle]) -> DeepTuneConfig {
            DeepTuneConfig(
                maxIterations: 20,
                trainSplitRatio: 0.8,
                convergenceThreshold: 0.5,
                symbol: symbol,
                candles: candles
            )
        }
    }
    
    // MARK: - Result Types
    
    struct DeepTuneResult: Sendable {
        let symbol: String
        let iterations: [IterationResult]
        let bestConfig: OrionV2TuningConfig
        let baselineResult: BacktestMetrics
        let bestResult: BacktestMetrics
        let outOfSampleResult: BacktestMetrics?
        let totalTime: TimeInterval
        let converged: Bool
    }
    
    struct IterationResult: Sendable {
        let iteration: Int
        let config: OrionV2TuningConfig
        let metrics: BacktestMetrics
    }
    
    struct BacktestMetrics: Sendable {
        let winRate: Double
        let totalReturn: Double
        let maxDrawdown: Double
        let tradeCount: Int
        let sharpeRatio: Double
        let profitFactor: Double
        
        var score: Double {
            // Composite score: Win Rate * 0.4 + Sharpe * 0.3 + Return * 0.2 + (1 - DD) * 0.1
            let normalizedWR = winRate / 100.0
            let normalizedReturn = max(0, min(1, (totalReturn + 50) / 100.0))
            let normalizedDD = max(0, min(1, 1 - (maxDrawdown / 50.0)))
            let normalizedSharpe = max(0, min(1, (sharpeRatio + 1) / 3.0))
            
            return (normalizedWR * 0.4) + (normalizedSharpe * 0.3) + (normalizedReturn * 0.2) + (normalizedDD * 0.1)
        }
    }
    
    // MARK: - Public API
    
    /// Runs deep tuning optimization
    func runDeepTune(
        config: DeepTuneConfig,
        onProgress: @escaping (Int, Int, IterationResult) -> Void
    ) async -> DeepTuneResult {
        let startTime = Date()
        var iterations: [IterationResult] = []
        var bestConfig = OrionV2TuningStore.shared.getConfig(symbol: config.symbol)
        var bestScore: Double = 0
        var converged = false
        
        print("🧠 Chiron Deep Tune başlıyor: \(config.symbol)")
        print("   Max İterasyon: \(config.maxIterations)")
        print("   Train/Test: \(Int(config.trainSplitRatio * 100))% / \(Int((1 - config.trainSplitRatio) * 100))%")
        
        // Split data into train and test
        let splitIndex = Int(Double(config.candles.count) * config.trainSplitRatio)
        let trainCandles = Array(config.candles.prefix(splitIndex))
        let testCandles = Array(config.candles.suffix(from: splitIndex))
        
        print("   Train veri: \(trainCandles.count) candle")
        print("   Test veri: \(testCandles.count) candle")
        
        // 1. Run baseline with current config
        let baselineConfig = OrionV2TuningStore.shared.getConfig(symbol: config.symbol)
        let baselineMetrics = await runBacktestWithConfig(
            symbol: config.symbol,
            candles: trainCandles,
            config: baselineConfig
        )
        print("📊 Baseline: WR=\(String(format: "%.1f", baselineMetrics.winRate))% Return=\(String(format: "%.1f", baselineMetrics.totalReturn))%")
        
        // 2. Generate and test parameter combinations
        let parameterSpace = generateParameterSpace()
        
        for (i, testConfig) in parameterSpace.prefix(config.maxIterations).enumerated() {
            // Apply test config temporarily
            OrionV2TuningStore.shared.updateConfig(symbol: config.symbol, config: testConfig)
            
            // Run backtest with this config
            let metrics = await runBacktestWithConfig(
                symbol: config.symbol,
                candles: trainCandles,
                config: testConfig
            )
            
            let iterResult = IterationResult(
                iteration: i + 1,
                config: testConfig,
                metrics: metrics
            )
            iterations.append(iterResult)
            
            print("📊 İterasyon \(i + 1)/\(config.maxIterations): Score=\(String(format: "%.3f", metrics.score)) WR=\(String(format: "%.1f", metrics.winRate))%")
            
            // Report progress
            onProgress(i + 1, config.maxIterations, iterResult)
            
            // Track best
            if metrics.score > bestScore {
                let improvement = bestScore > 0 ? ((metrics.score - bestScore) / bestScore) * 100 : 100
                bestScore = metrics.score
                bestConfig = testConfig
                print("   ✨ Yeni en iyi! Improvement: \(String(format: "%.1f", improvement))%")
                
                // Check convergence
                if improvement < config.convergenceThreshold && i > 5 {
                    print("   ✅ Convergence - iyileşme %\(String(format: "%.2f", improvement)) < threshold")
                    converged = true
                    break
                }
            }
            
            // Small delay
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // 3. Validate on out-of-sample data
        var outOfSampleResult: BacktestMetrics? = nil
        if testCandles.count > 30 {
            OrionV2TuningStore.shared.updateConfig(symbol: config.symbol, config: bestConfig)
            outOfSampleResult = await runBacktestWithConfig(
                symbol: config.symbol,
                candles: testCandles,
                config: bestConfig
            )
            print("📊 Out-of-Sample Test: WR=\(String(format: "%.1f", outOfSampleResult!.winRate))% Return=\(String(format: "%.1f", outOfSampleResult!.totalReturn))%")
        }
        
        // 4. Restore best config
        let finalConfig = OrionV2TuningConfig(
            structureWeight: bestConfig.structureWeight,
            trendWeight: bestConfig.trendWeight,
            momentumWeight: bestConfig.momentumWeight,
            patternWeight: bestConfig.patternWeight,
            volatilityWeight: bestConfig.volatilityWeight,
            entryThreshold: bestConfig.entryThreshold,
            exitThreshold: bestConfig.exitThreshold,
            partialExitThreshold: bestConfig.partialExitThreshold,
            stopLossPercent: bestConfig.stopLossPercent,
            takeProfitPercent: bestConfig.takeProfitPercent,
            updatedAt: Date(),
            confidence: min(0.95, 0.5 + bestScore * 0.5),
            reasoning: "Deep Tune: \(iterations.count) iterasyon, Score: \(String(format: "%.3f", bestScore))",
            backtestWinRate: iterations.max(by: { $0.metrics.score < $1.metrics.score })?.metrics.winRate,
            backtestReturn: iterations.max(by: { $0.metrics.score < $1.metrics.score })?.metrics.totalReturn
        )
        
        // Get best metrics for result
        let bestMetrics = iterations.max(by: { $0.metrics.score < $1.metrics.score })?.metrics ?? baselineMetrics
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("🏆 Deep Tune Tamamlandı! Süre: \(String(format: "%.1f", elapsed)) saniye")
        
        return DeepTuneResult(
            symbol: config.symbol,
            iterations: iterations,
            bestConfig: finalConfig,
            baselineResult: baselineMetrics,
            bestResult: bestMetrics,
            outOfSampleResult: outOfSampleResult,
            totalTime: elapsed,
            converged: converged
        )
    }
    
    // MARK: - Parameter Space Generation
    
    private func generateParameterSpace() -> [OrionV2TuningConfig] {
        var configs: [OrionV2TuningConfig] = []
        
        // Weight combinations (keeping total = 1.0)
        let structureOptions = [0.20, 0.25, 0.30, 0.35, 0.40]
        let trendOptions = [0.20, 0.25, 0.30, 0.35]
        let momentumOptions = [0.15, 0.20, 0.25, 0.30]
        
        // Threshold combinations
        let entryOptions = [65.0, 70.0, 75.0, 80.0]
        let exitOptions = [45.0, 50.0, 55.0]
        
        // Stop-loss combinations
        let stopOptions = [3.0, 5.0, 7.0, 10.0]
        
        // Generate combinations (limited to avoid explosion)
        for structure in structureOptions {
            for trend in trendOptions {
                let remaining = 1.0 - structure - trend
                guard remaining > 0.15 else { continue }
                
                for momentum in momentumOptions {
                    guard momentum <= remaining else { continue }
                    
                    let patternAndVol = remaining - momentum
                    guard patternAndVol >= 0.05 else { continue }
                    
                    let pattern = min(0.15, patternAndVol * 0.7)
                    let volatility = patternAndVol - pattern
                    
                    for entry in entryOptions {
                        for exit in exitOptions {
                            guard entry > exit else { continue }
                            
                            for stop in stopOptions {
                                let config = OrionV2TuningConfig(
                                    structureWeight: structure,
                                    trendWeight: trend,
                                    momentumWeight: momentum,
                                    patternWeight: pattern,
                                    volatilityWeight: volatility,
                                    entryThreshold: entry,
                                    exitThreshold: exit,
                                    partialExitThreshold: (entry + exit) / 2,
                                    stopLossPercent: stop,
                                    takeProfitPercent: stop * 3, // 3:1 R/R
                                    updatedAt: Date(),
                                    confidence: 0.5,
                                    reasoning: "Auto-generated",
                                    backtestWinRate: nil,
                                    backtestReturn: nil
                                )
                                configs.append(config)
                            }
                        }
                    }
                }
            }
        }
        
        // Shuffle for diversity
        return configs.shuffled()
    }
    
    // MARK: - Backtest Runner
    
    private func runBacktestWithConfig(
        symbol: String,
        candles: [Candle],
        config: OrionV2TuningConfig
    ) async -> BacktestMetrics {
        // Run actual backtest using ArgusBacktestEngine
        let backtestConfig = BacktestConfig(
            initialCapital: 10_000,
            strategy: .orionV2,
            stopLossPct: config.stopLossPercent / 100.0,
            startDate: nil,
            executionModel: .realistic
        )
        
        let result = await ArgusBacktestEngine.shared.runBacktest(
            symbol: symbol,
            config: backtestConfig,
            candles: candles,
            financials: nil
        )
        
        // Calculate Sharpe Ratio (simplified)
        let returns = result.trades.map { $0.pnlPercent }
        let avgReturn = returns.isEmpty ? 0 : returns.reduce(0, +) / Double(returns.count)
        let variance = returns.isEmpty ? 1 : returns.map { pow($0 - avgReturn, 2) }.reduce(0, +) / Double(returns.count)
        let stdDev = sqrt(variance)
        let sharpe = stdDev > 0 ? avgReturn / stdDev : 0
        
        return BacktestMetrics(
            winRate: result.winRate,
            totalReturn: result.totalReturn,
            maxDrawdown: result.maxDrawdown,
            tradeCount: result.trades.count,
            sharpeRatio: sharpe,
            profitFactor: result.profitFactor
        )
    }
}
