import Foundation
import Combine
import Security

// MARK: - API Key Store
/// API anahtarlarını güvenli bir şekilde yöneten merkezi servis.
/// Hem ObservableObject (SwiftUI) hem de static access (Services) destekler.

final class APIKeyStore: ObservableObject, @unchecked Sendable {
    static let shared = APIKeyStore()

    // UI Binding için (salt okunur public)
    @Published private(set) var keys: [APIProvider: String] = [:]

    private let defaults = UserDefaults.standard
    private let keychainService = "com.argus.apikeys"

    private init() {
        for provider in APIProvider.allCases {
            if let key = readProviderKey(for: provider) {
                keys[provider] = key
            }
        }
    }

    // MARK: - Legacy / Direct Access Properties

    var dovizComToken: String { Secrets.dovizComKey }
    var borsaPyToken: String { Secrets.borsaPyKey }

    var geminiApiKey: String { resolvedKey(for: .gemini, fallback: Secrets.geminiKey) }
    var glmApiKey: String { resolvedKey(for: .glm, fallback: Secrets.glmKey) }
    var groqApiKey: String { resolvedKey(for: .groq, fallback: Secrets.groqKey) }
    var deepSeekApiKey: String { resolvedKey(for: .deepSeek, fallback: Secrets.deepSeekKey) }
    var fredApiKey: String { resolvedKey(for: .fred, fallback: Secrets.fredKey) }

    var massiveToken: String {
        resolvedKey(for: .massive, fallback: "")
    }

    // MARK: - ObservableObject Methods (Heimdall & Settings)

    func setKey(provider: APIProvider, key: String) {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            deleteKey(provider: provider)
            return
        }

        keys[provider] = value
        saveKeychainValue(value, account: providerAccount(for: provider))
        defaults.removeObject(forKey: legacyDefaultsKey(for: provider))
        notifyUpdate()
    }

    func deleteKey(provider: APIProvider) {
        keys.removeValue(forKey: provider)
        deleteKeychainValue(account: providerAccount(for: provider))
        defaults.removeObject(forKey: legacyDefaultsKey(for: provider))
        notifyUpdate()
    }

    func getKey(for provider: APIProvider) -> String? {
        guard let key = keys[provider], isUsableKey(key) else {
            return nil
        }
        return key
    }

    func setCustomValue(_ value: String, for storageKey: String) {
        let sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            deleteCustomValue(for: storageKey)
            return
        }

        saveKeychainValue(sanitized, account: customAccount(for: storageKey))
        defaults.removeObject(forKey: storageKey)
        notifyUpdate()
    }

    func getCustomValue(for storageKey: String) -> String? {
        if let stored = readKeychainValue(account: customAccount(for: storageKey)), isUsableKey(stored) {
            return stored
        }

        if let legacy = defaults.string(forKey: storageKey), isUsableKey(legacy) {
            saveKeychainValue(legacy, account: customAccount(for: storageKey))
            defaults.removeObject(forKey: storageKey)
            return legacy
        }

        return nil
    }

    func deleteCustomValue(for storageKey: String) {
        deleteKeychainValue(account: customAccount(for: storageKey))
        defaults.removeObject(forKey: storageKey)
        notifyUpdate()
    }

    static func getDirectKey(for provider: APIProvider) -> String? {
        shared.getKey(for: provider)
    }

    // MARK: - Internal Helpers

    private func resolvedKey(for provider: APIProvider, fallback: String) -> String {
        if let existing = getKey(for: provider) {
            return existing
        }
        return isUsableKey(fallback) ? fallback : ""
    }

    private func readProviderKey(for provider: APIProvider) -> String? {
        let account = providerAccount(for: provider)

        if let keychainValue = readKeychainValue(account: account), isUsableKey(keychainValue) {
            return keychainValue
        }

        let legacyKey = legacyDefaultsKey(for: provider)
        if let legacyValue = defaults.string(forKey: legacyKey), isUsableKey(legacyValue) {
            saveKeychainValue(legacyValue, account: account)
            defaults.removeObject(forKey: legacyKey)
            return legacyValue
        }

        let fallback = secretFallback(for: provider)
        return isUsableKey(fallback) ? fallback : nil
    }

    private func secretFallback(for provider: APIProvider) -> String {
        switch provider {
        case .fred:
            return Secrets.fredKey
        case .gemini:
            return Secrets.geminiKey
        case .glm:
            return Secrets.glmKey
        case .groq:
            return Secrets.groqKey
        case .fmp:
            return Secrets.fmpKey
        case .twelveData:
            return Secrets.twelveDataKey
        case .tiingo:
            return Secrets.tiingoKey
        case .marketstack:
            return Secrets.marketStackKey
        case .alphaVantage:
            return Secrets.alphaVantageKey
        case .eodhd:
            return Secrets.eodhdKey
        case .deepSeek:
            return Secrets.deepSeekKey
        case .pinecone:
            return Secrets.pineconeKey
        case .massive:
            return ""
        }
    }

    private func isUsableKey(_ value: String?) -> Bool {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }

        let upper = raw.uppercased()
        if upper.hasPrefix("YOUR_") || upper.contains("PLACEHOLDER") {
            return false
        }
        if upper == "CHANGE_ME" || upper == "<REDACTED>" {
            return false
        }

        return true
    }

    private func legacyDefaultsKey(for provider: APIProvider) -> String {
        "API_KEY_\(provider.rawValue)"
    }

    private func providerAccount(for provider: APIProvider) -> String {
        "provider.\(provider.rawValue)"
    }

    private func customAccount(for storageKey: String) -> String {
        "custom.\(storageKey)"
    }

    // MARK: - Keychain

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private func readKeychainValue(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func saveKeychainValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        deleteKeychainValue(account: account)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychainValue(account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
    }

    private func notifyUpdate() {
        NotificationCenter.default.post(name: .argusKeyStoreDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let argusKeyStoreDidUpdate = Notification.Name("argusKeyStoreDidUpdate")
}
