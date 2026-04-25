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
    private let baseURL = "https://www.kap.org.tr/tr/api"
    private let marketLookbackDays = 14
    private let maxDisclosuresPerSymbol = 40
    
    // Cache
    private var cachedNews: [String: [KAPNews]] = [:]
    private var lastFetchTime: [String: Date] = [:]
    private var cachedMainFeed: [KAPMainItem] = []
    private var mainFeedLastFetch: Date?
    private var cachedMarketFeed: [KAPNews] = []
    private var marketFeedLastFetch: Date?
    private let cacheValiditySeconds: TimeInterval = 900 // 15 dakika (Haberler hizli degisebilir)
    
    // MARK: - Public API
    
    /// Belirli bir hisse icin KAP bildirimlerini getir
    func getDisclosures(for symbol: String) async -> [KAPNews] {
        let cleanSymbol = normalizeSymbol(symbol)
        
        // Cache kontrol
        if let cached = cachedNews[cleanSymbol],
           let lastTime = lastFetchTime[cleanSymbol],
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        let mainFeed = await fetchMainFeed()
        let filtered = filterDisclosures(mainFeed, for: cleanSymbol)

        cachedNews[cleanSymbol] = filtered
        lastFetchTime[cleanSymbol] = Date()
        return filtered
    }
    
    /// Son 24 saatteki onemli bildirimleri getir (Piyasa geneli)
    func getMarketDisclosures() async -> [KAPNews] {
        if let lastTime = marketFeedLastFetch,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cachedMarketFeed
        }

        do {
            let url = URL(string: "\(baseURL)/disclosure/list/light")!
            let data = try await request(url: url)
            let items = try JSONDecoder().decode([KAPLightItem].self, from: data)
            let mapped = items.prefix(120).map { item in
                KAPNews(
                    id: String(item.disclosureIndex),
                    title: item.subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: "\(item.title.trimmingCharacters(in: .whitespacesAndNewlines)) - \(item.summary.trimmingCharacters(in: .whitespacesAndNewlines))",
                    date: parseDate(item.publishDate),
                    relatedStocks: [],
                    type: mapNotificationType(disclosureClass: nil, disclosureType: nil, title: item.subject, summary: item.summary),
                    url: "https://www.kap.org.tr/tr/Bildirim/\(item.disclosureIndex)"
                )
            }

            cachedMarketFeed = mapped
            marketFeedLastFetch = Date()
            return mapped
        } catch {
            print("⚠️ KAP: Market disclosure cekimi basarisiz - \(error.localizedDescription)")
            return cachedMarketFeed
        }
    }
    
    // MARK: - Core Fetch
    
    private func fetchMainFeed() async -> [KAPMainItem] {
        if let lastTime = mainFeedLastFetch,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cachedMainFeed
        }

        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let start = calendar.date(byAdding: .day, value: -marketLookbackDays, to: today) ?? today

        let payload = KAPMainRequest(
            fromDate: formatDateForKAP(start),
            toDate: formatDateForKAP(today),
            fundTypes: ["BYF", "GMF", "GSF", "PFF"],
            memberTypes: ["IGS", "DDK"]
        )

        do {
            let url = URL(string: "\(baseURL)/disclosure/list/main")!
            let body = try JSONEncoder().encode(payload)
            let data = try await request(url: url, method: "POST", body: body, contentType: "application/json")
            let items = try JSONDecoder().decode([KAPMainItem].self, from: data)
            cachedMainFeed = items
            mainFeedLastFetch = Date()
            return items
        } catch {
            print("⚠️ KAP: Main disclosure cekimi basarisiz - \(error.localizedDescription)")
            return cachedMainFeed
        }
    }

    private func filterDisclosures(_ items: [KAPMainItem], for symbol: String) -> [KAPNews] {
        let normalized = normalizeSymbol(symbol)

        let news = items.compactMap { item -> KAPNews? in
            guard let basic = item.disclosureBasic else { return nil }
            guard matchesDisclosure(basic, symbol: normalized) else { return nil }
            guard let disclosureIndex = basic.disclosureIndex else { return nil }

            let related = Array(Set(parseStockTokens(basic.stockCode) + parseStockTokens(basic.relatedStocks))).sorted()
            let title = (basic.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = (basic.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = title.isEmpty ? "KAP Bildirimi" : title
            let finalSummary = summary.isEmpty ? finalTitle : summary

            return KAPNews(
                id: String(disclosureIndex),
                title: finalTitle,
                summary: finalSummary,
                date: parseDate(basic.publishDate),
                relatedStocks: related,
                type: mapNotificationType(
                    disclosureClass: basic.disclosureClass,
                    disclosureType: basic.disclosureType,
                    title: basic.title,
                    summary: basic.summary
                ),
                url: "https://www.kap.org.tr/tr/Bildirim/\(disclosureIndex)"
            )
        }

        return news
            .sorted { $0.date > $1.date }
            .prefix(maxDisclosuresPerSymbol)
            .map { $0 }
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

    private func request(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func normalizeSymbol(_ symbol: String) -> String {
        symbol
            .uppercased()
            .replacingOccurrences(of: ".IS", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseStockTokens(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw
            .uppercased()
            .replacingOccurrences(of: ".IS", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && $0.count <= 6 }
    }

    private func matchesDisclosure(_ basic: KAPDisclosureBasic, symbol: String) -> Bool {
        let tokens = Set(parseStockTokens(basic.stockCode) + parseStockTokens(basic.relatedStocks))
        if tokens.contains(symbol) {
            return true
        }

        let title = (basic.title ?? "").uppercased()
        let summary = (basic.summary ?? "").uppercased()
        return title.contains(symbol) || summary.contains(symbol)
    }

    private func mapNotificationType(
        disclosureClass: String?,
        disclosureType: String?,
        title: String?,
        summary: String?
    ) -> KAPNews.NotificationType {
        let cls = (disclosureClass ?? "").uppercased()
        let typ = (disclosureType ?? "").uppercased()
        let text = "\(title ?? "") \(summary ?? "")".uppercased()

        if cls == "FR" || typ == "FR" || text.contains("FINANSAL RAPOR") || text.contains("BILANCO") {
            return .financial
        }
        if text.contains("KAR PAYI") || text.contains("TEMETTU") {
            return .dividend
        }
        if typ == "CA" || text.contains("SERMAYE") || text.contains("BEDELLI") || text.contains("BEDELSIZ") {
            return .capital
        }
        if cls == "ODA" || typ == "ODA" || text.contains("OZEL DURUM") {
            return .material
        }
        return .general
    }

    private func parseDate(_ raw: String?) -> Date {
        guard let raw else { return Date() }
        let formatters: [DateFormatter] = [
            makeDateFormatter("dd.MM.yyyy HH:mm:ss"),
            makeDateFormatter("dd.MM.yyyy"),
            makeDateFormatter("yyyy-MM-dd")
        ]
        for formatter in formatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return Date()
    }

    private func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = format
        return formatter
    }

    private func formatDateForKAP(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    // MARK: - DTOs

    private struct KAPMainRequest: Codable {
        let fromDate: String
        let toDate: String
        let fundTypes: [String]
        let memberTypes: [String]
    }

    private struct KAPMainItem: Codable {
        let disclosureBasic: KAPDisclosureBasic?
    }

    private struct KAPDisclosureBasic: Codable {
        let disclosureIndex: Int?
        let disclosureClass: String?
        let disclosureType: String?
        let stockCode: String?
        let relatedStocks: String?
        let title: String?
        let summary: String?
        let publishDate: String?
    }

    private struct KAPLightItem: Codable {
        let disclosureIndex: Int
        let publishDate: String
        let subject: String
        let summary: String
        let title: String
    }
}
