import Foundation

/// The Omniscient Context for Argus Voice.
/// Aggregates knowledge from all subsystems.
struct ArgusContext: Codable, Sendable {
    // 1. Target (Focus)
    let symbol: String? // If focusing on a specific stock
    let price: Double?
    
    // 2. Subsystem States
    let demeter: DemeterSummary? // Sector/Shock Context
    let aether: MacroEnvironmentRating? // Macro Context
    let chiron: ChironRiskState? // Risk/Execution Context
    
    // 3. User Query (Optional)
    let userQuery: String?
    
    // 4. Decision Trace (Legacy/Specific)
    let trace: ArgusVoiceTrace?
    
    // 5. New Decision Snapshot (V2)
    let snapshot: DecisionSnapshot?
}

/// Simplified Summary of Demeter State for LLM Context
struct DemeterSummary: Codable, Sendable {
    let activeShocks: [ShockFlag]
    let topSectors: [String] // Top 3 Strongest
    let weakSectors: [String] // Bottom 3 Weakest
    let focusSectorScore: DemeterScore? // If specific symbol context spans a sector
}

/// Simplified Summary of Chiron Risk State
struct ChironRiskState: Codable, Sendable {
    let openPositions: Int
    let totalRiskR: Double
    let isRiskCapped: Bool
    let activeClusterLoads: [String: Int] // Sector concentration
}

// MARK: - Decision Trace Models (Recreated)

struct ArgusVoiceTrace: Codable, Sendable {
    let meta: Meta
    let action: Action
    let scores: Scores
    
    let orionBreakdown: OrionBreakdown?
    let atlasBreakdown: AtlasBreakdown?
    let aetherBreakdown: AetherBreakdown?
    let hermesBreakdown: HermesBreakdown?
    
    let risk: Risk
    let quality: Quality
    
    let reasonCodes: [String]
    let counterfactuals: [String]
    
    struct Meta: Codable, Sendable {
        let tradeId: String
        let symbol: String
        let assetType: String
        let mode: String
        let timeframe: String
        let signalTimeUTC: Date
        let fillTimeUTC: Date
        let providerUsed: [String]
        let cacheHit: Bool
    }
    
    struct Action: Codable, Sendable {
        let type: String // BUY, SELL, HOLD
        let fillPrice: Double
        let qty: Double
        let slippagePct: Double
        let gapPct: Double
    }
    
    struct Scores: Codable, Sendable {
        let overall: Double
        let orion: Double
        let atlas: Double
        let aether: Double
        let hermes: Double
        let missingModules: [String]
    }
    
    struct OrionBreakdown: Codable, Sendable {
        let trend: Component
        let momentum: Component
        let phoenix: Component
        let relativeStrength: Component
        let volatilityLiquidity: Component
        let overboughtPenalty: String?
        
        struct Component: Codable, Sendable {
            var active: Bool?
            var rsi14: Double?
            var macd: String?
            let score: Double
            var notes: String?
        }
    }
    
    struct AtlasBreakdown: Codable, Sendable {
        let profitability: Double
        let growth: Double
        let leverageRisk: Double
        let cashQuality: Double
        let forwardGuidance: Double
        let notes: String
    }
    
    struct AetherBreakdown: Codable, Sendable {
        let regime: String
        let score: Double
        let drivers: [String]
    }
    
    struct HermesBreakdown: Codable, Sendable {
        let sentiment: String
        let score: Double
        let confidence: Double
        let headlines: [String]
    }
    
    struct Risk: Codable, Sendable {
        let atrPct: Double
        let stopLossPct: Double
        let takeProfitPct: Double
        let positionRiskPct: Double
        let portfolioExposurePct: Double
    }
    
    struct Quality: Codable, Sendable {
        let dataFreshnessSec: Double
        let anomalies: [String]
        let warnings: [String]
    }
}
