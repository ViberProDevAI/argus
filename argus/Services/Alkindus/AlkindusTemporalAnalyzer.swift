import Foundation

// MARK: - Alkindus Temporal Analyzer
/// Learns time-based patterns in module performance.
/// "Mondays are weak for momentum modules"
/// "End of month boosts Aether accuracy"

// MARK: - Timezone Helpers

private extension Date {
    /// BIST için İstanbul timezone'ında saat
    var istanbulHour: Int {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = "HH"
        return Int(formatter.string(from: self)) ?? 0
    }

    /// NYSE için New York timezone'unda saat
    var newYorkHour: Int {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "HH"
        return Int(formatter.string(from: self)) ?? 0
    }

    /// Sembolün market'ına göre local saat
    func marketHour(for symbol: String) -> Int {
        let isBist = symbol.hasSuffix(".IS") || symbol.uppercased().contains("BIST")
        return isBist ? istanbulHour : newYorkHour
    }

    /// Get weekday symbol for given market
    func marketWeekday(for symbol: String) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeZone = symbol.hasSuffix(".IS") || symbol.uppercased().contains("BIST")
            ? TimeZone(identifier: "Europe/Istanbul")
            : TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
}

/// Get timezone-aware hour for symbol
private func getMarketHour(for symbol: String, from date: Date = Date()) -> String {
    let hour = date.marketHour(for: symbol)
    return String(format: "%02d", hour)
}

actor AlkindusTemporalAnalyzer {
    static let shared = AlkindusTemporalAnalyzer()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("temporal.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct TemporalData: Codable {
        var dayOfWeek: [String: DayStats]      // "Monday", "Tuesday", etc.
        var hourOfDay: [String: HourStats]     // "09", "14", etc.
        var monthOfYear: [String: MonthStats]  // "January", etc.
        var weekOfMonth: [String: WeekStats]   // "1", "2", "3", "4"
        var lastUpdated: Date
        
        static var empty: TemporalData {
            TemporalData(dayOfWeek: [:], hourOfDay: [:], monthOfYear: [:], weekOfMonth: [:], lastUpdated: Date())
        }
    }
    
    struct DayStats: Codable {
        var modulePerformance: [String: TimeSlotStats]
    }
    
    struct HourStats: Codable {
        var modulePerformance: [String: TimeSlotStats]
    }
    
    struct MonthStats: Codable {
        var modulePerformance: [String: TimeSlotStats]
    }
    
    struct WeekStats: Codable {
        var modulePerformance: [String: TimeSlotStats]
    }
    
    struct TimeSlotStats: Codable {
        var attempts: Int
        var correct: Int
        var hitRate: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
    }
    
    // MARK: - API
    
    /// Records a decision outcome with temporal context
    func recordOutcome(module: String, wasCorrect: Bool, timestamp: Date = Date(), symbol: String = "") async {
        var data = await loadData()
        let calendar = Calendar.current

        // Extract temporal components with timezone awareness
        let weekday = timestamp.marketWeekday(for: symbol)
        let hour = getMarketHour(for: symbol, from: timestamp)
        let month = calendar.monthSymbols[calendar.component(.month, from: timestamp) - 1]
        let weekOfMonth = String(calendar.component(.weekOfMonth, from: timestamp))
        
        // 1. Day of week
        if data.dayOfWeek[weekday] == nil {
            data.dayOfWeek[weekday] = DayStats(modulePerformance: [:])
        }
        if data.dayOfWeek[weekday]?.modulePerformance[module] == nil {
            data.dayOfWeek[weekday]?.modulePerformance[module] = TimeSlotStats(attempts: 0, correct: 0)
        }
        data.dayOfWeek[weekday]?.modulePerformance[module]?.attempts += 1
        if wasCorrect { data.dayOfWeek[weekday]?.modulePerformance[module]?.correct += 1 }
        
        // 2. Hour of day
        if data.hourOfDay[hour] == nil {
            data.hourOfDay[hour] = HourStats(modulePerformance: [:])
        }
        if data.hourOfDay[hour]?.modulePerformance[module] == nil {
            data.hourOfDay[hour]?.modulePerformance[module] = TimeSlotStats(attempts: 0, correct: 0)
        }
        data.hourOfDay[hour]?.modulePerformance[module]?.attempts += 1
        if wasCorrect { data.hourOfDay[hour]?.modulePerformance[module]?.correct += 1 }
        
        // 3. Month of year
        if data.monthOfYear[month] == nil {
            data.monthOfYear[month] = MonthStats(modulePerformance: [:])
        }
        if data.monthOfYear[month]?.modulePerformance[module] == nil {
            data.monthOfYear[month]?.modulePerformance[module] = TimeSlotStats(attempts: 0, correct: 0)
        }
        data.monthOfYear[month]?.modulePerformance[module]?.attempts += 1
        if wasCorrect { data.monthOfYear[month]?.modulePerformance[module]?.correct += 1 }
        
        // 4. Week of month
        if data.weekOfMonth[weekOfMonth] == nil {
            data.weekOfMonth[weekOfMonth] = WeekStats(modulePerformance: [:])
        }
        if data.weekOfMonth[weekOfMonth]?.modulePerformance[module] == nil {
            data.weekOfMonth[weekOfMonth]?.modulePerformance[module] = TimeSlotStats(attempts: 0, correct: 0)
        }
        data.weekOfMonth[weekOfMonth]?.modulePerformance[module]?.attempts += 1
        if wasCorrect { data.weekOfMonth[weekOfMonth]?.modulePerformance[module]?.correct += 1 }
        
        data.lastUpdated = Date()
        await saveData(data)
    }
    
    /// Gets best/worst days for a module
    func getDayInsights(for module: String) async -> (bestDay: String, worstDay: String)? {
        let data = await loadData()
        
        let dayPerformance = data.dayOfWeek.compactMap { day, stats -> (String, Double)? in
            guard let modStats = stats.modulePerformance[module], modStats.attempts >= 5 else { return nil }
            return (day, modStats.hitRate)
        }
        
        guard dayPerformance.count >= 2 else { return nil }
        
        let sorted = dayPerformance.sorted { $0.1 > $1.1 }
        return (sorted.first!.0, sorted.last!.0)
    }
    
    /// Gets temporal anomalies (times when module is significantly better/worse)
    func getTemporalAnomalies(threshold: Double = 0.15) async -> [TemporalAnomaly] {
        let data = await loadData()
        var anomalies: [TemporalAnomaly] = []
        
        // Check day of week
        for (day, stats) in data.dayOfWeek {
            for (module, modStats) in stats.modulePerformance {
                guard modStats.attempts >= 10 else { continue }
                
                // Calculate overall module average
                let allDayStats = data.dayOfWeek.values.compactMap { $0.modulePerformance[module] }
                let totalAttempts = allDayStats.reduce(0) { $0 + $1.attempts }
                let totalCorrect = allDayStats.reduce(0) { $0 + $1.correct }
                let avgRate = totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0.5
                
                let deviation = modStats.hitRate - avgRate
                if abs(deviation) >= threshold {
                    anomalies.append(TemporalAnomaly(
                        timeSlot: day,
                        timeType: .dayOfWeek,
                        module: module,
                        deviation: deviation,
                        hitRate: modStats.hitRate,
                        samples: modStats.attempts
                    ))
                }
            }
        }
        
        // Check week of month (especially week 4 = month end)
        for (week, stats) in data.weekOfMonth {
            for (module, modStats) in stats.modulePerformance {
                guard modStats.attempts >= 10 else { continue }
                
                let allWeekStats = data.weekOfMonth.values.compactMap { $0.modulePerformance[module] }
                let totalAttempts = allWeekStats.reduce(0) { $0 + $1.attempts }
                let totalCorrect = allWeekStats.reduce(0) { $0 + $1.correct }
                let avgRate = totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0.5
                
                let deviation = modStats.hitRate - avgRate
                if abs(deviation) >= threshold {
                    anomalies.append(TemporalAnomaly(
                        timeSlot: "Hafta \(week)",
                        timeType: .weekOfMonth,
                        module: module,
                        deviation: deviation,
                        hitRate: modStats.hitRate,
                        samples: modStats.attempts
                    ))
                }
            }
        }
        
        return anomalies.sorted { abs($0.deviation) > abs($1.deviation) }
    }
    
    /// Gets current time context advice
    func getCurrentTimeAdvice() async -> String? {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: now) - 1]
        let weekOfMonth = calendar.component(.weekOfMonth, from: now)
        
        let data = await loadData()
        var advice: [String] = []
        
        // Check if today has any strong patterns
        if let dayStats = data.dayOfWeek[weekday] {
            let strong = dayStats.modulePerformance
                .filter { $0.value.attempts >= 10 && $0.value.hitRate >= 0.65 }
                .sorted { $0.value.hitRate > $1.value.hitRate }
            
            if let best = strong.first {
                advice.append("\(weekday) günleri \(best.key.capitalized) güçlü (%\(Int(best.value.hitRate * 100)))")
            }
            
            let weak = dayStats.modulePerformance
                .filter { $0.value.attempts >= 10 && $0.value.hitRate < 0.40 }
            
            if let weakest = weak.first {
                advice.append("\(weekday) günleri \(weakest.key.capitalized) zayıf (%\(Int(weakest.value.hitRate * 100)))")
            }
        }
        
        // Check month end effect
        if weekOfMonth >= 4 {
            if let weekStats = data.weekOfMonth["4"] {
                let aetherStats = weekStats.modulePerformance["aether"]
                if let aether = aetherStats, aether.hitRate >= 0.60 && aether.attempts >= 5 {
                    advice.append("Ay sonu - Aether güçleniyor")
                }
            }
        }
        
        return advice.isEmpty ? nil : advice.joined(separator: " • ")
    }
    
    // MARK: - Private
    
    private func loadData() async -> TemporalData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(TemporalData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: TemporalData) async {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}

// MARK: - Temporal Anomaly Model

enum TimeType: String, Codable {
    case dayOfWeek = "GÜN"
    case hourOfDay = "SAAT"
    case monthOfYear = "AY"
    case weekOfMonth = "HAFTA"
}

struct TemporalAnomaly: Codable {
    let timeSlot: String
    let timeType: TimeType
    let module: String
    let deviation: Double
    let hitRate: Double
    let samples: Int
    
    var message: String {
        let direction = deviation > 0 ? "güçlü" : "zayıf"
        return "\(timeSlot): \(module.capitalized) %\(Int(abs(deviation) * 100)) \(direction)"
    }
}
