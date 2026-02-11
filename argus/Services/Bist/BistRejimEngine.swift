import Foundation

// MARK: - BIST Rejim Engine
// Piyasa rejimi ve risk modunu analiz eder
// USD/TRY, VIX, XU100 verilerini kullanır

actor BistRejimEngine {
    static let shared = BistRejimEngine()
    
    private init() {}
    
    // MARK: - Ana Analiz
    
    func analyze() async throws -> BistRejimResult {
        // Verileri Çek
        let xu100 = try? await BorsaPyProvider.shared.getXU100()
        let usdTry = try? await BorsaPyProvider.shared.getFXRate(asset: "USDTRY")
        
        // Rejim Bileşenleri
        var components: [RejimComponent] = []
        var totalScore: Double = 50
        
        // 1. XU100 Günlük Değişim
        if let xu = xu100 {
            let dailyChange = ((xu.last - xu.previousClose) / xu.previousClose) * 100
            let component: RejimComponent
            
            if dailyChange > BistThresholds.Momentum.strong {
                component = RejimComponent(name: "XU100", value: dailyChange, status: .bullish, detail: "+\(String(format: "%.1f", dailyChange))% (Güçlü Yükselis)")
                totalScore += 20
            } else if dailyChange > BistThresholds.Momentum.positive {
                component = RejimComponent(name: "XU100", value: dailyChange, status: .positive, detail: "+\(String(format: "%.1f", dailyChange))%")
                totalScore += 10
            } else if dailyChange > BistThresholds.Momentum.negativeUpper {
                component = RejimComponent(name: "XU100", value: dailyChange, status: .neutral, detail: "\(String(format: "%.1f", dailyChange))% (Yatay)")
                totalScore += 0
            } else if dailyChange > BistThresholds.Momentum.negative {
                component = RejimComponent(name: "XU100", value: dailyChange, status: .negative, detail: "\(String(format: "%.1f", dailyChange))%")
                totalScore -= 10
            } else {
                component = RejimComponent(name: "XU100", value: dailyChange, status: .bearish, detail: "\(String(format: "%.1f", dailyChange))% (Sert Düşüş)")
                totalScore -= 25
            }
            components.append(component)
        }
        
        // 2. USD/TRY Stres
        if let usd = usdTry {
            let fxChange = usd.open > 0 ? ((usd.last - usd.open) / usd.open) * 100 : 0
            let component: RejimComponent
            
            if fxChange < -0.5 {
                component = RejimComponent(name: "USD/TRY", value: fxChange, status: .bullish, detail: "\(String(format: "%.2f", fxChange))% (TL Güçleniyor)")
                totalScore += 15
            } else if fxChange < 0.5 {
                component = RejimComponent(name: "USD/TRY", value: fxChange, status: .neutral, detail: "\(String(format: "%.2f", fxChange))% (Stabil)")
                totalScore += 5
            } else if fxChange < 1.5 {
                component = RejimComponent(name: "USD/TRY", value: fxChange, status: .negative, detail: "+\(String(format: "%.2f", fxChange))% (Hafif Stres)")
                totalScore -= 10
            } else {
                component = RejimComponent(name: "USD/TRY", value: fxChange, status: .bearish, detail: "+\(String(format: "%.2f", fxChange))% (Yüksek Stres)")
                totalScore -= 25
            }
            components.append(component)
        }
        
        // 3. Makro Ortam (Sirkiye Aether)
        let macro = await SirkiyeAetherEngine.shared.analyze()
        let macroScore = macro.overallScore
        let macroComponent: RejimComponent
        
        if macroScore >= 70 {
            macroComponent = RejimComponent(name: "Makro", value: macroScore, status: .bullish, detail: "Güçlü Ekonomik Destek (Skor: \(Int(macroScore)))")
            totalScore += 15
        } else if macroScore >= 50 {
            macroComponent = RejimComponent(name: "Makro", value: macroScore, status: .positive, detail: "Stabil Görünüm (Skor: \(Int(macroScore)))")
            totalScore += 5
        } else if macroScore >= 40 {
            macroComponent = RejimComponent(name: "Makro", value: macroScore, status: .neutral, detail: "Nötr Görünüm (Skor: \(Int(macroScore)))")
        } else {
            macroComponent = RejimComponent(name: "Makro", value: macroScore, status: .bearish, detail: "Makro Riskler (Skor: \(Int(macroScore)))")
            totalScore -= 15
        }
        components.append(macroComponent)
        
        // 4. Seans Durumu
        let seansComponent = analyzeSeans()
        components.append(seansComponent)
        if seansComponent.status == .bullish { totalScore += 5 }
        
        // Rejim Belirleme
        let regime: PiyasaRejimi
        if totalScore >= 75 { regime = .gucluBoga }
        else if totalScore >= 60 { regime = .boga }
        else if totalScore >= 40 { regime = .notr }
        else if totalScore >= 25 { regime = .ayi }
        else { regime = .gucluAyi }
        
        return BistRejimResult(
            regime: regime,
            score: min(100, max(0, totalScore)),
            components: components,
            recommendation: getRecommendation(regime: regime),
            timestamp: Date()
        )
    }
    
    // MARK: - Seans Analizi
    
    private func analyzeSeans() -> RejimComponent {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        // Hafta sonu
        if weekday == 1 || weekday == 7 {
            return RejimComponent(name: "Seans", value: 0, status: .neutral, detail: "Borsa Kapalı (Hafta Sonu)")
        }
        
        // Seans saatleri (10:00 - 18:00)
        if hour < 10 {
            return RejimComponent(name: "Seans", value: 0, status: .neutral, detail: "Açılış Öncesi")
        } else if hour == 10 && minute < 30 {
            return RejimComponent(name: "Seans", value: 1, status: .bullish, detail: "Açılış Seansı (Volatil)")
        } else if hour < 13 {
            return RejimComponent(name: "Seans", value: 1, status: .positive, detail: "Sabah Seansı")
        } else if hour < 14 {
            return RejimComponent(name: "Seans", value: 0, status: .neutral, detail: "Öğle Arası")
        } else if hour < 17 || (hour == 17 && minute < 30) {
            return RejimComponent(name: "Seans", value: 1, status: .positive, detail: "Öğleden Sonra Seansı")
        } else if hour < 18 {
            return RejimComponent(name: "Seans", value: 1, status: .bullish, detail: "Kapanış Seansı (Yüksek Hacim)")
        } else {
            return RejimComponent(name: "Seans", value: 0, status: .neutral, detail: "Borsa Kapalı")
        }
    }
    
    // MARK: - Öneri
    
    private func getRecommendation(regime: PiyasaRejimi) -> String {
        switch regime {
        case .gucluBoga:
            return "Agresif alım fırsatı. Momentum güçlü."
        case .boga:
            return "Pozisyon artırılabilir. Trend yukarı."
        case .notr:
            return "Bekle-gör stratejisi. Kısa vadeli işlemler."
        case .ayi:
            return "Defansif ol. Stop-loss'ları sıkılaştır."
        case .gucluAyi:
            return "Risk azalt. Nakit pozisyonu artır."
        }
    }
}

// MARK: - Modeller

struct BistRejimResult: Sendable {
    let regime: PiyasaRejimi
    let score: Double
    let components: [RejimComponent]
    let recommendation: String
    let timestamp: Date
}

struct RejimComponent: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let status: RejimStatus
    let detail: String
}

enum RejimStatus: String, Sendable {
    case bullish = "Pozitif"
    case positive = "Hafif Pozitif"
    case neutral = "Nötr"
    case negative = "Hafif Negatif"
    case bearish = "Negatif"
    
    var color: String {
        switch self {
        case .bullish: return "green"
        case .positive: return "mint"
        case .neutral: return "yellow"
        case .negative: return "orange"
        case .bearish: return "red"
        }
    }
}

enum PiyasaRejimi: String, Sendable {
    case gucluBoga = "Güçlü Boğa"
    case boga = "Boğa"
    case notr = "Nötr"
    case ayi = "Ayı"
    case gucluAyi = "Güçlü Ayı"
    
    var icon: String {
        switch self {
        case .gucluBoga, .boga: return "arrow.up.circle.fill"
        case .notr: return "arrow.left.arrow.right.circle.fill"
        case .ayi, .gucluAyi: return "arrow.down.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .gucluBoga: return "green"
        case .boga: return "mint"
        case .notr: return "yellow"
        case .ayi: return "orange"
        case .gucluAyi: return "red"
        }
    }
}
