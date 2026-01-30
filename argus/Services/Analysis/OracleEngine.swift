import Foundation
import SwiftUI

/// Oracle: Piyasanın Kahini
/// EVDS verilerini işleyerek sektörel ve hisse bazlı "Zincirleme Reaksiyon" (Chain Reaction) sinyalleri üretir.
actor OracleEngine {
    static let shared = OracleEngine()
    
    // MARK: - Types
    
    enum OracleSignalType: String, CaseIterable {
        case housingBoom = "HOUSING_BOOM"       // Konut Satışları
        case retailPulse = "RETAIL_PULSE"       // Kredi Kartı Harcamaları
        case industryGear = "INDUSTRY_GEAR"     // Kapasite Kullanım
        case hotMoney = "HOT_MONEY"             // Yabancı Takas
        case tourismRush = "TOURISM_RUSH"       // Turizm Giriş
        case shieldStrength = "SHIELD_STRENGTH" // TCMB Rezerv
        case autoVelocity = "AUTO_VELOCITY"     // Otomotiv Satış
        case creditCrunch = "CREDIT_CRUNCH"     // Ticari Kredi Faizi
        
        var displayName: String {
            switch self {
            case .housingBoom: return "Konut İştahı"
            case .retailPulse: return "Tüketim Nabzı"
            case .industryGear: return "Sanayi Çarkları"
            case .hotMoney: return "Yabancı Akışı"
            case .tourismRush: return "Turizm Akını"
            case .shieldStrength: return "Kur Kalkanı"
            case .autoVelocity: return "Oto Pazarı"
            case .creditCrunch: return "Kredi Sıkışıklığı"
            }
        }
        
        var icon: String {
            switch self {
            case .housingBoom: return "house.fill"
            case .retailPulse: return "creditcard.fill"
            case .industryGear: return "gearshape.2.fill"
            case .hotMoney: return "airplane.departure" // Yabancı gelişi
            case .tourismRush: return "sun.max.fill"
            case .shieldStrength: return "shield.check.fill"
            case .autoVelocity: return "car.fill"
            case .creditCrunch: return "banknote.fill"
            }
        }
    }
    
    /// Oracle tarafından üretilen bir sinyal ve etkisi
    struct OracleSignal: Identifiable, Sendable {
        let id = UUID()
        let type: OracleSignalType
        let rawValue: Double // Örn: 120.000 (Konut satışı)
        let changeYoY: Double // Yıllık Değişim % (Örn: +15.0)
        let changeMoM: Double // Aylık Değişim %
        let sentiment: SignalSentiment
        let message: String
        
        // Etkilediği Sektörler ve Puanları (Multiplier)
        let effects: [OracleSectorEffect]
        
        var timestamp: Date = Date()
        
        // Veri Gecikmesi (Design Doc: Freshness Indicator)
        let freshness: DataFreshness
    }
    
    enum SignalSentiment: String, Sendable {
        case bullish = "POZİTİF"
        case bearish = "NEGATİF"
        case neutral = "NÖTR"
        
        var color: Color {
            switch self {
            case .bullish: return .green
            case .bearish: return .red
            case .neutral: return .gray
            }
        }
    }
    
    enum DataFreshness: String, Sendable {
        case realTime = "CANLI"
        case delayed1M = "1 AY GECİKMELİ"
        case delayed2M = "2 AY GECİKMELİ"
        case simulated = "SİMÜLASYON" // What-If modu için
    }
    
    struct OracleSectorEffect: Identifiable, Sendable {
        let id = UUID()
        let sectorCode: String // XU100, XBANK, XGMYO vs.
        let impactedStocks: [String] // ["EKGYO", "ISGYO"]
        let scoreImpact: Double // +15.0, -10.0
        let reason: String // "Konut kredisi faizlerindeki düşüş talebi artırıyor."
    }
    
    // MARK: - Core Logic
    
    /// EVDS Veri Setini Analiz Et ve Sinyal Üret
    func analyze(input: OracleDataInput) -> [OracleSignal] {
        var signals: [OracleSignal] = []
        
        // 1. KONUT SEKTÖRÜ (Housing Boom)
        let housingChange = input.housingSalesChangeYoY
        if abs(housingChange) > 5.0 {
            let sentiment: SignalSentiment = housingChange > 0 ? .bullish : .bearish
            let score = housingChange * 1.5 // %10 artış -> +15 Puan
            
            let signal = OracleSignal(
                type: .housingBoom,
                rawValue: input.housingSalesTotal,
                changeYoY: housingChange,
                changeMoM: input.housingSalesChangeMoM,
                sentiment: sentiment,
                message: housingChange > 0 
                    ? "Konut satışlarında yıllık %\(String(format: "%.1f", housingChange)) artış: GYO sektörü için pozitif talep şoku."
                    : "Konut piyasasında daralma: Yüksek faizler GYO talebini baskılıyor.",
                effects: [
                    OracleSectorEffect(
                        sectorCode: "XGMYO",
                        impactedStocks: ["EKGYO", "ISGYO", "TRGYO", "AKCNS"],
                        scoreImpact: score,
                        reason: "Konut satış trendindeki değişim doğrudan ciro beklentisini etkiliyor."
                    )
                ],
                freshness: .delayed1M
            )
            signals.append(signal)
        }
        
        // 2. PERAKENDE (Retail Pulse - Kredi Kartı)
        let spendingChange = input.creditCardSpendingChangeYoY
        // Enflasyondan Arındırılmış (Reel) Büyüme Kontrolü
        let realGrowth = spendingChange - input.inflationYoY
        
        if abs(realGrowth) > 2.0 {
            let sentiment: SignalSentiment = realGrowth > 0 ? .bullish : .bearish
            let score = realGrowth * 2.0 // Reel büyüme katsayısı yüksek
            
            let signal = OracleSignal(
                type: .retailPulse,
                rawValue: input.creditCardSpendingTotal, // Milyar TL
                changeYoY: spendingChange,
                changeMoM: 0, // Haftalık olduğu için MoM complex
                sentiment: sentiment,
                message: realGrowth > 0
                    ? "Tüketim çılgınlığı: Kredi kartı harcamaları reel olarak %\(String(format: "%.1f", realGrowth)) arttı."
                    : "Tüketici frene bastı: Reel harcamalarda düşüş var.",
                effects: [
                    OracleSectorEffect(
                        sectorCode: "XTCRT", // Ticaret
                        impactedStocks: ["BIMAS", "MGROS", "SOKM", "MAVI"],
                        scoreImpact: score,
                        reason: "Perakende harcamalarındaki reel değişim mağaza cirolarını direkt etkiler."
                    )
                ],
                freshness: .realTime // Haftalık veri
            )
            signals.append(signal)
        }
        
        // 3. SANAYİ (Industry Gear - KKO)
        let kko = input.capacityUsageRatio
        let kkoPrev = input.prevCapacityUsageRatio
        let kkoDelta = kko - kkoPrev
        
        if abs(kkoDelta) > 0.5 || kko > 78.0 || kko < 72.0 {
            var sentiment: SignalSentiment = .neutral
            var msg = ""
            var score = 0.0
            
            if kko > 78.0 {
                sentiment = .bullish
                msg = "Sanayi tam gaz: KKO %\(String(format: "%.1f", kko)) ile zirveye yakın."
                score = 20.0
            } else if kko < 72.0 {
                sentiment = .bearish
                msg = "Sanayi çarkları yavaşlıyor: KKO %\(String(format: "%.1f", kko)) seviyesine geriledi."
                score = -15.0
            } else if kkoDelta > 1.0 {
                sentiment = .bullish
                msg = "Üretimde toparlanma sinyali: KKO artış eğiliminde."
                score = 10.0
            }
            
            let signal = OracleSignal(
                type: .industryGear,
                rawValue: kko,
                changeYoY: 0,
                changeMoM: kkoDelta,
                sentiment: sentiment,
                message: msg,
                effects: [
                    OracleSectorEffect(
                        sectorCode: "XUSIN",
                        impactedStocks: ["EREGL", "KRDMD", "ARCLK", "FROTO", "TOASO"],
                        scoreImpact: score,
                        reason: "Kapasite kullanımındaki değişim sanayi üretim hacmini işaret eder."
                    )
                ],
                freshness: .delayed1M
            )
            signals.append(signal)
        }
        
        // 4. TURİZM (Tourism Rush) - Mevsimsellik!
        // Basit simülasyon mantığı: Yaz aylarında default pozitif, diğer aylar veriye bağlı.
        let tourismChange = input.touristArrivalsChangeYoY
        if tourismChange > 10.0 {
             let signal = OracleSignal(
                type: .tourismRush,
                rawValue: input.touristArrivalsTotal, // Milyon Kişi
                changeYoY: tourismChange,
                changeMoM: 0,
                sentiment: .bullish,
                message: "Turizmde rekor: Gelen turist sayısı %\(String(format: "%.0f", tourismChange)) arttı.",
                effects: [
                    OracleSectorEffect(
                        sectorCode: "XULAS",
                        impactedStocks: ["THYAO", "PGSUS", "TAVHL", "DOCO"],
                        scoreImpact: tourismChange * 0.8,
                        reason: "Turist akını doğrudan döviz geliri ve yolcu trafiği demektir."
                    )
                ],
                freshness: .delayed1M
            )
            signals.append(signal)
        }
        
        // 5. OTO (Auto Velocity)
        let autoChange = input.autoSalesChangeYoY
        if abs(autoChange) > 5.0 {
            let signal = OracleSignal(
                type: .autoVelocity,
                rawValue: input.autoSalesTotal,
                changeYoY: autoChange,
                changeMoM: 0,
                sentiment: autoChange > 0 ? .bullish : .bearish,
                message: autoChange > 0 
                    ? "Oto pazarı hareketli: Satışlar %\(String(format: "%.0f", autoChange)) büyüdü."
                    : "Oto satışlarında sert fren: Pazar %\(String(format: "%.0f", abs(autoChange))) daraldı.",
                effects: [
                    OracleSectorEffect(
                        sectorCode: "XMANA", // Metal Eşya (Oto dahil)
                        impactedStocks: ["FROTO", "TOASO", "DOAS", "TTRAK"],
                        scoreImpact: autoChange * 1.2,
                        reason: "Araç satış verisi otomotiv şirketlerinin cirosu için en net öncü göstergedir."
                    )
                ],
                freshness: .delayed1M // ODMD verisi
            )
            signals.append(signal)
        }
        
        return signals
    }
    
    // MARK: - Hisse Bazlı Sinyal
    
    func getSignals(for symbol: String) -> [OracleSignal] {
        // TODO: Implement specific stock signal logic based on sectors
        // For now return empty or basic signals
        return []
    }
}

/// Oracle Veri Giriş Modeli (Snapshot + Ekstra EVDS Verileri)
struct OracleDataInput: Sendable {
    // Macro Context
    let inflationYoY: Double
    
    // EVDS Specifics (Simulated or Fetched)
    let housingSalesTotal: Double
    let housingSalesChangeYoY: Double
    let housingSalesChangeMoM: Double
    
    let creditCardSpendingTotal: Double
    let creditCardSpendingChangeYoY: Double
    
    let capacityUsageRatio: Double
    let prevCapacityUsageRatio: Double
    
    let touristArrivalsTotal: Double
    let touristArrivalsChangeYoY: Double
    
    let autoSalesTotal: Double
    let autoSalesChangeYoY: Double
    
    // Varsayılan / Mock Veri Üretici (Ocak 2026 Context)
    static func mockJan2026(inflation: Double) -> OracleDataInput {
        return OracleDataInput(
            inflationYoY: inflation,
            
            // Konut: Faizler 38-40 bandında, konut hafif canlanıyor
            housingSalesTotal: 125000,
            housingSalesChangeYoY: 12.5, // Geçen seneki dipten dönüş
            housingSalesChangeMoM: 2.1,
            
            // Kredi Kartı: Enflasyonist ortamda harcama güçlü ama büyüme yavaşlıyor
            creditCardSpendingTotal: 250.0, // Milyar TL (Haftalık)
            creditCardSpendingChangeYoY: 45.0, // Nomimal artış (Enflasyon 30 ise Reel 15)
            
            // Sanayi: İhracat pazarları (EU) toparlanıyor
            capacityUsageRatio: 76.5,
            prevCapacityUsageRatio: 76.2,
            
            // Turizm: Kış sezonu ama YoY artış devam
            touristArrivalsTotal: 2.1, // Milyon (Ocak)
            touristArrivalsChangeYoY: 8.0,
            
            // Oto: ÖTV beklentisi vs ile dalgalı
            autoSalesTotal: 85000,
            autoSalesChangeYoY: -5.0 // Yüksek taşıt kredisi faizleri baskılıyor
        )
    }
}
