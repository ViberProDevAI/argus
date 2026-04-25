import Foundation
import Combine

/// "The Teaching Engine"
/// Captures every decision (Proposal, Execution, Rejection) and logs it for user education.
/// Persists data to JSONL for long-term "Flight Recorder" history.
actor ArgusInboxService: ObservableObject {
    static let shared = ArgusInboxService()
    
    // Memory Cache (Last N events for UI)
    @MainActor @Published var events: [InboxEvent] = []
    @MainActor @Published var postMortems: [PostMortemLog] = []
    
    private let maxMemEvents = 100
    private static let persistenceFileName = "argus_inbox_feed.jsonl"
    private static let postMortemFileName = "argus_post_mortems.jsonl"
    
    private init() {
        Task {
            await loadHistory()
        }
    }
    
    // MARK: - Ingestion
    
    func log(event: InboxEvent) {
        // 1. Memory Update & Persistence
        Task { @MainActor in
            events.insert(event, at: 0)
            if events.count > maxMemEvents { events.removeLast() }
            
            // 2. Disk Persistence (Fire & Forget, now on MainActor)
            saveToDisk(event: event)
        }
    }
    
    func logPostMortem(log: PostMortemLog) {
        Task { @MainActor in
            postMortems.insert(log, at: 0)
            saveToDisk(event: log)
        }
    }
    
    // MARK: - Factory Methods
    
    func createProposalEvent(
        symbol: String,
        proposal: ArgusProposal,
        price: Double
    ) -> InboxEvent {
        return InboxEvent(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            type: .proposed,
            engine: proposal.engine.rawValue,
            reasonTitle: "İşlem Önerisi Oluşturuldu",
            reasonBullets: [
                proposal.rationale,
                "Güven Skoru: \(Int(proposal.confidence))%",
                "Risk Seviyesi: \(proposal.riskLevel ?? 0)/10"
            ],
            scores: proposal.scores,
            dataHealth: proposal.dataHealth,
            chironRegime: proposal.chironRegime,
            activeWeights: [:], // TODO: Pass accurate weights from Chiron
            executionPrice: price,
            stopLoss: nil,
            takeProfit: nil,
            rejectionReason: nil
        )
    }
    
    func createRejectionEvent(
        symbol: String,
        proposal: ArgusProposal,
        reason: String
    ) -> InboxEvent {
        return InboxEvent(
            id: UUID(),
            timestamp: Date(),
            symbol: symbol,
            type: .rejected,
            engine: proposal.engine.rawValue,
            reasonTitle: "İşlem Reddedildi",
            reasonBullets: [reason],
            scores: proposal.scores,
            dataHealth: proposal.dataHealth,
            chironRegime: proposal.chironRegime,
            activeWeights: [:],
            executionPrice: nil,
            stopLoss: nil,
            takeProfit: nil,
            rejectionReason: reason
        )
    }
    
    // MARK: - Persistence
    
    @MainActor
    private func saveToDisk<T: Codable>(event: T) {
        let docsURL = getDocumentsDirectory()
        let pFileName = Self.persistenceFileName
        let pmFileName = Self.postMortemFileName
        
        // Removed inner Task, assuming caller is MainActor (which it now is)
        let filename = (event is InboxEvent) ? pFileName : pmFileName
        let url = docsURL.appendingPathComponent(filename)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(event)
            
            if let string = String(data: data, encoding: .utf8) {
                let line = string + "\n"
                
                if FileManager.default.fileExists(atPath: url.path) {
                    let fileHandle = try FileHandle(forWritingTo: url)
                    fileHandle.seekToEndOfFile()
                    if let lineData = line.data(using: .utf8) {
                        fileHandle.write(lineData)
                    }
                    fileHandle.closeFile()
                } else {
                    try line.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        } catch {
            print("❌ Inbox Persistence Error: \(error)")
        }
    }
    
    // Explicitly non-isolated helper for getDocumentsDirectory if needed by actor?
    // Actually getDocumentsDirectory is just a helper using FileManager. 
    // FileManager.default is thread-safe.
    nonisolated private func getDocumentsDirectory() -> URL {
        // Güvenli erişim - .first kullanımı crash önler
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback: Temporary directory (son çare)
            return FileManager.default.temporaryDirectory
        }
        return url
    }
    
    private func loadHistory() async {
        let url = getDocumentsDirectory().appendingPathComponent(Self.persistenceFileName)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        
        let lines = content.split(separator: "\n")
        
        // Decode on MainActor to satisfy isolation
        await MainActor.run {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var loadedEvents: [InboxEvent] = []
            
            for line in lines.suffix(maxMemEvents) {
                if let data = line.data(using: .utf8),
                   let event = try? decoder.decode(InboxEvent.self, from: data) {
                    loadedEvents.insert(event, at: 0)
                }
            }
            self.events = loadedEvents
        }
    }
}
