import Foundation

/// MIMIR AI Interface
/// Responsibility: Generate 'DataInstruction' for missing data.
/// Security: NEVER asks for raw values. ONLY asks for "How to fetch".
actor GeminiClient {
    static let shared = GeminiClient()
    
    private init() {}
    
    func generateInstruction(for issue: MimirIssue) async throws -> DataInstruction {
        // In a real implementation, this calls Google Generative AI API
        // Prompt: "Standardize data fetch for asset \(issue.asset) from valid providers."
        
        // Mock Response for "Aether Stale"
        if issue.engine == .aether && issue.asset == "CPI" {
             return DataInstruction(
                id: UUID().uuidString,
                targetProvider: "FRED",
                endpoint: "series/observer?series_id=CPIAUCSL",
                method: "GET",
                validationRegex: #"^\d+\.\d+$"#,
                requiredFields: ["value", "date"]
             )
        }
        
        throw URLError(.badURL) // "I don't know"
    }

    // MARK: - Argus Voice / General Generation
    
    /// Generates text content using GLM.
    /// Used by Argus Voice and legacy Gemini call sites.
    func generateContent(prompt: String) async throws -> String {
        guard let apiKey = APIKeyStore.getDirectKey(for: .glm), !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let body: [String: Any] = [
            "model": "glm-4-plus",  // Updated 2026-02: glm-4.7-flash no longer exists
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        let urls = [
            "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",
            "https://api.z.ai/api/paas/v4/chat/completions",
            "https://api.z.ai/api/coding/paas/v4/chat/completions"
        ]
        
        var lastError: Error?
        var responseData: Data?
        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    responseData = data
                    break
                }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let err = String(data: data, encoding: .utf8) ?? "Unknown Error"
                lastError = NSError(domain: "GLMClient", code: code, userInfo: [NSLocalizedDescriptionKey: "GLM Error: \(err)"])
            } catch {
                lastError = error
            }
        }
        
        guard let data = responseData else {
            throw lastError ?? URLError(.badServerResponse)
        }

        struct GLMResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(GLMResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "No response generated."
    }
}
