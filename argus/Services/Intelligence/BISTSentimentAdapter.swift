import Foundation

// MARK: - BIST Sentiment Adapter
// Converts BIST Sentiment Engine results to Hermes v2 Protocol

struct BISTSentimentAdapter {
    // Adapter içinde hafif, deterministic anahtar kelime seti.
    // Amaç: LLM yokken de "kulis" skorunun rasyonel davranması.
    private static let positiveKeywords: [String] = [
        "artış", "yükseliş", "büyüme", "kâr", "kar", "olumlu", "güçlü",
        "hedef yükseltti", "al tavsiyesi", "anlaşma", "ihale kazandı",
        "temettü", "yatırım", "ihracat", "kapasite artışı", "teşvik"
    ]
    
    private static let negativeKeywords: [String] = [
        "düşüş", "gerileme", "zarar", "olumsuz", "risk", "satış baskısı",
        "hedef düşürdü", "sat tavsiyesi", "ceza", "soruşturma", "dava",
        "ihale iptal", "borç", "kur şoku", "faiz artırımı", "yabancı çıkışı"
    ]
    
    /// BIST Sonucunu Hermes Protokolüne dönüştürür
    static func adapt(result: BISTSentimentResult, articles: [NewsArticle]) -> HermesNewsSnapshot {
        let now = Date()
        let normalizedSymbol = result.symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
        
        let sortedArticles = articles.sorted { $0.publishedAt > $1.publishedAt }
        let candidateArticles = Array(sortedArticles.prefix(20))
        
        var insights: [NewsInsight] = candidateArticles.map { article in
            buildInsight(
                article: article,
                result: result,
                normalizedSymbol: normalizedSymbol,
                now: now
            )
        }
        
        // Gürültülü veri durumunda düşük güvenli insight'ları ele.
        insights = insights.filter { $0.confidence >= 0.15 }
        
        if insights.isEmpty {
            insights = [fallbackInsight(result: result)]
        } else {
            insights = Array(insights.prefix(12))
        }
        
        return HermesNewsSnapshot(
            symbol: result.symbol,
            timestamp: result.lastUpdated,
            insights: insights,
            articles: articles
        )
    }
    
    private static func buildInsight(
        article: NewsArticle,
        result: BISTSentimentResult,
        normalizedSymbol: String,
        now: Date
    ) -> NewsInsight {
        let text = (article.headline + " " + (article.summary ?? "")).lowercased()
        
        let positiveHits = keywordHitCount(text: text, keywords: positiveKeywords)
        let negativeHits = keywordHitCount(text: text, keywords: negativeKeywords)
        
        // [0,1]
        let sourceReliability = min(max(article.sourceReliability, 0), 1)
        
        // 0h -> ~1.0, 24h+ -> ~0.35
        let ageHours = max(0, now.timeIntervalSince(article.publishedAt) / 3600.0)
        let freshness = max(0.35, exp(-ageHours / 18.0))
        
        let symbolToken = normalizedSymbol.lowercased()
        let symbolMentioned = text.contains(symbolToken)
        let symbolRelevance = symbolMentioned ? 1.0 : (result.isGeneralMarketSentiment ? 0.55 : 0.75)
        
        let signal: Double = {
            let totalHits = positiveHits + negativeHits
            if totalHits == 0 {
                // Ana score'u zayıf anchor olarak kullan.
                return clamp((result.overallScore - 50.0) / 50.0 * 0.35, min: -1, max: 1)
            }
            let raw = Double(positiveHits - negativeHits) / Double(max(totalHits, 1))
            return clamp(raw, min: -1, max: 1)
        }()
        
        let trendMultiplier: Double = {
            switch result.mentionTrend {
            case .increasing: return 1.08
            case .stable: return 1.0
            case .decreasing: return 0.94
            }
        }()
        
        // Coverage düşükse güven artmasın.
        let coverageFactor = clamp(Double(result.relevantNewsCount) / 8.0, min: 0.35, max: 1.0)
        let generalPenalty = result.isGeneralMarketSentiment ? 0.72 : 1.0
        
        var confidence = 0.15 + (sourceReliability * 0.45) + (freshness * 0.20) + (symbolRelevance * 0.20)
        confidence *= coverageFactor * generalPenalty
        confidence = clamp(confidence, min: 0.10, max: 0.95)
        
        var impactScore = 50.0
        impactScore += signal * 34.0
        impactScore += (sourceReliability - 0.5) * 24.0
        impactScore += (freshness - 0.5) * 18.0
        impactScore *= trendMultiplier
        impactScore = 50.0 + (impactScore - 50.0) * symbolRelevance
        
        // Genel piyasa fallback'i daha temkinli olsun.
        if result.isGeneralMarketSentiment {
            impactScore = 50.0 + (impactScore - 50.0) * 0.70
        }
        
        // Adaptör ile snapshot skorunu çok koparmayalım.
        impactScore = (impactScore * 0.70) + (result.overallScore * 0.30)
        impactScore = clamp(impactScore, min: 0, max: 100)
        
        let sentiment = sentimentFrom(score: impactScore)
        
        let impactSentence = impactSentence(
            sentiment: sentiment,
            sourceReliability: sourceReliability,
            freshness: freshness
        )
        
        let summary = """
        Kaynak: \(article.source). Haber etkisi \(Int(impactScore))/100.
        Güven: %\(Int(confidence * 100)) | Tazelik: %\(Int(freshness * 100)).
        Piyasa skoru anchor: \(Int(result.overallScore)).
        """
        
        return NewsInsight(
            symbol: result.symbol,
            articleId: article.id,
            headline: article.headline,
            summaryTRLong: summary,
            impactSentenceTR: impactSentence,
            sentiment: sentiment,
            confidence: confidence,
            impactScore: impactScore,
            createdAt: result.lastUpdated
        )
    }
    
    private static func fallbackInsight(result: BISTSentimentResult) -> NewsInsight {
        let sentiment = sentimentFrom(score: result.overallScore)
        let baseConfidence = result.isGeneralMarketSentiment ? 0.28 : 0.40
        
        return NewsInsight(
            symbol: result.symbol,
            articleId: "BIST_SENTIMENT_\(Int(result.lastUpdated.timeIntervalSince1970))",
            headline: "BIST Sentiment Raporu: \(result.symbol)",
            summaryTRLong: "BIST Sentiment Skoru: \(Int(result.overallScore)). Boğa oranı %\(Int(result.bullishPercent)), Ayı oranı %\(Int(result.bearishPercent)). Trend: \(result.mentionTrend.rawValue)",
            impactSentenceTR: result.keyHeadlines.first ?? "Yeterli sembol-haber eşleşmesi yok, kulis etkisi temkinli modda işlendi.",
            sentiment: sentiment,
            confidence: baseConfidence,
            impactScore: result.overallScore
        )
    }
    
    private static func impactSentence(sentiment: NewsSentiment, sourceReliability: Double, freshness: Double) -> String {
        let reliabilityText = sourceReliability >= 0.8 ? "yüksek kaynak güveni" : (sourceReliability >= 0.6 ? "orta kaynak güveni" : "düşük kaynak güveni")
        let freshnessText = freshness >= 0.75 ? "taze akış" : "gecikmeli akış"
        
        switch sentiment {
        case .strongPositive:
            return "Olumlu kulis baskın; \(reliabilityText), \(freshnessText)."
        case .weakPositive:
            return "Sınırlı olumlu sinyal; \(reliabilityText), \(freshnessText)."
        case .neutral:
            return "Haber tonu dengeli; \(reliabilityText), \(freshnessText)."
        case .weakNegative:
            return "Sınırlı olumsuz sinyal; \(reliabilityText), \(freshnessText)."
        case .strongNegative:
            return "Olumsuz kulis baskın; \(reliabilityText), \(freshnessText)."
        }
    }
    
    private static func sentimentFrom(score: Double) -> NewsSentiment {
        if score >= 65 { return .strongPositive }
        if score >= 55 { return .weakPositive }
        if score >= 45 { return .neutral }
        if score >= 35 { return .weakNegative }
        return .strongNegative
    }
    
    private static func keywordHitCount(text: String, keywords: [String]) -> Int {
        keywords.reduce(0) { partial, keyword in
            partial + (text.contains(keyword) ? 1 : 0)
        }
    }
    
    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}
