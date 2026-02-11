import Foundation

struct SectorMap: Sendable {
    nonisolated static let map: [String: SectorETF] = [
        // Technology (XLK)
        "AAPL": .XLK, "MSFT": .XLK, "NVDA": .XLK, "AVGO": .XLK, "ADBE": .XLK, "CRM": .XLK, "AMD": .XLK, "ORCL": .XLK, "INTC": .XLK, "CSCO": .XLK,
        
        // Communication Services (XLC)
        "GOOGL": .XLC, "GOOG": .XLC, "META": .XLC, "NFLX": .XLC, "DIS": .XLC, "TMUS": .XLC, "CMCSA": .XLC, "VZ": .XLC, "T": .XLC,
        
        // Consumer Discretionary (XLY)
        "AMZN": .XLY, "TSLA": .XLY, "HD": .XLY, "MCD": .XLY, "NKE": .XLY, "SBUX": .XLY, "LOW": .XLY, "BKNG": .XLY,
        
        // Financials (XLF)
        "JPM": .XLF, "BAC": .XLF, "V": .XLF, "MA": .XLF, "WFC": .XLF, "MS": .XLF, "GS": .XLF, "BLK": .XLF, "C": .XLF, "AXP": .XLF, "BRK.B": .XLF,
        
        // Healthcare (XLV)
        "LLY": .XLV, "UNH": .XLV, "JNJ": .XLV, "MRK": .XLV, "ABBV": .XLV, "TMO": .XLV, "PFE": .XLV, "AMGN": .XLV,
        
        // Industrials (XLI)
        "CAT": .XLI, "GE": .XLI, "UNP": .XLI, "BA": .XLI, "HON": .XLI, "UPS": .XLI, "LMT": .XLI, "DE": .XLI,
        
        // Energy (XLE)
        "XOM": .XLE, "CVX": .XLE, "COP": .XLE, "SLB": .XLE, "EOG": .XLE,
        
        // Consumer Staples (XLP)
        "PG": .XLP, "COST": .XLP, "WMT": .XLP, "PEP": .XLP, "KO": .XLP, "PM": .XLP,
        
        // Utilities (XLU)
        "NEE": .XLU, "DUK": .XLU, "SO": .XLU,
        
        // Real Estate (XLRE)
        "PLD": .XLRE, "AMT": .XLRE, "CCI": .XLRE, "EQIX": .XLRE,
        
        // Materials (XLB)
        "LIN": .XLB, "SHW": .XLB, "FCX": .XLB
    ]
    
    nonisolated static func getSector(for symbol: String) -> SectorETF? {
        // Direct Map
        if let etf = map[symbol] { return etf }
        
        // ETF Self-Identification
        if let etf = SectorETF(rawValue: symbol) { return etf }
        
        return nil
    }
}
