import Foundation

/// TTL Cache
/// Responsibility: Short-term canonical caching to reduce API load.
actor TTLCache {
    static let shared = TTLCache()
    
    struct CacheEntry {
        let value: Any
        let expiry: Date
    }
    
    private var storage: [String: CacheEntry] = [:]
    
    private init() {}
    
    func get<T>(key: String) -> T? {
        guard let entry = storage[key] else { return nil }
        
        if Date() > entry.expiry {
            storage.removeValue(forKey: key)
            return nil
        }
        
        return entry.value as? T
    }
    
    func set(key: String, value: Any, ttl: TimeInterval) {
        let expiry = Date().addingTimeInterval(ttl)
        storage[key] = CacheEntry(value: value, expiry: expiry)
        
        // Lazy Cleanup (Probabilistic or threshold based)
        if storage.count > 500 {
            cleanup()
        }
    }
    
    private func cleanup() {
        let now = Date()
        storage = storage.filter { $0.value.expiry > now }
    }
    
    func clear() {
        storage.removeAll()
    }
}

// MARK: - Stale Data Registry
//
// UI'ın ve karar motorlarının "bu veri ne kadar taze?" sorusunu hızla cevaplayabilmesi için
// hafif bir timestamp sicili. Her büyük veri fetch'inden sonra `touch(_:)` çağrılır,
// UI yeşil/sarı/kırmızı rozetle gösterir, decision engine'ler "stale" ise soft-fallback alır.
//
// Tasarım prensipleri:
//  - Aktör tabanlı: concurrency güvenli
//  - Harici bağımlılık yok: sadece Date ve sözlük
//  - Fail-safe: fetch olmadıysa "Never" döner, kararlar "bilinmiyor" varsayımıyla ilerleyebilir

public actor StaleDataRegistry {
    public static let shared = StaleDataRegistry()

    private var lastUpdate: [String: Date] = [:]

    /// Veri kaynağı için tazelik seviyesi
    public enum Freshness: String, Sendable {
        case fresh      // < 1x TTL
        case aging      // 1-2x TTL
        case stale      // > 2x TTL
        case unknown    // hiç touch edilmemiş
    }

    private init() {}

    /// Veri kaynağı güncellendi; şu an ile işaretle.
    public func touch(_ key: String, at date: Date = Date()) {
        lastUpdate[key] = date
    }

    /// Bir veri kaynağının yaşı (saniye). Hiç touch edilmediyse `nil`.
    public func ageSeconds(_ key: String) -> TimeInterval? {
        guard let last = lastUpdate[key] else { return nil }
        return Date().timeIntervalSince(last)
    }

    /// Bir veri kaynağının tazeliği — beklenen TTL'e göre.
    /// - Parameter expectedTTL: Bu veri ne sıklıkla yenilenmeli (saniye).
    public func freshness(_ key: String, expectedTTL: TimeInterval) -> Freshness {
        guard let age = ageSeconds(key) else { return .unknown }
        if age < expectedTTL { return .fresh }
        if age < expectedTTL * 2 { return .aging }
        return .stale
    }

    /// Tüm bilinen veri kaynaklarının yaşları (UI teşhis paneli için).
    public func snapshot() -> [String: TimeInterval] {
        let now = Date()
        return lastUpdate.mapValues { now.timeIntervalSince($0) }
    }
}
