import Foundation
import Combine
import SwiftUI

@globalActor actor DemeterActor {
    static let shared = DemeterActor()
}

@DemeterActor
final class DemeterEngine: ObservableObject {
    static let shared = DemeterEngine()
    
    // State
    @Published var sectorScores: [DemeterScore] = []
    @Published var activeShocks: [ShockFlag] = []
    @Published var correlationMatrix: CorrelationMatrix?
    @Published var lastAnalysisDate: Date?
    @Published var isRunning: Bool = false
    
    // Cache
    private var driverCache: [String: [Candle]] = [:]
    
    // MARK: - Main Analysis Loop
    func analyze() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        let etfs = SectorETF.allCases
        
        // 1. Fetch Drivers (Parallel)
        async let oilTask = fetchDriver(symbol: DemeterLabor.Config.Symbols.oil, lookback: 90)
        async let rateTask = fetchDriver(symbol: DemeterLabor.Config.Symbols.rates, lookback: 90)
        async let dxyTask = fetchDriver(symbol: DemeterLabor.Config.Symbols.dollar, lookback: 90)
        async let vixTask = fetchDriver(symbol: DemeterLabor.Config.Symbols.vix, lookback: 30) // Short term
        async let spyTask = fetchDriver(symbol: DemeterLabor.Config.Symbols.spy, lookback: 90)
        
        let (oil, rates, dxy, vix, spy) = await (oilTask, rateTask, dxyTask, vixTask, spyTask)
        
        print("🌾 Demeter Debug: Oil: \(oil.count), Rates: \(rates.count), DXY: \(dxy.count), VIX: \(vix.count), SPY: \(spy.count)")
        
        // 2. Detect Shocks
        let shocks = detectShocks(oil: oil, rates: rates, dxy: dxy, vix: vix)
        self.activeShocks = shocks
        
        // 3. Analyze Sectors
        var scores: [DemeterScore] = []
        var returnsDict: [String: [Double]] = [:] 
        
        // Using TaskGroup for Sectors
        await withTaskGroup(of: (SectorETF, [Candle]?).self) { group in
            for etf in etfs {
                group.addTask {
                    let val = await MarketDataStore.shared.ensureCandles(symbol: etf.rawValue, timeframe: "1day")
                    if val.value == nil { print("⚠️ Demeter: Failed to fetch candles for \(etf.rawValue)") }
                    return (etf, val.value)
                }
            }
            
            for await (etf, candles) in group {
                guard let c = candles, !c.isEmpty else {
                    print("⚠️ Demeter: Skipping \(etf.rawValue) due to empty candles.")
                    continue
                }
                
                // Score Sector
                if let score = self.scoreSector(etf: etf, candles: c, shocks: shocks, spy: spy, vix: vix) {
                    scores.append(score)
                } else {
                    print("⚠️ Demeter: Failed to score \(etf.rawValue)")
                }
                
                // Prepare Correlation Data
                let closes = c.suffix(61).map { $0.close }
                let logs = DemeterLabor.logReturns(Array(closes))
                if logs.count == 60 {
                    returnsDict[etf.rawValue] = logs
                }
            }
        }
        
        // 4. Update State
        self.sectorScores = scores.sorted(by: { $0.totalScore > $1.totalScore })
        self.correlationMatrix = DemeterEngine.calculateCorrelationMatrix(returns: returnsDict)
        self.lastAnalysisDate = Date()
        
        print("🌾 Demeter: Analysis Complete. Scores Generated: \(scores.count). Shocks: \(shocks.count).")
    }
    
    // MARK: - Driver Fetching
    private func fetchDriver(symbol: String, lookback: Int) async -> [Candle] {
        // We use Main Store to utilize standard cache if available, or direct fetch
        // For Drivers, we might need a dedicated pathway if they aren't standard stocks?
        // MarketDataStore supports generic symbols.
        let val = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
        return val.value ?? []
    }
    
    // MARK: - Shock Detection Logic
    private func detectShocks(oil: [Candle], rates: [Candle], dxy: [Candle], vix: [Candle]) -> [ShockFlag] {
        var flags: [ShockFlag] = []
        
        // 1. Oil Shock
        if let oilRes = detectChangeShock(candles: oil, days: DemeterLabor.Config.Lookback.oil, upThresh: DemeterLabor.Config.Thresholds.oilShockUp, downThresh: DemeterLabor.Config.Thresholds.oilShockDown, type: .energy) {
            flags.append(oilRes)
        }
        
        // 2. Rate Shock (Unique logic: Absolute Change)
        if let rateRes = detectAbsoluteShock(candles: rates, days: DemeterLabor.Config.Lookback.rates, upThresh: DemeterLabor.Config.Thresholds.rateShockUp, downThresh: DemeterLabor.Config.Thresholds.rateShockDown, type: .rates) {
            flags.append(rateRes)
        }
        
        // 3. Dollar Shock
        if let dxyRes = detectChangeShock(candles: dxy, days: DemeterLabor.Config.Lookback.dollar, upThresh: DemeterLabor.Config.Thresholds.dollarShockUp, downThresh: DemeterLabor.Config.Thresholds.dollarShockDown, type: .dollar) {
            flags.append(dxyRes)
        }
        
        // 4. Volatility Shock (Level based)
        if let lastVix = vix.last?.close {
            if lastVix > DemeterLabor.Config.Thresholds.volShockPanic {
                flags.append(ShockFlag(type: .vol, direction: .positive, severity: 100, description: "VIX > 35 (Panik)", detectedAt: Date()))
            } else if lastVix > DemeterLabor.Config.Thresholds.volShockStress {
                flags.append(ShockFlag(type: .vol, direction: .positive, severity: 50, description: "VIX > 25 (Stres)", detectedAt: Date()))
            }
        }
        
        return flags
    }
    
    // Helper: Percentage Change Shock
    private func detectChangeShock(candles: [Candle], days: Int, upThresh: Double, downThresh: Double, type: ShockType) -> ShockFlag? {
        // Güvenli bounds kontrolü
        let oldIndex = candles.count - days - 1
        guard candles.count > days,
              oldIndex >= 0,
              let currentCandle = candles.last else {
            return nil
        }
        let current = currentCandle.close
        let old = candles[oldIndex].close
        guard old > 0 else { return nil } // Division by zero koruması
        let change = (current - old) / old
        
        if change > upThresh {
            return ShockFlag(type: type, direction: .positive, severity: min(abs(change)*100, 100), description: "\(days) günde +%\(String(format: "%.1f", change*100))", detectedAt: Date())
        } else if change < downThresh {
            return ShockFlag(type: type, direction: .negative, severity: min(abs(change)*100, 100), description: "\(days) günde %\(String(format: "%.1f", change*100))", detectedAt: Date())
        }
        return nil
    }
    
    // Helper: Absolute Change Shock (for Rates)
    private func detectAbsoluteShock(candles: [Candle], days: Int, upThresh: Double, downThresh: Double, type: ShockType) -> ShockFlag? {
        // Güvenli bounds kontrolü
        let oldIndex = candles.count - days - 1
        guard candles.count > days,
              oldIndex >= 0,
              let currentCandle = candles.last else {
            return nil
        }
        let current = currentCandle.close
        let old = candles[oldIndex].close
        let change = current - old
        
        if change > upThresh {
             return ShockFlag(type: type, direction: .positive, severity: 75, description: "\(days) günde +\(String(format: "%.2f", change)) puan", detectedAt: Date())
        } else if change < downThresh {
             return ShockFlag(type: type, direction: .negative, severity: 75, description: "\(days) günde \(String(format: "%.2f", change)) puan", detectedAt: Date())
        }
        return nil
    }
    
    // MARK: - Sector Scoring
    private func scoreSector(etf: SectorETF, candles: [Candle], shocks: [ShockFlag], spy: [Candle], vix: [Candle]) -> DemeterScore? {
        // 1. Momentum (35%)
        // Simple MA logic
        let ma50 = candles.suffix(50).map { $0.close }.reduce(0, +) / 50.0
        let current = candles.last?.close ?? 0.0
        let momScoreRaw = (current > ma50) ? 75.0 : 25.0
        // Adjust by 20 day ROC
        let rocArray = DemeterLabor.logReturns(candles.map { $0.close })
        let roc20 = rocArray.suffix(20).reduce(0, +)
        let momScore = min(max(momScoreRaw + (roc20 * 100), 0), 100)
        
        // 2. Shock Impact (25%)
        var impactSum: Double = 0.0
        var contributions: [String: Double] = [:]
        
        for shock in shocks {
            let rules = DemeterLabor.getImpact(for: shock.type, direction: shock.direction)
            if let effect = rules[etf] {
                impactSum += effect
                contributions[shock.type.displayName] = effect
            }
        }
        // Normalize: 50 is base. +20 -> 70.
        let impactScore = min(max(50.0 + impactSum, 0), 100)
        
        // 3. Breadth / RS (20%)
        let rsSeries = DemeterLabor.relativeStrengthRatio(asset: candles.map { $0.close }, benchmark: spy.map { $0.close })
        let rsSlope = DemeterLabor.slope(Array(rsSeries.suffix(20)))
        let breadthScore = min(max(((rsSlope + 0.005) / 0.01) * 100.0, 0.0), 100.0)
        
        // 4. Regime (20%)
        // VIX < 20 -> RiskOn (+), VIX > 25 -> RiskOff (-)
        // SPY > SMA200 -> RiskOn
        let vixVal = vix.last?.close ?? 20.0
        let spyMa200 = spy.suffix(200).map{$0.close}.reduce(0, +) / Double(min(spy.count, 200))
        let spyVal = spy.last?.close ?? 0.0
        
        var regimeBase = 50.0
        if vixVal < 20 { regimeBase += 15 }
        if vixVal > 25 { regimeBase -= 15 }
        if spyVal > spyMa200 { regimeBase += 15 } else { regimeBase -= 15 }
        let regimeScore = min(max(regimeBase, 0), 100)
        
        // TOTAL WEIGHTED
        let total = (momScore * 0.35) + (impactScore * 0.25) + (breadthScore * 0.20) + (regimeScore * 0.20)
        
        let advice = DemeterLabor.getAdvice(for: etf, score: total, shocks: shocks)
        
        // Calculate confidence based on data quality
        let dataPointsUsed = min(candles.count, 50) + min(spy.count, 200) + min(vix.count, 30)
        let expectedDataPoints = 280.0 // 50 + 200 + 30
        let calculatedConfidence = min(Double(dataPointsUsed) / expectedDataPoints, 1.0)
        
        return DemeterScore(
            sector: etf,
            totalScore: total,
            momentumScore: momScore,
            shockImpactScore: impactScore,
            regimeScore: regimeScore,
            breadthScore: breadthScore,
            activeShocks: shocks,
            driverContributions: contributions,
            confidence: calculatedConfidence, // Data-driven confidence
            advice: advice,
            generatedAt: Date()
        )
    }
    
    // MARK: - Correlation Logic (Static Helper)
    static func calculateCorrelationMatrix(returns: [String: [Double]]) -> CorrelationMatrix {
        var pairs: [String: Double] = [:]
        let keys = Array(returns.keys)
        
        for i in 0..<keys.count {
            for j in (i+1)..<keys.count {
                let k1 = keys[i]
                let k2 = keys[j]
                
                if let r1 = returns[k1], let r2 = returns[k2] {
                    let corr = DemeterLabor.pearsonCorrelation(r1, r2)
                    let key = "\(k1)_\(k2)" // Store one way
                    pairs[key] = corr
                }
            }
        }
        
        return CorrelationMatrix(pairs: pairs, date: Date())
    }
    
    // Multiplier Hook (Legacy Support)
    func getMultipliers(for symbol: String) -> (priority: Double, size: Double, cooldown: Bool) {
        guard let etf = SectorMap.getSector(for: symbol),
              let score = sectorScores.first(where: { $0.sector == etf }) else {
            return (1.0, 1.0, false)
        }
        
        // Logic: Score > 75 -> Priority. Score < 30 -> Size Penalty.
        var priority = 1.0
        var size = 1.0
        
        if score.totalScore > 75 { priority = 1.5 }
        if score.totalScore < 30 { size = 0.5 }
        
        return (priority, size, false)
    }
}
