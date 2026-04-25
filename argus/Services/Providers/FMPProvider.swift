import Foundation

class FMPProvider {
    static let shared = FMPProvider()
    
    private let hardcodedKey = Secrets.fmpKey
    private let baseURL = "https://financialmodelingprep.com/api/v3"
    
    private init() {}
    
    // MARK: - Fetch Methods
    func fetchProfile(symbol: String) async throws -> FMPProfile? {
        let urlString = "\(baseURL)/profile/\(symbol)?apikey=\(hardcodedKey)"
        guard let url = URL(string: urlString) else { return nil }

        // Y2: 15s timeout (fundamentals endpoint; default 60s UI'yi donduruyordu).
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)

        // Y2: HTTP status explicit guard — FMP rate-limit 429 döndüğünde body boş bir
        // array ("[]") gelip decode başarılı oluyordu; silent empty sonuç UI'da "bilgi yok"
        // gibi görünüyor ama aslında erişim reddedilmişti.
        try Self.requireOK(response, context: "FMP profile \(symbol)")

        // FMP returns an array of profiles
        let profiles = try JSONDecoder().decode([FMPProfile].self, from: data)
        return profiles.first
    }

    func fetchQuote(symbol: String) async throws -> FMPQuote? {
        let urlString = "\(baseURL)/quote/\(symbol)?apikey=\(hardcodedKey)"
        guard let url = URL(string: urlString) else { return nil }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)

        try Self.requireOK(response, context: "FMP quote \(symbol)")

        let quotes = try JSONDecoder().decode([FMPQuote].self, from: data)
        return quotes.first
    }

    /// Y2: yalın HTTP 200 kontrolü; 4xx/5xx'de boş/kırık body'nin sessiz decode edilip
    /// "veri yok" gibi yorumlanmasını engeller. HeimdallNetwork'teki retry/jitter katmanının
    /// burada olmadığını unutma — üst katmandaki caller hata yönetimini kendi yapar.
    private static func requireOK(_ response: URLResponse, context: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "\(context): non-HTTP response"])
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "\(context): HTTP \(http.statusCode)"
            ])
        }
    }
}

// Basic Structures for FMP
struct FMPProfile: Codable {
    let symbol: String
    let price: Double?
    let beta: Double?
    let volAvg: Int?
    let mktCap: Double?
    let lastDiv: Double?
    let range: String?
    let changes: Double?
    let companyName: String?
    let currency: String?
    let isin: String?
    let cusip: String?
    let exchange: String?
    let exchangeShortName: String?
    let industry: String?
    let website: String?
    let description: String?
    let ceo: String?
    let sector: String?
    let country: String?
    let fullTimeEmployees: String?
    let phone: String?
    let address: String?
    let city: String?
    let state: String?
    let zip: String?
    let dcfDiff: Double?
    let dcf: Double?
    let image: String?
    let ipoDate: String?
    let defaultImage: Bool?
    let isEtf: Bool?
    let isActivelyTrading: Bool?
}

struct FMPQuote: Codable {
    let symbol: String
    let name: String?
    let price: Double?
    let changesPercentage: Double?
    let change: Double?
    let dayLow: Double?
    let dayHigh: Double?
    let yearHigh: Double?
    let yearLow: Double?
    let marketCap: Double?
    let priceAvg50: Double?
    let priceAvg200: Double?
    let volume: Int?
    let avgVolume: Int?
    let open: Double?
    let previousClose: Double?
    let eps: Double?
    let pe: Double?
    let earningsAnnouncement: String?
    let sharesOutstanding: Int?
    let timestamp: Int?
}
