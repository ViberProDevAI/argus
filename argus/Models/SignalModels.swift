import Foundation

struct CompositeScore: Identifiable {
    let id = UUID()
    let totalScore: Double // -100 to +100
    let breakdown: [String: Double] // e.g., "RSI": -20, "Trend": +50
    let sentiment: SignalAction // Derived from totalScore
    
    var colorName: String {
        if totalScore >= 50 { return "Green" }
        else if totalScore <= -50 { return "Red" }
        else { return "Gray" }
    }
}

struct Signal: Identifiable {
    let id = UUID()
    let strategyName: String
    let action: SignalAction
    let confidence: Double // 0.0 - 100.0
    let reason: String
    let indicatorValues: [String: String] // e.g. "RSI": "32.5"
    
    // V6: Education Module
    let logic: String // "How it works"
    let successContext: String // "Where it works best"
    let simplifiedExplanation: String // New: Detailed but simple explanation
    
    let date: Date = Date()
}

// MARK: - Auto Pilot Signals
struct TradeSignal {
    let symbol: String
    let action: SignalAction
    let reason: String
    let confidence: Double
    let timestamp: Date
    let stopLoss: Double?
    let takeProfit: Double?
    var trimPercentage: Double? = nil // Support for Partial Sells (Active Trim)
}

// MARK: - Schema V2 Structs
struct DecisionContext: Codable {
    let decisionId: String
    let overallAction: String
    let dominantSignals: [String]
    let conflicts: [DecisionConflict]
    let moduleVotes: ModuleVotes
}

struct DecisionConflict: Codable {
    let moduleA: String
    let moduleB: String
    let topic: String
    let severity: Double
}

struct ModuleVotes: Codable {
    let atlas: ModuleVote?
    let orion: ModuleVote?
    let aether: ModuleVote?
    let hermes: ModuleVote?
    let chiron: ModuleVote?
}

struct ModuleVote: Codable {
    let score: Double
    let direction: String
    let confidence: Double
}

// MARK: - Missing Snapshots (Fixing Compilation)

struct PhoenixSnapshot: Codable {
    let timeframe: String
    let activeSignal: Bool
    let confidence: Double
    let lowerBand: Double
    let upperBand: Double
    let midLine: Double
    let distanceToLow: Double?
}

// MARK: - Snapshot Helpers
struct SnapshotEvidence: Codable, Sendable {
    let module: String
    let claim: String
    let confidence: Double
    let direction: String
}

struct SnapshotRiskContext: Codable, Sendable {
    let regime: String
    let aetherScore: Double
    let chironState: String
}

struct DecisionSnapshot: Codable {
    // Identity
    let id: UUID
    let symbol: String
    let timestamp: Date
    
    // Core Decision
    let action: SignalAction
    let overallScore: Double
    let reason: String
    let confidence: Double
    
    // Detailed Context (Required for Audit/Trace)
    let evidence: [SnapshotEvidence]
    let riskContext: SnapshotRiskContext? 
    let dominantSignals: [String]
    let conflicts: [DecisionConflict]
    
    // Agora / Governance
    let locks: AgoraLocksSnapshot
    
    // Optional / Legacy Support
    let phoenix: PhoenixSnapshot? 
    let standardizedOutputs: [String: StandardModuleOutput]?
    
    // Helpers
    var reasonOneLiner: String { reason }
    
    // Initializer for convenience mapping
    init(symbol: String, action: SignalAction, reason: String, evidence: [SnapshotEvidence], riskContext: SnapshotRiskContext?, locks: AgoraLocksSnapshot, phoenix: PhoenixSnapshot?, standardizedOutputs: [String: StandardModuleOutput]?, dominantSignals: [String], conflicts: [DecisionConflict]) {
        self.id = UUID()
        self.timestamp = Date()
        self.symbol = symbol
        self.action = action
        self.reason = reason
        self.overallScore = 0.0
        self.confidence = 1.0
        self.evidence = evidence
        self.riskContext = riskContext
        self.locks = locks
        self.phoenix = phoenix
        self.standardizedOutputs = standardizedOutputs
        self.dominantSignals = dominantSignals
        self.conflicts = conflicts
    }
}

struct AgoraLocksSnapshot: Codable {
    let isLocked: Bool // If true, trade is blocked
    let reasons: [String] // Why blocked? (Cooldown, Risk, Veto)
    
    // Specific Lock Details
    let cooldownUntil: Date?
    let minHoldUntil: Date?
}
