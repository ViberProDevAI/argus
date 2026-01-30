import Foundation

enum SignalOutcome: String, Codable, CaseIterable {
    case hit = "HIT"
    case miss = "MISS"
    case neutral = "NEUTRAL"
    case unknown = "UNKNOWN"
}

struct ArgusDecisionLogEntry: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let mode: ArgusTimeframeMode // .core or .pulse
    let timestamp: Date
    let initialPrice: Double
    
    // Decision Snapshot
    let letterGrade: String
    let action: SignalAction
    let finalScore: Double
    
    // Component Scores
    let atlasScore: Double
    let orionScore: Double
    let aetherScore: Double
    let demeterScore: Double
    let hermesScore: Double
    
    // Performance Metrics (Ex-Post)
    var realizedReturn1D: Double?
    var realizedReturn5D: Double?
    var realizedReturn20D: Double?
    var maxDrawdown20D: Double?
    
    var outcome1D: SignalOutcome?
    var outcome5D: SignalOutcome?
    var outcome20D: SignalOutcome?
    
    init(decision: ArgusDecisionResult, mode: ArgusTimeframeMode, currentPrice: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.symbol = decision.symbol
        self.mode = mode
        self.timestamp = timestamp
        self.initialPrice = currentPrice
        
        // Map based on mode
        switch mode {
        case .core:
            self.letterGrade = decision.letterGradeCore
            self.action = decision.finalActionCore
            self.finalScore = decision.finalScoreCore
        case .pulse:
            self.letterGrade = decision.letterGradePulse
            self.action = decision.finalActionPulse
            self.finalScore = decision.finalScorePulse
        }
        
        self.atlasScore = decision.atlasScore
        self.orionScore = decision.orionScore
        self.aetherScore = decision.aetherScore
        self.demeterScore = decision.demeterScore ?? 0.0
        self.hermesScore = decision.hermesScore
    }
}

// Stats for UI
struct ArgusLabStats {
    // General
    var totalDecisionsCore: Int = 0
    var totalDecisionsPulse: Int = 0
    
    var hitRateCore5D: Double = 0.0
    var hitRatePulse5D: Double = 0.0
    
    var avgReturnCore5D: Double = 0.0
    var avgReturnPulse5D: Double = 0.0
    
    // Grade Distribution (e.g. A+ -> Stats)
    struct GradeStats: Identifiable {
        let id = UUID()
        let grade: String
        let count: Int
        let hitRate: Double
        let avgReturn: Double
    }
    var gradesCore: [GradeStats] = []
    var gradesPulse: [GradeStats] = []
    
    // Regime Analysis
    var riskOffHitRateCore: Double = 0.0
}

// MARK: - NEW UNIFIED LAB SYSTEM (v2)

/// Coverage Level: Determines if a signal has enough data to be part of the official statistics.
enum CoverageLevel: String, Codable {
    case full      // çekirdek istatistiklere dahil
    case partial   // veri var ama eksik / sınırlı
    case invalid   // bu veriyle karar vermek mantıksız
}

/// Her veri bacağını ayrı takip ediyoruz.
struct CoverageComponent: Codable, Equatable {
    var available: Bool      // veri var mı?
    var quality: Double      // 0.0 - 1.0 (0: çok kötü / yok, 1: gayet sağlam)
    var lastUpdated: Date?   // en son ne zaman güncellendi?
    
    static var missing: CoverageComponent {
        CoverageComponent(available: false, quality: 0.0, lastUpdated: nil)
    }
    
    static func present(quality: Double) -> CoverageComponent {
        CoverageComponent(available: true, quality: max(0.0, min(quality, 1.0)), lastUpdated: Date())
    }
    
    /// Checks if the data is fresh based on maximum accepted age.
    /// - Parameter maxAge: Maximum acceptable age in seconds.
    /// - Returns: True if data exists and was updated within maxAge.
    func isFresh(maxAge: TimeInterval) -> Bool {
        guard available, let updated = lastUpdated else { return false }
        return Date().timeIntervalSince(updated) < maxAge
    }
    
    /// Effective module weight multiplier (0 if stale/missing, quality if fresh).
    func effectiveWeight(maxAge: TimeInterval) -> Double {
        return isFresh(maxAge: maxAge) ? quality : 0.0
    }
}

/// Argus ekosisteminin veri kapsamı
struct DataCoverage: Codable {
    var technical: CoverageComponent
    var fundamental: CoverageComponent
    var macro: CoverageComponent
    var news: CoverageComponent
    
    /// 0...1 arası toplam kapsama skoru (kabaca)
    var overallScore: Double {
        let comps = [technical, fundamental, macro, news]
        let sum = comps.reduce(0.0) { $0 + $1.quality }
        return sum / Double(comps.count)
    }
    
    /// Çekirdek seviye sınıflandırma:
    /// - full: en az 2 bacak iyi, toplamda >= 0.6
    /// - partial: biraz veri var ama zayıf
    /// - invalid: neredeyse hiçbir şey yok
    var level: CoverageLevel {
        let goodCount = [technical, fundamental, macro, news]
            .filter { $0.quality >= 0.6 }.count
        
        if goodCount >= 2 && overallScore >= 0.6 {
            return .full
        } else if overallScore >= 0.25 {
            return .partial
        } else {
            return .invalid
        }
    }
}

/// Argus Lab’in logladığı ortak event
/// BUY / SELL / HOLD gibi aksiyonlar
enum LabAction: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case hold = "HOLD"
    case avoid = "AVOID"
    case riskOff = "RISK_OFF"
    case riskOn = "RISK_ON"
    case unknown = "UNKNOWN"
}

/// Algorithm Identity Constants
struct ArgusAlgoId {
    static let orionV1 = "ORION_V1"
    static let atlasV1 = "ATLAS_V1"       // fundamental / Argus Macro
    static let aetherV1 = "AETHER_V1"
    static let hermesV1 = "HERMES_V1"
    static let argusCoreV1 = "ARGUS_CORE_V1"  // Argus ana motor
    static let autoPilot = "AUTOPILOT_V1"
}

/// Unified Log Event for ALL Algorithms
struct ArgusLabEvent: Identifiable, Codable {
    var id: UUID = UUID()
    
    let symbol: String
    let algoId: String
    let createdAt: Date
    
    // Algoritmanın verdiği aksiyon
    let action: LabAction
    let confidence: Double?    // 0-100 arası, varsa
    
    // Skorlar (algoritmaya göre bazıları nil olabilir)
    let orionScore: Double?
    let atlasScore: Double?
    let aetherScore: Double?
    let hermesScore: Double?
    
    // Veri kapsam durumu
    let dataCoverage: DataCoverage
    let regimeTag: String?     // örn: "Bull", "HighVol" vs.
    
    // Değerlendirme alanları (event çözüldüğünde doldurulacak)
    var horizonDays: Int       // bu sinyal kaç gün sonra ölçülecek?
    var signalPrice: Double
    var resolvedAt: Date?
    var resolvedPrice: Double?
    var returnPercent: Double? // (resolvedPrice - signalPrice) / signalPrice * 100
    var isHit: Bool? // Deprecated logic, rely on returnPercent? Keeping for UI
    
    var notes: String?
    
    var isResolved: Bool {
        resolvedAt != nil && returnPercent != nil
    }
    
    init(
        symbol: String,
        algoId: String,
        action: LabAction,
        confidence: Double? = nil,
        orionScore: Double? = nil,
        atlasScore: Double? = nil,
        aetherScore: Double? = nil,
        hermesScore: Double? = nil,
        dataCoverage: DataCoverage,
        regimeTag: String? = nil,
        notes: String? = nil,
        signalPrice: Double,
        horizonDays: Int = 5
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.algoId = algoId
        self.createdAt = Date()
        self.action = action
        self.confidence = confidence
        self.orionScore = orionScore
        self.atlasScore = atlasScore
        self.aetherScore = aetherScore
        self.hermesScore = hermesScore
        self.dataCoverage = dataCoverage
        self.regimeTag = regimeTag
        self.notes = notes
        self.signalPrice = signalPrice
        self.horizonDays = horizonDays
    }
}

struct UnifiedAlgoStats {
    let algoId: String
    let totalSignals: Int
    let hitRate: Double
    let avgReturn: Double
    let winCount: Int
    let lossCount: Int
    let coverageFullCount: Int
    
    // Recent history for UI
    let recentEvents: [ArgusLabEvent]
}
