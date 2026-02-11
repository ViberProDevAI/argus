import Foundation

// MARK: - Core Execution Models

// MARK: - Core Execution Models

enum ArgusExecutionState: String, Codable, Sendable {
    case idle
    case scanning
    case proposing
    case riskGating
    case executing
    case verifying
    case learning // Post-trade analysis or Rejection Log
}

enum ExecutionTrigger: String, Codable, Sendable {
    case manualUser // Kullanıcı butona bastı
    case autoPilotSniper // AutoPilot Sniper modu
    case autoPilotShadow // AutoPilot Shadow modu
    case phoenixScout // Phoenix keşfi
    case stopLoss
    case takeProfit
}

struct ArgusProposal: Identifiable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let action: SignalAction // .buy, .sell, .hold, .skip
    let engine: EngineTag
    let confidence: Double // 0-100
    let rationale: String
    let riskLevel: Double? // 1-10
    
    // Context snapshot
    let scores: ArgusScoresSnapshot
    let dataHealth: Double
    let chironRegime: String
}

struct ArgusScoresSnapshot: Codable, Sendable {
    let atlas: Double?
    let orion: Double?
    let aether: Double?
    let hermes: Double?
    let cronos: Double?
    let final: Double
}

// MARK: - Inbox / Teaching Models

enum InboxActionType: String, Codable, Sendable {
    case proposed // Teklif edildi (Henüz işlem yok)
    case executed // Gerçekleşti
    case rejected // Reddedildi (Risk, Veri, Bütçe)
    case skipped // Pas geçildi (Skor yetersiz)
    case closed // Pozisyon kapatıldı
}

struct InboxEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let symbol: String
    let type: InboxActionType
    let engine: String // Sniper, Shadow, User
    
    // The "Why"
    let reasonTitle: String
    let reasonBullets: [String]
    
    // The "Context"
    let scores: ArgusScoresSnapshot
    let dataHealth: Double // %
    let chironRegime: String // "BullishVolatile"
    let activeWeights: [String: Double] // Atlas: 0.3, Orion: 0.4...
    
    // The "Plan" (If Execute)
    let executionPrice: Double?
    let stopLoss: Double?
    let takeProfit: Double?
    
    // Rejection details
    let rejectionReason: String? // "Data Quality < 70%", "Max Exposure Reached"
    
    // Metadata
    var notes: String?
    var providerPath: [String]? // ["Yahoo (Success)", "FMP (Quota)"]
}

struct PostMortemLog: Identifiable, Codable, Sendable {
    let id: UUID
    let openEventId: UUID
    let symbol: String
    let openDate: Date
    let closeDate: Date
    let holdDurationSeconds: TimeInterval
    
    let entryPrice: Double
    let exitPrice: Double
    let realizedPL: Double
    let realizedPLPercent: Double
    
    let originalThesis: String // "High Atlas Score (85)"
    let exitReason: String // "Stop Loss", "Target Hit", "Thesis Broken (Atlas dropped)"
    
    let slippage: Double // Estimated slippage
    let lessonLearned: String? // Optional user input or AI generated
}
