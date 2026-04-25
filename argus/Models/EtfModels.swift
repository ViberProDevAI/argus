import Foundation

// MARK: - ETF Check Logic
// "isETF" check will be handled in MarketDataProvider, likely via a mock or API "type" field.

// MARK: - ETF Holding
struct EtfHolding: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let weight: Double?   // percent, e.g. 7.5 for 7.5%
    let sector: String?
    let country: String?
}

struct EtfSectorWeight: Identifiable, Codable {
    var id: String { sector }
    let sector: String
    let weight: Double    // %
}

// MARK: - ETF Strategy Type
enum EtfStrategyType: String, Codable {
    case standard
    case leveragedLong // 2x, 3x Bull
    case leveragedShort // 1x, 2x, 3x Bear
    case active // Active managed (optional)
    
    var displayName: String {
        switch self {
        case .standard: return "Standart"
        case .leveragedLong: return "Kaldıraçlı (Long)"
        case .leveragedShort: return "Ters / Short"
        case .active: return "Aktif Yönetim"
        }
    }
}

// MARK: - Argus ETF Summary
struct ArgusEtfSummary: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let lastPrice: Double?
    let currency: String?
    
    // Strategy Info
    let strategyType: EtfStrategyType
    let leverageAmount: String? // e.g. "3x", "2x", "-1x"

    // ETF Basket Quality (The Brain)
    let weightedAtlasScore: Double?     // 0-100
    let weightedHermesScore: Double?    // 0-100

    // Technical View (The Chart)
    let orionScore: Double?             // 0-100
    let orionLetterGrade: String?       // A+, B, etc.

    // Final Grade & Profile
    let riskProfile: String             // "Agresif", "Dengeli", "Defansif"

    // Sector Distribution
    let topSectors: [EtfSectorWeight]

    // Top Holdings (Enriched)
    struct HoldingPreview: Identifiable, Codable {
        let id: UUID
        let symbol: String
        let weight: Double?
        let atlasScore: Double?
        let miniComment: String?
    }
    let topHoldingsPreview: [HoldingPreview]

    // Narrative
    let summaryText: String
}
