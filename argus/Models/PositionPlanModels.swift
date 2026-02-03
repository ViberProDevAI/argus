import Foundation

// MARK: - Position Plan (Trade Brain)
/// Her açık pozisyon için hafıza ve senaryo planı

// MARK: - Plan Trigger Event
/// Plan tetiklemesi kaydı
struct PlanTriggerEvent: Codable, Identifiable {
    let id: UUID = UUID()
    let planId: UUID
    let symbol: String
    let triggeredAt: Date
}

struct PositionPlan: Codable, Identifiable {
    let id: UUID
    let tradeId: UUID
    let symbol: String // For quick access to symbol (from EntrySnapshot)
    let dateCreated: Date
    let originalSnapshot: EntrySnapshot
    let initialQuantity: Double

    // Plan Context
    let thesis: String
    let invalidation: String
    
    // Execution State
    var executedSteps: [UUID]
    var status: PlanStatus // Optional: If we want to map .active
    var lastUpdated: Date
    
    // FAZE 2.2: Trailing stop tracking
    var highestPrice: Double = 0.0
    var trailingStopPrice: Double? = nil
    
    // Vortex Core Data
    var intent: TradeIntent // Neden aldık?
    var journeyLog: [PlanRevision] // Planın evrimi
    
    // Scenarios
    var bullishScenario: Scenario
    var bearishScenario: Scenario
    var neutralScenario: Scenario?
    
    var isActive: Bool
    
    init(tradeId: UUID, snapshot: EntrySnapshot, initialQuantity: Double, thesis: String, invalidation: String, bullish: Scenario, bearish: Scenario, neutral: Scenario? = nil, intent: TradeIntent = .undefined) {
        self.id = UUID()
        self.tradeId = tradeId
        self.symbol = snapshot.symbol
        self.dateCreated = Date()
        self.originalSnapshot = snapshot
        self.initialQuantity = initialQuantity
        self.thesis = thesis
        self.invalidation = invalidation
        
        self.executedSteps = []
        self.status = .active
        self.lastUpdated = Date()
        
        self.intent = intent
        self.journeyLog = []
        
        self.bullishScenario = bullish
        self.bearishScenario = bearish
        self.neutralScenario = neutral
        self.isActive = true
    }

    // MARK: - Computed Properties

    /// Convenience property for accessing quantity (same as initialQuantity)
    var quantity: Double {
        return initialQuantity
    }
}



enum PlanStatus: String, Codable {
    case active = "AKTİF"           // Plan devam ediyor
    case completed = "TAMAMLANDI"   // Pozisyon kapatıldı
    case invalidated = "GEÇERSİZ"   // Tez geçersiz oldu
    case paused = "DURDURULDU"      // Manuel durdurma
}

// MARK: - Scenario
/// Boğa/Ayı/Nötr senaryoları

// MARK: - Vortex Models
enum TradeIntent: String, Codable, CaseIterable {
    case valueInvestment = "Değer Yatırımı"         // Atlas Baskın (Uzun Vade)
    case momentumTrade = "Momentum Trade"           // Orion Baskın (Kısa Vade/Sniper)
    case speculativeSniper = "Spekülatif Sniper"    // Haber/Hacim Baskın (Çok Kısa)
    case technicalSwing = "Teknik Swing"            // Swing (Orta Vade)
    case undefined = "Tanımsız"
    
    var icon: String {
        switch self {
        case .valueInvestment: return "building.columns.fill" // Banka/Yatırım
        case .momentumTrade: return "bolt.fill"               // Hız
        case .speculativeSniper: return "scope"               // Sniper Dürbünü
        case .technicalSwing: return "arrow.triangle.swap"    // Dalga
        case .undefined: return "questionmark.circle"
        }
    }
    
    var colorName: String {
        switch self {
        case .valueInvestment: return "Blue"
        case .momentumTrade: return "Orange"
        case .speculativeSniper: return "Red"
        case .technicalSwing: return "Purple"
        case .undefined: return "Gray"
        }
    }
}

struct PlanRevision: Codable, Identifiable {
    var id: UUID = UUID()
    let timestamp: Date
    let reason: String
    let changeDescription: String // Örn: "Hedef 100 -> 105"
    let triggeredBy: String // "Vortex Auto", "User Manual", "Chiron"
}

struct Scenario: Codable, Identifiable {
    let id: UUID
    let type: ScenarioType
    var steps: [PlannedAction]
    var isActive: Bool              // Bu senaryo aktif mi?
    
    init(type: ScenarioType, steps: [PlannedAction], isActive: Bool = false) {
        self.id = UUID()
        self.type = type
        self.steps = steps
        self.isActive = isActive
    }
}

enum ScenarioType: String, Codable {
    case bullish = "BOĞA"           // Fiyat yükseliyor
    case neutral = "NÖTR"           // Fiyat yatay
    case bearish = "AYI"            // Fiyat düşüyor
}

// MARK: - Planned Action
/// Önceden planlanmış aksiyon

struct PlannedAction: Codable, Identifiable {
    let id: UUID
    let trigger: ActionTrigger
    let action: ActionType
    let description: String
    var priority: Int               // Düşük = önce çalışır
    
    init(trigger: ActionTrigger, action: ActionType, description: String, priority: Int = 0) {
        self.id = UUID()
        self.trigger = trigger
        self.action = action
        self.description = description
        self.priority = priority
    }
}

// MARK: - Action Trigger
/// Aksiyonu tetikleyen koşullar

enum ActionTrigger: Codable, Equatable {
    // BASIC
    case priceAbove(Double)             // Fiyat X üstüne çıkarsa
    case priceBelow(Double)             // Fiyat X altına düşerse
    case gainPercent(Double)            // Kâr %X olursa
    case lossPercent(Double)            // Zarar %X olursa
    case daysElapsed(Int)               // X gün geçerse
    case councilSignal(CouncilSignal)   // Konsey sinyali
    case priceAndTime(Double, Int)      // Fiyat + Zaman kombinasyonu
    
    // ADVANCED - Trailing & ATR
    case trailingStop(percent: Double)          // %X trailing stop
    case atrMultiple(multiplier: Double)        // ATR × X stop/hedef
    case entryAtrStop(multiplier: Double)       // Giriş ATR × X stop
    
    // ADVANCED - Teknik
    case rsiOverbought(threshold: Double)       // RSI > X (varsayılan 70)
    case rsiOversold(threshold: Double)         // RSI < X (varsayılan 30)
    case crossBelow(indicator: String)          // SMA200 altına düşerse
    case crossAbove(indicator: String)          // SMA50 üstüne çıkarsa
    case priceAboveEntry(percent: Double)       // Girişin %X üstünde
    case priceBelowEntry(percent: Double)       // Girişin %X altında
    
    // ADVANCED - Zaman
    case daysWithoutProgress(days: Int, minGain: Double)  // X gün %Y kâr yapamadıysa
    case earningsWithin(days: Int)              // Bilanço X gün içinde
    case maxHoldingDays(Int)                    // Maksimum tutma süresi
    
    // ADVANCED - Council/Delta
    case councilActionChanged(from: ArgusAction, to: ArgusAction)  // Karar değişti
    case councilConfidenceDropped(below: Double)    // Güven X altına düştü
    case orionScoreDropped(by: Double)              // Orion X puan düştü
    case deltaExceeds(threshold: Double)            // Delta skoru X'i geçti
    
    // ADVANCED - Market
    case marketModeChanged(to: MarketMode)          // Piyasa modu değişti
    case vixAbove(Double)                           // VIX > X
    case vixBelow(Double)                           // VIX < X
    case spyDropped(percent: Double)                // SPY %X düştü
    
    enum CouncilSignal: String, Codable {
        case trim = "AZALT"
        case liquidate = "ÇIK"
        case accumulate = "BİRİKTİR"
        case aggressive = "HÜCUM"
    }
    
    var displayText: String {
        switch self {
        // Basic
        case .priceAbove(let price): return "Fiyat > \(String(format: "%.2f", price))"
        case .priceBelow(let price): return "Fiyat < \(String(format: "%.2f", price))"
        case .gainPercent(let pct): return "Kâr > %\(Int(pct))"
        case .lossPercent(let pct): return "Zarar > %\(Int(pct))"
        case .daysElapsed(let days): return "\(days) gün geçerse"
        case .councilSignal(let sig): return "Konsey: \(sig.rawValue)"
        case .priceAndTime(let price, let days): return "\(days) gün içinde \(String(format: "%.2f", price))"
        
        // Trailing & ATR
        case .trailingStop(let pct): return "İz süren stop %\(Int(pct))"
        case .atrMultiple(let mult): return "ATR × \(String(format: "%.1f", mult))"
        case .entryAtrStop(let mult): return "Giriş ATR × \(String(format: "%.1f", mult))"
        
        // Teknik
        case .rsiOverbought(let th): return "RSI > \(Int(th))"
        case .rsiOversold(let th): return "RSI < \(Int(th))"
        case .crossBelow(let ind): return "\(ind) altına kırılım"
        case .crossAbove(let ind): return "\(ind) üstüne kırılım"
        case .priceAboveEntry(let pct): return "Girişin %\(Int(pct)) üstü"
        case .priceBelowEntry(let pct): return "Girişin %\(Int(pct)) altı"
        
        // Zaman
        case .daysWithoutProgress(let d, let g): return "\(d) gün %\(Int(g)) kâr yok"
        case .earningsWithin(let days): return "Bilanço \(days) gün içinde"
        case .maxHoldingDays(let days): return "Maks tutma: \(days) gün"
        
        // Council/Delta
        case .councilActionChanged(let from, let to): return "Karar: \(from.rawValue) → \(to.rawValue)"
        case .councilConfidenceDropped(let th): return "Güven < %\(Int(th * 100))"
        case .orionScoreDropped(let pts): return "Orion \(Int(pts)) puan düştü"
        case .deltaExceeds(let th): return "Delta > \(Int(th))"
        
        // Market
        case .marketModeChanged(let mode): return "Piyasa: \(mode.rawValue)"
        case .vixAbove(let v): return "VIX > \(Int(v))"
        case .vixBelow(let v): return "VIX < \(Int(v))"
        case .spyDropped(let pct): return "SPY %\(Int(pct)) düştü"
        }
    }
    
    var category: TriggerCategory {
        switch self {
        case .priceAbove, .priceBelow, .gainPercent, .lossPercent, .priceAboveEntry, .priceBelowEntry:
            return .price
        case .trailingStop, .atrMultiple, .entryAtrStop:
            return .stop
        case .rsiOverbought, .rsiOversold, .crossBelow, .crossAbove:
            return .technical
        case .daysElapsed, .daysWithoutProgress, .earningsWithin, .maxHoldingDays, .priceAndTime:
            return .time
        case .councilSignal, .councilActionChanged, .councilConfidenceDropped, .orionScoreDropped, .deltaExceeds:
            return .council
        case .marketModeChanged, .vixAbove, .vixBelow, .spyDropped:
            return .market
        }
    }
}

enum TriggerCategory: String {
    case price = "Fiyat"
    case stop = "Stop"
    case technical = "Teknik"
    case time = "Zaman"
    case council = "Konsey"
    case market = "Piyasa"
}

// MARK: - Action Type
/// Yapılacak aksiyon türleri

enum ActionType: Codable, Equatable {
    // SATIŞ
    case sellPercent(Double)            // Pozisyonun %X'ini sat
    case sellAll                        // Tamamını sat
    
    // ALIM
    case addPercent(Double)             // Pozisyona %X ekle
    case addFixed(Double)               // Sabit miktar ekle
    
    // STOP YÖNETİMİ
    case moveStopTo(Double)             // Stop'u X'e taşı
    case moveStopByPercent(Double)      // Stop'u %X yukarı taşı
    case activateTrailingStop(Double)   // %X iz süren stop aktifleştir
    case setBreakeven                   // Stop'u entry'ye taşı
    
    // DİĞER
    case doNothing                      // Bekle
    case reevaluate                     // Yeniden değerlendir
    case reduceAndHold(Double)          // %X azalt ve tut
    case alert(String)                  // Uyarı ver
    
    var displayText: String {
        switch self {
        case .sellPercent(let pct): return "%\(Int(pct)) sat"
        case .sellAll: return "Tamamını sat"
        case .addPercent(let pct): return "%\(Int(pct)) ekle"
        case .addFixed(let amt): return "\(String(format: "%.0f", amt)) ekle"
        case .moveStopTo(let price): return "Stop: \(String(format: "%.2f", price))"
        case .moveStopByPercent(let pct): return "Stop %\(Int(pct)) yukarı"
        case .activateTrailingStop(let pct): return "Trailing %\(Int(pct)) aktif"
        case .setBreakeven: return "Başabaşa stop"
        case .doNothing: return "Bekle"
        case .reevaluate: return "Yeniden değerlendir"
        case .reduceAndHold(let pct): return "%\(Int(pct)) azalt, tut"
        case .alert(let msg): return "Uyarı: \(msg)"
        }
    }
}

// MARK: - Plan Templates
/// Grand Council kararlarına göre varsayılan planlar

struct PlanTemplates {
    
    /// Hücum kararı için varsayılan plan
    static func aggressive(entryPrice: Double) -> [Scenario] {
        let stopPrice = entryPrice * 0.92  // -%8 stop
        
        return [
            // BOĞA SENARYosu
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .gainPercent(15),
                    action: .sellPercent(30),
                    description: "%15 kârda ilk %30 sat",
                    priority: 1
                ),
                PlannedAction(
                    trigger: .gainPercent(25),
                    action: .sellPercent(30),
                    description: "%25 kârda ikinci %30 sat",
                    priority: 2
                ),
                PlannedAction(
                    trigger: .gainPercent(35),
                    action: .sellAll,
                    description: "%35 kârda kalanı sat",
                    priority: 3
                )
            ], isActive: true),
            
            // AYI SENARYosu
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop tetiklendi, tamamını sat",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    /// Biriktir kararı için varsayılan plan
    static func accumulate(entryPrice: Double) -> [Scenario] {
        let stopPrice = entryPrice * 0.90  // -%10 stop
        
        return [
            // BOĞA SENARYOSU
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .gainPercent(20),
                    action: .sellPercent(50),
                    description: "%20 kârda yarısını sat",
                    priority: 1
                ),
                PlannedAction(
                    trigger: .gainPercent(30),
                    action: .sellAll,
                    description: "%30 kârda kalanı sat",
                    priority: 2
                )
            ], isActive: true),
            
            // AYI SENARYOSU
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop tetiklendi, tamamını sat",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    /// Nötr/Gözle için varsayılan plan (sadece stop)
    static func neutral(entryPrice: Double) -> [Scenario] {
        let stopPrice = entryPrice * 0.95  // -%5 stop
        
        return [
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop tetiklendi",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
}
