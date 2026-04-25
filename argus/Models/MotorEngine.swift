import Foundation

/// Argus motorlarının tek giriş noktası — renk/logo sistemi bu enum üzerinden
/// eşleşir. Yeni motor eklerken burayı, `InstitutionalTheme.Colors.Motors`'ı
/// ve gerekiyorsa asset adını güncelle.
///
/// Kaynak: Sprint 1 Brief (2026-04-22), V5 mockup motor paleti.
enum MotorEngine: String, CaseIterable, Hashable, Sendable {
    // Ana konsey motorları
    case orion       // Teknik (mavi)
    case atlas       // Temel (açık mavi)
    case aether      // Makro (cyan)
    case hermes      // Haber (pembe)
    case prometheus  // Momentum (turuncu)
    case phoenix     // Külden diriliş (turuncu — V5 Prometheus reuse)
    case chiron      // Öğrenme (mor)
    case alkindus    // Post-mortem / kalibrasyon (gri)

    // Pantheon üyeleri
    case athena      // Strateji (sarı)
    case demeter     // Sektör (yeşil)

    // Genişleme slotları (V5'te ayrık asset yok — rezerv)
    case poseidon
    case titan
    case chronos
    case hephaestus

    // Agrega/dış temsiller
    case council     // Konsey kararı
    case argus       // Master — tüm sistem
}

/// V5 tasarım adaptörü — Sanctum modül tipini MotorEngine'e çevirir.
/// Kullanım: `MotorLogo(module.motor)` gibi.
extension SanctumModuleType {
    var motor: MotorEngine {
        switch self {
        case .atlas:      return .atlas
        case .orion:      return .orion
        case .aether:     return .aether
        case .hermes:     return .hermes
        case .athena:     return .athena
        case .demeter:    return .demeter
        case .chiron:     return .chiron
        case .prometheus: return .prometheus
        case .council:    return .council
        }
    }
}

extension SanctumBistModuleType {
    var motor: MotorEngine {
        switch self {
        case .tahta, .grafik, .moneyflow: return .orion
        case .kasa, .bilanco, .faktor:    return .atlas
        case .rejim, .sirkiye, .oracle:   return .aether
        case .kulis:                       return .hermes
        case .sektor:                      return .demeter
        case .vektor:                      return .prometheus
        }
    }
}
