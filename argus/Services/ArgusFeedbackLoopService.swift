import Foundation

/// RL-Lite: Self-Tuning Feedback Loop.
/// Analyzes historical trade performance to adjust strategy weights dynamically.
final class ArgusFeedbackLoopService: Sendable {
    static let shared = ArgusFeedbackLoopService()
    
    // Multipliers (Default 1.0)
    // Range: 0.5 (Penalty) to 1.5 (Bonus)
    private var corseMultiplier: Double = 1.0
    private var pulseMultiplier: Double = 1.0
    
    private init() {}
    
    /// Called periodically (e.g. weekly or on app launch) to tune system.
    func tuneSystem(history: [Trade]) {
        let closedTrades = history.filter { !$0.isOpen && $0.engine != nil }
        
        // Need min sample size
        let recentPulse = closedTrades.filter { $0.engine == .pulse }.suffix(20)
        let recentCorse = closedTrades.filter { $0.engine == .corse }.suffix(20)
        
        self.pulseMultiplier = calculateMultiplier(trades: Array(recentPulse), defaultVal: 1.0)
        self.corseMultiplier = calculateMultiplier(trades: Array(recentCorse), defaultVal: 1.0)
        
        print("🧠 RL-Lite Ayarlandı: Corse Çarpanı = \(String(format: "%.2f", corseMultiplier)), Pulse Çarpanı = \(String(format: "%.2f", pulseMultiplier))")
    }
    
    private func calculateMultiplier(trades: [Trade], defaultVal: Double) -> Double {
        // Minimum örneklem büyüklüğü: 5'ten az işlemde bilgisayar istatistiği
        // anlamlı değil; neutral (1.0) döneriz. Eski sürüm 1 işlemle bile
        // 0.70/1.30 uygularak aşırı reaktif davranıyordu.
        guard trades.count >= 5 else { return defaultVal }

        let wins = trades.filter {
            guard let exit = $0.exitPrice else { return false }
            return exit > $0.entryPrice
        }.count

        let winRate = Double(wins) / Double(trades.count)

        // Ortalama R-multiple (kazanan işlemlerin ortalama yüzde kazancı)
        // Eski mantık sadece win rate'e bakıyordu; "düşük WR ama büyük kazanç"
        // durumunda haksız yere ceza veriyordu.
        let pnlPercents: [Double] = trades.compactMap { trade in
            guard let exit = trade.exitPrice, trade.entryPrice > 0 else { return nil }
            return (exit - trade.entryPrice) / trade.entryPrice
        }
        let avgReturn = pnlPercents.isEmpty ? 0 : pnlPercents.reduce(0, +) / Double(pnlPercents.count)

        // Beklenen değer = (WR * avgWin) + ((1-WR) * avgLoss)
        // avgReturn bunun proxy'si. Pozitif → sistem çalışıyor, negatif → zarar.
        // Pragma: avgReturn expected edge.
        //
        // Tuning: WR ve avgReturn'ı birlikte değerlendir
        //  - WR < %40 + avgReturn < 0 → gerçekten kötü, 0.70 ceza
        //  - WR < %40 ama avgReturn > 0 → küçük kazanan ama kazanan, 0.90
        //  - WR > %60 + avgReturn > 0 → güçlü kombo, 1.30 bonus
        //  - WR > %60 ama avgReturn < 0 → "büyük kaybedip küçük kazanan" profili, 0.85
        //  - arası durumlar 1.0

        if winRate < 0.40 {
            return avgReturn < 0 ? 0.70 : 0.90
        } else if winRate > 0.60 {
            return avgReturn > 0 ? 1.30 : 0.85
        }
        return 1.0
    }
    
    // Public Accessors
    func getMultiplier(for engine: AutoPilotEngine) -> Double {
        switch engine {
        case .corse: return corseMultiplier
        case .pulse: return pulseMultiplier
        default: return 1.0
        }
    }
}
