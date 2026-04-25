import Foundation

// MARK: - Chiron Auto-Tuner
/// Iteratif backtest optimizasyonu - en iyi ağırlıkları bulmak için
@MainActor
final class ChironAutoTuner {
    static let shared = ChironAutoTuner()
    
    private init() {}
    
    // MARK: - Configuration
    
    struct TuneConfig {
        let maxIterations: Int      // Maksimum iterasyon sayısı
        let convergenceThreshold: Double  // Değişim bu altına düşerse dur (%)
        let strategy: BacktestConfig.StrategyType
        
        static var `default`: TuneConfig {
            TuneConfig(
                maxIterations: 10,
                convergenceThreshold: 1.0,  // %1 değişim
                strategy: .orionV2
            )
        }
    }
    
    // MARK: - Result
    
    struct TuneResult: Sendable {
        let symbol: String
        let iterations: [IterationResult]
        let bestIteration: Int
        let bestWinRate: Double
        let bestTotalReturn: Double
        let finalWeights: ChironModuleWeights
        let converged: Bool
        let totalTime: TimeInterval
    }
    
    struct IterationResult: Sendable {
        let iteration: Int
        let winRate: Double
        let totalReturn: Double
        let maxDrawdown: Double
        let tradeCount: Int
        let weights: ChironModuleWeights
    }
    
    // MARK: - Public API
    
    /// Iteratif optimizasyon çalıştır
    func autoTune(
        symbol: String,
        candles: [Candle],
        engine: AutoPilotEngine = .pulse,
        config: TuneConfig = TuneConfig.default,
        onProgress: ((Int, IterationResult) -> Void)? = nil
    ) async -> TuneResult {
        let startTime = Date()
        var iterations: [IterationResult] = []
        var lastWinRate: Double = 0
        var converged = false
        
        print("🎯 Chiron Auto-Tune başlıyor: \(symbol)")
        print("   Max İterasyon: \(config.maxIterations), Strateji: \(config.strategy.rawValue)")
        
        for i in 1...config.maxIterations {
            print("\n📊 İterasyon \(i)/\(config.maxIterations)")
            
            // 1. Get current weights
            let currentWeights = ChironWeightStore.shared.getWeights(symbol: symbol, engine: engine)
            
            // 2. Create config and run backtest with current weights
            let backtestConfig = BacktestConfig(
                initialCapital: 100_000,
                strategy: config.strategy,
                stopLossPct: 7,
                startDate: nil,
                executionModel: .realistic
            )
            
            let result = await ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: backtestConfig,
                candles: candles,
                financials: nil
            )
            
            // 3. Create iteration result
            let iterResult = IterationResult(
                iteration: i,
                winRate: result.winRate,
                totalReturn: result.totalReturn,
                maxDrawdown: result.maxDrawdown,
                tradeCount: result.trades.count,
                weights: currentWeights
            )
            iterations.append(iterResult)
            
            print("   Win Rate: \(String(format: "%.1f", result.winRate))%")
            print("   Return: \(String(format: "%.1f", result.totalReturn))%")
            print("   Trades: \(result.trades.count)")
            
            // 4. Report progress
            onProgress?(i, iterResult)
            
            // 5. Check convergence
            let winRateChange = abs(result.winRate - lastWinRate)
            if i > 1 && winRateChange < config.convergenceThreshold {
                print("✅ Convergence! Win rate değişimi: \(String(format: "%.2f", winRateChange))%")
                converged = true
                break
            }
            lastWinRate = result.winRate
            
            // 6. Feed to Chiron for learning (this updates module weights)
            await ArgusBacktestEngine.shared.feedBacktestToChiron(symbol: symbol, result: result)
            
            // 7. ALSO optimize Orion V2 internal weights (Structure, Trend, Momentum, Pattern)
            await OrionV2WeightStore.shared.optimizeFromBacktest(
                symbol: symbol,
                trades: result.trades,
                logs: result.logs
            )
            
            // Small delay to let Chiron process
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // Find best iteration
        let bestIndex = iterations.enumerated()
            .max(by: { a, b in
                // Önce win rate, eşitse return
                if a.element.winRate == b.element.winRate {
                    return a.element.totalReturn < b.element.totalReturn
                }
                return a.element.winRate < b.element.winRate
            })?.offset ?? 0
        
        let best = iterations[bestIndex]
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("\n🏆 Auto-Tune Tamamlandı!")
        print("   En İyi: İterasyon \(best.iteration)")
        print("   Win Rate: \(String(format: "%.1f", best.winRate))%")
        print("   Return: \(String(format: "%.1f", best.totalReturn))%")
        print("   Süre: \(String(format: "%.1f", elapsed)) saniye")
        
        return TuneResult(
            symbol: symbol,
            iterations: iterations,
            bestIteration: best.iteration,
            bestWinRate: best.winRate,
            bestTotalReturn: best.totalReturn,
            finalWeights: iterations.last?.weights ?? .defaultPulse,
            converged: converged,
            totalTime: elapsed
        )
    }
}
