import Foundation

// MARK: - Conviction State

struct ConvictionState {
    let current: Double      // 0.0 – 1.0  (şu anki inanç gücü)
    let original: Double     // 0.0 – 1.0  (konseyin entry'deki skoru)
    let verdict: Verdict
    let dominantFactor: Factor

    enum Verdict {
        case fresh       // ≥0.70  — tez hâlâ güçlü
        case holding     // 0.50–0.70 — bekle
        case fading      // 0.30–0.50 — zayıflıyor, dikkat
        case expired     // <0.30  — tez tükendi, çıkış değerlendir

        var label: String {
            switch self {
            case .fresh:   return "Güçlü"
            case .holding: return "Sağlam"
            case .fading:  return "Zayıflıyor"
            case .expired: return "Tükendi"
            }
        }

        var color: String {     // hex — UI'da Color(hex:) ile kullanılır
            switch self {
            case .fresh:   return "00e676"
            case .holding: return "ffcc00"
            case .fading:  return "ff8c00"
            case .expired: return "ff3333"
            }
        }
    }

    enum Factor {
        case timeDecay      // Fiyat beklenen yönde gitmedi, zaman geçti
        case priceAgainst   // Fiyat teze karşı hareket etti
        case regimeMismatch // Makro rejim pozisyonu desteklemiyor
        case priceConfirm   // Fiyat tezi onayladı
    }
}

// MARK: - Conviction Decay Engine

/// Bir pozisyonun "inanç gücü"nü hesaplar.
/// Zaman geçtikçe, fiyat beklenen yönde gitmezse veya makro desteklemezse güven erir.
/// Yeni data gerektirmez — tamamen mevcut Trade + Decision + Regime verisini kullanır.
enum ConvictionDecayEngine {

    static func compute(
        councilConfidence: Double,   // ArgusGrandDecision.confidence (0–1)
        daysHeld: Int,
        pnlPercent: Double,          // (currentPrice - entryPrice) / entryPrice * 100
        action: ArgusAction,         // Pozisyon açılışındaki konsey aksiyonu
        regime: MarketRegime? = nil  // Chiron'dan gelen mevcut rejim
    ) -> ConvictionState {

        // 1. Zaman faktörü — her gün %1.2 erozyon, fiyat onaylarsa yavaşlar
        let rawTimePenalty = Double(min(daysHeld, 45)) * 0.012
        let confirmationBoost = priceConfirmationBoost(pnlPercent: pnlPercent, action: action)
        let timeFactor = max(0.35, 1.0 - rawTimePenalty + confirmationBoost)

        // 2. Fiyat onay faktörü — fiyat teze karşıysa conviction düşer
        let priceFactor = priceFactor(pnlPercent: pnlPercent, action: action)

        // 3. Rejim uyum faktörü — mevcut makro rejim pozisyonu destekliyor mu?
        let regimeFactor = regimeFactor(regime: regime, action: action)

        // Birleşik skor
        let raw = councilConfidence * timeFactor * priceFactor * regimeFactor
        let current = max(0.05, min(1.0, raw))

        let verdict: ConvictionState.Verdict
        switch current {
        case 0.70...: verdict = .fresh
        case 0.50..<0.70: verdict = .holding
        case 0.30..<0.50: verdict = .fading
        default: verdict = .expired
        }

        let dominant = dominantFactor(
            timeFactor: timeFactor,
            priceFactor: priceFactor,
            regimeFactor: regimeFactor,
            pnlPercent: pnlPercent,
            action: action
        )

        return ConvictionState(
            current: current,
            original: councilConfidence,
            verdict: verdict,
            dominantFactor: dominant
        )
    }

    // MARK: - Private

    private static func priceConfirmationBoost(pnlPercent: Double, action: ArgusAction) -> Double {
        let isBullish = action == .aggressiveBuy || action == .accumulate
        let confirming = isBullish ? pnlPercent > 0 : pnlPercent < 0
        guard confirming else { return 0 }
        let magnitude = min(abs(pnlPercent), 15.0)
        return (magnitude / 15.0) * 0.12   // Max +0.12 boost
    }

    private static func priceFactor(pnlPercent: Double, action: ArgusAction) -> Double {
        let isBullish = action == .aggressiveBuy || action == .accumulate
        // How far has price moved against the thesis?
        let divergence = isBullish ? -min(pnlPercent, 0) : max(pnlPercent, 0)

        if divergence <= 0   { return 1.00 }
        if divergence <= 3.0 { return 0.88 }
        if divergence <= 7.0 { return 0.72 }
        if divergence <= 12.0 { return 0.55 }
        return 0.38   // >12% against — thesis under serious pressure
    }

    private static func regimeFactor(regime: MarketRegime?, action: ArgusAction) -> Double {
        guard let regime else { return 1.0 }
        let isBullish = action == .aggressiveBuy || action == .accumulate

        switch (regime, isBullish) {
        case (.trend, true):     return 1.05  // Trend + long = conviction boost
        case (.riskOff, true):   return 0.72  // Risk-off + long = friction
        case (.newsShock, _):    return 0.80  // Shock erodes confidence
        case (.chop, _):         return 0.90  // Chop = drift
        case (.riskOff, false):  return 1.05  // Risk-off + short/trim = aligned
        default:                 return 1.00
        }
    }

    private static func dominantFactor(
        timeFactor: Double,
        priceFactor: Double,
        regimeFactor: Double,
        pnlPercent: Double,
        action: ArgusAction
    ) -> ConvictionState.Factor {
        let isBullish = action == .aggressiveBuy || action == .accumulate
        let divergence = isBullish ? -min(pnlPercent, 0) : max(pnlPercent, 0)

        if priceFactor < 0.65 && divergence > 5 { return .priceAgainst }
        if regimeFactor < 0.80 { return .regimeMismatch }
        if timeFactor < 0.65   { return .timeDecay }
        if priceFactor > 0.95  { return .priceConfirm }
        return .timeDecay
    }
}
