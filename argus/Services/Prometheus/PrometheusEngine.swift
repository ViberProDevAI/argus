import Foundation

// MARK: - Prometheus: Price Forecasting Engine
// Uses Holt-Winters Exponential Smoothing for 5-day price predictions
// Academic Reference: ESWA 2022 Literature Review recommends time-series models

actor PrometheusEngine {
    static let shared = PrometheusEngine()
    
    // Cache: Symbol -> Forecast
    private var forecastCache: [String: (forecast: PrometheusForecast, timestamp: Date)] = [:]
    private let cacheExpiry: TimeInterval = 3600 // 1 hour
    
    // MARK: - Public API
    
    /// Generates a 5-day price forecast for the given symbol
    /// - Parameters:
    ///   - symbol: Stock symbol
    ///   - historicalPrices: Array of closing prices (newest first, minimum 30 days)
    /// - Returns: PrometheusForecast with predictions
    func forecast(symbol: String, historicalPrices: [Double]) async -> PrometheusForecast {
        // Check cache
        if let cached = forecastCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
            return cached.forecast
        }
        
        // Need at least 30 data points for meaningful forecast
        guard historicalPrices.count >= 30 else {
            return PrometheusForecast.insufficient(symbol: symbol)
        }
        
        // Reverse to oldest-first for time series analysis
        let prices = Array(historicalPrices.reversed())
        
        // Apply Holt-Winters Double Exponential Smoothing
        let forecast = holtWintersForecast(prices: prices, daysAhead: 5)
        
        // Calculate confidence based on recent volatility
        let confidence = calculateConfidence(prices: prices)
        
        // Determine trend direction
        let trend = determineTrend(prices: prices, forecast: forecast)
        
        let currentPrice = historicalPrices.first ?? 0
        let predictedPrice = forecast.last ?? currentPrice
        let changePercent = ((predictedPrice - currentPrice) / currentPrice) * 100
        
        let result = PrometheusForecast(
            symbol: symbol,
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            predictions: forecast,
            changePercent: changePercent,
            confidence: confidence,
            trend: trend,
            generatedAt: Date()
        )
        
        // Cache result
        forecastCache[symbol] = (result, Date())
        
        // Forward Test Logging (Black Box)
        ArgusLedger.shared.logForecast(
            symbol: symbol,
            currentPrice: currentPrice,
            predictedPrice: predictedPrice,
            predictions: forecast,
            confidence: confidence
        )
        
        return result
    }
    
    // MARK: - Holt-Winters Algorithm
    
    /// Double Exponential Smoothing (Holt-Winters without seasonality)
    /// Good for short-term trending data
    private func holtWintersForecast(prices: [Double], daysAhead: Int) -> [Double] {
        guard prices.count >= 2 else { return [] }
        
        // Smoothing parameters (optimized for stock data)
        let alpha = 0.3  // Level smoothing
        let beta = 0.1   // Trend smoothing
        
        // Initialize
        var level = prices[0]
        var trend = prices[1] - prices[0]
        
        // Smooth through historical data
        for i in 1..<prices.count {
            let previousLevel = level
            
            // Update level
            level = alpha * prices[i] + (1 - alpha) * (previousLevel + trend)
            
            // Update trend
            trend = beta * (level - previousLevel) + (1 - beta) * trend
        }
        
        // Generate forecasts
        var forecasts: [Double] = []
        for day in 1...daysAhead {
            let prediction = level + (Double(day) * trend)
            // Ensure non-negative price
            forecasts.append(max(0, prediction))
        }
        
        return forecasts
    }
    
    // MARK: - Confidence Calculation
    
    /// Calculates forecast confidence based on recent price volatility
    /// Lower volatility = Higher confidence
    private func calculateConfidence(prices: [Double]) -> Double {
        guard prices.count >= 10 else { return 50.0 }
        
        let recentPrices = Array(prices.suffix(10))
        
        // Calculate standard deviation
        let mean = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let variance = recentPrices.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recentPrices.count)
        let stdDev = sqrt(variance)
        
        // Coefficient of variation (normalized volatility)
        let cv = stdDev / mean
        
        // Convert to confidence (lower CV = higher confidence)
        // CV of 0 = 100% confidence, CV of 0.1+ = 50% confidence
        let confidence = max(50, min(95, 100 - (cv * 500)))
        
        return confidence
    }
    
    // MARK: - Trend Detection
    
    private func determineTrend(prices: [Double], forecast: [Double]) -> PrometheusTrend {
        guard let lastPrice = prices.last, let predictedPrice = forecast.last else {
            return .neutral
        }
        
        let changePercent = ((predictedPrice - lastPrice) / lastPrice) * 100
        
        switch changePercent {
        case 5...: return .strongBullish
        case 2..<5: return .bullish
        case -2..<2: return .neutral
        case -5..<(-2): return .bearish
        default: return .strongBearish
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        forecastCache.removeAll()
    }
    
    func clearCache(for symbol: String) {
        forecastCache.removeValue(forKey: symbol)
    }
}

// MARK: - Models

struct PrometheusForecast: Equatable {
    let symbol: String
    let currentPrice: Double
    let predictedPrice: Double
    let predictions: [Double]  // Day 1, 2, 3, 4, 5
    let changePercent: Double
    let confidence: Double     // 0-100
    let trend: PrometheusTrend
    let generatedAt: Date
    
    var isValid: Bool {
        !predictions.isEmpty
    }
    
    var formattedChange: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", changePercent))%"
    }
    
    var confidenceLevel: String {
        switch confidence {
        case 80...100: return "Yüksek"
        case 60..<80: return "Orta"
        default: return "Düşük"
        }
    }
    
    /// Creates an "insufficient data" forecast
    static func insufficient(symbol: String) -> PrometheusForecast {
        PrometheusForecast(
            symbol: symbol,
            currentPrice: 0,
            predictedPrice: 0,
            predictions: [],
            changePercent: 0,
            confidence: 0,
            trend: .neutral,
            generatedAt: Date()
        )
    }
}

enum PrometheusTrend: String {
    case strongBullish = "Güçlü Yükseliş"
    case bullish = "Yükseliş"
    case neutral = "Yatay"
    case bearish = "Düşüş"
    case strongBearish = "Güçlü Düşüş"
    
    var icon: String {
        switch self {
        case .strongBullish: return "arrow.up.forward.circle.fill"
        case .bullish: return "arrow.up.right"
        case .neutral: return "arrow.left.arrow.right"
        case .bearish: return "arrow.down.right"
        case .strongBearish: return "arrow.down.forward.circle.fill"
        }
    }
    
    var colorName: String {
        switch self {
        case .strongBullish, .bullish: return "green"
        case .neutral: return "gray"
        case .bearish, .strongBearish: return "red"
        }
    }
}
