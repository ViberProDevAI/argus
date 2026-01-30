import Foundation

// MARK: - Alkindus Correlation Tracker
/// Tracks performance when multiple modules agree or disagree.
/// "When Orion 80+ AND Atlas 80+, what's the hit rate?"

actor AlkindusCorrelationTracker {
    static let shared = AlkindusCorrelationTracker()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("correlations.json")
    }()
    
    private init() {
        // Ensure directory exists
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct CorrelationData: Codable {
        var correlations: [String: CorrelationStats]
        var lastUpdated: Date
        
        static var empty: CorrelationData {
            CorrelationData(correlations: [:], lastUpdated: Date())
        }
    }
    
    struct CorrelationStats: Codable {
        var attempts: Int
        var correct: Int
        
        var hitRate: Double {
            guard attempts > 0 else { return 0 }
            return Double(correct) / Double(attempts)
        }
    }
    
    // MARK: - API
    
    /// Records outcome for a module combination
    /// Key format: "orion_80+_atlas_80+" or "orion_high_hermes_high"
    func recordCorrelation(modules: [String: Double], wasCorrect: Bool) async {
        var data = await loadData()
        
        // Generate correlation keys for high-performing modules (60+)
        let highModules = modules.filter { $0.value >= 60 }
            .map { ($0.key.lowercased(), bracketLabel($0.value)) }
            .sorted { $0.0 < $1.0 }
        
        // Record pairs
        if highModules.count >= 2 {
            for i in 0..<highModules.count {
                for j in (i+1)..<highModules.count {
                    let key = "\(highModules[i].0)_\(highModules[i].1)_\(highModules[j].0)_\(highModules[j].1)"
                    
                    if data.correlations[key] == nil {
                        data.correlations[key] = CorrelationStats(attempts: 0, correct: 0)
                    }
                    data.correlations[key]?.attempts += 1
                    if wasCorrect {
                        data.correlations[key]?.correct += 1
                    }
                }
            }
        }
        
        // Record all-agree (3+ modules)
        if highModules.count >= 3 {
            let allKey = "all_\(highModules.count)_agree"
            if data.correlations[allKey] == nil {
                data.correlations[allKey] = CorrelationStats(attempts: 0, correct: 0)
            }
            data.correlations[allKey]?.attempts += 1
            if wasCorrect {
                data.correlations[allKey]?.correct += 1
            }
        }
        
        data.lastUpdated = Date()
        await saveData(data)
    }
    
    /// Gets all correlations with minimum sample size
    func getSignificantCorrelations(minSamples: Int = 10) async -> [(key: String, stats: CorrelationStats)] {
        let data = await loadData()
        return data.correlations
            .filter { $0.value.attempts >= minSamples }
            .sorted { $0.value.hitRate > $1.value.hitRate }
            .map { (key: $0.key, stats: $0.value) }
    }
    
    /// Gets top performing combinations
    func getTopCorrelations(count: Int = 5) async -> [(key: String, hitRate: Double, attempts: Int)] {
        let significant = await getSignificantCorrelations(minSamples: 5)
        return significant.prefix(count).map { ($0.key, $0.stats.hitRate, $0.stats.attempts) }
    }
    
    /// Human readable correlation insight
    func getInsight(for key: String, stats: CorrelationStats) -> String {
        let parts = key.components(separatedBy: "_")
        if parts.first == "all" {
            let count = parts[1]
            return "\(count) modül aynı fikirde olduğunda %\(Int(stats.hitRate * 100)) isabet (\(stats.attempts) örnek)"
        } else if parts.count >= 4 {
            let m1 = parts[0].capitalized
            let m2 = parts[2].capitalized
            return "\(m1) + \(m2) birlikte yüksekse %\(Int(stats.hitRate * 100)) isabet"
        }
        return key
    }
    
    // MARK: - Private
    
    private func bracketLabel(_ score: Double) -> String {
        if score >= 80 { return "80+" }
        if score >= 60 { return "60+" }
        return "low"
    }
    
    private func loadData() async -> CorrelationData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(CorrelationData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: CorrelationData) async {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}
