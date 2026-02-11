import Foundation
import Combine

/// "Heimdall Telepresence"
/// The All-Seeing Eye. Centralized observability actor that records traces,
/// tracks engine health, and publishes real-time telemetry to the UI.
actor HeimdallTelepresence: ObservableObject {
    static let shared = HeimdallTelepresence()
    
    // MARK: - Storage (In-Memory Ring Buffer)
    private var traces: [RequestTraceEvent] = []
    private let maxTraceCount = 100
    
    // MARK: - Evidence Locker (Failure Snapshots)
    private var failureEvidence: [ProviderTag: FailureEvidence] = [:]
    
    // MARK: - Engine Health State
    private var engineHealth: [EngineTag: EngineHealthSnapshot] = [:]
    
    // MARK: - Publishing (MainActor Bridge)
    class TelemetryPublisher: ObservableObject {
        @Published var recentTraces: [RequestTraceEvent] = []
        @Published var engineHealth: [EngineTag: EngineHealthSnapshot] = [:]
        @Published var failoverStories: [String] = []
        // We don't publish evidence continuously, unnecessary overhead. Pulled on demand.
    }
    
    nonisolated let telemetry = TelemetryPublisher()
    
    init() {
        // This initializer is guaranteed not to throw or fail. All properties are initialized with non-failable code.
        // Initialize health snapshots
        for tag in EngineTag.allCases {
            engineHealth[tag] = EngineHealthSnapshot(engine: tag, lastSuccessAt: nil, lastFailureAt: nil, lastFailureCategory: nil, consecutiveFailures: 0)
        }
    }
    
    // MARK: - Ingestion API
    
    func record(trace: RequestTraceEvent, evidence: FailureEvidence? = nil) {
        // 1. Append to Ring Buffer
        traces.insert(trace, at: 0)
        if traces.count > maxTraceCount {
            traces.removeLast()
        }
        
        // 2. Update Engine Health
        updateHealth(from: trace)
        
        // 3. Store Evidence (If provided)
        if let ev = evidence {
            failureEvidence[trace.provider] = ev
        }
        
        // 4. Publish to UI
        let snapshotTraces = self.traces
        let snapshotHealth = self.engineHealth
        
        Task { @MainActor [snapshotTraces, snapshotHealth] in
            telemetry.recentTraces = snapshotTraces
            telemetry.engineHealth = snapshotHealth
        }
    }
    
    // MARK: - Logic
    
    private func updateHealth(from trace: RequestTraceEvent) {
        var snapshot = engineHealth[trace.engine] ?? EngineHealthSnapshot(engine: trace.engine, consecutiveFailures: 0)
        
        if trace.isSuccess {
            snapshot.lastSuccessAt = trace.timestamp
            snapshot.consecutiveFailures = 0
            
            // Log Success Story if it was a failover
            if let path = trace.failoverPath {
                addFailoverStory("✅ \(trace.engine.rawValue): \(path) (Success)")
            }
            
        } else {
            snapshot.lastFailureAt = trace.timestamp
            snapshot.lastFailureCategory = trace.failureCategory
            snapshot.consecutiveFailures += 1
            
            // Log Failure Story
            addFailoverStory("❌ \(trace.engine.rawValue): \(trace.provider.rawValue) failed via \(trace.failureCategory.rawValue)")
        }
        
        engineHealth[trace.engine] = snapshot
    }
    
    private func addFailoverStory(_ story: String) {
        Task { @MainActor in
            // Keep last 10 stories
            var current = telemetry.failoverStories
            current.insert(story, at: 0)
            if current.count > 10 { current.removeLast() }
            telemetry.failoverStories = current
        }
    }
    
    // MARK: - Query API
    
    // MARK: - Query API
    
    func getTraces() -> [RequestTraceEvent] {
        return traces
    }
    
    func getRecentTraces() -> [RequestTraceEvent] {
        return traces
    }
    
    func getFailureEvidence() -> [ProviderTag: FailureEvidence] {
        return failureEvidence
    }
    
    func getEngineHealth() -> [EngineTag: EngineHealthSnapshot] {
        return engineHealth
    }
    
    func getRegistrySnapshot() async -> RegistryDebugInfo {
        let auth = await ProviderCapabilityRegistry.shared.getAuthorizedProviders()
        let states = await ProviderCapabilityRegistry.shared.getEndpointStates()
        return RegistryDebugInfo(authorized: Array(auth).sorted(), states: states)
    }
    
    /// Generates a JSON Report of the current state
    func exportDiagnosticReport() -> String {
        struct DiagnosticReport: Codable {
            let timestamp: Date
            let health: [EngineTag: EngineHealthSnapshot]
            let recentTraces: [RequestTraceEvent]
            let appVersion: String
        }
        
        let report = DiagnosticReport(
            timestamp: Date(),
            health: self.engineHealth,
            recentTraces: self.traces,
            appVersion: "1.0.0"
        )
        
        // Pretty Print
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(report), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "Failed to generate report"
    }
}
    

