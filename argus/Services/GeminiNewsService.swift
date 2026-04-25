import Foundation

final class GeminiNewsService: Sendable {
    static let shared = GeminiNewsService()
    
    // Powered by Groq (Llama 3.3 70B)
    private var apiKey: String { Secrets.groqKey }
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let modelName = "llama-3.3-70b-versatile" // Updated to 3.3 (Latest/Best)
    
    // Rate Limiting (Groq is faster, let's allow 30 RPM)
    private let rateLimiter = TokenBucket(capacity: 30, tokensPerInterval: 1, interval: 2.0)
    
    // MARK: - Public API
    func analyzeNews(symbol: String, article: NewsArticle) async throws -> NewsInsight {
        // 1. Check Rate Limit
        if await rateLimiter.consume() {
            // Authorized to use API
            return try await performRemoteAnalysisWithRetry(symbol: symbol, article: article)
        } else {
            // Quota exhausted (Local Fallback)
            print("⚠️ Groq Rate Limit Protection (Local Fallback): \(article.headline)")
            return performLocalAnalysis(symbol: symbol, article: article)
        }
    }

    private func performRemoteAnalysisWithRetry(symbol: String, article: NewsArticle) async throws -> NewsInsight {
        let maxRetries = 2
        var currentAttempt = 0
        var lastError: Error?
        
        while currentAttempt < maxRetries {
            do {
                return try await performAnalysis(symbol: symbol, article: article)
            } catch let error as NSError where error.code == 429 {
                lastError = error
                currentAttempt += 1
                if currentAttempt >= maxRetries {
                    return performLocalAnalysis(symbol: symbol, article: article, error: error)
                }
                let delay = UInt64(1_000_000_000 * 1)
                try? await Task.sleep(nanoseconds: delay)
            } catch {
                return performLocalAnalysis(symbol: symbol, article: article, error: error)
            }
        }
        return performLocalAnalysis(symbol: symbol, article: article, error: lastError)
    }

    private func performAnalysis(symbol: String, article: NewsArticle) async throws -> NewsInsight {
        // 1. Prompt Construction (Simplified for Reliability)
        let isGeneralScan = (symbol == "MARKET" || symbol == "GENERAL")
        
        // Dynamic Subject Line
        let subjectLine = isGeneralScan 
            ? "Analyze this news. First, IDENTIFY the main company/asset mentioned. Then analyze the impact for THAT asset."
            : "Analyze this financial news for ticker: \(symbol)"
        
        // Simplified Prompt for Llama 3.3
        let promptText = """
        \(subjectLine)
        Headline: "\(article.headline)"
        Summary: "\(article.summary ?? "")"
        
        Return a JSON object with:
        - summaryTRLong: Turkish summary (max 2 sentences).
        - impactSentenceTR: Turkish impact comment (1 sentence).
        - sentiment: One of [strong_positive, weak_positive, neutral, weak_negative, strong_negative].
        - confidence: 0.0 to 1.0.
        - impact_score: 0 to 100.
        - relatedTickers: Array of strings (e.g. ["AAPL"]).
        """
        
        // 2. HTTP Request Body
        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a financial analyst. Output ONLY valid JSON. Do not write markdown blocks."],
            ["role": "user", "content": promptText]
        ]
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            // "response_format": ["type": "json_object"], // DISABLED: Groq raises 400 with Llama 3.x on some keys
            "temperature": 0.1 // Cleaner output
        ]
        
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 3. Perform Request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             throw NSError(domain: "GroqService", code: httpResponse.statusCode, userInfo: nil)
        }
        
        // 4. Parse Response
        let groqResponse = try JSONDecoder().decode(GroqNewsResponse.self, from: data)
        guard let text = groqResponse.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        
        let cleanedJsonString = cleanJsonString(text)
        guard let jsonData = cleanedJsonString.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let insightDTO = try JSONDecoder().decode(NewsInsightDTO.self, from: jsonData)
        
        return NewsInsight(
            id: UUID(),
            symbol: symbol,
            articleId: article.id,
            headline: article.headline,
            summaryTRLong: insightDTO.summaryTRLong,
            impactSentenceTR: insightDTO.impactSentenceTR,
            sentiment: NewsSentiment(rawValue: insightDTO.sentiment) ?? .neutral,
            confidence: insightDTO.confidence,
            impactScore: insightDTO.impact_score ?? 50.0, // Default to Neutral if missing
            relatedTickers: insightDTO.relatedTickers,
            createdAt: Date()
        )
    }
    
    // MARK: - Local Fallback Analysis
    private func performLocalAnalysis(symbol: String, article: NewsArticle, error: Error? = nil) -> NewsInsight {
        let text = (article.headline + " " + (article.summary ?? "")).lowercased()
        
        // Simple Keyword Matching
        let positives = ["yükseliş", "kar", "büyüme", "rekor", "anlaşma", "onay", "artış", "olumlu", "buy", "gain", "up", "profit"]
        let negatives = ["düşüş", "zarar", "iptal", "ceza", "kriz", "beklenti altı", "olumsuz", "sell", "loss", "down", "crash"]
        
        var score = 0
        for word in positives { if text.contains(word) { score += 1 } }
        for word in negatives { if text.contains(word) { score -= 1 } }
        
        let sentiment: NewsSentiment
        var calculatedImpact: Double = 50.0
        
        if score >= 2 { 
            sentiment = .strongPositive
            calculatedImpact = 85.0
        } else if score == 1 { 
            sentiment = .weakPositive 
            calculatedImpact = 65.0
        } else if score == -1 { 
            sentiment = .weakNegative 
            calculatedImpact = 35.0
        } else if score <= -2 { 
            sentiment = .strongNegative 
            calculatedImpact = 15.0
        } else { 
            sentiment = .neutral 
            calculatedImpact = 50.0
        }
                let summaryText = article.summary?.isEmpty ?? true ? "Analiz edilemedi." : article.summary ?? "Haber metni üzerinden otomatik analiz (Offline Mod)."
        var impactText = "Piyasa koşullarına göre takip edilmeli."
        
        if let err = error {
            impactText += " [Hata: \(err.localizedDescription)]"
        }
        
        return NewsInsight(
            id: UUID(),
            symbol: symbol,
            articleId: article.id,
            headline: article.headline,
            summaryTRLong: summaryText,
            impactSentenceTR: impactText,
            sentiment: sentiment,
            confidence: 0.5, // Lower confidence for local
            impactScore: calculatedImpact,
            relatedTickers: nil,
            createdAt: Date()
        )
    }
    
    private func cleanJsonString(_ input: String) -> String {
        // 1. Remove Markdown Code Blocks
        var str = input
        if str.contains("```json") { str = str.replacingOccurrences(of: "```json", with: "") }
        if str.contains("```") { str = str.replacingOccurrences(of: "```", with: "") }
        
        // 2. Find JSON Block (Start with { and end with })
        // This handles cases where Llama adds "Here is the JSON:" preamble
        if let startIndex = str.firstIndex(of: "{"),
           let endIndex = str.lastIndex(of: "}") {
            if startIndex <= endIndex {
                 str = String(str[startIndex...endIndex])
            }
        }
        
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Token Bucket Rate Limiter
actor TokenBucket {
    private let capacity: Double
    private let tokensPerInterval: Double
    private let interval: TimeInterval
    private var tokens: Double
    private var lastRefillTime: Date
    
    init(capacity: Double, tokensPerInterval: Double, interval: TimeInterval) {
        self.capacity = capacity
        self.tokensPerInterval = tokensPerInterval
        self.interval = interval
        self.tokens = capacity
        self.lastRefillTime = Date()
    }
    
    func consume() -> Bool {
        refill()
        if tokens >= 1.0 {
            tokens -= 1.0
            return true
        }
        return false
    }
    
    private func refill() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = (timePassed / interval) * tokensPerInterval
        
        if tokensToAdd > 0 {
            tokens = min(capacity, tokens + tokensToAdd)
            lastRefillTime = now
        }
    }
}

// MARK: - Helper Models for Groq API
private struct GroqNewsResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
    }
    struct Message: Codable {
        let content: String
    }
}

private struct NewsInsightDTO: Codable {
    let summaryTRLong: String
    let impactSentenceTR: String
    let sentiment: String
    let confidence: Double
    let impact_score: Double? // New Field
    let relatedTickers: [String]?
}
