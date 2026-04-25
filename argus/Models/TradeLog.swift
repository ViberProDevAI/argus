import Foundation

/// Pillar 8: Logging & Learning
/// Represents a closed trade or significant decision outcome.
struct TradeLog: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let date: Date
    let symbol: String
    
    // Outcome
    let entryPrice: Double
    let exitPrice: Double
    let pnlPercent: Double
    let pnlAbsolute: Double
    
    // Context at Entry
    let entryRegime: MarketRegime
    let entryOrionScore: Double
    let entryAtlasScore: Double
    let entryAetherScore: Double
    
    // Who made the decision?
    let engine: String // "AutoPilot", "Manual", "Scout"
    
    // NEW: Orion Bileşen Detayları (Chiron Öğrenme için)
    var entryOrionSnapshot: OrionComponentSnapshot?
    var exitOrionSnapshot: OrionComponentSnapshot?
    
    // MARK: - Computed Properties
    
    var isWin: Bool { pnlPercent > 0 }
    
    /// Bileşen bazlı performans analizi için yardımcı
    var componentPerformance: [String: Bool]? {
        guard let entry = entryOrionSnapshot else { return nil }
        
        // Hangi bileşenler yüksek skor verdi ve trade kazandı mı?
        var result: [String: Bool] = [:]
        for (component, score) in entry.componentDict {
            // Eğer bileşen skoru > 60 ise "sinyal verdi" sayılır
            if score > 60 {
                result[component] = isWin // Sinyal verdi ve kazandı mı?
            }
        }
        return result
    }
}

/// Store for TradeLogs
final class TradeLogStore: Sendable {
    static let shared = TradeLogStore()
    private let key = "ArgusTradeLogs"
    
    private init() {}
    
    func append(_ log: TradeLog) {
        var logs = fetchLogs()
        logs.append(log)
        // Keep last 100 for efficiency
        if logs.count > 100 { logs.removeFirst(logs.count - 100) }
        
        DiskCacheService.shared.save(logs, key: key)
    }
    
    func fetchLogs() -> [TradeLog] {
        return DiskCacheService.shared.load([TradeLog].self, key: key, maxAge: 365 * 24 * 3600) ?? []
    }
}
