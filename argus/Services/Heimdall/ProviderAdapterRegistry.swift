import Foundation

/// Registry for mapping Canonical Providers to their runtime Adapters.
/// Solves the "Candidate Yahoo has no adapter" bug by strictly verifying capabilities.
actor ProviderAdapterRegistry {
    static let shared = ProviderAdapterRegistry()
    
    // Map: ProviderTag -> (Domain -> Adapter)
    private var adapters: [ProviderTag: [HeimdallDataField: any HeimdallProvider]] = [:]
    
    private init() {}
    
    /// Registers an adapter for specific capabilities
    func register(adapter: any HeimdallProvider, for domains: [HeimdallDataField]) {
        let tag = ProviderTag(rawValue: adapter.name) ?? .unknown // Map string name to Enum Tag
        
        if adapters[tag] == nil {
            adapters[tag] = [:]
        }
        
        for domain in domains {
            adapters[tag]?[domain] = adapter
            print("🔌 Registry: Linked [\(tag.rawValue)] -> [\(domain.rawValue)]")
        }
    }
    
    /// Retrieves the correct adapter for a specific job
    func getAdapter(provider: String, domain: HeimdallDataField) -> (any HeimdallProvider)? {
        guard let tag = ProviderTag(rawValue: provider) else { return nil }
        return adapters[tag]?[domain]
    }
    
    /// Verifies if a provider is actually executable for a domain
    func hasAdapter(provider: String, domain: HeimdallDataField) -> Bool {
        guard let tag = ProviderTag(rawValue: provider) else { return false }
        return adapters[tag]?[domain] != nil
    }
    
    /// Bulk Load (Call at Startup)
    func loadDirectly() async {
        // Resolve Singletons on Main Actor to avoid isolation errors
        let (yahoo, fred, twelve, eod, local, massive) = await MainActor.run {
            return (
                YahooFinanceProvider.shared,
                FredProvider.shared,
                TwelveDataService.shared,
                EODHDProvider.shared,
                LocalScannerAdapter.shared,
                MassiveProvider.shared
            )
        }

        // Register Adapters
        // Yahoo now handles candles via delegation, so we register it for .candles too
        register(adapter: yahoo, for: [.quote, .screener, .macro, .fundamentals, .candles])

        register(adapter: fred, for: [.macro])

        register(adapter: twelve, for: [.quote, .candles, .fundamentals])

        register(adapter: eod, for: [.quote, .candles, .fundamentals])

        register(adapter: local, for: [.screener])
        
        register(adapter: massive, for: [.options])
        
        print("🔌 ProviderAdapterRegistry: Loaded.")
    }
}
