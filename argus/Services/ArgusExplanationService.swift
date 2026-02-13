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
        
        // System Prompt (V5 - Clean Output)
        let systemPrompt = """
        Sen Argus, profesyonel bir finansal analist ve portföy danışmanısın.

        KESİN KURALLAR:
        1. SADECE TÜRKÇE KONUŞ.
        2. "Orion", "Atlas", "Aether", "Hermes" gibi iç sistem isimlerini KULLANMA.
        3. Her iddiayı somut bir sayıyla destekle. "Güçlü görünüyor" değil, "F/K 12 ile sektör ortalaması 22'nin çok altında" de.
        4. Kısa ve net cevaplar ver. Her cevap 3-5 cümle.
        5. Sana verilen analiz verilerini referans al ama robotik sıralama yapma, doğal bir dille sentezle.
        6. Bilmediğin şeyi UYDURMA. "Bu konuda elimde veri yok" de.
        7. Kullanıcı karşılaştırma isterse, her iki hisseyi de somut metriklerle kıyasla.
        8. Kullanıcı risk soruyorsa en büyük 2-3 riski somut veriyle destekle.
        9. Spekülatif cümlelerden kaçın. Verinin ne söylediğini aktar.

        FORMAT YASAKLARI (KESİNLİKLE YASAK):
        - Yıldız: *, **, *** YOK
        - Tire: -, --, --- YOK
        - Diyez: #, ##, ### YOK
        - Nokta: ..., •, ◦ YOK
        - Alt çizgi: _, __ YOK
        - Ters tırnak: `, ``` YOK
        - Emoji YOK
        
        Yanıtını düz metin olarak ver. Hiçbir formatlama karakteri kullanma.
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
        Aşağıdaki analiz verisini değerlendir ve Türkçe, profesyonel bir özet oluştur.

        KURALLAR:
        1. JSON yapısından veya iç modül isimlerinden (Orion, Atlas, Aether, Hermes) bahsetme.
        2. Her iddiayı somut bir sayıyla destekle (F/K, RSI, skor gibi).
        3. "title" kısa ve çarpıcı olsun (5-8 kelime).
        4. "summary" 2 cümleyi geçmesin, veriye dayalı olsun.
        5. "bullets" en fazla 3 madde, her biri somut veri içersin.
        6. Teknik ve temel çelişiyorsa bunu belirt.
        7. Veri yoksa o konuyu atla, UYDURMA.

        ÇIKTI FORMATI (JSON):
        {
          "title": "Kısa Çarpıcı Başlık",
          "summary": "Veriye dayalı 2 cümle özet.",
          "bullets": ["Somut veri içeren madde 1", "Somut veri içeren madde 2", "Risk veya fırsat"],
          "riskNote": "Varsa en büyük risk, yoksa null",
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
