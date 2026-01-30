import Foundation

struct ArgusNotification: Identifiable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let headline: String
    let summary: String
    let detailedReport: String // Markdown formatted reasoning
    let score: Double
    let type: NotificationType
    let timestamp: Date
    var isRead: Bool
    
    enum NotificationType: String, Codable {
        case buyOpportunity = "AL FIRSATI"
        case sellWarning = "SATIŞ UYARISI"
        case marketUpdate = "PİYASA GÜNCELLEMESİ"
        case tradeExecuted = "İŞLEM GERÇEKLEŞTİ"
        case positionClosed = "POZİSYON KAPANDI"
        case alert = "UYARI"
        case dailyReport = "GÜNLÜK RAPOR"
        case weeklyReport = "HAFTALIK RAPOR"
    }
    
    init(
        id: UUID = UUID(),
        symbol: String,
        headline: String,
        summary: String,
        detailedReport: String,
        score: Double,
        type: NotificationType,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.headline = headline
        self.summary = summary
        self.detailedReport = detailedReport
        self.score = score
        self.type = type
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

/// Generates persuasive, data-driven narratives for Argus Notifications.
class ArgusReportGenerator {
    static let shared = ArgusReportGenerator()
    
    func generateReport(
        symbol: String,
        decision: ArgusDecisionResult,
        quote: Quote
    ) -> (headline: String, summary: String, report: String) {
        
        let score = decision.finalScoreCore
        let action = decision.finalActionCore
        let regime = decision.chironResult?.regime.descriptor ?? "Bilinmiyor"
        
        // 1. Headline
        let headline: String
        if action == .buy {
            headline = "🚀 \(symbol): Güçlü Alım Sinyali (\(Int(score)))"
        } else if action == .sell {
            headline = "⚠️ \(symbol): Satış Alarmı (\(Int(score)))"
        } else {
            headline = "ℹ️ \(symbol): Takip Güncellemesi"
        }
        
        // 2. Summary (Short for Push/Preview)
        let summary = "Argus, \(symbol) üzerinde %\(String(format: "%.1f", score)) başarı potansiyeli tespit etti. Rejim: \(regime). Detaylar için dokunun."
        
        // 3. Detailed Report (Markdown)
        var sections: [String] = []
        
        // Introduction
        sections.append("## 🎯 Argus Kararı: \(action.rawValue)")
        sections.append("**Skor:** \(Int(score))/100  |  **Fiyat:** $\(String(format: "%.2f", quote.currentPrice))")
        sections.append("Argus algoritmaları bu hissede belirgin bir \(action.rawValue) fırsatı görüyor.")
        
        // Technicals (Orion)
        let orion = decision.orionScore
        sections.append("### 📈 Orion Teknik Analiz (\(Int(orion)))")
        if orion > 70 {
            sections.append("- Trend pozitif ve momentum güçlü.")
            sections.append("- Hareketli ortalamaların üzerinde fiyatlama.")
        } else if orion < 30 {
            sections.append("- Trend zayıf, satış baskısı hakim.")
        } else {
            sections.append("- Teknik görünüm yatay/nötr.")
        }
        
        // Fundamentals (Atlas)
        let atlas = decision.atlasScore
        sections.append("### 🏢 Atlas Temel Analiz (\(Int(atlas)))")
        if atlas > 70 {
            sections.append("- Şirket finansalları sağlam.")
            sections.append("- Kârlılık ve büyüme verileri sektör üstü.")
        } else {
            sections.append("- Temel verilerde bazı riskler mevcut.")
        }
        
        // Macro (Aether)
        let aether = decision.aetherScore
        sections.append("### 🌍 Aether Makro Ortam (\(Int(aether)))")
        sections.append("- Piyasa rejimi: **\(regime)**")
        if aether > 60 {
            sections.append("- Genel piyasa koşulları risk almaya uygun.")
        } else {
            sections.append("- Piyasa genelinde baskı var, dikkatli olunmalı.")
        }
        
        // Conclusion
        sections.append("### 🧠 Sonuç ve Tavsiye")
        if action == .buy {
            sections.append("Mevcut veri seti, risk/getiri profilinin alım yönünde cazip olduğunu gösteriyor. Portföye ekleme yapılması önerilir.")
        } else if action == .sell {
            sections.append("Kâr realizasyonu veya zarar durdurma (Stop-Loss) için uygun bir zaman olabilir.")
        }
        
        let fullReport = sections.joined(separator: "\n\n")
        
        return (headline, summary, fullReport)
    }
}

struct NotificationContent: Codable {
    let title: String
    let body: String
    let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case title, body, data
    }
    
    init(title: String, body: String, data: [String: Any]? = nil) {
        self.title = title
        self.body = body
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        // Skip data decoding/encoding for now to satisfy Codable safely
        data = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
    }
}
