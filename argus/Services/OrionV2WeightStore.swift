import Foundation

// MARK: - Orion V2 Component Weights
/// Weights for Orion V2 internal components (Structure, Trend, Momentum, Pattern)
struct OrionV2Weights: Codable, Sendable {
    var structure: Double   // Max: 35
    var trend: Double       // Max: 25
    var momentum: Double    // Max: 25
    var pattern: Double     // Max: 15
    
    let updatedAt: Date
    let confidence: Double
    let reasoning: String
    
    // Default weights (V2 design)
    static var `default`: OrionV2Weights {
        OrionV2Weights(
            structure: 0.35,
            trend: 0.25,
            momentum: 0.25,
            pattern: 0.15,
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "Varsayılan Orion V2 ağırlıkları"
        )
    }
    
    // Calculated total (should be 1.0)
    var total: Double {
        structure + trend + momentum + pattern
    }
    
    // Normalized weights (ensure they sum to 1.0)
    func normalized() -> OrionV2Weights {
        let sum = total
        guard sum > 0 else { return .default }
        return OrionV2Weights(
            structure: structure / sum,
            trend: trend / sum,
            momentum: momentum / sum,
            pattern: pattern / sum,
            updatedAt: updatedAt,
            confidence: confidence,
            reasoning: reasoning
        )
    }
}

// MARK: - Orion V2 Weight Store
/// Persists Orion V2 component weights per symbol
@MainActor
final class OrionV2WeightStore {
    static let shared = OrionV2WeightStore()
    
    private var cache: [String: OrionV2Weights] = [:]
    private let fileURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("orion_v2_weights.json")
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func getWeights(symbol: String) -> OrionV2Weights {
        cache[symbol] ?? .default
    }
    
    func updateWeights(symbol: String, weights: OrionV2Weights) {
        cache[symbol] = weights.normalized()
        saveToDisk()
        print("🧠 OrionV2WeightStore: \(symbol) güncellendi - S:\(Int(weights.structure * 100))% T:\(Int(weights.trend * 100))% M:\(Int(weights.momentum * 100))% P:\(Int(weights.pattern * 100))%")
    }
    
    /// Optimize weights based on backtest performance
    func optimizeFromBacktest(
        symbol: String,
        trades: [BacktestTrade],
        logs: [BacktestDayLog]
    ) {
        guard trades.count >= 3 else {
            print("🧠 OrionV2: Yeterli trade yok (\(trades.count) < 3)")
            return
        }
        
        let currentWeights = getWeights(symbol: symbol)
        
        // Analyze which components contributed to wins vs losses
        var componentScores: [String: (wins: Double, losses: Double, count: Int)] = [
            "structure": (0, 0, 0),
            "trend": (0, 0, 0),
            "momentum": (0, 0, 0),
            "pattern": (0, 0, 0)
        ]
        
        // For simplicity, we attribute success based on overall win rate
        // In a real system, you'd look at which scores were high during wins
        let winRate = Double(trades.filter { $0.pnl > 0 }.count) / Double(trades.count)
        
        // Adjust weights based on performance (simple heuristic)
        var newWeights = currentWeights
        
        // If win rate > 60%, boost momentum (good timing)
        // If win rate < 40%, reduce momentum, boost structure (need better structure)
        if winRate > 0.6 {
            newWeights.momentum = min(0.35, currentWeights.momentum * 1.1)
            newWeights.structure = max(0.20, currentWeights.structure * 0.95)
        } else if winRate < 0.4 {
            newWeights.structure = min(0.45, currentWeights.structure * 1.1)
            newWeights.momentum = max(0.15, currentWeights.momentum * 0.9)
            newWeights.trend = max(0.15, currentWeights.trend * 0.95)
        }
        
        // Normalize and save
        let optimized = OrionV2Weights(
            structure: newWeights.structure,
            trend: newWeights.trend,
            momentum: newWeights.momentum,
            pattern: newWeights.pattern,
            updatedAt: Date(),
            confidence: min(0.95, currentWeights.confidence + 0.05),
            reasoning: "Auto-Tune: Win Rate \(String(format: "%.1f", winRate * 100))%"
        ).normalized()
        
        updateWeights(symbol: symbol, weights: optimized)
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            cache = try JSONDecoder().decode([String: OrionV2Weights].self, from: data)
            print("🧠 OrionV2WeightStore: \(cache.count) sembol yüklendi")
        } catch {
            print("🧠 OrionV2WeightStore: Load error - \(error.localizedDescription)")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL)
        } catch {
            print("🧠 OrionV2WeightStore: Save error - \(error.localizedDescription)")
        }
    }
}
