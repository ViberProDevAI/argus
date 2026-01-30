import Foundation

// MARK: - Argus Voice Service (Reporting Layer)

/// The Voice of Argus (Omniscient).
/// Generates human-readable explanations using Gemini (LLM).
/// Now fully aware of Demeter (Sectors), Aether (Macro), and Chiron (Risk).
actor ArgusVoiceService {
    static let shared = ArgusVoiceService()
    
    private init() {}
    
    // MARK: - System Prompt
    
    // MARK: - Updated Context (V3)
    struct ArgusContext: Codable {
        let symbol: String
        let price: Double?
        let decision: ArgusGrandDecision? // NEW: Direct access to V3 Decision
        let demeter: DemeterScore? // Changed from DemeterSummary to DemeterScore
        let userQuery: String?
    }
    
    // MARK: - System Prompt (V3 - Reform)
    
    private let systemPrompt = """
    Sen "Argus", süper-zeki bir algoritmik trading ekosisteminin "Baş Analisti"sin.
    
    ### GÖREV
    Kullanıcıya yapılan işlemin **TÜM KARAR SÜRECİNİ (Journey)** detaylandır. Bu rapor "Argus Grand Council" (Büyük Konsey) kararlarını temel alır.
    
    ### KONSEY ÜYELERİ VE ROLLERİ:
    1. **ORION (Teknik Lider):** Trend, momentum ve fiyat hareketlerini analiz eder. Phoenix (Destek/Direnç) artık Orion'un bir alt birimidir.
    2. **ATLAS (Temel Lider):** Şirketin finansal sağlığını, büyümesini ve değerlemesini inceler.
    3. **AETHER (Makro Vizyoner):** Küresel piyasa rejimitini (Risk-On/Risk-Off) ve dış faktörleri değerlendirir.
    4. **HERMES (Haberci):** Son dakika haberlerini ve sentiment (duygu) analizini yapar.
    5. **CHIRON (Risk Bekçisi):** Risk/Ödül dengesini ve zamanlamayı kontrol eder.
    
    ### KURALLAR
    1. **HİKAYELEŞTİR:** "Orion al dedi, Atlas sattı" deme. "Orion teknik fırsatı gördü ancak Atlas temel verilerin bu yükselişi desteklemediğini savundu..." gibi bağlam kur.
    2. **HERMES ENTEGRASYONU:** Eğer Hermes verisi varsa mutlaka haberlerin etkisinden bahset. Yoksa bahsetme.
    3. **KANIT ODAKLI KONUŞ:** "Orion al dedi" YETERSİZ. "Orion, RSI 30 seviyesinden dönüş ve Trend Gücü 18/25 olduğu için alım önerdi" ŞEKLİNDE KONUŞ.
    4. **ATLAS DETAYLARI:** "Temeli sağlam" deme. "F/K 5.4 ile sektör ortalamasının altında ve %40 büyüme var" de.
    5. **TÜRKÇE:** Sadece Türkçe kullan. Profesyonel, analitik ama akıcı bir dille yaz. Borsa İstanbul jargonuna hakim ol.
    
    ### KULLANILACAK VERİLER (Eğer Context'te Varsa):
    *   **Orion (Teknik):** RSI, Trend Score, Momentum Score, Structure Score.
    *   **Atlas (Temel):** F/K (PE), Peg Ratio, Büyüme (Growth), Borçluluk (Debt/Equity).
    *   **Hermes (Haber):** Sentiment ve Özet.
    *   **Aether (Makro):** Rejim (Risk-On/Off).
    
    ### İSTENEN ÇIKTI FORMATI:
    
    **🏛️ KARAR MİMARİSİ:**
    *   **Konsey Kararı:** [KARAR] (Güven: %[GÜVEN])
    *   **Lider Gerekçe:** [Decision Reasoning]
    *   **Konsey Oyları:**
        [Burada dinamik olarak oy veren modülleri listele. Örn: 🔵 Orion: AL, 🔴 Aether: SAT]
    
    **📜 GEREKÇE (HİKAYE):**
    [Buraya detaylı bir paragraf yaz. Modüllerin tartışmasını özetle. Veto varsa neden veto edildiğini açıkla. Hermes'in getirdiği haberlerin etkisini vurgula.]
    
    **⚠️ RİSK VE STRATEJİ:**
    *   **Risk Notu:** [Risk analizi]
    *   **Phoenix Seviyeleri:** [Eğer data varsa destek/direnç belirt]
    """
    
    // MARK: - Public API
    
    /// Generates a generic report/answer based on the full Omniscient Context.
    func askArgus(question: String, context: ArgusContext) async -> String {
        do {
            let jsonString = try await encodeContext(context)
            
            let fullPrompt = """
            ### DURUM RAPORU (CONTEXT):
            \(jsonString)
            
            ### KULLANICI SORUSU:
            "\(question)"
            """
            
            let messages: [GroqClient.ChatMessage] = [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: fullPrompt)
            ]
            
            let rawResponse = try await GroqClient.shared.chat(messages: messages)
            
            // SPK Compliance
            let isRisky = context.symbol.lowercased().contains("btc") || context.symbol.lowercased().contains("eth")
            return SPKRegulatoryEngine.shared.ensureCompliance(content: rawResponse, isHighRisk: isRisky)
        } catch {
            print("❌ Argus Voice Error: \(error)")
            // Fallback to Deterministic Report
            return generateOfflineReport(context: context)
        }
    }
    
    /// Deterministic Report Generator (Offline / No-LLM)
    private func generateOfflineReport(context: ArgusContext) -> String {
        guard let d = context.decision else { return "Veri yetersiz." }
        let decision = d.action.rawValue
        let score = Int(d.confidence * 100)
        
        var text = ""
        
        // Orion
        let orion = Int(d.orionDetails?.score ?? d.orionDecision.netSupport * 100)
        let orionScoreRaw = d.orionDetails?.score ?? d.orionDecision.netSupport
        text += "Teknik tarafta Orion, \(orion) puan ile \(describeScore(orionScoreRaw)) bir görünüm sunuyor. "
        
        // Atlas
        let atlas = Int(d.atlasDecision?.netSupport ?? 0 * 100)
        text += "Temel veriler açısından Atlas, \(atlas) puan verdi. "
        
        // Aether
        let aether = Int(d.aetherDecision.netSupport * 100)
        if aether < 50 {
            text += "Ancak Aether, makro piyasa koşullarının riskli olduğu konusunda uyarıyor (Puan: \(aether)). "
        } else {
            text += "Makro piyasa koşulları ise destekleyici (Puan: \(aether)). "
        }
        
        text += "Sonuç olarak, mevcut veriler ışığında \(decision) yönünde hareket etmeniz önerilir."
        
        return SPKRegulatoryEngine.shared.ensureCompliance(content: text, isHighRisk: false)
    }
    
    private func describeScore(_ score: Double) -> String {
        if score >= 70 { return "güçlü" }
        if score >= 50 { return "dengeli" }
        if score >= 30 { return "zayıf" }
        return "negatif"
    }
    
    /// Generates a specific insight for a Demeter Sector Score.
    func generateDemeterInsight(score: DemeterScore) async -> String {
        let taskPrompt = """
        GÖREV: Aşağıdaki Demeter Sektör Puanı verisini analiz et ve 2-3 cümlelik net bir "Sektör Görünümü" yaz.
        Şokların etkisini ve momentuma olan desteği/kösteği vurgula.
        
        VERİ:
        Sektör: \(score.sector.rawValue) (\(score.sector.name))
        Toplam Puan: \(Int(score.totalScore))/100 (Grade: \(score.grade))
        Momentum: \(Int(score.momentumScore))
        Şok Etkisi: \(Int(score.shockImpactScore)) (Düşükse şok var demektir)
        Rejim: \(Int(score.regimeScore))
        Aktif Şoklar: \(score.activeShocks.map{"\($0.type.displayName) (\($0.direction.symbol))"}.joined(separator: ", "))
        
        Çıktı sadece analiz metni olsun.
        """
        
        
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: taskPrompt)
        ]
        
        do {
            print("🎙️ Argus Voice (Gemini): Generating Demeter Insight for \(score.sector.rawValue)...")
            // Use Gemini for Sector Insights (Load Balancing)
            let result = try await GeminiClient.shared.generateContent(prompt: taskPrompt)
            print("✅ Argus Voice: Insight Generated. Length: \(result.count)")
            return result
        } catch {
            print("❌ Argus Voice Error (Demeter/Gemini): \(error)")
            // Fallback to Grok if Gemini fails
            do {
                 print("⚠️ Gemini Failed. Falling back to Grok...")
                 return try await GroqClient.shared.chat(messages: messages)
            } catch {
                return "Analiz oluşturulamadı: \(error.localizedDescription)"
            }
        }
    }
    
    /// Generates a report from the V3 Grand Decision.
    /// This is the main method for "Argus Sesli Notu".
    func generateReport(decision: ArgusGrandDecision) async -> String {
        let context = ArgusContext(
            symbol: decision.symbol,
            price: nil, // Can be added if needed, but decision has context
            decision: decision,
            demeter: nil, // Demeter is inside decision advisors if needed
            userQuery: "Bu işlem için detaylı 'Karar Mimarisi' ve 'Hikaye' raporunu oluştur."
        )
        
        return await askArgus(question: context.userQuery!, context: context)
    }
    
    /// Overload for legacy calls or specific needs (Deprecated eventually)
    func generateReport(from snapshot: DecisionSnapshot) async -> String {
        // Fallback or map snapshot to simple context
         return "⚠️ Rapor oluşturulamadı: Lütfen ArgusGrandDecision kullanın."
    }

    // MARK: - Helpers
    
    private func encodeContext(_ context: ArgusContext) async throws -> String {
        return await MainActor.run {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(context) else { return "{}" }
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }
}
