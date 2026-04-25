import Foundation

// MARK: - Pullback Detector
// Momentum-pullback setup'ını algılar. Uptrend + zonda geri çekilme kombinasyonu.
//
// Algoritma:
//   1. Orion günlük skoru ≥ 55 (conviction gate — Argus zaten bu sembole "evet" demiş mi?)
//   2. Son 30 günde ≥ +%10 momentum (trend gate — bu bir uptrend mi, spekülasyon mu?)
//   3. Fiyat EMA20 veya EMA50 zonunda (±0.5 ATR) (pullback gate — şu an retest mi, extension mi?)
//   4. Confluence sayımı: fib overlap, RSI cooldown, volume dry-up, reversal bar
//
// Çıktı üç durum alabilir:
//   .ready → tetik anlamlı, fiyat zonda; EntrySetupEngine grade + R:R hesaplar
//   .waitingForPullback → gate'ler OK ama fiyat zonun üstünde, pullback bekleniyor
//   .rejected → temel gate fail; setup oluşmaz, neden user'a iletilir

struct PullbackResult: Equatable {
    let trigger: EntryTrigger
    let entryZone: ClosedRange<Double>
    let confluence: [ConfluenceFactor]
}

enum PullbackDetector {

    enum Outcome: Equatable {
        case ready(PullbackResult)
        case waitingForPullback(targetZone: ClosedRange<Double>, level: String)
        case rejected(reason: String)
    }

    /// Mumlar eski → yeni sıralı olmalı. Yeterli veri yoksa rejected döner.
    static func evaluate(
        candles: [Candle],
        currentPrice: Double,
        keyLevels: KeyLevels,
        orionDailyScore: Double
    ) -> Outcome {

        // Gate 1 — Conviction
        guard orionDailyScore >= 55 else {
            return .rejected(reason: String(
                format: "Konviksiyon düşük (Orion %.0f/100). Giriş için skor ≥ 55 olmalı.",
                orionDailyScore
            ))
        }

        // Gate 2 — Momentum trend (son 30 gün ≥ +%10)
        guard candles.count >= 30 else {
            return .rejected(reason: "30 günlük veri yetersiz — trend ölçülemez.")
        }
        let close30 = candles[candles.count - 30].close
        guard let latest = candles.last, close30 > 0 else {
            return .rejected(reason: "Geçersiz fiyat verisi.")
        }
        let ret30 = (latest.close - close30) / close30
        guard ret30 >= 0.10 else {
            return .rejected(reason: String(
                format: "Momentum yok (%.1f%% / 30g). Trend oluşmadan pullback anlamsız.",
                ret30 * 100
            ))
        }

        // Gate 3 — Key levels mevcut
        guard let ema20 = keyLevels.ema20,
              let ema50 = keyLevels.ema50,
              let atr = keyLevels.atr14, atr > 0 else {
            return .rejected(reason: "Teknik seviyeler eksik (EMA veya ATR hesaplanamadı).")
        }

        let ema20Zone = (ema20 - 0.5 * atr)...(ema20 + 0.5 * atr)
        let ema50Zone = (ema50 - 0.5 * atr)...(ema50 + 0.5 * atr)

        // Fiyat hangi zonda? (EMA20 önce — daha yakın retest, daha sıcak sinyal)
        let primary: (trigger: EntryTrigger, zone: ClosedRange<Double>, conf: ConfluenceFactor)
        if ema20Zone.contains(currentPrice) {
            primary = (
                .pullbackToEMA(emaPeriod: 20, level: ema20),
                ema20Zone,
                .emaSupport(period: 20)
            )
        } else if ema50Zone.contains(currentPrice) {
            primary = (
                .pullbackToEMA(emaPeriod: 50, level: ema50),
                ema50Zone,
                .emaSupport(period: 50)
            )
        } else if currentPrice > ema20Zone.upperBound {
            // Fiyat EMA20 üstünde uzamış — pullback henüz başlamamış.
            return .waitingForPullback(targetZone: ema20Zone, level: "EMA20")
        } else {
            // Fiyat EMA50 altına kaymış — trend yapısı zayıflamış.
            return .rejected(reason: "Fiyat EMA50 altında. Trend yapısı zayıf, pullback değil reversal denemesi.")
        }

        // Confluence sayımı
        var confluence: [ConfluenceFactor] = [primary.conf]

        if let f38 = keyLevels.fib38, let f62 = keyLevels.fib62 {
            let lo = min(f38, f62), hi = max(f38, f62)
            if (lo...hi).contains(currentPrice) {
                confluence.append(.fibonacciLevel(closestFib(currentPrice: currentPrice, keyLevels: keyLevels)))
            }
        }

        let closes = candles.map { $0.close }
        let rsiSeries = IndicatorService.calculateRSI(values: closes, period: 14)
        if let last = rsiSeries.last, let rsiNow = last, (50.0...65.0).contains(rsiNow) {
            let lookback = rsiSeries.dropLast().suffix(10)
            if lookback.contains(where: { ($0 ?? 0) > 70 }) {
                confluence.append(.rsiCooldown)
            }
        }

        if candles.count >= 20 {
            let v3 = candles.suffix(3).map { $0.volume }.reduce(0, +) / 3.0
            let v20 = candles.suffix(20).map { $0.volume }.reduce(0, +) / 20.0
            if v20 > 0, v3 < v20 * 0.8 {
                confluence.append(.volumeDryUp)
            }
        }

        if isBullishReversalBar(candles: candles) {
            confluence.append(.hammerCandle)
        }

        return .ready(PullbackResult(
            trigger: primary.trigger,
            entryZone: primary.zone,
            confluence: confluence
        ))
    }

    // MARK: - Helpers

    private static func closestFib(currentPrice: Double, keyLevels: KeyLevels) -> Double {
        var pairs: [(level: Double, percent: Double)] = []
        if let v = keyLevels.fib38 { pairs.append((v, 0.382)) }
        if let v = keyLevels.fib50 { pairs.append((v, 0.500)) }
        if let v = keyLevels.fib62 { pairs.append((v, 0.618)) }
        return pairs.min(by: { abs($0.level - currentPrice) < abs($1.level - currentPrice) })?.percent ?? 0.5
    }

    /// Hammer veya bullish engulfing — son barın reversal teyidi.
    private static func isBullishReversalBar(candles: [Candle]) -> Bool {
        guard candles.count >= 2 else { return false }
        let last = candles.last!
        let prev = candles[candles.count - 2]

        let body = abs(last.close - last.open)
        let range = last.high - last.low
        guard range > 0 else { return false }

        let lowerWick = min(last.open, last.close) - last.low
        let upperWick = last.high - max(last.open, last.close)
        let isHammer = (body / range) < 0.33 && lowerWick > 2 * body && upperWick < body

        let prevBearish = prev.close < prev.open
        let nowBullish = last.close > last.open
        let engulfOpen = last.open < prev.close
        let engulfClose = last.close > prev.open
        let isEngulfing = prevBearish && nowBullish && engulfOpen && engulfClose

        return isHammer || isEngulfing
    }
}
