import Foundation

// MARK: - Chiron Council Learning Service
/// Learns from council voting records to adjust member weights
actor ChironCouncilLearningService {
    static let shared = ChironCouncilLearningService()
    
    // Voting records waiting for outcome
    private var pendingRecords: [UUID: CouncilVotingRecord] = [:]
    
    // Completed records for analysis
    private var completedRecords: [CouncilVotingRecord] = []
    
    // Persistence
    private let recordsPath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("ChironCouncilRecords.json")
    }()

    private let councilWeightsPath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("ChironCouncilWeights.json")
    }()
    
    // symbol -> engine -> weights
    private var councilWeightsMatrix: [String: [AutoPilotEngine: CouncilMemberWeights]] = [:]
    
    init() {
        Task {
            await loadFromDisk()
        }
    }
    
    // MARK: - Public API
    
    /// Record a council decision (called when trade opens)
    func recordDecision(_ record: CouncilVotingRecord) {
        pendingRecords[record.id] = record
        print("🧠 Chiron: Konsey kararı kaydedildi - \(record.symbol) (\(record.id.uuidString.prefix(8)))")
    }
    
    /// Update a record with trade outcome (called when trade closes)
    func updateOutcome(recordId: UUID, outcome: TradeOutcome, pnlPercent: Double) async {
        guard var record = pendingRecords.removeValue(forKey: recordId) else {
            print("⚠️ Chiron: Kayıt bulunamadı - \(recordId.uuidString.prefix(8))")
            return
        }
        
        record.outcome = outcome
        record.pnlPercent = pnlPercent
        completedRecords.append(record)
        
        print("🧠 Chiron: Trade sonucu güncellendi - \(record.symbol) | \(outcome.rawValue) | %\(String(format: "%.1f", pnlPercent))")
        
        // Learn from this outcome
        await learnFromRecord(record)
        
        // Save
        await saveToDisk()
    }
    
    /// Find a pending record for a symbol
    func findPendingRecord(symbol: String, engine: AutoPilotEngine) -> CouncilVotingRecord? {
        return pendingRecords.values.first { $0.symbol == symbol && $0.engine == engine }
    }
    
    /// Simplified: Update outcome by symbol (finds latest pending record)
    func updateOutcome(symbol: String, outcome: ChironTradeOutcome, pnlPercent: Double) async {
        // Find most recent pending record for this symbol
        guard let record = pendingRecords.values.first(where: { $0.symbol == symbol }) else {
            // No pending record - just log and learn from outcome anyway
            print("🧠 Chiron: \(symbol) için kayıt yok, genel öğrenme uygulanıyor")
            await learnFromSimpleOutcome(symbol: symbol, outcome: outcome, pnlPercent: pnlPercent)
            return
        }
        
        // Use existing record-based learning
        await updateOutcome(recordId: record.id, outcome: outcome.toTradeOutcome, pnlPercent: pnlPercent)
    }
    
    /// Simple learning for trades without council records
    private func learnFromSimpleOutcome(symbol: String, outcome: ChironTradeOutcome, pnlPercent: Double) async {
        // Just log - detailed learning requires council records
        let pnlStr = String(format: "%.2f", pnlPercent)
        print("   → \(outcome.rawValue) | PnL: \(pnlStr)%")
        await saveToDisk()
    }
    
    /// Get council weights for a symbol+engine (nonisolated for performance)
    nonisolated func getCouncilWeights(symbol: String, engine: AutoPilotEngine) -> CouncilMemberWeights {
        // Return defaults directly (actor state access is nonisolated-requires cache copy)
        // For now, return defaults to prevent blocking
        switch engine {
        case .corse:
            return .defaultCorse
        case .pulse:
            return .defaultPulse
        default:
            return .defaultPulse
        }
    }
    
    /// Get learning stats for UI
    func getLearningStats() -> (totalTrades: Int, winRate: Double, pendingCount: Int) {
        let wins = completedRecords.filter { $0.outcome == .win }.count
        let total = completedRecords.count
        let winRate = total > 0 ? Double(wins) / Double(total) * 100 : 0
        return (total, winRate, pendingRecords.count)
    }
    
    /// Get member performance stats
    func getMemberPerformance() -> [String: MemberPerformance] {
        var performance: [String: MemberPerformance] = [:]
        
        // Initialize all members
        let memberIds = ["trend_master", "momentum_master", "structure_master", "pattern_master", "price_master"]
        for id in memberIds {
            performance[id] = MemberPerformance(correctProposals: 0, incorrectProposals: 0, correctVetos: 0, incorrectVetos: 0)
        }
        
        // Analyze completed records
        for record in completedRecords {
            guard let outcome = record.outcome else { continue }
            let isWin = outcome == .win
            
            // Proposer
            if var perf = performance[record.proposerId] {
                if isWin {
                    perf.correctProposals += 1
                } else {
                    perf.incorrectProposals += 1
                }
                performance[record.proposerId] = perf
            }
            
            // Approvers
            for approver in record.approvers {
                if var perf = performance[approver] {
                    if isWin {
                        perf.correctProposals += 1 // Supported winning trade
                    } else {
                        perf.incorrectProposals += 1 // Supported losing trade
                    }
                    performance[approver] = perf
                }
            }
            
            // Vetoers
            for vetoer in record.vetoers {
                if var perf = performance[vetoer] {
                    if isWin {
                        perf.incorrectVetos += 1 // Vetoed winning trade
                    } else {
                        perf.correctVetos += 1 // Correctly vetoed losing trade
                    }
                    performance[vetoer] = perf
                }
            }
        }
        
        return performance
    }
    
    // MARK: - Learning Logic
    
    private func learnFromRecord(_ record: CouncilVotingRecord) async {
        guard record.outcome != nil else { return }

        let pnl = record.pnlPercent ?? 0
        let symbol = record.symbol
        let engine = record.engine

        // Get current weights
        var weights = getCouncilWeights(symbol: symbol, engine: engine)

        // SÜREKLİ ÖDÜL FONKSİYONU (Binary yerine PnL bazlı)
        // PnL'e göre ödül/ceza hesapla (-1.0 ile +1.0 arasında normalize)
        let reward: Double
        switch pnl {
        case ..<(-10): reward = -1.0      // Büyük kayıp → Tam ceza
        case -10..<(-5): reward = -0.7    // Orta kayıp
        case -5..<0: reward = -0.3        // Küçük kayıp
        case 0..<3: reward = 0.2          // Başabaş / Küçük kazanç
        case 3..<7: reward = 0.5          // İyi kazanç
        case 7..<15: reward = 0.8         // Güçlü kazanç
        default: reward = 1.0             // Mükemmel kazanç (>%15)
        }

        // Adaptif öğrenme oranı (lineer decay - sqrt'dan daha kontrollü)
        let tradeCount = Double(completedRecords.count + 1)
        // Trade 1: 0.099, Trade 50: 0.05, Trade 80+: 0.02 (sabit)
        let baseLearningRate = max(0.02, 0.1 - (0.001 * tradeCount))

        // Learning rates (ödüle göre ölçeklenmiş)
        let proposerDelta = reward * baseLearningRate * 1.0    // Öneri getiren
        let approverDelta = reward * baseLearningRate * 0.5    // Onaylayan
        let vetoerDelta = -reward * baseLearningRate * 0.7     // Veto eden (ters yönde öğrenir)

        // Update proposer weight
        weights = updateMemberWeight(weights, memberId: record.proposerId, delta: proposerDelta)

        // Update approvers
        for approver in record.approvers {
            weights = updateMemberWeight(weights, memberId: approver, delta: approverDelta)
        }

        // Update vetoers (veto eden için ödül/ceza ters)
        for vetoer in record.vetoers {
            weights = updateMemberWeight(weights, memberId: vetoer, delta: vetoerDelta)
        }
        
        // Normalize and save
        weights = weights.normalized()
        weights = CouncilMemberWeights(
            trendMaster: weights.trendMaster,
            momentumMaster: weights.momentumMaster,
            structureMaster: weights.structureMaster,
            patternMaster: weights.patternMaster,
            priceMaster: weights.priceMaster,
            updatedAt: Date(),
            confidence: min(1.0, weights.confidence + 0.05) // Increase confidence with each learning
        )
        
        // Store
        if councilWeightsMatrix[symbol] == nil {
            councilWeightsMatrix[symbol] = [:]
        }
        councilWeightsMatrix[symbol]?[engine] = weights
        
        print("🧠 Chiron Öğrendi: \(symbol) | PnL: %\(String(format: "%.1f", pnl)) | Reward: \(String(format: "%.2f", reward))")
        print("   Trend: \(String(format: "%.0f", weights.trendMaster * 100))%, Momentum: \(String(format: "%.0f", weights.momentumMaster * 100))%, Structure: \(String(format: "%.0f", weights.structureMaster * 100))%, Pattern: \(String(format: "%.0f", weights.patternMaster * 100))%, Price: \(String(format: "%.0f", weights.priceMaster * 100))%")
    }
    
    private func updateMemberWeight(_ weights: CouncilMemberWeights, memberId: String, delta: Double) -> CouncilMemberWeights {
        var w = weights
        switch memberId {
        case "trend_master":
            w = CouncilMemberWeights(trendMaster: max(0.05, min(0.50, w.trendMaster + delta)), momentumMaster: w.momentumMaster, structureMaster: w.structureMaster, patternMaster: w.patternMaster, priceMaster: w.priceMaster, updatedAt: w.updatedAt, confidence: w.confidence)
        case "momentum_master":
            w = CouncilMemberWeights(trendMaster: w.trendMaster, momentumMaster: max(0.05, min(0.50, w.momentumMaster + delta)), structureMaster: w.structureMaster, patternMaster: w.patternMaster, priceMaster: w.priceMaster, updatedAt: w.updatedAt, confidence: w.confidence)
        case "structure_master":
            w = CouncilMemberWeights(trendMaster: w.trendMaster, momentumMaster: w.momentumMaster, structureMaster: max(0.05, min(0.50, w.structureMaster + delta)), patternMaster: w.patternMaster, priceMaster: w.priceMaster, updatedAt: w.updatedAt, confidence: w.confidence)
        case "pattern_master":
            w = CouncilMemberWeights(trendMaster: w.trendMaster, momentumMaster: w.momentumMaster, structureMaster: w.structureMaster, patternMaster: max(0.05, min(0.50, w.patternMaster + delta)), priceMaster: w.priceMaster, updatedAt: w.updatedAt, confidence: w.confidence)
        case "price_master":
            w = CouncilMemberWeights(trendMaster: w.trendMaster, momentumMaster: w.momentumMaster, structureMaster: w.structureMaster, patternMaster: w.patternMaster, priceMaster: max(0.05, min(0.50, w.priceMaster + delta)), updatedAt: w.updatedAt, confidence: w.confidence)
        default:
            break
        }
        return w
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            // Save completed records
            let recordsData = try JSONEncoder().encode(completedRecords)
            try recordsData.write(to: recordsPath)
            
            // Save weights matrix
            var serializable: [String: [String: CouncilMemberWeights]] = [:]
            for (symbol, engines) in councilWeightsMatrix {
                var engineDict: [String: CouncilMemberWeights] = [:]
                for (engine, weights) in engines {
                    engineDict[engine.rawValue] = weights
                }
                serializable[symbol] = engineDict
            }
            let weightsData = try JSONEncoder().encode(serializable)
            try weightsData.write(to: councilWeightsPath)
            
            print("💾 ChironCouncilLearning: Saved \(completedRecords.count) records")
        } catch {
            print("❌ ChironCouncilLearning: Save failed - \(error)")
        }
    }
    
    private func loadFromDisk() {
        // Load records
        if FileManager.default.fileExists(atPath: recordsPath.path) {
            do {
                let data = try Data(contentsOf: recordsPath)
                completedRecords = try JSONDecoder().decode([CouncilVotingRecord].self, from: data)
                print("📂 ChironCouncilLearning: Loaded \(completedRecords.count) records")
            } catch {
                print("❌ ChironCouncilLearning: Records load failed - \(error)")
            }
        }
        
        // Load weights
        if FileManager.default.fileExists(atPath: councilWeightsPath.path) {
            do {
                let data = try Data(contentsOf: councilWeightsPath)
                let serializable = try JSONDecoder().decode([String: [String: CouncilMemberWeights]].self, from: data)
                
                for (symbol, engines) in serializable {
                    councilWeightsMatrix[symbol] = [:]
                    for (engineRaw, weights) in engines {
                        if let engine = AutoPilotEngine(rawValue: engineRaw) {
                            councilWeightsMatrix[symbol]?[engine] = weights
                        }
                    }
                }
                print("📂 ChironCouncilLearning: Loaded weights for \(councilWeightsMatrix.count) symbols")
            } catch {
                print("❌ ChironCouncilLearning: Weights load failed - \(error)")
            }
        }
    }
}

// MARK: - Member Performance
struct MemberPerformance: Sendable {
    var correctProposals: Int
    var incorrectProposals: Int
    var correctVetos: Int
    var incorrectVetos: Int
    
    var proposalAccuracy: Double {
        let total = correctProposals + incorrectProposals
        return total > 0 ? Double(correctProposals) / Double(total) * 100 : 0
    }
    
    var vetoAccuracy: Double {
        let total = correctVetos + incorrectVetos
        return total > 0 ? Double(correctVetos) / Double(total) * 100 : 0
    }
    
    var overallScore: Double {
        let proposalScore = proposalAccuracy * 0.7
        let vetoScore = vetoAccuracy * 0.3
        return proposalScore + vetoScore
    }
}

// MARK: - Chiron Trade Outcome (Simple)
enum ChironTradeOutcome: String, Sendable {
    case win = "KAZANÇ"
    case loss = "KAYIP"
    
    var toTradeOutcome: TradeOutcome {
        switch self {
        case .win: return .win
        case .loss: return .loss
        }
    }
}
