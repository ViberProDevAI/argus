import Foundation

// MARK: - User-facing display names
//
// 2026-04-24 H-28 — UI'da motor isimleri mitolojik kod adı yerine işlev
// adı ile gösterilir. Internal kod (case .athena) aynı kalır; sadece
// kullanıcının okuduğu metin değişir.
//
// Tek source-of-truth: bu dosya. Sanctum orb caption, Drawer item,
// chip text, accessibility label — hepsi `motor.displayName` veya
// `motor.shortName` üzerinden okur.
//
// Kural:
//   • `displayName`     — uzun form ("Bilanço", "Konsey kararı")
//   • `shortName`       — pill/chip için kısa form (genelde aynı)
//   • `isUserFacing`    — UI'da gösterilebilir mi (Athena şu an false)
//   • `description`     — bir cümle açıklama (tooltip/onboarding için)

extension MotorEngine {
    /// Kullanıcının ekranda göreceği işlev adı.
    var displayName: String {
        switch self {
        case .atlas:      return "Bilanço"
        case .orion:      return "Teknik"
        case .aether:     return "Makro"
        case .hermes:     return "Haber"
        case .demeter:    return "Sektör"
        case .chiron:     return "Rejim"
        case .prometheus: return "Tahmin"
        case .phoenix:    return "Tahmin"      // Prometheus ile birleşik
        case .athena:     return "Athena"      // İçeride yaşıyor, UI'de gizli
        case .alkindus:   return "Alkindus"    // Marka adı
        case .council:    return "Konsey"
        case .argus:      return "Argus"       // Marka adı
        case .poseidon, .titan, .chronos, .hephaestus:
            return rawValue.capitalized        // Rezerv — UI'de görünmez
        }
    }

    /// Pill/chip gibi dar yerlerde kullanılacak kısa form.
    /// Bugün hepsi `displayName` ile aynı; ileride "Bilanço" yerine
    /// "Bil." gerekirse burada özelleşir.
    var shortName: String { displayName }

    /// Bu motor user-facing yüzeylerde gösterilmeli mi?
    /// Athena: veri akışı henüz oturmadığı için ekrandan çıkarıldı —
    /// veri sağlamca akmaya başlayınca tek satırla `true` olur.
    /// Phoenix: Prometheus ile aynı işlevi gördüğü için "Tahmin" altında
    /// birleşti — ayrı orb göstermiyoruz.
    /// Reserved (poseidon/titan/chronos/hephaestus): asset/akış yok.
    var isUserFacing: Bool {
        switch self {
        case .atlas, .orion, .aether, .hermes, .demeter, .chiron, .prometheus:
            return true
        case .alkindus, .council, .argus:
            return true
        case .athena, .phoenix:
            return false
        case .poseidon, .titan, .chronos, .hephaestus:
            return false
        }
    }

    /// Tek cümle açıklama — tooltip / onboarding / accessibility hint için.
    var functionDescription: String {
        switch self {
        case .atlas:      return "Temel analiz · F/K, borç, nakit akışı"
        case .orion:      return "Teknik analiz · fiyat, hacim, formasyon"
        case .aether:     return "Makro rejim · risk-on/off, faiz, küresel"
        case .hermes:     return "Haber akışı · sentiment ve etki yorumu"
        case .demeter:    return "Sektör rotasyonu ve karşılaştırma"
        case .chiron:     return "Piyasa rejimi · trend / yatay / risk-off"
        case .prometheus: return "Yön tahmini · güven ve zaman ufku"
        case .phoenix:    return "Regresyon — Tahmin altında çalışır"
        case .athena:     return "Sentez katmanı · veri akışı bekleniyor"
        case .alkindus:   return "Yapay zeka asistanı"
        case .council:    return "Tüm motorların ortak kararı"
        case .argus:      return "Argus — sistemin tamamı"
        case .poseidon, .titan, .chronos, .hephaestus:
            return "Rezerv motor"
        }
    }
}

// MARK: - SanctumModuleType convenience

extension SanctumModuleType {
    /// `module.motor.displayName` zincirini kısaltır — render kodu
    /// `Text(module.displayName)` yazabilir.
    var displayName: String { motor.displayName }

    /// Sanctum halkasında orb olarak görünmeli mi?
    /// Athena false döner, halkanın 8 değil 7 orb ile çizilmesini sağlar.
    var isVisibleInRing: Bool { motor.isUserFacing }

    var functionDescription: String { motor.functionDescription }
}

// MARK: - SanctumBistModuleType convenience
//
// 2026-04-24 H-28: BIST tarafındaki "Tahta / Kasa / Kulis / Sirkiye / Kısmet"
// jargon adları kullanıcı UI'sinden çıkarıldı. Hem global hem BIST tek
// işlev sözlüğünden okur. Sirkiye TAB adı olarak kalır (sirk + Türkiye),
// modül adı olarak değil.

extension SanctumBistModuleType {
    var displayName: String { motor.displayName }
    var isVisibleInRing: Bool { motor.isUserFacing }
    var functionDescription: String { motor.functionDescription }
}
