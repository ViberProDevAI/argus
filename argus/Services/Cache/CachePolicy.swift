import Foundation

// MARK: - Unified Cache Policy
// Tüm cache TTL değerlerini merkezi bir noktadan yönetir
// Mevcut çelişkili TTL'leri standardize eder

/// Unified cache time-to-live values
/// Tüm modüller bu dosyadaki değerleri kullanmalı
struct CacheTTL {
    
    // MARK: - Market Data (High Frequency)
    
    /// Gerçek zamanlı fiyat verileri
    static let quote: TimeInterval = 15 // 15 saniye
    
    /// Mum grafik verileri
    static let candles: TimeInterval = 300 // 5 dakika
    
    /// Order book / depth verileri
    static let orderBook: TimeInterval = 5 // 5 saniye
    
    // MARK: - Analysis Data (Medium Frequency)
    
    /// Orion teknik analiz sonuçları
    static let orionScore: TimeInterval = 300 // 5 dakika
    
    /// Atlas fundamental analiz sonuçları
    static let atlasScore: TimeInterval = 3600 // 1 saat
    
    /// Hermes haber özetleri
    static let hermesSummary: TimeInterval = 600 // 10 dakika
    
    /// Aether makro verileri
    static let macroData: TimeInterval = 300 // 5 dakika
    
    /// Phoenix senaryoları
    static let phoenixScenario: TimeInterval = 300 // 5 dakika
    
    // MARK: - Static Data (Low Frequency)
    
    /// Şirket profil bilgileri
    static let profile: TimeInterval = 86400 // 24 saat
    
    /// Fundamental data (bilanço vs)
    static let fundamentals: TimeInterval = 3600 // 1 saat
    
    /// Sektör bilgileri
    static let sectorData: TimeInterval = 86400 // 24 saat
    
    // MARK: - Decision Data
    
    /// Argus karar cache'i
    static let decision: TimeInterval = 60 // 1 dakika
    
    /// Grand Council kararları
    static let councilDecision: TimeInterval = 300 // 5 dakika
    
    // MARK: - Convenience Methods
    
    /// TTL'i saniye cinsinden milisaniyeye çevir
    static func toMilliseconds(_ ttl: TimeInterval) -> Int {
        Int(ttl * 1000)
    }
    
    /// TTL bitmiş mi kontrol et
    static func isExpired(timestamp: Date?, ttl: TimeInterval) -> Bool {
        guard let timestamp = timestamp else { return true }
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Cache Entry

/// Generic cache entry with TTL support
struct CacheEntry<T> {
    let value: T
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
    
    var timeRemaining: TimeInterval {
        max(0, ttl - Date().timeIntervalSince(timestamp))
    }
    
    init(value: T, ttl: TimeInterval) {
        self.value = value
        self.timestamp = Date()
        self.ttl = ttl
    }
}

// MARK: - Cache Store Protocol

/// Generic cache store interface
protocol CacheStore {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) -> Value?
    func set(_ key: Key, value: Value, ttl: TimeInterval)
    func invalidate(_ key: Key)
    func invalidateAll()
    var count: Int { get }
}

// MARK: - In-Memory Cache Store

/// Thread-safe in-memory cache store
@MainActor
final class MemoryCacheStore<Key: Hashable, Value>: CacheStore {
    
    private var cache: [Key: CacheEntry<Value>] = [:]
    
    func get(_ key: Key) -> Value? {
        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key) // Auto-cleanup expired
            return nil
        }
        return entry.value
    }
    
    func set(_ key: Key, value: Value, ttl: TimeInterval) {
        cache[key] = CacheEntry(value: value, ttl: ttl)
    }
    
    func invalidate(_ key: Key) {
        cache.removeValue(forKey: key)
    }
    
    func invalidateAll() {
        cache.removeAll()
    }
    
    var count: Int {
        cache.count
    }
    
    /// Expired entries temizle
    func cleanup() {
        let now = Date()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= entry.ttl
        }
    }
}

// MARK: - Migration Notes

/*
 MEVCUT CACHE SİSTEMLERİ VE YENİ STANDART DEĞERLERİ:
 
 1. MarketDataStore
    - Eski: quotes 15s, candles çeşitli, profile 24h
    - Yeni: CacheTTL.quote, CacheTTL.candles, CacheTTL.profile
 
 2. QuoteCache (TTLCache içinde)
    - Eski: 1 dakika
    - Yeni: CacheTTL.quote (15s) - Daha taze veri
 
 3. MacroRegimeService
    - Eski: 5 dakika
    - Yeni: CacheTTL.macroData (5 dakika) - Aynı
 
 4. ArgusGrandCouncil
    - Eski: 5 dakika
    - Yeni: CacheTTL.councilDecision (5 dakika) - Aynı
 
 5. FundamentalScoreStore
    - Eski: 1 saat
    - Yeni: CacheTTL.atlasScore (1 saat) - Aynı
 
 MIGRATION:
 - Yeni kod CacheTTL sabitlerini kullanmalı
 - Mevcut kod zamanla migrate edilecek
 - CacheEntry<T> wrapper'ı kullanılması önerilir
*/
