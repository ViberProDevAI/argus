import Foundation

// MARK: - Chiron Optimization Input
/// The data payload sent to the LLM to learn and optimize weights.
struct ChironOptimizationInput: Codable {
    let globalSettings: GlobalSettings
    let performanceLogs: [PerformanceLog]
    
    struct GlobalSettings: Codable {
        let currentArgusWeights: ArgusWeights
        let currentOrionWeights: OrionWeights
        let safeguards: Safeguards
    }
    
    struct ArgusWeights: Codable {
        let core: ModuleWeights
        let pulse: ModuleWeights
    }
    
    struct OrionWeights: Codable {
        let trend: Double
        let momentum: Double
        let relStrength: Double
        let volatility: Double
        let pullback: Double
        let riskReward: Double
        // Optional extras can be added if needed
    }
    
    struct Safeguards: Codable {
        let minTradesForLearning: Int
        let maxWeightChangePerStep: Double
        let minModuleWeightCore: Double
        let minModuleWeightPulse: Double
    }
}

// MARK: - Performance Log
struct PerformanceLog: Codable {
    let symbol: String
    let timeframe: String
    let regime: RegimeInfo
    let dataHealth: Double // 0-100
    let moduleResults: ModuleResults
    let orionSubStrategies: [OrionSubStrategyLog]
    let hermesStatus: HermesStatus
    let historicalSteps: [HistoricalStep]?
    let strategyType: String? // NEW: "orionV2", "phoenixChannel", etc.
    
    struct RegimeInfo: Codable {
        let macro: String // "RISK_ON", "RISK_OFF", "MIXED"
        let trendState: String // "TRENDING", "RANGING"
    }
    
    struct ModuleResults: Codable {
        let atlas: ModuleStats
        let orion: ModuleStats
        let phoenix: ModuleStats? // NEW
        let aether: ModuleStats? // NEW
        let hermes: ModuleStats? // NEW
        
        // Convenience init for backwards compatibility
        init(atlas: ModuleStats, orion: ModuleStats, phoenix: ModuleStats? = nil, aether: ModuleStats? = nil, hermes: ModuleStats? = nil) {
            self.atlas = atlas
            self.orion = orion
            self.phoenix = phoenix
            self.aether = aether
            self.hermes = hermes
        }
    }
    
    struct ModuleStats: Codable {
        let trades: Int
        let winRate: Double
        let avgR: Double
        let pnlPercent: Double
        let maxDrawdown: Double
        
        static let empty = ModuleStats(trades: 0, winRate: 0, avgR: 0, pnlPercent: 0, maxDrawdown: 0)
    }
    
    struct HermesStatus: Codable {
        let available: Bool
        let dataHealth: Double
    }
    
    struct HistoricalStep: Codable {
        let timestamp: Date
        let argusScoreCore: Double
        let argusScorePulse: Double
        let autoPilotDecision: String
        let realizedPnlSince: Double
    }
}

struct OrionSubStrategyLog: Codable {
    let id: String // "trend", "meanReversion", etc.
    let trades: Int
    let winRate: Double
    let avgR: Double
    let pnlPercent: Double
    let maxDrawdown: Double
}

// MARK: - Chiron Optimization Output
/// The structured response from the LLM.
struct ChironOptimizationOutput: Codable {
    let newArgusWeights: ChironOptimizationInput.ArgusWeights
    let newOrionWeights: ChironOptimizationInput.OrionWeights
    let perSymbolOverrides: [PerSymbolOverride]?
    let learningNotes: [String]
    
    struct PerSymbolOverride: Codable {
        let symbol: String
        let timeframe: String
        let regime: PerformanceLog.RegimeInfo
        let orionLocalWeights: [String: Double]
    }
}
