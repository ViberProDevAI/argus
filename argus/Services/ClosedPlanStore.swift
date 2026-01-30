import Foundation
import Combine

// MARK: - Closed Plan Store
/// Kapatılan pozisyonların plan performansını takip eden store

class ClosedPlanStore: ObservableObject {
    static let shared = ClosedPlanStore()
    
    @Published var stats: [ClosedPlanStats] = []
    
    private let persistenceKey = "ArgusClosedPlanStats"
    
    private init() {
        loadStats()
    }
    
    // MARK: - Recording
    
    /// Trade kapatıldığında plan istatistiğini kaydet
    func recordClosedPlan(
        trade: Trade,
        plan: PositionPlan?,
        exitPrice: Double,
        closedBy: ClosureReason
    ) {
        let entryPrice = plan?.originalSnapshot.entryPrice ?? trade.entryPrice
        let pnlAmount = (exitPrice - entryPrice) * trade.quantity
        let pnlPercent = ((exitPrice - entryPrice) / entryPrice) * 100
        let daysHeld = Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
        
        // Hedeflere ulaşım kontrolü
        var reachedTarget1 = false
        var reachedTarget2 = false
        var reachedTarget3 = false
        var hitStop = false
        
        if let plan = plan {
            // Bullish scenario hedeflerini kontrol et
            for (index, step) in plan.bullishScenario.steps.enumerated() {
                if plan.executedSteps.contains(step.id) {
                    switch index {
                    case 0: reachedTarget1 = true
                    case 1: reachedTarget2 = true
                    case 2: reachedTarget3 = true
                    default: break
                    }
                }
            }
            
            // Bearish scenario (stop) kontrolü
            for step in plan.bearishScenario.steps {
                if plan.executedSteps.contains(step.id) {
                    hitStop = true
                    break
                }
            }
        }
        
        let stat = ClosedPlanStats(
            id: UUID(),
            tradeId: trade.id,
            symbol: trade.symbol,
            intent: plan?.intent ?? .undefined,
            closedAt: Date(),
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            pnlPercent: pnlPercent,
            pnlAmount: pnlAmount,
            daysHeld: daysHeld,
            isWin: pnlPercent > 0,
            reachedTarget1: reachedTarget1,
            reachedTarget2: reachedTarget2,
            reachedTarget3: reachedTarget3,
            hitStop: hitStop,
            closedBy: closedBy
        )
        
        stats.append(stat)
        saveStats()
        
        print("📊 Plan Performans Kaydedildi: \(trade.symbol)")
        print("   PnL: \(String(format: "%.1f", pnlPercent))% | Intent: \(stat.intent.rawValue)")
        print("   Hedefler: T1=\(reachedTarget1) T2=\(reachedTarget2) T3=\(reachedTarget3) | Stop=\(hitStop)")
    }
    
    // MARK: - Analytics
    
    /// Intent bazlı win rate
    var winRateByIntent: [TradeIntent: (wins: Int, total: Int, rate: Double)] {
        var result: [TradeIntent: (wins: Int, total: Int, rate: Double)] = [:]
        
        let grouped = Dictionary(grouping: stats) { $0.intent }
        
        for (intent, intentStats) in grouped {
            let wins = intentStats.filter { $0.isWin }.count
            let total = intentStats.count
            let rate = total > 0 ? Double(wins) / Double(total) * 100 : 0
            result[intent] = (wins, total, rate)
        }
        
        return result
    }
    
    /// Genel win rate
    var overallWinRate: Double {
        guard !stats.isEmpty else { return 0 }
        let wins = stats.filter { $0.isWin }.count
        return Double(wins) / Double(stats.count) * 100
    }
    
    /// Ortalama tutma süresi
    var avgHoldingDays: Double {
        guard !stats.isEmpty else { return 0 }
        let totalDays = stats.reduce(0) { $0 + $1.daysHeld }
        return Double(totalDays) / Double(stats.count)
    }
    
    /// Hedef ulaşım oranları
    var targetReachRates: (t1: Double, t2: Double, t3: Double) {
        guard !stats.isEmpty else { return (0, 0, 0) }
        let t1 = Double(stats.filter { $0.reachedTarget1 }.count) / Double(stats.count) * 100
        let t2 = Double(stats.filter { $0.reachedTarget2 }.count) / Double(stats.count) * 100
        let t3 = Double(stats.filter { $0.reachedTarget3 }.count) / Double(stats.count) * 100
        return (t1, t2, t3)
    }
    
    /// Stop yeme oranı
    var stopHitRate: Double {
        guard !stats.isEmpty else { return 0 }
        return Double(stats.filter { $0.hitStop }.count) / Double(stats.count) * 100
    }
    
    /// Ortalama kazanç/kayıp
    var avgPnL: (avgWin: Double, avgLoss: Double, expectancy: Double) {
        let wins = stats.filter { $0.isWin }
        let losses = stats.filter { !$0.isWin }
        
        let avgWin = wins.isEmpty ? 0 : wins.reduce(0) { $0 + $1.pnlPercent } / Double(wins.count)
        let avgLoss = losses.isEmpty ? 0 : losses.reduce(0) { $0 + $1.pnlPercent } / Double(losses.count)
        
        // Expectancy = (Win% × AvgWin) + (Loss% × AvgLoss)
        let winPct = stats.isEmpty ? 0 : Double(wins.count) / Double(stats.count)
        let lossPct = stats.isEmpty ? 0 : Double(losses.count) / Double(stats.count)
        let expectancy = (winPct * avgWin) + (lossPct * avgLoss)
        
        return (avgWin, avgLoss, expectancy)
    }
    
    // MARK: - Persistence
    
    private func saveStats() {
        do {
            let data = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ ClosedPlanStats kaydetme hatası: \(error)")
        }
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            stats = try JSONDecoder().decode([ClosedPlanStats].self, from: data)
            print("📊 \(stats.count) closed plan stats yüklendi")
        } catch {
            print("❌ ClosedPlanStats yükleme hatası: \(error)")
        }
    }
    
    func clearStats() {
        stats.removeAll()
        saveStats()
    }
}

// MARK: - Models

struct ClosedPlanStats: Codable, Identifiable {
    let id: UUID
    let tradeId: UUID
    let symbol: String
    let intent: TradeIntent
    let closedAt: Date
    let entryPrice: Double
    let exitPrice: Double
    let pnlPercent: Double
    let pnlAmount: Double
    let daysHeld: Int
    let isWin: Bool
    let reachedTarget1: Bool
    let reachedTarget2: Bool
    let reachedTarget3: Bool
    let hitStop: Bool
    let closedBy: ClosureReason
}

enum ClosureReason: String, Codable {
    case target = "HEDEF"
    case stop = "STOP"
    case manual = "MANUEL"
    case council = "COUNCIL"
    case timeout = "SÜRE_AŞIMI"
    case planExecution = "PLAN"
}
