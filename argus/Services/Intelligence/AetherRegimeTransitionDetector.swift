import Foundation

// MARK: - Aether Rejim Dönüşüm Detektörü
//
// Felsefe:
// Aether'i sadece "puan üreten" bir motor değil, **rejim dönüşümünü erken yakalayan**
// bir makro radar olarak kullanmak istiyoruz. Klasik "Aether 40'ın altında → kabuğa çekil"
// yaklaşımı makro korkuyu korur ama **dönüş rally'lerini kaçırır**: savaş sürerken ateşkes
// haberi gelir, fiyatlar sıçrar, Aether puanı hâlâ 35'te — sistem uyuşuk kalır.
//
// Bu detektör dönüşümü SKOR YÜKSELMEDEN ÖNCE şu birleşik delillerle tespit eder:
//  1. Aether velocity pozitif ivmeli (son 48h skor artıyor)
//  2. Hermes tarafında yüksek etkili POZİTİF haber akışı (kataliz)
//  3. Piyasa breadth'i yükseliyor (MarketMomentumGate global signal BUILDING+)
//  4. Volatilite düşüyor (ATR proxy veya VIX-benzeri — basitlik için breadth strong ise vol düşer varsayımı)
//
// İki+ delil birleşince `turning up` dönüşüm sinyali verilir; Council bunu gördüğünde
// risk-off/panic hard veto'sunu advisor note'a düşürüp alım penceresi açar.

public actor AetherRegimeTransitionDetector {
    public static let shared = AetherRegimeTransitionDetector()

    public enum Regime: String, Sendable {
        case panic      // < 25
        case fear       // 25-40
        case cautious   // 40-55
        case neutral    // 55-70
        case optimism   // 70+

        static func from(score: Double) -> Regime {
            switch score {
            case ..<25:   return .panic
            case ..<40:   return .fear
            case ..<55:   return .cautious
            case ..<70:   return .neutral
            default:      return .optimism
            }
        }

        var rank: Int {
            switch self {
            case .panic:    return 0
            case .fear:     return 1
            case .cautious: return 2
            case .neutral:  return 3
            case .optimism: return 4
            }
        }
    }

    public struct Transition: Sendable {
        public let current: Regime
        public let projected: Regime           // Velocity devam ederse 5 gün sonra
        public let direction: Direction
        public let confidence: Double          // 0.0-1.0
        public let evidence: [String]          // Okunabilir kanıt listesi
        public let timeframe: String           // "son 48 saat"

        public enum Direction: String, Sendable {
            case turningUp     = "RISING"       // korku → cesaret geçişi
            case turningDown   = "FALLING"      // cesaret → korku geçişi
            case stable        = "STABLE"
        }

        /// Council bu durumu gördüğünde hard-veto'yu soft'a düşürsün mü?
        public var shouldBypassHardVeto: Bool {
            direction == .turningUp && confidence >= 0.50
        }

        public var summary: String {
            switch direction {
            case .turningUp:
                return "📈 Rejim dönüşümü: \(current.rawValue) → \(projected.rawValue) (%\(Int(confidence * 100)) güven, \(timeframe))"
            case .turningDown:
                return "📉 Rejim bozulması: \(current.rawValue) → \(projected.rawValue) (%\(Int(confidence * 100)) güven)"
            case .stable:
                return "➡️ \(current.rawValue) — dönüşüm sinyali yok"
            }
        }
    }

    private init() {}

    // MARK: - Public API

    /// Tüm delilleri topla ve rejim dönüşüm durumunu değerlendir.
    ///
    /// Parametreler opsiyonel çünkü bazı kaynaklar (Hermes, momentum) her zaman
    /// güncel olmayabilir; parametre nil ise o delil 0 sayılır.
    func analyze(
        velocity: AetherVelocityEngine.VelocityAnalysis,
        recentPositiveHermesEvents: Int = 0,
        recentNegativeHermesEvents: Int = 0,
        globalMomentumLevel: MarketMomentumGate.MomentumSignal.Level? = nil,
        bistMomentumLevel: MarketMomentumGate.MomentumSignal.Level? = nil,
        watchlistPulse: WatchlistPulseMonitor.Pulse? = nil
    ) -> Transition {

        let current = Regime.from(score: velocity.currentScore)
        let projected = Regime.from(score: velocity.projectedScore5d)

        // Kanıt toplama — her biri birer "oy"
        var upEvidence: [String] = []
        var downEvidence: [String] = []

        // 1) Velocity — Aether'in kendi hızı
        switch velocity.signal {
        case .recoveringFast:
            upEvidence.append("Aether hızla iyileşiyor (\(String(format: "%+.1f", velocity.velocity))/gün)")
        case .recovering:
            upEvidence.append("Aether iyileşiyor (\(String(format: "%+.1f", velocity.velocity))/gün)")
        case .deteriorating:
            downEvidence.append("Aether kötüleşiyor (\(String(format: "%+.1f", velocity.velocity))/gün)")
        case .deterioratingFast:
            downEvidence.append("Aether hızla kötüleşiyor (\(String(format: "%+.1f", velocity.velocity))/gün)")
        case .stable:
            break
        }

        // 2) Crossing alert — eşik geçişi tahmini
        if let alert = velocity.crossingAlert {
            switch alert {
            case .willCross25Upward, .willCross40Upward, .willCross55Upward:
                upEvidence.append(alert.description)
            case .willCross25Downward, .willCross40Downward:
                downEvidence.append(alert.description)
            }
        }

        // 3) Hermes haber akışı — kataliz
        if recentPositiveHermesEvents >= 2 {
            upEvidence.append("Hermes: \(recentPositiveHermesEvents) yüksek etkili pozitif haber")
        }
        if recentNegativeHermesEvents >= 2 {
            downEvidence.append("Hermes: \(recentNegativeHermesEvents) yüksek etkili negatif haber")
        }

        // 4) Piyasa breadth'i — fiyat-hacim teyidi
        let isBreadthUp = isLevelBullish(globalMomentumLevel) || isLevelBullish(bistMomentumLevel)
        if isBreadthUp {
            let label = isLevelBullish(globalMomentumLevel) ? "Global" : "BIST"
            upEvidence.append("\(label) piyasa breadth'i yükselişte")
        }

        // 5) Watchlist pulse — tüm listenin ortak ani hareketi (cross-sectional ivme)
        //    Bu Aether'in "makro gözlüğüyle görmediği" şeyi yakalar: tek bir sembol
        //    değil, listenin TAMAMI birden hareket ediyorsa piyasa-geneli olay var.
        if let pulse = watchlistPulse {
            switch (pulse.intensity, pulse.direction) {
            case (.extreme, .up), (.surging, .up):
                upEvidence.append("Watchlist \(pulse.intensity.rawValue) ↑: \(pulse.symbolsUp)/\(pulse.totalSymbols) uyum · hız \(String(format: "%+.2f", pulse.avgMoveRate))%/mum · hacim ×\(String(format: "%.1f", pulse.volumeSpikeRatio))")
            case (.extreme, .down), (.surging, .down):
                downEvidence.append("Watchlist \(pulse.intensity.rawValue) ↓: \(pulse.symbolsDown)/\(pulse.totalSymbols) uyum · hız \(String(format: "%+.2f", pulse.avgMoveRate))%/mum")
            case (.stirring, .up):
                upEvidence.append("Watchlist kıpırdanması ↑: \(pulse.symbolsUp)/\(pulse.totalSymbols) uyum")
            case (.stirring, .down):
                downEvidence.append("Watchlist kıpırdanması ↓: \(pulse.symbolsDown)/\(pulse.totalSymbols) uyum")
            default:
                break
            }
        }

        // Yön kararı
        let direction: Transition.Direction
        if upEvidence.count >= 2 && upEvidence.count > downEvidence.count {
            direction = .turningUp
        } else if downEvidence.count >= 2 && downEvidence.count > upEvidence.count {
            direction = .turningDown
        } else {
            direction = .stable
        }

        // Güven: kanıt yoğunluğu (max 5 kanıttan ne kadarı)
        let maxEvidence = 5.0
        let rawConfidence = Double(max(upEvidence.count, downEvidence.count)) / maxEvidence
        let confidence = min(0.95, max(0.0, rawConfidence))

        let evidenceList = direction == .turningUp ? upEvidence
                         : direction == .turningDown ? downEvidence
                         : []

        return Transition(
            current: current,
            projected: projected,
            direction: direction,
            confidence: confidence,
            evidence: evidenceList,
            timeframe: "son 48 saat"
        )
    }

    private func isLevelBullish(_ level: MarketMomentumGate.MomentumSignal.Level?) -> Bool {
        guard let level = level else { return false }
        switch level {
        case .building, .strong, .extreme: return true
        case .neutral: return false
        }
    }
}
