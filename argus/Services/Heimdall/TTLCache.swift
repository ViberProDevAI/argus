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
