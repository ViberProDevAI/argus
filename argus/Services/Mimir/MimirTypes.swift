import Foundation

public enum MimirTaskType: String, Codable, Sendable {
    case atlasFieldMapping
    case aetherExplanation
    case orionNormalization
    case phoenixDebugSummary
    case generalReasoning
}

public struct MimirTask: Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sourceModule: String         // "ATLAS", "AETHER", ...
    public let type: MimirTaskType
    public let priority: Int               // 0 (Critical) .. 3 (Low)
    public let valueScore: Int             // 1..100
    public let ttlSeconds: Int?
    public let inputs: [String: String]    // Context data
    
    public init(module: String, type: MimirTaskType, priority: Int, value: Int, inputs: [String: String], ttl: Int? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceModule = module
        self.type = type
        self.priority = priority
        self.valueScore = value
        self.inputs = inputs
        self.ttlSeconds = ttl
    }
}

public struct MimirResult: Codable, Sendable {
    public let taskId: UUID
    public let status: Status
    public let modelUsed: String?
    public let json: String?               // Strict JSON output
    public let explanation: String?        // Log/UI text
    public let timestamp: Date
    
    public enum Status: String, Codable, Sendable {
        case ok
        case cached
        case queued
        case skipped
        case degraded // Fallback or partial
        case error
    }
    
    nonisolated static func error(id: UUID, message: String) -> MimirResult {
        return MimirResult(taskId: id, status: .error, modelUsed: nil, json: nil, explanation: message, timestamp: Date())
    }
}
