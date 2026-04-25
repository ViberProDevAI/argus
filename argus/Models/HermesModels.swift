import Foundation

// MARK: - Hermes Models

/// The mode in which Hermes is currently operating.
enum HermesMode: String, Codable {
    case full = "Full (AI)"
    case lite = "Lite (Offline)"
}

/// A processed summary of a news article, either from AI or Lite mode.
struct HermesSummary: Identifiable, Codable {
    let id: String // same as articleId
    let symbol: String
    
    // Content
    let summaryTR: String        // Türkçe özet
    let impactCommentTR: String  // Türkçe etki yorumu
    let impactScore: Int         // 0-100
    
    // Hermes v2.0 Context
    var relatedSectors: [String]? // e.g. ["Aviation", "Energy"]
    var rippleEffectScore: Int?   // 0-100 Impact on market/sectors
    
    // Metadata
    let createdAt: Date
    let mode: HermesMode
    
    // P2: Weighted Average Support
    var publishedAt: Date?
    var sourceReliability: Double? // 0.0 - 1.0
    
    // Computed helper for Color
    var impactColor: String {
        switch impactScore {
        case 80...100: return "Green"
        case 60..<80: return "Blue"
        case 40..<60: return "Gray"
        case 20..<40: return "Orange"
        default: return "Red"
        }
    }
}

/// DTO for Batch Gemini Response
struct HermesBatchResponse: Codable {
    let results: [HermesBatchItem]
}

struct HermesBatchItem: Codable {
    let id: String // Article ID to map back
    let detected_symbol: String? // v2.3: LLM'in tespit ettiği sembol (Global feed için)
    let summary_tr: String
    let impact_comment_tr: String
    let sentiment: String? // Added for validation (v2.2)
    let impact_score: Double
    let related_sectors: [String]
    let ripple_effect_score: Double
}

enum HermesError: Error {
    case quotaExhausted
    case apiError(Int)
    case parsingError
}

// MARK: - Hermes V2: Quick Sentiment (Finnhub Powered)

/// Quick sentiment result from Finnhub API (no LLM required)
struct HermesQuickSentiment {
    let symbol: String
    let score: Double           // 0-100 (50 = neutral)
    let bullishPercent: Double  // 0-100
    let bearishPercent: Double  // 0-100
    let newsCount: Int
    let source: SentimentSource
    let lastUpdated: Date
    
    enum SentimentSource {
        case finnhub
        case llm
        case fallback
    }
    
    /// Sentiment interpretation
    var interpretation: String {
        switch score {
        case 70...100: return "Çok Olumlu"
        case 55..<70: return "Olumlu"
        case 45..<55: return "Nötr"
        case 30..<45: return "Olumsuz"
        default: return "Çok Olumsuz"
        }
    }
    
    /// Color for UI
    var colorName: String {
        switch score {
        case 70...100: return "green"
        case 55..<70: return "blue"
        case 45..<55: return "gray"
        case 30..<45: return "orange"
        default: return "red"
        }
    }
}

