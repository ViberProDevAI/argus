import Foundation
import Combine

// MARK: - API Key Store
/// API anahtarlarını güvenli bir şekilde yöneten merkezi servis.
/// Hem ObservableObject (SwiftUI) hem de static access (Services) destekler.

final class APIKeyStore: ObservableObject, @unchecked Sendable {
    static let shared = APIKeyStore()
    
    // UI Binding için
    @Published var keys: [APIProvider: String] = [:]
    
    private let defaults = UserDefaults.standard
    
    private init() {
        // 1. Load from UserDefaults first (Runtime Overrides)
        // 2. Fallback to Secrets/Info.plist (Build-time Config)
        
        // Define all supported providers
        let providers: [APIProvider] = [.fred, .gemini, .groq, .fmp, .twelveData, .tiingo, .marketstack, .alphaVantage, .eodhd, .deepSeek] // Note: .finnhub removed because APIProvider has no such case
        
        for provider in providers {
            if let savedKey = defaults.string(forKey: "API_KEY_\(provider.rawValue)"), !savedKey.isEmpty {
                keys[provider] = savedKey
            } else {
                // Fallback to Secrets
                switch provider {
                case .fred: keys[.fred] = Secrets.fredKey
                case .gemini: keys[.gemini] = Secrets.geminiKey
                case .groq: keys[.groq] = Secrets.groqKey // Now we load dynamic key
                case .deepSeek: keys[.deepSeek] = Secrets.deepSeekKey
                case .fmp: keys[.fmp] = Secrets.fmpKey
                case .twelveData: keys[.twelveData] = Secrets.twelveDataKey
                case .tiingo: keys[.tiingo] = Secrets.tiingoKey
                case .marketstack: keys[.marketstack] = Secrets.marketStackKey
                case .alphaVantage: keys[.alphaVantage] = Secrets.alphaVantageKey
                case .eodhd: keys[.eodhd] = Secrets.eodhdKey
                default: break
                }
            }
        }
    }
    
    // MARK: - Legacy / Direct Access Properties
    
    var dovizComToken: String { Secrets.dovizComKey }
    var borsaPyToken: String { Secrets.borsaPyKey }
    
    var geminiApiKey: String { keys[.gemini] ?? Secrets.geminiKey }
    var groqApiKey: String { keys[.groq] ?? Secrets.groqKey } // Fixed: Uses dynamic key
    var deepSeekApiKey: String { keys[.deepSeek] ?? Secrets.deepSeekKey }
    var fredApiKey: String { keys[.fred] ?? Secrets.fredKey }
    
    var massiveToken: String {
        return keys[.massive] ?? ""
    }
    
    // MARK: - ObservableObject Methods (Heimdall & Settings)
    
    func setKey(provider: APIProvider, key: String) {
        keys[provider] = key
        // Persist to UserDefaults
        defaults.set(key, forKey: "API_KEY_\(provider.rawValue)")
        notifyUpdate()
    }
    
    func deleteKey(provider: APIProvider) {
        keys.removeValue(forKey: provider)
        defaults.removeObject(forKey: "API_KEY_\(provider.rawValue)")
        
        // Restore default if available
        // (Simplified re-init logic)
        notifyUpdate()
    }
    
    func getKey(for provider: APIProvider) -> String? {
        return keys[provider]
    }
    
    static func getDirectKey(for provider: APIProvider) -> String? {
        return shared.getKey(for: provider)
    }
    
    private func notifyUpdate() {
        NotificationCenter.default.post(name: .argusKeyStoreDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let argusKeyStoreDidUpdate = Notification.Name("argusKeyStoreDidUpdate")
}
