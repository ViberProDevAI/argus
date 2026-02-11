import Foundation

actor HermesCalibrationService {
    static let shared = HermesCalibrationService()
    
    private let weightsKey = "hermes_event_calibration_weights_v1"
    private let profilesKey = "hermes_event_calibration_profiles_v2"
    private let pendingKey = "hermes_event_calibration_pending_v1"
    
    private var multipliers: [String: Double] = [:] // key: scope|eventType (legacy)
    private var profiles: [String: HermesCalibrationProfile] = [:]
    private var pending: [HermesCalibrationItem] = []
    
    private init() {
        if let loaded: [String: Double] = UserDefaults.standard.dictionary(forKey: weightsKey) as? [String: Double] {
            self.multipliers = loaded
        }
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([String: HermesCalibrationProfile].self, from: data) {
            self.profiles = decoded
        } else if !multipliers.isEmpty {
            // Migrate legacy multipliers into profiles if available.
            // var migrated: [String: HermesCalibrationProfile] = [:]
            // for (key, value) in multipliers {
            //    migrated[key] = HermesCalibrationProfile(multiplier: value)
            // }
            // self.profiles = migrated
        }
        if let data = UserDefaults.standard.data(forKey: pendingKey),
           let decoded = try? JSONDecoder().decode([HermesCalibrationItem].self, from: data) {
            self.pending = decoded
        }
    }
    
    func adjustedScore(for baseScore: Double, scope: HermesEventScope, eventType: HermesEventType, flags: [HermesRiskFlag]) -> Double {
        let key = makeKey(scope: scope, eventType: eventType, group: calibrationGroup(scope: scope, flags: flags))
        let profile = profiles[key] ?? HermesCalibrationProfile()
        let clampedBase = max(0.0, min(baseScore, 100.0))
        
        var adjusted = (clampedBase - profile.bias) * profile.multiplier
        adjusted = max(0.0, min(adjusted, 100.0))
        
        if let bucket = profile.bucket(for: clampedBase), bucket.count >= 5, bucket.predictedAvg > 0.1 {
            let ratio = bucket.realizedAvg / bucket.predictedAvg
            let blend = min(0.4, Double(bucket.count) / 25.0 * 0.4)
            adjusted = adjusted * (1.0 - blend) + (adjusted * ratio) * blend
        }
        
        if profile.totalCount >= 20, profile.hitRate < 0.45 {
            adjusted = adjusted * 0.85 + 50.0 * 0.15
        }
        
        return max(0.0, min(adjusted, 100.0))
    }
    
    func summary(scope: HermesEventScope, eventType: HermesEventType, horizon: HermesEventHorizon, flags: [HermesRiskFlag]) -> HermesCalibrationSummary {
        let group = calibrationGroup(scope: scope, flags: flags)
        let key = makeKey(scope: scope, eventType: eventType, group: group)
        let profile = profiles[key] ?? HermesCalibrationProfile()
        let horizons = evaluationDays(for: scope, horizon: horizon)
        let benchmarks = benchmarkCandidates(for: scope)
        return HermesCalibrationSummary(
            multiplier: profile.multiplier,
            bias: profile.bias,
            totalCount: profile.totalCount,
            hitRate: profile.hitRate,
            meanAbsError: profile.meanAbsError(),
            lastUpdated: profile.lastUpdated,
            benchmarkCandidates: benchmarks,
            primaryDays: horizons.primary,
            secondaryDays: horizons.secondary,
            calibrationGroup: group
        )
    }
    
    func kulisGroupStats(minCount: Int = 5) -> [HermesKulisCalibrationStat] {
        var aggregates: [String: HermesKulisCalibrationAccumulator] = [:]
        
        for (key, profile) in profiles {
            let parts = key.split(separator: "|")
            guard parts.count >= 3, parts[0] == "bist" else { continue }
            let group = String(parts[2])
            let count = max(profile.totalCount, 0)
            guard count > 0 else { continue }
            
            var current = aggregates[group] ?? HermesKulisCalibrationAccumulator()
            current.totalCount += count
            current.hitRateSum += profile.hitRate * Double(count)
            current.meanAbsErrorSum += profile.meanAbsError() * Double(count)
            if let updatedAt = profile.lastUpdated {
                current.lastUpdated = max(current.lastUpdated ?? updatedAt, updatedAt)
            }
            aggregates[group] = current
        }
        
        return aggregates.compactMap { key, value in
            guard value.totalCount >= minCount else { return nil }
            return HermesKulisCalibrationStat(
                group: key,
                totalCount: value.totalCount,
                hitRate: value.hitRateSum / Double(value.totalCount),
                meanAbsError: value.meanAbsErrorSum / Double(value.totalCount),
                lastUpdated: value.lastUpdated
            )
        }
        .sorted { $0.group < $1.group }
    }
    
    func enqueue(event: HermesEvent) async {
        let item = HermesCalibrationItem(
            eventId: event.id,
            scope: event.scope,
            eventType: event.eventType,
            symbol: event.symbol,
            publishedAt: event.publishedAt,
            predictedScore: event.finalScore,
            polarity: event.polarity,
            horizonHint: event.horizonHint,
            calibrationGroup: calibrationGroup(scope: event.scope, flags: event.riskFlags)
        )
        pending.append(item)
        persistPending()
        await processPendingEvents()
    }
    
    func processPendingEvents() async {
        guard !pending.isEmpty else { return }
        
        var remaining: [HermesCalibrationItem] = []
        
        for item in pending {
            guard let outcome = await evaluate(item: item) else {
                remaining.append(item)
                continue
            }
            
            applyCalibration(item: item, outcome: outcome)
        }
        
        pending = remaining
        persistPending()
        persistMultipliers()
        persistProfiles()
    }
    
    private func evaluate(item: HermesCalibrationItem) async -> HermesCalibrationOutcome? {
        let now = Date()
        let ageDays = now.timeIntervalSince(item.publishedAt) / 86400.0
        
        // Only evaluate when enough time has passed for at least T+1d.
        if ageDays < 1.0 { return nil }
        
        let symbol = normalizeSymbol(item.symbol, scope: item.scope)
        let benchmarkSymbols = benchmarkCandidates(for: item.scope)
        let horizons = evaluationDays(for: item.scope, horizon: item.horizonHint)
        
        _ = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
        
        guard let entry = await MarketDataStore.shared.fetchHistoricalClose(symbol: symbol, targetDate: item.publishedAt) else {
            return nil
        }
        
        var benchmark: String? = nil
        var benchmarkEntry: Double? = nil
        for candidate in benchmarkSymbols {
            _ = await MarketDataStore.shared.ensureCandles(symbol: candidate, timeframe: "1day")
            if let entryValue = await MarketDataStore.shared.fetchHistoricalClose(symbol: candidate, targetDate: item.publishedAt) {
                benchmark = candidate
                benchmarkEntry = entryValue
                break
            }
        }
        
        guard let benchmarkSymbol = benchmark, let benchmarkEntryValue = benchmarkEntry else {
            return nil
        }
        
        let primaryDate = Calendar.current.date(byAdding: .day, value: horizons.primary, to: item.publishedAt) ?? item.publishedAt
        let secondaryDate = Calendar.current.date(byAdding: .day, value: horizons.secondary, to: item.publishedAt) ?? item.publishedAt
        
        let exitPrimary = await MarketDataStore.shared.fetchHistoricalClose(symbol: symbol, targetDate: primaryDate)
        let exitSecondary = await MarketDataStore.shared.fetchHistoricalClose(symbol: symbol, targetDate: secondaryDate)
        
        let benchPrimary = await MarketDataStore.shared.fetchHistoricalClose(symbol: benchmarkSymbol, targetDate: primaryDate)
        let benchSecondary = await MarketDataStore.shared.fetchHistoricalClose(symbol: benchmarkSymbol, targetDate: secondaryDate)
        
        guard let exitPrimaryVal = exitPrimary, let benchPrimaryVal = benchPrimary else {
            return nil
        }
        
        let retPrimary = (exitPrimaryVal - entry) / entry * 100.0
        let benchRetPrimary = (benchPrimaryVal - benchmarkEntryValue) / benchmarkEntryValue * 100.0
        let arPrimary = retPrimary - benchRetPrimary
        
        var arSecondary: Double? = nil
        if let exitSecondaryVal = exitSecondary, let benchSecondaryVal = benchSecondary {
            let retSecondary = (exitSecondaryVal - entry) / entry * 100.0
            let benchRetSecondary = (benchSecondaryVal - benchmarkEntryValue) / benchmarkEntryValue * 100.0
            arSecondary = retSecondary - benchRetSecondary
        }
        
        return HermesCalibrationOutcome(arPrimary: arPrimary, arSecondary: arSecondary)
    }
    
    private func applyCalibration(item: HermesCalibrationItem, outcome: HermesCalibrationOutcome) {
        let key = makeKey(scope: item.scope, eventType: item.eventType, group: item.calibrationGroup)
        let currentProfile = profiles[key] ?? HermesCalibrationProfile()
        
        let realized = outcome.arSecondary ?? outcome.arPrimary
        let predicted = item.predictedScore
        
        // Map realized impact to 0-100 style for comparison (simple clamp)
        let realizedScore = max(0.0, min((realized + 10.0) * 5.0, 100.0))
        let error = (predicted - realizedScore) / 100.0 // positive = overestimate
        
        // Adjust multiplier and bias gently
        let multiplierAdjustment = error * 0.18
        let biasAdjustment = error * 8.0
        var updatedProfile = currentProfile
        updatedProfile.multiplier = max(0.6, min(1.25, currentProfile.multiplier - multiplierAdjustment))
        updatedProfile.bias = max(-15.0, min(15.0, currentProfile.bias + biasAdjustment))
        
        let predictedSign = HermesCalibrationProfile.sign(for: predicted)
        let realizedSign = HermesCalibrationProfile.sign(for: realizedScore)
        let hit = (predictedSign == realizedSign) || (predictedSign == 0 && realizedSign == 0)
        
        updatedProfile.updateBucket(for: predicted, realizedScore: realizedScore, hit: hit)
        profiles[key] = updatedProfile
        multipliers[key] = updatedProfile.multiplier
    }
    
    private func makeKey(scope: HermesEventScope, eventType: HermesEventType, group: String?) -> String {
        guard let group, !group.isEmpty else {
            return "\(scope.rawValue)|\(eventType.rawValue)"
        }
        return "\(scope.rawValue)|\(eventType.rawValue)|\(group)"
    }
    
    private func persistMultipliers() {
        UserDefaults.standard.set(multipliers, forKey: weightsKey)
    }
    
    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }
    
    private func persistPending() {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }
}

private struct HermesCalibrationItem: Codable {
    let eventId: UUID
    let scope: HermesEventScope
    let eventType: HermesEventType
    let symbol: String
    let publishedAt: Date
    let predictedScore: Double
    let polarity: HermesEventPolarity?
    let horizonHint: HermesEventHorizon
    let calibrationGroup: String?
}

private struct HermesCalibrationOutcome {
    let arPrimary: Double
    let arSecondary: Double?
}

private struct HermesCalibrationProfile: Codable {
    var multiplier: Double = 1.0
    var bias: Double = 0.0
    var buckets: [HermesScoreBucket] = HermesScoreBucket.defaultBuckets
    var totalCount: Int = 0
    var hitRate: Double = 0.5
    var lastUpdated: Date? = nil
    
    init(multiplier: Double = 1.0) {
        self.multiplier = multiplier
    }
    
    func bucket(for score: Double) -> HermesScoreBucket? {
        buckets.first(where: { $0.contains(score) })
    }
    
    mutating func updateBucket(for predictedScore: Double, realizedScore: Double, hit: Bool) {
        totalCount += 1
        let hitValue = hit ? 1.0 : 0.0
        hitRate = ((hitRate * Double(totalCount - 1)) + hitValue) / Double(totalCount)
        lastUpdated = Date()
        
        guard let index = buckets.firstIndex(where: { $0.contains(predictedScore) }) else { return }
        buckets[index].update(predictedScore: predictedScore, realizedScore: realizedScore, hit: hit)
    }
    
    static func sign(for score: Double) -> Int {
        if score >= 55 { return 1 }
        if score <= 45 { return -1 }
        return 0
    }
    
    func meanAbsError() -> Double {
        let total = buckets.reduce(0) { $0 + $1.count }
        guard total > 0 else { return 0 }
        let weighted = buckets.reduce(0.0) { partial, bucket in
            partial + (bucket.meanAbsError * Double(bucket.count))
        }
        return weighted / Double(total)
    }
}

private struct HermesScoreBucket: Codable {
    let min: Double
    let max: Double
    var count: Int
    var predictedAvg: Double
    var realizedAvg: Double
    var meanAbsError: Double
    var hitRate: Double
    
    var range: ClosedRange<Double> { min...max }
    
    func contains(_ value: Double) -> Bool {
        range.contains(value)
    }
    
    mutating func update(predictedScore: Double, realizedScore: Double, hit: Bool) {
        let newCount = count + 1
        predictedAvg = (predictedAvg * Double(count) + predictedScore) / Double(newCount)
        realizedAvg = (realizedAvg * Double(count) + realizedScore) / Double(newCount)
        meanAbsError = (meanAbsError * Double(count) + abs(predictedScore - realizedScore)) / Double(newCount)
        let hitValue = hit ? 1.0 : 0.0
        hitRate = (hitRate * Double(count) + hitValue) / Double(newCount)
        count = newCount
    }
    
    static let defaultBuckets: [HermesScoreBucket] = [
        HermesScoreBucket(min: 0, max: 20, count: 0, predictedAvg: 10, realizedAvg: 10, meanAbsError: 0, hitRate: 0.5),
        HermesScoreBucket(min: 20, max: 40, count: 0, predictedAvg: 30, realizedAvg: 30, meanAbsError: 0, hitRate: 0.5),
        HermesScoreBucket(min: 40, max: 60, count: 0, predictedAvg: 50, realizedAvg: 50, meanAbsError: 0, hitRate: 0.5),
        HermesScoreBucket(min: 60, max: 80, count: 0, predictedAvg: 70, realizedAvg: 70, meanAbsError: 0, hitRate: 0.5),
        HermesScoreBucket(min: 80, max: 100, count: 0, predictedAvg: 90, realizedAvg: 90, meanAbsError: 0, hitRate: 0.5)
    ]
}

struct HermesCalibrationSummary: Sendable {
    let multiplier: Double
    let bias: Double
    let totalCount: Int
    let hitRate: Double
    let meanAbsError: Double
    let lastUpdated: Date?
    let benchmarkCandidates: [String]
    let primaryDays: Int
    let secondaryDays: Int
    let calibrationGroup: String?
}

private struct HermesEvaluationHorizon {
    let primary: Int
    let secondary: Int
}

private struct HermesKulisCalibrationAccumulator {
    var totalCount: Int = 0
    var hitRateSum: Double = 0.0
    var meanAbsErrorSum: Double = 0.0
    var lastUpdated: Date? = nil
}

struct HermesKulisCalibrationStat: Sendable {
    let group: String
    let totalCount: Int
    let hitRate: Double
    let meanAbsError: Double
    let lastUpdated: Date?
}

private func benchmarkCandidates(for scope: HermesEventScope) -> [String] {
    switch scope {
    case .bist:
        return ["XU100.IS", "XU030.IS", "XU050.IS"]
    case .global:
        return ["SPY", "QQQ"]
    }
}

private func evaluationDays(for scope: HermesEventScope, horizon: HermesEventHorizon) -> HermesEvaluationHorizon {
    switch scope {
    case .bist:
        switch horizon {
        case .intraday:
            return HermesHorizonConfig.bistIntraday
        case .shortTerm:
            return HermesHorizonConfig.bistShortTerm
        case .multiweek:
            return HermesHorizonConfig.bistMultiweek
        }
    case .global:
        switch horizon {
        case .intraday:
            return HermesHorizonConfig.globalIntraday
        case .shortTerm:
            return HermesHorizonConfig.globalShortTerm
        case .multiweek:
            return HermesHorizonConfig.globalMultiweek
        }
    }
}

private func normalizeSymbol(_ symbol: String, scope: HermesEventScope) -> String {
    guard scope == .bist else { return symbol }
    if symbol.uppercased().hasSuffix(".IS") { return symbol }
    return "\(symbol.uppercased()).IS"
}

private func calibrationGroup(scope: HermesEventScope, flags: [HermesRiskFlag]) -> String? {
    guard scope == .bist else { return nil }
    if flags.contains(.rumor) {
        return "rumor"
    }
    if flags.contains(.lowReliability) {
        return "lowrel"
    }
    return "core"
}

private enum HermesHorizonConfig {
    static let bistIntraday = HermesEvaluationHorizon(primary: 1, secondary: 2)
    static let bistShortTerm = HermesEvaluationHorizon(primary: 2, secondary: 4)
    static let bistMultiweek = HermesEvaluationHorizon(primary: 7, secondary: 14)
    static let globalIntraday = HermesEvaluationHorizon(primary: 1, secondary: 2)
    static let globalShortTerm = HermesEvaluationHorizon(primary: 1, secondary: 3)
    static let globalMultiweek = HermesEvaluationHorizon(primary: 5, secondary: 10)
}
