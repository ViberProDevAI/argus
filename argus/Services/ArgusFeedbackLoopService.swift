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
        guard !trades.isEmpty else { return defaultVal }
        
        // Calculate Win Rate
        let wins = trades.filter {
            guard let exit = $0.exitPrice else { return false }
            return exit > $0.entryPrice
        }.count
        
        let winRate = Double(wins) / Double(trades.count)
        
        // Tuning Logic
        // Benchmark: 50% Win Rate usually OK if Risk/Reward is 1:2.
        // But for Pulse (Scalp), we want high win rate usually? Or strict stops?
        // Let's assume:
        // WR < 40% -> Punishment (Market is choppy/bad for this logic)
        // WR > 60% -> Reward (Market aligns with strategy)
        
        if winRate < 0.40 {
            return 0.70 // Reduce exposure by 30%
        } else if winRate > 0.60 {
            return 1.30 // Boost exposure by 30%
        }
        
        return 1.0 // Neutral
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
