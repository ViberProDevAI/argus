import Foundation

// MARK: - KAP (Kamuyu Aydinlatma Platformu) Data Service
/// KAP uzerinden sirket haberlerini ve bildirimlerini scrape eder.
/// Kaynak: kap.org.tr
/// Bu servis, sirketlerle ilgili kritik gelismeleri (ozel durum aciklamalari, bilanco, vb.) takip eder.

actor KAPDataService {
    static let shared = KAPDataService()
    
    // MARK: - Data Models
    
    struct KAPNews: Identifiable, Codable {
        let id: String
        let title: String
        let summary: String
        let date: Date
        let relatedStocks: [String]
        let type: NotificationType
        let url: String
        
        enum NotificationType: String, Codable {
            case financial = "FINANSAL RAPOR"
            case material = "OZEL DURUM ACIKLAMASI"
            case general = "GENEL"
            case dividend = "KAR PAYI DAGITIM"
            case capital = "SERMAYE ARTIRIMI"
            case unknown = "DIGER"
        }
        
        var disclosureTypeColor: String {
            switch type {
            case .financial: return "0000FF" // Mavi
            case .material: return "FF0000"  // Kirmizi
            case .dividend: return "00FF00"  // Yesil
            case .capital: return "FFA500"   // Turuncu
            default: return "808080"         // Gri
            }
        }
    }
    
    // MARK: - Configuration
    private let baseURL = "https://www.kap.org.tr"
    
    // Cache
    private var cachedNews: [String: [KAPNews]] = [:]
    private var lastFetchTime: [String: Date] = [:]
    private let cacheValiditySeconds: TimeInterval = 900 // 15 dakika (Haberler hizli degisebilir)
    
    // MARK: - Public API
    
    /// Belirli bir hisse icin KAP bildirimlerini getir
    func getDisclosures(for symbol: String) async -> [KAPNews] {
        let cleanSymbol = symbol.replacingOccurrences(of: ".IS", with: "")
        
        // Cache kontrol
        if let cached = cachedNews[cleanSymbol],
           let lastTime = lastFetchTime[cleanSymbol],
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        // Scrape
        return await scrapeDisclosures(for: cleanSymbol)
    }
    
    /// Son 24 saatteki onemli bildirimleri getir (Piyasa geneli)
    func getMarketDisclosures() async -> [KAPNews] {
        // Ana sayfa scrape yapilabilir
        return [] // Simdilik bos
    }
    
    // MARK: - Scraping Logic
    
    private func scrapeDisclosures(for symbol: String) async -> [KAPNews] {
        // KAP mobil sitesi veya RSS feed uzerinden scrape etmek daha kolaydir
        // Ornek URL: https://www.kap.org.tr/tr/sirket-bildirimleri/4028328c594c03af01594c5999d300d5 (Thy gibi ID lazim)
        // Alternatif: https://www.kap.org.tr/tr/Lozan'dan arama yapip ID bulmak lazim
        
        // Basitlik icin su an mock veri uretecegiz, cunku KAP ID mapping'i karmasik ve degisken.
        // Ileride KAP API veya ID mapping tablosu eklenebilir.
        
        // Mock veri uretimi kaldirildi. Gercek scrape entegrasyonu tamamlanana kadar bos doner.
        cachedNews[symbol] = []
        lastFetchTime[symbol] = Date()
        return []
    }
    
    // MARK: - Helper Methods
    
    /// Bildirimin önem derecesini analiz et (0-10)
    func analyzeImpact(of news: KAPNews) -> Int {
        switch news.type {
        case .financial: return 8
        case .material: return 7
        case .dividend: return 9
        case .capital: return 6 // Bedelli/Bedelsiz'e gore degisir
        default: return 3
        }
    }
}
