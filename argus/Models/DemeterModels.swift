import Foundation

// MARK: - Sector ETF Definition
enum SectorETF: String, CaseIterable, Codable, Sendable, Identifiable {
    case XLC = "XLC" // Communication Services
    case XLY = "XLY" // Consumer Discretionary
    case XLP = "XLP" // Consumer Staples
    case XLE = "XLE" // Energy
    case XLF = "XLF" // Financials
    case XLV = "XLV" // Health Care
    case XLI = "XLI" // Industrials
    case XLB = "XLB" // Materials
    case XLRE = "XLRE" // Real Estate
    case XLK = "XLK" // Technology
    case XLU = "XLU" // Utilities
    
    var id: String { rawValue }
    
    nonisolated var name: String {
        switch self {
        case .XLC: return "İletişim Hizmetleri"
        case .XLY: return "Tüketici (İsteğe Bağlı)"
        case .XLP: return "Tüketici (Temel)"
        case .XLE: return "Enerji"
        case .XLF: return "Finans"
        case .XLV: return "Sağlık"
        case .XLI: return "Sanayi"
        case .XLB: return "Malzeme/Emtia"
        case .XLRE: return "Gayrimenkul"
        case .XLK: return "Teknoloji"
        case .XLU: return "Altyapı (Utilities)"
        }
    }
}

// MARK: - Shock Definitions
enum ShockType: String, Codable, Sendable, CaseIterable {
    case energy = "ENERGY"
    case rates = "RATES"
    case dollar = "DOLLAR"
    case vol = "VOLATILITY"
    case credit = "CREDIT"     // Placeholder
    case liquidity = "LIQUIDITY" // Placeholder
    
    nonisolated var displayName: String {
        switch self {
        case .energy: return "Enerji Şoku"
        case .rates: return "Faiz Şoku"
        case .dollar: return "Dolar Baskısı"
        case .vol: return "Volatilite (Korku)"
        case .credit: return "Kredi Stresi"
        case .liquidity: return "Likidite Krizi"
        }
    }
}

enum ShockDirection: String, Codable, Sendable {
    case positive = "POSITIVE" // Yükseliş Şoku (Örn: Petrol Fırladı)
    case negative = "NEGATIVE" // Düşüş Şoku (Örn: Petrol Çakıldı)
    
    nonisolated var symbol: String {
        return self == .positive ? "↑" : "↓"
    }
}

struct ShockFlag: Identifiable, Codable, Sendable {
    var id: String { "\(type.rawValue)_\(direction.rawValue)" }
    let type: ShockType
    let direction: ShockDirection
    let severity: Double // 0-100 (Şiddet)
    let description: String // "30 günde +%25"
    let detectedAt: Date
}

// MARK: - Demeter Final Score
struct DemeterScore: Identifiable, Codable, Sendable {
    var id: String { sector.rawValue }
    let sector: SectorETF
    
    // Core Score (0-100)
    let totalScore: Double
    
    // Components
    let momentumScore: Double // 35p
    let shockImpactScore: Double // 25p (Net Impact)
    let regimeScore: Double // 20p
    let breadthScore: Double // 20p
    
    // Context
    let activeShocks: [ShockFlag]
    let driverContributions: [String: Double] // "Petrol": +15.0
    
    // Meta
    let confidence: Double // 0.0 - 1.0 (Data Freshness)
    let advice: String // "Dikkatli İzle"
    let generatedAt: Date
    
    nonisolated var grade: String {
        if totalScore >= 75 { return "Güçlü" }
        else if totalScore >= 45 { return "Nötr" }
        else { return "Zayıf" }
    }
    
    nonisolated var colorName: String {
        if totalScore >= 75 { return "Green" }
        else if totalScore >= 45 { return "Yellow" }
        else { return "Red" }
    }
}

// MARK: - Correlation Matrix (Can stay simple)
struct CorrelationMatrix: Codable, Sendable {
    let pairs: [String: Double]
    let date: Date
    
    func getCorrelation(_ a: SectorETF, _ b: SectorETF) -> Double {
        if a == b { return 1.0 }
        let key1 = "\(a.rawValue)_\(b.rawValue)"
        let key2 = "\(b.rawValue)_\(a.rawValue)"
        return pairs[key1] ?? pairs[key2] ?? 0.0
    }
}
