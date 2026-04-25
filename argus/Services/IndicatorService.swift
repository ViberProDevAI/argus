import Foundation

// MARK: - Indicator Service
// Teknik analiz indikatörlerini hesaplar.

struct IndicatorService {
    
    // MARK: - Convenience Functions (Single Value - Son değer döndürür)
    // Bu fonksiyonlar, mevcut dizi hesaplamalarını kullanarak son değeri döndürür.
    
    /// RSI'ın son değerini döndürür (varsayılan period: 14)
    static func lastRSI(values: [Double], period: Int = 14) -> Double? {
        let rsi = calculateRSI(values: values, period: period)
        return rsi.last ?? nil
    }
    
    /// RSI'ın son değerini döndürür - Candle input için
    static func lastRSI(candles: [Candle], period: Int = 14) -> Double? {
        let values = candles.map { $0.close }
        return lastRSI(values: values, period: period)
    }
    
    /// MACD'nin son değerlerini tuple olarak döndürür (macd, signal, histogram)
    static func lastMACD(values: [Double], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: Double?, signal: Double?, histogram: Double?) {
        let result = calculateMACD(values: values, fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod)
        return (result.macd.last ?? nil, result.signal.last ?? nil, result.histogram.last ?? nil)
    }
    
    /// MACD'nin son değerlerini döndürür - Candle input için
    static func lastMACD(candles: [Candle], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: Double?, signal: Double?, histogram: Double?) {
        let values = candles.map { $0.close }
        return lastMACD(values: values, fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod)
    }
    
    /// SMA'nın son değerini döndürür
    static func lastSMA(values: [Double], period: Int) -> Double? {
        let sma = calculateSMA(values: values, period: period)
        return sma.last ?? nil
    }
    
    /// Bollinger Bands'in son değerlerini döndürür (upper, middle, lower)
    static func lastBollingerBands(values: [Double], period: Int = 20, stdDevMultiplier: Double = 2.0) -> (upper: Double?, middle: Double?, lower: Double?) {
        let result = calculateBollingerBands(values: values, period: period, stdDevMultiplier: stdDevMultiplier)
        return (result.upper.last ?? nil, result.middle.last ?? nil, result.lower.last ?? nil)
    }
    
    /// Stochastic'in son değerlerini döndürür (%K, %D)
    static func lastStochastic(candles: [Candle], kPeriod: Int = 14, dPeriod: Int = 3) -> (k: Double?, d: Double?) {
        let result = calculateStochastic(candles: candles, kPeriod: kPeriod, dPeriod: dPeriod)
        return (result.k.last ?? nil, result.d.last ?? nil)
    }
    
    /// CCI'ın son değerini döndürür
    static func lastCCI(candles: [Candle], period: Int = 20) -> Double? {
        let cci = calculateCCI(candles: candles, period: period)
        return cci.last ?? nil
    }
    
    /// ADX'in son değerini döndürür
    static func lastADX(candles: [Candle], period: Int = 14) -> Double? {
        let adx = calculateADX(candles: candles, period: period)
        return adx.last ?? nil
    }
    
    /// ATR'ın son değerini döndürür
    static func lastATR(candles: [Candle], period: Int = 14) -> Double? {
        let atr = calculateATR(candles: candles, period: period)
        return atr.last ?? nil
    }
    
    /// Williams %R'ın son değerini döndürür
    static func lastWilliamsR(candles: [Candle], period: Int = 14) -> Double? {
        let values = TechnicalAnalysisEngine.williamsR(candles: candles, period: period)
        return values.last ?? nil
    }
    
    // MARK: - Aroon Oscillator
    /// Returns Aroon Oscillator value (-100 to +100)
    static func lastAroon(candles: [Candle], period: Int = 25) -> Double? {
        let values = TechnicalAnalysisEngine.aroon(candles: candles, period: period)
        return values.last ?? nil
    }

    // MARK: - RSI
    static func calculateRSI(values: [Double], period: Int = 14) -> [Double?] {
        return TechnicalAnalysisEngine.rsi(values: values, period: period)
    }
    
    // MARK: - MACD
    static func calculateMACD(values: [Double], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {
        return TechnicalAnalysisEngine.macd(values: values, fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod)
    }
    
    // MARK: - SMA (Simple Moving Average)
    static func calculateSMA(values: [Double], period: Int) -> [Double?] {
        return TechnicalAnalysisEngine.sma(values: values, period: period)
    }

    // MARK: - EMA Helper
    static func calculateEMA(values: [Double], period: Int) -> [Double?] {
        return TechnicalAnalysisEngine.ema(values: values, period: period)
    }
    
    // MARK: - Bollinger Bands
    static func calculateBollingerBands(values: [Double], period: Int = 20, stdDevMultiplier: Double = 2.0) -> (upper: [Double?], middle: [Double?], lower: [Double?]) {
        return TechnicalAnalysisEngine.bollingerBands(values: values, period: period, multiplier: stdDevMultiplier)
    }
    // MARK: - ATR (Average True Range)
    static func calculateATR(candles: [Candle], period: Int = 14) -> [Double?] {
        return TechnicalAnalysisEngine.atr(candles: candles, period: period)
    }
    
    // MARK: - ADX (Average Directional Index)
    static func calculateADX(candles: [Candle], period: Int = 14) -> [Double?] {
        return TechnicalAnalysisEngine.adx(candles: candles, period: period)
    }

    // MARK: - Parabolic SAR
    static func calculateSAR(candles: [Candle], acceleration: Double = 0.02, maximum: Double = 0.2) -> [Double?] {
        return TechnicalAnalysisEngine.sar(candles: candles, acceleration: acceleration, maximum: maximum)
    }

    // MARK: - Stochastic Oscillator
    static func calculateStochastic(candles: [Candle], kPeriod: Int = 14, dPeriod: Int = 3) -> (k: [Double?], d: [Double?]) {
        return TechnicalAnalysisEngine.stochastic(candles: candles, kPeriod: kPeriod, dPeriod: dPeriod)
    }
    
    // MARK: - CCI (Commodity Channel Index)
    static func calculateCCI(candles: [Candle], period: Int = 20) -> [Double?] {
        return TechnicalAnalysisEngine.cci(candles: candles, period: period)
    }
    
    // MARK: - Ichimoku Cloud
    typealias IchimokuResult = TechnicalAnalysisEngine.IchimokuResult
    
    static func calculateIchimoku(candles: [Candle]) -> IchimokuResult {
        return TechnicalAnalysisEngine.ichimoku(candles: candles)
    }
    
    // MARK: - TSI (True Strength Index)
    /// Calculates TSI values for the given close prices
    /// Returns an array of TSI values (-100 to +100 range)
    static func calculateTSI(values: [Double], longPeriod: Int = 9, shortPeriod: Int = 3) -> [Double?] {
        // TechnicalAnalysisEngine defaults to 25, 13 but TSI standard is often 25, 13.
        // The inline code here used parameters 9, 3 but mapped to logic.
        // Let's pass parameters strictly.
        return TechnicalAnalysisEngine.tsi(values: values, longPeriod: longPeriod, shortPeriod: shortPeriod)
    }
    

}


