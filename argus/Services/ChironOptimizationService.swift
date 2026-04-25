import Foundation

/// Service that optimizes Chiron weights based on backtest performance.
/// Deterministic approach with regime-aware, symbol-specific learning.
final class ChironOptimizationService: Sendable {
    static let shared = ChironOptimizationService()
    
    private init() {}
    
    /// Calculates optimized weights based on performance metrics.
    /// Now includes: Regime awareness, Symbol overrides, Drawdown penalty
    func optimize(input: ChironOptimizationInput) async throws -> ChironOptimizationOutput {
        print("🧠 Chiron Optimization v2: Enhanced Learning Mode...")
        
        // Get current weights as starting point
        let currentCore = input.globalSettings.currentArgusWeights.core
        let currentPulse = input.globalSettings.currentArgusWeights.pulse
        var learningNotes: [String] = []
        var symbolOverrides: [ChironOptimizationOutput.PerSymbolOverride] = []
        
        // Aggregate adjustments by regime
        var trendingOrionDelta: Double = 0
        var rangingOrionDelta: Double = 0
        var trendingPhoenixDelta: Double = 0
        var rangingPhoenixDelta: Double = 0
        var globalAtlasDelta: Double = 0
        
        var trendingCount = 0
        var rangingCount = 0
        
        // Process each performance log
        for log in input.performanceLogs {
            let isTrending = log.regime.trendState == "TRENDING"
            let analysis = analyzeModulePerformance(log: log, safeguards: input.globalSettings.safeguards)
            
            // REGIME-AWARE LEARNING
            if isTrending {
                trendingCount += 1
                if let adj = analysis.orionAdjustment {
                    trendingOrionDelta += adj
                }
                if let adj = analysis.phoenixAdjustment {
                    trendingPhoenixDelta += adj
                }
            } else {
                rangingCount += 1
                if let adj = analysis.orionAdjustment {
                    rangingOrionDelta += adj
                }
                if let adj = analysis.phoenixAdjustment {
                    rangingPhoenixDelta += adj
                }
            }
            
            if let adj = analysis.atlasAdjustment {
                globalAtlasDelta += adj
            }
            
            // SYMBOL-SPECIFIC OVERRIDE
            if let override = generateSymbolOverride(log: log, analysis: analysis) {
                symbolOverrides.append(override)
                learningNotes.append("🎯 \(log.symbol): Özel ağırlık override oluşturuldu")
            }
            
            // Log details
            if analysis.orionAdjustment != nil || analysis.phoenixAdjustment != nil {
                let regime = isTrending ? "TREND" : "RANGE"
                learningNotes.append("📊 \(log.symbol) [\(regime)]: Orion Δ\(String(format: "%+.2f", analysis.orionAdjustment ?? 0)), Phoenix Δ\(String(format: "%+.2f", analysis.phoenixAdjustment ?? 0))")
            }
        }
        
        // BLEND REGIME-SPECIFIC DELTAS
        // Trending'de Orion daha önemli, Ranging'de Phoenix
        let orionDelta: Double
        let phoenixDelta: Double
        
        if trendingCount > 0 && rangingCount > 0 {
            // Mix both regime learnings
            orionDelta = (trendingOrionDelta * 0.6 + rangingOrionDelta * 0.4)
            phoenixDelta = (trendingPhoenixDelta * 0.4 + rangingPhoenixDelta * 0.6) // Phoenix more important in range
            learningNotes.append("📈 Karma öğrenme: \(trendingCount) trending + \(rangingCount) ranging backtest")
        } else if trendingCount > 0 {
            orionDelta = trendingOrionDelta
            phoenixDelta = trendingPhoenixDelta
            learningNotes.append("📈 Trending-ağırlıklı öğrenme (\(trendingCount) backtest)")
        } else if rangingCount > 0 {
            orionDelta = rangingOrionDelta
            phoenixDelta = rangingPhoenixDelta
            learningNotes.append("📉 Ranging-ağırlıklı öğrenme (\(rangingCount) backtest)")
        } else {
            orionDelta = 0
            phoenixDelta = 0
        }
        
        // Build new weights
        let newCore = ModuleWeights(
            atlas: clamp(currentCore.atlas + globalAtlasDelta, min: input.globalSettings.safeguards.minModuleWeightCore, max: 2.0),
            orion: clamp(currentCore.orion + orionDelta, min: input.globalSettings.safeguards.minModuleWeightCore, max: 2.0),
            aether: currentCore.aether,
            demeter: currentCore.demeter,
            phoenix: clamp((currentCore.phoenix ?? 1.0) + phoenixDelta, min: input.globalSettings.safeguards.minModuleWeightCore, max: 2.0),
            hermes: currentCore.hermes,
            athena: currentCore.athena
        ).normalized
        
        let newPulse = ModuleWeights(
            atlas: clamp(currentPulse.atlas + globalAtlasDelta, min: input.globalSettings.safeguards.minModuleWeightPulse, max: 2.0),
            orion: clamp(currentPulse.orion + orionDelta, min: input.globalSettings.safeguards.minModuleWeightPulse, max: 2.0),
            aether: currentPulse.aether,
            demeter: currentPulse.demeter,
            phoenix: clamp((currentPulse.phoenix ?? 1.0) + phoenixDelta, min: input.globalSettings.safeguards.minModuleWeightPulse, max: 2.0),
            hermes: currentPulse.hermes,
            athena: currentPulse.athena
        ).normalized
        
        // Summary note
        if orionDelta != 0 || phoenixDelta != 0 {
            learningNotes.append("✅ Yeni Ağırlıklar → Orion: \(String(format: "%.2f", newPulse.orion)), Phoenix: \(String(format: "%.2f", newPulse.phoenix ?? 0))")
        } else {
            learningNotes.append("ℹ️ Yetersiz veri veya nötr performans - ağırlık değişimi yok")
        }
        
        print("🧠 Chiron v2 Complete: \(learningNotes.count) notes, \(symbolOverrides.count) overrides")
        
        return ChironOptimizationOutput(
            newArgusWeights: ChironOptimizationInput.ArgusWeights(core: newCore, pulse: newPulse),
            newOrionWeights: input.globalSettings.currentOrionWeights,
            perSymbolOverrides: symbolOverrides.isEmpty ? nil : symbolOverrides,
            learningNotes: learningNotes
        )
    }
    
    // MARK: - Performance Analysis with Drawdown Penalty
    
    private struct ModuleAnalysis {
        var orionAdjustment: Double?
        var phoenixAdjustment: Double?
        var atlasAdjustment: Double?
        var shouldCreateOverride: Bool = false
    }
    
    private func analyzeModulePerformance(log: PerformanceLog, safeguards: ChironOptimizationInput.Safeguards) -> ModuleAnalysis {
        var analysis = ModuleAnalysis()
        let maxChange = safeguards.maxWeightChangePerStep
        
        // Analyze Orion
        if log.moduleResults.orion.trades >= safeguards.minTradesForLearning {
            let orion = log.moduleResults.orion
            analysis.orionAdjustment = calculateAdjustmentWithDrawdown(
                winRate: orion.winRate,
                pnlPercent: orion.pnlPercent,
                avgR: orion.avgR,
                maxDrawdown: orion.maxDrawdown,
                maxChange: maxChange
            )
            
            // Flag for override if performance is exceptional (good or bad)
            if abs(orion.pnlPercent) > 15 || orion.maxDrawdown > 20 {
                analysis.shouldCreateOverride = true
            }
            
            print("🧠 Orion: Trades=\(orion.trades), WR=\(String(format: "%.0f", orion.winRate))%, PnL=\(String(format: "%.1f", orion.pnlPercent))%, DD=\(String(format: "%.1f", orion.maxDrawdown))% → Δ\(String(format: "%+.3f", analysis.orionAdjustment ?? 0))")
        }
        
        // Analyze Phoenix
        if let phoenix = log.moduleResults.phoenix, phoenix.trades >= safeguards.minTradesForLearning {
            analysis.phoenixAdjustment = calculateAdjustmentWithDrawdown(
                winRate: phoenix.winRate,
                pnlPercent: phoenix.pnlPercent,
                avgR: phoenix.avgR,
                maxDrawdown: phoenix.maxDrawdown,
                maxChange: maxChange
            )
            
            if abs(phoenix.pnlPercent) > 15 || phoenix.maxDrawdown > 20 {
                analysis.shouldCreateOverride = true
            }
            
            print("🧠 Phoenix: Trades=\(phoenix.trades), WR=\(String(format: "%.0f", phoenix.winRate))%, PnL=\(String(format: "%.1f", phoenix.pnlPercent))%, DD=\(String(format: "%.1f", phoenix.maxDrawdown))% → Δ\(String(format: "%+.3f", analysis.phoenixAdjustment ?? 0))")
        }
        
        // Analyze Atlas
        if log.moduleResults.atlas.trades >= safeguards.minTradesForLearning {
            let atlas = log.moduleResults.atlas
            analysis.atlasAdjustment = calculateAdjustmentWithDrawdown(
                winRate: atlas.winRate,
                pnlPercent: atlas.pnlPercent,
                avgR: atlas.avgR,
                maxDrawdown: atlas.maxDrawdown,
                maxChange: maxChange
            )
        }
        
        return analysis
    }
    
    /// Enhanced adjustment calculation with drawdown penalty
    private func calculateAdjustmentWithDrawdown(winRate: Double, pnlPercent: Double, avgR: Double, maxDrawdown: Double, maxChange: Double) -> Double {
        // Base scores (same as before)
        let wrScore = (winRate - 50.0) / 50.0  // -1 to +1
        let pnlScore = pnlPercent / 20.0       // normalized around ±20%
        let rScore = (avgR - 1.0) / 2.0        // 1R=neutral
        
        // DRAWDOWN PENALTY (NEW)
        // DD < 10% = no penalty
        // DD 10-20% = small penalty (-0.1 to -0.2)
        // DD > 20% = heavy penalty (up to -0.5)
        var ddPenalty: Double = 0
        if maxDrawdown > 10 {
            ddPenalty = -min(0.5, (maxDrawdown - 10) / 20.0)  // Max -0.5 penalty
        }
        
        // Weighted combination: WR 30%, PnL 35%, AvgR 15%, DD 20%
        let compositeScore = (wrScore * 0.30) + (pnlScore * 0.35) + (rScore * 0.15) + (ddPenalty * 0.20)
        
        // Scale and clamp
        let adjustment = compositeScore * maxChange
        return clamp(adjustment, min: -maxChange, max: maxChange)
    }
    
    // MARK: - Symbol Override Generation
    
    private func generateSymbolOverride(log: PerformanceLog, analysis: ModuleAnalysis) -> ChironOptimizationOutput.PerSymbolOverride? {
        guard analysis.shouldCreateOverride else { return nil }
        
        // Create local weight adjustments for this symbol
        var localWeights: [String: Double] = [:]
        
        if let orionAdj = analysis.orionAdjustment {
            // If Orion performed well, boost trend-following
            localWeights["trend"] = orionAdj > 0 ? 0.35 : 0.25
            localWeights["momentum"] = orionAdj > 0 ? 0.25 : 0.15
        }
        
        if let phoenixAdj = analysis.phoenixAdjustment {
            // If Phoenix performed well, boost mean-reversion
            localWeights["meanReversion"] = phoenixAdj > 0 ? 0.30 : 0.10
        }
        
        guard !localWeights.isEmpty else { return nil }
        
        return ChironOptimizationOutput.PerSymbolOverride(
            symbol: log.symbol,
            timeframe: log.timeframe,
            regime: log.regime,
            orionLocalWeights: localWeights
        )
    }
    
    private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        return Swift.max(minVal, Swift.min(maxVal, value))
    }
}
