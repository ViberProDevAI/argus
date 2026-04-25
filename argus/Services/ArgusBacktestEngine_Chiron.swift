import Foundation

// MARK: - Chiron Integration
extension ArgusBacktestEngine {
    
    /// Converts a backtest result into a Chiron Performance Log and triggers optimization.
    func feedBacktestToChiron(symbol: String, result: BacktestResult) async {
        print("🧠 Chiron: Analyzing backtest results for \(symbol) - Strategy: \(result.config.strategy.rawValue)...")
        
        // 0. Save individual trades to DataLake for learning
        await saveBacktestTradesToDataLake(symbol: symbol, result: result)
        
        // 1. Convert to PerformanceLog - metrics based on strategy type
        let metrics = calculateMetrics(trades: result.trades, finalCapital: result.finalCapital, initialCapital: result.config.initialCapital, maxDrawdown: result.maxDrawdown)
        
        // Determine which module to attribute the metrics to
        let moduleResults: PerformanceLog.ModuleResults
        let strategyTypeString: String
        
        switch result.config.strategy {
        case .orionV2:
            moduleResults = PerformanceLog.ModuleResults(
                atlas: .empty,
                orion: metrics,
                phoenix: nil,
                aether: nil,
                hermes: nil
            )
            strategyTypeString = "orionV2"
            
        case .phoenixChannel:
            moduleResults = PerformanceLog.ModuleResults(
                atlas: .empty,
                orion: .empty,
                phoenix: metrics,
                aether: nil,
                hermes: nil
            )
            strategyTypeString = "phoenixChannel"
            
        case .aggressive:
            // Phoenix-based aggressive
            moduleResults = PerformanceLog.ModuleResults(
                atlas: .empty,
                orion: .empty,
                phoenix: metrics,
                aether: nil,
                hermes: nil
            )
            strategyTypeString = "aggressive_phoenix"
            
        case .argusStandard, .conservative:
            // Blended - attribute to both
            moduleResults = PerformanceLog.ModuleResults(
                atlas: metrics,
                orion: metrics,
                phoenix: nil,
                aether: nil,
                hermes: nil
            )
            strategyTypeString = result.config.strategy.rawValue
            
        default:
            // Technical strategies - Orion based
            moduleResults = PerformanceLog.ModuleResults(
                atlas: .empty,
                orion: metrics,
                phoenix: nil,
                aether: nil,
                hermes: nil
            )
            strategyTypeString = result.config.strategy.rawValue
        }
        
        let log = PerformanceLog(
            symbol: symbol,
            timeframe: "D1", // Daily candles assumed
            regime: detectRegimeFromBacktest(result: result),  // DYNAMIC REGIME DETECTION
            dataHealth: 100.0, // Backtest data is clean
            moduleResults: moduleResults,
            orionSubStrategies: [],
            hermesStatus: PerformanceLog.HermesStatus(available: false, dataHealth: 0),
            historicalSteps: nil,
            strategyType: strategyTypeString
        )
        
        // 2. Build Input
        let currentResult = ChironRegimeEngine.shared.evaluate(context: ChironContext(
            atlasScore: 50, orionScore: 50, aetherScore: 50, demeterScore: nil, phoenixScore: nil, hermesScore: nil, athenaScore: nil,
            symbol: symbol, orionTrendStrength: nil, chopIndex: nil, volatilityHint: nil, isHermesAvailable: false
        ))
        
        let input = ChironOptimizationInput(
            globalSettings: ChironOptimizationInput.GlobalSettings(
                currentArgusWeights: ChironOptimizationInput.ArgusWeights(
                    core: currentResult.coreWeights,
                    pulse: currentResult.pulseWeights
                ),
                currentOrionWeights: ChironOptimizationInput.OrionWeights(trend: 0.3, momentum: 0.2, relStrength: 0.2, volatility: 0.1, pullback: 0.1, riskReward: 0.1),
                safeguards: ChironOptimizationInput.Safeguards(
                    minTradesForLearning: 5,      // Lowered from 10
                    maxWeightChangePerStep: 0.10,  // Increased from 0.05
                    minModuleWeightCore: 0.05,     // Lowered from 0.1
                    minModuleWeightPulse: 0.05     // Lowered from 0.1
                )
            ),
            performanceLogs: [log]
        )
        
        // DEBUG: Print what we're sending
        print("🧠 Chiron Input: Strategy=\(strategyTypeString) Trades=\(metrics.trades) WinRate=\(String(format: "%.1f", metrics.winRate))% PnL=\(String(format: "%.1f", metrics.pnlPercent))%")
        
        // 3. Call Service
        do {
            let optimized = try await ChironOptimizationService.shared.optimize(input: input)
            
            // DEBUG: Print what we got back
            print("🧠 Chiron Output: Notes=\(optimized.learningNotes.count)")
            print("🧠 Chiron: New Orion Pulse Weight = \(String(format: "%.2f", optimized.newArgusWeights.pulse.orion))")
            if let phxWeight = optimized.newArgusWeights.pulse.phoenix {
                print("🧠 Chiron: New Phoenix Pulse Weight = \(String(format: "%.2f", phxWeight))")
            }
            
            // 4. Update Engine
            await MainActor.run {
                ChironRegimeEngine.shared.loadDynamicWeights(optimized)
                print("🧠 Chiron: Optimization applied for \(strategyTypeString)!")
                for (i, note) in optimized.learningNotes.enumerated() {
                    print("   📝 Note \(i+1): \(note)")
                }
            }
            
            // 5. ALSO update ChironWeightStore for UI display (NEW!)
            let newWeights = ChironModuleWeights(
                orion: optimized.newArgusWeights.pulse.orion,
                atlas: optimized.newArgusWeights.pulse.atlas,
                phoenix: optimized.newArgusWeights.pulse.phoenix ?? 0.2,
                aether: optimized.newArgusWeights.pulse.aether ?? 0.1,
                hermes: optimized.newArgusWeights.pulse.hermes ?? 0.1,
                demeter: optimized.newArgusWeights.pulse.demeter ?? 0.1,
                athena: optimized.newArgusWeights.pulse.athena ?? 0.05,
                updatedAt: Date(),
                confidence: 0.8,
                reasoning: "Backtest-based optimization"
            )
            await ChironWeightStore.shared.updateWeights(symbol: symbol, engine: .pulse, weights: newWeights)
            print("🧠 Chiron: WeightStore updated for \(symbol) - O:\(String(format: "%.0f", newWeights.orion * 100))% A:\(String(format: "%.0f", newWeights.atlas * 100))% P:\(String(format: "%.0f", newWeights.phoenix * 100))%")
            
        } catch {
            print("🧠 Chiron Error: \(error.localizedDescription)")
        }
    }
    
    private func calculateMetrics(trades: [BacktestTrade], finalCapital: Double, initialCapital: Double, maxDrawdown: Double) -> PerformanceLog.ModuleStats {
        let count = trades.count
        guard count > 0 else {
            return .empty
        }
        
        let wins = trades.filter { $0.pnl > 0 }.count
        let winRate = Double(wins) / Double(count) * 100.0
        
        // PnL %
        let pnlPercent = ((finalCapital - initialCapital) / initialCapital) * 100.0
        
        // Average R (simplified - PnL / trade count normalized)
        let totalPnL = trades.reduce(0.0) { $0 + $1.pnl }
        let avgPnLPerTrade = totalPnL / Double(count)
        let avgR = initialCapital > 0 ? (avgPnLPerTrade / (initialCapital * 0.01)) : 1.0 // 1% risk base
        
        return PerformanceLog.ModuleStats(
            trades: count,
            winRate: winRate,
            avgR: avgR,
            pnlPercent: pnlPercent,
            maxDrawdown: maxDrawdown
        )
    }
    
    // MARK: - Dynamic Regime Detection from Backtest Data
    
    /// Analyzes backtest trades to determine market regime
    private func detectRegimeFromBacktest(result: BacktestResult) -> PerformanceLog.RegimeInfo {
        let trades = result.trades
        
        // 1. Determine Trend State from trade distribution
        let trendState: String
        if trades.isEmpty {
            trendState = "MIXED"
        } else {
            // Count winning streaks and losing streaks
            var winStreak = 0
            var maxWinStreak = 0
            var loseStreak = 0
            var maxLoseStreak = 0
            
            for trade in trades {
                if trade.pnl > 0 {
                    winStreak += 1
                    loseStreak = 0
                    maxWinStreak = max(maxWinStreak, winStreak)
                } else {
                    loseStreak += 1
                    winStreak = 0
                    maxLoseStreak = max(maxLoseStreak, loseStreak)
                }
            }
            
            // Long win/lose streaks suggest trending, short streaks suggest ranging
            let maxStreak = max(maxWinStreak, maxLoseStreak)
            if maxStreak >= 5 {
                trendState = "TRENDING"
            } else if maxStreak <= 2 {
                trendState = "RANGING"
            } else {
                trendState = "MIXED"
            }
        }
        
        // 2. Determine Macro from PnL and Drawdown
        let macro: String
        let pnlPercent = ((result.finalCapital - result.config.initialCapital) / result.config.initialCapital) * 100
        
        if pnlPercent > 10 && result.maxDrawdown < 15 {
            macro = "RISK_ON"  // Good returns, controlled risk
        } else if pnlPercent < -5 || result.maxDrawdown > 25 {
            macro = "RISK_OFF"  // Losses or high drawdown
        } else {
            macro = "MIXED"
        }
        
        print("🧠 Regime Detection: \(trendState) / \(macro) (PnL: \(String(format: "%.1f", pnlPercent))%, DD: \(String(format: "%.1f", result.maxDrawdown))%)")
        
        return PerformanceLog.RegimeInfo(macro: macro, trendState: trendState)
    }
    
    // MARK: - DataLake Trade Logging
    
    /// Saves individual backtest trades to ChironDataLake for learning
    private func saveBacktestTradesToDataLake(symbol: String, result: BacktestResult) async {
        let trades = result.trades
        guard !trades.isEmpty else { return }
        
        // Determine engine based on strategy
        let engine: AutoPilotEngine = {
            switch result.config.strategy {
            case .orionV2:
                return .pulse  // Technical strategies
            case .argusStandard, .conservative:
                return .corse  // Fundamental blend
            default:
                return .pulse
            }
        }()
        
        // Convert each BacktestTrade to TradeOutcomeRecord
        for trade in trades {
            let pnlPercent = trade.entryPrice > 0 ? ((trade.exitPrice - trade.entryPrice) / trade.entryPrice) * 100.0 : 0
            
            let record = TradeOutcomeRecord(
                id: UUID(),
                symbol: symbol,
                engine: engine,
                entryDate: trade.entryDate,
                exitDate: trade.exitDate,
                entryPrice: trade.entryPrice,
                exitPrice: trade.exitPrice,
                pnlPercent: pnlPercent,
                exitReason: trade.exitReason,
                orionScoreAtEntry: nil,  // Backtest doesn't have these
                atlasScoreAtEntry: nil,
                aetherScoreAtEntry: nil,
                phoenixScoreAtEntry: nil,
                allModuleScores: nil,
                systemDecision: nil,
                ignoredWarnings: nil,
                regime: nil
            )
            
            await ChironDataLakeService.shared.logTrade(record)
        }
        
        print("🧠 Chiron DataLake: \(trades.count) backtest trades saved for \(symbol)")
    }
}

