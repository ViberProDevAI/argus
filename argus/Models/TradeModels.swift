import Foundation

enum TradeSource: String, Codable {
    case user = "USER"
    case autoPilot = "AUTO_PILOT"
}

enum AutoPilotEngine: String, Codable {
    case corse = "CORSE" // Swing / Mid-Term
    case pulse = "PULSE" // Scalp / News / Short-Term
    case shield = "SHIELD" // Hedge / Defense
    case hermes = "HERMES" // News Discovery
    case manual = "MANUAL"
}

enum Currency: String, Codable {
    case USD = "USD"
    case TRY = "TRY"
    
    var symbol: String {
        switch self {
        case .USD: return "$"
        case .TRY: return "₺"
        }
    }
}

struct Trade: Identifiable, Codable {
    var id = UUID()
    let symbol: String
    let entryPrice: Double
    var quantity: Double // Spot Precision (Fractional shares supported)
    let entryDate: Date
    var isOpen: Bool
    var exitPrice: Double?
    var exitDate: Date?
    var source: TradeSource = .user
    var engine: AutoPilotEngine? // Corse or Pulse
    
    // NEW: Currency Awareness (Safety)
    var currency: Currency = .USD // Default to USD for legacy, but init will detect
    
    // Auto-Pilot Details
    var stopLoss: Double?
    var takeProfit: Double? // (Optional, usually dynamic now)
    var highWaterMark: Double? // Highest price seen since entry (For Trailing Stop)
    var isPendingSale: Bool = false // Duplicate stop loss/TP trigger koruması
    var rationale: String?
    var voiceReport: String? // Cached Argus Voice Report
    var decisionContext: DecisionContext? // Snapshot of the decision (Why/How/Who)
    var agoraTrace: AgoraTrace? // AGORA V2 Trace
    
    // NEW: Chiron Öğrenme için Orion Snapshot
    var entryOrionSnapshot: OrionComponentSnapshot?
    var exitOrionSnapshot: OrionComponentSnapshot?
    
    var profit: Double {
        guard let exit = exitPrice else { return 0.0 }
        let diff = exit - entryPrice
        return diff * quantity
    }
    
    var profitPercentage: Double {
        guard let exit = exitPrice else { return 0.0 }
        guard entryPrice > 0 else { return 0.0 } // Safety
        return ((exit - entryPrice) / entryPrice) * 100.0
    }
    
    // Smart Init for Migration
    init(id: UUID = UUID(), symbol: String, entryPrice: Double, quantity: Double, entryDate: Date, isOpen: Bool, source: TradeSource = .user, engine: AutoPilotEngine? = nil, stopLoss: Double? = nil, takeProfit: Double? = nil, rationale: String? = nil, decisionContext: DecisionContext? = nil, agoraTrace: AgoraTrace? = nil, currency: Currency? = nil) {
        self.id = id
        self.symbol = symbol
        self.entryPrice = entryPrice
        self.quantity = quantity
        self.entryDate = entryDate
        self.isOpen = isOpen
        self.source = source
        self.engine = engine
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.rationale = rationale
        self.decisionContext = decisionContext
        self.agoraTrace = agoraTrace
        
        // Auto-Detect Currency if not provided
        if let c = currency {
            self.currency = c
        } else {
            if symbol.uppercased().hasSuffix(".IS") {
                self.currency = .TRY
            } else {
                self.currency = .USD
            }
        }
    }
    
    // MARK: - Codable Compliance & Backward Compatibility
    enum CodingKeys: String, CodingKey {
        case id, symbol, entryPrice, quantity, entryDate, isOpen, exitPrice, exitDate
        case source, engine, currency, stopLoss, takeProfit, highWaterMark, rationale
        case voiceReport, decisionContext, agoraTrace
        case entryOrionSnapshot, exitOrionSnapshot
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        entryPrice = try container.decode(Double.self, forKey: .entryPrice)
        quantity = try container.decode(Double.self, forKey: .quantity)
        entryDate = try container.decode(Date.self, forKey: .entryDate)
        isOpen = try container.decode(Bool.self, forKey: .isOpen)
        exitPrice = try container.decodeIfPresent(Double.self, forKey: .exitPrice)
        exitDate = try container.decodeIfPresent(Date.self, forKey: .exitDate)
        source = try container.decodeIfPresent(TradeSource.self, forKey: .source) ?? .user
        engine = try container.decodeIfPresent(AutoPilotEngine.self, forKey: .engine)
        
        stopLoss = try container.decodeIfPresent(Double.self, forKey: .stopLoss)
        takeProfit = try container.decodeIfPresent(Double.self, forKey: .takeProfit)
        highWaterMark = try container.decodeIfPresent(Double.self, forKey: .highWaterMark)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
        voiceReport = try container.decodeIfPresent(String.self, forKey: .voiceReport)
        // Robust Decoding: Use try? for complex nested objects to prevent crash on schema change
        decisionContext = try? container.decodeIfPresent(DecisionContext.self, forKey: .decisionContext)
        agoraTrace = try? container.decodeIfPresent(AgoraTrace.self, forKey: .agoraTrace)
        entryOrionSnapshot = try? container.decodeIfPresent(OrionComponentSnapshot.self, forKey: .entryOrionSnapshot)
        exitOrionSnapshot = try? container.decodeIfPresent(OrionComponentSnapshot.self, forKey: .exitOrionSnapshot)
        
        // Migration Logic: Currency
        if let c = try container.decodeIfPresent(Currency.self, forKey: .currency) {
            currency = c
        } else {
            // Fallback Detection
            if symbol.uppercased().hasSuffix(".IS") {
                currency = .TRY
            } else {
                currency = .USD
            }
        }
    }
}

// MARK: - Transaction History
enum TransactionType: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case attempt = "ATTEMPT" // NEW: Blocked trades
}

// MARK: - Export Snapshots (Enriched Data)
struct DecisionTraceSnapshot: Codable {
    let mode: String // CORSE, PULSE
    let overallScore: Double?
    let scores: ScoresSnapshot
    let thresholds: ThresholdsSnapshot
    let reasonsTop3: [ReasonSnapshot]
    let guards: GuardsSnapshot
    let blockReason: String?
    let phoenix: PhoenixSnapshot? // Schema V2
    let standardizedOutputs: [String: StandardModuleOutput]? // Export V2
    
    struct ScoresSnapshot: Codable {
        let atlas: Double?
        let orion: Double?
        let aether: Double?
        let hermes: Double?
        let demeter: Double?
    }
    struct ThresholdsSnapshot: Codable {
        let buyOverallMin: Double?
        let sellOverallMin: Double?
        let orionMin: Double?
        let atlasMin: Double?
        let aetherMin: Double?
        let hermesMin: Double?
    }
    struct ReasonSnapshot: Codable {
        let key: String
        let value: Double?
        let note: String
    }
    struct GuardsSnapshot: Codable {
        let cooldownActive: Bool
        let minHoldBlocked: Bool
        let minMoveBlocked: Bool
        let costGateBlocked: Bool
        let rebalanceBandBlocked: Bool
        let rateLimitBlocked: Bool
        let otherBlocked: Bool
    }
}

struct PositionSnapshot: Codable {
    let positionQtyBefore: Double?
    let positionQtyAfter: Double?
    let avgCostBefore: Double?
    let avgCostAfter: Double?
    let holdingSeconds: Double?
    let unrealizedPnlBefore: Double?
    let realizedPnlThisTrade: Double?
    let portfolioSnapshot: PortfolioSnapshot?
    
    struct PortfolioSnapshot: Codable {
        let cashBefore: Double?
        let cashAfter: Double?
        let grossExposure: Double?
        let netExposure: Double?
        let positionsCount: Int?
    }
}

struct ExecutionSnapshot: Codable {
    let orderType: String // MARKET, LIMIT
    let requestedPrice: Double?
    let filledPrice: Double?
    let slippagePct: Double?
    let latencyMs: Double?
    let partialFill: Bool?
    // Schema V2
    let requestedQty: Double?
    let filledQty: Double?
    let venue: String?
}

struct OutcomeLabels: Codable {
    var pnlAfter1h: Double?
    var pnlAfter1d: Double?
    var mfePct: Double?
    var mddPct: Double?
    var flipWithin1h: Bool?
    var flipWithin1d: Bool?
    var label: String? // GOOD, BAD, NEUTRAL
    var labelHorizon: String?
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    let type: TransactionType
    let symbol: String
    let amount: Double // Total Value
    let price: Double
    let date: Date
    var fee: Double? // Midas Fee etc.
    
    // NEW: Currency Awareness
    var currency: Currency = .USD
    
    // PnL Data
    var pnl: Double?
    var pnlPercent: Double?
    
    // Enriched Data (Argus v2 Export)
    var decisionTrace: DecisionTraceSnapshot?
    var marketSnapshot: MarketSnapshot?
    var positionSnapshot: PositionSnapshot?
    var execution: ExecutionSnapshot?
    var outcome: OutcomeLabels?
    
    // Schema V2 Extensions
    var schemaVersion: Int?
    var source: String? // AUTOPILOT / MANUAL
    var strategy: String? // CORSE / PULSE
    var reasonCode: String?
    var decisionContext: DecisionContext?
    
    // Churn
    var cooldownUntil: Date?
    var minHoldUntil: Date?
    var guardrailHit: Bool?
    var guardrailReason: String?
    
    // Idempotency (ID V2)
    var decisionId: String? // Linked from DecisionSnapshot
    var intentId: String? // Unique ID for this specific trade attempt
    
    // Memberwise Init Explicitly Defined for readability & default currency
    init(id: UUID, type: TransactionType, symbol: String, amount: Double, price: Double, date: Date, fee: Double? = nil, currency: Currency? = nil, pnl: Double? = nil, pnlPercent: Double? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil, positionSnapshot: PositionSnapshot? = nil, execution: ExecutionSnapshot? = nil, outcome: OutcomeLabels? = nil, schemaVersion: Int? = 2, source: String? = nil, strategy: String? = nil, reasonCode: String? = nil, decisionContext: DecisionContext? = nil, cooldownUntil: Date? = nil, minHoldUntil: Date? = nil, guardrailHit: Bool? = nil, guardrailReason: String? = nil, decisionId: String? = nil, intentId: String? = nil) {
        self.id = id
        self.type = type
        self.symbol = symbol
        self.amount = amount
        self.price = price
        self.date = date
        self.fee = fee
        
        if let c = currency {
            self.currency = c
        } else {
            if symbol.uppercased().hasSuffix(".IS") {
                self.currency = .TRY
            } else {
                self.currency = .USD
            }
        }
        
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.decisionTrace = decisionTrace
        self.marketSnapshot = marketSnapshot
        self.positionSnapshot = positionSnapshot
        self.execution = execution
        self.outcome = outcome
        self.schemaVersion = schemaVersion
        self.source = source
        self.strategy = strategy
        self.reasonCode = reasonCode
        self.decisionContext = decisionContext
        self.cooldownUntil = cooldownUntil
        self.minHoldUntil = minHoldUntil
        self.guardrailHit = guardrailHit
        self.guardrailReason = guardrailReason
        self.decisionId = decisionId
        self.intentId = intentId
    }

    // Custom Decoding to handle Date format mismatch
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        symbol = try container.decode(String.self, forKey: .symbol)
        amount = try container.decode(Double.self, forKey: .amount)
        price = try container.decode(Double.self, forKey: .price)
        
        // Handle Date: Try Double first, then String (ISO8601)
        if let doubleDate = try? container.decode(Double.self, forKey: .date) {
            date = Date(timeIntervalSinceReferenceDate: doubleDate)
        } else if let stringDate = try? container.decode(String.self, forKey: .date) {
            // Try ISO8601
            if let d = ISO8601DateFormatter().date(from: stringDate) {
                date = d
            } else {
                // Try standard formatting
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                if let d2 = formatter.date(from: stringDate) {
                    date = d2
                } else {
                    // Fallback to current date on failure to prevent crash
                    date = Date() 
                }
            }
        } else {
            // Last resort fallback
            date = Date()
        }

        fee = try container.decodeIfPresent(Double.self, forKey: .fee)
        pnl = try container.decodeIfPresent(Double.self, forKey: .pnl)
        pnlPercent = try container.decodeIfPresent(Double.self, forKey: .pnlPercent)
        // Robust Decoding: Use try? for complex nested objects
        decisionTrace = try? container.decodeIfPresent(DecisionTraceSnapshot.self, forKey: .decisionTrace)
        marketSnapshot = try? container.decodeIfPresent(MarketSnapshot.self, forKey: .marketSnapshot)
        positionSnapshot = try? container.decodeIfPresent(PositionSnapshot.self, forKey: .positionSnapshot)
        execution = try? container.decodeIfPresent(ExecutionSnapshot.self, forKey: .execution)
        outcome = try? container.decodeIfPresent(OutcomeLabels.self, forKey: .outcome)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        strategy = try container.decodeIfPresent(String.self, forKey: .strategy)
        reasonCode = try container.decodeIfPresent(String.self, forKey: .reasonCode)
        decisionContext = try? container.decodeIfPresent(DecisionContext.self, forKey: .decisionContext)
        cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
        minHoldUntil = try container.decodeIfPresent(Date.self, forKey: .minHoldUntil)
        guardrailHit = try container.decodeIfPresent(Bool.self, forKey: .guardrailHit)
        guardrailReason = try container.decodeIfPresent(String.self, forKey: .guardrailReason)
        decisionId = try container.decodeIfPresent(String.self, forKey: .decisionId)
        intentId = try container.decodeIfPresent(String.self, forKey: .intentId)
        
        // Migration Logic: Currency
        if let c = try container.decodeIfPresent(Currency.self, forKey: .currency) {
            currency = c
        } else {
            // Fallback Detection
            if symbol.uppercased().hasSuffix(".IS") {
                currency = .TRY
            } else {
                currency = .USD
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, symbol, amount, price, date, fee
        case currency
        case pnl, pnlPercent
        case decisionTrace, marketSnapshot, positionSnapshot, execution, outcome
        case schemaVersion, source, strategy, reasonCode, decisionContext
        case cooldownUntil, minHoldUntil, guardrailHit, guardrailReason
        case decisionId, intentId
    }
}
