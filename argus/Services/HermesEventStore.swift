import Foundation

final class HermesEventStore {
    static let shared = HermesEventStore()
    
    private let cacheKey = "argus_hermes_event_cache_v1"
    private var cache: [String: HermesEvent] = [:] // Key: Article ID
    private let lock = NSLock()
    
    private init() {
        Task {
            if let loaded: [String: HermesEvent] = await ArgusDataStore.shared.load(key: cacheKey) {
                lock.lock()
                cache = loaded
                lock.unlock()
            }
        }
    }
    
    func getEvent(for articleId: String) -> HermesEvent? {
        lock.lock()
        defer { lock.unlock() }
        return cache[articleId]
    }
    
    func getEvents(for symbol: String) -> [HermesEvent] {
        lock.lock()
        let events = cache.values.filter { $0.symbol.uppercased() == symbol.uppercased() }
        lock.unlock()
        return events.sorted { $0.publishedAt > $1.publishedAt }
    }
    
    func saveEvents(_ events: [HermesEvent]) {
        guard !events.isEmpty else { return }
        lock.lock()
        for event in events {
            cache[event.articleId] = event
        }
        let snapshot = cache
        lock.unlock()
        
        Task {
            await ArgusDataStore.shared.save(snapshot, key: cacheKey)
        }
    }
}
