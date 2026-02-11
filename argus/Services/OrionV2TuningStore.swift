import Foundation

// MARK: - Orion V2 Tuning Configuration
/// All tunable parameters for Orion V2 scoring and trading
struct OrionV2TuningConfig: Codable, Sendable {
    
    // MARK: - Component Weights (should sum to 1.0)
    var structureWeight: Double  // Default: 0.30, Range: 0.15 - 0.45
    var trendWeight: Double      // Default: 0.30, Range: 0.15 - 0.40
    var momentumWeight: Double   // Default: 0.25, Range: 0.10 - 0.35
    var patternWeight: Double    // Default: 0.10, Range: 0.05 - 0.20
    var volatilityWeight: Double // Default: 0.05, Range: 0.00 - 0.15
    
    // MARK: - Trading Thresholds
    var entryThreshold: Double   // Default: 70, Range: 55 - 85 (min score to BUY)
    var exitThreshold: Double    // Default: 50, Range: 35 - 60 (max score to SELL)
    var partialExitThreshold: Double // Default: 62, Range: 50 - 70 (partial exit)
    
    // MARK: - Risk Parameters
    var stopLossPercent: Double  // Default: 5.0, Range: 2 - 12%
    var takeProfitPercent: Double // Default: 15.0, Range: 5 - 30%
    
    // MARK: - Metadata
    let updatedAt: Date
    let confidence: Double      // 0.0 - 1.0, how confident are we in this config
    let reasoning: String       // Why these values were chosen
    let backtestWinRate: Double? // Win rate that led to this config
    let backtestReturn: Double?  // Total return that led to this config
    
    // MARK: - Defaults
    
    static var `default`: OrionV2TuningConfig {
        OrionV2TuningConfig(
            structureWeight: 0.30,
            trendWeight: 0.30,
            momentumWeight: 0.25,
            patternWeight: 0.10,
            volatilityWeight: 0.05,
            entryThreshold: 70,
            exitThreshold: 50,
            partialExitThreshold: 62,
            stopLossPercent: 5.0,
            takeProfitPercent: 15.0,
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "Varsayılan Orion V3 ağırlıkları",
            backtestWinRate: nil,
            backtestReturn: nil
        )
    }
    
    // MARK: - Validation
    
    /// Ensures weights sum to 1.0
    func normalized() -> OrionV2TuningConfig {
        let sum = structureWeight + trendWeight + momentumWeight + patternWeight + volatilityWeight
        guard sum > 0 else { return .default }
        
        return OrionV2TuningConfig(
            structureWeight: structureWeight / sum,
            trendWeight: trendWeight / sum,
            momentumWeight: momentumWeight / sum,
            patternWeight: patternWeight / sum,
            volatilityWeight: volatilityWeight / sum,
            entryThreshold: entryThreshold,
            exitThreshold: exitThreshold,
            partialExitThreshold: partialExitThreshold,
            stopLossPercent: stopLossPercent,
            takeProfitPercent: takeProfitPercent,
            updatedAt: Date(),
            confidence: confidence,
            reasoning: reasoning,
            backtestWinRate: backtestWinRate,
            backtestReturn: backtestReturn
        )
    }
    
    /// Clamps values to valid ranges
    func clamped() -> OrionV2TuningConfig {
        OrionV2TuningConfig(
            structureWeight: max(0.15, min(0.45, structureWeight)),
            trendWeight: max(0.15, min(0.40, trendWeight)),
            momentumWeight: max(0.10, min(0.35, momentumWeight)),
            patternWeight: max(0.05, min(0.20, patternWeight)),
            volatilityWeight: max(0.00, min(0.15, volatilityWeight)),
            entryThreshold: max(55, min(85, entryThreshold)),
            exitThreshold: max(35, min(60, exitThreshold)),
            partialExitThreshold: max(50, min(70, partialExitThreshold)),
            stopLossPercent: max(2, min(12, stopLossPercent)),
            takeProfitPercent: max(5, min(30, takeProfitPercent)),
            updatedAt: Date(),
            confidence: confidence,
            reasoning: reasoning,
            backtestWinRate: backtestWinRate,
            backtestReturn: backtestReturn
        )
    }
    
    // MARK: - Computed Properties
    
    var weightsTotal: Double {
        structureWeight + trendWeight + momentumWeight + patternWeight + volatilityWeight
    }
    
    var isValid: Bool {
        abs(weightsTotal - 1.0) < 0.01 &&
        entryThreshold > exitThreshold &&
        stopLossPercent > 0 &&
        takeProfitPercent > stopLossPercent
    }
    
    // MARK: - Display Helpers
    
    var weightsSummary: String {
        "S:\(Int(structureWeight * 100))% T:\(Int(trendWeight * 100))% M:\(Int(momentumWeight * 100))% P:\(Int(patternWeight * 100))% V:\(Int(volatilityWeight * 100))%"
    }
    
    var thresholdsSummary: String {
        "Entry≥\(Int(entryThreshold)) Exit<\(Int(exitThreshold)) SL:\(String(format: "%.1f", stopLossPercent))%"
    }
}

// MARK: - Orion V2 Tuning Store
/// Persists tuning configurations per symbol
@MainActor
final class OrionV2TuningStore {
    static let shared = OrionV2TuningStore()
    
    private var cache: [String: OrionV2TuningConfig] = [:]
    private var globalConfig: OrionV2TuningConfig = .default
    private let fileURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("orion_v2_tuning.json")
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Gets config for a specific symbol, falls back to global if not found
    func getConfig(symbol: String) -> OrionV2TuningConfig {
        cache[symbol] ?? globalConfig
    }
    
    /// Gets the global config
    func getGlobalConfig() -> OrionV2TuningConfig {
        globalConfig
    }
    
    /// Updates config for a specific symbol
    func updateConfig(symbol: String, config: OrionV2TuningConfig) {
        let validated = config.normalized().clamped()
        cache[symbol] = validated
        saveToDisk()
        print("🧠 OrionV2TuningStore: \(symbol) güncellendi - \(validated.weightsSummary)")
    }
    
    /// Updates the global config (used when no symbol-specific config)
    func updateGlobalConfig(_ config: OrionV2TuningConfig) {
        globalConfig = config.normalized().clamped()
        saveToDisk()
        print("🧠 OrionV2TuningStore: Global config güncellendi - \(globalConfig.weightsSummary)")
    }
    
    /// Removes symbol-specific config (reverts to global)
    func resetToGlobal(symbol: String) {
        cache.removeValue(forKey: symbol)
        saveToDisk()
        print("🧠 OrionV2TuningStore: \(symbol) global config'e döndürüldü")
    }
    
    /// Returns all symbols with custom configs
    func getCustomizedSymbols() -> [String] {
        Array(cache.keys)
    }
    
    // MARK: - Persistence
    
    private struct StorageFormat: Codable {
        let global: OrionV2TuningConfig
        let perSymbol: [String: OrionV2TuningConfig]
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let storage = try JSONDecoder().decode(StorageFormat.self, from: data)
            globalConfig = storage.global
            cache = storage.perSymbol
            print("🧠 OrionV2TuningStore: \(cache.count) sembol + global yüklendi")
        } catch {
            print("🧠 OrionV2TuningStore: Load error - \(error.localizedDescription)")
        }
    }
    
    private func saveToDisk() {
        do {
            let storage = StorageFormat(global: globalConfig, perSymbol: cache)
            let data = try JSONEncoder().encode(storage)
            try data.write(to: fileURL)
        } catch {
            print("🧠 OrionV2TuningStore: Save error - \(error.localizedDescription)")
        }
    }
}
