import Foundation
import Security

// MARK: - Keychain Manager
/// API anahtarlarını güvenli bir şekilde saklar
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Keychain Service
    private let service = "com.algotrading.keys"
    
    // MARK: - Key Types
    enum APIKey: String, CaseIterable {
        case twelveData = "TWELVE_DATA_KEY"
        case fmp = "FMP_KEY"
        case finnhub = "FINNHUB_KEY"
        case tiingo = "TIINGO_KEY"
        case marketstack = "MARKETSTACK_KEY"
        case groq = "GROQ_KEY"
        case alphaVantage = "ALPHA_VANTAGE_KEY"
        case eodhd = "EODHD_KEY"
        case gemini = "GEMINI_KEY"
        case deepseek = "DEEPSEEK_KEY"
        case fred = "FRED_KEY"
        // 2026-04-24: `case simfin` kaldırıldı — SimFin entegrasyonu hiç yazılmadı,
        // case tanımı APIKey.allCases üzerinden keychain migration'a ölü entry
        // ekliyordu. INFOPLIST_KEY_SIMFIN_KEY ve Secrets.xcconfig.example girdisi
        // de bu commit'te temizlendi.
        case pinecone = "PINECONE_KEY"
    }
    
    // MARK: - Save Key
    func save(key: APIKey, value: String) -> Bool {
        guard !value.isEmpty else { return false }
        
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            // 2026-04-23 security hardening: WhenUnlocked → AfterFirstUnlockThisDeviceOnly.
            // Cihaza bağlı (yedekten başka cihaza restore ile taşınmaz) + ilk
            // unlock sonrası okunabilir (background refresh'e izin verir).
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Önce varsa sil
        SecItemDelete(query as CFDictionary)
        
        let result = SecItemAdd(query as CFDictionary, nil)
        
        if result == errSecSuccess {
            print("🔐 Keychain: \(key.rawValue) kaydedildi")
            return true
        } else {
            print("❌ Keychain: \(key.rawValue) kaydedilemedi - \(result)")
            return false
        }
    }
    
    // MARK: - Read Key
    func read(key: APIKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        print("⚠️ Keychain: \(key.rawValue) bulunamadı")
        return nil
    }
    
    // MARK: - Delete Key
    func delete(key: APIKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("🗑️ Keychain: \(key.rawValue) silindi")
            return true
        } else if status == errSecItemNotFound {
            print("ℹ️ Keychain: \(key.rawValue) zaten yok")
            return true
        } else {
            print("❌ Keychain: \(key.rawValue) silinemedi - \(status)")
            return false
        }
    }
    
    // MARK: - Delete All Keys
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("🗑️ Keychain: Tüm anahtarlar silindi")
            return true
        } else {
            print("❌ Keychain: Anahtarlar silinemedi - \(status)")
            return false
        }
    }
    
    // MARK: - List All Keys
    func listAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        var keys: [String] = []
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String {
                    keys.append(account)
                }
            }
        }
        
        return keys
    }
    
    // MARK: - Check Key Exists
    func keyExists(key: APIKey) -> Bool {
        return read(key: key) != nil
    }
    
    // MARK: - Initialize Keys from Secrets.xcconfig
    func initializeFromSecretsFile() {
        print("🔐 Keychain: Secrets.xcconfig'den anahtarları yükleniyor...")
        
        let defaults = UserDefaults.standard
        
        for keyType in APIKey.allCases {
            // Keychain'de var mı kontrol et
            if keyExists(key: keyType) {
                print("✅ \(keyType.rawValue): Zaten keychain'de")
                continue
            }
            
            // UserDefaults'tan oku (Secrets.xcconfig'ten gelmiş olabilir)
            if let value = defaults.string(forKey: keyType.rawValue), !value.isEmpty, !value.contains("YOUR_") {
                if save(key: keyType, value: value) {
                    // UserDefaults'tan sil (artık keychain'de)
                    defaults.removeObject(forKey: keyType.rawValue)
                    print("✅ \(keyType.rawValue): Keychain'a taşındı, UserDefaults'tan temizlendi")
                }
            } else {
                print("⚠️ \(keyType.rawValue): Secrets'te bulunamadı veya placeholder")
            }
        }
        
        print("🔐 Keychain: Başlatma tamamlandı")
    }
    
    // MARK: - Key Rotation (Placeholder)
    /// Anahtar rotasyonu için placeholder
    func rotateKeys() {
        print("🔄 Keychain: Anahtar rotasyonu başlatılıyor...")
        
        // Gelecekte: API endpoint'lerini kontrol et
        // Expired keys'i tespit et
        // Yeni keys'i generate et veya kullanıcıdan iste
        
        for keyType in APIKey.allCases {
            if let currentValue = read(key: keyType) {
                // Rotasyon logic'i buraya gelecek
                if currentValue.isEmpty {
                    continue
                }
                print("ℹ️ \(keyType.rawValue): Rotasyon kontrol ediliyor.")
            }
        }
        
        print("🔄 Keychain: Anahtar rotasyonu tamamlandı")
    }
}

// MARK: - Convenience Extension
extension KeychainManager {
    /// Tüm required key'lerin keychain'de olup olmadığını kontrol et
    func validateAllKeys() -> Bool {
        var missingKeys: [String] = []
        
        for keyType in APIKey.allCases {
            if !keyExists(key: keyType) {
                missingKeys.append(keyType.rawValue)
            }
        }
        
        if missingKeys.isEmpty {
            print("✅ Keychain: Tüm anahtarlar mevcut")
            return true
        } else {
            print("⚠️ Keychain: Eksik anahtarlar - \(missingKeys.joined(separator: ", "))")
            return false
        }
    }
    
    /// Belirli bir key'i UserDefaults fallback ile al
    func getKeySafely(key: APIKey) -> String {
        // Önce keychain'den oku
        if let value = read(key: key) {
            return value
        }

        // Fallback: UserDefaults'tan oku (migration için)
        if let value = UserDefaults.standard.string(forKey: key.rawValue) {
            // Keychain'a kaydet ve UserDefaults'tan sil
            save(key: key, value: value)
            UserDefaults.standard.removeObject(forKey: key.rawValue)
            return value
        }

        print("❌ Keychain: \(key.rawValue) bulunamadı ve fallback yok")
        return ""
    }

    /// Güvenlik temizliği: UserDefaults'ta plaintext kalmış olabilecek TÜM API key'leri
    /// Keychain'e migrate eder ve UserDefaults'tan siler. Uygulama başlangıcında çağrılır.
    /// Eski sürümlerde (Keychain henüz kullanılmıyordu) plaintext kalmış olma riskine karşı.
    func migrateLegacyUserDefaultsKeys() {
        let defaults = UserDefaults.standard
        var migrated: [String] = []
        var scrubbed: [String] = []

        for key in APIKey.allCases {
            guard let legacyValue = defaults.string(forKey: key.rawValue),
                  !legacyValue.isEmpty else { continue }

            // Keychain'da yoksa migrate et, varsa sadece UserDefaults'ı temizle
            if read(key: key) == nil {
                if save(key: key, value: legacyValue) {
                    migrated.append(key.rawValue)
                }
            } else {
                scrubbed.append(key.rawValue)
            }
            defaults.removeObject(forKey: key.rawValue)
        }

        if !migrated.isEmpty {
            print("🔐 Keychain migration: UserDefaults → Keychain taşındı: \(migrated.joined(separator: ", "))")
        }
        if !scrubbed.isEmpty {
            print("🧹 Keychain migration: UserDefaults plaintext kalıntıları temizlendi: \(scrubbed.joined(separator: ", "))")
        }
    }
}
