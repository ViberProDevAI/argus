import Foundation

// MARK: - Agora Signal Protocol (The Contract)
// Tüm modüllerin (Orion, Atlas, Aether vb.) uyması gereken ortak dil.

enum AgoraModule: String, Codable, Sendable {
    case orion = "ORION"   // Technical
    case atlas = "ATLAS"   // Fundamental
    case aether = "AETHER" // Macro
    case hermes = "HERMES" // News/Sentiment
    case chiron = "CHIRON" // Risk/Governance
    case phoenix = "PHOENIX" // Dip Hunter
}

enum AgoraAction: String, Codable, Sendable {
    case buy = "BUY"
    case sell = "SELL"
    case hold = "HOLD"
    case add = "ADD"
    case reduce = "REDUCE"
    case noTrade = "NO_TRADE" // Pasif
}

enum AgoraTimeframeTag: String, Codable, Sendable {
    case auto = "AUTO"
    case t1Min = "1M"
    case t5Min = "5M"
    case t15Min = "15M"
    case t1Hour = "1H"
    case t4Hour = "4H"
    case t1Day = "1D"
    case t1Week = "1W"
}

enum AgoraHorizon: String, Codable, Sendable {
    case short = "SHORT" // Scalp (Pulse)
    case mid = "MID"     // Swing (Corse)
    case long = "LONG"   // Investment
}

// Kanıt (Modülün "Neden?" sorusuna cevabı)
struct AgoraEvidence: Codable, Sendable {
    let key: String       // örn: "RSI", "PE_Ratio"
    let value: String     // örn: "24.5", "12.0"
    let rule: String      // örn: "RSI < 30 (Oversold)"
    let weight: Double    // 0.0 - 1.0 (Kanıtın gücü)
    let isCounterfactual: Bool // "Bu olmasaydı karar değişirdi" mi?
}

// Sinyal (Bir modülün ham çıktısı)
struct AgoraSignal: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let module: AgoraModule
    let symbol: String
    
    // Karar Çekirdeği
    let action: AgoraAction
    let direction: Int // -1 (Bear), 0 (Neutral), +1 (Bull)
    
    // Nitelik
    let strength: Double   // 0.0 - 1.0 (Sinyalin şiddeti, örn: RSI 20 vs 29)
    let confidence: Double // 0.0 - 1.0 (Veri kalitesi ve kesinlik)
    
    // Zamanlama
    let horizon: AgoraHorizon
    let timeframeTag: AgoraTimeframeTag
    
    // Açıklanabilirlik
    let evidence: [AgoraEvidence]
    
    // Metadata
    let dataFreshnessSec: TimeInterval
    let missingBarsRatio: Double // 0.0 - 1.0
    let outlierCount: Int
    
    // Init helper
    init(module: AgoraModule, symbol: String, action: AgoraAction, direction: Int, strength: Double, confidence: Double, horizon: AgoraHorizon, timeframeTag: AgoraTimeframeTag, evidence: [AgoraEvidence], freshness: TimeInterval = 0) {
        self.id = UUID()
        self.timestamp = Date()
        self.module = module
        self.symbol = symbol
        self.action = action
        self.direction = direction
        self.strength = strength
        self.confidence = confidence
        self.horizon = horizon
        self.timeframeTag = timeframeTag
        self.evidence = evidence
        self.dataFreshnessSec = freshness
        self.missingBarsRatio = 0.0
        self.outlierCount = 0
    }
}

// MARK: - Agora Deliberation Models (The Debate)

// İddia (Sinyalin Agora masasına konmuş hali)
struct AgoraClaim: Codable, Sendable {
    let sourceSignal: AgoraSignal
    let impactScore: Double // direction * strength * confidence
}

// İtiraz (Bir modülün başka bir iddiaya karşı çıkışı)
struct AgoraChallenge: Codable, Sendable {
    let fromModule: AgoraModule
    let againstModule: AgoraModule
    let reason: String
    let severity: Double // 0.0 - 1.0 (1.0 = Veto/Block)
}

// Nihai Karar (Agora çıktısı)
struct AgoraDecisionResult: Codable, Sendable, Identifiable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    
    // Sonuç
    let finalAction: AgoraAction
    let netEdge: Double // (-1.0 to +1.0) Boğa/Ayı dengesi
    let confidenceGlobal: Double // (0.0 - 1.0) Veri sağlığı ve konsensüs
    let sizePenalty: Double // (0.0 - 1.0) Risk nedeniyle boyut kısıtlaması
    
    // Detaylar
    let winningClaims: [AgoraClaim] // Kabul edilen iddialar
    let activeChallenges: [AgoraChallenge] // Masadaki itirazlar
    let vetoTriggered: String? // Veto sebebi (varsa)
    
    // Phoenix Levels (Varsa)
    let phoenixLevels: PhoenixLevelPack?
    
    // Churn State
    let cooldownState: CooldownStatus
}

struct PhoenixLevelPack: Codable, Sendable {
    let timeframe: AgoraTimeframeTag
    let entryZoneLow: Double
    let entryZoneHigh: Double
    let stopLoss: Double
    let takeProfit1: Double
    let takeProfit2: Double
    let fitQuality: Double // R-Squared
}

enum CooldownStatus: String, Codable, Sendable {
    case active
    case ready
    case frozen // Manual action sonrası
}
