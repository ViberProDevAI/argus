import Foundation

// MARK: - Key Levels Engine
// Fiyatın yakınındaki "anlamlı" seviyeleri tek seferde çıkarır.
// EntrySetupEngine bu sonucu kullanarak giriş zonunu, stop'u ve R:R'ı hesaplar.
//
// Minimum 60 bar gerekir (EMA50 + swing penceresi güvenli sinyal için).
// 200+ bar yoksa ema200 nil; diğerleri mümkün olduğu kadar doldurulur.

enum KeyLevelsEngine {

    /// Son bara ait anlamlı destek/direnç/trend seviyelerini çıkarır.
    /// - Parameter candles: Tarihsel sıralı günlük mumlar (eski → yeni).
    /// - Returns: Yeterli veri yoksa nil.
    static func extract(candles: [Candle]) -> KeyLevels? {
        guard candles.count >= 60 else { return nil }

        let closes = candles.map { $0.close }

        let ema20 = IndicatorService.calculateEMA(values: closes, period: 20).last ?? nil
        let ema50 = IndicatorService.calculateEMA(values: closes, period: 50).last ?? nil
        let ema200: Double? = {
            guard candles.count >= 200 else { return nil }
            return IndicatorService.calculateEMA(values: closes, period: 200).last ?? nil
        }()

        // ATR14 → stop mesafesini kalibre eder (1.5×ATR altına stop gibi).
        let atr14 = IndicatorService.lastATR(candles: candles, period: 14)

        // Klasik pivot ÖNCEKİ bardan hesaplanır; son bar henüz kapanmamış olabilir.
        let pivot: Double? = {
            guard candles.count >= 2 else { return nil }
            let prev = candles[candles.count - 2]
            return (prev.high + prev.low + prev.close) / 3.0
        }()

        // Son 90 barın uç değerleri — yakın direnç ve destek.
        let window90 = candles.suffix(90)
        let recentHigh90d = window90.map { $0.high }.max()
        let recentLow90d = window90.map { $0.low }.min()

        // Fib retracement: son 60 bar içinde low → high (sırayla) impulse ara.
        let window60 = Array(candles.suffix(60))
        let (fib38, fib50, fib62) = fibonacciLevels(candles: window60)

        return KeyLevels(
            ema20: ema20,
            ema50: ema50,
            ema200: ema200,
            atr14: atr14,
            pivot: pivot,
            recentHigh90d: recentHigh90d,
            recentLow90d: recentLow90d,
            fib38: fib38,
            fib50: fib50,
            fib62: fib62
        )
    }

    // Swing low'u bulur, ondan SONRA gelen en yüksek high ile impulse'u çıkarır.
    // Geçerli bir up-impulse yoksa üçü de nil (pullback setup burada aranmaz).
    private static func fibonacciLevels(candles: [Candle]) -> (Double?, Double?, Double?) {
        guard candles.count >= 10 else { return (nil, nil, nil) }

        var lowIndex = 0
        var low = candles[0].low
        for i in 1..<candles.count where candles[i].low < low {
            low = candles[i].low
            lowIndex = i
        }

        guard lowIndex < candles.count - 1 else { return (nil, nil, nil) }
        let postLow = candles[(lowIndex + 1)...]
        guard let high = postLow.map({ $0.high }).max(), high > low else { return (nil, nil, nil) }

        let range = high - low
        let fib38 = high - range * 0.382
        let fib50 = high - range * 0.500
        let fib62 = high - range * 0.618
        return (fib38, fib50, fib62)
    }
}
