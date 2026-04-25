import Foundation

struct SymbolMapper {
    enum ProviderType {
        case twelveData, finnhub, eodhd, alphaVantage, yahoo
        case fmp, tiingo, coinApi, marketStack
    }
    
    static func normalize(symbol: String, for provider: ProviderType) -> String {
        let clean = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        switch provider {
        case .eodhd:
            if !clean.contains(".") { return "\(clean).US" }
            return clean
            
        case .twelveData, .finnhub, .alphaVantage, .yahoo, .fmp, .tiingo, .marketStack:
            return clean
            
        case .coinApi:
             // CoinAPI raw ID
            return clean
        }
    }
}
