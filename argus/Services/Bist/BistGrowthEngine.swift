import Foundation

// MARK: - BIST Growth Engine
// Şirketin büyüme dinamiklerini (Satış, Kar) analiz eder
// Puan: 0-100

actor BistGrowthEngine {
    static let shared = BistGrowthEngine()
    
    private init() {}
    
    struct GrowthResult: Sendable {
        let score: Double
        let status: GrowthStatus
        let details: String
        let revenueGrowth: Double?
        let profitGrowth: Double?
    }
    
    enum GrowthStatus: String, Sendable {
        case hyper = "Hiper Büyüme" // > %100
        case strong = "Güçlü Büyüme" // > %50
        case moderate = "Orta Büyüme" // > %20
        case stable = "Stabil" // %0 - %20
        case contracting = "Daralma" // < %0
        case unknown = "Veri Yok"
        
        var color: String {
            switch self {
            case .hyper: return "purple"
            case .strong: return "green"
            case .moderate: return "mint"
            case .stable: return "yellow"
            case .contracting: return "red"
            case .unknown: return "gray"
            }
        }
    }
    
    /// BIST Financials verisinden büyüme analizi yapar
    func analyze(financials: BistFinancials) -> GrowthResult {
        // Veri kontrolü
        guard let revGrowth = financials.revenueGrowth else {
            return GrowthResult(score: 50, status: .unknown, details: "Büyüme verisi hesaplanamadı", revenueGrowth: nil, profitGrowth: nil)
        }
        
        let netProfitGrowth = financials.netProfitGrowth ?? 0
        var score: Double = 50
        
        // 1. Satış Büyümesi Skoru (%60 Ağırlık)
        // Enflasyonist ortamda %40 altı büyüme aslında reel daralmadır.
        // Eşik değerleri dinamik olmalı (Enflasyon + Marj) ama şimdilik sabit
        let inflation = 45.0 // Varsayılan TÜFE
        let realGrowth = revGrowth - inflation
        
        if realGrowth > 50 { score += 50 } // Enflasyon üstü %50
        else if realGrowth > 20 { score += 40 }
        else if realGrowth > 0 { score += 30 }
        else if realGrowth > -10 { score += 15 }
        else { score += 0 }
        
        // 2. Net Kar Büyümesi Skoru (%40 Ağırlık)
        if netProfitGrowth > revGrowth { // Kar marjı genişliyor
            score += 10
        }
        
        if netProfitGrowth > inflation + 20 { score += 40 }
        else if netProfitGrowth > inflation { score += 30 }
        else if netProfitGrowth > 0 { score += 20 }
        else { score -= 10 }
        
        // Normalize (0-100)
        score = min(100, max(0, score))
        
        // Statü Belirleme
        let status: GrowthStatus
        if revGrowth > 100 { status = .hyper }
        else if revGrowth > 50 { status = .strong }
        else if revGrowth > 20 { status = .moderate }
        else if revGrowth > 0 { status = .stable }
        else { status = .contracting }
        
        let detailText = "Satış: %\(String(format: "%.1f", revGrowth)) / Kar: %\(String(format: "%.1f", netProfitGrowth))"
        
        return GrowthResult(
            score: score,
            status: status,
            details: detailText,
            revenueGrowth: revGrowth,
            profitGrowth: netProfitGrowth
        )
    }
}
