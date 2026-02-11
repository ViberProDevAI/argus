import Foundation

// MARK: - Chiron Data Lake Service
/// Centralized storage for Chiron's learning data
actor ChironDataLakeService {
    static let shared = ChironDataLakeService()
    
    // MARK: - Data Paths
    private let basePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChironDataLake", isDirectory: true)
    }()
    
    init() {
        Task { await setupDirectories() }
    }
    
    private func setupDirectories() {
        let fm = FileManager.default
        let paths = [
            basePath,
            basePath.appendingPathComponent("trades"),
            basePath.appendingPathComponent("module_accuracy"),
            basePath.appendingPathComponent("regime"),
            basePath.appendingPathComponent("learning_logs")
        ]
        
        for path in paths {
            if !fm.fileExists(atPath: path.path) {
                try? fm.createDirectory(at: path, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Trade History
    
    /// Log a completed trade for learning
    func logTrade(_ record: TradeOutcomeRecord) async {
        let path = basePath.appendingPathComponent("trades/\(record.symbol)_history.json")
        var history = await loadTradeHistory(symbol: record.symbol)
        history.append(record)
        
        // Keep last 500 trades per symbol (artırıldı: daha fazla öğrenme verisi)
        if history.count > 500 {
            history = Array(history.suffix(500))
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: path)
            
            // RAG Sync - Push learning to vector database
            let holdingDays = Calendar.current.dateComponents([.day], from: record.entryDate, to: record.exitDate).day ?? 0
            await MainActor.run {
                Task {
                    await AlkindusRAGEngine.shared.syncChironTrade(
                        id: record.id.uuidString,
                        symbol: record.symbol,
                        engine: record.engine.rawValue,
                        entryPrice: record.entryPrice,
                        exitPrice: record.exitPrice,
                        pnlPercent: record.pnlPercent,
                        holdingDays: holdingDays,
                        orionScore: record.orionScoreAtEntry,
                        atlasScore: record.atlasScoreAtEntry,
                        regime: record.regime?.rawValue
                    )
                    
                    // Mark as synced after successful RAG push
                    await ChironDataLakeService.shared.markAsSynced(tradeId: record.id, symbol: record.symbol)
                }
            }
        } catch {
            print("❌ ChironDataLake: Failed to save trade - \(error)")
        }
    }
    
    /// Mark a trade as RAG synced
    func markAsSynced(tradeId: UUID, symbol: String) async {
        var history = await loadTradeHistory(symbol: symbol)
        
        if let index = history.firstIndex(where: { $0.id == tradeId }) {
            var updated = history[index]
            updated.ragSynced = true
            updated.ragSyncedAt = Date()
            history[index] = updated
            
            let path = basePath.appendingPathComponent("trades/\(symbol)_history.json")
            do {
                let data = try JSONEncoder().encode(history)
                try data.write(to: path)
                print("✅ Chiron: Trade \(tradeId) marked as RAG synced")
            } catch {
                print("❌ Chiron: Failed to mark trade as synced - \(error)")
            }
        }
    }
    
    /// Cleanup synced records older than specified days
    func cleanupSyncedRecords(olderThanDays: Int = 7) async -> Int {
        var deletedCount = 0
        let cutoff = Date().addingTimeInterval(-Double(olderThanDays) * 24 * 60 * 60)
        
        let fm = FileManager.default
        let tradesPath = basePath.appendingPathComponent("trades")
        
        guard let files = try? fm.contentsOfDirectory(atPath: tradesPath.path) else { return 0 }
        
        for file in files where file.hasSuffix("_history.json") {
            let symbol = file.replacingOccurrences(of: "_history.json", with: "")
            var history = await loadTradeHistory(symbol: symbol)
            let originalCount = history.count
            
            // Keep: not synced OR synced but newer than cutoff
            history = history.filter { record in
                !record.ragSynced || (record.ragSyncedAt ?? Date()) > cutoff
            }
            
            let removed = originalCount - history.count
            deletedCount += removed
            
            if removed > 0 {
                let path = basePath.appendingPathComponent("trades/\(symbol)_history.json")
                do {
                    let data = try JSONEncoder().encode(history)
                    try data.write(to: path)
                } catch {
                    print("❌ Chiron Cleanup: Failed for \(symbol) - \(error)")
                }
            }
        }
        
        if deletedCount > 0 {
            print("🧹 Chiron Cleanup: \(deletedCount) synced records deleted (>\(olderThanDays) days old)")
        }
        
        return deletedCount
    }
    
    func loadTradeHistory(symbol: String) async -> [TradeOutcomeRecord] {
        let path = basePath.appendingPathComponent("trades/\(symbol)_history.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([TradeOutcomeRecord].self, from: data)
        } catch {
            return []
        }
    }
    
    // MARK: - Module Accuracy Tracking
    
    /// Track module prediction accuracy
    func logModulePrediction(_ record: ModulePredictionRecord) async {
        let path = basePath.appendingPathComponent("module_accuracy/\(record.module)_accuracy.json")
        var history = await loadModuleAccuracy(module: record.module)
        history.append(record)
        
        // Keep last 200 predictions per module
        if history.count > 200 {
            history = Array(history.suffix(200))
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: path)
        } catch {
            print("❌ ChironDataLake: Failed to save module accuracy - \(error)")
        }
    }
    
    func loadModuleAccuracy(module: String) async -> [ModulePredictionRecord] {
        let path = basePath.appendingPathComponent("module_accuracy/\(module)_accuracy.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ModulePredictionRecord].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Calculate win rate for a module
    func getModuleWinRate(module: String) async -> Double {
        let history = await loadModuleAccuracy(module: module)
        guard !history.isEmpty else { return 0.5 }
        
        let wins = history.filter { $0.wasCorrect }.count
        return Double(wins) / Double(history.count)
    }
    
    // MARK: - Learning Logs
    
    /// Log a learning event (weight update, rule change, etc.)
    func logLearningEvent(_ event: ChironLearningEvent) async {
        let path = basePath.appendingPathComponent("learning_logs/events.json")
        var events = await loadLearningEvents()
        events.append(event)
        
        // Keep last 50 events
        if events.count > 50 {
            events = Array(events.suffix(50))
        }
        
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: path)
        } catch {
            print("❌ ChironDataLake: Failed to save learning event - \(error)")
        }
    }
    
    func loadLearningEvents() async -> [ChironLearningEvent] {
        let path = basePath.appendingPathComponent("learning_logs/events.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ChironLearningEvent].self, from: data)
        } catch {
            return []
        }
    }
    
    // MARK: - Summary Statistics
    
    /// Get summary stats for a symbol
    func getSymbolStats(symbol: String) async -> SymbolLearningStats {
        let trades = await loadTradeHistory(symbol: symbol)
        
        let wins = trades.filter { $0.pnlPercent > 0 }.count
        let winRate = trades.isEmpty ? 0 : Double(wins) / Double(trades.count) * 100
        let avgPnl = trades.isEmpty ? 0 : trades.map { $0.pnlPercent }.reduce(0, +) / Double(trades.count)
        
        let corse = trades.filter { $0.engine == .corse }
        let pulse = trades.filter { $0.engine == .pulse }
        
        let corseWinRate = corse.isEmpty ? 0 : Double(corse.filter { $0.pnlPercent > 0 }.count) / Double(corse.count) * 100
        let pulseWinRate = pulse.isEmpty ? 0 : Double(pulse.filter { $0.pnlPercent > 0 }.count) / Double(pulse.count) * 100
        
        return SymbolLearningStats(
            symbol: symbol,
            totalTrades: trades.count,
            winRate: winRate,
            avgPnlPercent: avgPnl,
            corseWinRate: corseWinRate,
            pulseWinRate: pulseWinRate,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Transaction Import (Chiron 3.0)
    
    /// Geçmiş transaction'ları TradeOutcomeRecord'a dönüştürür
    func importFromTransactions(_ transactions: [Transaction]) async -> Int {
        var importCount = 0
        
        // Sadece tamamlanmış (satış) işlemlerini import et
        let sellTransactions = transactions.filter { $0.type == .sell }
        
        for sellTx in sellTransactions {
            // Bu satışa karşılık gelen alış işlemini bul
            guard let buyTx = transactions.first(where: {
                $0.symbol == sellTx.symbol &&
                $0.type == .buy &&
                $0.date < sellTx.date
            }) else { continue }
            
            let pnlPercent = ((sellTx.price - buyTx.price) / buyTx.price) * 100
            
            let record = TradeOutcomeRecord(
                id: UUID(),
                symbol: sellTx.symbol,
                engine: .corse, // Varsayılan
                entryDate: buyTx.date,
                exitDate: sellTx.date,
                entryPrice: buyTx.price,
                exitPrice: sellTx.price,
                pnlPercent: pnlPercent,
                exitReason: "Imported",
                orionScoreAtEntry: nil,
                atlasScoreAtEntry: nil,
                aetherScoreAtEntry: nil,
                phoenixScoreAtEntry: nil,
                allModuleScores: nil,
                systemDecision: nil,
                ignoredWarnings: nil,
                regime: nil
            )
            
            await logTrade(record)
            importCount += 1
        }
        
        print("📥 Chiron: \(importCount) trade import edildi")
        return importCount
    }
    
    /// Tüm trade geçmişini döndürür
    func loadAllTradeHistory() async -> [TradeOutcomeRecord] {
        var allTrades: [TradeOutcomeRecord] = []
        
        let fm = FileManager.default
        let tradesPath = basePath.appendingPathComponent("trades")
        
        if let files = try? fm.contentsOfDirectory(atPath: tradesPath.path) {
            for file in files where file.hasSuffix("_history.json") {
                let symbol = file.replacingOccurrences(of: "_history.json", with: "")
                let trades = await loadTradeHistory(symbol: symbol)
                allTrades.append(contentsOf: trades)
            }
        }
        
        return allTrades.sorted { $0.exitDate > $1.exitDate }
    }
}

// MARK: - Data Models

struct TradeOutcomeRecord: Codable, Sendable {
    let id: UUID
    let symbol: String
    let engine: AutoPilotEngine
    let entryDate: Date
    let exitDate: Date
    let entryPrice: Double
    let exitPrice: Double
    let pnlPercent: Double
    let exitReason: String
    
    // Scores at entry time (for learning)
    let orionScoreAtEntry: Double?
    let atlasScoreAtEntry: Double?
    let aetherScoreAtEntry: Double?
    let phoenixScoreAtEntry: Double?
    
    // Chiron 3.0 - Genişletilmiş Alanlar
    let allModuleScores: [String: Double]?  // Tüm modüllerin giriş skorları
    let systemDecision: String?              // AL/SAT/BEKLE
    let ignoredWarnings: [String]?           // Hangi modüller uyarı verdi ama dinlenmedi
    let regime: MarketRegime?                // Giriş anındaki rejim
    
    // RAG Sync Tracking
    var ragSynced: Bool
    var ragSyncedAt: Date?
    
    // Default initializer with ragSynced = false
    init(
        id: UUID = UUID(),
        symbol: String,
        engine: AutoPilotEngine,
        entryDate: Date,
        exitDate: Date,
        entryPrice: Double,
        exitPrice: Double,
        pnlPercent: Double,
        exitReason: String,
        orionScoreAtEntry: Double? = nil,
        atlasScoreAtEntry: Double? = nil,
        aetherScoreAtEntry: Double? = nil,
        phoenixScoreAtEntry: Double? = nil,
        allModuleScores: [String: Double]? = nil,
        systemDecision: String? = nil,
        ignoredWarnings: [String]? = nil,
        regime: MarketRegime? = nil,
        ragSynced: Bool = false,
        ragSyncedAt: Date? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.engine = engine
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.pnlPercent = pnlPercent
        self.exitReason = exitReason
        self.orionScoreAtEntry = orionScoreAtEntry
        self.atlasScoreAtEntry = atlasScoreAtEntry
        self.aetherScoreAtEntry = aetherScoreAtEntry
        self.phoenixScoreAtEntry = phoenixScoreAtEntry
        self.allModuleScores = allModuleScores
        self.systemDecision = systemDecision
        self.ignoredWarnings = ignoredWarnings
        self.regime = regime
        self.ragSynced = ragSynced
        self.ragSyncedAt = ragSyncedAt
    }
}

struct ModulePredictionRecord: Codable, Sendable {
    let id: UUID
    let module: String  // "orion", "atlas", "phoenix", etc.
    let symbol: String
    let date: Date
    let signal: String  // "BUY", "SELL", "HOLD"
    let scoreAtTime: Double
    let wasCorrect: Bool
    let actualPnl: Double?
}

struct ChironLearningEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let eventType: ChironEventType
    let symbol: String?
    let engine: AutoPilotEngine?
    let description: String
    let reasoning: String
    let confidence: Double
    
    init(id: UUID = UUID(), date: Date = Date(), eventType: ChironEventType, symbol: String? = nil, engine: AutoPilotEngine? = nil, description: String, reasoning: String, confidence: Double) {
        self.id = id
        self.date = date
        self.eventType = eventType
        self.symbol = symbol
        self.engine = engine
        self.description = description
        self.reasoning = reasoning
        self.confidence = confidence
    }
}

enum ChironEventType: String, Codable, Sendable {
    case weightUpdate = "WEIGHT_UPDATE"
    case ruleAdded = "RULE_ADDED"
    case ruleRemoved = "RULE_REMOVED"
    case analysisCompleted = "ANALYSIS_COMPLETED"
    case anomalyDetected = "ANOMALY_DETECTED"
    case forwardTest = "FORWARD_TEST"  // Forward test doğrulama sonucu
}

struct SymbolLearningStats: Codable, Sendable {
    let symbol: String
    let totalTrades: Int
    let winRate: Double
    let avgPnlPercent: Double
    let corseWinRate: Double
    let pulseWinRate: Double
    let lastUpdated: Date
}
