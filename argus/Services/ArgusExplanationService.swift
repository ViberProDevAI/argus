import Foundation

// MARK: - Chat Models
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
}

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

/// Service that interprets the Argus Decision into a human-readable Turkish explanation using Groq (LLaMA 3).
final class ArgusExplanationService: Sendable {
    static let shared = ArgusExplanationService()
    
    // In-Memory Cache: Key = "SYMBOL_FINAL_SCORE_DATE_HOUR"
    private var cache: [String: ArgusExplanation] = [:]
    
    private init() {
        // Load cache from disk
        Task {
            if let loaded: [String: ArgusExplanation] = await ArgusDataStore.shared.load(key: "argus_explanation_cache") {
                self.cache = loaded
                print("🧠 ArgusExplanation: Loaded \(loaded.count) items from disk cache.")
            }
        }
    }
    
    // MARK: - Chat Functionality
    
    func chat(history: [ChatMessage], contextDecisions: [ArgusDecisionResult], portfolio: [Trade]) async throws -> String {
        var messages: [GroqClient.ChatMessage] = []
        
        // System Prompt
        let systemPrompt = """
        SEN 'ARGUS'SUN. Bu algoritmik ticaret sisteminin YÖNETİCİ ZEKASISIN.
        Kullanıcı senin "Kaptanın". Ona stratejik tavsiyeler ver. Analitik ve otoriter ol.
        
        KURALLAR:
        1. SADECE TÜRKÇE KONUŞ. Asla İngilizce, Çince veya Endonezce kelime kullanma.
        2. "ATLAS sistemim...", "ORION sistemim..." gibi cümleler kurarken terminolojiye sadık kal ama robotik olma.
        3. Kısa ve net cevaplar ver. Felsefe yapma.
        
        SİSTEMLER:
        - ATLAS: Temel Analiz
        - AETHER: Makroekonomik Analiz
        - ORION: Teknik Analiz
        - HERMES: Haber Analizi
        - CRONOS: Zamanlama
        """
        messages.append(.init(role: "system", content: systemPrompt))
        
        // Portfolio Context
        if !portfolio.isEmpty {
            let openPositions = portfolio.filter { $0.isOpen }
            var portfolioDesc = "MEVCUT PORTFÖY:\n"
            for trade in openPositions {
                portfolioDesc += "- \(trade.symbol): \(trade.quantity) Adet @ $\(trade.entryPrice).\n"
            }
            messages.append(.init(role: "system", content: portfolioDesc))
        }
        
        // Decisions Context
        let uniqueDecisions = Array(contextDecisions.suffix(5))
        if !uniqueDecisions.isEmpty {
             let encoder = JSONEncoder() 
             encoder.outputFormatting = .prettyPrinted
             for decision in uniqueDecisions {
                 if let data = try? encoder.encode(decision), let str = String(data: data, encoding: .utf8) {
                     messages.append(.init(role: "system", content: "ANALİZ VERİSİ (\(decision.symbol)): \(str)"))
                 }
             }
        }
        
        // History
        for msg in history.suffix(10) {
            messages.append(.init(role: msg.role.rawValue, content: msg.content))
        }
        
        return try await GroqClient.shared.chat(messages: messages)
    }
    
    func generateExplanation(for decision: ArgusDecisionResult) async throws -> ArgusExplanation {
        // 1. Check Cache (Throttling: 6 Hour Rule - Extended to save LLM quota)
        // Prevent API spam by reusing valid explanations for the same symbol
        let cacheKey = "\(decision.symbol)_v2"
        if let cached = cache[cacheKey], !cached.isOffline {
             let age = Date().timeIntervalSince(cached.createdAt)
             if age < 21600 { // 6 Hours (was 1 hour)
                 print("♻️ Argus: Using Cached Explanation for \(decision.symbol) (\(Int(age/3600))h old)")
                 return cached
             }
        }
        
        // 2. Prepare Prompt
        let promptText = try buildPrompt(for: decision)
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "You are a JSON-speaking financial analyst. Output valid JSON only."),
            .init(role: "user", content: promptText)
        ]
        
        // 3. Request via GroqClient
        do {
            var explanation: ArgusExplanation = try await GroqClient.shared.generateJSON(messages: messages)
            explanation.createdAt = Date()
            
            // Cache & Return
            self.cache[cacheKey] = explanation
            self.persistCache()
            
            return explanation
            
        } catch {
            print("❌ Groq Explanation Failed: \(error)")
            // Fallback with Real Error Reason
            let fallback = generateOfflineExplanation(for: decision, reason: error.localizedDescription)
            self.cache[cacheKey] = fallback
            self.persistCache()
            return fallback
        }
    }
    
    // MARK: - Offline / Deterministic Generator (The "Real Data" Engine)
    /// Generates a data-driven explanation even if the LLM is offline.
    /// This prevents "fake" or "placeholder" text by constructing sentences from actual scores.
    func generateOfflineExplanation(for decision: ArgusDecisionResult, reason: String? = nil) -> ArgusExplanation {
        
        // 1. Determine Tone & Title
        let grade = decision.letterGradeCore
        var title = ""
        var toneTag = "balanced"
        
        if decision.finalScoreCore >= 75 {
            title = "Güçlü Yükseliş Potansiyeli (\(grade))"
            toneTag = "bullish"
        } else if decision.finalScoreCore <= 35 {
            title = "Zayıf Görünüm (\(grade))"
            toneTag = "bearish"
        } else {
            title = "Dengeli / Nötr Görünüm (\(grade))"
            toneTag = "balanced"
        }
        
        // ORION (Active Trader Context) override
        // E.g. If Orion is screaming Buy but Atlas sucks -> "Teknik Fırsat" instead of just "Dengeli"
        if decision.orionScore > 80 && decision.atlasScore < 40 {
            title = "Teknik Fırsat (Orion Onayı)"
        }
        
        // 2. Build Bullets (Dynamic)
        var bullets: [String] = []
        
        // Bullet 1: Orion / Technical
        let orionDesc = describeScore(decision.orionScore, type: "teknik")
        bullets.append("Orion (Teknik): \(orionDesc) (Skor: \(Int(decision.orionScore)))")
        
        // Bullet 2: Atlas / Fundamental
        let atlasDesc = describeScore(decision.atlasScore, type: "temel")
        bullets.append("Atlas (Temel): \(atlasDesc) (Skor: \(Int(decision.atlasScore)))")
        
        // Bullet 3: Special Insight or Risk
        if decision.aetherScore < 40 {
             bullets.append("Aether (Makro): Piyasa rüzgarı ters yönde esiyor (Risk-Off).")
        } else if decision.hermesScore > 70 {
             bullets.append("Hermes (Haber): Haber akışı pozitif ve momentumu destekliyor.")
        } else if decision.hermesScore < 30 {
             bullets.append("Hermes (Haber): Negatif haber akışı baskı yaratıyor.")
        } else {
             // Default Risk Note
             bullets.append("Genel Risk: Konsey kararı '\(decision.finalActionCore.rawValue)' yönünde.")
        }
        
        // 3. Construct Summary
        // "Argus analizi [Symbol] için [Grade] notu verdi. [Orion] ve [Atlas] görünümü hakim."
        let summary = "Argus sistemi \(decision.symbol) için \(grade) notunu verdi. Teknik tarafta \(orionDesc.lowercased()) bir yapı varken, temel veriler \(atlasDesc.lowercased()) bir tablo çiziyor."
        
        // 4. Handle "Error" Reason (If passed) - Append to title but keep data valid
        if let err = reason {
            // We don't change the title to "Error", we just log it or append subtle note
            print("⚠️ Argus Explanation fell back to deterministic due to: \(err)")
        }
        
        return ArgusExplanation(
            title: title,
            summary: summary,
            bullets: bullets,
            riskNote: decision.aetherScore < 50 ? "Makro piyasa koşulları dikkat gerektiriyor." : nil,
            toneTag: toneTag,
            createdAt: Date(),
            isOffline: true
        )
    }
    
    // Helper for score descriptions
    private func describeScore(_ score: Double, type: String) -> String {
        if score >= 85 { return "Mükemmel" }
        if score >= 70 { return "Güçlü" }
        if score >= 50 { return "Makul/Nötr" }
        if score >= 30 { return "Zayıf" }
        return "Kritik Seviyede Kötü"
    }
    
    private func buildPrompt(for decision: ArgusDecisionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let decisionData = try encoder.encode(decision)
        let decisionString = String(data: decisionData, encoding: .utf8) ?? "{}"
        
        return """
        SEN 'ARGUS'SUN. Bu algoritmik ticaret sisteminin YÖNETİCİ ZEKASISIN.
        GÖREVİN: Aşağıdaki 'Karar JSON' verisini analiz ederek kullanıcıya YATIRIMCI GÖZÜYLE NET, PROFESYONEL VE ETKİLEYİCİ bir açıklama yapmak.
        
        KURALLAR:
        1. Asla JSON yapısından bahsetme. Doğrudan analiz yap.
        2. ToneTag 'balanced' ise objektif, 'bullish' ise heyecanlı, 'bearish' ise uyarıcı ol.
        3. En fazla 3 madde işareti (bullet) kullan.
        4. Summary kısmı 2 cümleyi geçmesin.
        5. Eğer Orion (Teknik) veya Atlas (Temel) skorları zayıfsa bunu belirt.
        
        ÇIKTI FORMATI (JSON):
        {
          "title": "Kısa Çarpıcı Başlık",
          "summary": "2-3 cümlelik özet.",
          "bullets": ["Madde 1", "Madde 2", "Madde 3"],
          "riskNote": "Varsa risk uyarısı yoksa null",
          "toneTag": "balanced"
        }
        
        VERİLER:
        \(decisionString)
        """
    }
    
    private func persistCache() {
        let snapshot = self.cache
        Task {
            await ArgusDataStore.shared.save(snapshot, key: "argus_explanation_cache")
        }
    }
}
