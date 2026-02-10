import Foundation

/// Shared Client for LLM APIs
/// Priority: GLM -> Groq -> Gemini
/// Replaces ad-hoc implementations in Hermes and ArgusExplanationService.
final class GroqClient: Sendable {
    static let shared = GroqClient()

    // API Keys from Secrets (Modified to use APIKeyStore for Runtime Updates)
    private var apiKey: String { APIKeyStore.shared.groqApiKey }
    private var glmKey: String { APIKeyStore.shared.glmApiKey }

    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let glmURLs = [
        "https://open.bigmodel.cn/api/paas/v4/chat/completions",
        "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",
        "https://api.z.ai/api/paas/v4/chat/completions",
        "https://api.z.ai/api/coding/paas/v4/chat/completions"
    ]

    private let primaryModel = "llama-3.3-70b-versatile" // NEW LLaMA 3.3
    private let fallbackModel = "llama-3.1-8b-instant" // Fast Fallback
    // GLM Models: glm-4-plus is confirmed working (2026-02)
    private let glmModels = ["glm-4-plus"]
    
    // GLM Rate Limiting (Concurrency + Token Bucket)
    private let glmLimiter = GLMConcurrencyLimiter(maxConcurrent: 2)
    private let glmBucket = GLMTokenBucket(capacity: 8, tokensPerInterval: 4, interval: 5.0)
    
    // Rate Limit: Groq free tier ~30 RPM, ~6000 TPM
    // Capacity: 50 burst (Increased for paid tiers), refill: 10 tokens per 10 seconds
    private let rateLimiter = GroqTokenBucket(capacity: 50, tokensPerInterval: 10, interval: 10.0)
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    private init() {}
    
    /// Generates a structured JSON object from a prompt
    /// Priority: GLM -> Groq -> Gemini (DeepSeek removed - no balance)
    func generateJSON<T: Decodable>(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> T {
        // 1. Try GLM First (user preference - confirmed working 2026-02)
        if !glmKey.isEmpty {
            do {
                print("🤖 Trying GLM for JSON...")
                return try await generateJSONWithGLM(messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ GLM JSON Failed (\(error)). Trying Groq...")
            }
        }

        // 2. Groq Primary Model (LLaMA 3.3)
        do {
            return try await generateJSONWithModel(model: primaryModel, messages: messages, maxTokens: maxTokens)
        } catch {
            print("⚠️ Groq Primary Failed (\(error)). Switching to Fallback (\(fallbackModel))....")

            // 3. Fallback to LLaMA 3.1
            do {
                return try await generateJSONWithModel(model: fallbackModel, messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ Groq Fallback Failed. Trying Gemini...")
            }

            // 4. Last Resort: Text Mode via Gemini + Aggressive Cleaning
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
    
    // MARK: - GLM Rate Limiting Actors
    // GLM ConcurrencyLimiter and TokenBucket actors
    actor GLMConcurrencyLimiter {
        private let maxConcurrent: Int
        private var current: Int = 0
        private var waitQueue: [CheckedContinuation<Void, Never>] = []

        init(maxConcurrent: Int) { self.maxConcurrent = maxConcurrent }

        func acquire() async {
            if current < maxConcurrent {
                current += 1
                return
            }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                waitQueue.append(cont)
            }
        }

        func release() {
            if let cont = waitQueue.first {
                waitQueue.removeFirst()
                cont.resume()
            } else {
                current = max(0, current - 1)
            }
        }
    }

    actor GLMTokenBucket {
        let capacity: Double
        let tokensPerInterval: Double
        let interval: TimeInterval

        private var tokens: Double
        private var lastRefill: Date

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

    // MARK: - Groq API Methods

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
    /// Priority: GLM -> Groq -> Gemini (DeepSeek removed - no balance)
    func chat(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> String {
        // 1. Try GLM First (user preference)
        if !glmKey.isEmpty {
            do {
                print("🤖 Trying GLM...")
                return try await chatWithGLM(messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ GLM Chat Failed (\(error)). Trying Groq...")
            }
        }

        // 2. Groq Primary
        do {
            return try await chatWithModel(model: primaryModel, messages: messages, maxTokens: maxTokens)
        } catch {
            print("⚠️ Groq Chat Primary Failed (\(error)). Switching to Fallback (\(fallbackModel))...")
            do {
                return try await chatWithModel(model: fallbackModel, messages: messages, maxTokens: maxTokens)
            } catch {
                print("⚠️ Groq Chat Fallback Failed. Trying Gemini...")
            }

            // 3. Gemini Fallback (last resort)
            return try await chatWithGemini(messages: messages)
        }
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

    // MARK: - GLM Integration

    private func generateJSONWithGLM<T: Decodable>(messages: [ChatMessage], maxTokens: Int = 1024) async throws -> T {
        // GLM local rate limiting
        if !(await glmBucket.consume()) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        await glmLimiter.acquire()
        defer { glmLimiter.release() }
        
        var lastError: Error?
        for model in glmModels {
            let requestBody: [String: Any] = [
                "model": model,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
                "response_format": ["type": "json_object"],
                "max_tokens": maxTokens,
                "temperature": 0.2
            ]

            do {
                let data = try await performGLMRequest(body: requestBody)
                let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
                guard let content = responseWrapper.choices.first?.message.content else {
                    throw URLError(.cannotParseResponse)
                }

                let cleanJson = cleanJsonString(content)
                guard let jsonData = cleanJson.data(using: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }
                return try JSONDecoder().decode(T.self, from: jsonData)
            } catch {
                lastError = error
                if let ns = error as NSError?,
                   ns.domain == "GLMClient" {
                    let desc = ns.localizedDescription
                    // Model not found - try next model
                    if desc.contains("\"code\":\"1211\"") || desc.contains("模型不存在") {
                        continue
                    }
                    // Rate limit - wait longer and retry
                    if desc.contains("\"code\":\"1302\"") || desc.contains("并发数过高") {
                        print("⏳ GLM Rate Limit. Waiting 5s...")
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        continue
                    }
                }
                throw error
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    private func chatWithGLM(messages: [ChatMessage], maxTokens: Int) async throws -> String {
        // GLM local rate limiting
        if !(await glmBucket.consume()) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        await glmLimiter.acquire()
        defer { glmLimiter.release() }
        
        var lastError: Error?
        for model in glmModels {
            let requestBody: [String: Any] = [
                "model": model,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
                "max_tokens": maxTokens,
                "temperature": 0.7
            ]

            do {
                let data = try await performGLMRequest(body: requestBody)
                let responseWrapper = try JSONDecoder().decode(GroqResponseWrapper.self, from: data)
                return responseWrapper.choices.first?.message.content ?? ""
            } catch {
                lastError = error
                if let ns = error as NSError?,
                   ns.domain == "GLMClient" {
                    let desc = ns.localizedDescription
                    // Model not found - try next model
                    if desc.contains("\"code\":\"1211\"") || desc.contains("模型不存在") {
                        continue
                    }
                    // Rate limit - wait longer and retry
                    if desc.contains("\"code\":\"1302\"") || desc.contains("并发数过高") {
                        print("⏳ GLM Rate Limit. Waiting 5s...")
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        continue
                    }
                }
                throw error
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    // MARK: - Gemini Fallback

    private func chatWithGemini(messages: [ChatMessage]) async throws -> String {
        let prompt = messages.map { "\($0.role.uppercased()): \($0.content)" }.joined(separator: "\n\n")
        return try await GeminiClient.shared.generateContent(prompt: prompt)
    }

    private func performGLMRequest(body: [String: Any]) async throws -> Data {
        guard !glmKey.isEmpty else { throw URLError(.userAuthenticationRequired) }

        var lastError: Error?
        // Exponential backoff config
        var attempt = 1
        let maxAttempts = 5

        while attempt <= maxAttempts {
            for rawURL in glmURLs {
                guard let url = URL(string: rawURL) else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(glmKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                        return data
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let errStr = String(data: data, encoding: .utf8) ?? ""
                    print("❌ GLM API Error Body (\(rawURL)): \(errStr)")

                    // If 429 or provider code 1302 (并发数过高), apply backoff and retry
                    if statusCode == 429 || errStr.contains("\"code\":\"1302\"") || errStr.contains("并发数过高") {
                        // Honor Retry-After if present
                        if let http = response as? HTTPURLResponse,
                           let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
                           let seconds = Double(retryAfter) {
                            let ns = UInt64(seconds * 1_000_000_000)
                            print("⏳ GLM Retry-After: waiting \(seconds)s...")
                            try? await Task.sleep(nanoseconds: ns)
                        } else {
                            let backoff = UInt64(pow(2.0, Double(attempt)) * 500_000_000) // 0.5s,1s,2s,4s,8s
                            print("⏳ GLM 429/1302 backoff attempt #\(attempt). Waiting \(Double(backoff)/1_000_000_000)s...")
                            try? await Task.sleep(nanoseconds: backoff)
                        }
                        lastError = NSError(domain: "GLMClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "GLM Error \(statusCode): \(errStr)"])
                        continue
                    }

                    // Model missing -> try next URL/model without extra delay
                    if errStr.contains("\"code\":\"1211\"") || errStr.contains("模型不存在") {
                        lastError = NSError(domain: "GLMClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "GLM Error \(statusCode): \(errStr)"])
                        continue
                    }

                    // Other errors: fail fast
                    lastError = NSError(domain: "GLMClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "GLM Error \(statusCode): \(errStr)"])
                } catch {
                    lastError = error
                }
            }
            attempt += 1
        }

        throw lastError ?? URLError(.badServerResponse)
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

