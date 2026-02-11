import Foundation

// MARK: - Alkindus Indicator Learner
/// İndikatörlerin sembol ve zaman bazlı performansını öğrenir.

@MainActor
final class AlkindusIndicatorLearner {
    static let shared = AlkindusIndicatorLearner()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("indicator_learnings.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct IndicatorLearningData: Codable {
        var indicators: [String: IndicatorProfile]
        var lastUpdated: Date
        
        static var empty: IndicatorLearningData {
            IndicatorLearningData(indicators: [:], lastUpdated: Date())
        }
    }
    
    struct IndicatorProfile: Codable {
        var name: String
        var globalStats: PerformanceStats
        var symbolStats: [String: PerformanceStats]
        var timeframeStats: [String: PerformanceStats]
        var conditionStats: [String: PerformanceStats]
    }
    
    struct PerformanceStats: Codable {
        var attempts: Int
        var successes: Int
        var totalGain: Double
        var bestGain: Double
        var worstLoss: Double
        var lastUpdated: Date
        
        var hitRate: Double { attempts > 0 ? Double(successes) / Double(attempts) : 0 }
        var avgGain: Double { attempts > 0 ? totalGain / Double(attempts) : 0 }
        
        static var empty: PerformanceStats {
            PerformanceStats(attempts: 0, successes: 0, totalGain: 0, bestGain: 0, worstLoss: 0, lastUpdated: Date())
        }
    }
    
    enum Indicator: String, CaseIterable, Codable {
        case rsi = "rsi"
        case macd = "macd"
        case stochastic = "stochastic"
        case adx = "adx"
        case bollinger = "bollinger"
        case cci = "cci"
        case williamsR = "williams_r"
        case atr = "atr"
        case sma = "sma"
        case ema = "ema"
        
        var displayName: String {
            switch self {
            case .rsi: return "RSI"
            case .macd: return "MACD"
            case .stochastic: return "Stochastic"
            case .adx: return "ADX"
            case .bollinger: return "Bollinger"
            case .cci: return "CCI"
            case .williamsR: return "Williams %R"
            case .atr: return "ATR"
            case .sma: return "SMA"
            case .ema: return "EMA"
            }
        }
    }
    
    // MARK: - API
    
    func recordSignal(
        indicator: Indicator,
        condition: String,
        symbol: String,
        timeframe: String,
        wasSuccess: Bool,
        gainPercent: Double
    ) {
        var data = loadData()
        
        if data.indicators[indicator.rawValue] == nil {
            data.indicators[indicator.rawValue] = IndicatorProfile(
                name: indicator.displayName,
                globalStats: .empty,
                symbolStats: [:],
                timeframeStats: [:],
                conditionStats: [:]
            )
        }
        
        updateStats(&data.indicators[indicator.rawValue]!.globalStats, wasSuccess: wasSuccess, gain: gainPercent)
        
        if data.indicators[indicator.rawValue]?.symbolStats[symbol] == nil {
            data.indicators[indicator.rawValue]?.symbolStats[symbol] = .empty
        }
        updateStats(&data.indicators[indicator.rawValue]!.symbolStats[symbol]!, wasSuccess: wasSuccess, gain: gainPercent)
        
        if data.indicators[indicator.rawValue]?.timeframeStats[timeframe] == nil {
            data.indicators[indicator.rawValue]?.timeframeStats[timeframe] = .empty
        }
        updateStats(&data.indicators[indicator.rawValue]!.timeframeStats[timeframe]!, wasSuccess: wasSuccess, gain: gainPercent)
        
        if data.indicators[indicator.rawValue]?.conditionStats[condition] == nil {
            data.indicators[indicator.rawValue]?.conditionStats[condition] = .empty
        }
        updateStats(&data.indicators[indicator.rawValue]!.conditionStats[condition]!, wasSuccess: wasSuccess, gain: gainPercent)
        
        data.lastUpdated = Date()
        saveData(data)
        
        // Sync to RAG (Vector DB)
        Task {
            await AlkindusRAGEngine.shared.syncIndicatorLearning(
                indicator: indicator.displayName,
                symbol: symbol,
                condition: condition,
                wasSuccess: wasSuccess,
                gain: gainPercent
            )
        }
    }
    
    func getBestIndicators(for symbol: String, minAttempts: Int = 10) -> [(indicator: Indicator, hitRate: Double, avgGain: Double)] {
        let data = loadData()
        var results: [(Indicator, Double, Double)] = []
        
        for indicator in Indicator.allCases {
            if let profile = data.indicators[indicator.rawValue],
               let stats = profile.symbolStats[symbol],
               stats.attempts >= minAttempts {
                results.append((indicator, stats.hitRate, stats.avgGain))
            }
        }
        
        return results.sorted { $0.1 > $1.1 }
    }
    
    func getWorstIndicators(for symbol: String, minAttempts: Int = 10) -> [(indicator: Indicator, hitRate: Double)] {
        let data = loadData()
        var results: [(Indicator, Double)] = []
        
        for indicator in Indicator.allCases {
            if let profile = data.indicators[indicator.rawValue],
               let stats = profile.symbolStats[symbol],
               stats.attempts >= minAttempts,
               stats.hitRate < 0.45 {
                results.append((indicator, stats.hitRate))
            }
        }
        
        return results.sorted { $0.1 < $1.1 }
    }
    
    func getGlobalIndicatorRanking() -> [(indicator: Indicator, hitRate: Double, samples: Int)] {
        let data = loadData()
        var results: [(Indicator, Double, Int)] = []
        
        for indicator in Indicator.allCases {
            if let profile = data.indicators[indicator.rawValue] {
                results.append((indicator, profile.globalStats.hitRate, profile.globalStats.attempts))
            }
        }
        
        return results.sorted { $0.1 > $1.1 }
    }
    
    func getIndicatorAdvice(for symbol: String, timeframe: String) -> IndicatorAdvice {
        let best = getBestIndicators(for: symbol, minAttempts: 5)
        let worst = getWorstIndicators(for: symbol, minAttempts: 5)
        
        let trustMessage: String
        if let top = best.first {
            trustMessage = "\(top.indicator.displayName) en güvenilir (%\(Int(top.hitRate * 100)))"
        } else {
            trustMessage = "Henüz yeterli veri yok"
        }
        
        let avoidMessage: String
        if let bottom = worst.first {
            avoidMessage = "\(bottom.indicator.displayName)'den kaçın (%\(Int(bottom.hitRate * 100)))"
        } else {
            avoidMessage = ""
        }
        
        return IndicatorAdvice(
            symbol: symbol,
            timeframe: timeframe,
            trustIndicators: best.prefix(3).map { $0.indicator },
            avoidIndicators: worst.prefix(2).map { $0.indicator },
            trustMessage: trustMessage,
            avoidMessage: avoidMessage
        )
    }
    
    // MARK: - Private Helpers
    
    private func updateStats(_ stats: inout PerformanceStats, wasSuccess: Bool, gain: Double) {
        stats.attempts += 1
        if wasSuccess { stats.successes += 1 }
        stats.totalGain += gain
        stats.bestGain = max(stats.bestGain, gain)
        stats.worstLoss = min(stats.worstLoss, gain)
        stats.lastUpdated = Date()
    }
    
    private func loadData() -> IndicatorLearningData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(IndicatorLearningData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: IndicatorLearningData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}

// MARK: - Indicator Advice Model

struct IndicatorAdvice {
    let symbol: String
    let timeframe: String
    let trustIndicators: [AlkindusIndicatorLearner.Indicator]
    let avoidIndicators: [AlkindusIndicatorLearner.Indicator]
    let trustMessage: String
    let avoidMessage: String
    
    var summary: String {
        var msg = "🎯 \(symbol): \(trustMessage)"
        if !avoidMessage.isEmpty {
            msg += " | ⚠️ \(avoidMessage)"
        }
        return msg
    }
}
