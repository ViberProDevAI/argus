import Foundation

/// "Phoenix" - Scenario & Level Engine
/// Produces trading scenarios (Entry, Invalidation, Targets) without executing trades.
/// Features: Linear Regression Channel, ATR Buffers, RSI Reversals, Divergence Detection.
actor PhoenixScenarioEngine {
    static let shared = PhoenixScenarioEngine()
    
    // Cache: Key = "SYMBOL_TIMEFRAME", Value = (Date, Advice)
    private var cache: [String: (Date, PhoenixAdvice)] = [:]
    
    private init() {}
    
    // MARK: - Public API
    
    func analyze(symbol: String, timeframe: PhoenixTimeframe) async -> PhoenixAdvice {
        let cacheKey = "\(symbol)_\(timeframe.rawValue)"
        
        // 1. Cache Check (60s validity)
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.0) < 60 {
            return cached.1
        }
        
        var advice: PhoenixAdvice
        
        do {
            // 2. Resolve Configuration
            let config = PhoenixConfig()
            
            // 3. Fetch Data (with Resampling if needed)
            let candles = try await fetchAndResampleData(symbol: symbol, timeframe: timeframe)
            
            // 4. Validate Data Sufficiency
            if candles.count < config.minBars {
                advice = PhoenixAdvice.insufficient(symbol: symbol, timeframe: timeframe)
            } else {
                // 5. Calculate Scenarios
                advice = calculate(candles: candles, symbol: symbol, timeframe: timeframe, config: config)
            }
            
        } catch {
            print("🔥 Phoenix Engine Error: \(error)")
            advice = PhoenixAdvice.insufficient(symbol: symbol, timeframe: timeframe) // Fail gracefully
        }
        
        // 6. Cache Result
        cache[cacheKey] = (Date(), advice)
        return advice
    }
    
    // MARK: - Data Pipeline
    
    private func fetchAndResampleData(symbol: String, timeframe: PhoenixTimeframe) async throws -> [Candle] {
        let fetchLimit = 360 // Request more to allow for lookback and resampling
        
        switch timeframe {
        case .h4:
            // Fetch 1h candles and resample (4:1)
            let (rawCandles, _) = try await YahooCandleAdapter.shared.fetchCandles(symbol: symbol, timeframe: "60m", limit: fetchLimit * 4)
            return resample(candles: rawCandles, groupSize: 4)
            
        case .auto:
            // Default to 1h for Auto (logic handles resolution upstream usually, or here)
            // Ideally explicit timeframe is passed. If Auto arrives here, assume 1h.
            let (candles, _) = try await YahooCandleAdapter.shared.fetchCandles(symbol: symbol, timeframe: "60m", limit: fetchLimit)
            return candles
            
        default:
            let (candles, _) = try await YahooCandleAdapter.shared.fetchCandles(symbol: symbol, timeframe: timeframe.yahooInterval, limit: fetchLimit)
            return candles
        }
    }
    
    private func resample(candles: [Candle], groupSize: Int) -> [Candle] {
        guard !candles.isEmpty else { return [] }
        
        var resampled: [Candle] = []
        var chunk: [Candle] = []
        
        // Simple grouping logic: Every N candles makes 1 new candle.
        // Important: Ensure we start from the most recent backward or oldest forward?
        // Standard resampling usually aligns to time boundaries (00:00, 04:00).
        // Here we do a simpler sliding window because Yahoo returns localized times which might be tricky to align.
        // We will group from the START of the array (Oldest).
        
        for c in candles {
            chunk.append(c)
            if chunk.count == groupSize {
                if let agg = aggregate(chunk) {
                    resampled.append(agg)
                }
                chunk = []
            }
        }
        // Handle remainder? Usually discard incomplete bar at the end if strict, but maybe include?
        // We discard remainder to ensure closed bars.
        
        return resampled
    }
    
    private func aggregate(_ chunk: [Candle]) -> Candle? {
        guard let first = chunk.first, let last = chunk.last else { return nil }
        
        let open = first.open
        let close = last.close
        let high = chunk.map { $0.high }.max() ?? 0
        let low = chunk.map { $0.low }.min() ?? 0
        let vol = chunk.map { $0.volume }.reduce(0, +)
        
        return Candle(date: last.date, open: open, high: high, low: low, close: close, volume: vol)
    }
    
    // MARK: - Core Calculation
    
    private func calculate(candles: [Candle], symbol: String, timeframe: PhoenixTimeframe, config: PhoenixConfig) -> PhoenixAdvice {
        return PhoenixLogic.analyze(candles: candles, symbol: symbol, timeframe: timeframe, config: config)
    }
}
