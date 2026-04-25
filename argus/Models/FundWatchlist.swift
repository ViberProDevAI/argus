import Foundation

// MARK: - Fund Categories
enum FundCategory: String, CaseIterable, Identifiable {
    case hisse = "Hisse Senedi"
    case paraPiyasasi = "Para Piyasası"
    case kiymetliMaden = "Kıymetli Madenler"
    case borclanma = "Borçlanma Araçları"
    case degisken = "Değişken"
    case serbest = "Serbest"
    case fonSepeti = "Fon Sepeti"
    case katilim = "Katılım"
    case karma = "Karma"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .hisse: return "chart.line.uptrend.xyaxis"
        case .paraPiyasasi: return "banknote"
        case .kiymetliMaden: return "bitcoinsign.circle"
        case .borclanma: return "doc.text"
        case .degisken: return "arrow.triangle.swap"
        case .serbest: return "flame"
        case .fonSepeti: return "basket"
        case .katilim: return "moon.stars"
        case .karma: return "square.grid.2x2"
        }
    }
    
    var color: String {
        switch self {
        case .hisse: return "blue"
        case .paraPiyasasi: return "green"
        case .kiymetliMaden: return "yellow"
        case .borclanma: return "purple"
        case .degisken: return "orange"
        case .serbest: return "red"
        case .fonSepeti: return "teal"
        case .katilim: return "indigo"
        case .karma: return "gray"
        }
    }
}

// MARK: - Fund Founder (Portfolio Company)
enum FundFounder: String, CaseIterable {
    // Major Banks
    case isPorfoy = "İş Portföy"
    case akPortfoy = "Ak Portföy"
    case yapiKredi = "Yapı Kredi Portföy"
    case garanti = "Garanti Portföy"
    case ziraat = "Ziraat Portföy"
    case teb = "TEB Portföy"
    case deniz = "Deniz Portföy"
    case qnb = "QNB Finans Portföy"
    case halk = "Halk Portföy"
    case vakif = "Vakıf Portföy"
    case hsbc = "HSBC Portföy"
    
    // Boutique Companies
    case tera = "Tera Portföy"
    case istanbulPortfoy = "İstanbul Portföy"
    case pardus = "Pardus Portföy"
    case allbatross = "Allbatross Portföy"
    case atlas = "Atlas Portföy"
    case pusula = "Pusula Portföy"
    case one = "One Portföy"
    case hedef = "Hedef Portföy"
    case unlu = "Ünlü Portföy"
    case rePie = "Re-Pie Portföy"
    case ata = "Ata Portföy"
    case mt = "MT Portföy"
    case fonmap = "Fonmap Portföy"
    case bv = "BV Portföy"
    case rota = "Rota Portföy"
    case osmanlı = "Osmanlı Portföy"
    case kuveytTurk = "Kuveyt Türk Portföy"
    case albaraka = "Albaraka Portföy"
    case other = "Diğer"
}

// MARK: - Fund List Item (Lightweight model for list display)
struct FundListItem: Identifiable, Hashable {
    let id: String // Fund code (e.g., "TI2", "IPB")
    let code: String
    let name: String
    let shortName: String
    let category: FundCategory
    let founder: FundFounder
    
    init(code: String, name: String, shortName: String? = nil, category: FundCategory, founder: FundFounder) {
        self.id = code
        self.code = code
        self.name = name
        self.shortName = shortName ?? name
        self.category = category
        self.founder = founder
    }
}

// MARK: - Fund Watchlist (Static curated list from TEFAS research)
struct FundWatchlist {
    
    /// All funds in the watchlist (~45 funds across 9 categories)
    static let allFunds: [FundListItem] = {
        var funds: [FundListItem] = []
        funds.append(contentsOf: hisseFonlari)
        funds.append(contentsOf: paraPiyasasiFonlari)
        funds.append(contentsOf: kiymetliMadenFonlari)
        funds.append(contentsOf: borclanmaFonlari)
        funds.append(contentsOf: degiskenFonlar)
        funds.append(contentsOf: serbestFonlar)
        funds.append(contentsOf: fonSepetiFonlari)
        funds.append(contentsOf: katilimFonlari)
        funds.append(contentsOf: karmaFonlar)
        return funds
    }()
    
    // MARK: - Hisse Senedi Fonları
    static let hisseFonlari: [FundListItem] = [
        FundListItem(code: "BIH", name: "Pardus Portföy Birinci Hisse Senedi Fonu", shortName: "Pardus Hisse", category: .hisse, founder: .pardus),
        FundListItem(code: "BDS", name: "Pardus Portföy BIST 30 Dışı Hisse Fonu", shortName: "Pardus BIST30 Dışı", category: .hisse, founder: .pardus),
        FundListItem(code: "AOY", name: "Ak Portföy Alternatif Enerji Hisse Fonu", shortName: "Ak Alt. Enerji", category: .hisse, founder: .akPortfoy),
        FundListItem(code: "AFT", name: "Ak Portföy Yeni Teknolojiler Hisse Fonu", shortName: "Ak Yeni Teknoloji", category: .hisse, founder: .akPortfoy),
        FundListItem(code: "MTH", name: "MT Portföy Birinci Hisse Senedi Fonu", shortName: "MT Hisse", category: .hisse, founder: .mt),
        FundListItem(code: "TI2", name: "İş Portföy Hisse Senedi Fonu", shortName: "İş Hisse", category: .hisse, founder: .isPorfoy),
    ]
    
    // MARK: - Para Piyasası Fonları
    static let paraPiyasasiFonlari: [FundListItem] = [
        FundListItem(code: "TP2", name: "Tera Portföy Para Piyasası Fonu", shortName: "Tera PP", category: .paraPiyasasi, founder: .tera),
        FundListItem(code: "PRY", name: "Pusula Portföy Para Piyasası Fonu", shortName: "Pusula PP", category: .paraPiyasasi, founder: .pusula),
        FundListItem(code: "GO6", name: "One Portföy Para Piyasası Fonu", shortName: "One PP", category: .paraPiyasasi, founder: .one),
        FundListItem(code: "HVT", name: "Allbatross Portföy Birinci Para Piyasası Fonu", shortName: "Allbatross PP", category: .paraPiyasasi, founder: .allbatross),
        FundListItem(code: "PPT", name: "Atlas Portföy Para Piyasası Fonu", shortName: "Atlas PP", category: .paraPiyasasi, founder: .atlas),
        FundListItem(code: "IPP", name: "İş Portföy Para Piyasası Fonu", shortName: "İş PP", category: .paraPiyasasi, founder: .isPorfoy),
    ]
    
    // MARK: - Kıymetli Maden Fonları (Altın/Gümüş)
    static let kiymetliMadenFonlari: [FundListItem] = [
        FundListItem(code: "HBF", name: "HSBC Portföy Altın Fonu", shortName: "HSBC Altın", category: .kiymetliMaden, founder: .hsbc),
        FundListItem(code: "UP1", name: "Ünlü Portföy Altın Fonu", shortName: "Ünlü Altın", category: .kiymetliMaden, founder: .unlu),
        FundListItem(code: "PAF", name: "Pardus Portföy Altın Fonu", shortName: "Pardus Altın", category: .kiymetliMaden, founder: .pardus),
        FundListItem(code: "OJK", name: "QNB Finans Portföy Altın Fonu", shortName: "QNB Altın", category: .kiymetliMaden, founder: .qnb),
        FundListItem(code: "DBA", name: "Deniz Portföy Altın Fonu", shortName: "Deniz Altın", category: .kiymetliMaden, founder: .deniz),
        FundListItem(code: "GAF", name: "Garanti Portföy Altın Fonu", shortName: "Garanti Altın", category: .kiymetliMaden, founder: .garanti),
    ]
    
    // MARK: - Borçlanma Araçları Fonları
    static let borclanmaFonlari: [FundListItem] = [
        FundListItem(code: "BBP", name: "Allbatross Portföy Birinci Borçlanma Fonu", shortName: "Allbatross Borç", category: .borclanma, founder: .allbatross),
        FundListItem(code: "BBF", name: "Pardus Portföy Birinci Borçlanma Fonu", shortName: "Pardus Borç", category: .borclanma, founder: .pardus),
        FundListItem(code: "HVK", name: "Hedef Portföy Birinci Borçlanma Fonu", shortName: "Hedef Borç", category: .borclanma, founder: .hedef),
        FundListItem(code: "OSD", name: "Osmanlı Portföy ÖSBA Fonu", shortName: "Osmanlı ÖSBA", category: .borclanma, founder: .osmanlı),
        FundListItem(code: "IST", name: "İstanbul Portföy Kısa Vadeli Borçlanma Fonu", shortName: "İstanbul KV", category: .borclanma, founder: .istanbulPortfoy),
    ]
    
    // MARK: - Değişken Fonlar
    static let degiskenFonlar: [FundListItem] = [
        FundListItem(code: "JET", name: "Ata Portföy Havacılık ve Savunma Değişken Fonu", shortName: "Ata Havacılık", category: .degisken, founder: .ata),
        FundListItem(code: "RIK", name: "Re-Pie Portföy İkinci Değişken Fon", shortName: "Re-Pie Değişken", category: .degisken, founder: .rePie),
        FundListItem(code: "URA", name: "Ata Portföy Enerji Değişken Fonu", shortName: "Ata Enerji", category: .degisken, founder: .ata),
        FundListItem(code: "FDG", name: "Fonmap Portföy Birinci Değişken Fon", shortName: "Fonmap Değişken", category: .degisken, founder: .fonmap),
        FundListItem(code: "RUT", name: "BV Portföy Robotik ve Uzay Teknolojileri Fonu", shortName: "BV Robotik", category: .degisken, founder: .bv),
    ]
    
    // MARK: - Serbest Fonlar
    static let serbestFonlar: [FundListItem] = [
        FundListItem(code: "TLY", name: "Tera Portföy Birinci Serbest Fon", shortName: "Tera Serbest", category: .serbest, founder: .tera),
        FundListItem(code: "THV", name: "Ata Portföy Barbaros Serbest Fon", shortName: "Ata Barbaros", category: .serbest, founder: .ata),
        FundListItem(code: "DFI", name: "Atlas Portföy Serbest Fon", shortName: "Atlas Serbest", category: .serbest, founder: .atlas),
        FundListItem(code: "IOG", name: "İş Portföy Gümüş Serbest Fon", shortName: "İş Gümüş", category: .serbest, founder: .isPorfoy),
        FundListItem(code: "RIH", name: "Re-Pie Portföy İkinci Serbest Fon", shortName: "Re-Pie Serbest", category: .serbest, founder: .rePie),
    ]
    
    // MARK: - Fon Sepeti Fonları
    static let fonSepetiFonlari: [FundListItem] = [
        FundListItem(code: "GMC", name: "TEB Portföy Gümüş Fon Sepeti", shortName: "TEB Gümüş", category: .fonSepeti, founder: .teb),
        FundListItem(code: "YZG", name: "Yapı Kredi Portföy Gümüş Fon Sepeti", shortName: "YKP Gümüş", category: .fonSepeti, founder: .yapiKredi),
        FundListItem(code: "DMG", name: "Deniz Portföy Gümüş Fon Sepeti", shortName: "Deniz Gümüş", category: .fonSepeti, founder: .deniz),
        FundListItem(code: "GUM", name: "Ak Portföy Gümüş Fon Sepeti", shortName: "Ak Gümüş", category: .fonSepeti, founder: .akPortfoy),
        FundListItem(code: "PIL", name: "Rota Portföy Pil Teknolojileri Fon Sepeti", shortName: "Rota Pil", category: .fonSepeti, founder: .rota),
    ]
    
    // MARK: - Katılım Fonları (Faizsiz)
    static let katilimFonlari: [FundListItem] = [
        FundListItem(code: "KUT", name: "Kuveyt Türk Kıymetli Madenler Katılım Fonu", shortName: "Kuveyt Altın", category: .katilim, founder: .kuveytTurk),
        FundListItem(code: "HAM", name: "Hedef Portföy Altın Katılım Fonu", shortName: "Hedef Altın", category: .katilim, founder: .hedef),
        FundListItem(code: "RBA", name: "Albaraka Bereket Vakfı Altın Katılım Fonu", shortName: "Albaraka Altın", category: .katilim, founder: .albaraka),
        FundListItem(code: "KZL", name: "Kuveyt Türk Altın Katılım Fonu", shortName: "Kuveyt Türk Altın", category: .katilim, founder: .kuveytTurk),
    ]
    
    // MARK: - Karma Fonlar
    static let karmaFonlar: [FundListItem] = [
        FundListItem(code: "IKP", name: "İş Portföy Yenilenebilir Enerji Karma Fonu", shortName: "İş Yenilenebilir", category: .karma, founder: .isPorfoy),
        FundListItem(code: "IPJ", name: "İş Portföy Elektrikli Araçlar Karma Fonu", shortName: "İş Elektrikli", category: .karma, founder: .isPorfoy),
        FundListItem(code: "IJP", name: "İş Portföy Blockchain Karma Fonu", shortName: "İş Blockchain", category: .karma, founder: .isPorfoy),
    ]
    
    // MARK: - Helper Methods
    
    /// Get funds by category
    static func funds(for category: FundCategory) -> [FundListItem] {
        allFunds.filter { $0.category == category }
    }
    
    /// Get funds by founder
    static func funds(by founder: FundFounder) -> [FundListItem] {
        allFunds.filter { $0.founder == founder }
    }
    
    /// Get all fund codes (for batch API calls)
    static var allCodes: [String] {
        allFunds.map { $0.code }
    }
}
