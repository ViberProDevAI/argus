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
        // Comprehensive Universe — 2026-04 genişletildi
        // Hedef: çeşit + likidite. Scan kapasitesi (batch 30, timer 180s)
        // ~300 sembole kadar rahat kaldırıyor. Üzerine çıkarmak Yahoo rate
        // limit ve BorsaPy tıkanmasına yol açabilir.
        let comprehensiveUniverse: [String] = [
            // Technology — core (21)
            "AAPL", "MSFT", "NVDA", "AVGO", "ORCL", "ADBE", "CRM", "AMD", "QCOM", "TXN",
            "IBM", "INTC", "NOW", "AMAT", "MU", "LRCX", "ADI", "KLAC", "PANW", "SNOW", "PLTR",
            // Technology — yeni: semi + AI/cloud derinliği (18)
            "ARM", "MCHP", "ON", "MRVL", "SMCI", "DELL", "NET", "DDOG", "MDB", "ESTC",
            "ZS", "CRWD", "FTNT", "CSCO", "HPQ", "WDC", "STX", "ANET",
            // Communication (10)
            "GOOGL", "META", "NFLX", "DIS", "CMCSA", "TMUS", "VZ", "T", "CHTR", "WBD",
            // Communication — yeni: sosyal + medya (6)
            "SNAP", "PINS", "RBLX", "DKNG", "SPOT", "PARA",
            // Financials — core (16)
            "JPM", "V", "MA", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP",
            "SPGI", "CB", "PGR", "SCHW", "COIN",
            // Financials — yeni: fintech + regional (7)
            "SQ", "PYPL", "HOOD", "AFRM", "SOFI", "USB", "TFC",
            // Healthcare — core (15)
            "LLY", "UNH", "JNJ", "MRK", "ABBV", "TMO", "PFE", "AMGN", "ISRG", "ABT",
            "DHR", "BMY", "CVS", "ELV", "GILD",
            // Healthcare — yeni: biotech + pharma (8)
            "REGN", "VRTX", "BIIB", "MRNA", "NVO", "AZN", "HUM", "CI",
            // Consumer Discretionary (12)
            "AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "BKNG", "TJX", "LOW", "LVS", "MAR", "HLT",
            // Consumer Discretionary — yeni: EV + retail (8)
            "F", "GM", "RIVN", "LCID", "ABNB", "CMG", "YUM", "EBAY",
            // Consumer Staples — core (10)
            "WMT", "PG", "COST", "KO", "PEP", "PM", "MO", "CL", "TGT", "EL",
            // Consumer Staples — yeni (5)
            "KHC", "MDLZ", "KDP", "DG", "KR",
            // Energy (8)
            "XOM", "CVX", "COP", "SLB", "EOG", "OXY", "MPC", "PSX",
            // Energy — yeni: hizmet + pipeline (4)
            "VLO", "HES", "KMI", "WMB",
            // Industrials (10)
            "CAT", "GE", "UNP", "HON", "UPS", "LMT", "RTX", "BA", "DE", "MMM",
            // Industrials — yeni: defense + transport (6)
            "NOC", "GD", "HII", "FDX", "NSC", "CSX",
            // Airlines (4)
            "AAL", "DAL", "UAL", "LUV",
            // Materials (4)
            "LIN", "SHW", "FCX", "NEM",
            // Materials — yeni (3)
            "DOW", "APD", "ECL",
            // Real Estate (4)
            "PLD", "AMT", "EQIX", "O",
            // Real Estate — yeni (3)
            "SPG", "WELL", "DLR",
            // Utilities (3)
            "NEE", "SO", "DUK",
            // Utilities — yeni (3)
            "AEP", "EXC", "SRE",
            // Crypto (2)
            "BTC-USD", "ETH-USD",
            // Crypto — yeni: majors (4)
            "SOL-USD", "ADA-USD", "AVAX-USD", "LINK-USD",
            // ETF — sektör (10)
            "XLK", "XLF", "XLV", "XLE", "XLI", "XLY", "XLP", "XLU", "XLRE", "XLC",
            // ETF — piyasa + hacim (6)
            "SPY", "QQQ", "IWM", "DIA", "VTI", "VOO",
            // ETF — emtia + tahvil (8)
            "GLD", "SLV", "USO", "UNG", "TLT", "IEF", "LQD", "HYG",
            // ETF — volatilite + emerging (4)
            "VIXY", "EEM", "FXI", "INDA",
            // International ADR (5)
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            // International ADR — yeni: Çin + Avrupa (6)
            "BABA", "JD", "PDD", "TCEHY", "SONY", "RACE",

            // BIST — core (50, 2026-04 öncesi liste)
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS",
            "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS",
            // BIST — yeni: likit mid-cap + sektör derinliği (25)
            "AGHOL.IS", "AKFGY.IS", "ALKIM.IS", "AYGAZ.IS", "BIOEN.IS",
            "CCOLA.IS", "ECILC.IS", "EUPWR.IS", "ISMEN.IS", "KLKIM.IS",
            "MPARK.IS", "PARSN.IS", "PENGD.IS", "SELEC.IS", "SKBNK.IS",
            "SMRTG.IS", "TATGD.IS", "TTRAK.IS", "YATAS.IS", "ZOREN.IS",
            "BIZIM.IS", "OYAKC.IS", "ALBRK.IS"
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
        
        // DYNAMIC INJECTION — 2026-04 genişletme.
        // Mevcut kullanıcılarda watchlist zaten varsa bu liste eksik
        // sembolleri ekler (mevcut olanlara dokunmaz). Yeni kullanıcılar
        // yukarıdaki comprehensiveUniverse'ı alır.
        let requiredSymbols = [
            // Semi + AI/cloud derinliği
            "ARM", "MCHP", "ON", "MRVL", "SMCI", "DELL", "NET", "DDOG", "MDB", "ESTC",
            "ZS", "CRWD", "FTNT", "CSCO", "HPQ", "WDC", "STX", "ANET",
            // Sosyal + medya
            "SNAP", "PINS", "RBLX", "DKNG", "SPOT", "PARA",
            // Fintech + regional bank
            "SQ", "PYPL", "HOOD", "AFRM", "SOFI", "USB", "TFC",
            // Biotech + pharma
            "REGN", "VRTX", "BIIB", "MRNA", "NVO", "AZN", "HUM", "CI",
            // EV + retail
            "F", "GM", "RIVN", "LCID", "ABNB", "CMG", "YUM", "EBAY",
            // Staples
            "KHC", "MDLZ", "KDP", "DG", "KR",
            // Energy service + pipeline
            "VLO", "HES", "KMI", "WMB",
            // Defense + transport
            "NOC", "GD", "HII", "FDX", "NSC", "CSX",
            // Airlines
            "AAL", "DAL", "UAL", "LUV",
            // Materials
            "DOW", "APD", "ECL",
            // Real Estate
            "SPG", "WELL", "DLR",
            // Utilities
            "AEP", "EXC", "SRE",
            // Crypto majors
            "SOL-USD", "ADA-USD", "AVAX-USD", "LINK-USD",
            // Sector ETFs
            "XLK", "XLF", "XLV", "XLE", "XLI", "XLY", "XLP", "XLU", "XLRE", "XLC",
            // Market ETFs
            "SPY", "QQQ", "IWM", "DIA", "VTI", "VOO",
            // Commodity + bond ETFs
            "GLD", "SLV", "USO", "UNG", "TLT", "IEF", "LQD", "HYG",
            // Volatility + emerging ETFs
            "VIXY", "EEM", "FXI", "INDA",
            // International ADRs
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            "BABA", "JD", "PDD", "TCEHY", "SONY", "RACE",

            // BIST core
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS",
            "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS",
            // BIST mid-cap
            "AGHOL.IS", "AKFGY.IS", "ALKIM.IS", "AYGAZ.IS", "BIOEN.IS",
            "CCOLA.IS", "ECILC.IS", "EUPWR.IS", "ISMEN.IS", "KLKIM.IS",
            "MPARK.IS", "PARSN.IS", "PENGD.IS", "SELEC.IS", "SKBNK.IS",
            "SMRTG.IS", "TATGD.IS", "TTRAK.IS", "YATAS.IS", "ZOREN.IS",
            "BIZIM.IS", "OYAKC.IS", "ALBRK.IS"
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

        // 2026-04-22: Delisted sembolleri kaldır.
        // Yahoo/borsapy 404 döndüren, artık işlem görmeyen semboller:
        //   KOZAL.IS, KOZAA.IS — halka arz kapandı
        //   ANACM.IS — delisted
        //   KERVT.IS — delisted
        //   MMC — NYSE'de yok (Marsh McLennan şimdi farklı ticker)
        let delisted: Set<String> = ["KOZAL.IS", "KOZAA.IS", "ANACM.IS", "KERVT.IS", "MMC"]
        let beforeCount = self.items.count
        self.items.removeAll { delisted.contains($0) }
        let removed = beforeCount - self.items.count
        if removed > 0 {
            print("🧹 WatchlistStore: Delisted \(removed) sembol temizlendi (KOZAL/KOZAA/ANACM/KERVT/MMC)")
            saveWatchlist()
        }
    }
    
    private func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "watchlist_v2")
        }
    }
}
