import Foundation

// MARK: - Entry Engine Contract
// Argus'un "ne alınır" (Orion kanaat) + "ne zaman/hangi fiyattan" (Entry setup)
// ayrımının core contract'ı. Her sembol için EntrySetup şunu söyler:
//   - Şu an girilebilir mi? Hangi grade? (A/B/C/reject)
//   - Girilecekse: hangi fiyat zonunda, hangi trigger ile, stop ve hedef nerede?
//   - Girilmeyecekse: neden, ve ne bekleniyor?

/// Giriş setup kalitesi. Reject her zaman bir sebep taşır — sessiz "al" yasak.
enum EntryGrade: Equatable {
    case a                        // R:R ≥ 3, 2+ confluence, çoklu TF hizalı
    case b                        // R:R ≥ 2.5, 1+ confluence
    case c                        // R:R ≥ 2, zayıf confluence
    case reject(reason: String)   // Grade yok — kullanıcıya neden söyle

    var isActionable: Bool {
        switch self {
        case .a, .b, .c: return true
        case .reject: return false
        }
    }

    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .reject: return "BEKLE"
        }
    }
}

/// Tetik türü — setup'ın NE ZAMAN aktif olacağını tarif eder.
/// Fiyat zonuna girmek setup'ı "olgunlaştırır", trigger bar kapanışı olayı setup'ı "ateşler".
enum EntryTrigger: Equatable {
    /// Belirli bir EMA seviyesine geri çekilme + destek teyidi.
    case pullbackToEMA(emaPeriod: Int, level: Double)
    /// Önceki swing low'a geri çekilme.
    case pullbackToSwingLow(level: Double)
    /// Direnç kırılımı + minimum hacim çarpanı (ör. 1.3x ortalama).
    case breakoutAbove(level: Double, minVolumeMultiplier: Double)
    /// Destek seviyesinde reversal candle (hammer/engulfing) teyidi.
    case supportRetest(level: Double)

    var userDescription: String {
        switch self {
        case .pullbackToEMA(let period, let level):
            return String(format: "%d-EMA (%.2f) retest", period, level)
        case .pullbackToSwingLow(let level):
            return String(format: "Önceki dip retest (%.2f)", level)
        case .breakoutAbove(let level, let mult):
            return String(format: "%.2f kırılım + hacim ×%.1f", level, mult)
        case .supportRetest(let level):
            return String(format: "%.2f desteğinde dönüş", level)
        }
    }
}

/// Fiyatın yakınındaki anlamlı seviyeler. R:R ve trigger hesapları buradan beslenir.
struct KeyLevels: Equatable {
    let ema20: Double?
    let ema50: Double?
    let ema200: Double?
    let atr14: Double?
    /// Klasik günlük pivot (H+L+C)/3.
    let pivot: Double?
    /// Son 90 barın en yüksek kapanışı (direnç).
    let recentHigh90d: Double?
    /// Son 90 barın en düşük kapanışı (destek).
    let recentLow90d: Double?
    /// Son major swing low→high'a göre Fibonacci retracement seviyeleri.
    let fib38: Double?
    let fib50: Double?
    let fib62: Double?
}

/// Setup'ı güçlendiren / onaylayan bağımsız faktörler. Ne kadar çok, o kadar yüksek grade.
enum ConfluenceFactor: Equatable {
    case emaSupport(period: Int)   // Fiyat 20 veya 50 EMA'ya oturdu
    case fibonacciLevel(Double)    // 38/50/62 fib seviyesinde
    case rsiCooldown               // RSI 70+ → 50-65'e soğudu
    case volumeDryUp               // Pullback sırasında hacim ortalamadan düşük
    case hammerCandle              // Son barda hammer / bullish engulfing

    var userDescription: String {
        switch self {
        case .emaSupport(let p): return "\(p)-EMA desteği"
        case .fibonacciLevel(let f): return String(format: "Fib %.0f%%", f * 100)
        case .rsiCooldown: return "RSI soğudu"
        case .volumeDryUp: return "Hacim kurudu"
        case .hammerCandle: return "Reversal bar"
        }
    }
}

/// Ana çıktı — kullanıcının "al" butonuna basmadan önce göreceği tam resim.
struct EntrySetup: Equatable {
    let symbol: String
    let grade: EntryGrade
    /// Giriş penceresi. Fiyat bu aralıktaysa setup "olgun"; dışındaysa bekle.
    let entryZone: ClosedRange<Double>?
    let trigger: EntryTrigger?
    /// Zorunlu stop (long için entry altı). Nil sadece reject'te olabilir.
    let stopPrice: Double?
    /// Kademeli hedefler (TP1, TP2, ...). R:R ≥ 2'yi garantiler.
    let targets: [Double]
    /// Reward / Risk. 2.0 = 2R kazanç için 1R risk.
    let rrRatio: Double?
    let confluence: [ConfluenceFactor]
    /// Setup ne zaman geçersizleşir (ör. 2 iş günü).
    let validUntil: Date
    let generatedAt: Date
    /// Reject'te neden, ready'de null (veya "fiyat zona girene kadar bekle" notu).
    let waitMessage: String?

    /// UI için: setup aktif mi (grade = actionable VE validUntil geçmemiş VE zorunlu alanlar dolu)?
    var isActionable: Bool {
        guard grade.isActionable else { return false }
        guard validUntil > Date() else { return false }
        return entryZone != nil && stopPrice != nil && !targets.isEmpty
    }

    /// Mevcut fiyat giriş zonu içinde mi? (UI "şu an girilebilir" mi göstermek için)
    func isPriceInZone(_ price: Double) -> Bool {
        guard let zone = entryZone else { return false }
        return zone.contains(price)
    }
}
