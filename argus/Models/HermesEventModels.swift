import Foundation

// MARK: - Hermes Event Models (V3)

enum HermesEventScope: String, Codable, Sendable {
    case global
    case bist
}

enum HermesEventPolarity: String, Codable, Sendable {
    case positive
    case negative
    case mixed
}

enum HermesEventHorizon: String, Codable, Sendable {
    case intraday = "intraday"
    case shortTerm = "1-3d"
    case multiweek = "multiweek"
}

enum HermesRiskFlag: String, Codable, CaseIterable, Sendable {
    case rumor
    case lowReliability = "low_reliability"
    case pricedIn = "priced_in"
    case regulatoryUncertainty = "regulatory_uncertainty"
}

enum HermesEventType: String, Codable, CaseIterable, Sendable {
    // Global
    case earningsSurprise = "earnings_surprise"
    case guidanceRaise = "guidance_raise"
    case guidanceCut = "guidance_cut"
    case revenueMiss = "revenue_miss"
    case marginPressure = "margin_pressure"
    case buybackAnnouncement = "buyback_announcement"
    case dividendChange = "dividend_change"
    case mergerAcquisition = "m_and_a"
    case regulatoryAction = "regulatory_action"
    case legalRisk = "legal_risk"
    case productLaunch = "product_launch"
    case supplyChainDisruption = "supply_chain_disruption"
    case macroShock = "macro_shock"
    case ratingUpgrade = "rating_upgrade"
    case ratingDowngrade = "rating_downgrade"
    case insiderActivity = "insider_activity"
    case sectorRotation = "sector_rotation"
    case geopoliticalRisk = "geopolitical_risk"
    case fraudAllegation = "fraud_allegation"
    case leadershipChange = "leadership_change"
    // BIST
    case kapDisclosure = "kap_disclosure"
    case bedelliCapitalIncrease = "bedelli_capital_increase"
    case bedelsizBonusIssue = "bedelsiz_bonus_issue"
    case temettuAnnouncement = "temettu_announcement"
    case ihaleKazandi = "ihale_kazandi"
    case ihaleIptal = "ihale_iptal"
    case spkAction = "spk_action"
    case ortaklikAnlasmasi = "ortaklik_anlasmasi"
    case borclanmaIhraci = "borclanma_ihraci"
    case karUyarisi = "kar_uyarisi"
    case kurRiski = "kur_riski"
    case ihracatSiparisi = "ihracat_siparisi"
    case yatirimPlani = "yatirim_plani"
    case tesisAcilisi = "tesis_acilisi"
    case sektorTesvik = "sektor_tesvik"
    case davaOlumsuz = "dava_olumsuz"
    case davaOlumlu = "dava_olumlu"
    case yonetimDegisim = "yonetim_degisim"
    case operasyonelAriza = "operasyonel_ariza"
}

extension HermesEventType {
    var displayTitleTR: String {
        switch self {
        case .earningsSurprise: return "Bilanço Sürprizi"
        case .guidanceRaise: return "Yönlendirme Artışı"
        case .guidanceCut: return "Yönlendirme Düşüşü"
        case .revenueMiss: return "Gelir Beklentisi Kaçırıldı"
        case .marginPressure: return "Marj Baskısı"
        case .buybackAnnouncement: return "Hisse Geri Alımı"
        case .dividendChange: return "Temettü Değişimi"
        case .mergerAcquisition: return "Birleşme/Satın Alma"
        case .regulatoryAction: return "Regülasyon Etkisi"
        case .legalRisk: return "Hukuki Risk"
        case .productLaunch: return "Ürün Lansmanı"
        case .supplyChainDisruption: return "Tedarik Zinciri Sorunu"
        case .macroShock: return "Makro Şok"
        case .ratingUpgrade: return "Not Artışı"
        case .ratingDowngrade: return "Not Düşüşü"
        case .insiderActivity: return "İçeriden İşlem"
        case .sectorRotation: return "Sektör Rotasyonu"
        case .geopoliticalRisk: return "Jeopolitik Risk"
        case .fraudAllegation: return "Usulsüzlük İddiası"
        case .leadershipChange: return "Yönetim Değişimi"
        case .kapDisclosure: return "KAP Bildirimi"
        case .bedelliCapitalIncrease: return "Bedelli Sermaye Artırımı"
        case .bedelsizBonusIssue: return "Bedelsiz Sermaye Artırımı"
        case .temettuAnnouncement: return "Temettü Duyurusu"
        case .ihaleKazandi: return "İhale Kazanımı"
        case .ihaleIptal: return "İhale İptali"
        case .spkAction: return "SPK İşlemi"
        case .ortaklikAnlasmasi: return "Ortaklık Anlaşması"
        case .borclanmaIhraci: return "Borçlanma İhracı"
        case .karUyarisi: return "Kâr Uyarısı"
        case .kurRiski: return "Kur Riski"
        case .ihracatSiparisi: return "İhracat Siparişi"
        case .yatirimPlani: return "Yatırım Planı"
        case .tesisAcilisi: return "Tesis Açılışı"
        case .sektorTesvik: return "Sektör Teşviki"
        case .davaOlumsuz: return "Dava (Olumsuz)"
        case .davaOlumlu: return "Dava (Olumlu)"
        case .yonetimDegisim: return "Yönetim Değişimi"
        case .operasyonelAriza: return "Operasyonel Arıza"
        }
    }
}

struct HermesEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let scope: HermesEventScope
    let symbol: String
    let articleId: String
    let headline: String
    let eventType: HermesEventType
    let polarity: HermesEventPolarity
    let severity: Double
    let confidence: Double
    let sentimentLabel: NewsSentiment?
    let horizonHint: HermesEventHorizon
    let rationaleShort: String
    let evidenceQuotes: [String]
    let riskFlags: [HermesRiskFlag]
    let sourceName: String
    let sourceReliability: Double // 1-100
    let publishedAt: Date
    let createdAt: Date
    let ingestDelayMinutes: Double
    let finalScore: Double
    let articleUrl: String?
    
    init(
        id: UUID = UUID(),
        scope: HermesEventScope,
        symbol: String,
        articleId: String,
        headline: String,
        eventType: HermesEventType,
        polarity: HermesEventPolarity,
        severity: Double,
        confidence: Double,
        sentimentLabel: NewsSentiment? = nil,
        horizonHint: HermesEventHorizon,
        rationaleShort: String,
        evidenceQuotes: [String],
        riskFlags: [HermesRiskFlag],
        sourceName: String,
        sourceReliability: Double,
        publishedAt: Date,
        createdAt: Date = Date(),
        ingestDelayMinutes: Double = 0.0,
        finalScore: Double,
        articleUrl: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.symbol = symbol
        self.articleId = articleId
        self.headline = headline
        self.eventType = eventType
        self.polarity = polarity
        self.severity = severity
        self.confidence = confidence
        self.sentimentLabel = sentimentLabel
        self.horizonHint = horizonHint
        self.rationaleShort = rationaleShort
        self.evidenceQuotes = evidenceQuotes
        self.riskFlags = riskFlags
        self.sourceName = sourceName
        self.sourceReliability = sourceReliability
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.ingestDelayMinutes = ingestDelayMinutes
        self.finalScore = finalScore
        self.articleUrl = articleUrl
    }
}
