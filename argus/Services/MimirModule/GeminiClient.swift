import Foundation

/// MIMIR AI Interface + General Gemini Access
/// Now uses real Gemini 2.5 Flash API as primary, GLM as fallback.
actor GeminiClient {
    static let shared = GeminiClient()

    private let geminiModels = [
        "gemini-2.5-flash-preview-05-20",
        "gemini-2.0-flash"
    ]
    private let geminiBaseURL = "https://generativelanguage.googleapis.com"

    private init() {}

    func generateInstruction(for issue: MimirIssue) async throws -> DataInstruction {
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

        throw URLError(.badURL)
    }

    // MARK: - General Text Generation

    /// Generates text content using Gemini 2.5 Flash (primary) or GLM (fallback).
    /// Used by Argus Voice and legacy call sites.
    func generateContent(prompt: String) async throws -> String {
        // 1. Try Gemini 2.5 Flash first
        let geminiKey = APIKeyStore.shared.geminiApiKey
        if !geminiKey.isEmpty {
            do {
                return try await callGemini(prompt: prompt, apiKey: geminiKey)
            } catch {
                print("⚠️ GeminiClient: Gemini failed (\(error)). Trying GLM fallback...")
            }
        }

        // 2. Fallback to GLM
        guard let glmKey = APIKeyStore.getDirectKey(for: .glm), !glmKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await callGLM(prompt: prompt, apiKey: glmKey)
    }

    // MARK: - Gemini API

    private func callGemini(prompt: String, apiKey: String) async throws -> String {
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048
            ]
        ]

        var lastError: Error?
        for version in ["v1beta", "v1"] {
            for model in geminiModels {
                guard let url = URL(string: "\(geminiBaseURL)/\(version)/models/\(model):generateContent?key=\(apiKey)") else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                        struct GeminiResponse: Decodable {
                            struct Candidate: Decodable {
                                struct Content: Decodable {
                                    struct Part: Decodable { let text: String? }
                                    let parts: [Part]
                                }
                                let content: Content
                            }
                            let candidates: [Candidate]?
                        }
                        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                        if let text = decoded.candidates?.first?.content.parts.first?.text {
                            print("✅ GeminiClient: \(model) success")
                            return text
                        }
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("⚠️ GeminiClient \(version)/\(model) Error (\(statusCode)): \(errStr.prefix(200))")
                    lastError = NSError(domain: "GeminiClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error \(statusCode)"])
                } catch {
                    lastError = error
                }
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    // MARK: - GLM Fallback

    private func callGLM(prompt: String, apiKey: String) async throws -> String {
        let body: [String: Any] = [
            "model": "glm-4-plus",
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
                    struct GLMResponse: Decodable {
                        struct Choice: Decodable {
                            struct Message: Decodable { let content: String }
                            let message: Message
                        }
                        let choices: [Choice]
                    }
                    let decoded = try JSONDecoder().decode(GLMResponse.self, from: data)
                    return decoded.choices.first?.message.content ?? "No response generated."
                }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let err = String(data: data, encoding: .utf8) ?? "Unknown Error"
                lastError = NSError(domain: "GLMClient", code: code, userInfo: [NSLocalizedDescriptionKey: "GLM Error: \(err)"])
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.badServerResponse)
    }
}
