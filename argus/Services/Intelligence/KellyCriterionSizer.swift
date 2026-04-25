import Foundation

// MARK: - Kelly Criterion Position Sizer
/// Alkindus'un geçmiş verdict'lerinden hesaplanan kazanma/kaybetme oranlarını kullanarak
/// optimal pozisyon boyutunu belirler. Sabit %5/%10 yerine dinamik, kanıta dayalı boyutlama.
///
/// Kelly Formülü: f* = (b·p - q) / b
///   f* = optimal bahis oranı (0..1)
///   b  = ort. kazanç / ort. kayıp (odds)
///   p  = kazanma olasılığı
///   q  = kaybetme olasılığı (1 - p)
///
/// Güvenlik için Half-Kelly kullanılır (f* / 2) — tam Kelly çok agresif.

struct KellyCriterionSizer {

    struct KellyProfile {
        let winRate: Double        // p
        let avgWinPct: Double      // Ortalama kazanç (%)
        let avgLossPct: Double     // Ortalama kayıp (%)
        let sampleSize: Int        // Veri sayısı
        let kellyFraction: Double  // Hesaplanan f* (half-Kelly)
        let confidence: KellyConfidence

        enum KellyConfidence {
            case low(reason: String)    // < 10 örnek → güvenme
            case medium                  // 10-30 örnek
            case high                    // 30+ örnek

            var multiplier: Double {
                switch self {
                case .low:    return 0.3   // Kelly'i %30'a indir
                case .medium: return 0.6   // Kelly'i %60'a indir
                case .high:   return 1.0   // Kelly'i tam uygula
                }
            }
        }

        /// Gerçekte kullanılacak final oran (güven ağırlıklı)
        var effectiveFraction: Double {
            kellyFraction * confidence.multiplier
        }

        /// Base percent'e uygulanacak çarpan (0.5x – 2.0x arası)
        /// Merkez: 1.0x (kelly sayısı yok, historik veri yeterli değil)
        var positionMultiplier: Double {
            let ef = effectiveFraction
            if ef <= 0 { return 0.3 } // Negatif Kelly = çok küçük pozisyon
            // ef=0.5 → 1.0x, ef=1.0 → 2.0x, ef=0.0 → 0.0x
            // normalize: base 0.5 kelly = 1.0x multiplier
            let normalized = ef / 0.5
            return max(0.3, min(2.0, normalized))
        }
    }

    // MARK: - Ana Hesaplama

    /// Verilen sembol ve modül kombinasyonu için Kelly profili hesapla
    static func calculate(
        symbol: String? = nil,
        regime: String? = nil,
        verdicts: [AlkindusVerdict]
    ) -> KellyProfile {

        // Filtreleme
        var filtered = verdicts
        if let sym = symbol {
            filtered = filtered.filter { $0.symbol == sym }
        }
        if let reg = regime {
            filtered = filtered.filter { $0.regime.lowercased().contains(reg.lowercased()) }
        }

        guard filtered.count >= 5 else {
            return KellyProfile(
                winRate: 0.5,
                avgWinPct: 2.0,
                avgLossPct: 2.0,
                sampleSize: filtered.count,
                kellyFraction: 0.25,
                confidence: .low(reason: "Yeterli veri yok (\(filtered.count) örnek)")
            )
        }

        let wins  = filtered.filter { $0.wasCorrect }
        let losses = filtered.filter { !$0.wasCorrect }

        let p = Double(wins.count) / Double(filtered.count)
        let q = 1 - p

        // Ortalama kazanç/kayıp yüzdeleri
        let avgWin  = wins.isEmpty  ? 2.0 : wins.map  { abs($0.priceChange) }.reduce(0, +) / Double(wins.count)
        let avgLoss = losses.isEmpty ? 2.0 : losses.map { abs($0.priceChange) }.reduce(0, +) / Double(losses.count)

        // b = odds ratio (her 1 birim kayıp için kaç birim kazanç)
        let b = avgWin / max(0.1, avgLoss)

        // Kelly: f* = (b·p - q) / b, sonra half-kelly için /2
        let kelly = (b * p - q) / b
        let halfKelly = max(0, kelly / 2.0)

        let confidence: KellyProfile.KellyConfidence
        switch filtered.count {
        case ..<10:  confidence = .low(reason: "\(filtered.count) örnek")
        case 10..<30: confidence = .medium
        default:     confidence = .high
        }

        return KellyProfile(
            winRate: p,
            avgWinPct: avgWin,
            avgLossPct: avgLoss,
            sampleSize: filtered.count,
            kellyFraction: halfKelly,
            confidence: confidence
        )
    }

    /// Tüm verdicts'ten genel sistem Kelly profili
    static func systemProfile(verdicts: [AlkindusVerdict]) -> KellyProfile {
        calculate(symbol: nil, regime: nil, verdicts: verdicts)
    }

    /// Sembol × Rejim spesifik Kelly (en granüler)
    static func specificProfile(
        symbol: String,
        regime: MarketRegime,
        verdicts: [AlkindusVerdict]
    ) -> KellyProfile {
        // Önce spesifik, yeterli veri yoksa genele dön
        let specific = calculate(symbol: symbol, regime: regime.rawValue, verdicts: verdicts)
        if specific.sampleSize >= 10 { return specific }

        let symbolOnly = calculate(symbol: symbol, regime: nil, verdicts: verdicts)
        if symbolOnly.sampleSize >= 10 { return symbolOnly }

        return systemProfile(verdicts: verdicts)
    }
}

// MARK: - Kelly Cache (async, actor-safe)
/// Alkindus verdict'lerini asenkron yükleyip Kelly profilini cache'ler
actor KellyCache {
    static let shared = KellyCache()
    private var systemProfile: KellyCriterionSizer.KellyProfile?
    private var lastUpdated: Date?
    private let staleDuration: TimeInterval = 3600 // 1 saat

    func getSystemProfile() async -> KellyCriterionSizer.KellyProfile {
        if let cached = systemProfile,
           let last = lastUpdated,
           Date().timeIntervalSince(last) < staleDuration {
            return cached
        }

        let verdicts = await AlkindusMemoryStore.shared.loadVerdicts()
        let profile = KellyCriterionSizer.systemProfile(verdicts: verdicts)
        systemProfile = profile
        lastUpdated = Date()

        let conf: String
        switch profile.confidence {
        case .low(let r): conf = "Düşük (\(r))"
        case .medium:     conf = "Orta"
        case .high:       conf = "Yüksek"
        }
        print("🎯 Kelly: WinRate=\(String(format: "%.0f%%", profile.winRate*100)) Odds=\(String(format: "%.2f", profile.avgWinPct/max(0.1,profile.avgLossPct))) f*=\(String(format: "%.2f", profile.kellyFraction)) Güven=\(conf)")

        return profile
    }

    func invalidate() { systemProfile = nil }
}
