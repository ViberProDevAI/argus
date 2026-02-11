import Foundation

// MARK: - BIST Sector Registry
/// Merkezi sektör yönetimi - duplikasyon önleme
/// Tüm sektör mapping'leri tek kaynaktan

actor BistSectorRegistry {
    static let shared = BistSectorRegistry()

    private init() {}

    // MARK: - Sektör Sembolleri (Static - Sync erişim için)

    /// Bankacılık Sektörü
    static let banks = ["AKBNK", "GARAN", "ISCTR", "YKBNK", "HALKB", "VAKBN", "TSKB"]

    /// Sınai/Sanayi Sektörü
    static let industrials = ["EREGL", "KRDMD", "TOASO", "FROTO", "TUPRS", "PETKM"]

    /// Holding Şirketleri
    static let holdings = ["SAHOL", "KCHOL", "DOHOL", "KOZAL", "TAVHL"]

    /// Teknoloji/Bilişim Sektörü
    static let tech = ["ASELS", "LOGO", "NETAS"]

    /// GYO (Gayrimenkul)
    static let realEstate = ["EKGYO", "ISGYO", "HLGYO"]

    /// Ulaştırma
    static let transportation = ["THYAO", "PGSUS"]

    /// Enerji
    static let energy = ["AYGAZ", "AKSEN", "ODAS"]

    /// Perakende
    static let retail = ["BIMAS", "MGROS", "SOKM", "BIZIM"]

    /// Telekomünikasyon
    static let telecom = ["TCELL", "TTKOM"]
    
    // MARK: - Sektör Mapping
    
    /// Sembol için sektör kodunu döner (nonisolated - sync erişim)
    nonisolated static func sectorCode(for symbol: String) -> String? {
        let cleanSymbol = symbol.uppercased().replacingOccurrences(of: ".IS", with: "")

        if banks.contains(cleanSymbol) { return "XBANK" }
        if industrials.contains(cleanSymbol) { return "XUSIN" }
        if holdings.contains(cleanSymbol) { return "XHOLD" }
        if tech.contains(cleanSymbol) { return "XBLSM" }
        if realEstate.contains(cleanSymbol) { return "XGMYO" }
        if transportation.contains(cleanSymbol) { return "XULAS" }
        if energy.contains(cleanSymbol) { return "XELKT" }
        if retail.contains(cleanSymbol) { return "XGIDA" }
        if telecom.contains(cleanSymbol) { return "XILTM" }

        return nil
    }

    /// Sembol için sektör adını döner (nonisolated - sync erişim)
    nonisolated static func sectorName(for symbol: String) -> String? {
        let cleanSymbol = symbol.uppercased().replacingOccurrences(of: ".IS", with: "")

        if banks.contains(cleanSymbol) { return "Bankacılık" }
        if industrials.contains(cleanSymbol) { return "Sınai" }
        if holdings.contains(cleanSymbol) { return "Holding" }
        if tech.contains(cleanSymbol) { return "Teknoloji" }
        if realEstate.contains(cleanSymbol) { return "GYO" }
        if transportation.contains(cleanSymbol) { return "Ulaştırma" }
        if energy.contains(cleanSymbol) { return "Enerji" }
        if retail.contains(cleanSymbol) { return "Perakende" }
        if telecom.contains(cleanSymbol) { return "Telekomünikasyon" }

        return nil
    }

    /// Belirli bir sektördeki tüm sembolleri döner (nonisolated - sync erişim)
    nonisolated static func symbols(for sectorCode: String) -> [String] {
        switch sectorCode.uppercased() {
        case "XBANK": return banks
        case "XUSIN": return industrials
        case "XHOLD": return holdings
        case "XBLSM": return tech
        case "XGMYO": return realEstate
        case "XULAS": return transportation
        case "XELKT": return energy
        case "XGIDA": return retail
        case "XILTM": return telecom
        default: return []
        }
    }

    /// Tüm bilinen sembolleri döner
    nonisolated static var allSymbols: [String] {
        banks + industrials + holdings + tech + realEstate +
        transportation + energy + retail + telecom
    }
}

// MARK: - BistSector Enum (Opsiyonel)

enum BistSector: String, CaseIterable, Sendable {
    case bank = "XBANK"
    case industrial = "XUSIN"
    case holding = "XHOLD"
    case tech = "XBLSM"
    case realEstate = "XGMYO"
    case transportation = "XULAS"
    case energy = "XELKT"
    case retail = "XGIDA"
    case telecom = "XILTM"
    case unknown = "UNKNOWN"
    
    var displayName: String {
        switch self {
        case .bank: return "Bankacılık"
        case .industrial: return "Sınai"
        case .holding: return "Holding"
        case .tech: return "Teknoloji"
        case .realEstate: return "GYO"
        case .transportation: return "Ulaştırma"
        case .energy: return "Enerji"
        case .retail: return "Perakende"
        case .telecom: return "Telekomünikasyon"
        case .unknown: return "Bilinmiyor"
        }
    }
    
    var icon: String {
        switch self {
        case .bank: return "building.columns.fill"
        case .industrial: return "gear.circle.fill"
        case .holding: return "briefcase.fill"
        case .tech: return "cpu.fill"
        case .realEstate: return "building.2.fill"
        case .transportation: return "airplane"
        case .energy: return "bolt.fill"
        case .retail: return "cart.fill"
        case .telecom: return "phone.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
