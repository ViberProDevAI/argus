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

    // MARK: - Rejim Dönüşüm Detektörü için sayım API'leri
    //
    // AetherRegimeTransitionDetector'ın "son 24 saatte kaç yüksek etkili pozitif/negatif
    // haber geldi?" sorusuna gerçek cevap. Önceki sürüm tek symbol'ün netSupport'una
    // bakıyordu; bu piyasa-geneli (global scope) haber akışını tarıyor.

    /// Son `window` saat içinde gelen, belirtilen polariteye sahip YÜKSEK ETKİLİ
    /// event sayısı. "Yüksek etkili" = severity × sourceReliability/100 ≥ impactThreshold.
    /// - Parameters:
    ///   - polarity: `.positive` veya `.negative`
    ///   - windowHours: varsayılan 24 saat
    ///   - impactThreshold: varsayılan 50 (severity 1-100 × reliability/100)
    func countHighImpactEvents(
        polarity: HermesEventPolarity,
        windowHours: Double = 24,
        impactThreshold: Double = 50
    ) -> Int {
        let cutoff = Date().addingTimeInterval(-windowHours * 3600)
        lock.lock()
        defer { lock.unlock() }
        return cache.values.filter { event in
            guard event.polarity == polarity else { return false }
            guard event.publishedAt >= cutoff else { return false }
            let impact = event.severity * (event.sourceReliability / 100.0)
            return impact >= impactThreshold
        }.count
    }

    /// Son `window` saat içindeki tüm event'lerin ham listesi (debug/UI için).
    func recentEvents(windowHours: Double = 24) -> [HermesEvent] {
        let cutoff = Date().addingTimeInterval(-windowHours * 3600)
        lock.lock()
        defer { lock.unlock() }
        return cache.values
            .filter { $0.publishedAt >= cutoff }
            .sorted { $0.publishedAt > $1.publishedAt }
    }
}
