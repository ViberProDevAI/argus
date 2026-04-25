import Foundation

// MARK: - Watchlist Pulse Monitor
//
// Felsefe:
// Aether şu ana kadar sadece makro veriye (TCMB, VIX, oranlar) bakıyor ve
// cevap vermesi gün/saat alıyor. Ama piyasada bir şey olduğunda — ateşkes,
// faiz kararı sürprizi, deprem, teknoloji açıklaması — izleme listesinin
// **TAMAMI birden** hareket eder. Bu motor o "ortak nabzı" ölçer:
//
// Kullanıcı ifadesiyle: "hepsinde ortak bir ani hareket olursa, hareketin
// hızını gözlemlesin mumlardan. bir şey olduğunu anlasın."
//
// Tek tek semboller değil, **cross-sectional ivme**: son 15 mumun ortalama
// yüzde değişimi + hacim spike oranı + uyum (aynı yönde hareket eden sembol oranı).
// Bu üçü birden yüksekse piyasa-geneli bir olay var demektir ve Aether hâlâ
// güncel değilse bile rejim dönüşüm detektörü bu nabzı kanıt olarak kullanır.

public actor WatchlistPulseMonitor {
    public static let shared = WatchlistPulseMonitor()

    public struct Pulse: Sendable {
        /// Son N mumda ortalama yüzde değişim (sembol başına, sonra ortalama).
        /// Pozitif = toplu yükseliş, negatif = toplu düşüş.
        public let avgMoveRate: Double

        /// Kaç sembol yukarı / aşağı hareket etti (son N mum son fiyatı vs N mum önce).
        public let symbolsUp: Int
        public let symbolsDown: Int
        public let totalSymbols: Int

        /// Hacim spike oranı: son N mumun ortalama hacmi / önceki 20 mumun ortalama hacmi.
        /// 1.0 = normal, 2.0 = iki kat, 0.5 = yarısı.
        public let volumeSpikeRatio: Double

        /// Uyum oranı: yukarı+aşağı / total (0-1). Yüksek = çoğu aynı yöne gidiyor.
        public var consensusRatio: Double {
            guard totalSymbols > 0 else { return 0 }
            return Double(max(symbolsUp, symbolsDown)) / Double(totalSymbols)
        }

        /// Sinyal sınıflandırması — piyasa nabzının kalitesi.
        public enum Intensity: String, Sendable {
            case dormant    = "DORMANT"     // Hiçbir şey olmuyor
            case normal     = "NORMAL"      // Rutin piyasa akışı
            case stirring   = "STIRRING"    // Bir şey başlıyor (consensus yüksek ama hız düşük)
            case surging    = "SURGING"     // Ani ortak hareket — OLAY
            case extreme    = "EXTREME"     // Neredeyse hepsinde aynı yönde sert hareket
        }

        public let intensity: Intensity

        /// Yön — toplu hareketin işareti.
        public enum Direction: String, Sendable {
            case up = "UP"
            case down = "DOWN"
            case mixed = "MIXED"
        }
        public let direction: Direction

        public let timestamp: Date

        public var summary: String {
            switch intensity {
            case .dormant:
                return "Nabız yok — watchlist sessiz"
            case .normal:
                return "Nabız normal"
            case .stirring:
                let dir = direction == .up ? "yukarı" : (direction == .down ? "aşağı" : "karışık")
                return "Kıpırdanma — %\(Int(consensusRatio * 100)) uyum \(dir) yönünde"
            case .surging:
                let dir = direction == .up ? "↑" : (direction == .down ? "↓" : "↕")
                return "TOPLU HAREKET \(dir) · %\(Int(consensusRatio * 100)) uyum · hız \(String(format: "%+.2f", avgMoveRate))%/mum · hacim ×\(String(format: "%.1f", volumeSpikeRatio))"
            case .extreme:
                let dir = direction == .up ? "🚀" : "💥"
                return "EKSTREM \(dir) · hepsi aynı yöne koşuyor · hız \(String(format: "%+.2f", avgMoveRate))%/mum"
            }
        }

        public static let empty = Pulse(
            avgMoveRate: 0,
            symbolsUp: 0,
            symbolsDown: 0,
            totalSymbols: 0,
            volumeSpikeRatio: 1.0,
            intensity: .dormant,
            direction: .mixed,
            timestamp: Date()
        )
    }

    private var lastPulse: Pulse = .empty

    private init() {}

    // MARK: - Public API

    /// Watchlist'in "son 15 mum nabzı". TradeBrainExecutor veya Settings'den periyodik çağrılır.
    /// - Parameters:
    ///   - candlesBySymbol: Her sembol için son mumlar (en az 25 mum olmalı).
    ///   - recentWindow: "Son" penceresi (varsayılan 15 mum — intraday yaklaşık 15 dakika).
    ///   - baselineWindow: Karşılaştırma (varsayılan önceki 20 mum, hacim için).
    func assess(
        candlesBySymbol: [String: [Candle]],
        recentWindow: Int = 15,
        baselineWindow: Int = 20
    ) -> Pulse {
        guard !candlesBySymbol.isEmpty else {
            lastPulse = .empty
            return .empty
        }

        var moveRates: [Double] = []
        var upCount = 0
        var downCount = 0
        var recentVolumes: [Double] = []
        var baselineVolumes: [Double] = []

        for (_, candles) in candlesBySymbol {
            // Yeterli veri yok → atla
            guard candles.count >= (recentWindow + baselineWindow) else { continue }

            let sorted = candles.sorted { $0.date < $1.date }
            let recent = Array(sorted.suffix(recentWindow))
            let baselineStart = sorted.count - recentWindow - baselineWindow
            let baseline = Array(sorted[baselineStart..<(baselineStart + baselineWindow)])

            guard let firstRecent = recent.first, let lastRecent = recent.last,
                  firstRecent.close > 0 else { continue }

            // Son N mumdaki toplam fiyat değişimi (%)
            let moveRate = ((lastRecent.close - firstRecent.close) / firstRecent.close) * 100.0
            moveRates.append(moveRate)

            // Yön sayımı — %0.5 eşiği (mikro gürültüyü elemek için)
            if moveRate > 0.5 {
                upCount += 1
            } else if moveRate < -0.5 {
                downCount += 1
            }

            // Hacim
            let recentVol = recent.map { $0.volume }.reduce(0, +) / Double(recent.count)
            let baselineVol = baseline.map { $0.volume }.reduce(0, +) / Double(baseline.count)
            if recentVol > 0 { recentVolumes.append(recentVol) }
            if baselineVol > 0 { baselineVolumes.append(baselineVol) }
        }

        let totalSymbols = moveRates.count
        guard totalSymbols > 0 else {
            lastPulse = .empty
            return .empty
        }

        let avgMove = moveRates.reduce(0, +) / Double(totalSymbols)

        // Hacim spike oranı — sembol başına ortalama oran
        let volumeSpike: Double = {
            guard !recentVolumes.isEmpty, !baselineVolumes.isEmpty else { return 1.0 }
            let avgRecent = recentVolumes.reduce(0, +) / Double(recentVolumes.count)
            let avgBaseline = baselineVolumes.reduce(0, +) / Double(baselineVolumes.count)
            guard avgBaseline > 0 else { return 1.0 }
            return avgRecent / avgBaseline
        }()

        // Yön
        let direction: Pulse.Direction = {
            if upCount > downCount * 2 { return .up }
            if downCount > upCount * 2 { return .down }
            return .mixed
        }()

        // Uyum oranı
        let consensusRatio = Double(max(upCount, downCount)) / Double(totalSymbols)

        // Yoğunluk sınıflandırması
        let intensity: Pulse.Intensity = {
            let absMove = Swift.abs(avgMove)

            // EXTREME: %70+ uyum + %2+ ortalama hareket + hacim ≥1.5x
            if consensusRatio >= 0.70 && absMove >= 2.0 && volumeSpike >= 1.5 {
                return .extreme
            }
            // SURGING: %55+ uyum + %1+ ortalama hareket + hacim ≥1.3x
            if consensusRatio >= 0.55 && absMove >= 1.0 && volumeSpike >= 1.3 {
                return .surging
            }
            // STIRRING: %50+ uyum ama hız/hacim zayıf — "bir şey başlıyor olabilir"
            if consensusRatio >= 0.50 && (absMove >= 0.5 || volumeSpike >= 1.2) {
                return .stirring
            }
            // NORMAL: az hareket ama toplu bir şey yok
            if absMove >= 0.2 || volumeSpike >= 1.1 {
                return .normal
            }
            return .dormant
        }()

        let pulse = Pulse(
            avgMoveRate: avgMove,
            symbolsUp: upCount,
            symbolsDown: downCount,
            totalSymbols: totalSymbols,
            volumeSpikeRatio: volumeSpike,
            intensity: intensity,
            direction: direction,
            timestamp: Date()
        )
        lastPulse = pulse
        return pulse
    }

    public func getLast() -> Pulse {
        return lastPulse
    }
}
