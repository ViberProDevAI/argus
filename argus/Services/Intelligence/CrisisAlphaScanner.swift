import Foundation

// MARK: - Crisis Alpha Scanner
/// Makro kötüyken (Aether < 35) BİREYSEL hisse seviyesinde aşırı satım fırsatları tarar.
/// "Piyasa batar, ama THYAO %40 düştüyse ve teknik dip sinyali veriyorsa → kısa scalp al"
///
/// Strateji: Mean Reversion
///   - Z-skor: son 20 günün ortalamasından kaç standart sapma uzakta?
///   - RSI benzeri momentum: son 5 güne göre momentum
///   - Hacim anomalisi: panik satışı mı?
///   - Sonuç: Küçük pozisyon (normal %30), dar stop (ATR × 1.0), kısa hedef (ATR × 1.5)

struct CrisisAlphaScanner {

    // MARK: - Modeller

    struct AlphaOpportunity {
        let symbol: String
        let opportunityType: OpportunityType
        let zScore: Double           // Ne kadar aşırı satılmış (negatif = aşırı satım)
        let momentumScore: Double    // 0-100 (düşük = momentum dönüyor)
        let volumeAnomaly: Double    // 1.0 = normal, 2.0 = 2x hacim
        let suggestedEntry: Double
        let suggestedStop: Double    // Dar — kriz modunda geniş stop olmaz
        let suggestedTarget: Double  // Kısa hedef
        let positionSizeMultiplier: Double  // Normal boyutun %20-40'ı
        let confidence: Double       // 0-1

        enum OpportunityType: String {
            case oversoldBounce   = "AŞIRI_SATIM_TOPARLANMA"
            case panicReversal    = "PANİK_DÖNÜŞÜ"
            case supportTest      = "DESTEK_TESTİ"
        }

        var summary: String {
            "🎯 \(symbol) | \(opportunityType.rawValue) | Z:\(String(format: "%.1f", zScore)) | Güven:\(Int(confidence*100))%"
        }
    }

    struct CrisisContext {
        let aetherScore: Double
        let isActiveCrisis: Bool  // Aether < 35

        var crisisMultiplier: Double {
            // Kriz ne kadar derin → pozisyon o kadar küçük
            switch aetherScore {
            case ..<10:  return 0.15  // %15 normal boyut
            case 10..<20: return 0.20
            case 20..<25: return 0.25
            case 25..<35: return 0.30
            default:      return 0.40
            }
        }
    }

    // MARK: - Tarama

    /// Verilen semboller için kriz alpha fırsatı ara
    static func scan(
        symbols: [String],
        quotes: [String: Quote],
        candleHistory: [String: [Candle]],  // symbol → son 20 gün mum
        context: CrisisContext
    ) -> [AlphaOpportunity] {
        guard context.isActiveCrisis else { return [] }

        var opportunities: [AlphaOpportunity] = []

        for symbol in symbols {
            guard let quote = quotes[symbol],
                  let candles = candleHistory[symbol],
                  candles.count >= 10 else { continue }

            let price = quote.currentPrice
            let closes = candles.map { $0.close }

            // 1. Z-skor hesapla (son 20 günün ortalamasından sapma)
            let zScore = calculateZScore(price: price, history: closes)

            // Z-skor < -1.5 = anlamlı aşırı satım
            guard zScore < -1.5 else { continue }

            // 2. Momentum dönüşü var mı?
            let momentum = calculateMomentumReversal(candles: candles)
            guard momentum.hasBounceSignal else { continue }

            // 3. Hacim anomalisi (panik satışı sonrası)
            let volumeAnomaly = calculateVolumeAnomaly(candles: candles)

            // 4. ATR hesapla (dar stop için)
            let atr = calculateATR(candles: candles)

            // 5. Güven skoru
            let confidence = calculateConfidence(
                zScore: zScore,
                momentumScore: momentum.score,
                volumeAnomaly: volumeAnomaly,
                aetherScore: context.aetherScore
            )

            guard confidence >= 0.45 else { continue }

            // 6. Opportunity type belirle
            let oppType: AlphaOpportunity.OpportunityType
            if volumeAnomaly > 2.5 && momentum.hasBounceSignal {
                oppType = .panicReversal
            } else if zScore < -2.5 {
                oppType = .oversoldBounce
            } else {
                oppType = .supportTest
            }

            opportunities.append(AlphaOpportunity(
                symbol: symbol,
                opportunityType: oppType,
                zScore: zScore,
                momentumScore: momentum.score,
                volumeAnomaly: volumeAnomaly,
                suggestedEntry: price,
                suggestedStop: price - atr * 1.0,   // Dar stop
                suggestedTarget: price + atr * 1.5, // Kısa hedef
                positionSizeMultiplier: context.crisisMultiplier,
                confidence: confidence
            ))
        }

        // En güçlü fırsatları öne al, max 3 tane
        return opportunities
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Hesaplamalar

    private static func calculateZScore(price: Double, history: [Double]) -> Double {
        let recent = Array(history.suffix(20))
        guard recent.count >= 5 else { return 0 }

        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recent.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return 0 }
        return (price - mean) / stdDev
    }

    private struct MomentumResult {
        let score: Double           // 0-100
        let hasBounceSignal: Bool
    }

    private static func calculateMomentumReversal(candles: [Candle]) -> MomentumResult {
        let recent = Array(candles.suffix(5))
        guard recent.count >= 3 else { return MomentumResult(score: 50, hasBounceSignal: false) }

        // Son 3 günde düşüş yavaşladı mı?
        let losses = recent.dropLast().map { max(0, $0.close - $0.open) == 0 ? abs($0.close - $0.open) : 0 }
        let lastCandle = recent.last!

        // Doji veya hammer mumu (dönüş sinyali)
        let bodySize = abs(lastCandle.close - lastCandle.open)
        let totalRange = lastCandle.high - lastCandle.low
        let isDoji = totalRange > 0 && bodySize / totalRange < 0.3

        // Alt gölge uzun mu? (Hammer)
        let lowerShadow = min(lastCandle.open, lastCandle.close) - lastCandle.low
        let isHammer = totalRange > 0 && lowerShadow / totalRange > 0.5

        // Momentum skoru (düşük = dönüş olası)
        let avgLoss = losses.isEmpty ? 0 : losses.reduce(0, +) / Double(losses.count)
        let score = max(0, min(100, 50 - avgLoss * 10))

        let hasBounce = isDoji || isHammer || score < 30

        return MomentumResult(score: score, hasBounceSignal: hasBounce)
    }

    private static func calculateVolumeAnomaly(candles: [Candle]) -> Double {
        let recent = Array(candles.suffix(20))
        guard recent.count >= 10 else { return 1.0 }

        let avgVolume = recent.dropLast(3).map { $0.volume }.reduce(0, +) / Double(recent.count - 3)
        let recentVolume = recent.suffix(3).map { $0.volume }.reduce(0, +) / 3.0

        guard avgVolume > 0 else { return 1.0 }
        return recentVolume / avgVolume
    }

    private static func calculateATR(candles: [Candle]) -> Double {
        let recent = Array(candles.suffix(14))
        guard recent.count >= 2 else { return recent.last.map { $0.close * 0.02 } ?? 1.0 }

        var trValues: [Double] = []
        for i in 1..<recent.count {
            let high = recent[i].high
            let low  = recent[i].low
            let prevClose = recent[i-1].close
            let tr = max(high - low, abs(high - prevClose), abs(low - prevClose))
            trValues.append(tr)
        }

        return trValues.reduce(0, +) / Double(trValues.count)
    }

    private static func calculateConfidence(
        zScore: Double,
        momentumScore: Double,
        volumeAnomaly: Double,
        aetherScore: Double
    ) -> Double {
        var score = 0.0

        // Z-skor katkısı (daha negatif = daha iyi)
        score += min(0.4, abs(zScore) * 0.1)

        // Momentum dönüşü katkısı (düşük momentum skoru = dönüş yakın)
        score += max(0, (50 - momentumScore) / 50 * 0.3)

        // Hacim anomalisi (panik = dönüş yakın olabilir)
        if volumeAnomaly > 2.0 { score += 0.15 }
        if volumeAnomaly > 3.0 { score += 0.10 }

        // Aether ceza faktörü (çok düşükse risk var)
        let aetherPenalty = aetherScore < 15 ? -0.15 : 0.0
        score += aetherPenalty

        return max(0, min(1.0, score))
    }
}
