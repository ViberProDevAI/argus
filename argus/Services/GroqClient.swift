import Foundation

/// Shared Client for Groq API (LLaMA 3.3 70B) with DeepSeek Fallback
/// Replaces ad-hoc implementations in Hermes and ArgusExplanationService.
final class GroqClient: Sendable {
    static let shared = GroqClient()
    
    // API Keys from Secrets (Modified to use APIKeyStore for Runtime Updates)
    private var apiKey: String { APIKeyStore.shared.groqApiKey }
    private var deepSeekKey: String { APIKeyStore.shared.deepSeekApiKey }
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let deepSeekURL = "https://api.deepseek.com/v1/chat/completions"
    
    private let primaryModel = "llama-3.3-70b-versatile" // NEW LLaMA 3.3
    private let fallbackModel = "llama-3.1-8b-instant" // Fast Fallback
    private let deepSeekModel = "deepseek-chat" // DeepSeek V3
    
    // Rate Limit: Groq free tier ~30 RPM, ~6000 TPM
    // Capacity: 50 burst (Increased for paid tiers), refill: 10 tokens per 10 seconds
    private let rateLimiter = GroqTokenBucket(capacity: 50, tokensPerInterval: 10, interval: 10.0)
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    private init() {}
    
    /// Generates a structured JSON object from a prompt
    func generateJSON<T: Decodable>(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> T {
        // 1. Try Primary Model (LLaMA 3.3)
        do {
            return try await generateJSONWithModel(model: primaryModel, messages: messages, maxTokens: maxTokens)
        } catch {
            print("⚠️ Groq Primary Failed (\(error)). Switching to Fallback (\(fallbackModel))....")
            
            // 2. Fallback to LLaMA 3.1
            do {
                return try await generateJSONWithModel(model: fallbackModel, messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ Groq Fallback Failed. Trying DeepSeek...")
            }
            
            // 3. DeepSeek Fallback (for quota or model failures)
            do {
                return try await generateJSONWithDeepSeek(messages: messages, maxTokens: maxTokens)
            } catch {
                // 4. Gemini Fallback (if DeepSeek fails)
                print("⚠️ DeepSeek Failed. Trying Gemini...")
                do {
                    return try await generateJSONWithGemini(messages: messages)
                } catch {
                    // 5. Last Resort: Text Mode + Aggressive Cleaning
                    print("⚠️ Gemini Failed. Trying Manual Text Extraction...")
                    let text = try await chat(messages: messages)
                    
                    let clean = text.replacingOccurrences(of: "```json", with: "")
                                    .replacingOccurrences(of: "```", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard let jsonData = clean.data(using: .utf8) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    return try JSONDecoder().decode(T.self, from: jsonData)
                }
            }
        }
    }
    
    private func generateJSONWithDeepSeek<T: Decodable>(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> T {
        let requestBody: [String: Any] = [
            "model": deepSeekModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
            "temperature": 0.3
        ]
        
        let data = try await performDeepSeekRequest(body: requestBody)
        
        let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
        guard let content = responseWrapper.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        
        let cleanJson = cleanJsonString(content)
        
        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return try JSONDecoder().decode(T.self, from: jsonData)
    }
    
    // State Management (Thread Safe)
    private let state = ClientState()
    
    actor ClientState {
        var isDeepSeekDisabled = false
        func disableDeepSeek() { isDeepSeekDisabled = true }
        func isDeepSeekActive() -> Bool { return !isDeepSeekDisabled }
    }

    private func performDeepSeekRequest(body: [String: Any]) async throws -> Data {
        // Circuit Breaker Check
        guard await state.isDeepSeekActive() else {
            throw NSError(domain: "DeepSeekClient", code: 503, userInfo: [NSLocalizedDescriptionKey: "DeepSeek Disabled due to Insufficient Balance"])
        }
        
        guard let url = URL(string: deepSeekURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(deepSeekKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errStr = String(data: data, encoding: .utf8) ?? ""
            print("❌ DeepSeek API Error: \(errStr)")
            
            // Check for Insufficient Balance
            if httpResponse.statusCode == 402 || errStr.contains("Insufficient Balance") {
                print("⛔️ DeepSeek Balance Exhausted. Disabling DeepSeek Fallback.")
                await state.disableDeepSeek()
            }
            
            throw NSError(domain: "DeepSeekClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "DeepSeek Error \(httpResponse.statusCode): \(errStr)"])
        }
        
        print("✅ DeepSeek Fallback Başarılı")
        return data
    }
    
    private func generateJSONWithModel<T: Decodable>(model: String, messages: [ChatMessage], maxTokens: Int = 1024) async throws -> T {
        // Rate Limit Check (Relaxed)
        if !(await rateLimiter.consume()) {
             print("⏳ Groq Local Rate Limit. Waiting 1s...")
             try? await Task.sleep(nanoseconds: 1_000_000_000)
             // Force proceed even if bucket empty, assuming paid tier might allow burst
        }
        
        // Force JSON instruction
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "response_format": ["type": "json_object"], // Enable JSON Mode
            "max_tokens": maxTokens,
            "temperature": 0.3 // Deterministic
        ]
        
        let data = try await performRequestWithRetry(body: requestBody)
        
        // Parse Wrapper
        let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
        guard let content = responseWrapper.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        
        // Parse Inner JSON
        let cleanJson = cleanJsonString(content)
        
        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return try JSONDecoder().decode(T.self, from: jsonData)
    }
    
    /// Sends a standard chat prompt and returns string
    func chat(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> String {
        // 1. Try Primary Model
        do {
            return try await chatWithModel(model: primaryModel, messages: messages, maxTokens: maxTokens)
        } catch {
            print("⚠️ Groq Chat Primary Failed (\(error)). Switching to Fallback (\(fallbackModel))...")
            do {
                return try await chatWithModel(model: fallbackModel, messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ Groq Chat Fallback Failed. Trying DeepSeek...")
            }
            
            // 3. DeepSeek Fallback (for quota or model failures)
            do {
                return try await chatWithDeepSeek(messages: messages, maxTokens: maxTokens)
            } catch {
                // 4. Gemini Fallback
                print("⚠️ DeepSeek Chat Failed. Trying Gemini...")
                return try await chatWithGemini(messages: messages)
            }
        }
    }
    
    private func chatWithDeepSeek(messages: [ChatMessage], maxTokens: Int) async throws -> String {
        let requestBody: [String: Any] = [
            "model": deepSeekModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]
        
        let data = try await performDeepSeekRequest(body: requestBody)
        let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
        return responseWrapper.choices.first?.message.content ?? ""
    }
    
    private func chatWithModel(model: String, messages: [ChatMessage], maxTokens: Int) async throws -> String {
        // Rate Limit Check
        if !(await rateLimiter.consume()) {
             try? await Task.sleep(nanoseconds: 2_000_000_000)
             if !(await rateLimiter.consume()) {
                 throw NSError(domain: "GroqClient", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate Limit Exceeded (Local)"])
             }
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]
        
        let data = try await performRequestWithRetry(body: requestBody)
        let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
        return responseWrapper.choices.first?.message.content ?? ""
    }
    
    // MARK: - Gemini Integration
    
    private func generateJSONWithGemini<T: Decodable>(messages: [ChatMessage]) async throws -> T {
        // Convert chat messages to single prompt
        let prompt = messages.map { "\($0.role.uppercased()): \($0.content)" }.joined(separator: "\n\n") + "\n\nRespond with VALID JSON ONLY."
        
        // Use GeminiClient
        let response = try await GeminiClient.shared.generateContent(prompt: prompt)
        
        // Clean JSON
        let clean = response.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = clean.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return try JSONDecoder().decode(T.self, from: jsonData)
    }
    
    private func chatWithGemini(messages: [ChatMessage]) async throws -> String {
        let prompt = messages.map { "\($0.role.uppercased()): \($0.content)" }.joined(separator: "\n\n")
        return try await GeminiClient.shared.generateContent(prompt: prompt)
    }
    
    private func performRequestWithRetry(body: [String: Any], attempt: Int = 1) async throws -> Data {
        do {
            return try await performRequest(body: body)
        } catch {
            let nsError = error as NSError
            if nsError.code == 429 {
                // Check if it's Daily Limit (TPD) -> "tokens per day"
                let errorStr = nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
                if errorStr.contains("tokens per day") || errorStr.contains("TPD") {
                    print("⛔️ Groq Daily Quota Exceeded. Stopping Retries.")
                    throw HermesError.quotaExhausted
                }
                
                if attempt <= 4 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 5_000_000_000) // 5s, 10s, 20s, 40s
                    print("⚠️ Groq Rate Limit (429). Waiting \(delay/1_000_000_000)s...")
                    try await Task.sleep(nanoseconds: delay)
                    return try await performRequestWithRetry(body: body, attempt: attempt + 1)
                }
            }
            throw error
        }
    }
    
    private func performRequest(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             let errStr = String(data: data, encoding: .utf8) ?? ""
             print("❌ Groq API Error Body: \(errStr)")
             throw NSError(domain: "GroqClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Groq Error \(httpResponse.statusCode): \(errStr)"])
        }
        
        return data
    }
    
    private func cleanJsonString(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Remove Markdown Code Blocks
        if clean.contains("```") {
            let parts = clean.components(separatedBy: "```")
            if parts.count >= 3 {
                clean = parts[1]
                if clean.hasPrefix("json") {
                    clean = String(clean.dropFirst(4))
                }
            }
        }
        
        // 2. Robust Regex Extraction: Find first '{' and last '}'
        if let firstBrace = clean.firstIndex(of: "{"),
           let lastBrace = clean.lastIndex(of: "}") {
            if firstBrace <= lastBrace {
                clean = String(clean[firstBrace...lastBrace])
            }
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Private Token Bucket
actor GroqTokenBucket {
    let capacity: Double
    let tokensPerInterval: Double
    let interval: TimeInterval
    
    var tokens: Double
    var lastRefill: Date
    
    init(capacity: Double, tokensPerInterval: Double, interval: TimeInterval) {
        self.capacity = capacity
        self.tokensPerInterval = tokensPerInterval
        self.interval = interval
        self.tokens = capacity
        self.lastRefill = Date()
    }
    
    func consume() -> Bool {
        refill()
        if tokens >= 1 {
            tokens -= 1
            return true
        }
        return false
    }
    
    private func refill() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefill)
        let tokensToAdd = (timePassed / interval) * tokensPerInterval
        
        if tokensToAdd > 0 {
            tokens = min(capacity, tokens + tokensToAdd)
            lastRefill = now
        }
    }
}

// Private Wrappers
private struct GroqResponseWrapper: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
    }
    struct Message: Codable {
        let content: String
    }
}
