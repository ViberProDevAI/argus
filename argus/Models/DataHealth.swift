import Foundation

/// Pillar 1: Data Health System (v2 - Component Based)
/// Tracks the completeness and quality of data for a given symbol using granular components.
struct DataHealth: Codable, Equatable {
    let symbol: String
    var lastUpdated: Date
    
    // Components
    var fundamental: CoverageComponent
    var technical: CoverageComponent
    var macro: CoverageComponent
    var news: CoverageComponent
    
    init(symbol: String, lastUpdated: Date = Date(), fundamental: CoverageComponent = .missing, technical: CoverageComponent = .missing, macro: CoverageComponent = .missing, news: CoverageComponent = .missing) {
        self.symbol = symbol
        self.lastUpdated = lastUpdated
        self.fundamental = fundamental
        self.technical = technical
        self.macro = macro
        self.news = news
    }
    
    /// Score from 0 to 100 based on weighted component coverage
    var qualityScore: Int {
        // Simple equal weight for now, or prioritize Technical for Algo
        let fundScore = fundamental.available ? (fundamental.quality * 25) : 0
        let techScore = technical.available ? (technical.quality * 25) : 0
        let macroScore = macro.available ? (macro.quality * 25) : 0
        let newsScore = news.available ? (news.quality * 25) : 0
        
        
        return Int(fundScore + techScore + macroScore + newsScore)
    }
    
    /// Is this symbol safe for Auto-Pilot trading?
    var isSafeForTrading: Bool {
        // Technical is mandatory.
        guard technical.available else { return false }
        
        // Quality threshold
        return qualityScore >= 50
    }
    
    /// Human readable status
    var localizedStatus: String {
        switch qualityScore {
        case 80...100: return "Mükemmel"
        case 60..<80: return "Yeterli"
        case 40..<60: return "Eksik"
        default: return "Yetersiz"
        }
    }
    
    // MARK: - Backward Compatibility
    var hasQuotes: Bool { technical.available }
    var hasIntraday: Bool { technical.available && technical.quality > 0.5 }
    var hasFundamentals: Bool { fundamental.available }
    var hasMacro: Bool { macro.available }
    var hasNews: Bool { news.available }
}

extension DataHealth {
    static var healthy: DataHealth {
        DataHealth(
            symbol: "MOCK",
            fundamental: CoverageComponent(available: true, quality: 1.0),
            technical: CoverageComponent(available: true, quality: 1.0),
            macro: CoverageComponent(available: true, quality: 1.0),
            news: CoverageComponent(available: true, quality: 1.0)
        )
    }
}
