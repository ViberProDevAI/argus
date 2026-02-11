import Foundation

/// Interface for actual LLM calls
public protocol MimirLLMProtocol: Sendable {
    func generate(model: String, prompt: String) async throws -> String
}

/// The Gatekeeper that performs the Network Call
struct MimirLLMGateway: Sendable {
    private let client: MimirLLMProtocol
    
    nonisolated init(client: MimirLLMProtocol? = nil) {
        self.client = client ?? MockMimirLLMClient()
    }
    
    func execute(task: MimirTask, model: String) async throws -> MimirResult {
        // Construct Prompt
        let prompt = buildPrompt(task: task)
        
        // Call LLM
        let rawResponse = try await client.generate(model: model, prompt: prompt)
        
        // Validate JSON
        guard let json = extractJSON(from: rawResponse) else {
            throw MimirError.invalidJSON
        }
        
        // In real app, we would validate Schema here specifically per TaskType
        
        return MimirResult(
            taskId: task.id,
            status: .ok,
            modelUsed: model,
            json: json,
            explanation: nil,
            timestamp: Date()
        )
    }
    
    private func buildPrompt(task: MimirTask) -> String {
        // Enforce strict JSON
        return """
        system: You are a data processing engine. Output valid JSON only. No markdown.
        task: \(task.type.rawValue)
        inputs: \(task.inputs)
        """
    }
    
    private func extractJSON(from text: String) -> String? {
        // Simple extractor handling markdown blocks
        let pattern = #"```json\s*(\{[\s\S]*?\})\s*```"#
        
        if let range = text.range(of: pattern, options: .regularExpression) {
             let match = text[range]
             return String(match.dropFirst(7).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            return text
        }
        return nil
    }
}

enum MimirError: Error {
    case invalidJSON
    case gatewayTimeout
}

struct MockMimirLLMClient: MimirLLMProtocol {
    nonisolated init() {}
    func generate(model: String, prompt: String) async throws -> String {
        // Simulate Network Latency
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        return """
        ```json
        { "status": "mock_success", "model": "\(model)" }
        ```
        """
    }
}
