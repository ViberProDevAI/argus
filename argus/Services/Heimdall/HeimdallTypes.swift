import Foundation

/// Unique identifier for a traced request
struct TraceID: Identifiable, Hashable, Codable, CustomStringConvertible {
    let id: UUID
    var description: String { id.uuidString.prefix(8).uppercased() }
    var uuidString: String { id.uuidString }
    
    nonisolated init() { self.id = UUID() }
}

/// The specific engine or subsystem making the request
enum EngineTag: String, Codable, CaseIterable {
    case atlas = "ATLAS"       // Fundamentals
    case aether = "AETHER"     // Macro
    case orion = "ORION"       // Tech Analysis
    case hermes = "HERMES"     // News
    case cronos = "CRONOS"     // Time/Cycles
    case athena = "ATHENA"     // Factor Analysis
    case poseidon = "POSEIDON" // Whale Tracking
    case phoenix = "PHOENIX"   // Scanner
    case scout = "SCOUT"       // Opportunity Discovery
    case heimdall = "HEIMDALL" // System/Health
    case market = "MARKET"     // Raw Quotes/Candles
    case demeter = "DEMETER"   // Sector/Flow
    case shadow = "Shadow"
}

/// Broad Asset Class for Capability Filtering
enum AssetType: String, Codable, CaseIterable {
    case stock = "Stock"
    case etf = "ETF"
    case crypto = "Crypto"
    case forex = "Forex"

    case index = "Index"
    case commodity = "Commodity"
    case unknown = "Unknown"
}

// HeimdallCanonicalAsset replaced by CanonicalInstrument.swift
// If aliases are needed, they are handled there.


/// Action to take on a signal
enum SignalAction: String, Codable, CaseIterable, Sendable {
    case buy = "BUY"
    case sell = "SELL"
    case hold = "HOLD"
    case skip = "SKIP"
    case wait = "WAIT"
    
    var localized: String {
        switch self {
        case .buy: return "AL"
        case .sell: return "SAT"
        case .hold: return "TUT"
        case .skip: return "PAS"
        case .wait: return "BEKLE"
        }
    }
}

/// The external data provider being accessed
enum ProviderTag: String, Codable, CaseIterable {
    case yahoo = "Yahoo"
    case fmp = "FMP"
    case twelvedata = "TwelveData"
    case tiingo = "Tiingo"
    case finnhub = "Finnhub"
    case alphavantage = "AlphaVantage"
    case eodhd = "EODHD"
    case fred = "FRED"
    case massive = "Massive" // New Options Provider
    case localScanner = "LocalScanner" // Fallback
    case coingecko = "CoinGecko"
    case unknown = "Unknown"
}

/// How the cache layer handled this request
enum CachePolicy: String, Codable {
    case hit = "HIT"            // Served from cache (fresh)
    case miss = "MISS"          // Not in cache
    case staleHit = "STALE"     // Served from cache (expired but allowed)
    case bypass = "BYPASS"      // Cache ignored explicitly
    case write = "WRITE"        // Fetched networking and wrote to cache
    case none = "NONE"
}

/// Categorized reason for failure
public enum FailureCategory: String, Codable, Sendable {
    case none = "None"
    
    // Auth & Entitlement (Critical distinction)
    case authInvalid = "Auth Invalid"           // 401: Key is wrong -> LOCK PROVIDER
    case entitlementDenied = "Entitlement Denied" // 403: Endpoint deprecated/Plan Limit -> DISABLE ENDPOINT
    
    // Operational
    case rateLimited = "Rate Limited"           // 429
    case serverError = "Server Error"           // 5xx
    case networkError = "Network Error"         // Offline/Timeout
    case decodeError = "Decode Error"           // JSON Mismatch
    
    // Logic/Other
    case symbolNotFound = "Not Found"           // 404
    case emptyPayload = "Empty Payload"         // 200 OK but []
    case circuitOpen = "Circuit Open"
    case unknown = "Unknown"
}

/// A detailed log of a single data request lifecycle
struct RequestTraceEvent: Identifiable, Codable {
    let id: TraceID
    let timestamp: Date
    var durationMs: Double
    
    let engine: EngineTag
    let provider: ProviderTag
    let endpoint: String
    let symbol: String
    let parameters: String? // Redacted sensitive info
    
    var httpStatusCode: Int?
    var byteCount: Int
    
    let cachePolicy: CachePolicy
    var isSuccess: Bool
    var failureCategory: FailureCategory
    var errorMessage: String?
    
    // Failover Context
    var retryCount: Int
    var failoverPath: String? // "FMP -> Yahoo"
    var circuitStateSnapshot: String? // "FMP: Open, Yahoo: Closed"
    var bodyPrefix: String? // First 300 chars of response (for debugging)
    var canonicalAsset: CanonicalInstrument? // Defined if known
    
    // Forensic Decision Context
    var candidates: [String]? // "Yahoo(95), FMP(20)"
    var selectionReason: String? // "Health Score + Quota Available"
    var decisionPath: [String]? // ["Tried Yahoo -> Timeout", "Tried FMP -> Success"]
    
    // Deep Forensic
    var failingURL: String?
    var errorDomain: String?
    var errorCode: Int?
    
    nonisolated static func start(engine: EngineTag, provider: ProviderTag, endpoint: String, symbol: String, canonicalAsset: CanonicalInstrument? = nil) -> RequestTraceEvent {
        return RequestTraceEvent(
            id: TraceID(),
            timestamp: Date(),
            durationMs: 0,
            engine: engine,
            provider: provider,
            endpoint: endpoint,
            symbol: symbol,
            parameters: nil,
            httpStatusCode: nil,
            byteCount: 0,
            cachePolicy: .none,
            isSuccess: false,
            failureCategory: .none,
            errorMessage: nil,
            retryCount: 0,
            failoverPath: nil,
            circuitStateSnapshot: nil,
            bodyPrefix: nil,
            canonicalAsset: canonicalAsset,
            failingURL: nil,
            errorDomain: nil,
            errorCode: nil
        )
    }
    
    nonisolated func completed(success: Bool, duration: Double, code: Int?, bytes: Int, error: String? = nil, category: FailureCategory = .none, body: String? = nil, failingURL: String? = nil, errorDomain: String? = nil, errorCode: Int? = nil) -> RequestTraceEvent {
        var copy = self
        copy.isSuccess = success
        copy.durationMs = duration
        copy.httpStatusCode = code
        copy.byteCount = bytes
        copy.errorMessage = error
        copy.failureCategory = category
        copy.bodyPrefix = body
        copy.failingURL = failingURL
        copy.errorDomain = errorDomain
        copy.errorCode = errorCode
        return copy
    }
}

/// Aggregated health status for a specific engine
struct EngineHealthSnapshot: Identifiable, Codable {
    var id: String { engine.rawValue }
    let engine: EngineTag
    
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
    var lastFailureCategory: FailureCategory?
    var consecutiveFailures: Int
    
    var state: HealthState {
        if let last = lastSuccessAt, Date().timeIntervalSince(last) < 300 { return .fresh } // 5 min
        if let last = lastSuccessAt, Date().timeIntervalSince(last) < 3600 { return .stale } // 1 hour
        return .missing
    }
    
    enum HealthState: String, Codable {
        case fresh = "Fresh"
        case stale = "Stale"
        case missing = "Missing"
    }
}

// MARK: - Heimdall 3.0 Unification (Engine Contract)

/// Standardized output for ALL Argus Engines (Atlas, Aether, Orion, etc.)
/// Ensures "No Data" is handled gracefully and scores are normalized (0-10).
struct EngineOutput: Sendable, Codable {
    /// Normalized score (0.0 to 10.0). 5.0 is Neutral.
    /// NEVER return 0.0 just because data is missing.
    let score10: Double
    
    /// Confidence in the score (0.0 to 1.0).
    /// Based on data coverage, freshness, and provider health.
    let confidence: Double
    
    /// Ratio of required data points found (0.0 to 1.0).
    let coverage: Double
    
    /// Age of the oldest critical data point in seconds.
    let freshnessSec: Int
    
    /// High-level operational status of the engine.
    let status: EngineStatus
    
    /// Human-readable explanation (3-8 lines).
    let explain: [String]
    
    /// Forensic details for debugging/UI strip.
    let diagnostics: EngineDiagnostics
    
    /// Helper for "Missing" state
    static var missing: EngineOutput {
        return EngineOutput(
            score10: 5.0,
            confidence: 0.0,
            coverage: 0.0,
            freshnessSec: 999999,
            status: .missing,
            explain: ["Veri bulunamadı veya sağlayıcılar erişilemez durumda.", "Nötr skor atandı."],
            diagnostics: .empty
        )
    }
}

enum EngineStatus: String, Codable, Sendable {
    case ok = "OK"
    case degraded = "Degraded"      // Some data missing or fallback used
    case missing = "Missing"        // No data at all
    case quarantined = "Quarantined" // Provider blocked
    case error = "Error"            // Crash/Exception
}

struct EngineDiagnostics: Sendable, Codable {
    let providerPath: String // e.g., "Yahoo -> EODHD"
    let attemptCount: Int
    let lastErrorCategory: FailureCategory
    let symbolsUsed: [String]
    let latencyMs: Double
    
    static var empty: EngineDiagnostics {
        return EngineDiagnostics(
            providerPath: "None",
            attemptCount: 0,
            lastErrorCategory: .none,
            symbolsUsed: [],
            latencyMs: 0
        )
    }
}

// MARK: - Unified Data Layer Models (SSoT)
// Models (DataProvenance, DataValue) are defined in Models/DataProvenance.swift
