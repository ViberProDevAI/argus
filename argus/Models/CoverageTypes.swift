import Foundation

// MARK: - Veri Kapsama Türleri
//
// Bu tipler eskiden `ArgusLabModels.swift` içinde tanımlıydı; Lab sistemi kaldırıldığında
// buraya ayrı bir dosyaya taşındı. Lab ile semantik bağları yok — DataHealth, scout
// taraması ve decision engine'in "veri yeterli mi?" kararı için genel altyapıdır.

/// Coverage Level: Bir sinyalin resmi istatistiklere dahil edilecek kadar veriye sahip olup olmadığını belirler.
public enum CoverageLevel: String, Codable {
    case full       // çekirdek istatistiklere dahil
    case partial    // veri var ama eksik / sınırlı
    case invalid    // bu veriyle karar vermek mantıksız
}

/// Her veri bacağını (teknik, temel, makro, haber) ayrı takip eden bileşen.
public struct CoverageComponent: Codable, Equatable {
    public var available: Bool      // veri var mı?
    public var quality: Double      // 0.0 – 1.0 (0: yok/çok kötü, 1: sağlam)
    public var lastUpdated: Date?

    public init(available: Bool, quality: Double, lastUpdated: Date? = nil) {
        self.available = available
        self.quality = quality
        self.lastUpdated = lastUpdated
    }

    public static var missing: CoverageComponent {
        CoverageComponent(available: false, quality: 0.0, lastUpdated: nil)
    }

    public static func present(quality: Double) -> CoverageComponent {
        CoverageComponent(available: true, quality: max(0.0, min(quality, 1.0)), lastUpdated: Date())
    }

    /// Veri hâlâ taze mi (maxAge saniye içinde güncellenmiş mi)?
    public func isFresh(maxAge: TimeInterval) -> Bool {
        guard available, let updated = lastUpdated else { return false }
        return Date().timeIntervalSince(updated) < maxAge
    }

    /// Modül ağırlığı çarpanı — stale/missing ise 0, taze ise quality.
    public func effectiveWeight(maxAge: TimeInterval) -> Double {
        return isFresh(maxAge: maxAge) ? quality : 0.0
    }
}
