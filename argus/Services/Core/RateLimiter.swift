import Foundation

/// RateLimiter: API isteklerini sınırlayan actor.
/// Yahoo Finance ve diğer API'lerin rate limit aşımını önler.
/// Her istek arasında minimum bekleme süresi uygular.
actor RateLimiter {
    
    // MARK: - Singleton
    static let shared = RateLimiter()
    
    // MARK: - Configuration
    // 🔧 DENGELENMIŞ AYARLAR - Network timeout'ları önlemek için
    private let minInterval: TimeInterval = 0.1  // 100ms = 10 req/sec max
    private var lastRequestTime: Date = .distantPast
    private var requestCount: Int = 0
    private var windowStart: Date = Date()
    private let maxRequestsPerMinute: Int = 300  // Çok daha yüksek limit
    
    private init() {}
    
    // MARK: - Public API
    
    /// İstek yapmadan önce bu fonksiyonu çağır.
    /// Paralel istek flood'unu önlemek için minimum bekleme uygular.
    func waitIfNeeded() async {
        // Sadece minimum interval - dakikalık limit yok
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            let waitTime = minInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    /// Mevcut rate limit durumunu döndürür
    var status: String {
        return "Requests: \(requestCount)/\(maxRequestsPerMinute) per minute"
    }
    
    /// Rate limiter'ı sıfırla (test için)
    func reset() {
        lastRequestTime = .distantPast
        requestCount = 0
        windowStart = Date()
    }
}
