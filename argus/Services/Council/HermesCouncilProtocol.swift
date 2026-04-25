import Foundation

// MARK: - Hermes Council Protocol & Models
// The News Council - evaluates news and sentiment impact
// Uses existing NewsArticle and NewsSentiment from NewsModels.swift

// MARK: - News Council Member Protocol

protocol NewsCouncilMember: Sendable {
    var id: String { get }
    var name: String { get }
    
    func analyze(news: HermesNewsSnapshot, symbol: String) async -> HermesNewsProposal?
    func vote(on proposal: HermesNewsProposal, news: HermesNewsSnapshot) -> HermesNewsVote
}

// MARK: - Hermes News Snapshot (Input Data)

struct HermesNewsSnapshot: Sendable, Codable {
    let symbol: String
    let timestamp: Date
    
    // News insights (analyzed)
    let insights: [NewsInsight]
    
    // Raw articles
    let articles: [NewsArticle]
    
    // Aggregated sentiment
    var aggregatedSentiment: Double? {
        guard !insights.isEmpty else { return nil }
        var sum = 0.0
        for insight in insights {
            switch insight.sentiment {
            case .strongPositive: sum += 1.0
            case .weakPositive: sum += 0.5
            case .neutral: sum += 0.0
            case .weakNegative: sum -= 0.5
            case .strongNegative: sum -= 1.0
            }
        }
        return sum / Double(insights.count)
    }
    
    var avgConfidence: Double {
        guard !insights.isEmpty else { return 0 }
        return insights.map { $0.confidence }.reduce(0, +) / Double(insights.count)
    }
    
    // Catalyst detection from headlines
    var hasUpgrade: Bool {
        articles.contains { $0.headline.lowercased().contains("upgrade") || $0.headline.contains("yükselt") }
    }
    
    var hasDowngrade: Bool {
        articles.contains { $0.headline.lowercased().contains("downgrade") || $0.headline.contains("düşür") }
    }
    
    var hasDividendAnnouncement: Bool {
        articles.contains { $0.headline.lowercased().contains("dividend") || $0.headline.contains("temettü") }
    }
    
    var hasEarnings: Bool {
        articles.contains { $0.headline.lowercased().contains("earnings") || $0.headline.contains("kazanç") }
    }
    
    var hasMergersAcquisitions: Bool {
        articles.contains { 
            $0.headline.lowercased().contains("merger") || 
            $0.headline.lowercased().contains("acquisition") ||
            $0.headline.contains("birleşme") || 
            $0.headline.contains("satın al")
        }
    }
    
    static func empty(symbol: String) -> HermesNewsSnapshot {
        HermesNewsSnapshot(symbol: symbol, timestamp: Date(), insights: [], articles: [])
    }
}

// MARK: - Hermes News Proposal

struct HermesNewsProposal: Sendable, Identifiable, Codable {
    let id = UUID()
    let proposer: String
    let proposerName: String
    let sentiment: NewsSentiment
    let confidence: Double
    let reasoning: String
    let keyHeadline: String?
    let timestamp: Date = Date()
    
    var actionBias: ProposedAction {
        switch sentiment {
        case .strongPositive, .weakPositive: return .buy
        case .neutral: return .hold
        case .weakNegative, .strongNegative: return .sell
        }
    }
}

// MARK: - Hermes News Vote

struct HermesNewsVote: Sendable, Codable {
    let voter: String
    let voterName: String
    let decision: VoteDecision
    let reasoning: String?
    let weight: Double
}

// MARK: - Hermes Decision

struct HermesDecision: Sendable, Codable {
    let symbol: String
    let sentiment: NewsSentiment
    let actionBias: ProposedAction
    let netSupport: Double
    let isHighImpact: Bool
    let winningProposal: HermesNewsProposal?
    let votes: [HermesNewsVote]
    let keyHeadlines: [String]
    let catalysts: [String]
    let timestamp: Date
    
    var summary: String {
        "\(symbol) Haber: \(sentiment.rawValue) | Etki: \(isHighImpact ? "YÜKSEK" : "NORMAL")"
    }
}

// MARK: - Hermes Member Weights

struct HermesMemberWeights: Codable, Sendable {
    var sentimentMaster: Double
    var impactMaster: Double
    var timingMaster: Double
    var credibilityMaster: Double
    var catalystMaster: Double
    var updatedAt: Date
    var confidence: Double
    
    static let defaultWeights = HermesMemberWeights(
        sentimentMaster: 0.25,
        impactMaster: 0.25,
        timingMaster: 0.15,
        credibilityMaster: 0.15,
        catalystMaster: 0.20,
        updatedAt: Date(),
        confidence: 0.5
    )
    
    func weight(for memberId: String) -> Double {
        switch memberId {
        case "hermes_sentiment_master": return sentimentMaster
        case "hermes_impact_master": return impactMaster
        case "hermes_timing_master": return timingMaster
        case "hermes_credibility_master": return credibilityMaster
        case "hermes_catalyst_master": return catalystMaster
        default: return 0.1
        }
    }
}
