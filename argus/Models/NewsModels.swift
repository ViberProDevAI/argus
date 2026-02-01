import Foundation

// MARK: - 1.1 NewsArticle
struct NewsArticle: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let symbol: String
    let source: String
    let headline: String
    let summary: String?
    let url: String?
    let publishedAt: Date
    let fetchedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, source, headline, summary, url, publishedAt, fetchedAt
    }
    
    // Hermes v2.0: Source Reliability Score (0.0 - 1.0)
    var sourceReliability: Double {
        return NewsArticle.calculateReliability(for: source)
    }
    
    static func calculateReliability(for source: String) -> Double {
        let s = source.lowercased()
        if s.contains("kap") || s.contains("kamuyu aydinlatma") || s.contains("kamu aydinlatma") || s.contains("borsa istanbul") || s.contains("spk") {
            return 0.95 // Resmi BIST/KAP kaynaklari
        }
        if s.contains("bloomberg") || s.contains("reuters") || s.contains("wsj") || s.contains("dj") || s.contains("dow jones") {
            return 1.0 // Tier 1 (Gold)
        }
        if s.contains("cnbc") || s.contains("financial times") || s.contains("marketwatch") || s.contains("yahoo") {
            return 0.8 // Tier 2 (Silver)
        }
        if s.contains("analyst") || s.contains("benzinga") || s.contains("seeking alpha") {
            return 0.6 // Tier 3 (Bronze)
        }
        if s.contains("kulis") || s.contains("forum") || s.contains("telegram") {
            return 0.4 // Kulis/sosyal kaynaklar
        }
        if s.contains("reddit") || s.contains("twitter") || s.contains("social") {
            return 0.3 // Tier 4 (Social/Noise)
        }
        return 0.5 // Default (Unknown)
    }
}

// MARK: - 1.2 NewsSentiment
enum NewsSentiment: String, Codable, CaseIterable, Sendable {
    case strongPositive = "strong_positive"
    case weakPositive = "weak_positive"
    case neutral = "neutral"
    case weakNegative = "weak_negative"
    case strongNegative = "strong_negative"
    
    var displayTitle: String {
        switch self {
        case .strongPositive: return "Çok Olumlu"
        case .weakPositive: return "Olumlu"
        case .neutral: return "Nötr"
        case .weakNegative: return "Olumsuz"
        case .strongNegative: return "Çok Olumsuz"
        }
    }
    
    var emoji: String {
        switch self {
        case .strongPositive: return ""
        case .weakPositive: return ""
        case .neutral: return ""
        case .weakNegative: return ""
        case .strongNegative: return ""
        }
    }
    
    var colorName: String {
        switch self {
        case .strongPositive: return "Green"
        case .weakPositive: return "Mint" // Veya Blue
        case .neutral: return "Gray"
        case .weakNegative: return "Orange"
        case .strongNegative: return "Red"
        }
    }
}

// MARK: - 1.3 NewsInsight
struct NewsInsight: Identifiable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let articleId: String
    let headline: String
    
    let summaryTRLong: String    // 2–3 cümlelik Türkçe açıklama
    let impactSentenceTR: String // 1 cümlelik Türkçe “etki özeti”
    
    let sentiment: NewsSentiment
    let confidence: Double       // 0.0 – 1.0 arası güven skoru
    let impactScore: Double // New field (0-100)
    
    let relatedTickers: [String]? // Sembol keşfi için
    
    let createdAt: Date
    
    // Custom Codable to handle missing fields from LLM
    enum CodingKeys: String, CodingKey {
        case id, symbol, articleId, headline, summaryTRLong, impactSentenceTR, sentiment, confidence, impactScore, relatedTickers, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.articleId = try container.decodeIfPresent(String.self, forKey: .articleId) ?? "AI_GEN_\(UUID().uuidString.prefix(8))"
        self.headline = try container.decode(String.self, forKey: .headline)
        self.summaryTRLong = try container.decode(String.self, forKey: .summaryTRLong)
        self.impactSentenceTR = try container.decode(String.self, forKey: .impactSentenceTR)
        self.sentiment = try container.decode(NewsSentiment.self, forKey: .sentiment)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.impactScore = try container.decode(Double.self, forKey: .impactScore)
        self.relatedTickers = try container.decodeIfPresent([String].self, forKey: .relatedTickers)
        
        // Handle optional ID or Generate
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            self.id = decodedId
        } else {
            self.id = UUID()
        }
        
        // Handle optional createdAt or Default
        if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
    }
    
    // Memberwise init for manual creation
    init(id: UUID = UUID(), symbol: String, articleId: String, headline: String, summaryTRLong: String, impactSentenceTR: String, sentiment: NewsSentiment, confidence: Double, impactScore: Double, relatedTickers: [String]? = nil, createdAt: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.articleId = articleId
        self.headline = headline
        self.summaryTRLong = summaryTRLong
        self.impactSentenceTR = impactSentenceTR
        self.sentiment = sentiment
        self.confidence = confidence
        self.impactScore = impactScore
        self.relatedTickers = relatedTickers
        self.createdAt = createdAt
    }
    
    // Sorting helper
    static func < (lhs: NewsInsight, rhs: NewsInsight) -> Bool {
        return lhs.createdAt < rhs.createdAt
    }
}
