import Foundation

// MARK: - Aether Velocity Engine
/// Aether'in sadece anlık değerini değil, hızını ve ivmesini takip eder.
/// "Aether 20'de ama 3 gündür artıyor" → iyileşme sinyali ver, sistemi uyanmaya zorla.
/// "Aether 60'ta ama serbest düşüşte" → henüz düşmeden pozisyonları küçült.

actor AetherVelocityEngine {
    static let shared = AetherVelocityEngine()

    // MARK: - Veri Modeli

    struct AetherReading: Codable {
        let score: Double
        let timestamp: Date
    }

    /// Aether hız + ivme yorumu
    enum VelocitySignal: String, Codable {
        case recoveringFast     = "RECOVERING_FAST"    // +5+/gün → erken alım penceresi
        case recovering         = "RECOVERING"          // +2..+5/gün → iyileşiyor
        case stable             = "STABLE"              // ±2/gün → normal
        case deteriorating      = "DETERIORATING"       // -2..-5/gün → dikkat
        case deterioratingFast  = "DETERIORATING_FAST"  // -5-/gün → erken çıkış

        var emoji: String {
            switch self {
            case .recoveringFast:    return "🚀"
            case .recovering:        return "📈"
            case .stable:            return "➡️"
            case .deteriorating:     return "📉"
            case .deterioratingFast: return "🔻"
            }
        }

        var positionBoost: Double {
            switch self {
            case .recoveringFast:    return 0.40  // +40% ek boyut
            case .recovering:        return 0.20  // +20% ek boyut
            case .stable:            return 0.00  // Değişmez
            case .deteriorating:     return -0.20 // -%20 boyut kısma
            case .deterioratingFast: return -0.40 // -%40 boyut kısma
            }
        }
    }

    struct VelocityAnalysis {
        let currentScore: Double
        let velocity: Double          // Günlük değişim (puan/gün)
        let acceleration: Double      // Hız değişimi (puan/gün²)
        let signal: VelocitySignal
        let projectedScore5d: Double  // 5 gün sonrası tahmini
        let crossingAlert: CrossingAlert?

        enum CrossingAlert {
            case willCross25Upward(inDays: Int)   // Çöküş → Kötü'ye çıkacak
            case willCross40Upward(inDays: Int)   // Kötü → Dikkat'e çıkacak
            case willCross55Upward(inDays: Int)   // Dikkat → Nötr'e çıkacak
            case willCross25Downward(inDays: Int) // Tehlike: 25'in altına düşecek
            case willCross40Downward(inDays: Int) // Uyarı: 40'ın altına düşecek

            var description: String {
                switch self {
                case .willCross25Upward(let d):   return "⚡ \(d) günde kriz bölgesinden çıkıyor"
                case .willCross40Upward(let d):   return "📈 \(d) günde iyileşme bölgesine geçiyor"
                case .willCross55Upward(let d):   return "🚀 \(d) günde nötr bölgeye ulaşıyor"
                case .willCross25Downward(let d): return "🔴 \(d) günde kriz bölgesine girecek"
                case .willCross40Downward(let d): return "🟡 \(d) günde risk-off bölgesine girecek"
                }
            }
        }

        /// Velocity'i dikkate alarak düzeltilmiş Aether skoru
        /// Örn: Aether=22 ama hızlı iyileşiyor → efektif skor daha yüksek
        var effectiveScore: Double {
            let boost = signal.positionBoost * 15.0 // max ±15 puan kayma
            return max(0, min(100, currentScore + boost))
        }

        var summary: String {
            "\(signal.emoji) Aether \(Int(currentScore)) | Hız: \(String(format: "%+.1f", velocity))/gün | 5g Tahmin: \(Int(projectedScore5d))"
        }
    }

    // MARK: - State

    private var readings: [AetherReading] = []
    private let maxReadings = 30       // 30 okuma yeterli (saatlik → ~30 saat)
    private let persistPath: URL = FileManager.default.documentsURL
        .appendingPathComponent("aether_velocity.json")

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// Yeni Aether skoru ekle (her makro güncellemesinde çağrılmalı)
    func record(score: Double) {
        let reading = AetherReading(score: score, timestamp: Date())
        readings.append(reading)
        if readings.count > maxReadings {
            readings = Array(readings.suffix(maxReadings))
        }
        saveToDisk()
    }

    /// Güncel velocity analizi
    func analyze() -> VelocityAnalysis {
        guard readings.count >= 3 else {
            let score = readings.last?.score ?? 50
            return VelocityAnalysis(
                currentScore: score,
                velocity: 0,
                acceleration: 0,
                signal: .stable,
                projectedScore5d: score,
                crossingAlert: nil
            )
        }

        let current = readings.last!.score
        let velocity = calculateVelocity()
        let acceleration = calculateAcceleration()
        let signal = classifySignal(velocity: velocity, acceleration: acceleration)
        let projected5d = max(0, min(100, current + velocity * 5))
        let alert = detectCrossingAlert(current: current, velocity: velocity)

        return VelocityAnalysis(
            currentScore: current,
            velocity: velocity,
            acceleration: acceleration,
            signal: signal,
            projectedScore5d: projected5d,
            crossingAlert: alert
        )
    }

    /// Velocity'i dikkate alan düzeltilmiş pozisyon çarpanı
    /// RegimePositionSizer.multiplier() sonucuna ek olarak uygulanır
    func velocityAdjustedMultiplier(base: Double) -> Double {
        let analysis = analyze()

        // Kriz bölgesinde (< 25) ama hızlı iyileşiyorsa → küçük erken giriş izni
        if analysis.currentScore < 25 && analysis.signal == .recoveringFast {
            return max(base, 0.15) // min %15 — tamamen durma
        }

        // Kriz bölgesinde ama iyileşiyorsa → çok küçük giriş
        if analysis.currentScore < 25 && analysis.signal == .recovering {
            return max(base, 0.08)
        }

        // İyi bölgede ama hızlı bozuluyorsa → öne geç, küçül
        if analysis.currentScore > 40 && analysis.signal == .deterioratingFast {
            return base * 0.5
        }

        // Normal boost/azaltma
        let boost = analysis.signal.positionBoost
        return max(0, min(1.0, base + base * boost))
    }

    // MARK: - Hesaplama

    private func calculateVelocity() -> Double {
        guard readings.count >= 2 else { return 0 }

        // Son 5 okuma üzerinden lineer regresyon eğimi
        let recent = Array(readings.suffix(5))
        guard recent.count >= 2 else { return 0 }

        let n = Double(recent.count)
        let first = recent.first!.timestamp
        let xs = recent.map { $0.timestamp.timeIntervalSince(first) / 86400.0 } // gün cinsinden
        let ys = recent.map { $0.score }

        let xMean = xs.reduce(0, +) / n
        let yMean = ys.reduce(0, +) / n

        let num = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let den = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }

        guard den > 0 else { return 0 }
        return num / den
    }

    private func calculateAcceleration() -> Double {
        guard readings.count >= 5 else { return 0 }

        // Son 3 vs önceki 3'ün velocity farkı
        let recent = Array(readings.suffix(3))
        let prior = Array(readings.dropLast(3).suffix(3))

        let recentVel = velocityFor(readings: recent)
        let priorVel  = velocityFor(readings: prior)

        return recentVel - priorVel
    }

    private func velocityFor(readings: [AetherReading]) -> Double {
        guard readings.count >= 2 else { return 0 }
        let deltaScore = readings.last!.score - readings.first!.score
        let deltaTime  = max(0.01, readings.last!.timestamp.timeIntervalSince(readings.first!.timestamp) / 86400.0)
        return deltaScore / deltaTime
    }

    private func classifySignal(velocity: Double, acceleration: Double) -> VelocitySignal {
        switch velocity {
        case 5...:    return .recoveringFast
        case 2..<5:   return .recovering
        case -2..<2:  return acceleration > 2 ? .recovering : acceleration < -2 ? .deteriorating : .stable
        case -5..<(-2): return .deteriorating
        default:      return .deterioratingFast
        }
    }

    private func detectCrossingAlert(current: Double, velocity: Double) -> VelocityAnalysis.CrossingAlert? {
        guard abs(velocity) > 0.5 else { return nil }

        let thresholds: [(Double, Bool)] = [(25, true), (40, true), (55, true),
                                            (25, false), (40, false)]

        for (threshold, upward) in thresholds {
            if upward && velocity > 0 && current < threshold {
                let daysToReach = (threshold - current) / velocity
                if daysToReach > 0 && daysToReach <= 10 {
                    let d = Int(ceil(daysToReach))
                    switch threshold {
                    case 25: return .willCross25Upward(inDays: d)
                    case 40: return .willCross40Upward(inDays: d)
                    case 55: return .willCross55Upward(inDays: d)
                    default: break
                    }
                }
            } else if !upward && velocity < 0 && current > threshold {
                let daysToReach = (current - threshold) / (-velocity)
                if daysToReach > 0 && daysToReach <= 7 {
                    let d = Int(ceil(daysToReach))
                    switch threshold {
                    case 25: return .willCross25Downward(inDays: d)
                    case 40: return .willCross40Downward(inDays: d)
                    default: break
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(readings) {
            try? data.write(to: persistPath)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: persistPath),
              let decoded = try? JSONDecoder().decode([AetherReading].self, from: data) else { return }
        readings = decoded
    }
}
