import Foundation

/// Merkezi Sağlayıcı Listesi (Single Source of Truth)
/// Sistemdeki tüm "Key Gerektiren" veya "API Tabanlı" servisler burada tanımlanır.
public enum ArgusProvider: String, CaseIterable, Codable, Sendable {
    // Market Data
    case twelveData = "TwelveData"
    case yahoo = "Yahoo" // Key gerektirmez ama izlenir
    case tiingo = "Tiingo"
    case fmp = "FMP" // Legacy/Disabled
    case alphaVantage = "AlphaVantage"
    case eodhd = "EODHD"
    case marketStack = "MarketStack" // Opsiyonel
    case coinApi = "CoinAPI"
    
    // Macro / Economics
    case fred = "FRED"
    
    // AI / Intelligence
    case groq = "Groq"
    case gemini = "Gemini"
    case openAI = "OpenAI"
    
    // Yardımcılar
    case unknown = "Unknown"
    
    /// Kullanıcı dostu ad
    var displayName: String {
        switch self {
        case .twelveData: return "Twelve Data"
        case .yahoo: return "Yahoo Finance"
        case .tiingo: return "Tiingo"
        case .fmp: return "FMP (Financial Modeling Prep)"
        case .alphaVantage: return "Alpha Vantage"
        case .eodhd: return "EODHD"
        case .marketStack: return "MarketStack"
        case .coinApi: return "CoinAPI"
        case .fred: return "FRED (St. Louis Fed)"
        case .groq: return "Groq AI"
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        case .unknown: return "Bilinmeyen"
        }
    }
    
    /// API Key gerektiriyor mu?
    var requiresKey: Bool {
        switch self {
        case .yahoo: return false // Public scraping / v8 API
        case .unknown: return false
        default: return true
        }
    }
}

/// Her bir API anahtarı için metadata (durum bilgisi)
public struct APIKeyMetadata: Codable, Sendable {
    public let provider: ArgusProvider
    public let lastUpdatedAt: Date
    public var lastValidatedAt: Date?
    public var isValid: Bool
    public var lastErrorCategory: String? // "403 Forbidden", "Quota Exceeded" vb.
    
    // UI için maskeli önizleme (Sadece son kullanıcıya göstermek için, debug bundle'a da bu girer)
    public let maskedPreview: String
    
    public init(provider: ArgusProvider, key: String, isValid: Bool = true) {
        self.provider = provider
        self.lastUpdatedAt = Date()
        self.isValid = isValid
        self.lastErrorCategory = nil
        
        // Maskeleme
        if key.count > 6 {
            let prefix = key.prefix(3)
            let suffix = key.suffix(3)
            self.maskedPreview = "\(prefix)...\(suffix)"
        } else {
            self.maskedPreview = "***"
        }
    }
}
