import Foundation

// MARK: - Alkindus Anomaly Detector
/// Tracks rolling statistics and detects when modules deviate from their baseline.
/// "Hermes is performing 20% below average this week"

actor AlkindusAnomalyDetector {
    static let shared = AlkindusAnomalyDetector()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("rolling_stats.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct RollingData: Codable {
        var modules: [String: ModuleRollingStats]
        var lastUpdated: Date
        
        static var empty: RollingData {
            RollingData(modules: [:], lastUpdated: Date())
        }
    }
    
    struct ModuleRollingStats: Codable {
        var allTimeScores: [Double]       // Rolling window (max 100)
        var last7DaysScores: [Double]     // Last 7 days
        var last7DaysOutcomes: [Bool]     // Last 7 days win/loss
        var lastUpdated: Date
        
        var allTimeAvg: Double {
            guard !allTimeScores.isEmpty else { return 50 }
            return allTimeScores.reduce(0, +) / Double(allTimeScores.count)
        }
        
        var allTimeStd: Double {
            guard allTimeScores.count > 1 else { return 10 }
            let avg = allTimeAvg
            let variance = allTimeScores.map { pow($0 - avg, 2) }.reduce(0, +) / Double(allTimeScores.count - 1)
            return sqrt(variance)
        }
        
        var last7DaysAvg: Double {
            guard !last7DaysScores.isEmpty else { return allTimeAvg }
            return last7DaysScores.reduce(0, +) / Double(last7DaysScores.count)
        }
        
        var last7DaysHitRate: Double {
            guard !last7DaysOutcomes.isEmpty else { return 0.5 }
            let wins = last7DaysOutcomes.filter { $0 }.count
            return Double(wins) / Double(last7DaysOutcomes.count)
        }
        
        var deviationPercent: Double {
            guard allTimeAvg > 0 else { return 0 }
            return ((last7DaysAvg - allTimeAvg) / allTimeAvg) * 100
        }
        
        var zScore: Double {
            guard allTimeStd > 0 else { return 0 }
            return (last7DaysAvg - allTimeAvg) / allTimeStd
        }
    }
    
    // MARK: - API
    
    /// Records a module's score and outcome
    func recordModulePerformance(module: String, score: Double, wasCorrect: Bool) async {
        var data = await loadData()
        let key = module.lowercased()
        
        // Initialize if needed
        if data.modules[key] == nil {
            data.modules[key] = ModuleRollingStats(
                allTimeScores: [],
                last7DaysScores: [],
                last7DaysOutcomes: [],
                lastUpdated: Date()
            )
        }
        
        // Add to all-time (keep max 100)
        data.modules[key]?.allTimeScores.append(score)
        if data.modules[key]!.allTimeScores.count > 100 {
            data.modules[key]?.allTimeScores.removeFirst()
        }
        
        // Add to 7-day window
        data.modules[key]?.last7DaysScores.append(score)
        data.modules[key]?.last7DaysOutcomes.append(wasCorrect)
        
        // Trim 7-day window (assume max 50 decisions per week)
        if data.modules[key]!.last7DaysScores.count > 50 {
            data.modules[key]?.last7DaysScores.removeFirst()
            data.modules[key]?.last7DaysOutcomes.removeFirst()
        }
        
        data.modules[key]?.lastUpdated = Date()
        data.lastUpdated = Date()
        await saveData(data)
    }
    
    /// Detects anomalies (modules performing significantly different from baseline)
    func detectAnomalies(thresholdZScore: Double = 1.5) async -> [AnomalyAlert] {
        let data = await loadData()
        var alerts: [AnomalyAlert] = []
        
        for (module, stats) in data.modules {
            let z = stats.zScore
            
            // Significant deviation
            if abs(z) >= thresholdZScore && stats.allTimeScores.count >= 20 {
                let direction: AnomalyDirection = z > 0 ? .performingAbove : .performingBelow
                alerts.append(AnomalyAlert(
                    module: module,
                    direction: direction,
                    deviationPercent: stats.deviationPercent,
                    zScore: z,
                    last7DaysHitRate: stats.last7DaysHitRate,
                    allTimeAvg: stats.allTimeAvg,
                    last7DaysAvg: stats.last7DaysAvg
                ))
            }
        }
        
        return alerts.sorted { abs($0.zScore) > abs($1.zScore) }
    }
    
    /// Gets rolling stats for a module
    func getStats(for module: String) async -> ModuleRollingStats? {
        let data = await loadData()
        return data.modules[module.lowercased()]
    }
    
    /// Gets all module stats
    func getAllStats() async -> [String: ModuleRollingStats] {
        let data = await loadData()
        return data.modules
    }
    
    // MARK: - Private
    
    private func loadData() async -> RollingData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(RollingData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: RollingData) async {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}

// MARK: - Anomaly Alert Model

enum AnomalyDirection: String, Codable {
    case performingAbove = "ABOVE"
    case performingBelow = "BELOW"
}

struct AnomalyAlert: Codable {
    let module: String
    let direction: AnomalyDirection
    let deviationPercent: Double
    let zScore: Double
    let last7DaysHitRate: Double
    let allTimeAvg: Double
    let last7DaysAvg: Double
    
    var message: String {
        let dirText = direction == .performingAbove ? "üstünde" : "altında"
        return "\(module.capitalized) son 7 günde ortalamanın %\(Int(abs(deviationPercent))) \(dirText) performans gösteriyor"
    }
    
    var severity: AlertSeverity {
        if abs(zScore) >= 2.5 { return .critical }
        if abs(zScore) >= 2.0 { return .high }
        return .medium
    }
}

enum AlertSeverity: String {
    case critical = "KRİTİK"
    case high = "YÜKSEK"
    case medium = "ORTA"
}
