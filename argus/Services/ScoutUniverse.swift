import Foundation

// MARK: - Scout Universe
/// Predefined list of high-volume US stocks for scouting beyond watchlist
struct ScoutUniverse {
    
    /// Top 50 most traded US stocks
    static let topUS: [String] = [
        // FAANG + Big Tech
        "AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA",
        
        // Semiconductors
        "AMD", "INTC", "AVGO", "QCOM", "MU", "MRVL",
        
        // Software & Cloud
        "CRM", "ADBE", "NOW", "SNOW", "PLTR", "NET", "DDOG",
        
        // E-commerce & Payments
        "SHOP", "SQ", "PYPL", "COIN", "AFRM",
        
        // Streaming & Entertainment
        "NFLX", "DIS", "ROKU", "SPOT",
        
        // EV & Energy
        "RIVN", "LCID", "NIO", "ENPH", "FSLR",
        
        // Biotech & Healthcare
        "MRNA", "BNTX", "CRSP", "DXCM",
        
        // Finance
        "JPM", "GS", "V", "MA", "BAC",
        
        // Consumer
        "NKE", "SBUX", "MCD", "HD", "TGT"
    ]
    
    /// Rotation list for daily variety (randomized subset)
    static func dailyRotation(count: Int = 20) -> [String] {
        Array(topUS.shuffled().prefix(count))
    }
    
    /// Merges watchlist with scout universe (removes duplicates)
    static func combinedList(watchlist: [String], universeCount: Int = 30) -> [String] {
        var combined = Set(watchlist)
        
        // Add universe symbols until we reach the limit
        let universeToAdd = topUS.filter { !combined.contains($0) }
        let toAdd = Array(universeToAdd.prefix(universeCount))
        
        combined.formUnion(toAdd)
        
        return Array(combined)
    }
    
    /// Categories for UI grouping
    enum Category: String, CaseIterable {
        case tech = "Teknoloji"
        case semiconductor = "Yarı İletken"
        case cloud = "Bulut"
        case fintech = "Fintech"
        case ev = "EV & Enerji"
        case healthcare = "Sağlık"
        case finance = "Finans"
        case consumer = "Tüketici"
        
        var symbols: [String] {
            switch self {
            case .tech: return ["AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA"]
            case .semiconductor: return ["AMD", "INTC", "AVGO", "QCOM", "MU", "MRVL"]
            case .cloud: return ["CRM", "ADBE", "NOW", "SNOW", "PLTR", "NET", "DDOG"]
            case .fintech: return ["SQ", "PYPL", "COIN", "AFRM"]
            case .ev: return ["RIVN", "LCID", "NIO", "ENPH", "FSLR"]
            case .healthcare: return ["MRNA", "BNTX", "CRSP", "DXCM"]
            case .finance: return ["JPM", "GS", "V", "MA", "BAC"]
            case .consumer: return ["NKE", "SBUX", "MCD", "HD", "TGT"]
            }
        }
    }
}
