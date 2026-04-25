import Foundation

// Extension to GeminiNewsService

extension GeminiNewsService {

    /// Analyzes multiple articles and returns a weighted aggregate score (0-100).
    /// Uses Time Decay: Newer news matters more.
    func analyzeBatchSentiment(symbol: String, articles: [NewsArticle]) async -> Double {
        if articles.isEmpty { return 50.0 }
        
        let recentArticles = articles.sorted { $0.publishedAt > $1.publishedAt }.prefix(5) // Analyze top 5 most recent
        
        var totalWeight = 0.0
        var weightedScoreSum = 0.0
        
        for article in recentArticles {
            // Analyze (Parallelize in real app, serial for now)
            guard let insight = try? await analyzeNews(symbol: symbol, article: article) else { continue }
            
            // Time Decay
            let daysOld = Date().timeIntervalSince(article.publishedAt) / (24 * 3600)
            let timeWeight = max(0.1, 1.0 - (daysOld * 0.15)) // -15% per day
            
            // Confidence Weight
            let confWeight = insight.confidence
            
            let finalWeight = timeWeight * confWeight
            
            weightedScoreSum += (insight.impactScore * finalWeight)
            totalWeight += finalWeight
        }
        
        guard totalWeight > 0 else { return 50.0 }
        return weightedScoreSum / totalWeight
    }
    
    /// Scans General News and returns Tickers that look interesting for AutoPilot
    func scanGeneraNewsForOpportunities(articles: [NewsArticle]) async -> [String] {
        var candidates = Set<String>()
        
        for article in articles {
            // Quick check: If headline contains "Gain", "Jump", "Surge", "Deal"...
            // Or use Groq to extract tickers.
            
            // Let's use Groq analysis
            if let insight = try? await analyzeNews(symbol: "GENERAL", article: article) {
                if insight.impactScore > 70, let tickers = insight.relatedTickers {
                    for t in tickers {
                        candidates.insert(t)
                    }
                }
            }
        }
        return Array(candidates)
    }
}
