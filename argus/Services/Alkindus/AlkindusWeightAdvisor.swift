import Foundation

// MARK: - Alkindus Weight Advisor
//
// 2026-05-09 Faz B — "Öğrendiklerini kullan" hattı.
//
// Eski sistemde Alkindus aylardır kalibrasyon verisi biriktiriyordu ama
// bu veri karar verme zincirinde HİÇ kullanılmıyordu. ArgusGrandCouncil
// her seferinde sıfırdan oy topluyor, "geçmişte Aether risk-off rejiminde
// %38 doğruydu" bilgisini hiç sormuyordu. Sonuç: aylardır biriktirilen
// öğrenme bilgisi diske yazılıp orada kalıyordu, hiçbir karara dönmüyordu.
//
// AlkindusWeightAdvisor bu boşluğu doldurur:
//   • Konsey karar vermeden önce her modülün şu anki rejim/skor
//     bracket'inde geçmiş güveni sorulur
//   • Geçmiş güven, modülün konseydeki ağırlığını çarpan olarak ayarlar
//   • Az örnekli durumda nötr (1.0) çarpan, çok örnekli durumda gerçek
//     güveni yansıtan çarpan
//
// Çıktı (`WeightAdvice`) sadece çarpan değil — UI'da şeffaflık için
// gerekçe metni, örnek boyutu ve güven aralığını da içerir. AgoraDebateSheet
// kullanıcıya "neden Aether'in oyunu zayıflattım" sorusunu cevaplayabilir.

/// Bir modülün şu anki bağlamda Alkindus tarafından önerilen ağırlık
/// ayarlaması. Konsey base weight ile bu çarpanı çarpıp normalize eder.
struct WeightAdvice: Sendable, Equatable, Codable {
    /// Base weight'e uygulanacak çarpan. Tipik aralık: 0.5..1.5.
    /// 1.0 = nötr (yeterli veri yok ya da %50 hit rate)
    /// > 1.0 = modülün geçmişi pozitif → daha fazla söz sahibi
    /// < 1.0 = modülün geçmişi negatif → oyu kısıtla
    let multiplier: Double

    /// Smoothed hit rate (Laplace prior'lı). UI'da gösterilir.
    let smoothedHitRate: Double

    /// Wilson %95 güven aralığı.
    let confidenceLower: Double
    let confidenceUpper: Double

    /// Toplam denenme sayısı (ağırlıklı). 10+ "güvenilir" sayılır.
    let sampleSize: Double

    /// Bu kararda kullanılan bracket (örn. "60-80").
    let bracket: String

    /// Bu kararda kullanılan rejim (örn. "Risk-On").
    let regime: String

    /// İnsan-okuyabilir gerekçe — UI'da kullanıcıya gösterilir.
    /// Örn: "Geçmişte Risk-On rejiminde 60-80 skor bracket'inde %38 doğru
    /// (12 test). Oyu %12'ye düşürüldü."
    let evidence: String

    /// Yeterli örneğe sahip miyiz?
    var isReliable: Bool { sampleSize >= 10 }

    static let neutral = WeightAdvice(
        multiplier: 1.0,
        smoothedHitRate: 0.5,
        confidenceLower: 0,
        confidenceUpper: 1,
        sampleSize: 0,
        bracket: "",
        regime: "",
        evidence: "Henüz veri yok, nötr ağırlık."
    )
}

actor AlkindusWeightAdvisor {
    static let shared = AlkindusWeightAdvisor()

    private let memoryStore = AlkindusMemoryStore.shared

    /// Calibration data önbelleği — her karar tetiklendiğinde diskten
    /// okumayı engellemek için. Karar oranı saatte birkaç düzine; cache
    /// 60 saniye yeterli.
    private var cachedCalibration: CalibrationData?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 60

    private init() {}

    // MARK: - Public API

    /// Birden fazla modül için tek seferde tavsiye al. Console karar başına
    /// tek çağrı yapar; cache hit'le birkaç ms sürer.
    func getAdvice(moduleScores: [String: Double], regime: String) async -> [String: WeightAdvice] {
        let calibration = await loadCalibrationCached()
        var result: [String: WeightAdvice] = [:]
        for (module, score) in moduleScores {
            result[module] = computeAdvice(
                module: module,
                score: score,
                regime: regime,
                calibration: calibration
            )
        }
        return result
    }

    /// Tek modül için tavsiye — UI veya tekil sorgular için.
    func getAdvice(module: String, score: Double, regime: String) async -> WeightAdvice {
        let calibration = await loadCalibrationCached()
        return computeAdvice(module: module, score: score, regime: regime, calibration: calibration)
    }

    /// Cache'i temizle — örn. öğrenme sıfırlandıktan sonra.
    func invalidateCache() {
        cachedCalibration = nil
        cacheTimestamp = nil
    }

    // MARK: - Internal

    private func loadCalibrationCached() async -> CalibrationData {
        if let cached = cachedCalibration,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL {
            return cached
        }
        let fresh = await memoryStore.loadCalibration()
        cachedCalibration = fresh
        cacheTimestamp = Date()
        return fresh
    }

    private func computeAdvice(
        module: String,
        score: Double,
        regime: String,
        calibration: CalibrationData
    ) -> WeightAdvice {
        let bracket = scoreToBracket(score)
        let normalizedModule = module.lowercased()

        // Bracket bazlı stats
        guard let moduleCal = calibration.modules[normalizedModule],
              let stats = moduleCal.brackets[bracket] else {
            return WeightAdvice(
                multiplier: 1.0,
                smoothedHitRate: 0.5,
                confidenceLower: 0,
                confidenceUpper: 1,
                sampleSize: 0,
                bracket: bracket,
                regime: regime,
                evidence: "\(displayName(module)): bu skor aralığında henüz veri yok, nötr ağırlık."
            )
        }

        let smoothed = stats.smoothedHitRate
        let interval = stats.wilsonInterval95
        let attempts = stats.attempts

        // Çarpan formülü:
        //   • Yetersiz örnek (n<10): tam nötr (1.0)
        //   • Yeterli örnek: 0.5 + smoothedHitRate, [0.5, 1.5] aralığında
        //     - %50 hit rate → 1.0x (nötr)
        //     - %75 hit rate → 1.25x
        //     - %25 hit rate → 0.75x
        //     - %100 (smoothed olmaz ama teorik) → 1.5x
        let multiplier: Double
        if attempts < 10 {
            multiplier = 1.0
        } else {
            multiplier = max(0.5, min(1.5, 0.5 + smoothed))
        }

        let evidence = buildEvidenceString(
            module: module,
            score: score,
            bracket: bracket,
            regime: regime,
            stats: stats,
            multiplier: multiplier
        )

        return WeightAdvice(
            multiplier: multiplier,
            smoothedHitRate: smoothed,
            confidenceLower: interval.lower,
            confidenceUpper: interval.upper,
            sampleSize: attempts,
            bracket: bracket,
            regime: regime,
            evidence: evidence
        )
    }

    /// Skor → bracket map. AlkindusCalibrationEngine.scoreToBracket ile aynı.
    /// Tek kaynaktan okunması ideal ama o `private`. Tutarlı kalsın diye burada
    /// kopyalandı; iki yerde değişirse veri tutarsız hale gelir.
    private func scoreToBracket(_ score: Double) -> String {
        switch score {
        case 78...:    return "80-100"
        case 58..<78:  return "60-80"
        case 38..<58:  return "40-60"
        case 18..<38:  return "20-40"
        default:       return "0-20"
        }
    }

    private func buildEvidenceString(
        module: String,
        score: Double,
        bracket: String,
        regime: String,
        stats: BracketStats,
        multiplier: Double
    ) -> String {
        let displayMod = displayName(module)
        let n = Int(stats.attempts.rounded())
        let rate = Int(stats.smoothedHitRate * 100)
        let rawRate = Int((stats.attempts > 0 ? stats.correct / stats.attempts : 0) * 100)
        let regimeLabel = displayRegime(regime)

        if stats.attempts < 10 {
            return "\(displayMod) · \(regimeLabel) · \(bracket) skor: \(n) test (yeterli değil), nötr ağırlık."
        }

        let direction: String
        if multiplier > 1.05 {
            direction = "→ ağırlık güçlendirildi (×\(String(format: "%.2f", multiplier)))"
        } else if multiplier < 0.95 {
            direction = "→ ağırlık zayıflatıldı (×\(String(format: "%.2f", multiplier)))"
        } else {
            direction = "→ nötr ağırlık"
        }

        return "\(displayMod) · \(regimeLabel) · \(bracket): geçmişte %\(rawRate) (smooth %\(rate), \(n) test) \(direction)"
    }

    private func displayName(_ module: String) -> String {
        switch module.lowercased() {
        case "orion":          return "Teknik (Orion)"
        case "orion patterns": return "Teknik formasyon"
        case "atlas":          return "Bilanço (Atlas)"
        case "aether":         return "Makro (Aether)"
        case "hermes":         return "Haber (Hermes)"
        case "demeter":        return "Sektör (Demeter)"
        case "phoenix":        return "Risk (Phoenix)"
        case "athena":         return "Faktör (Athena)"
        case "prometheus":     return "Tahmin (Prometheus)"
        default:               return module.capitalized
        }
    }

    private func displayRegime(_ regime: String) -> String {
        switch regime.lowercased() {
        case "riskon", "risk_on", "risk-on":    return "Risk-On"
        case "riskoff", "risk_off", "risk-off": return "Risk-Off"
        case "neutral", "nötr":                 return "Nötr"
        case "transition", "geçiş":             return "Geçiş"
        case "trend":                           return "Trend"
        case "chop":                            return "Yatay"
        case "newsshock", "news_shock":         return "Haber şoku"
        default:                                 return regime.capitalized
        }
    }
}
