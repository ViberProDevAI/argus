import Foundation
import Combine

/// Central logging service for Auto-Pilot decisions.
/// Persists logs to disk for "Flight Recorder" functionality.
@MainActor
final class AutoPilotLogger: ObservableObject {
    static let shared = AutoPilotLogger()
    
    @Published private(set) var decisions: [AutoPilotDecision] = []
    
    private let fileManager = FileManager.default
    private let fileName = "argus_autopilot_log.json"
    
    private var logFileURL: URL {
        // Use Application Support directory
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ArgusTerminal", isDirectory: true)
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir.appendingPathComponent(fileName)
    }
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Logging API
    
    func log(_ decision: AutoPilotDecision) {
        decisions.append(decision)
        // Debounce optimization could be added here, but saving immediately for safety
        saveToDisk()
    }
    
    func allDecisions() -> [AutoPilotDecision] {
        return decisions
    }
    
    func clearAll() {
        decisions.removeAll()
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: logFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: logFileURL)
            let loaded = try JSONDecoder().decode([AutoPilotDecision].self, from: data)
            self.decisions = loaded
            print("📼 Flight Recorder: Loaded \(loaded.count) decisions.")
        } catch {
            print("❌ Flight Recorder Load Failed: \(error)")
        }
    }
    
    private func saveToDisk() {
        let snapshot = self.decisions
        let url = self.logFileURL
        
        Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url)
            } catch {
                print("❌ Flight Recorder Save Failed: \(error)")
            }
        }
    }
    
    // MARK: - Export
    
    /// Exports decisions as a JSON file and returns the temporary URL.
    func exportAsJSONTempFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(decisions)
        
        let tempDir = fileManager.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("argus_autopilot_log_\(Date().timeIntervalSince1970).json")
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    /// Exports decisions as a CSV file and returns the temporary URL.
    /// Exports decisions as a CSV file and returns the temporary URL.
    func exportAsCSVTempFile() throws -> URL {
        var csvString = "timestamp,mode,strategy,symbol,provider,action,quantity,price,positionValueUSD,takeProfit,stopLoss,riskMultiple,atlasScore,orionScore,aetherScore,hermesScore,argusFinalScore,dataQualityScore,fundamentalsPartial,technicalPartial,macroPartial,cryptoFallbackUsed,dataSourceNotes,portfolioValueBefore,portfolioValueAfter,rationale\n"
        
        let isoFormatter = ISO8601DateFormatter()
        
        for d in decisions {
            // Break down row creation to avoid compiler timeout
            let timeStr = isoFormatter.string(from: d.timestamp)
            let provStr = d.provider ?? "Unknown"
            let qtyStr = "\(d.quantity)"
            let priceStr = d.price.map { String($0) } ?? ""
            let valStr = d.positionValueUSD.map { String($0) } ?? ""
            let tpStr = d.takeProfit.map { String($0) } ?? ""
            let slStr = d.stopLoss.map { String($0) } ?? ""
            let rmStr = d.riskMultiple.map { String($0) } ?? ""
            
            let scores = [
                d.atlasScore.map { String($0) },
                d.orionScore.map { String($0) },
                d.aetherScore.map { String($0) },
                d.hermesScore.map { String($0) },
                d.argusFinalScore.map { String($0) },
                d.dataQualityScore.map { String($0) }
            ].map { $0 ?? "" }
            
            let flags = [
                "\(d.fundamentalsPartial)",
                "\(d.technicalPartial)",
                "\(d.macroPartial)",
                "\(d.cryptoFallbackUsed)"
            ]
            
            let notes = "\"\(d.dataSourceNotes ?? "")\""
            let portBefore = d.portfolioValueBefore.map { String($0) } ?? ""
            let portAfter = d.portfolioValueAfter.map { String($0) } ?? ""
            let rationale = "\"\(d.rationale ?? "")\""
            
            let rowParts = [
                timeStr, d.mode, d.strategy, d.symbol, provStr, d.action, qtyStr, priceStr, valStr, tpStr, slStr, rmStr,
                scores[0], scores[1], scores[2], scores[3], scores[4], scores[5],
                flags[0], flags[1], flags[2], flags[3],
                notes, portBefore, portAfter, rationale
            ]
            
            csvString.append(rowParts.joined(separator: ",") + "\n")
        }
        
        let tempDir = fileManager.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("argus_autopilot_log_\(Date().timeIntervalSince1970).csv")
        
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
