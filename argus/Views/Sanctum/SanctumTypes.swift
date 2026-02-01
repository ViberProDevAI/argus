import SwiftUI

// MARK: - SANCTUM THEME CONSTANTS
/// Argus Sanctum görsel tema sabitleri.
/// Bloomberg V2 tasarım dili.
struct SanctumTheme {
    // Background: Deep Charcoal (Pro Terminal)
    static let bg = Color(hex: "0F172A") // Deep Navy Slate
    static let terminalBg = Color(hex: "121212") // Pure Dark Charcoal
    static let surface = Color(hex: "1E1E1E") // Card Surface
    
    // Core Palette (Bloomberg V3)
    static let hologramBlue = Color(hex: "38BDF8") // Active/Focus
    static let auroraGreen = Color(hex: "34D399") // Positive
    static let neonGreen = Color(hex: "00FF41") // Terminal Green (Sharp)
    static let titanGold = Color(hex: "FBBF24") // Mythic/Accent
    static let ghostGrey = Color(hex: "94A3B8") // Passive Text
    static let crimsonRed = Color(hex: "F43F5E") // Negative/Alert
    
    // Module Colors (Mapped to V2)
    static let orionColor = hologramBlue     // Technical -> Hologram Blue
    static let atlasColor = titanGold        // Fundamental -> Titan Gold
    static let aetherColor = ghostGrey       // Macro -> Ghost Grey (Neutral base)
    static let athenaColor = titanGold       // Smart Beta -> Titan Gold (Wisdom)
    static let hermesColor = Color(hex: "FB923C") // News -> Orange (distinct from gold)
    static let demeterColor = auroraGreen    // Sectors -> Aurora Green (Growth)
    static let chironColor = Color.white     // System -> White (Ultimate contrast)
    
    // Glass Effect
    static let glassMaterial = Material.thickMaterial
    static let proCardMaterial = Material.ultraThinMaterial
}

// MARK: - MODULE TYPE (Global Markets)
/// Global piyasalar icin Argus modulleri.
enum SanctumModuleType: String, CaseIterable {
    case atlas = "ATLAS"
    case orion = "ORION"
    case aether = "AETHER"
    case hermes = "HERMES"
    case athena = "ATHENA"
    case demeter = "DEMETER"
    case chiron = "CHIRON"
    case prometheus = "PROMETHEUS"
    case council = "COUNCIL"
    
    /// Custom neon asset icon (from Assets.xcassets)
    var assetIcon: String? {
        switch self {
        case .orion: return "OrionIcon"
        case .atlas: return "AtlasIcon"
        case .aether: return "AetherIcon"
        case .hermes: return "HermesIcon"
        default: return nil
        }
    }

    /// SF Symbol fallback icon
    var icon: String {
        switch self {
        case .atlas: return "building.columns.fill"
        case .orion: return "chart.xyaxis.line"
        case .aether: return "globe.europe.africa.fill"
        case .hermes: return "newspaper.fill"
        case .athena: return "brain.head.profile"
        case .demeter: return "leaf.fill"
        case .chiron: return "graduationcap.fill"
        case .prometheus: return "crystal.ball"
        case .council: return "building.columns.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .atlas: return SanctumTheme.atlasColor
        case .orion: return SanctumTheme.orionColor
        case .aether: return SanctumTheme.aetherColor
        case .hermes: return SanctumTheme.hermesColor
        case .athena: return SanctumTheme.athenaColor
        case .demeter: return SanctumTheme.demeterColor
        case .chiron: return SanctumTheme.chironColor
        case .prometheus: return SanctumTheme.hologramBlue
        case .council: return SanctumTheme.titanGold
        }
    }
    
    var description: String {
        switch self {
        case .atlas: return "Temel Analiz & Degerleme"
        case .orion: return "Teknik Indikatorler"
        case .aether: return "Makroekonomik Rejim"
        case .hermes: return "Haber & Duygu Analizi"
        case .athena: return "Akilli Varyans (Smart Beta)"
        case .demeter: return "Sektor & Endustri Analizi"
        case .chiron: return "Ogrenme & Risk Yonetimi"
        case .prometheus: return "5 Gunluk Fiyat Tahmini"
        case .council: return "Nihai Karar Mercii"
        }
    }
}

// MARK: - BIST MODULE TYPE (Turkiye Markets)
/// BIST piyasasi icin ozel Argus modulleri.
/// Konsolidasyon sonrasi: TAHTA (Teknik), KASA (Temel), REJIM (Makro)
enum SanctumBistModuleType: String, CaseIterable {
    // YENİ KONSOLİDE MODÜLLER
    case tahta = "TAHTA"        // Teknik Analiz Merkezi (Grafik + MoneyFlow + RS)
    case kasa = "KASA"          // Temel Analiz Merkezi (Bilanço + Faktör) - FAZA 2'de
    case rejim = "REJIM"        // Makro/Piyasa Modu (Sirkiye + Oracle + Sektör) - FAZA 3'te

    // ESKİ MODÜLLER (Geçiş sürecinde korunuyor)
    case bilanco = "BILANCO"    // Atlas karsiligi -> KASA'ya taşınacak
    case grafik = "GRAFIK"      // Orion karsiligi -> TAHTA'ya taşındı
    case sirkiye = "SIRKIYE"    // Aether karsiligi -> REJIM'e taşınacak
    case kulis = "KULIS"        // Hermes karsiligi
    case faktor = "FAKTOR"      // Athena karsiligi -> KASA'ya taşınacak
    case vektor = "VEKTOR"      // Prometheus karsiligi
    case sektor = "SEKTOR"      // Demeter karsiligi -> REJIM'e taşınacak
    case oracle = "ORACLE"      // Makro Sinyal Motoru -> REJIM'e taşınacak
    case moneyflow = "PARA-AKIL" // Para Girisi/Takas -> TAHTA'ya taşındı

    /// Custom neon asset icon (from Assets.xcassets)
    var assetIcon: String? {
        switch self {
        case .tahta, .grafik: return "OrionIcon"       // Teknik = Orion
        case .kasa, .bilanco: return "AtlasIcon"       // Temel = Atlas
        case .rejim, .sirkiye: return "AetherIcon"     // Makro = Aether
        case .kulis: return "HermesIcon"               // Haber = Hermes
        default: return nil
        }
    }

    /// SF Symbol fallback icon
    var icon: String {
        switch self {
        // Yeni modüller
        case .tahta: return "chart.xyaxis.line"
        case .kasa: return "building.columns.fill"
        case .rejim: return "globe.europe.africa.fill"
        // Eski modüller
        case .bilanco: return "building.columns.fill"
        case .grafik: return "chart.xyaxis.line"
        case .sirkiye: return "globe.europe.africa.fill"
        case .kulis: return "newspaper.fill"
        case .faktor: return "brain.head.profile"
        case .vektor: return "crystal.ball"
        case .sektor: return "leaf.fill"
        case .oracle: return "sparkles"
        case .moneyflow: return "arrow.up.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        // Yeni modüller
        case .tahta: return SanctumTheme.orionColor // Cyan/Blue
        case .kasa: return SanctumTheme.atlasColor // Gold
        case .rejim: return Color.purple // Purple
        // Eski modüller
        case .bilanco: return SanctumTheme.atlasColor
        case .grafik: return SanctumTheme.orionColor
        case .sirkiye: return SanctumTheme.aetherColor
        case .kulis: return SanctumTheme.hermesColor
        case .faktor: return SanctumTheme.athenaColor
        case .vektor: return SanctumTheme.hologramBlue
        case .sektor: return SanctumTheme.demeterColor
        case .oracle: return Color.purple
        case .moneyflow: return Color.green
        }
    }

    var description: String {
        switch self {
        // Yeni modüller
        case .tahta: return "Teknik Analiz Merkezi: SAR, TSI, RSI, Para Akışı, Rölatif Güç"
        case .kasa: return "Temel Analiz Merkezi: Bilanço, Rasyolar, Faktör Analizi"
        case .rejim: return "Piyasa & Makro Merkezi: Rejim, Oracle Sinyalleri, Sektör Rotasyonu"
        // Eski modüller
        case .bilanco: return "Bilanco ve Temel Veriler"
        case .grafik: return "Teknik Analiz ve Indikatorler"
        case .sirkiye: return "Makroekonomik Gostergeler (Sirkiye)"
        case .kulis: return "KAP Haberleri ve Duygu Analizi"
        case .faktor: return "Faktor Yatirimi (Smart Beta)"
        case .vektor: return "Yapay Zeka Fiyat Tahmini"
        case .sektor: return "Sektorel Performans Analizi"
        case .oracle: return "Makro Sinyal ve Etki Analizi"
        case .moneyflow: return "Para Giris/Cikis ve Takas Analizi"
        }
    }
}

extension SanctumModuleType: Identifiable {
    var id: String { rawValue }
}

extension SanctumBistModuleType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Type Aliases (Backward Compatibility)
/// ArgusSanctumView icindeki eski referanslar icin
typealias ModuleType = SanctumModuleType
typealias BistModuleType = SanctumBistModuleType

// MARK: - Module Icon View
/// Reusable view for rendering module icons with custom asset support
struct SanctumModuleIconView: View {
    let assetIcon: String?
    let sfSymbol: String
    var size: CGFloat = 20

    init(module: SanctumModuleType, size: CGFloat = 20) {
        self.assetIcon = module.assetIcon
        self.sfSymbol = module.icon
        self.size = size
    }

    init(bistModule: SanctumBistModuleType, size: CGFloat = 20) {
        self.assetIcon = bistModule.assetIcon
        self.sfSymbol = bistModule.icon
        self.size = size
    }

    init(assetIcon: String?, sfSymbol: String, size: CGFloat = 20) {
        self.assetIcon = assetIcon
        self.sfSymbol = sfSymbol
        self.size = size
    }

    var body: some View {
        Group {
            if let asset = assetIcon {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: sfSymbol)
            }
        }
        .frame(width: size, height: size)
    }
}
