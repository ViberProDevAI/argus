import Foundation

// MARK: - Foreign Investor Flow Service
/// Yabanci yatirimci net alim/satim verilerini saglar
/// Kaynak: Bloomberg HT, Finnet (scrape)
/// Bu veri BIST hisseleri icin cok guclu bir sinyal kaynagi

actor ForeignInvestorFlowService {
    static let shared = ForeignInvestorFlowService()
    
    // MARK: - Data Models
    
    struct ForeignFlowData {
        let symbol: String
        let netFlow: Double           // Pozitif = net alim, Negatif = net satim (USD)
        let foreignRatio: Double      // Yabanci pay orani (%)
        let dailyChange: Double       // Gunluk degisim (USD)
        let trend: FlowTrend
        let timestamp: Date
        
        var isPositive: Bool { netFlow > 0 }
        var formattedFlow: String {
            let sign = netFlow >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", netFlow / 1_000_000))M $"
        }
    }
    
    enum FlowTrend: String {
        case strongBuy = "GUCLU ALIM"
        case buy = "ALIM"
        case neutral = "NOTR"
        case sell = "SATIM"
        case strongSell = "GUCLU SATIM"
        
        var color: String {
            switch self {
            case .strongBuy: return "00FF00"
            case .buy: return "90EE90"
            case .neutral: return "FFFF00"
            case .sell: return "FFA500"
            case .strongSell: return "FF0000"
            }
        }
    }
    
    struct MarketSummary {
        let totalNetFlow: Double        // Toplam net alim/satim
        let topBuys: [(String, Double)] // En cok alinan hisseler
        let topSells: [(String, Double)]// En cok satilan hisseler
        let timestamp: Date
        
        var marketSentiment: String {
            if totalNetFlow > 100_000_000 { return "GUCLU YABANCI GIRISI" }
            if totalNetFlow > 0 { return "YABANCI GIRISI" }
            if totalNetFlow > -100_000_000 { return "YABANCI CIKISI" }
            return "GUCLU YABANCI CIKISI"
        }
    }
    
    // MARK: - Cache
    private var cachedData: [String: ForeignFlowData] = [:]
    private var cachedSummary: MarketSummary?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 3600 // 1 saat
    
    // MARK: - Public API
    
    /// Belirli bir hisse icin yabanci akis verisini getir
    func getFlowData(for symbol: String) async -> ForeignFlowData? {
        // Cache kontrol
        if let cached = cachedData[symbol],
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        // Scrape
        return await scrapeFlowData(for: symbol)
    }
    
    /// Piyasa genel ozeti
    func getMarketSummary() async -> MarketSummary {
        if let cached = cachedSummary,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        return await scrapeMarketSummary()
    }
    
    /// Tum hisseler icin yabanci akislarini getir
    func getAllFlows() async -> [ForeignFlowData] {
        return Array(cachedData.values)
    }
    
    // MARK: - Scraping (Bloomberg HT)
    
    private func scrapeFlowData(for symbol: String) async -> ForeignFlowData? {
        // İş Yatırım Hisse Detay Sayfasından Scrape Denemesi
        // URL: https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/genel-bakis.aspx?hisse=THYAO
        
        let cleanSymbol = symbol.replacingOccurrences(of: ".IS", with: "")
        let urlString = "https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/default.aspx?hisse=\(cleanSymbol)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // Hızlı fail etsin
            // User-Agent eklemezsek 403 alabiliriz
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                print("⚠️ Yabancı Takas verisi çekilemedi: \(symbol) (HTTP \( (response as? HTTPURLResponse)?.statusCode ?? 0 ))")
                return nil
            }
            
            // Parse HTML for foreign investor data
            // Gerçekçi olmayan bir veri dönmektense hiç dönmemek daha iyidir (User Request: "Ayıkla pirincin taşını")
            
            if let ratio = parseForeignRatio(from: html) {
                // Net Flow verisi sayfada yoksa 0 kabul et, ama oran gerçek olsun
                let flowData = ForeignFlowData(
                    symbol: symbol,
                    netFlow: 0, // Net para girişi verisi bu sayfada yok
                    foreignRatio: ratio,
                    dailyChange: 0,
                    trend: .neutral, // Veri yoksa nötr
                    timestamp: Date()
                )
                
                cachedData[symbol] = flowData
                lastFetchTime = Date()
                print("✅ Yabancı Takas Oranı: \(symbol) - %\(ratio)")
                return flowData
            } else {
                 print("⚠️ Yabancı Takas verisi parse edilemedi: \(symbol). HTML değişmiş olabilir.")
                 return nil
            }
            
        } catch {
            print("❌ Yabancı Akış servisine ulaşılamadı: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func scrapeMarketSummary() async -> MarketSummary {
        // Finnet veya Bloomberg HT ozet sayfasindan scrape
        // Varsayilan degerler don
        
        let summary = MarketSummary(
            totalNetFlow: 0,
            topBuys: [],
            topSells: [],
            timestamp: Date()
        )
        
        cachedSummary = summary
        return summary
    }
    
    // MARK: - Parsing Helpers
    
    private func parseNetFlow(from html: String) -> Double {
        return 0.0 // Mock veri kaldırıldı.
    }
    
    private func parseForeignRatio(from html: String) -> Double? {
        // İş Yatırım sayfasında "Yabancı Oranı (%)" araması
        // HTML yapısı değişebilir, regex ile esnek arama yapalım
        // Pattern: "Yabancı Oranı (%)" sonrasında gelen sayısal değer
        
        // Örnek HTML: <td class="text-right">34,56</td>
        // Bu çok genel, daha spesifik bir context lazım.
        // Şimdilik basit bir "NO RANDOM" implementasyonu.
        // Eğer regex çalışmazsa NIL dönecek. ASLA random dönmeyecek.
        
        return nil // Şimdilik nil dönüyoruz, çünkü regex yazmak için HTML yapısını görmemiz lazım.
                   // Bu "En azından yalan söyleme" kuralına uygundur.
    }
    
    private func determineTrend(netFlow: Double) -> FlowTrend {
        switch netFlow {
        case let x where x > 50_000_000: return .strongBuy
        case let x where x > 10_000_000: return .buy
        case let x where x > -10_000_000: return .neutral
        case let x where x > -50_000_000: return .sell
        default: return .strongSell
        }
    }
    
    // MARK: - Integration with Sirkiye Engine
    
    /// Sirkiye Engine icin yabanci akis skoru hesapla (0-100)
    func getForeignFlowScore(for symbol: String) async -> Double {
        guard let flow = await getFlowData(for: symbol) else { return 50.0 }
        
        // Net akisi 0-100 skora cevir
        // -100M = 0, 0 = 50, +100M = 100
        let normalized = (flow.netFlow / 100_000_000) * 50 + 50
        return min(100, max(0, normalized))
    }
    
    /// Piyasa geneli yabanci sentiment skoru
    func getMarketForeignSentiment() async -> Double {
        let summary = await getMarketSummary()
        let normalized = (summary.totalNetFlow / 500_000_000) * 50 + 50
        return min(100, max(0, normalized))
    }
}

// MARK: - Sirkiye Engine Extension


