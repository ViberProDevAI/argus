import SwiftUI

// MARK: - SANCTUM THEME CONSTANTS
/// Argus Sanctum görsel tema sabitleri.
/// Bloomberg V2 tasarım dili.
struct SanctumTheme {
    // Background: Institutional System
    static let bg = InstitutionalTheme.Colors.background
    static let terminalBg = InstitutionalTheme.Colors.surface1
    static let surface = InstitutionalTheme.Colors.surface2
    
    // Core Palette (Bloomberg V3)
    static let hologramBlue = InstitutionalTheme.Colors.primary
    static let auroraGreen = InstitutionalTheme.Colors.positive
    static let neonGreen = InstitutionalTheme.Colors.positive
    static let titanGold = InstitutionalTheme.Colors.neutral      // Artık neutral gri
    static let ghostGrey = InstitutionalTheme.Colors.textSecondary
    static let crimsonRed = InstitutionalTheme.Colors.negative
    
    // Module Colors (Mapped to V2)
    static let orionColor = hologramBlue     // Technical -> Hologram Blue
    static let atlasColor = hologramBlue     // Fundamental -> Mavi (artık altın yok)
    static let aetherColor = ghostGrey       // Macro -> Ghost Grey (Neutral base)
    static let athenaColor = hologramBlue    // Smart Beta -> Mavi
    static let hermesColor = InstitutionalTheme.Colors.neutral
    static let demeterColor = auroraGreen    // Sectors -> Aurora Green (Growth)
    static let chironColor = InstitutionalTheme.Colors.textPrimary
    
    // Glass Effect
    static let glassMaterial = Material.thickMaterial
    static let proCardMaterial = Material.ultraThinMaterial
}

// MARK: - Council Education Language
/// Konsey kararlarını tavsiye-dışı, öğretici bir 5 aşamalı dile çevirir.
struct CouncilEducationStage {
    let level: Int
    let title: String
    let scenarioLabel: String
    let color: Color
    let why: String
    let uncertainty: String
    let invalidation: String
    let learningNote: String

    let disclaimer = "Eğitim amaçlıdır, yatırım tavsiyesi değildir."

    var badgeText: String { "SEVIYE \(level)" }
}

extension ArgusGrandDecision {
    var educationStage: CouncilEducationStage {
        let normalizedConfidence = max(0, min(confidence, 1))

        var level = Self.baseEducationLevel(normalizedConfidence)
        if contributors.count <= 1 { level = min(level, 2) }
        if action == .neutral { level = min(level, 3) }
        if !vetoes.isEmpty { level = min(level, 3) }

        let title: String
        switch level {
        case 1: title = "Veri Zayif"
        case 2: title = "Erken Sinyal"
        case 3: title = "Karisik Gorunum"
        case 4: title = "Guclu Senaryo"
        default: title = "Teyitli Senaryo"
        }

        let scenarioLabel: String
        switch action {
        case .aggressiveBuy, .accumulate:
            scenarioLabel = "Olumlu Senaryo"
        case .neutral:
            scenarioLabel = "Notr Senaryo"
        case .trim, .liquidate:
            scenarioLabel = "Temkinli Senaryo"
        }

        let color: Color
        switch level {
        case 1: color = SanctumTheme.crimsonRed
        case 2: color = Color.orange
        case 3: color = SanctumTheme.titanGold
        case 4: color = SanctumTheme.hologramBlue
        default: color = SanctumTheme.auroraGreen
        }

        let whyText = Self.cleanText(reasoning, fallback: "Bu asamada veri toplama suruyor.")
        let uncertaintyText = Self.uncertaintyText(
            confidence: normalizedConfidence,
            contributors: contributors,
            vetoes: vetoes
        )
        let invalidationText = Self.invalidationText(
            action: action,
            confidence: normalizedConfidence,
            vetoes: vetoes
        )
        let learningText = Self.learningNote(contributors: contributors)

        return CouncilEducationStage(
            level: level,
            title: title,
            scenarioLabel: scenarioLabel,
            color: color,
            why: whyText,
            uncertainty: uncertaintyText,
            invalidation: invalidationText,
            learningNote: learningText
        )
    }

    private static func baseEducationLevel(_ confidence: Double) -> Int {
        switch confidence {
        case ..<0.20: return 1
        case ..<0.40: return 2
        case ..<0.60: return 3
        case ..<0.80: return 4
        default: return 5
        }
    }

    private static func uncertaintyText(
        confidence: Double,
        contributors: [ModuleContribution],
        vetoes: [ModuleVeto]
    ) -> String {
        if let veto = vetoes.first {
            return "\(veto.module.uppercased()) cekincesi var: \(cleanText(veto.reason, fallback: "Veto nedeni belirsiz."))"
        }
        if contributors.count < 3 {
            return "Tum modullerden yeterli katilim yok; bu asamada senaryo erken olabilir."
        }
        if confidence < 0.5 {
            return "Guven duzeyi dusuk; yeni veri geldikce seviye degisebilir."
        }
        return "Piyasa kosullari hizli degisebilir; senaryoyu duzenli yeniden degerlendirin."
    }

    private static func invalidationText(
        action: ArgusAction,
        confidence: Double,
        vetoes: [ModuleVeto]
    ) -> String {
        if let veto = vetoes.first {
            return "Gecersizlik kosulu: \(cleanText(veto.reason, fallback: "\(veto.module) cekincesi devam ediyor."))"
        }

        switch action {
        case .aggressiveBuy, .accumulate:
            let threshold = max(25, Int(confidence * 100) - 20)
            return "Guven %\(threshold) altina inerse olumlu senaryo zayiflar."
        case .neutral:
            return "Yeni veri olmadan notr senaryo teyitli sayilmaz."
        case .trim, .liquidate:
            let threshold = min(80, Int(confidence * 100) + 15)
            return "Guven %\(threshold) uzerine toparlanirsa temkinli senaryo zayiflar."
        }
    }

    private static func learningNote(contributors: [ModuleContribution]) -> String {
        let topModules = contributors
            .sorted { $0.confidence > $1.confidence }
            .prefix(2)
            .map { $0.module.uppercased() }

        if topModules.isEmpty {
            return "Once veri kalitesini artirip moduller arasi tutarliligi kontrol edin."
        }

        let joined = topModules.joined(separator: " + ")
        return "Bu asamada \(joined) gerekcelerini kendi planin ve risk sinirinla karsilastir."
    }

    private static func cleanText(_ text: String, fallback: String) -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
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
        case .athena: return "AthenaIcon"
        case .demeter: return "DemeterIcon"
        case .chiron: return "ChironIcon"
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
        case .faktor: return "AthenaIcon"              // Faktor = Athena
        case .sektor: return "DemeterIcon"             // Sektor = Demeter
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
        case .rejim: return SanctumTheme.aetherColor
        // Eski modüller
        case .bilanco: return SanctumTheme.atlasColor
        case .grafik: return SanctumTheme.orionColor
        case .sirkiye: return SanctumTheme.aetherColor
        case .kulis: return SanctumTheme.hermesColor
        case .faktor: return SanctumTheme.athenaColor
        case .vektor: return SanctumTheme.hologramBlue
        case .sektor: return SanctumTheme.demeterColor
        case .oracle: return SanctumTheme.aetherColor
        case .moneyflow: return SanctumTheme.auroraGreen
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
