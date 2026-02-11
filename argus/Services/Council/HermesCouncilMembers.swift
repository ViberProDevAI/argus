import Foundation

// MARK: - Hermes Sentiment Master
struct HermesSentimentMasterEngine: NewsCouncilMember, Sendable {
    let id = "hermes_sentiment_master"
    let name = "Duygu Analisti"
    
    nonisolated init() {}
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal? {
        guard let sentiment = news.aggregatedSentiment, news.avgConfidence >= 0.5 else { return nil }
        
        var proposedSentiment: NewsSentiment = .neutral
        var reasoning = ""
        
        if sentiment > 0.6 {
            proposedSentiment = .strongPositive
            reasoning = "Çok güçlü pozitif haber akışı (Duygu: \(String(format: "%.0f", sentiment * 100))%)"
        } else if sentiment > 0.3 {
            proposedSentiment = .weakPositive
            reasoning = "Pozitif haber akışı (Duygu: \(String(format: "%.0f", sentiment * 100))%)"
        } else if sentiment < -0.6 {
            proposedSentiment = .strongNegative
            reasoning = "Çok güçlü negatif haber akışı (Duygu: \(String(format: "%.0f", sentiment * 100))%)"
        } else if sentiment < -0.3 {
            proposedSentiment = .weakNegative
            reasoning = "Negatif haber akışı (Duygu: \(String(format: "%.0f", sentiment * 100))%)"
        } else {
            return nil
        }
        
        let keyHeadline = news.articles.first?.headline
        
        return HermesNewsProposal(
            proposer: id,
            proposerName: name,
            sentiment: proposedSentiment,
            confidence: news.avgConfidence,
            reasoning: reasoning,
            keyHeadline: keyHeadline
        )
    }
    
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote {
        guard let sentiment = news.aggregatedSentiment else {
            return HermesNewsVote(voter: id, voterName: name, decision: .abstain, reasoning: "Veri yok", weight: 0)
        }
        
        let isPositive = proposal.sentiment == .weakPositive || proposal.sentiment == .strongPositive
        let isNegative = proposal.sentiment == .weakNegative || proposal.sentiment == .strongNegative
        
        if isPositive && sentiment < -0.3 {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Duygu negatif", weight: 0.9)
        }
        if isNegative && sentiment > 0.3 {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Duygu pozitif", weight: 0.9)
        }
        
        return HermesNewsVote(voter: id, voterName: name, decision: .approve, reasoning: "Duygu uyumlu", weight: 0.8)
    }
}

// MARK: - Impact Master
struct HermesImpactMasterEngine: NewsCouncilMember, Sendable {
    let id = "hermes_impact_master"
    let name = "Etki Analisti"
    
    nonisolated init() {}
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal? {
        let highImpactInsights = news.insights.filter { $0.impactScore > 70 }
        guard !highImpactInsights.isEmpty else { return nil }
        
        let avgSentimentScore = news.aggregatedSentiment ?? 0
        let maxImpact = highImpactInsights.map { $0.impactScore }.max() ?? 0
        
        var sentiment: NewsSentiment = .neutral
        var reasoning = "\(highImpactInsights.count) yüksek etkili haber tespit edildi"
        
        if avgSentimentScore > 0.3 {
            sentiment = maxImpact > 80 ? .strongPositive : .weakPositive
            reasoning += " - Pozitif potansiyel"
        } else if avgSentimentScore < -0.3 {
            sentiment = maxImpact > 80 ? .strongNegative : .weakNegative
            reasoning += " - Negatif potansiyel"
        } else {
            return nil
        }
        
        return HermesNewsProposal(
            proposer: id,
            proposerName: name,
            sentiment: sentiment,
            confidence: maxImpact / 100.0,
            reasoning: reasoning,
            keyHeadline: highImpactInsights.first?.headline
        )
    }
    
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote {
        let hasHighImpact = news.insights.contains { $0.impactScore > 70 }
        
        if hasHighImpact {
            return HermesNewsVote(voter: id, voterName: name, decision: .approve, reasoning: "Yüksek etki destekliyor", weight: 1.0)
        }
        
        return HermesNewsVote(voter: id, voterName: name, decision: .abstain, reasoning: "Etki orta", weight: 0.5)
    }
}

// MARK: - Timing Master
struct HermesTimingMasterEngine: NewsCouncilMember, Sendable {
    let id = "hermes_timing_master"
    let name = "Zamanlama Analisti"
    
    nonisolated init() {}
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal? {
        let now = Date()
        let recentArticles = news.articles.filter {
            now.timeIntervalSince($0.publishedAt) < 3600 // Son 1 saat
        }
        
        guard !recentArticles.isEmpty else { return nil }
        
        // Get sentiment from recent insights
        let recentInsights = news.insights.filter {
            now.timeIntervalSince($0.createdAt) < 3600
        }
        
        guard !recentInsights.isEmpty else { return nil }
        
        var sum = 0.0
        for insight in recentInsights {
            switch insight.sentiment {
            case .strongPositive: sum += 1.0
            case .weakPositive: sum += 0.5
            case .neutral: sum += 0.0
            case .weakNegative: sum -= 0.5
            case .strongNegative: sum -= 1.0
            }
        }
        let avgSentiment = sum / Double(recentInsights.count)
        
        var sentiment: NewsSentiment = .neutral
        var reasoning = "\(recentArticles.count) taze haber (son 1 saat)"
        
        if avgSentiment > 0.3 {
            sentiment = .weakPositive
            reasoning += " - Pozitif trend"
        } else if avgSentiment < -0.3 {
            sentiment = .weakNegative
            reasoning += " - Negatif trend"
        } else {
            return nil
        }
        
        return HermesNewsProposal(
            proposer: id,
            proposerName: name,
            sentiment: sentiment,
            confidence: 0.70,
            reasoning: reasoning,
            keyHeadline: recentArticles.first?.headline
        )
    }
    
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote {
        let now = Date()
        let veryFreshNews = news.articles.filter {
            now.timeIntervalSince($0.publishedAt) < 1800 // Son 30 dk
        }
        
        let isStrong = proposal.sentiment == .strongPositive || proposal.sentiment == .strongNegative
        
        if veryFreshNews.isEmpty && isStrong {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Taze haber yok", weight: 0.7)
        }
        
        return HermesNewsVote(voter: id, voterName: name, decision: .abstain, reasoning: "Zamanlama uygun", weight: 0.5)
    }
}

// MARK: - Credibility Master
struct HermesCredibilityMasterEngine: NewsCouncilMember, Sendable {
    let id = "hermes_credibility_master"
    let name = "Güvenilirlik Analisti"
    
    nonisolated init() {}
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal? {
        let trustedArticles = news.articles.filter { $0.sourceReliability >= 0.8 }
        
        guard !trustedArticles.isEmpty else { return nil }
        
        // Get corresponding insights
        let trustedInsights = news.insights.filter { insight in
            trustedArticles.contains { $0.id == insight.articleId }
        }
        
        guard !trustedInsights.isEmpty else { return nil }
        
        var sum = 0.0
        for insight in trustedInsights {
            switch insight.sentiment {
            case .strongPositive: sum += 1.0
            case .weakPositive: sum += 0.5
            case .neutral: sum += 0.0
            case .weakNegative: sum -= 0.5
            case .strongNegative: sum -= 1.0
            }
        }
        let avgSentiment = sum / Double(trustedInsights.count)
        
        var sentiment: NewsSentiment = .neutral
        var reasoning = "\(trustedArticles.count) güvenilir kaynaktan haber"
        
        if avgSentiment > 0.3 {
            sentiment = .weakPositive
            reasoning += " - Pozitif"
        } else if avgSentiment < -0.3 {
            sentiment = .weakNegative
            reasoning += " - Negatif"
        } else {
            return nil
        }
        
        return HermesNewsProposal(
            proposer: id,
            proposerName: name,
            sentiment: sentiment,
            confidence: 0.85,
            reasoning: reasoning,
            keyHeadline: trustedArticles.first?.headline
        )
    }
    
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote {
        let trustedCount = news.articles.filter { $0.sourceReliability >= 0.8 }.count
        
        if trustedCount == 0 && proposal.confidence > 0.7 {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Güvenilir kaynak yok", weight: 0.8)
        }
        
        return HermesNewsVote(voter: id, voterName: name, decision: .abstain, reasoning: "Kaynaklar orta", weight: 0.5)
    }
}

// MARK: - Catalyst Master
struct HermesCatalystMasterEngine: NewsCouncilMember, Sendable {
    let id = "hermes_catalyst_master"
    let name = "Katalizör Analisti"
    
    nonisolated init() {}
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal? {
        var catalysts: [String] = []
        var sentiment: NewsSentiment = .neutral
        var confidence = 0.0
        
        if news.hasUpgrade {
            catalysts.append("⬆️ Analist yükseltmesi")
            sentiment = .weakPositive
            confidence = max(confidence, 0.80)
        }
        
        if news.hasDowngrade {
            catalysts.append("⬇️ Analist düşürmesi")
            sentiment = .weakNegative
            confidence = max(confidence, 0.80)
        }
        
        if news.hasDividendAnnouncement {
            catalysts.append("💰 Temettü açıklaması")
            if sentiment == .neutral { sentiment = .weakPositive }
            confidence = max(confidence, 0.75)
        }
        
        if news.hasMergersAcquisitions {
            catalysts.append("🤝 M&A haberi")
            confidence = max(confidence, 0.85)
        }
        
        if news.hasEarnings {
            catalysts.append("📊 Kazanç raporu")
            confidence = max(confidence, 0.70)
        }
        
        guard !catalysts.isEmpty && confidence >= 0.70 else { return nil }
        
        let reasoning = "Katalizörler: " + catalysts.joined(separator: ", ")
        
        return HermesNewsProposal(
            proposer: id,
            proposerName: name,
            sentiment: sentiment,
            confidence: confidence,
            reasoning: reasoning,
            keyHeadline: nil
        )
    }
    
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote {
        let isPositive = proposal.sentiment == .weakPositive || proposal.sentiment == .strongPositive
        let isNegative = proposal.sentiment == .weakNegative || proposal.sentiment == .strongNegative
        
        if news.hasDowngrade && isPositive {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Analist düşürmesi var", weight: 0.9)
        }
        
        if news.hasUpgrade && isNegative {
            return HermesNewsVote(voter: id, voterName: name, decision: .veto, reasoning: "Analist yükseltmesi var", weight: 0.9)
        }
        
        if news.hasUpgrade || news.hasDividendAnnouncement {
            return HermesNewsVote(voter: id, voterName: name, decision: .approve, reasoning: "Pozitif katalizör", weight: 0.8)
        }
        
        return HermesNewsVote(voter: id, voterName: name, decision: .abstain, reasoning: "Katalizör nötr", weight: 0.5)
    }
}
