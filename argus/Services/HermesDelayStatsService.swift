import Foundation

final class HermesDelayStatsService {
    static let shared = HermesDelayStatsService()
    
    private let storeKey = "hermes_delay_stats_v1"
    private let maxSamplesPerSource = 120
    private var stats: [String: HermesDelayStats] = [:]
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([String: HermesDelayStats].self, from: data) {
            stats = decoded
        }
    }
    
    func record(source: String, delayMinutes: Double, scope: HermesEventScope) {
        guard delayMinutes.isFinite, delayMinutes >= 0 else { return }
        let key = makeKey(source: source, scope: scope)
        var current = stats[key] ?? HermesDelayStats()
        current.addSample(delayMinutes, maxSamples: maxSamplesPerSource)
        stats[key] = current
        persist()
    }
    
    func summary(source: String, scope: HermesEventScope) -> HermesDelaySummary {
        let key = makeKey(source: source, scope: scope)
        let current = stats[key] ?? HermesDelayStats()
        return HermesDelaySummary(
            count: current.count,
            averageMinutes: current.averageMinutes,
            p50Minutes: current.percentile(50),
            p90Minutes: current.percentile(90)
        )
    }
    
    func describe(source: String, scope: HermesEventScope) -> String {
        let summary = summary(source: source, scope: scope)
        if summary.count == 0 {
            return "Yeni kaynak, veri birikiyor."
        }
        let avg = Int(summary.averageMinutes.rounded())
        let p90 = Int(summary.p90Minutes.rounded())
        return "Ort. \(avg) dk (P90 \(p90) dk, \(summary.count) örnek)."
    }
    
    func describe(source: String) -> String {
        let global = summary(source: source, scope: .global)
        let bist = summary(source: source, scope: .bist)
        
        if global.count + bist.count == 0 {
            return "Yeni kaynak, veri birikiyor."
        }
        
        let avg = weightedAverage(global.averageMinutes, global.count, bist.averageMinutes, bist.count)
        let p90 = max(global.p90Minutes, bist.p90Minutes)
        let total = global.count + bist.count
        return "Ort. \(Int(avg.rounded())) dk (P90 \(Int(p90.rounded())) dk, \(total) örnek)."
    }
    
    func topSources(scope: HermesEventScope, limit: Int = 5) -> [HermesDelaySourceStat] {
        stats.compactMap { key, value in
            let parts = key.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, parts[0] == scope.rawValue else { return nil }
            let source = String(parts[1])
            return HermesDelaySourceStat(
                source: source,
                summary: HermesDelaySummary(
                    count: value.count,
                    averageMinutes: value.averageMinutes,
                    p50Minutes: value.percentile(50),
                    p90Minutes: value.percentile(90)
                ),
                recentSamples: value.recentSamples(limit: 12)
            )
        }
        .sorted { $0.summary.averageMinutes < $1.summary.averageMinutes }
        .prefix(limit)
        .map { $0 }
    }
    
    private func weightedAverage(_ a: Double, _ ac: Int, _ b: Double, _ bc: Int) -> Double {
        let total = max(ac + bc, 1)
        return (a * Double(ac) + b * Double(bc)) / Double(total)
    }
    
    private func makeKey(source: String, scope: HermesEventScope) -> String {
        let normalized = source.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(scope.rawValue)|\(normalized)"
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}

private struct HermesDelayStats: Codable {
    private(set) var samples: [Double] = []
    
    var count: Int { samples.count }
    var averageMinutes: Double {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0, +)
        return sum / Double(samples.count)
    }
    
    mutating func addSample(_ value: Double, maxSamples: Int) {
        samples.append(value)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }
    
    func percentile(_ percentile: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let rank = max(0, min(sorted.count - 1, Int(round((percentile / 100.0) * Double(sorted.count - 1)))))
        return sorted[rank]
    }
    
    func recentSamples(limit: Int) -> [Double] {
        guard limit > 0, !samples.isEmpty else { return [] }
        return Array(samples.suffix(limit))
    }
}

struct HermesDelaySummary: Sendable {
    let count: Int
    let averageMinutes: Double
    let p50Minutes: Double
    let p90Minutes: Double
}

struct HermesDelaySourceStat: Sendable {
    let source: String
    let summary: HermesDelaySummary
    let recentSamples: [Double]
}
