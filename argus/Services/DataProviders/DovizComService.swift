
import Foundation

enum DovizComError: Error {
    case invalidURL
    case networkError(Error)
    case parsingError
    case dataNotAvailable
}

class DovizComService {
    static let shared = DovizComService()
    
    private let baseURL = "https://api.doviz.com/v1/"
    private var token: String { APIKeyStore.shared.dovizComToken }
    private let kurBaseURL = "https://kur.doviz.com"
    private let altinBaseURL = "https://altin.doviz.com"
    
    // Doviz.com metal slug mapping
    private let metalSlugs: [String: String] = [
        "gram-altin": "gram-altin",
        "gram-gumus": "gumus",
        "ons-altin": "ons",
        "gram-platin": "gram-platin",
        "gram-paladyum": "gram-paladyum"
    ]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Kurum bazlı değerli metal fiyatlarını getirir (HTML Scraping)
    /// - Parameter asset: "gram-altin", "gram-gumus" vb.
    func fetchMetalInstitutionRates(asset: String) async throws -> [InstitutionRate] {
        guard let slug = metalSlugs[asset] else {
            throw DovizComError.dataNotAvailable
        }
        
        let urlString = "\(altinBaseURL)/\(slug)"
        guard let url = URL(string: urlString) else { throw DovizComError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { throw DovizComError.parsingError }
        
        return parseInstitutionRates(html: html, asset: asset)
    }
    
    // MARK: - HTML Parsing
    
    private func parseInstitutionRates(html: String, asset: String) -> [InstitutionRate] {
        var rates: [InstitutionRate] = []
        
        // Regex ile tablo satırlarını bulmaya çalışalım
        // <a href="https://altin.doviz.com/akbank/gram-altin">...Akbank...</a>...<td>3.000,00</td>...<td>3.100,00</td>
        
        // Basit regex desenleri (Not: HTML regex ile parse edilmez ama basit yapılar için hızlı çözüm)
        // Alternatif: Satır satır işleyip belirli pattern'leri yakalamak
        
        // Doviz.com yapısına uygun regex (basitleştirilmiş)
        // href="https://altin.doviz.com/([^/]+)/[^"]+".*?>([^<]+)</a>.*?<td>([\d\.,]+)</td>.*?<td>([\d\.,]+)</td>
        
        let pattern = #"href="https:\/\/altin\.doviz\.com\/([^\/]+)\/[^"]+".*?>([^<]+)<\/a>.*?<td>([\d\.,]+)<\/td>.*?<td>([\d\.,]+)<\/td>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in results {
            if match.numberOfRanges >= 5 {
                let slug = nsString.substring(with: match.range(at: 1))
                let name = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let buyStr = nsString.substring(with: match.range(at: 3))
                let sellStr = nsString.substring(with: match.range(at: 4))
                
                if let buy = parseTurkishNumber(buyStr),
                   let sell = parseTurkishNumber(sellStr) {
                    
                    // Spread hesapla
                    let spread = ((sell - buy) / buy) * 100
                    
                    rates.append(InstitutionRate(
                        institution: slug,
                        institutionName: name,
                        asset: asset,
                        buy: buy,
                        sell: sell,
                        spread: spread,
                        updateTime: Date() // Anlık çekildiği için şimdiki zaman
                    ))
                }
            }
        }
        
        return rates
    }
    
    private func parseTurkishNumber(_ value: String) -> Double? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                           .replacingOccurrences(of: ".", with: "") // Binlik ayırıcıyı kaldır
                           .replacingOccurrences(of: ",", with: ".") // Ondalık ayırıcıyı nokta yap
        return Double(cleaned)
    }
}
