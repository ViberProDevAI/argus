import Foundation

class ProviderSelector {
    static let shared = ProviderSelector()
    
    private init() {}
    
    enum ProviderType: String {
        case twelveData = "TwelveData"
        case finnhub = "Finnhub"
        case eodhd = "EODHD"
        case alphaVantage = "AlphaVantage"
        case yahoo = "Yahoo"
        // NEW
        case fmp = "FMP"
        case tiingo = "Tiingo"
        case coinApi = "CoinAPI"
        case marketStack = "MarketStack"
        
        var isBatchCapable: Bool {
            switch self {
            case .twelveData: return true
            case .eodhd: return true // Bulk API
            default: return false
            }
        }
    }
    
    func getPrioritizedProviders(for field: String) -> [ProviderType] {
        // 1. Get stats for last 24h
        let stats = ArgusProviderStatsStore.shared.stats(forLastDays: 1, field: field)
        
        // 2. Default Order: Diversity is strength
        // Order: 12D (Reliable) -> FMP (Fast) -> Tiingo (IEX) -> Finnhub -> EODHD -> MarketStack -> AV -> CoinAPI -> Yahoo
        var candidates: [ProviderType] = [.twelveData, .fmp, .tiingo, .finnhub, .eodhd, .marketStack, .alphaVantage, .coinApi, .yahoo]
        
        // 3. Re-order based on Health
        // Algorithm: If a provider has > 10 requests and successRate < 50%, move to bottom.
        let penaltyBox = stats.filter { $0.requestCount > 10 && $0.successRate < 50.0 }.map { $0.provider }
        
        if !penaltyBox.isEmpty {
            candidates.removeAll { penaltyBox.contains($0.rawValue) }
            // Add them back at the end
            candidates.append(contentsOf: penaltyBox.compactMap { ProviderType(rawValue: $0) })
        }
        
        return candidates
    }
}
