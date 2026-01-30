import Foundation

// MARK: - Forward Test Result
/// Bir karar veya tahminin doğrulanmış sonucu
struct ForwardTestResult: Codable, Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let testType: ForwardTestType
    let eventDate: Date          // Kararın verildiği tarih
    let verificationDate: Date    // Doğrulama yapıldığı tarih
    
    // Orijinal Tahmin
    let originalPrice: Double
    let predictedPrice: Double?   // Prometheus için
    let predictedAction: String?  // Argus için (BUY/SELL/HOLD)
    
    // Gerçekleşen
    let actualPrice: Double
    let actualChange: Double      // Yüzde değişim
    
    // Sonuç
    let wasCorrect: Bool
    let accuracy: Double          // 0-100 (tahmin ne kadar yakın)
    
    // Metadata
    let moduleScores: [String: Double]?  // Karar anındaki modül skorları
    let notes: String?
}

enum ForwardTestType: String, Codable, Sendable {
    case prometheusforecast = "prometheus"  // 5 günlük fiyat tahmini
    case argusDecision = "argus"            // BUY/SELL/HOLD kararı
}

// MARK: - Processing Statistics
struct ForwardTestStats: Codable, Sendable {
    let totalTests: Int
    let correctTests: Int
    let hitRate: Double           // correctTests / totalTests
    let averageAccuracy: Double   // Ortalama accuracy
    
    // Tip bazlı
    let prometheusHitRate: Double
    let argusHitRate: Double
    
    // En son güncelleme
    let lastUpdated: Date
    
    static var empty: ForwardTestStats {
        ForwardTestStats(
            totalTests: 0,
            correctTests: 0,
            hitRate: 0,
            averageAccuracy: 0,
            prometheusHitRate: 0,
            argusHitRate: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Pending Event (İşlenmeyi bekleyen)
struct PendingForwardTest: Codable, Identifiable, Sendable {
    let id: String                // event_id from database
    let symbol: String
    let testType: ForwardTestType
    let eventDate: Date
    let originalPrice: Double
    let predictedPrice: Double?
    let predictedAction: String?
    let daysUntilMature: Int      // Kaç gün kaldı doğrulamaya
    
    var isMature: Bool {
        daysUntilMature <= 0
    }
}

// MARK: - Event Data Types (For Ledger Queries)
struct ForecastEventData: Sendable {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let predictedPrice: Double
}

struct DecisionEventData: Sendable {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let action: String
    let moduleScores: [String: Double]
    
    // Observatory: Horizon & Outcome Tracking
    var horizon: DecisionHorizon = .t7
    var outcome: DecisionOutcome = .pending
    var maturedAt: Date?
    var actualPnl: Double?
}

// MARK: - Decision Horizon (Değerlendirme Süresi)
enum DecisionHorizon: String, Codable, Sendable {
    case t7 = "T+7"     // 7 gün sonra değerlendir
    case t15 = "T+15"   // 15 gün sonra değerlendir
    case t60 = "T+60"   // 60 gün sonra değerlendir
    
    var days: Int {
        switch self {
        case .t7: return 7
        case .t15: return 15
        case .t60: return 60
        }
    }
}

// MARK: - Decision Outcome (Karar Sonucu)
enum DecisionOutcome: String, Codable, Sendable {
    case pending = "PENDING"     // Henüz olgunlaşmadı
    case matured = "MATURED"     // Değerlendirildi
    case stale = "STALE"         // Veri eksik, değerlendirilemedi
    
    var displayName: String {
        switch self {
        case .pending: return "Bekleniyor"
        case .matured: return "Değerlendirildi"
        case .stale: return "Veri Yok"
        }
    }
}

// MARK: - Learning Event (Öğrenme Olayı)
/// Chiron ağırlık güncellemelerinin kaydı
struct LearningEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    
    // Ne değişti?
    let weightDeltas: [String: Double]  // "Orion": +0.08, "Hermes": -0.05
    let oldWeights: [String: Double]
    let newWeights: [String: Double]
    
    // Neden değişti?
    let reason: String                   // "High-vol rejimde Orion hit-rate düştü"
    let triggerMetric: String?           // "win_rate", "sharpe", vb.
    let triggerValue: Double?            // 0.41
    
    // Hangi koşulda?
    let regime: String?                  // "Trend", "Chop", "RiskOff"
    let windowDays: Int                  // 30, 60, 90
    let sampleSize: Int                  // Kaç karar üzerinden hesaplandı
    
    // UI için
    var summaryText: String {
        let changes = weightDeltas.map { key, value in
            let sign = value >= 0 ? "+" : ""
            return "\(key): \(sign)\(String(format: "%.2f", value))"
        }.joined(separator: ", ")
        return "Δ \(changes)"
    }
}

// MARK: - Extracted Models (Phase 4 Refactoring)

struct TradeRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let status: String // "OPEN" or "CLOSED"
    let entryDate: Date
    let entryPrice: Double
    let entryReason: String?
    let exitDate: Date?
    let exitPrice: Double?
    let pnlPercent: Double?
    let dominantSignal: String?
    let decisionId: String?
    
    // Computed
    var isOpen: Bool { status == "OPEN" }
}

struct LessonRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let tradeId: UUID
    let createdAt: Date
    let lessonText: String
    let deviationPercent: Double?
    let weightChanges: [String: Double]?
}

struct DecisionCard: Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let market: String           // "US" or "BIST"
    let timestamp: Date
    let action: String           // "BUY", "SELL", "HOLD"
    let confidence: Double       // 0.0 - 1.0
    let topFactors: [Factor]
    let horizon: DecisionHorizon
    let outcome: DecisionOutcome
    let actualPnl: Double?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: timestamp)
    }
    
    // UI Logic moved to View Extensions

    
    // Sub-struct
    struct Factor: Sendable {
        let name: String
        let emoji: String
        let value: Double
    }
}
