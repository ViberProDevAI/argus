import Foundation

actor QuoteCache {
    static let shared = QuoteCache()
    
    private struct CachedItem {
        let quote: Quote
        let timestamp: Date
    }
    
    private var cache: [String: CachedItem] = [:]
    private let ttl: TimeInterval = 60 // 1 Minute Freshness
    
    private init() {}
    
    func get(symbol: String) -> Quote? {
        guard let item = cache[symbol] else { return nil }
        if Date().timeIntervalSince(item.timestamp) < ttl {
            return item.quote
        }
        return nil // Expired
    }
    
    // Returns even expired data if we want to show "stale" state
    func getAny(symbol: String) -> (Quote?, Bool) {
        guard let item = cache[symbol] else { return (nil, false) }
        let isFresh = Date().timeIntervalSince(item.timestamp) < ttl
        return (item.quote, isFresh)
    }
    
    func set(symbol: String, quote: Quote) {
        cache[symbol] = CachedItem(quote: quote, timestamp: Date())
    }
    
    func setBatch(quotes: [String: Quote]) {
        let now = Date()
        for (sym, q) in quotes {
            cache[sym] = CachedItem(quote: q, timestamp: now)
        }
    }
}
