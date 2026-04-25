import Foundation

// MARK: - Chiron Regret Engine
/// Pişmanlık metriklerini hesaplar: Önlenebilir kayıplar ve kaçırılan fırsatlar

actor ChironRegretEngine {
    static let shared = ChironRegretEngine()
    
    private let dataLake = ChironDataLakeService.shared
    
    // MARK: - Types
    
    enum RegretType: String, Codable, Sendable {
        case preventableLoss = "PREVENTABLE_LOSS"       // Modül uyardı, dinlemedik, kaybettik
        case missedOpportunity = "MISSED_OPPORTUNITY"   // Modül "AL" dedi, girmedik, kaçırdık
    }
    
    struct RegretRecord: Codable, Identifiable, Sendable {
        let id: UUID
        let tradeId: UUID?
        let symbol: String
        let type: RegretType
        let ignoredModule: String       // Hangi modül uyarmıştı
        let moduleSignal: Double        // Modülün verdiği skor
        let actualOutcome: Double       // Gerçekleşen PnL %
        let potentialOutcome: Double    // Dinleseydik ne olurdu (tahmini)
        let regretAmount: Double        // Pişmanlık miktarı ($)
        let date: Date
        let lesson: String              // Öğrenilen ders
    }
    
    struct RegretSummary: Codable, Sendable {
        let totalPreventableLossCount: Int
        let totalMissedOpportunityCount: Int
        let totalPreventableLossAmount: Double
        let totalMissedGainAmount: Double
        let mostIgnoredModule: String?
        let lessons: [String]
        let generatedAt: Date
    }
    
    // MARK: - Persistence
    
    private var regretRecords: [RegretRecord] = []
    
    private var regretFilePath: URL {
        FileManager.default.documentsURL
            .appendingPathComponent("ChironDataLake/regret_records.json")
    }
    
    init() {
        Task { await loadRecords() }
    }
    
    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: regretFilePath.path) else { return }
        do {
            let data = try Data(contentsOf: regretFilePath)
            regretRecords = try JSONDecoder().decode([RegretRecord].self, from: data)
        } catch {
            print("⚠️ ChironRegretEngine: Kayıtlar yüklenemedi - \(error)")
        }
    }
    
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(regretRecords)
            try data.write(to: regretFilePath)
        } catch {
            print("❌ ChironRegretEngine: Kayıtlar kaydedilemedi - \(error)")
        }
    }
    
    // MARK: - Kayıt Ekleme
    
    /// Trade sonlandığında pişmanlık analizi yapar
    func analyzeTradeForRegret(_ trade: TradeOutcomeRecord) async {
        // Kayıp trade'lerde uyarı veren modülleri kontrol et
        if trade.pnlPercent < 0 {
            await checkForPreventableLoss(trade)
        }
    }
    
    /// Kaçırılan fırsat kaydı ekler (Watchlist'ten çağrılır)
    func recordMissedOpportunity(
        symbol: String,
        moduleSignal: Double,
        moduleName: String,
        actualGain: Double
    ) async {
        let record = RegretRecord(
            id: UUID(),
            tradeId: nil,
            symbol: symbol,
            type: .missedOpportunity,
            ignoredModule: moduleName,
            moduleSignal: moduleSignal,
            actualOutcome: actualGain,
            potentialOutcome: actualGain,
            regretAmount: 0, // Gerçek miktar hesaplanamaz
            date: Date(),
            lesson: "📈 \(moduleName) bu sembol için %\(Int(actualGain)) kazanç fırsatı tespit etmişti ancak pozisyon alınmadı."
        )
        
        regretRecords.append(record)
        
        // Son 100 kayıt tut
        if regretRecords.count > 100 {
            regretRecords = Array(regretRecords.suffix(100))
        }
        
        saveRecords()
        
        print("😔 Chiron Regret: Kaçırılan fırsat - \(symbol) (\(moduleName) sinyal: \(Int(moduleSignal)), kazanç: %\(String(format: "%.1f", actualGain)))")
    }
    
    // MARK: - Private Analysis
    
    private func checkForPreventableLoss(_ trade: TradeOutcomeRecord) async {
        var warnings: [(module: String, signal: Double)] = []
        
        // Hangi modüller uyarı veriyordu? (< 45 = dikkatli ol sinyali)
        if let orion = trade.orionScoreAtEntry, orion < 45 {
            warnings.append(("orion", orion))
        }
        if let atlas = trade.atlasScoreAtEntry, atlas < 45 {
            warnings.append(("atlas", atlas))
        }
        if let aether = trade.aetherScoreAtEntry, aether < 45 {
            warnings.append(("aether", aether))
        }
        if let phoenix = trade.phoenixScoreAtEntry, phoenix < 45 {
            warnings.append(("phoenix", phoenix))
        }
        
        // Eğer en az bir modül uyarı verdiyse → Önlenebilir Kayıp
        for warning in warnings {
            let estimatedLoss = abs(trade.pnlPercent)
            
            let record = RegretRecord(
                id: UUID(),
                tradeId: trade.id,
                symbol: trade.symbol,
                type: .preventableLoss,
                ignoredModule: warning.module,
                moduleSignal: warning.signal,
                actualOutcome: trade.pnlPercent,
                potentialOutcome: 0, // Girmeseydik 0 olurdu
                regretAmount: estimatedLoss,
                date: Date(),
                lesson: "⚠️ \(warning.module.capitalized) modülü %\(Int(warning.signal)) skoruyla uyarı vermişti. Bu uyarı dikkate alınsaydı %\(String(format: "%.1f", estimatedLoss)) kayıp önlenebilirdi."
            )
            
            regretRecords.append(record)
            
            print("😔 Chiron Regret: Önlenebilir kayıp - \(trade.symbol) (\(warning.module) uyardı, skorı \(Int(warning.signal)))")
        }
        
        // Son 100 kayıt tut
        if regretRecords.count > 100 {
            regretRecords = Array(regretRecords.suffix(100))
        }
        
        saveRecords()
    }
    
    // MARK: - Raporlama
    
    /// Pişmanlık özeti oluşturur
    func generateSummary() async -> RegretSummary {
        let preventable = regretRecords.filter { $0.type == .preventableLoss }
        let missed = regretRecords.filter { $0.type == .missedOpportunity }
        
        // En çok görmezden gelinen modülü bul
        var moduleCounts: [String: Int] = [:]
        for record in regretRecords {
            moduleCounts[record.ignoredModule, default: 0] += 1
        }
        let mostIgnored = moduleCounts.max(by: { $0.value < $1.value })?.key
        
        // Öğrenilen dersler (son 5)
        let lessons = regretRecords.suffix(5).map { $0.lesson }
        
        return RegretSummary(
            totalPreventableLossCount: preventable.count,
            totalMissedOpportunityCount: missed.count,
            totalPreventableLossAmount: preventable.reduce(0) { $0 + $1.regretAmount },
            totalMissedGainAmount: missed.reduce(0) { $0 + $1.potentialOutcome },
            mostIgnoredModule: mostIgnored,
            lessons: lessons,
            generatedAt: Date()
        )
    }
    
    /// Tüm pişmanlık kayıtlarını döndürür
    func getAllRecords() async -> [RegretRecord] {
        return regretRecords
    }
    
    /// Belirli bir sembol için pişmanlık kayıtlarını döndürür
    func getRecords(for symbol: String) async -> [RegretRecord] {
        return regretRecords.filter { $0.symbol == symbol }
    }
    
    // MARK: - Öğrenme Entegrasyonu
    
    /// Pişmanlık yaşanan modülün ağırlığını artırmak için öneriler üretir
    func getWeightAdjustmentSuggestions() async -> [String: Double] {
        var suggestions: [String: Double] = [:]
        
        // Son 20 pişmanlık kaydındaki modülleri say
        let recentRecords = regretRecords.suffix(20)
        var moduleCounts: [String: Int] = [:]
        
        for record in recentRecords {
            moduleCounts[record.ignoredModule, default: 0] += 1
        }
        
        // En çok görmezden gelinen modüllere boost öner
        for (module, count) in moduleCounts {
            // Her 5 pişmanlık için +%2 ağırlık artışı öner
            let boost = min(0.10, Double(count) * 0.02) // Max +10% boost
            suggestions[module] = boost
        }
        
        return suggestions
    }
}
