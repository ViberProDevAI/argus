import Foundation

final class CoinGeckoProvider: FallbackDataProvider {
    let name = "CoinGecko"
    
    func supports(symbol: String, field: DataField) -> Bool {
        // Supports BTC/ETH daily change and price
        if field == .btcDailyChangePercent || field == .btcPrice || field == .lastPrice {
            return symbol.uppercased().contains("BTC")
        }
        return false
    }
    
    func fetch(field: DataField, for symbol: String) async throws -> DataFieldValue {
        // Map symbol to CoinGecko ID
        let id = mapToCoinGeckoId(symbol)
        
        // Simple Price API
        let urlStr = "https://api.coingecko.com/api/v3/simple/price?ids=\(id)&vs_currencies=usd&include_24hr_change=true"
        guard let url = URL(string: urlStr) else { throw DataFallbackError.invalidData }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw DataFallbackError.networkError("CoinGecko HTTP Error")
        }
        
        let result = try JSONDecoder().decode(CoinGeckoSimpleResponse.self, from: data)
        
        // Dynamic access to the ID key
        // But Codable is strict. Use a dictionary wrapper or just hardcode for bitcoin for now.
        // Or make the struct dynamic.
        guard let item = result.data[id] else {
            throw DataFallbackError.invalidData
        }
        
        switch field {
        case .lastPrice, .btcPrice:
            return .double(item.usd)
        case .btcDailyChangePercent:
            return .double(item.usd_24h_change)
        default:
            throw DataFallbackError.notSupported
        }
    }
    
    private func mapToCoinGeckoId(_ symbol: String) -> String {
        let s = symbol.uppercased()
        if s.contains("BTC") { return "bitcoin" }
        if s.contains("ETH") { return "ethereum" }
        return "bitcoin" // default
    }
}

// Private Models
private struct CoinGeckoSimpleResponse: Codable {
    let data: [String: CoinGeckoItem]
    
    struct CoinGeckoItem: Codable {
        let usd: Double
        let usd_24h_change: Double
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.data = try container.decode([String: CoinGeckoItem].self)
    }
}
