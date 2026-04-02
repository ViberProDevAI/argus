import Foundation

/// Aether makro skoru + piyasa rejimine göre pozisyon büyüklüğü çarpanı hesaplar.
/// Boğa piyasasında agresif, ayı/çöküş piyasasında küçük veya sıfır.
struct RegimePositionSizer: Sendable {

    /// Aether skoru + piyasa rejimine göre base percent çarpanı döner (0.0 – 1.0).
    /// 0.0 = alım yok, 1.0 = tam boyut
    static func multiplier(aetherScore: Double, regime: MarketRegime) -> Double {
        let macroFactor: Double
        switch aetherScore {
        case 70...:    macroFactor = 1.0   // Boğa: tam gaz
        case 55..<70:  macroFactor = 0.75  // Nötr: %75
        case 40..<55:  macroFactor = 0.50  // Dikkat: %50
        case 25..<40:  macroFactor = 0.25  // Kötü: %25 (toe-hold)
        default:       macroFactor = 0.0   // Çöküş: sıfır giriş
        }

        let regimeFactor: Double
        switch regime {
        case .riskOff:   regimeFactor = 0.0   // Ayı rejimi: dur
        case .chop:      regimeFactor = 0.5   // Yatay: küçük
        case .neutral:   regimeFactor = 0.8   // Nötr
        case .trend:     regimeFactor = 1.0   // Trend: tam
        case .newsShock: regimeFactor = 0.5   // Haber şoku: küçük
        }

        return min(macroFactor, regimeFactor)
    }
}
