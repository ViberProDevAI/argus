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
        guard let apiKey = APIKeyStore.getDirectKey(for: .gemini) else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Use gemini-1.5-flash for speed and higher rate limits
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            
            print("❌ Gemini API Error (\(statusCode)): \(errorText)")
            
            // Check for Billing/Quota Issues
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
            
            throw NSError(domain: "GeminiClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error: \(errorText)"])
        }
        
        // Parse Response
        // Structure: { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
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
}
