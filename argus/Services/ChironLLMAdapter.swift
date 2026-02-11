import Foundation

// MARK: - Chiron LLM Adapter
/// Uses Groq (Llama 3.3) for intelligent weight recommendations
@MainActor
final class ChironLLMAdapter {
    static let shared = ChironLLMAdapter()
    
    // Groq API - Secrets'tan al
    private var apiKey: String { Secrets.groqKey }
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let modelName = "llama-3.3-70b-versatile"
    
    private init() {}
    
    // MARK: - Weight Recommendation
    
    /// Ask LLM to recommend weight adjustments based on trade history
    func recommendWeights(
        symbol: String,
        engine: AutoPilotEngine,
        tradeHistory: [TradeOutcomeRecord],
        currentWeights: ChironModuleWeights
    ) async -> ChironModuleWeights? {
        
        guard tradeHistory.count >= 3 else { return nil }
        
        // Build trade summary
        let wins = tradeHistory.filter { $0.pnlPercent > 0 }
        let losses = tradeHistory.filter { $0.pnlPercent <= 0 }
        let winRate = Double(wins.count) / Double(tradeHistory.count) * 100
        let avgWinPnl = wins.isEmpty ? 0 : wins.map { $0.pnlPercent }.reduce(0, +) / Double(wins.count)
        let avgLossPnl = losses.isEmpty ? 0 : losses.map { $0.pnlPercent }.reduce(0, +) / Double(losses.count)
        
        // Analyze module performance at entry
        let avgOrionWin = wins.compactMap { $0.orionScoreAtEntry }.reduce(0, +) / max(1.0, Double(wins.compactMap { $0.orionScoreAtEntry }.count))
        let avgOrionLoss = losses.compactMap { $0.orionScoreAtEntry }.reduce(0, +) / max(1.0, Double(losses.compactMap { $0.orionScoreAtEntry }.count))
        let avgAtlasWin = wins.compactMap { $0.atlasScoreAtEntry }.reduce(0, +) / max(1.0, Double(wins.compactMap { $0.atlasScoreAtEntry }.count))
        let avgAtlasLoss = losses.compactMap { $0.atlasScoreAtEntry }.reduce(0, +) / max(1.0, Double(losses.compactMap { $0.atlasScoreAtEntry }.count))
        
        let prompt = """
        Sen bir trading sistemi için ağırlık optimizasyon danışmanısın.
        
        SEMBOL: \(symbol)
        MOTOR: \(engine.rawValue)
        
        TRADE GEÇMİŞİ:
        - Toplam trade: \(tradeHistory.count)
        - Win rate: %\(String(format: "%.1f", winRate))
        - Ortalama kazanç: %\(String(format: "%.2f", avgWinPnl))
        - Ortalama kayıp: %\(String(format: "%.2f", avgLossPnl))
        
        MODÜL PERFORMANSI (kazananlardaki vs kaybedenler):
        - Orion (Teknik): Kazananlarda \(String(format: "%.0f", avgOrionWin)), Kaybedenler \(String(format: "%.0f", avgOrionLoss))
        - Atlas (Temel): Kazananlarda \(String(format: "%.0f", avgAtlasWin)), Kaybedenler \(String(format: "%.0f", avgAtlasLoss))
        
        MEVCUT AĞIRLIKLAR:
        - orion: \(String(format: "%.2f", currentWeights.orion))
        - atlas: \(String(format: "%.2f", currentWeights.atlas))
        - phoenix: \(String(format: "%.2f", currentWeights.phoenix))
        - aether: \(String(format: "%.2f", currentWeights.aether))
        - hermes: \(String(format: "%.2f", currentWeights.hermes))
        - demeter: \(String(format: "%.2f", currentWeights.demeter))
        - athena: \(String(format: "%.2f", currentWeights.athena))
        
        GÖREV: Bu verilere dayanarak yeni ağırlıklar öner. Ağırlıklar toplamı 1.0 olmalı.
        
        JSON formatında döndür:
        {
            "orion": 0.XX,
            "atlas": 0.XX,
            "phoenix": 0.XX,
            "aether": 0.XX,
            "hermes": 0.XX,
            "demeter": 0.XX,
            "athena": 0.XX,
            "reasoning": "Türkçe kısa açıklama (max 2 cümle)",
            "confidence": 0.X
        }
        """
        
        do {
            let response = try await callGroq(prompt: prompt)
            return parseWeightsResponse(response, symbol: symbol, engine: engine)
        } catch {
            print("❌ ChironLLM: API error - \(error)")
            return nil
        }
    }
    
    // MARK: - Groq API Call
    
    private func callGroq(prompt: String) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": "Sen finansal bir analiz asistanısın. Sadece geçerli JSON döndür, markdown kullanma."],
            ["role": "user", "content": prompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.1
        ]
        
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "ChironLLM", code: httpResponse.statusCode, userInfo: nil)
        }
        
        struct GroqResponse: Codable {
            let choices: [Choice]
            struct Choice: Codable {
                let message: Message
            }
            struct Message: Codable {
                let content: String
            }
        }
        
        let groqResponse = try JSONDecoder().decode(GroqResponse.self, from: data)
        return groqResponse.choices.first?.message.content ?? ""
    }
    
    // MARK: - Parse Response
    
    private func parseWeightsResponse(_ text: String, symbol: String, engine: AutoPilotEngine) -> ChironModuleWeights? {
        // Clean JSON
        var str = text
        if str.contains("```json") { str = str.replacingOccurrences(of: "```json", with: "") }
        if str.contains("```") { str = str.replacingOccurrences(of: "```", with: "") }
        
        if let startIndex = str.firstIndex(of: "{"),
           let endIndex = str.lastIndex(of: "}") {
            if startIndex <= endIndex {
                str = String(str[startIndex...endIndex])
            }
        }
        
        guard let jsonData = str.data(using: .utf8) else { return nil }
        
        struct LLMWeights: Codable {
            let orion: Double
            let atlas: Double
            let phoenix: Double
            let aether: Double
            let hermes: Double
            let demeter: Double
            let athena: Double
            let reasoning: String
            let confidence: Double
        }
        
        do {
            let parsed = try JSONDecoder().decode(LLMWeights.self, from: jsonData)
            
            return ChironModuleWeights(
                orion: parsed.orion,
                atlas: parsed.atlas,
                phoenix: parsed.phoenix,
                aether: parsed.aether,
                hermes: parsed.hermes,
                demeter: parsed.demeter,
                athena: parsed.athena,
                updatedAt: Date(),
                confidence: parsed.confidence,
                reasoning: "🤖 LLM: \(parsed.reasoning)"
            ).normalized()
        } catch {
            print("❌ ChironLLM: Parse error - \(error)")
            return nil
        }
    }
}
