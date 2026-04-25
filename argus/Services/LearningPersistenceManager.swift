import Foundation
import SwiftData

/// Manages SwiftData persistence for the Learning Module (Shadow & Logs)
/// Pillar 8/9 Infrastructure
@MainActor
final class LearningPersistenceManager {
    static let shared = LearningPersistenceManager()
    
    // Injected by App
    var modelContext: ModelContext?
    
    private init() {}
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Actions
    
    func logShadowEntry(symbol: String, price: Double, atlas: Double, orion: Double, aether: Double, vix: Double) {
        guard let context = modelContext else { return }
        let session = ShadowTradeSession(symbol: symbol, price: price, atlas: atlas, orion: orion, aether: aether, vix: vix)
        context.insert(session)
        save()
    }
    
    func logMissedOpportunity(symbol: String, score: Double, reason: String) {
        guard let context = modelContext else { return }
        let log = MissedOpportunityLog(symbol: symbol, score: score, reason: reason)
        context.insert(log)
        save()
    }
    
    private func save() {
        do {
            try modelContext?.save()
        } catch {
            print("❌ LearningPersistenceManager: Save Failed - \(error)")
        }
    }
    
    // MARK: - Analysis & Export
    
    func fetchStats() -> (winRate: Double, avgPnL: Double) {
        // Placeholder for future query logic
        // Need to fetch logs with exitPrice != nil
        return (0.0, 0.0)
    }
    
    func exportToCSV() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<ShadowTradeSession>(sortBy: [SortDescriptor(\.entryDate, order: .reverse)])
            let sessions = try context.fetch(descriptor)
            
            var csv = "Tarih,Sembol,Durum,GirisFiyati,Atlas,Orion,Aether,VIX\n"
            
            let dateFormatter = ISO8601DateFormatter()
            
            for session in sessions {
                let line = "\(dateFormatter.string(from: session.entryDate)),\(session.symbol),\(session.status),\(session.entryPrice),\(session.recordedAtlasScore),\(session.recordedOrionScore),\(session.recordedAetherScore),\(session.recordedVix)\n"
                csv.append(line)
            }
            
            let filename = "Argus_Ogrenme_Verisi.csv"
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            
            try csv.write(to: path, atomically: true, encoding: .utf8)
            print("✅ Learning Data Exported to: \(path.path)")
            
        } catch {
            print("❌ Export Failed: \(error)")
        }
    }
}
