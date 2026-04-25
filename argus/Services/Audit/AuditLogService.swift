import Foundation

// MARK: - Audit Log Service
/// Karar ve işlem geçmişini persistent olarak kaydeden servis

actor AuditLogService {
    static let shared = AuditLogService()
    
    private var decisionLogs: [DecisionAuditLog] = []
    private var tradeLogs: [TradeAuditLog] = []
    
    private let fileManager = FileManager.default
    private nonisolated var auditDirectory: URL {
        FileManager.default.documentsURL.appendingPathComponent("AuditLogs", isDirectory: true)
    }
    
    private init() {
        // Create directory synchronously (nonisolated)
        try? FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        Task { await loadFromDisk() }
    }
    
    // MARK: - Decision Logging
    
    /// Karar logu ekle
    func logDecision(_ log: DecisionAuditLog) {
        decisionLogs.append(log)
        saveDecisionsToDisk()
        
        print("📋 Audit: Decision logged for \(log.symbol) - \(log.finalAction.rawValue)")
    }
    
    /// Yeni karar logu oluştur ve kaydet
    func recordDecision(
        symbol: String,
        candidateSource: String,
        moduleScores: [String: Double],
        moduleOpinions: [String: String],
        chironWeights: [String: Double]?,
        debateSummary: String,
        riskApproved: Bool,
        riskReason: String?,
        finalAction: SignalAction,
        finalScore: Double,
        executionPlan: String?
    ) {
        let log = DecisionAuditLog(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            candidateSource: candidateSource,
            moduleScores: moduleScores,
            moduleOpinions: moduleOpinions,
            chironWeights: chironWeights,
            debateSummary: debateSummary,
            riskApproved: riskApproved,
            riskReason: riskReason,
            finalAction: finalAction,
            finalScore: finalScore,
            executionPlan: executionPlan
        )
        
        decisionLogs.append(log)
        saveDecisionsToDisk()
    }
    
    // MARK: - Trade Logging
    
    /// Trade logu ekle
    func logTrade(_ log: TradeAuditLog) {
        tradeLogs.append(log)
        saveTradesToDisk()
        
        print("📋 Audit: Trade logged - \(log.action.rawValue) \(log.symbol) @ \(log.executedPrice)")
    }
    
    /// Yeni trade logu oluştur ve kaydet
    func recordTrade(
        symbol: String,
        action: TradeAction,
        requestedQuantity: Double,
        executedQuantity: Double,
        requestedPrice: Double,
        executedPrice: Double,
        slippage: Double,
        commission: Double,
        decisionId: UUID?,
        triggerReason: String,
        moduleScoresAtEntry: [String: Double]?
    ) {
        let log = TradeAuditLog(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            action: action,
            requestedQuantity: requestedQuantity,
            executedQuantity: executedQuantity,
            requestedPrice: requestedPrice,
            executedPrice: executedPrice,
            slippage: slippage,
            commission: commission,
            totalCost: slippage + commission,
            decisionId: decisionId,
            triggerReason: triggerReason,
            moduleScoresAtEntry: moduleScoresAtEntry
        )
        
        tradeLogs.append(log)
        saveTradesToDisk()
    }
    
    // MARK: - Query
    
    /// Belirli sembol için kararları getir
    func getDecisions(for symbol: String, limit: Int = 50) -> [DecisionAuditLog] {
        return decisionLogs
            .filter { $0.symbol == symbol }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Tüm kararları getir
    func getAllDecisions(limit: Int = 100) -> [DecisionAuditLog] {
        return decisionLogs
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Belirli sembol için trade'leri getir
    func getTrades(for symbol: String, limit: Int = 50) -> [TradeAuditLog] {
        return tradeLogs
            .filter { $0.symbol == symbol }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Tüm trade'leri getir
    func getAllTrades(limit: Int = 100) -> [TradeAuditLog] {
        return tradeLogs
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Tarih aralığına göre filtrele
    func getDecisions(from startDate: Date, to endDate: Date) -> [DecisionAuditLog] {
        return decisionLogs.filter {
            $0.timestamp >= startDate && $0.timestamp <= endDate
        }
    }
    
    /// Belirli bir decision için trade'leri bul
    func getTrades(forDecisionId decisionId: UUID) -> [TradeAuditLog] {
        return tradeLogs.filter { $0.decisionId == decisionId }
    }
    
    // MARK: - Analytics
    
    /// Decision-to-execution performansı
    func analyzeExecutionQuality() -> ExecutionQualityReport {
        var totalSlippage = 0.0
        var totalCommission = 0.0
        var tradeCount = 0
        var fillRates: [Double] = []
        
        for trade in tradeLogs {
            totalSlippage += trade.slippage
            totalCommission += trade.commission
            tradeCount += 1
            
            if trade.requestedQuantity > 0 {
                fillRates.append(trade.executedQuantity / trade.requestedQuantity)
            }
        }
        
        let avgFillRate = fillRates.isEmpty ? 1.0 : fillRates.reduce(0, +) / Double(fillRates.count)
        
        return ExecutionQualityReport(
            totalTrades: tradeCount,
            totalSlippage: totalSlippage,
            totalCommission: totalCommission,
            avgSlippagePerTrade: tradeCount > 0 ? totalSlippage / Double(tradeCount) : 0,
            avgFillRate: avgFillRate,
            generatedAt: Date()
        )
    }
    
    /// Modül başarı analizi (hangi modül hangi trade'i tetikledi)
    func analyzeModuleSuccess() -> [String: ModuleSuccessStats] {
        // Basit implementasyon - trade'lerin PnL'ine göre modül skorlarını değerlendir
        // Gerçek implementasyon trade kapanışlarını takip etmeli
        return [:]
    }
    
    // MARK: - Export
    
    /// JSON export
    func exportToJSON() -> URL? {
        let export = AuditExport(
            exportDate: Date(),
            decisions: decisionLogs,
            trades: tradeLogs
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(export)
            let fileName = "audit_export_\(ISO8601DateFormatter().string(from: Date())).json"
            let url = auditDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url)
            return url
        } catch {
            print("❌ Audit export failed: \(error)")
            return nil
        }
    }
    
    /// Eski logları temizle (30 günden eski)
    func pruneOldLogs(olderThan days: Int = 30) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        decisionLogs.removeAll { $0.timestamp < cutoff }
        tradeLogs.removeAll { $0.timestamp < cutoff }
        
        saveDecisionsToDisk()
        saveTradesToDisk()
    }
    
    // MARK: - Persistence
    
    private func createDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
    }
    
    private func saveDecisionsToDisk() {
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(decisionLogs)
                let url = auditDirectory.appendingPathComponent("decisions.json")
                try data.write(to: url)
            } catch {
                print("❌ Failed to save decision logs: \(error)")
            }
        }
    }
    
    private func saveTradesToDisk() {
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(tradeLogs)
                let url = auditDirectory.appendingPathComponent("trades.json")
                try data.write(to: url)
            } catch {
                print("❌ Failed to save trade logs: \(error)")
            }
        }
    }
    
    private func loadFromDisk() {
        // Load decisions
        let decisionsURL = auditDirectory.appendingPathComponent("decisions.json")
        if let data = try? Data(contentsOf: decisionsURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let logs = try? decoder.decode([DecisionAuditLog].self, from: data) {
                decisionLogs = logs
                print("📋 Audit: Loaded \(logs.count) decision logs")
            }
        }
        
        // Load trades
        let tradesURL = auditDirectory.appendingPathComponent("trades.json")
        if let data = try? Data(contentsOf: tradesURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let logs = try? decoder.decode([TradeAuditLog].self, from: data) {
                tradeLogs = logs
                print("📋 Audit: Loaded \(logs.count) trade logs")
            }
        }
    }
}

// MARK: - Audit Models

struct DecisionAuditLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let symbol: String
    
    // Source
    let candidateSource: String // "WATCHLIST", "SCOUT", "HERMES", "MANUAL"
    
    // Module Data
    let moduleScores: [String: Double]     // "Orion": 75, "Atlas": 62, etc.
    let moduleOpinions: [String: String]   // "Orion": "BUY", "Atlas": "HOLD"
    let chironWeights: [String: Double]?   // "Orion": 0.25, etc.
    
    // Debate
    let debateSummary: String
    
    // Risk Gate
    let riskApproved: Bool
    let riskReason: String?
    
    // Final Decision
    let finalAction: SignalAction
    let finalScore: Double
    let executionPlan: String?
}

struct TradeAuditLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let symbol: String
    
    // Trade Details
    let action: TradeAction
    let requestedQuantity: Double
    let executedQuantity: Double
    let requestedPrice: Double
    let executedPrice: Double
    
    // Costs
    let slippage: Double
    let commission: Double
    let totalCost: Double
    
    // Link to Decision
    let decisionId: UUID?
    let triggerReason: String
    
    // Context
    let moduleScoresAtEntry: [String: Double]?
}

struct ExecutionQualityReport: Codable {
    let totalTrades: Int
    let totalSlippage: Double
    let totalCommission: Double
    let avgSlippagePerTrade: Double
    let avgFillRate: Double
    let generatedAt: Date
}

struct ModuleSuccessStats: Codable {
    let moduleName: String
    let tradesTriggered: Int
    let winRate: Double
    let avgPnL: Double
}

struct AuditExport: Codable {
    let exportDate: Date
    let decisions: [DecisionAuditLog]
    let trades: [TradeAuditLog]
}

// TradeAction extension moved to BacktestModels.swift
