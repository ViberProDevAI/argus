import Foundation

// MARK: - BIST Sentiment Adapter
// Converts BIST Sentiment Engine results to Hermes v2 Protocol

struct BISTSentimentAdapter {
    
    /// BIST Sonucunu Hermes Protokolüne dönüştürür
    static func adapt(result: BISTSentimentResult) -> HermesNewsSnapshot {
        // 1. Convert Score to Sentiment Enum
        let sentiment: NewsSentiment
        if result.overallScore >= 65 { sentiment = .strongPositive }
        else if result.overallScore >= 55 { sentiment = .weakPositive }
        else if result.overallScore >= 45 { sentiment = .neutral }
        else if result.overallScore >= 35 { sentiment = .weakNegative }
        else { sentiment = .strongNegative }
        
        // 2. Create Insight
        let insight = NewsInsight(
            symbol: result.symbol,
            articleId: "BIST_SENTIMENT_\(Int(result.lastUpdated.timeIntervalSince1970))",
            headline: "BIST Sentiment Raporu: \(result.symbol)",
            summaryTRLong: "BIST Sentiment Skoru: \(Int(result.overallScore)). Boğa oranı %\(Int(result.bullishPercent)), Ayı oranı %\(Int(result.bearishPercent)). Trend: \(result.mentionTrend.rawValue)",
            impactSentenceTR: result.keyHeadlines.first ?? "Piyasa verileri analiz edildi.",
            sentiment: sentiment,
            confidence: Double(result.relevantNewsCount) / Double(max(1, result.newsVolume)),
            impactScore: result.mentionTrend == .increasing ? 80.0 : 50.0
        )
        
        // 3. Create Dummy Articles (Hermes expects articles, but we have aggregated result)
        // We wrap headlines as minimal articles
        let articles = result.keyHeadlines.map { headline in
            NewsArticle(
                id: UUID().uuidString,
                symbol: result.symbol,
                source: "BIST Feed",
                headline: headline,
                summary: "BIST Sentiment Engine tarafından derlendi.",
                url: "",
                publishedAt: result.lastUpdated,
                fetchedAt: result.lastUpdated
            )
        }
        
        return HermesNewsSnapshot(
            symbol: result.symbol,
            timestamp: result.lastUpdated,
            insights: [insight],
            articles: articles
        )
    }
}
