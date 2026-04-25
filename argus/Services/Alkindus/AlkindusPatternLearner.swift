import Foundation

// MARK: - Alkindus Pattern Learner
/// Formasyonların sembol ve piyasa bazlı performansını öğrenir.

@MainActor
final class AlkindusPatternLearner {
    static let shared = AlkindusPatternLearner()
    
    private let filePath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("alkindus_memory").appendingPathComponent("pattern_learnings.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct PatternLearningData: Codable {
        var patterns: [String: PatternProfile]
        var lastUpdated: Date
        
        static var empty: PatternLearningData {
            PatternLearningData(patterns: [:], lastUpdated: Date())
        }
    }
    
    struct PatternProfile: Codable {
        var name: String
        var displayName: String
        var globalStats: PerformanceStats
        var symbolStats: [String: PerformanceStats]
        var marketStats: [String: PerformanceStats]
        var timeframeStats: [String: PerformanceStats]
    }
    
    struct PerformanceStats: Codable {
        var attempts: Int
        var successes: Int
        var totalGain: Double
        var avgHoldingDays: Double
        var lastSeen: Date
        
        var hitRate: Double { attempts > 0 ? Double(successes) / Double(attempts) : 0 }
        var avgGain: Double { attempts > 0 ? totalGain / Double(attempts) : 0 }
        
        static var empty: PerformanceStats {
            PerformanceStats(attempts: 0, successes: 0, totalGain: 0, avgHoldingDays: 0, lastSeen: Date())
        }
    }
    
    // MARK: - Known Patterns
    
    enum ChartPattern: String, CaseIterable, Codable {
        case cupAndHandle = "cup_and_handle"
        case doubleBottom = "double_bottom"
        case tripleBottom = "triple_bottom"
        case inverseHeadAndShoulders = "inverse_head_shoulders"
        case ascendingTriangle = "ascending_triangle"
        case bullFlag = "bull_flag"
        case bullPennant = "bull_pennant"
        case fallingWedge = "falling_wedge"
        case headAndShoulders = "head_shoulders"
        case doubleTop = "double_top"
        case tripleTop = "triple_top"
        case descendingTriangle = "descending_triangle"
        case bearFlag = "bear_flag"
        case bearPennant = "bear_pennant"
        case risingWedge = "rising_wedge"
        case symmetricalTriangle = "symmetrical_triangle"
        case rectangle = "rectangle"
        case channel = "channel"
        
        var displayName: String {
            switch self {
            case .cupAndHandle: return "Fincan & Kulp"
            case .doubleBottom: return "Çift Dip"
            case .tripleBottom: return "Üçlü Dip"
            case .inverseHeadAndShoulders: return "Ters Omuz Baş Omuz"
            case .ascendingTriangle: return "Yükselen Üçgen"
            case .bullFlag: return "Boğa Bayrağı"
            case .bullPennant: return "Boğa Flama"
            case .fallingWedge: return "Düşen Kama"
            case .headAndShoulders: return "Omuz Baş Omuz"
            case .doubleTop: return "Çift Tepe"
            case .tripleTop: return "Üçlü Tepe"
            case .descendingTriangle: return "Düşen Üçgen"
            case .bearFlag: return "Ayı Bayrağı"
            case .bearPennant: return "Ayı Flama"
            case .risingWedge: return "Yükselen Kama"
            case .symmetricalTriangle: return "Simetrik Üçgen"
            case .rectangle: return "Dikdörtgen"
            case .channel: return "Kanal"
            }
        }
        
        var expectedBias: PatternBias {
            switch self {
            case .cupAndHandle, .doubleBottom, .tripleBottom, .inverseHeadAndShoulders,
                 .ascendingTriangle, .bullFlag, .bullPennant, .fallingWedge:
                return .bullish
            case .headAndShoulders, .doubleTop, .tripleTop, .descendingTriangle,
                 .bearFlag, .bearPennant, .risingWedge:
                return .bearish
            case .symmetricalTriangle, .rectangle, .channel:
                return .neutral
            }
        }
    }
    
    enum PatternBias: String, Codable {
        case bullish = "BOĞA"
        case bearish = "AYI"
        case neutral = "NÖTR"
    }
    
    // MARK: - API
    
    func recordPattern(
        pattern: ChartPattern,
        symbol: String,
        timeframe: String,
        wasSuccess: Bool,
        gainPercent: Double,
        holdingDays: Double
    ) {
        var data = loadData()
        let isBist = symbol.uppercased().hasSuffix(".IS")
        let market = isBist ? "bist" : "global"
        
        if data.patterns[pattern.rawValue] == nil {
            data.patterns[pattern.rawValue] = PatternProfile(
                name: pattern.rawValue,
                displayName: pattern.displayName,
                globalStats: .empty,
                symbolStats: [:],
                marketStats: [:],
                timeframeStats: [:]
            )
        }
        
        updateStats(&data.patterns[pattern.rawValue]!.globalStats, wasSuccess: wasSuccess, gain: gainPercent, holdingDays: holdingDays)
        
        if data.patterns[pattern.rawValue]?.symbolStats[symbol] == nil {
            data.patterns[pattern.rawValue]?.symbolStats[symbol] = .empty
        }
        updateStats(&data.patterns[pattern.rawValue]!.symbolStats[symbol]!, wasSuccess: wasSuccess, gain: gainPercent, holdingDays: holdingDays)
        
        if data.patterns[pattern.rawValue]?.marketStats[market] == nil {
            data.patterns[pattern.rawValue]?.marketStats[market] = .empty
        }
        updateStats(&data.patterns[pattern.rawValue]!.marketStats[market]!, wasSuccess: wasSuccess, gain: gainPercent, holdingDays: holdingDays)
        
        if data.patterns[pattern.rawValue]?.timeframeStats[timeframe] == nil {
            data.patterns[pattern.rawValue]?.timeframeStats[timeframe] = .empty
        }
        updateStats(&data.patterns[pattern.rawValue]!.timeframeStats[timeframe]!, wasSuccess: wasSuccess, gain: gainPercent, holdingDays: holdingDays)
        
        data.lastUpdated = Date()
        saveData(data)
        
        // Sync to RAG (Vector DB)
        Task {
            await AlkindusRAGEngine.shared.syncPatternLearning(
                pattern: pattern.displayName,
                symbol: symbol,
                wasSuccess: wasSuccess,
                gain: gainPercent,
                holdingDays: holdingDays
            )
        }
        
        print("📐 Alkindus Pattern: \(pattern.displayName) on \(symbol) - \(wasSuccess ? "✅" : "❌")")
    }
    
    func getPatternStats(for symbol: String) -> [PatternStat] {
        let data = loadData()
        var stats: [PatternStat] = []
        
        for pattern in ChartPattern.allCases {
            if let profile = data.patterns[pattern.rawValue],
               let symbolStats = profile.symbolStats[symbol],
               symbolStats.attempts >= 3 {
                stats.append(PatternStat(
                    pattern: pattern,
                    hitRate: symbolStats.hitRate,
                    avgGain: symbolStats.avgGain,
                    samples: symbolStats.attempts,
                    reliability: calculateReliability(stats: symbolStats)
                ))
            }
        }
        
        return stats.sorted { $0.hitRate > $1.hitRate }
    }
    
    func getMarketPatternStats(isBist: Bool) -> [PatternStat] {
        let data = loadData()
        let market = isBist ? "bist" : "global"
        var stats: [PatternStat] = []
        
        for pattern in ChartPattern.allCases {
            if let profile = data.patterns[pattern.rawValue],
               let marketStats = profile.marketStats[market],
               marketStats.attempts >= 5 {
                stats.append(PatternStat(
                    pattern: pattern,
                    hitRate: marketStats.hitRate,
                    avgGain: marketStats.avgGain,
                    samples: marketStats.attempts,
                    reliability: calculateReliability(stats: marketStats)
                ))
            }
        }
        
        return stats.sorted { $0.hitRate > $1.hitRate }
    }
    
    func getBestPatterns(for symbol: String, minSamples: Int = 3) -> [ChartPattern] {
        let stats = getPatternStats(for: symbol)
        return stats.filter { $0.samples >= minSamples && $0.hitRate >= 0.60 }.map { $0.pattern }
    }
    
    func getPatternsToAvoid(for symbol: String, minSamples: Int = 3) -> [ChartPattern] {
        let stats = getPatternStats(for: symbol)
        return stats.filter { $0.samples >= minSamples && $0.hitRate < 0.40 }.map { $0.pattern }
    }
    
    func getPatternAdvice(pattern: ChartPattern, symbol: String) -> PatternAdvice {
        let data = loadData()
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        var symbolHitRate: Double?
        var marketHitRate: Double?
        var globalHitRate: Double?
        
        if let profile = data.patterns[pattern.rawValue] {
            if let s = profile.symbolStats[symbol], s.attempts >= 3 {
                symbolHitRate = s.hitRate
            }
            if let m = profile.marketStats[isBist ? "bist" : "global"], m.attempts >= 5 {
                marketHitRate = m.hitRate
            }
            globalHitRate = profile.globalStats.attempts >= 10 ? profile.globalStats.hitRate : nil
        }
        
        let trustLevel: TrustLevel
        let message: String
        
        if let shr = symbolHitRate {
            if shr >= 0.70 {
                trustLevel = .high
                message = "\(pattern.displayName) bu hissede güçlü: %\(Int(shr * 100)) başarı"
            } else if shr >= 0.50 {
                trustLevel = .medium
                message = "\(pattern.displayName) bu hissede orta: %\(Int(shr * 100)) başarı"
            } else {
                trustLevel = .low
                message = "⚠️ \(pattern.displayName) bu hissede zayıf: %\(Int(shr * 100)) başarı"
            }
        } else if let mhr = marketHitRate {
            if mhr >= 0.60 {
                trustLevel = .medium
                message = "\(pattern.displayName) \(isBist ? "BIST" : "Global")'de: %\(Int(mhr * 100)) başarı"
            } else {
                trustLevel = .low
                message = "\(pattern.displayName) \(isBist ? "BIST" : "Global")'de zayıf: %\(Int(mhr * 100))"
            }
        } else {
            trustLevel = .unknown
            message = "\(pattern.displayName) için henüz yeterli veri yok"
        }
        
        return PatternAdvice(
            pattern: pattern,
            symbol: symbol,
            trustLevel: trustLevel,
            symbolHitRate: symbolHitRate,
            marketHitRate: marketHitRate,
            globalHitRate: globalHitRate,
            message: message
        )
    }
    
    // MARK: - Private Helpers
    
    private func updateStats(_ stats: inout PerformanceStats, wasSuccess: Bool, gain: Double, holdingDays: Double) {
        stats.attempts += 1
        if wasSuccess { stats.successes += 1 }
        stats.totalGain += gain
        stats.avgHoldingDays = ((stats.avgHoldingDays * Double(stats.attempts - 1)) + holdingDays) / Double(stats.attempts)
        stats.lastSeen = Date()
    }
    
    private func calculateReliability(stats: PerformanceStats) -> ReliabilityLevel {
        if stats.attempts >= 20 && stats.hitRate >= 0.65 { return .proven }
        if stats.attempts >= 10 { return .reliable }
        if stats.attempts >= 5 { return .emerging }
        return .insufficient
    }
    
    private func loadData() -> PatternLearningData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(PatternLearningData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: PatternLearningData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}

// MARK: - Supporting Models

struct PatternStat {
    let pattern: AlkindusPatternLearner.ChartPattern
    let hitRate: Double
    let avgGain: Double
    let samples: Int
    let reliability: ReliabilityLevel
}

enum ReliabilityLevel: String, Codable {
    case proven = "KANITLANMIŞ"
    case reliable = "GÜVENİLİR"
    case emerging = "GELİŞEN"
    case insufficient = "YETERSİZ"
}

enum TrustLevel: String {
    case high = "YÜKSEK"
    case medium = "ORTA"
    case low = "DÜŞÜK"
    case unknown = "BİLİNMİYOR"
}

struct PatternAdvice {
    let pattern: AlkindusPatternLearner.ChartPattern
    let symbol: String
    let trustLevel: TrustLevel
    let symbolHitRate: Double?
    let marketHitRate: Double?
    let globalHitRate: Double?
    let message: String
}
