import Foundation
import Combine

// MARK: - Chiron Health Monitor
/// Açık pozisyonların "sağlık durumunu" izleyen ve skorlayan servis
/// Entry Snapshot ile güncel durumu karşılaştırarak pozisyon sağlığını değerlendirir

class ChironHealthMonitor: ObservableObject {
    static let shared = ChironHealthMonitor()
    
    @Published var healthScores: [UUID: PositionHealth] = [:] // tradeId -> health
    
    private init() {
        print("🏥 Chiron Health Monitor Online")
    }
    
    // MARK: - Health Calculation
    
    /// Bir pozisyonun sağlık skorunu hesapla
    func calculateHealth(
        trade: Trade,
        currentPrice: Double,
        currentOrionScore: Double?,
        currentGrandDecision: ArgusGrandDecision?,
        plan: PositionPlan?
    ) -> PositionHealth {
        
        let snapshot = plan?.originalSnapshot ?? EntrySnapshotStore.shared.getSnapshot(for: trade.id)
        
        // Alt skorları hesapla
        let planAdherence = calculatePlanAdherence(trade: trade, currentPrice: currentPrice, plan: plan)
        let technicalHealth = calculateTechnicalHealth(entryOrion: snapshot?.orionScore ?? 50, currentOrion: currentOrionScore ?? 50)
        let sentimentHealth = calculateSentimentHealth(entryAction: snapshot?.councilAction, currentDecision: currentGrandDecision)
        let timeHealth = calculateTimeHealth(entryDate: trade.entryDate)
        
        let health = PositionHealth(
            tradeId: trade.id,
            symbol: trade.symbol,
            calculatedAt: Date(),
            planAdherence: planAdherence,
            technicalHealth: technicalHealth,
            sentimentHealth: sentimentHealth,
            timeHealth: timeHealth,
            pnlPercent: ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100,
            daysHeld: Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
        )
        
        // Cache'e kaydet
        healthScores[trade.id] = health
        
        return health
    }
    
    /// Tüm açık pozisyonların sağlığını güncelle
    func updateAllHealth(
        trades: [Trade],
        quotes: [String: Quote],
        orionScores: [String: OrionScoreResult],
        grandDecisions: [String: ArgusGrandDecision],
        plans: [UUID: PositionPlan]
    ) {
        let openTrades = trades.filter { $0.isOpen }
        
        for trade in openTrades {
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let orionScore = orionScores[trade.symbol]?.score
            let grandDecision = grandDecisions[trade.symbol]
            let plan = plans[trade.id]
            
            _ = calculateHealth(
                trade: trade,
                currentPrice: currentPrice,
                currentOrionScore: orionScore,
                currentGrandDecision: grandDecision,
                plan: plan
            )
        }
    }
    
    // MARK: - Sub-Score Calculations
    
    /// Plan uyumu skoru (hedefler arasında mı, plana uygun gidiyor mu?)
    private func calculatePlanAdherence(trade: Trade, currentPrice: Double, plan: PositionPlan?) -> Int {
        guard let plan = plan else { return 50 } // Plan yoksa nötr
        
        var score = 50
        let entryPrice = plan.originalSnapshot.entryPrice
        let pnlPercent = ((currentPrice - entryPrice) / entryPrice) * 100
        
        // Bullish senaryodaki ilk hedefe yakınlık
        if let firstTarget = plan.bullishScenario.steps.first,
           case .priceAbove(let target) = firstTarget.trigger {
            let progressToTarget = (currentPrice - entryPrice) / (target - entryPrice)
            if progressToTarget > 0.8 { score += 25 }      // Hedefe çok yakın
            else if progressToTarget > 0.5 { score += 15 } // İyi ilerliyor
            else if progressToTarget > 0.2 { score += 5 }  // Yolda
        }
        
        // Bearish senaryodaki stop'a yakınlık (kötü)
        if let stopStep = plan.bearishScenario.steps.first,
           case .priceBelow(let stop) = stopStep.trigger {
            let riskToStop = (currentPrice - stop) / (entryPrice - stop)
            if riskToStop < 0.3 { score -= 25 }      // Stop'a çok yakın!
            else if riskToStop < 0.5 { score -= 15 } // Tehlikeli bölge
        }
        
        // Genel P&L etkisi
        if pnlPercent > 10 { score += 10 }
        else if pnlPercent > 5 { score += 5 }
        else if pnlPercent < -5 { score -= 10 }
        else if pnlPercent < -10 { score -= 20 }
        
        return max(0, min(100, score))
    }
    
    /// Teknik sağlık skoru (Orion değişimi)
    private func calculateTechnicalHealth(entryOrion: Double, currentOrion: Double) -> Int {
        var score = 50
        let orionDelta = currentOrion - entryOrion
        
        if orionDelta > 15 { score += 25 }       // Teknik güçlendi
        else if orionDelta > 5 { score += 10 }   
        else if orionDelta < -15 { score -= 25 } // Teknik zayıfladı
        else if orionDelta < -5 { score -= 10 }
        
        // Mutlak Orion değeri
        if currentOrion > 75 { score += 15 }
        else if currentOrion > 60 { score += 5 }
        else if currentOrion < 40 { score -= 15 }
        else if currentOrion < 50 { score -= 5 }
        
        return max(0, min(100, score))
    }
    
    /// Sentiment sağlık skoru (Council kararı değişimi)
    private func calculateSentimentHealth(entryAction: ArgusAction?, currentDecision: ArgusGrandDecision?) -> Int {
        var score = 50
        
        guard let currentAction = currentDecision?.action else { return score }
        guard let entryAction = entryAction else { return score }
        
        // Karar değişimi kontrolü
        let positiveActions: [ArgusAction] = [.aggressiveBuy, .accumulate]
        let negativeActions: [ArgusAction] = [.trim, .liquidate]
        
        let wasPositive = positiveActions.contains(entryAction)
        let isNowPositive = positiveActions.contains(currentAction)
        let isNowNegative = negativeActions.contains(currentAction)
        
        if wasPositive && isNowNegative {
            score -= 30 // Ciddi kötüleşme
        } else if wasPositive && !isNowPositive {
            score -= 15 // Orta kötüleşme
        } else if !wasPositive && isNowPositive {
            score += 20 // İyileşme
        }
        
        // Güven seviyesi
        if let confidence = currentDecision?.confidence {
            if confidence > 0.8 && isNowPositive { score += 10 }
            else if confidence > 0.8 && isNowNegative { score -= 15 }
            else if confidence < 0.5 { score -= 5 } // Düşük güven
        }
        
        return max(0, min(100, score))
    }
    
    /// Zaman sağlık skoru (çok uzun tutuldu mu?)
    private func calculateTimeHealth(entryDate: Date) -> Int {
        let daysHeld = Calendar.current.dateComponents([.day], from: entryDate, to: Date()).day ?? 0
        
        var score = 70 // Başlangıç
        
        // İlk hafta bonus
        if daysHeld < 7 { score = 80 }
        
        // Zaman geçtikçe azalan sağlık
        if daysHeld > 90 { score -= 30 }      // 3 ay+
        else if daysHeld > 60 { score -= 20 } // 2 ay+
        else if daysHeld > 30 { score -= 10 } // 1 ay+
        else if daysHeld > 14 { score -= 5 }  // 2 hafta+
        
        return max(0, min(100, score))
    }
    
    // MARK: - Aggregate Health
    
    /// Portföy genel sağlık ortalaması
    var averagePortfolioHealth: Int {
        guard !healthScores.isEmpty else { return 50 }
        let total = healthScores.values.reduce(0) { $0 + $1.overallScore }
        return total / healthScores.count
    }
    
    /// En sağlıksız pozisyonlar
    func getUnhealthyPositions(threshold: Int = 50) -> [PositionHealth] {
        return healthScores.values
            .filter { $0.overallScore < threshold }
            .sorted { $0.overallScore < $1.overallScore }
    }
}

// MARK: - Position Health Model

struct PositionHealth: Identifiable {
    let id = UUID()
    let tradeId: UUID
    let symbol: String
    let calculatedAt: Date
    
    // Alt Skorlar (0-100)
    let planAdherence: Int      // Plana uyum
    let technicalHealth: Int    // Teknik durum (Orion)
    let sentimentHealth: Int    // Karar değişimi
    let timeHealth: Int         // Zaman faktörü
    
    // Ek Bilgiler
    let pnlPercent: Double
    let daysHeld: Int
    
    // MARK: - Computed Properties
    
    /// Birleşik sağlık skoru (0-100)
    var overallScore: Int {
        // Ağırlıklı ortalama
        let weighted = (planAdherence * 30 + technicalHealth * 25 + sentimentHealth * 25 + timeHealth * 20) / 100
        return max(0, min(100, weighted))
    }
    
    /// Sağlık durumu emoji
    var emoji: String {
        switch overallScore {
        case 80...100: return "💚"
        case 60..<80: return "💛"
        case 40..<60: return "🧡"
        default: return "❤️"
        }
    }
    
    /// Sağlık durumu açıklaması
    var description: String {
        switch overallScore {
        case 80...100: return "Sağlıklı"
        case 60..<80: return "İzlenmeli"
        case 40..<60: return "Dikkat"
        default: return "Kritik"
        }
    }
    
    /// Sağlık rengi
    var color: String {
        switch overallScore {
        case 80...100: return "Green"
        case 60..<80: return "Yellow"
        case 40..<60: return "Orange"
        default: return "Red"
        }
    }
    
    /// Alt skor detayları
    var breakdownText: String {
        """
        Plan Uyumu: \(planAdherence)/100
        Teknik: \(technicalHealth)/100
        Sentiment: \(sentimentHealth)/100
        Zaman: \(timeHealth)/100
        """
    }
}
