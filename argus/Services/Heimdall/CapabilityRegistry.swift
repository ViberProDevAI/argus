import Foundation

/// Static registry of what each provider CAN do.
/// Does not track health, only capability.
struct CapabilityRegistry {
    
    static let providers: [ProviderIdentity] = [
        ProviderIdentity(name: "FMP", supportedFields: [.quote, .candles, .fundamentals, .profile, .news, .holdings, .screener], supportedAssets: [.stock, .etf, .crypto, .index, .forex]),
        ProviderIdentity(name: "Yahoo", supportedFields: [.quote, .candles, .macro, .screener], supportedAssets: [.stock, .etf, .index, .crypto, .forex]),
        ProviderIdentity(name: "TwelveData", supportedFields: [.quote, .candles], supportedAssets: [.stock, .etf, .crypto, .forex]),
        ProviderIdentity(name: "Finnhub", supportedFields: [.quote, .news], supportedAssets: [.stock]),
        ProviderIdentity(name: "AlphaVantage", supportedFields: [.macro, .fx], supportedAssets: [.stock, .etf, .forex, .crypto]),
        ProviderIdentity(name: "Tiingo", supportedFields: [.quote, .candles], supportedAssets: [.stock, .etf]),
        ProviderIdentity(name: "EODHD", supportedFields: [.quote, .candles, .fundamentals], supportedAssets: [.stock, .etf, .crypto, .index])
    ]
    
    /// Returns a list of potential providers for a given field, ordered by static preference.
    /// This list is then filtered/reordered by HealthStore based on live metrics.
    static func getCandidates(for field: HeimdallDataField, assetType: AssetType = .stock) -> [String] {
        return providers.filter { $0.supportedFields.contains(field) && $0.supportedAssets.contains(assetType) }.map { $0.name }
    }
}

struct ProviderIdentity {
    let name: String
    let supportedFields: Set<HeimdallDataField>
    let supportedAssets: Set<AssetType>
    
    init(name: String, supportedFields: Set<HeimdallDataField>, supportedAssets: Set<AssetType> = [.stock, .etf, .index, .crypto, .forex]) {
        self.name = name
        self.supportedFields = supportedFields
        self.supportedAssets = supportedAssets
    }
}
