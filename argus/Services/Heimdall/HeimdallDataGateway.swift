import Foundation

/// Central Data Pipeline
/// Responsibility: Dedup (Coalesce) -> Cache -> Network
actor HeimdallDataGateway {
    static let shared = HeimdallDataGateway()
    
    private let coalescer = RequestCoalescer.shared
    private let cache = TTLCache.shared
    
    enum CachePolicy {
        case networkOnly
        case cacheOnly
        case cacheElseNetwork(ttl: TimeInterval)
    }
    
    private init() {}
    
    /// Generic Fetch Pipeline
    func fetch<T>(
        key: String,
        policy: CachePolicy,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T where T: Sendable {
        // 1. Cache Read
        if case .cacheElseNetwork(_) = policy {
            if let cached: T = await cache.get(key: key) {
                print("⚡️ Heimdall Gateway: Cache Hit for \(key)")
                return cached
            }
        } else if case .cacheOnly = policy {
            if let cached: T = await cache.get(key: key) {
                return cached
            }
            throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "Cache Miss for \(key)", bodyPrefix: "CacheOnly")
        }
        
        // 2. Coalesce & Execute
        let result = try await coalescer.coalesce(key: key) {
            // print("🌍 Heimdall Gateway: Network Call for \(key)") // Silenced to reduce noise
            return try await operation()
        }
        
        // 3. Cache Write
        if case .cacheElseNetwork(let ttl) = policy {
            await cache.set(key: key, value: result, ttl: ttl)
        }
        
        return result
    }
}
