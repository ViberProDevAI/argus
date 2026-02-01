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
    
    /// Generates text content using Gemini Pro.
    /// Used by Argus Voice for Reporting.
    func generateContent(prompt: String) async throws -> String {
        // Correctly access via Enum (Direct Static Access)
        guard let apiKey = APIKeyStore.getDirectKey(for: .gemini), !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        // Model fallback chain (v1beta -> v1)
        let modelCandidates = [
            "gemini-1.5-pro",
            "gemini-1.0-pro"
        ]
        
        var lastError: Error?
        for version in ["v1beta", "v1"] {
            for model in modelCandidates {
                let urlString = "https://generativelanguage.googleapis.com/\(version)/models/\(model):generateContent?key=\(apiKey)"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    struct GeminiResponse: Decodable {
                        struct Candidate: Decodable {
                            struct Content: Decodable {
                                struct Part: Decodable {
                                    let text: String
                                }
                                let parts: [Part]
                            }
                            let content: Content?
                        }
                        let candidates: [Candidate]?
                    }
                    
                    let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return result.candidates?.first?.content?.parts.first?.text ?? "No response generated."
                }
                
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
                print("❌ Gemini API Error (\(statusCode)) [\(version)/\(model)]: \(errorText)")
                
                if statusCode == 429 {
                    print("""
                    🚨 GEMINI QUOTA EXCEEDED (429)
                    --------------------------------------------------
                    Google'a kredi kartı eklemek yeterli değildir!
                    Lütfen şu adrese gidip 'Pay-as-you-go' (Faturalı) modunu açın:
                    👉 https://aistudio.google.com/app/plan_information
                    
                    Projeyi 'Free of Charge' yerine 'Blaze' veya 'Pay-as-you-go' olarak seçmelisiniz.
                    --------------------------------------------------
                    """)
                }
                
                lastError = NSError(domain: "GeminiClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error: \(errorText)"])
            }
        }
        
        if let lastError {
            throw lastError
        }
        throw URLError(.badServerResponse)
        
        // handled by model fallback chain above
    }
}
