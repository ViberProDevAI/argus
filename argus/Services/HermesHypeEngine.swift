import Foundation

// MARK: - Hermes Hype Meter (v2.0)
/// Tracks the velocity of news to detect viral trends ("Hype").
final class HermesHypeEngine: Sendable {
    static let shared = HermesHypeEngine()
    
    // Storage: Symbol -> List of Timestamps
    private let queue = DispatchQueue(label: "com.argus.hermes.hype", attributes: .concurrent)
    private var newsTimestamps: [String: [Date]] = [:]
    
    // Constants
    private let windowSeconds: TimeInterval = 3600 * 4 // 4 Hours lookback
    private let hypeThreshold: Int = 5 // Minimum articles in window to consider hype
    
    private init() {}
    
    /// Ingest a new article to update velocity stats
    func track(article: NewsArticle) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var timestamps = self.newsTimestamps[article.symbol] ?? []
            timestamps.append(article.publishedAt)
            
            // Cleanup old
            let cutoff = Date().addingTimeInterval(-self.windowSeconds)
            timestamps = timestamps.filter { $0 > cutoff }
            
            self.newsTimestamps[article.symbol] = timestamps
        }
    }
    
    /// Returns a Hype Score (0-100) based on news velocity
    func getHypeScore(symbol: String) -> Double {
        queue.sync {
            guard let timestamps = newsTimestamps[symbol] else { return 0.0 }
            
            // Count recent articles (Last 4 hours)
            let count = timestamps.count
            
            if count <= 2 { return 0.0 } // Cold
            
            // Simple Linear Scaling
            // 3 articles -> 20
            // 5 articles -> 50 (Hype Start)
            // 10 articles -> 100 (Viral)
            
            // Formula: (Count / 10) * 100
            let score = (Double(count) / 10.0) * 100.0
            
            return min(score, 100.0)
        }
    }
    
    /// Returns true if the stock is currently "Viral"
    func isViral(symbol: String) -> Bool {
        return getHypeScore(symbol: symbol) > 75.0
    }
}
