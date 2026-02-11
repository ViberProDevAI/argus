import Foundation
import Combine
import SwiftUI

@MainActor
class WatchlistStore: ObservableObject {
    static let shared = WatchlistStore()
    
    @Published var items: [String] = [] {
        didSet {
            saveWatchlist()
        }
    }
    
    private init() {
        loadWatchlist()
    }
    
    // MARK: - Public API
    
    func add(_ symbol: String) -> Bool {
        if !items.contains(symbol) {
            items.append(symbol)
            return true
        }
        return false
    }
    
    func remove(_ symbol: String) {
        if let index = items.firstIndex(of: symbol) {
            items.remove(at: index)
        }
    }
    
    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    // MARK: - Persistence Logic
    
    private func loadWatchlist() {
        // Comprehensive Universe for defaults
        let comprehensiveUniverse: [String] = [
            // Technology (20)
            "AAPL", "MSFT", "NVDA", "AVGO", "ORCL", "ADBE", "CRM", "AMD", "QCOM", "TXN",
            "IBM", "INTC", "NOW", "AMAT", "MU", "LRCX", "ADI", "KLAC", "PANW", "SNOW", "PLTR",
            // Communication (10)
            "GOOGL", "META", "NFLX", "DIS", "CMCSA", "TMUS", "VZ", "T", "CHTR", "WBD",
            // Financials (15)
            "JPM", "V", "MA", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP", "SPGI", "CB", "MMC", "PGR", "SCHW", "COIN",
            // Healthcare (15)
            "LLY", "UNH", "JNJ", "MRK", "ABBV", "TMO", "PFE", "AMGN", "ISRG", "ABT", "DHR", "BMY", "CVS", "ELV", "GILD",
            // Consumer Discretionary (12)
            "AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "BKNG", "TJX", "LOW", "LVS", "MAR", "HLT",
            // Consumer Staples (10)
            "WMT", "PG", "COST", "KO", "PEP", "PM", "MO", "CL", "TGT", "EL",
            // Energy (8)
            "XOM", "CVX", "COP", "SLB", "EOG", "OXY", "MPC", "PSX",
            // Industrials (10)
            "CAT", "GE", "UNP", "HON", "UPS", "LMT", "RTX", "BA", "DE", "MMM",
            // Materials (4)
            "LIN", "SHW", "FCX", "NEM",
            // Real Estate (4)
            "PLD", "AMT", "EQIX", "O",
            // Utilities (3)
            "NEE", "SO", "DUK",
            // Crypto (2)
            "BTC-USD", "ETH-USD",
            // 2025 Analyst Picks
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            
            // BIST 50 - Türkiye Borsası (Kaliteli Hisseler)
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS", "KOZAL.IS",
            "KOZAA.IS", "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS"
        ].sorted()
        
        // Priority: Check v2
        if let data = UserDefaults.standard.data(forKey: "watchlist_v2"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.items = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: "watchlist"),
                  let decoded = try? JSONDecoder().decode([String].self, from: legacyData) {
            // MIGRATION: Restore Legacy Data
            print("📦 WatchlistStore: Migration from Legacy Storage")
            self.items = decoded
            saveWatchlist()
        }
        
        // FAILSAFE: If user has fewer than 5 symbols
        if self.items.isEmpty || (self.items.count < 5 && UserDefaults.standard.object(forKey: "watchlist_v2") == nil) {
            print("⚠️ WatchlistStore: Initializing Comprehensive Universe.")
            self.items = comprehensiveUniverse
            saveWatchlist()
        }
        
        // DYNAMIC INJECTION: Ensure BIST + 2025 Analyst Picks are present
        let requiredSymbols = [
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS", "KOZAL.IS",
            "KOZAA.IS", "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS"
        ]
        
        var addedCount = 0
        for symbol in requiredSymbols {
            if !self.items.contains(symbol) {
                self.items.append(symbol)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            print("✨ WatchlistStore: Added \(addedCount) new required symbols.")
            saveWatchlist()
        }
    }
    
    private func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "watchlist_v2")
        }
    }
}
