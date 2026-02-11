import Foundation

// MARK: - Alkindus Insight Generator
/// Generates human-readable insights from Alkindus learnings.
/// "Today I learned: Phoenix is strengthening in BIST"

actor AlkindusInsightGenerator {
    static let shared = AlkindusInsightGenerator()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("insights.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct InsightLog: Codable {
        var insights: [Insight]
        var lastGenerated: Date
        
        static var empty: InsightLog {
            InsightLog(insights: [], lastGenerated: Date.distantPast)
        }
    }
    
    struct Insight: Codable, Identifiable {
        let id: UUID
        let category: InsightCategory
        let title: String
        let detail: String
        let importance: InsightImportance
        let generatedAt: Date
        let relatedModules: [String]
        
        init(category: InsightCategory, title: String, detail: String, importance: InsightImportance, relatedModules: [String] = []) {
            self.id = UUID()
            self.category = category
            self.title = title
            self.detail = detail
            self.importance = importance
            self.generatedAt = Date()
            self.relatedModules = relatedModules
        }
    }
    
    enum InsightCategory: String, Codable {
        case correlation = "KORELASYON"
        case anomaly = "ANOMALİ"
        case trend = "TREND"
        case performance = "PERFORMANS"
        case regime = "REJİM"
        case warning = "UYARI"
        case discovery = "KEŞİF"
    }
    
    enum InsightImportance: String, Codable {
        case critical = "KRİTİK"
        case high = "YÜKSEK"
        case medium = "ORTA"
        case low = "DÜŞÜK"
    }
    
    // MARK: - Generate Daily Insights
    
    /// Generates insights from all Alkindus subsystems
    func generateDailyInsights() async -> [Insight] {
        var newInsights: [Insight] = []
        
        // 1. Correlation Insights
        let correlationInsights = await generateCorrelationInsights()
        newInsights.append(contentsOf: correlationInsights)
        
        // 2. Anomaly Insights
        let anomalyInsights = await generateAnomalyInsights()
        newInsights.append(contentsOf: anomalyInsights)
        
        // 3. Calibration Insights
        let calibrationInsights = await generateCalibrationInsights()
        newInsights.append(contentsOf: calibrationInsights)
        
        // Save insights
        await saveInsights(newInsights)
        
        return newInsights
    }
    
    // MARK: - Correlation Insights
    
    private func generateCorrelationInsights() async -> [Insight] {
        var insights: [Insight] = []
        
        let topCorrelations = await AlkindusCorrelationTracker.shared.getTopCorrelations(count: 3)
        
        for (key, hitRate, attempts) in topCorrelations {
            if hitRate >= 0.65 && attempts >= 10 {
                let insight = Insight(
                    category: .correlation,
                    title: "Güçlü Modül Kombinasyonu",
                    detail: "\(key.replacingOccurrences(of: "_", with: " + ")) birlikte olduğunda %\(Int(hitRate * 100)) isabet oranı (\(attempts) örnek)",
                    importance: hitRate >= 0.75 ? .high : .medium,
                    relatedModules: extractModules(from: key)
                )
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    // MARK: - Anomaly Insights
    
    private func generateAnomalyInsights() async -> [Insight] {
        var insights: [Insight] = []
        
        let anomalies = await AlkindusAnomalyDetector.shared.detectAnomalies()
        
        for anomaly in anomalies {
            let importance: InsightImportance = {
                switch anomaly.severity {
                case .critical: return .critical
                case .high: return .high
                case .medium: return .medium
                }
            }()
            
            let category: InsightCategory = anomaly.direction == .performingBelow ? .warning : .discovery
            
            let insight = Insight(
                category: category,
                title: anomaly.direction == .performingBelow ? "Performans Düşüşü" : "Performans Artışı",
                detail: anomaly.message,
                importance: importance,
                relatedModules: [anomaly.module]
            )
            insights.append(insight)
        }
        
        return insights
    }
    
    // MARK: - Calibration Insights
    
    private func generateCalibrationInsights() async -> [Insight] {
        var insights: [Insight] = []
        
        let stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
        
        // Top performer
        if let top = stats.topModule, top.hitRate >= 0.60 {
            let insight = Insight(
                category: .performance,
                title: "En Güvenilir Modül",
                detail: "\(top.name.capitalized) yüksek bracket'larda %\(Int(top.hitRate * 100)) isabet oranıyla lider",
                importance: .medium,
                relatedModules: [top.name]
            )
            insights.append(insight)
        }
        
        // Weakest performer
        if let weak = stats.weakestModule, weak.hitRate < 0.40 {
            let insight = Insight(
                category: .warning,
                title: "Zayıf Performans",
                detail: "\(weak.name.capitalized) sadece %\(Int(weak.hitRate * 100)) isabet - dikkatli değerlendir",
                importance: .high,
                relatedModules: [weak.name]
            )
            insights.append(insight)
        }
        
        let kulisStats = await HermesCalibrationService.shared.kulisGroupStats(minCount: 8)
        
        if let core = kulisStats.first(where: { $0.group == "core" }), core.hitRate >= 0.60 {
            let insight = Insight(
                category: .performance,
                title: "Kulis Çekirdek Gücü",
                detail: "Kulis çekirdek haberlerde %\(Int(core.hitRate * 100)) isabet (\(core.totalCount) olay). Ortalama hata \(Int(core.meanAbsError)) puan.",
                importance: .medium,
                relatedModules: ["hermes", "kulis"]
            )
            insights.append(insight)
        }
        
        if let rumor = kulisStats.first(where: { $0.group == "rumor" }), rumor.hitRate < 0.45 {
            let insight = Insight(
                category: .warning,
                title: "Kulis Dedikodu Riski",
                detail: "Söylenti/kulis grubunda isabet %\(Int(rumor.hitRate * 100)) (\(rumor.totalCount) olay). Bu grubu daha temkinli yorumla.",
                importance: .high,
                relatedModules: ["hermes", "kulis"]
            )
            insights.append(insight)
        }
        
        if let lowrel = kulisStats.first(where: { $0.group == "lowrel" }), lowrel.hitRate < 0.40 {
            let insight = Insight(
                category: .warning,
                title: "Düşük Güven Kulis",
                detail: "Düşük güvenli kaynaklarda isabet %\(Int(lowrel.hitRate * 100)) (\(lowrel.totalCount) olay).",
                importance: .high,
                relatedModules: ["hermes", "kulis"]
            )
            insights.append(insight)
        }
        
        return insights
    }
    
    // MARK: - API
    
    /// Gets today's insights
    func getTodaysInsights() async -> [Insight] {
        let data = await loadData()
        let calendar = Calendar.current
        return data.insights.filter { calendar.isDateInToday($0.generatedAt) }
    }
    
    /// Gets recent insights (last 7 days)
    func getRecentInsights(days: Int = 7) async -> [Insight] {
        let data = await loadData()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return data.insights.filter { $0.generatedAt >= cutoff }
            .sorted { $0.generatedAt > $1.generatedAt }
    }
    
    /// Check if insights should be regenerated
    func shouldRegenerate() async -> Bool {
        let data = await loadData()
        let calendar = Calendar.current
        return !calendar.isDateInToday(data.lastGenerated)
    }
    
    // MARK: - Private
    
    private func extractModules(from key: String) -> [String] {
        let parts = key.components(separatedBy: "_")
        var modules: [String] = []
        for part in parts {
            if ["orion", "atlas", "hermes", "aether", "phoenix", "athena", "demeter"].contains(part.lowercased()) {
                modules.append(part)
            }
        }
        return modules
    }
    
    private func loadData() async -> InsightLog {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(InsightLog.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveInsights(_ newInsights: [Insight]) async {
        var data = await loadData()
        data.insights.append(contentsOf: newInsights)
        
        // Keep only last 100 insights
        if data.insights.count > 100 {
            data.insights = Array(data.insights.suffix(100))
        }
        
        data.lastGenerated = Date()
        
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}
