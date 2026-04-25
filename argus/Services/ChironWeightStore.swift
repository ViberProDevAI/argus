import Foundation

// MARK: - Chiron Module Weights (Engine-Aware)
/// Weights for Corse/Pulse specific evaluation with metadata
/// 7 Modül: Orion, Atlas, Phoenix, Aether, Hermes, Demeter, Athena
struct ChironModuleWeights: Codable, Sendable {
    var orion: Double    // Teknik analiz
    var atlas: Double    // Temel analiz
    var phoenix: Double  // Pattern/Senaryo
    var aether: Double   // Makro ekonomi
    var hermes: Double   // Haber/Sentiment
    var demeter: Double  // Sektör rotasyonu
    var athena: Double   // Smart Beta/Factor
    
    let updatedAt: Date
    let confidence: Double
    let reasoning: String
    
    // Default balanced weights - CORSE (Uzun Vade, Fundamental Ağırlıklı)
    static var defaultCorse: ChironModuleWeights {
        ChironModuleWeights(
            orion: 0.15,   // Teknik daha az önemli
            atlas: 0.30,   // Fundamental öncelikli
            phoenix: 0.10,
            aether: 0.15,  // Makro önemli
            hermes: 0.05,
            demeter: 0.15, // Sektör rotasyonu
            athena: 0.10,  // Factor investing
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "📊 Uzun vadeli yatırım stratejisi. Atlas (fundamental), Demeter (sektör) ve Aether (makro) öncelikli."
        )
    }
    
    // Default balanced weights - PULSE (Kısa Vade, Momentum Ağırlıklı)
    static var defaultPulse: ChironModuleWeights {
        ChironModuleWeights(
            orion: 0.30,   // Teknik öncelikli
            atlas: 0.05,   // Fundamental daha az
            phoenix: 0.25, // Pattern önemli
            aether: 0.10,
            hermes: 0.15,  // Haber önemli
            demeter: 0.10,
            athena: 0.05,
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "⚡ Kısa vadeli momentum stratejisi. Orion (teknik), Phoenix (pattern) ve Hermes (haber) öncelikli."
        )
    }
    
    var totalWeight: Double {
        orion + atlas + phoenix + aether + hermes + demeter + athena
    }
    
    func normalized() -> ChironModuleWeights {
        let total = totalWeight
        guard total > 0 else { return self }
        return ChironModuleWeights(
            orion: orion / total,
            atlas: atlas / total,
            phoenix: phoenix / total,
            aether: aether / total,
            hermes: hermes / total,
            demeter: demeter / total,
            athena: athena / total,
            updatedAt: updatedAt,
            confidence: confidence,
            reasoning: reasoning
        )
    }
}

// MARK: - Chiron Weight Store
@MainActor
final class ChironWeightStore {
    static let shared = ChironWeightStore()
    
    // symbol -> engine -> weights
    private var matrix: [String: [AutoPilotEngine: ChironModuleWeights]] = [:]
    
    // Persistence path
    private let storePath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("ChironWeights.json")
    }()
    
    init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Get weights for a specific symbol and engine
    func getWeights(symbol: String, engine: AutoPilotEngine) -> ChironModuleWeights {
        // 1. Symbol-specific override exists?
        if let symbolWeights = matrix[symbol], let engineWeights = symbolWeights[engine] {
            return engineWeights
        }
        
        // 2. Return defaults
        switch engine {
        case .corse:
            return .defaultCorse
        case .pulse:
            return .defaultPulse
        default:
            return .defaultPulse // Fallback
        }
    }
    
    /// Update weights for a symbol/engine pair. Shadow mode açıksa yazma
    /// yapılmaz; önerilen ağırlığın mevcutla divergence'ı log'lanır (OSLog).
    func updateWeights(symbol: String, engine: AutoPilotEngine, weights: ChironModuleWeights) {
        let normalized = weights.normalized()

        if AutoPilotConfig.chironShadowMode {
            let current = getWeights(symbol: symbol, engine: engine)
            let dOr = String(format: "%+.2f", normalized.orion - current.orion)
            let dAt = String(format: "%+.2f", normalized.atlas - current.atlas)
            let dAe = String(format: "%+.2f", normalized.aether - current.aether)
            ArgusLogger.info(
                "[SHADOW] \(symbol) \(engine.rawValue) Δorion=\(dOr) Δatlas=\(dAt) Δaether=\(dAe) — production unchanged",
                category: "CHIRON_SHADOW"
            )
            return
        }

        if matrix[symbol] == nil {
            matrix[symbol] = [:]
        }
        matrix[symbol]?[engine] = normalized

        saveToDisk()
    }
    
    /// Get all stored weights (for UI display)
    func getAllWeights() -> [String: [AutoPilotEngine: ChironModuleWeights]] {
        return matrix
    }
    
    /// Check if symbol has custom weights
    func hasCustomWeights(symbol: String) -> Bool {
        return matrix[symbol] != nil
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            // Convert to serializable format
            var serializable: [String: [String: ChironModuleWeights]] = [:]
            for (symbol, engines) in matrix {
                var engineDict: [String: ChironModuleWeights] = [:]
                for (engine, weights) in engines {
                    engineDict[engine.rawValue] = weights
                }
                serializable[symbol] = engineDict
            }
            
            let data = try JSONEncoder().encode(serializable)
            try data.write(to: storePath)
            print("💾 ChironWeightStore: Saved to disk")
        } catch {
            print("❌ ChironWeightStore: Save failed - \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storePath.path) else { return }
        
        do {
            let data = try Data(contentsOf: storePath)
            let serializable = try JSONDecoder().decode([String: [String: ChironModuleWeights]].self, from: data)
            
            // Convert back to proper types
            for (symbol, engines) in serializable {
                matrix[symbol] = [:]
                for (engineRaw, weights) in engines {
                    if let engine = AutoPilotEngine(rawValue: engineRaw) {
                        matrix[symbol]?[engine] = weights
                    }
                }
            }
            print("📂 ChironWeightStore: Loaded \(matrix.count) symbols from disk")
        } catch {
            print("❌ ChironWeightStore: Load failed - \(error)")
        }
    }
}
