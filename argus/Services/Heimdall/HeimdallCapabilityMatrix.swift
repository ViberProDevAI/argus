import Foundation

/// Static definition of Provider Capabilities and Characteristics.
/// This acts as the "Constitution" for Heimdall Routing.
struct HeimdallCapabilityMatrix {
    static let shared = HeimdallCapabilityMatrix()
    
    struct ProviderProfile: Sendable {
        let tag: ProviderTag
        let supportedAssets: Set<AssetType>
        let supportedEndpoints: Set<HeimdallDataField>
        let costWeight: Int // Relative cost (1-10)
        let baseReliability: Double // 0.0 - 1.0
        let isPermanentlyQuarantined: Bool
        let quarantineReason: String?
    }
    
    let profiles: [ProviderTag: ProviderProfile]
    
    init() {
        var p: [ProviderTag: ProviderProfile] = [:]
        
        // 1. Yahoo Finance (The Workhorse)
        // 1. Yahoo Finance (The Workhorse)
        // 1. Yahoo Finance (Backup due to Quality Complaints)
        p[.yahoo] = ProviderProfile(
            tag: .yahoo,
            supportedAssets: [.stock, .etf, .crypto, .forex, .index],
            supportedEndpoints: [.quote, .candles, .profile, .screener, .macro, .fundamentals],
            costWeight: 1, // PRIMARY for Deep Data (Resurrected via Auth)
            baseReliability: 0.95,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        
        // 2. FMP (Financial Modeling Prep) - ACTIVE (New API Key)
        p[.fmp] = ProviderProfile(
            tag: .fmp,
            supportedAssets: [.stock, .etf],
            supportedEndpoints: [.quote, .candles, .fundamentals, .profile, .news],
            costWeight: 2, // Secondary to TwelveData
            baseReliability: 0.90,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        
        // 3. EODHD (Reliable Backup - Demo Key Limit)
        p[.eodhd] = ProviderProfile(
            tag: .eodhd,
            supportedAssets: [.stock, .etf, .crypto, .index, .forex],
            supportedEndpoints: [.quote, .candles, .screener],
            costWeight: 10, // EMERGENCY BACKUP ONLY (20 calls/day limit)
            baseReliability: 0.90,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )

        // 4. TwelveData (Primary Market Data)
        p[.twelvedata] = ProviderProfile(
            tag: .twelvedata,
            supportedAssets: [.stock, .forex, .etf, .crypto],
            supportedEndpoints: [.quote, .candles, .fundamentals], // Enabled for Atlas Fallback
            costWeight: 1, // PRIMARY MARKET DATA
            baseReliability: 0.99,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        p[.fred] = ProviderProfile(
            tag: .fred,
            supportedAssets: [.index], // Proxy for Macro
            supportedEndpoints: [.macro],
            costWeight: 1,
            baseReliability: 0.99,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        
        // 5. TwelveData (Specific Geo)
        // 5. TwelveData (Specific Geo) - Duplicate removed
        
        // 6. Tiingo (Backup)
        p[.tiingo] = ProviderProfile(
            tag: .tiingo,
            supportedAssets: [.stock, .crypto, .etf],
            supportedEndpoints: [.quote],
            costWeight: 4,
            baseReliability: 0.80,
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        
        // 7. LocalScanner (Phoenix Fallback)
        p[.localScanner] = ProviderProfile(
            tag: .localScanner,
            supportedAssets: [.stock, .etf, .crypto],
            supportedEndpoints: [.screener],
            costWeight: 99, // Last Resort
            baseReliability: 1.0, // Local is always "up"
            isPermanentlyQuarantined: false,
            quarantineReason: nil
        )
        
        self.profiles = p
    }
    
    func getProfile(for provider: ProviderTag) -> ProviderProfile? {
        return profiles[provider]
    }
    
    func getCandidates(for field: HeimdallDataField, assetType: AssetType) -> [ProviderTag] {
        let all = profiles.values.map { $0.tag.rawValue }
        let withEndpoint = profiles.values.filter { $0.supportedEndpoints.contains(field) }.map { $0.tag.rawValue }
        let withAsset = profiles.values.filter { $0.supportedEndpoints.contains(field) && $0.supportedAssets.contains(assetType) }.map { $0.tag.rawValue }
        let notQuarantined = profiles.values.filter { $0.supportedEndpoints.contains(field) && $0.supportedAssets.contains(assetType) && !$0.isPermanentlyQuarantined }.map { $0.tag.rawValue }
        
        if field == .fundamentals {
            print("🔍 MATRIX getCandidates: field=\(field) assetType=\(assetType)")
            print("   all=\(all)")
            print("   withEndpoint=\(withEndpoint)")
            print("   withAsset=\(withAsset)")
            print("   notQuarantined=\(notQuarantined)")
        }
        
        return profiles.values
            .filter { $0.supportedEndpoints.contains(field) }
            .filter { $0.supportedAssets.contains(assetType) }
            .filter { !$0.isPermanentlyQuarantined }
            .sorted { $0.costWeight < $1.costWeight } // Cheapest first
            .map { $0.tag }
    }
}
