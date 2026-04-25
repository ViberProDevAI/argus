
import Foundation

class TefasService {
    static let shared = TefasService()
    
    // FUNDTURKEY.COM.TR - TEFAS alternatif domain (WAF yok!)
    private let baseURL = "https://fundturkey.com.tr"
    private let historyInfoURL = "https://fundturkey.com.tr/api/DB/BindHistoryInfo"
    private let allocationURL = "https://fundturkey.com.tr/api/DB/BindHistoryAllocation"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fonun tarihsel fiyat verilerini getirir
    func fetchHistory(fundCode: String, startDate: Date, endDate: Date = Date()) async throws -> [FundPrice] {
        let params = [
            "fontip": "YAT",
            "fonkod": fundCode.uppercased(),
            "bastarih": formatDate(startDate),
            "bittarih": formatDate(endDate)
        ]
        
        let data = try await postRequest(url: historyInfoURL, params: params)
        return parseHistory(data: data)
    }
    
    /// Fonun varlık dağılımını getirir
    func fetchAllocation(fundCode: String, startDate: Date? = nil) async throws -> [FundAllocation] {
        let end = Date()
        let start = startDate ?? Calendar.current.date(byAdding: .day, value: -7, to: end)!
        
        let params = [
            "fontip": "YAT",
            "fonkod": fundCode.uppercased(),
            "bastarih": formatDate(start),
            "bittarih": formatDate(end)
        ]
        
        let data = try await postRequest(url: allocationURL, params: params)
        return parseAllocation(data: data)
    }
    
    // MARK: - Helper Methods
    
    // Session with cookie storage
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        return URLSession(configuration: config)
    }()
    
    private var hasWarmedUp = false
    
    /// Warm up session by visiting main page first (gets cookies)
    private func warmUpSession() async {
        guard !hasWarmedUp else { return }
        
        // Visit main page to get session cookies
        if let url = URL(string: "\(baseURL)/TarihselVeriler.aspx") {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            
            _ = try? await session.data(for: request)
            hasWarmedUp = true
            print("🔐 FundTurkey: Session warmed up with cookies")
        }
    }
    
    private func postRequest(url: String, params: [String: String]) async throws -> Data {
        // Warm up session first
        await warmUpSession()
        
        guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        
        // Headers for fundturkey.com.tr (simpler - no aggressive WAF)
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://fundturkey.com.tr", forHTTPHeaderField: "Origin")
        request.setValue("https://fundturkey.com.tr/TarihselVeriler.aspx", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        // Parametreleri form-urlencoded yap
        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔍 TEFAS DEBUG: URL=\(url)")
        print("🔍 TEFAS DEBUG: Body=\(bodyString)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("🔍 TEFAS DEBUG: Status=\(httpResponse.statusCode)")
        
        // Debug: Show first part of response
        if let rawStr = String(data: data, encoding: .utf8) {
            print("🔍 TEFAS DEBUG: Response (first 300): \(rawStr.prefix(300))")
        }
        
        // Check for WAF block in response
        if httpResponse.statusCode == 200 {
            if let str = String(data: data, encoding: .utf8), str.contains("Web Application Firewall") {
                print("⚠️ TEFAS: WAF block detected, waiting and retrying...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second wait
                hasWarmedUp = false // Force re-warm
                await warmUpSession()
                throw URLError(.userAuthenticationRequired)
            }
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ TEFAS: HTTP Error \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    private func parseHistory(data: Data) -> [FundPrice] {
        // Debug: Log raw response
        if let rawString = String(data: data, encoding: .utf8) {
            print("📊 TEFAS Raw Response (first 500 chars): \(rawString.prefix(500))")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = json["data"] as? [[String: Any]] else {
            print("❌ TEFAS: Failed to parse JSON structure")
            return []
        }
        
        print("📊 TEFAS: Found \(dataList.count) data items")
        
        var prices: [FundPrice] = []
        
        for item in dataList {
            // TARIH can be Int, Double, or String (milliseconds since epoch)
            var dateMs: TimeInterval?
            if let intDate = item["TARIH"] as? Int {
                dateMs = TimeInterval(intDate)
            } else if let doubleDate = item["TARIH"] as? Double {
                dateMs = doubleDate
            } else if let stringDate = item["TARIH"] as? String, let parsed = Double(stringDate) {
                dateMs = parsed
            }
            
            // FIYAT can be Double or String
            var price: Double?
            if let doublePrice = item["FIYAT"] as? Double {
                price = doublePrice
            } else if let stringPrice = item["FIYAT"] as? String {
                price = Double(stringPrice.replacingOccurrences(of: ",", with: "."))
            }
            
            if let dateMs = dateMs, let price = price, price > 0 {
                let date = Date(timeIntervalSince1970: dateMs / 1000)
                
                // KISISAYISI can be Int or Double
                var investors: Int?
                if let intVal = item["KISISAYISI"] as? Int {
                    investors = intVal
                } else if let doubleVal = item["KISISAYISI"] as? Double {
                    investors = Int(doubleVal)
                }
                
                let size = item["PORTFOYBUYUKLUK"] as? Double
                
                prices.append(FundPrice(date: date, price: price, fundSize: size, investors: investors))
            } else {
                print("⚠️ TEFAS: Skipping item - dateMs: \(String(describing: dateMs)), price: \(String(describing: price))")
            }
        }
        
        print("✅ TEFAS: Parsed \(prices.count) valid prices")
        return prices.sorted { $0.date < $1.date }
    }
    
    private func parseAllocation(data: Data) -> [FundAllocation] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = json["data"] as? [[String: Any]] else {
            return []
        }
        
        var allocations: [FundAllocation] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy" // TARIH string gelebilir mi kontrol et
        
        // TEFAS Allocationda tarih timestamp (Long) olarak geliyor
        
        for item in dataList {
            if let dateMs = item["TARIH"] as? TimeInterval,
               let type = item["TURIBD"] as? String, // Örn: "HS"
               let name = item["TURACIKLAMA"] as? String, // Örn: "Hisse Senedi"
               let weight = item["ORAN"] as? Double {
                
                let date = Date(timeIntervalSince1970: dateMs / 1000)
                allocations.append(FundAllocation(assetType: type, assetName: name, weight: weight, date: date))
            }
        }
        
        // Sadece son güne ait verileri veya tüm verileri döndürebiliriz.
        // UI'da "Allocation History" göstereceksek hepsini döndürelim.
        return allocations.sorted { $0.date > $1.date }
    }
}
