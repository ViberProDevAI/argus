import Foundation

// MARK: - Chronos Walk-Forward Engine ⏳
/// Overfit'i önleyen profesyonel backtest yaklaşımı: Chronos
/// In-sample optimizasyon + Out-of-sample validation

actor ChronosWalkForwardEngine {
    static let shared = ChronosWalkForwardEngine()
    
    private init() {}
    
    // MARK: - Walk-Forward Analysis
    
    /// Walk-forward backtest çalıştır
    func runWalkForward(
        symbol: String,
        candles: [Candle],
        config: WalkForwardConfig,
        strategy: BacktestConfig.StrategyType,
        financials: FinancialsData? = nil
    ) async -> WalkForwardResult {
        
        var windowResults: [WindowResult] = []
        var combinedTrades: [BacktestTrade] = []
        var outOfSampleEquity: [EquityPoint] = []
        
        // Veri sıralama kontrolü
        let sortedCandles = candles.sorted { $0.date < $1.date }
        let totalDays = sortedCandles.count
        
        let windowSize = config.inSampleDays + config.outOfSampleDays
        var startIndex = 0
        var windowNumber = 0
        
        print("⏳ Chronos: Starting analysis for \(symbol) with \(totalDays) candles")
        
        // Sliding window loop
        while startIndex + windowSize <= totalDays {
            windowNumber += 1
            
            let inSampleEnd = startIndex + config.inSampleDays
            let outSampleEnd = startIndex + windowSize
            
            // Split data
            let inSampleCandles = Array(sortedCandles[startIndex..<inSampleEnd])
            let outSampleCandles = Array(sortedCandles[inSampleEnd..<outSampleEnd])
            
            // 1. In-Sample: Optimize parameters (simulated)
            let optimizedParams = await optimizeParameters(
                candles: inSampleCandles,
                strategy: strategy,
                symbol: symbol,
                financials: financials
            )
            
            // 2. Out-of-Sample: Test with optimized parameters
            let backtest = BacktestConfig(
                initialCapital: config.initialCapital,
                strategy: strategy,
                stopLossPct: optimizedParams.stopLossPct
            )
            
            let result = await ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: backtest,
                candles: outSampleCandles,
                financials: financials
            )
            
            // Record window result
            let window = WindowResult(
                windowNumber: windowNumber,
                inSampleStart: inSampleCandles.first?.date ?? Date(),
                inSampleEnd: inSampleCandles.last?.date ?? Date(),
                outSampleStart: outSampleCandles.first?.date ?? Date(),
                outSampleEnd: outSampleCandles.last?.date ?? Date(),
                inSampleReturn: optimizedParams.inSampleReturn,
                outOfSampleReturn: result.totalReturn,
                tradeCount: result.trades.count,
                winRate: result.winRate,
                optimizedParams: optimizedParams
            )
            
            windowResults.append(window)
            combinedTrades.append(contentsOf: result.trades)
            outOfSampleEquity.append(contentsOf: result.equityCurve)
            
            print("  Window \(windowNumber): IS=\(String(format: "%.1f", optimizedParams.inSampleReturn))% → OOS=\(String(format: "%.1f", result.totalReturn))%")
            
            // Slide window
            startIndex += config.stepDays
        }
        
        // Calculate overall metrics
        let totalOOSReturn = windowResults.reduce(0.0) { $0 + $1.outOfSampleReturn }
        let avgOOSReturn = windowResults.isEmpty ? 0 : totalOOSReturn / Double(windowResults.count)
        
        // Overfit Ratio (IS/OOS return comparison)
        let totalISReturn = windowResults.reduce(0.0) { $0 + $1.inSampleReturn }
        let avgISReturn = windowResults.isEmpty ? 0 : totalISReturn / Double(windowResults.count)
        let overfitRatio = avgISReturn != 0 ? avgOOSReturn / avgISReturn : 1.0
        
        // Consistency: How many windows were profitable OOS?
        let profitableWindows = windowResults.filter { $0.outOfSampleReturn > 0 }.count
        let consistencyScore = Double(profitableWindows) / Double(max(1, windowResults.count)) * 100.0
        
        // Win rate across all OOS trades
        let wins = combinedTrades.filter { $0.pnl > 0 }.count
        let totalTrades = combinedTrades.count
        let overallWinRate = totalTrades > 0 ? Double(wins) / Double(totalTrades) * 100.0 : 0
        
        return WalkForwardResult(
            symbol: symbol,
            strategy: strategy,
            config: config,
            windowResults: windowResults,
            totalOutOfSampleReturn: totalOOSReturn,
            avgOutOfSampleReturn: avgOOSReturn,
            avgInSampleReturn: avgISReturn,
            overfitRatio: overfitRatio,
            consistencyScore: consistencyScore,
            totalTrades: totalTrades,
            overallWinRate: overallWinRate,
            combinedTrades: combinedTrades,
            outOfSampleEquity: outOfSampleEquity,
            generatedAt: Date()
        )
    }
    
    // MARK: - Parameter Optimization (Simplified)
    
    /// In-sample veri üzerinde parametre optimizasyonu
    private func optimizeParameters(
        candles: [Candle],
        strategy: BacktestConfig.StrategyType,
        symbol: String,
        financials: FinancialsData?
    ) async -> OptimizedParameters {
        
        // Test different stop-loss levels
        let stopLossOptions = [0.03, 0.05, 0.07, 0.10]
        var bestReturn = -Double.infinity
        var bestStopLoss = 0.05
        
        for sl in stopLossOptions {
            let config = BacktestConfig(
                initialCapital: 10000,
                strategy: strategy,
                stopLossPct: sl
            )
            
            let result = await ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: config,
                candles: candles,
                financials: financials
            )
            
            // Sharpe-like score (return / risk adjusted)
            let adjustedReturn = result.totalReturn - (result.maxDrawdown * 0.5)
            
            if adjustedReturn > bestReturn {
                bestReturn = adjustedReturn
                bestStopLoss = sl
            }
        }
        
        // Run final backtest with best params
        let finalConfig = BacktestConfig(
            initialCapital: 10000,
            strategy: strategy,
            stopLossPct: bestStopLoss
        )
        
        let finalResult = await ArgusBacktestEngine.shared.runBacktest(
            symbol: symbol,
            config: finalConfig,
            candles: candles,
            financials: financials
        )
        
        return OptimizedParameters(
            stopLossPct: bestStopLoss,
            entryThreshold: 75.0, // Default for now
            exitThreshold: 45.0,
            inSampleReturn: finalResult.totalReturn,
            inSampleWinRate: finalResult.winRate,
            inSampleDrawdown: finalResult.maxDrawdown
        )
    }
    
    // MARK: - Overfit Detection
    
    /// Overfit skoru hesapla (0-100, düşük = iyi)
    func calculateOverfitScore(result: WalkForwardResult) -> OverfitAnalysis {
        var score = 0.0
        var warnings: [String] = []
        
        // 1. IS/OOS Return Gap
        let returnGap = result.avgInSampleReturn - result.avgOutOfSampleReturn
        if returnGap > 20 {
            score += 30
            warnings.append("In-sample süper, Out-of-sample kötü (Gap: \(String(format: "%.1f", returnGap))%). Overfit belirtisi.")
        } else if returnGap > 10 {
            score += 15
        }
        
        // 2. Overfit Ratio
        if result.overfitRatio < 0.5 {
            score += 25
            warnings.append("OOS performansı IS'nin yarısından az.")
        } else if result.overfitRatio < 0.75 {
            score += 10
        }
        
        // 3. Consistency
        if result.consistencyScore < 50 {
            score += 25
            warnings.append("Test pencerelerinin çoğunda zarar etti (Tutarsız).")
        } else if result.consistencyScore < 70 {
            score += 10
        }
        
        // 4. Trade Count
        if result.totalTrades < 10 {
            score += 15
            warnings.append("Yetersiz işlem sayısı (\(result.totalTrades)). İstatistiksel güven düşük.")
        }
        
        // 5. Win Rate Collapse
        let avgISWinRate = result.windowResults.map { $0.optimizedParams.inSampleWinRate }.reduce(0, +) / Double(max(1, result.windowResults.count))
        let winRateDrop = avgISWinRate - result.overallWinRate
        if winRateDrop > 20 {
            score += 10
            warnings.append("Win rate OOS'de ciddi düştü.")
        }
        
        let level: OverfitLevel
        switch score {
        case 0..<25: level = .low
        case 25..<50: level = .moderate
        case 50..<75: level = .high
        default: level = .critical
        }
        
        return OverfitAnalysis(
            score: min(100, score),
            level: level,
            warnings: warnings,
            recommendation: generateRecommendation(level: level, warnings: warnings)
        )
    }
    
    private func generateRecommendation(level: OverfitLevel, warnings: [String]) -> String {
        switch level {
        case .low:
            return "✅ Chronos Onayı: Strateji zaman testinden başarıyla geçti. Güvenilir."
        case .moderate:
            return "⚠️ Dikkat: Bazı dönemlerde performans düşüyor. Canlı işlemde küçük risk alın."
        case .high:
             return "❌ Riskli: Yüksek overfit riski. Geçmişe aşırı uyum sağlanmış olabilir."
        case .critical:
             return "⛔️ RED: Chronos bu stratejiyi veto etti. Canlı piyasada batma riski yüksek."
        }
    }
}
