import Foundation

/// Orchestrates data fetching by trying providers in sequence.
final class FieldBasedFallbackManager: Sendable {
    static let shared = FieldBasedFallbackManager()
    
    // Register Providers in Order of Priority
    // 1. Official / Primary (e.g. EODHD, Twelve) - To be implemented/passed
    // 2. Secondary
    // 3. Fallback (Yahoo)
    private var providers: [FallbackDataProvider] = []
    
    private let yahooFallback = YahooFallbackProvider()
    private let coinGecko = CoinGeckoProvider()
    
    private init() {
        // Setup default chain
        // Note: Real 'EODHDProvider' etc should be injected here.
        // For now, we only have YahooFallback implemented purely as DataProvider.
        // We will add placeholders or adapters for others.
        
        // Example:
        // providers.append(EODHDProviderAdapter())
        
        // Add CoinGecko for Crypto
        providers.append(coinGecko)
        
        // Always add Yahoo last
        providers.append(yahooFallback)
    }
    
    /// Register a high priority provider dynamically
    func registerProvider(_ provider: FallbackDataProvider) {
        // Insert at beginning? Or strict order?
        // Let's prepend to prioritize over Yahoo.
        if !providers.contains(where: { $0.name == provider.name }) {
            providers.insert(provider, at: 0)
        }
    }
    
    func fetch(field: DataField, for symbol: String) async throws -> DataFieldValue {
        var lastError: Error = DataFallbackError.noProviderForField
        
        for provider in providers {
            // 1. Check Support
            if !provider.supports(symbol: symbol, field: field) {
                continue
            }
            
            // 2. Try Fetch
            do {
                let val = try await provider.fetch(field: field, for: symbol)
                // 3. Validate (Basic Check)
                if isValid(val) {
                    return val
                } else {
                    // Logic for invalid data (e.g. 0 price)?
                    // Continue to next provider
                    print("⚠️ Provider \(provider.name) returned invalid data for \(symbol)/\(field)")
                }
            } catch {
                print("⚠️ Provider \(provider.name) failed for \(symbol)/\(field): \(error)")
                lastError = error
                // Continue to next provider
            }
        }
        
        // If all failed
        throw lastError
    }
    
    private func isValid(_ val: DataFieldValue) -> Bool {
        switch val {
        case .double(let d): return !d.isNaN && !d.isInfinite
        case .quote(let q): return q.currentPrice > 0
        default: return true
        }
    }
}
