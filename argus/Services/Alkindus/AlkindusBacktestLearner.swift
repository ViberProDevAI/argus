import Foundation

// MARK: - Alkindus Backtest Learner
/// Geçmiş veri üzerinde indikatör ve formasyonların başarı oranlarını öğrenir.
/// "RSI > 70 olduğunda ne oldu? %65 düşme mi?"

@MainActor
final class AlkindusBacktestLearner {
    static let shared = AlkindusBacktestLearner()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("backtest_learnings.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct BacktestLearnings: Codable {
        var indicators: [String: IndicatorLearnings]
        var patterns: [String: PatternLearnings]
        var lastBacktestDate: Date?
        var totalSymbolsProcessed: Int
        
        static var empty: BacktestLearnings {
            BacktestLearnings(indicators: [:], patterns: [:], lastBacktestDate: nil, totalSymbolsProcessed: 0)
        }
    }
    
    struct IndicatorLearnings: Codable {
        var conditions: [String: TimeframeLearnings]
    }
    
    struct PatternLearnings: Codable {
        var timeframes: [String: TimeframeLearnings]
    }
    
    struct TimeframeLearnings: Codable {
        var symbols: [String: SymbolStats]
        var aggregate: AggregateStats
    }
    
    struct SymbolStats: Codable {
        var attempts: Int
        var correct: Int
        var hitRate: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
    }
    
    struct AggregateStats: Codable {
        var attempts: Int
        var correct: Int
        var hitRate: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
    }
    
    // MARK: - Backtest Configuration
    
    struct BacktestConfig {
        let timeframes: [String]
        let horizons: [String: Int]
        let minBarsRequired: Int
        
        static var standard: BacktestConfig {
            BacktestConfig(
                timeframes: ["1d", "4h", "1h"],
                horizons: ["1d": 7, "4h": 6, "1h": 24],
                minBarsRequired: 100
            )
        }
    }
    
    // MARK: - Result Models
    
    struct AlkindusBacktestResult {
        let symbol: String
        let timeframe: String
        let processed: Int
        let learned: [String]
    }
    
    struct AlkindusBatchResult {
        let results: [AlkindusBacktestResult]
        let totalProcessed: Int
        
        var summary: String {
            "\(results.count) sembol/timeframe kombinasyonu, toplam \(totalProcessed) bar işlendi"
        }
    }
    
    // MARK: - API
    
    /// Runs backtest on a symbol using historical candles
    func runBacktest(symbol: String, candles: [Candle], timeframe: String, config: BacktestConfig = .standard) -> AlkindusBacktestResult {
        let horizon = config.horizons[timeframe] ?? 7
        guard candles.count >= config.minBarsRequired + horizon else {
            return AlkindusBacktestResult(symbol: symbol, timeframe: timeframe, processed: 0, learned: [])
        }
        
        var learnings: [String] = []
        var data = loadData()
        
        let evaluatableCount = candles.count - horizon
        
        for i in 14..<evaluatableCount {
            let slice = Array(candles[0...i])
            let futureSlice = Array(candles[i..<(i + horizon)])
            
            let closes = slice.map { $0.close }
            let currentPrice = closes.last ?? 0
            let futurePrice = futureSlice.last?.close ?? currentPrice
            let priceChange = (futurePrice - currentPrice) / currentPrice
            let wasSuccess = priceChange > 0.02
            
            // RSI Analysis
            if let rsi = IndicatorService.lastRSI(values: closes) {
                let condition: String
                if rsi > 70 {
                    condition = "overbought"
                } else if rsi < 30 {
                    condition = "oversold"
                } else {
                    condition = "neutral"
                }
                
                recordIndicatorResult(
                    data: &data,
                    indicator: "rsi",
                    condition: condition,
                    timeframe: timeframe,
                    symbol: symbol,
                    wasSuccess: condition == "oversold" ? wasSuccess : !wasSuccess
                )
            }
            
            // MACD Analysis
            let macd = IndicatorService.lastMACD(values: closes)
            if let histogram = macd.histogram {
                let condition = histogram > 0 ? "bullish" : "bearish"
                recordIndicatorResult(
                    data: &data,
                    indicator: "macd",
                    condition: condition,
                    timeframe: timeframe,
                    symbol: symbol,
                    wasSuccess: condition == "bullish" ? wasSuccess : !wasSuccess
                )
            }
            
            // Stochastic Analysis
            if slice.count >= 14 {
                let stoch = IndicatorService.lastStochastic(candles: slice)
                if let k = stoch.k {
                    let condition: String
                    if k > 80 {
                        condition = "overbought"
                    } else if k < 20 {
                        condition = "oversold"
                    } else {
                        condition = "neutral"
                    }
                    
                    recordIndicatorResult(
                        data: &data,
                        indicator: "stochastic",
                        condition: condition,
                        timeframe: timeframe,
                        symbol: symbol,
                        wasSuccess: condition == "oversold" ? wasSuccess : !wasSuccess
                    )
                }
            }
            
            // ADX Analysis
            if slice.count >= 14 {
                if let adx = IndicatorService.lastADX(candles: slice) {
                    let condition = adx > 25 ? "strong_trend" : "weak_trend"
                    recordIndicatorResult(
                        data: &data,
                        indicator: "adx",
                        condition: condition,
                        timeframe: timeframe,
                        symbol: symbol,
                        wasSuccess: wasSuccess
                    )
                }
            }
            
            // Bollinger Bands Analysis
            let bb = IndicatorService.lastBollingerBands(values: closes)
            if let upper = bb.upper, let lower = bb.lower {
                let condition: String
                if currentPrice > upper {
                    condition = "above_upper"
                } else if currentPrice < lower {
                    condition = "below_lower"
                } else {
                    condition = "within_bands"
                }
                
                recordIndicatorResult(
                    data: &data,
                    indicator: "bollinger",
                    condition: condition,
                    timeframe: timeframe,
                    symbol: symbol,
                    wasSuccess: condition == "below_lower" ? wasSuccess : (condition == "above_upper" ? !wasSuccess : wasSuccess)
                )
            }
        }
        
        data.lastBacktestDate = Date()
        data.totalSymbolsProcessed += 1
        saveData(data)
        
        learnings.append("RSI, MACD, Stochastic, ADX, Bollinger analiz edildi")
        
        return AlkindusBacktestResult(
            symbol: symbol,
            timeframe: timeframe,
            processed: evaluatableCount - 14,
            learned: learnings
        )
    }
    
    /// Batch backtest for multiple symbols
    func runBatchBacktest(symbols: [String], fetchCandles: (String, String) async -> [Candle]?) async -> AlkindusBatchResult {
        var results: [AlkindusBacktestResult] = []
        let config = BacktestConfig.standard
        
        for symbol in symbols {
            for timeframe in config.timeframes {
                if let candles = await fetchCandles(symbol, timeframe) {
                    let result = runBacktest(symbol: symbol, candles: candles, timeframe: timeframe, config: config)
                    results.append(result)
                    print("📊 Alkindus Backtest: \(symbol) \(timeframe) - \(result.processed) bar işlendi")
                }
            }
        }
        
        return AlkindusBatchResult(results: results, totalProcessed: results.reduce(0) { $0 + $1.processed })
    }
    
    /// Gets indicator success rate for a symbol
    func getIndicatorAdvice(indicator: String, condition: String, timeframe: String, symbol: String) -> Double? {
        let data = loadData()
        return data.indicators[indicator]?.conditions[condition]?.symbols[symbol]?.hitRate
    }
    
    /// Gets best indicators for a symbol
    func getBestIndicators(for symbol: String, timeframe: String) -> [(indicator: String, condition: String, hitRate: Double)] {
        let data = loadData()
        var results: [(String, String, Double)] = []
        
        for (indicator, learnings) in data.indicators {
            for (condition, tfLearnings) in learnings.conditions {
                if let stats = tfLearnings.symbols[symbol], stats.attempts >= 10 {
                    results.append((indicator, condition, stats.hitRate))
                }
            }
        }
        
        return results.sorted { $0.2 > $1.2 }
    }
    
    /// Gets aggregate stats for all symbols
    func getAggregateStats() -> [String: [String: Double]] {
        let data = loadData()
        var result: [String: [String: Double]] = [:]
        
        for (indicator, learnings) in data.indicators {
            result[indicator] = [:]
            for (condition, tfLearnings) in learnings.conditions {
                result[indicator]?[condition] = tfLearnings.aggregate.hitRate
            }
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func recordIndicatorResult(
        data: inout BacktestLearnings,
        indicator: String,
        condition: String,
        timeframe: String,
        symbol: String,
        wasSuccess: Bool
    ) {
        if data.indicators[indicator] == nil {
            data.indicators[indicator] = IndicatorLearnings(conditions: [:])
        }
        
        if data.indicators[indicator]?.conditions[condition] == nil {
            data.indicators[indicator]?.conditions[condition] = TimeframeLearnings(
                symbols: [:],
                aggregate: AggregateStats(attempts: 0, correct: 0)
            )
        }
        
        if data.indicators[indicator]?.conditions[condition]?.symbols[symbol] == nil {
            data.indicators[indicator]?.conditions[condition]?.symbols[symbol] = SymbolStats(attempts: 0, correct: 0)
        }
        
        data.indicators[indicator]?.conditions[condition]?.symbols[symbol]?.attempts += 1
        data.indicators[indicator]?.conditions[condition]?.aggregate.attempts += 1
        
        if wasSuccess {
            data.indicators[indicator]?.conditions[condition]?.symbols[symbol]?.correct += 1
            data.indicators[indicator]?.conditions[condition]?.aggregate.correct += 1
        }
    }
    
    private func loadData() -> BacktestLearnings {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(BacktestLearnings.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: BacktestLearnings) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}
