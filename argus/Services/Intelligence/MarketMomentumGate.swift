import Foundation

// MARK: - Market Momentum Gate
/// Fiyat/hacim verilerinden saatlik bazlı hızlı rejim değişimi tespiti.
/// Yavaş güncellenen Aether (haftalık) üzerinde oturan breadth katmanı.
/// Rally başlarken rejim hâlâ riskOff kalabilir — bu gate o boşluğu kapatır.
///
/// Mimari:
///   Global watchlist (non-.IS) → globalSignal
///   BIST watchlist (.IS)       → bistSignal
/// Her iki sinyalin sonucu RegimePositionSizer'a momentumFloor olarak geçer.

actor MarketMomentumGate {
    static let shared = MarketMomentumGate()

    private init() {}

    // MARK: - Momentum Signal

    struct MomentumSignal: Sendable {
        enum Level: String, Sendable {
            case neutral  = "NEUTRAL"   // breadth <40%  → floor=0 (hiçbir etkisi yok)
            case building = "BUILDING"  // breadth 40–60% → floor=35
            case strong   = "STRONG"    // breadth 60–75% → floor=45
            case extreme  = "EXTREME"   // breadth >75%   → floor=55
        }

        let level: Level
        let breadthPct: Double   // Rally kriterini karşılayan sembol yüzdesi
        let aetherFloor: Double  // RegimePositionSizer'a geçecek minimum Aether değeri
        let symbolCount: Int     // Hesaba katılan sembol sayısı
        let rallyCount: Int      // Rally kriterini geçen sembol sayısı
        let timestamp: Date

        /// Momentum sinyali aktif mi? (floor uygulanmalı mı?)
        var isActive: Bool { level != .neutral }

        static let neutral = MomentumSignal(
            level: .neutral, breadthPct: 0, aetherFloor: 0,
            symbolCount: 0, rallyCount: 0, timestamp: .distantPast
        )

        var summary: String {
            "\(level.rawValue) — %\(Int(breadthPct)) breadth (\(rallyCount)/\(symbolCount)) floor=\(Int(aetherFloor))"
        }
    }

    // MARK: - Cache (15 dakikalık — fade tespiti için kısa, noise için yeterli uzun)
    // NOT: Cache koşulunda isActive kullanmıyoruz.
    // Önceki implementasyonda `globalSignal.isActive && age < 4h` kontrolü vardı;
    // bu, sinyal BUILDING iken breadth gerçekten düşse bile 4 saat boyunca eski
    // BUILDING sonucunu döndürüyor, fade exit'in ateşlenmesini engelliyordu.
    // Düzeltme: Sinyal aktif olsun ya da olmasın, 15 dakika sonra yeniden hesapla.

    private var globalSignal: MomentumSignal = .neutral
    private var bistSignal: MomentumSignal   = .neutral
    private let cacheLifespan: TimeInterval  = 15 * 60   // 15 dakika

    // MARK: - Public API

    /// Global piyasa breadth analizi (non-.IS sembolleri: S&P, Nasdaq bileşenleri vb.)
    func assessGlobal(
        quotes: [String: Quote],
        candles: [String: [Candle]],
        watchlistSymbols: [String]
    ) -> MomentumSignal {
        // Sinyal aktif/pasif ayrımı yapmadan süresi dolmuşsa yeniden hesapla
        if Date().timeIntervalSince(globalSignal.timestamp) < cacheLifespan {
            return globalSignal
        }
        let symbols = watchlistSymbols.filter { !$0.hasSuffix(".IS") }
        let signal = computeBreadth(symbols: symbols, quotes: quotes, candles: candles)
        globalSignal = signal
        // Veri tazelik sicili — UI rozeti ve diğer karar motorları sorgulayabilsin
        Task { await StaleDataRegistry.shared.touch("momentum.global") }
        return signal
    }

    /// BIST breadth analizi (.IS sembolleri)
    func assessBist(
        quotes: [String: Quote],
        candles: [String: [Candle]],
        watchlistSymbols: [String]
    ) -> MomentumSignal {
        if Date().timeIntervalSince(bistSignal.timestamp) < cacheLifespan {
            return bistSignal
        }
        let symbols = watchlistSymbols.filter { $0.hasSuffix(".IS") }
        let signal = computeBreadth(symbols: symbols, quotes: quotes, candles: candles)
        bistSignal = signal
        Task { await StaleDataRegistry.shared.touch("momentum.bist") }
        return signal
    }

    /// Cache'i sıfırla (test / zorla yenileme için)
    func resetCache() {
        globalSignal = .neutral
        bistSignal   = .neutral
    }

    // MARK: - Core Breadth Hesabı

    /// Rally kriteri:
    ///   1. Günlük değişim > +1.5%
    ///   2. Hacim, son 20 günlük ortalamanın ≥ 1.2x üzerinde
    /// İki kriter birden gerekli — sadece fiyat yetmez, hacim teyit etmeli.
    private func computeBreadth(
        symbols: [String],
        quotes: [String: Quote],
        candles: [String: [Candle]]
    ) -> MomentumSignal {
        guard symbols.count >= 5 else { return .neutral }

        var rallyCount = 0
        var validCount = 0

        for symbol in symbols {
            guard let quote = quotes[symbol], quote.currentPrice > 0 else { continue }

            // Fiyat kanalı: +1.5% üzeri artış
            let changePercent = quote.percentChange
            let isUp = changePercent > 1.5

            // Hacim teyidi: bugünkü hacim ortalama ≥ 1.2x
            //
            // Güvenlik düzeltmesi: Eski sürüm mum verisi yetersizse `isHighVolume = true`
            // dönerek hacim kontrolünü tamamen atlıyordu. Bu düşük likiditeli BIST
            // hisselerinde pump&dump sinyallerinin rally olarak sayılmasına yol açıyordu.
            // Yeni davranış: mum verisi yetersizse sembol rally sayımına **hiç katılmaz**
            // (validCount de artmaz), böylece ölçüm gerçek hacim teyidiyle yapılır.
            let isHighVolume: Bool
            let hasReliableVolume: Bool
            if let symbolCandles = candles[symbol], symbolCandles.count >= 10 {
                let recentCandles = symbolCandles.suffix(20)
                let avgVolume = recentCandles.map { $0.volume }.reduce(0, +) / Double(recentCandles.count)
                let todayVolume: Double
                if let todayVol = quote.volume, todayVol > 0 {
                    todayVolume = todayVol
                } else {
                    todayVolume = symbolCandles.last?.volume ?? 0
                }
                isHighVolume = avgVolume > 0 && todayVolume >= avgVolume * 1.2
                hasReliableVolume = avgVolume > 0
            } else {
                isHighVolume = false
                hasReliableVolume = false
            }

            // Güvenilir hacim yoksa bu sembol breadth hesabına girmez.
            guard hasReliableVolume else { continue }

            validCount += 1
            if isUp && isHighVolume {
                rallyCount += 1
            }
        }

        guard validCount >= 5 else { return .neutral }

        let breadthPct = Double(rallyCount) / Double(validCount) * 100.0

        let level: MomentumSignal.Level
        let floor: Double

        switch breadthPct {
        case 75...:      level = .extreme;  floor = 55
        case 60..<75:    level = .strong;   floor = 45
        case 40..<60:    level = .building; floor = 35
        default:         level = .neutral;  floor = 0
        }

        return MomentumSignal(
            level: level,
            breadthPct: breadthPct,
            aetherFloor: floor,
            symbolCount: validCount,
            rallyCount: rallyCount,
            timestamp: Date()
        )
    }
}
