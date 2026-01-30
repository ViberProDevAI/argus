import Foundation

// MARK: - Entry Snapshot
/// Alış anındaki tüm verileri kaydeden snapshot

struct EntrySnapshot: Codable {
    let id: UUID
    let tradeId: UUID
    let symbol: String
    let capturedAt: Date
    
    // MARK: - Grand Council Kararı
    let councilAction: ArgusAction
    let councilConfidence: Double
    let councilReasoning: String
    
    // MARK: - Modül Skorları
    let orionScore: Double
    let atlasScore: Double?
    let aetherStance: MacroStance
    let hermesScore: Double?
    
    // MARK: - Teknik Veriler
    let entryPrice: Double
    let rsi: Double?
    let atr: Double?                    // Average True Range (volatilite)
    let sma20: Double?
    let sma50: Double?
    let sma200: Double?
    let distanceFromATH: Double?        // ATH'den uzaklık %
    let distanceFrom52WeekLow: Double?  // 52 hafta dip'inden uzaklık %
    
    // MARK: - Destek/Direnç
    let nearestSupport: Double?
    let nearestResistance: Double?
    let trend: TrendDirection?
    
    // MARK: - Makro Veriler
    let vix: Double?
    let spyPrice: Double?
    let marketMode: MarketMode?
    
    // MARK: - Temel Veriler
    let lastEarningsDate: Date?
    let nextEarningsDate: Date?
    let peRatio: Double?
    let pbRatio: Double?
    let revenueGrowthYoY: Double?
    let netIncomeGrowthYoY: Double?
    
    init(
        tradeId: UUID,
        symbol: String,
        entryPrice: Double,
        grandDecision: ArgusGrandDecision,
        orionScore: Double,
        atlasScore: Double? = nil,
        technicalData: TechnicalSnapshotData? = nil,
        macroData: MacroSnapshotData? = nil,
        fundamentalData: FundamentalSnapshotData? = nil
    ) {
        self.id = UUID()
        self.tradeId = tradeId
        self.symbol = symbol
        self.capturedAt = Date()
        
        // Grand Council
        self.councilAction = grandDecision.action
        self.councilConfidence = grandDecision.confidence
        self.councilReasoning = grandDecision.reasoning
        
        // Modül Skorları
        self.orionScore = orionScore
        self.atlasScore = atlasScore
        self.aetherStance = grandDecision.aetherDecision.stance
        self.hermesScore = nil // Hermes skorunu ayrı tutmuyoruz şimdilik
        
        // Teknik
        self.entryPrice = entryPrice
        self.rsi = technicalData?.rsi
        self.atr = technicalData?.atr
        self.sma20 = technicalData?.sma20
        self.sma50 = technicalData?.sma50
        self.sma200 = technicalData?.sma200
        self.distanceFromATH = technicalData?.distanceFromATH
        self.distanceFrom52WeekLow = technicalData?.distanceFrom52WeekLow
        self.nearestSupport = technicalData?.nearestSupport
        self.nearestResistance = technicalData?.nearestResistance
        self.trend = technicalData?.trend
        
        // Makro
        self.vix = macroData?.vix
        self.spyPrice = macroData?.spyPrice
        self.marketMode = macroData?.marketMode
        
        // Temel
        self.lastEarningsDate = fundamentalData?.lastEarningsDate
        self.nextEarningsDate = fundamentalData?.nextEarningsDate
        self.peRatio = fundamentalData?.peRatio
        self.pbRatio = fundamentalData?.pbRatio
        self.revenueGrowthYoY = fundamentalData?.revenueGrowthYoY
        self.netIncomeGrowthYoY = fundamentalData?.netIncomeGrowthYoY
    }
    
    // MARK: - Entry Quality Score
    
    /// Giriş kalitesini 0-100 arasında skorlar
    /// Yüksek skor = İyi zamanlama ile yapılmış giriş
    var entryQualityScore: Int {
        var score = 50 // Başlangıç (nötr)
        
        // 1. RSI Analizi (Aşırı satımda giriş iyi)
        if let rsi = rsi {
            if rsi < 35 { score += 15 }       // Aşırı satım - harika giriş
            else if rsi < 45 { score += 10 }  // Düşük RSI - iyi giriş
            else if rsi > 70 { score -= 15 }  // Aşırı alım - kötü giriş
            else if rsi > 60 { score -= 5 }   // Yüksek RSI - riskli
        }
        
        // 2. Orion Score (Teknik güç)
        if orionScore > 80 { score += 15 }
        else if orionScore > 65 { score += 10 }
        else if orionScore < 40 { score -= 10 }
        
        // 3. Council Kararı
        switch councilAction {
        case .aggressiveBuy: score += 15
        case .accumulate: score += 10
        case .neutral: score += 0
        case .trim: score -= 10
        case .liquidate: score -= 20
        }
        
        // 4. Council Confidence
        if councilConfidence > 0.8 { score += 10 }
        else if councilConfidence < 0.5 { score -= 5 }
        
        // 5. VIX Analizi (Düşük VIX = sakin piyasa)
        if let vix = vix {
            if vix < 15 { score += 5 }        // Çok sakin
            else if vix < 20 { score += 3 }   // Normal
            else if vix > 30 { score -= 10 }  // Korku
            else if vix > 25 { score -= 5 }   // Endişe
        }
        
        // 6. Makro Stance
        switch aetherStance {
        case .riskOn: score += 10
        case .cautious: score += 0
        case .defensive: score -= 5
        case .riskOff: score -= 15
        }
        
        // 7. Atlas Score (Temel Analiz)
        if let atlas = atlasScore {
            if atlas > 75 { score += 10 }
            else if atlas > 60 { score += 5 }
            else if atlas < 40 { score -= 5 }
        }
        
        return max(0, min(100, score))
    }
    
    /// Giriş kalitesi emoji'si
    var entryQualityEmoji: String {
        switch entryQualityScore {
        case 80...100: return "⭐⭐⭐⭐⭐"
        case 65..<80: return "⭐⭐⭐⭐"
        case 50..<65: return "⭐⭐⭐"
        case 35..<50: return "⭐⭐"
        default: return "⭐"
        }
    }
    
    /// Giriş kalitesi açıklaması
    var entryQualityDescription: String {
        switch entryQualityScore {
        case 80...100: return "Mükemmel Zamanlama"
        case 65..<80: return "İyi Giriş"
        case 50..<65: return "Ortalama"
        case 35..<50: return "Zayıf Zamanlama"
        default: return "Kötü Giriş"
        }
    }
}

// MARK: - Helper Structs

struct TechnicalSnapshotData {
    let rsi: Double?
    let atr: Double?
    let sma20: Double?
    let sma50: Double?
    let sma200: Double?
    let distanceFromATH: Double?
    let distanceFrom52WeekLow: Double?
    let nearestSupport: Double?
    let nearestResistance: Double?
    let trend: TrendDirection?
}

struct MacroSnapshotData {
    let vix: Double?
    let spyPrice: Double?
    let marketMode: MarketMode?
}

struct FundamentalSnapshotData {
    let lastEarningsDate: Date?
    let nextEarningsDate: Date?
    let peRatio: Double?
    let pbRatio: Double?
    let revenueGrowthYoY: Double?
    let netIncomeGrowthYoY: Double?
}

enum TrendDirection: String, Codable {
    case strongUp = "GÜÇLÜ YUKARI"
    case up = "YUKARI"
    case sideways = "YATAY"
    case down = "AŞAĞI"
    case strongDown = "GÜÇLÜ AŞAĞI"
}

// MARK: - Entry Snapshot Store

class EntrySnapshotStore {
    static let shared = EntrySnapshotStore()
    
    private var snapshots: [UUID: EntrySnapshot] = [:]  // tradeId -> snapshot
    private let persistenceKey = "ArgusEntrySnapshots"
    
    private init() {
        loadSnapshots()
    }
    
    // MARK: - Public API
    
    func getSnapshot(for tradeId: UUID) -> EntrySnapshot? {
        return snapshots[tradeId]
    }
    
    func hasSnapshot(for tradeId: UUID) -> Bool {
        return snapshots[tradeId] != nil
    }
    
    @discardableResult
    func captureSnapshot(
        for trade: Trade,
        grandDecision: ArgusGrandDecision,
        orionScore: Double,
        atlasScore: Double? = nil,
        technicalData: TechnicalSnapshotData? = nil,
        macroData: MacroSnapshotData? = nil,
        fundamentalData: FundamentalSnapshotData? = nil
    ) -> EntrySnapshot {
        let snapshot = EntrySnapshot(
            tradeId: trade.id,
            symbol: trade.symbol,
            entryPrice: trade.entryPrice,
            grandDecision: grandDecision,
            orionScore: orionScore,
            atlasScore: atlasScore,
            technicalData: technicalData,
            macroData: macroData,
            fundamentalData: fundamentalData
        )
        
        snapshots[trade.id] = snapshot
        saveSnapshots()
        
        print("📸 Entry Snapshot kaydedildi: \(trade.symbol)")
        print("   Council: \(snapshot.councilAction.rawValue) (\(String(format: "%.0f", snapshot.councilConfidence * 100))%)")
        print("   Orion: \(String(format: "%.0f", snapshot.orionScore))")
        if let atr = snapshot.atr {
            print("   ATR: \(String(format: "%.2f", atr))")
        }
        
        return snapshot
    }
    
    func removeSnapshot(for tradeId: UUID) {
        snapshots.removeValue(forKey: tradeId)
        saveSnapshots()
    }
    
    // MARK: - Persistence
    
    private func saveSnapshots() {
        do {
            let data = try JSONEncoder().encode(Array(snapshots.values))
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ Snapshot kaydetme hatası: \(error)")
        }
    }
    
    private func loadSnapshots() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            let loaded = try JSONDecoder().decode([EntrySnapshot].self, from: data)
            for snapshot in loaded {
                snapshots[snapshot.tradeId] = snapshot
            }
            print("📸 \(loaded.count) entry snapshot yüklendi")
        } catch {
            print("❌ Snapshot yükleme hatası: \(error)")
        }
    }
}
