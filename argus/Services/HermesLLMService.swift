import Foundation

/// Handles interaction with AI (Groq/LLaMA 3) for Hermes News Analysis
/// Migrated from Gemini to Groq for centralized reliability.
final class HermesLLMService: Sendable {
    static let shared = HermesLLMService()
    
    // Cache: Article ID -> Summary
    private var cache: [String: HermesSummary] = [:]
    private let eventStore = HermesEventStore.shared
    
    private init() {
        // Load cache
        Task {
            if let loaded: [String: HermesSummary] = await ArgusDataStore.shared.load(key: "argus_hermes_cache") {
                self.cache = loaded
                print("🧠 Hermes: Loaded \(loaded.count) items from disk cache.")
            }
        }
    }

    // MARK: - Hermes V3: Event Extraction
    
    private func applyKulisAdjustments(
        scope: HermesEventScope,
        article: NewsArticle,
        eventType: HermesEventType,
        flags: [HermesRiskFlag],
        severity: Double,
        confidence: Double
    ) -> (severity: Double, confidence: Double, flags: [HermesRiskFlag], extraMultiplier: Double) {
        guard scope == .bist else {
            return (severity, confidence, flags, 1.0)
        }
        
        let text = (article.headline + " " + (article.summary ?? "")).lowercased()
        var adjustedSeverity = severity
        var adjustedConfidence = confidence
        var flagSet = Set(flags)
        var extraMultiplier = 1.0
        
        let isRumor = HermesLLMService.kulisRumorKeywords.contains { text.contains($0) }
        let isOfficial = HermesLLMService.kulisOfficialKeywords.contains { text.contains($0) }
            || HermesLLMService.kulisOfficialKeywords.contains { article.source.lowercased().contains($0) }
        let typeMultiplier = HermesLLMService.kulisEventTypeMultipliers[eventType] ?? 1.0
        extraMultiplier *= typeMultiplier
        
        if isRumor {
            flagSet.insert(.rumor)
            adjustedConfidence = max(0.1, adjustedConfidence * 0.7)
            adjustedSeverity = max(0.0, adjustedSeverity - 10.0)
            extraMultiplier *= 0.85
        }
        
        if isOfficial {
            adjustedConfidence = min(1.0, adjustedConfidence + 0.1)
            adjustedSeverity = min(100.0, adjustedSeverity + 5.0)
            flagSet.remove(.rumor)
            extraMultiplier *= 1.05
        }
        
        if article.sourceReliability < 0.5 {
            flagSet.insert(.lowReliability)
            extraMultiplier *= 0.9
        }
        
        return (
            max(0.0, min(adjustedSeverity, 100.0)),
            max(0.0, min(adjustedConfidence, 1.0)),
            Array(flagSet),
            extraMultiplier
        )
    }
    
    private static let kulisRumorKeywords: [String] = [
        "kulis",
        "iddia",
        "soylenti",
        "dedikodu",
        "fisi",
        "fısılt",
        "iddialara gore",
        "iddialara göre",
        "iddia edildi",
        "iddia ediliyor"
    ]
    
    private static let kulisOfficialKeywords: [String] = [
        "kap",
        "kamuyu aydinlatma",
        "kamu aydinlatma",
        "spk",
        "borsa istanbul",
        "resmi aciklama",
        "resmi açıklama",
        "duyuru",
        "bildirim"
    ]
    
    private static let kulisEventTypeMultipliers: [HermesEventType: Double] = [
        .kapDisclosure: 1.05,
        .bedelliCapitalIncrease: 0.9,
        .bedelsizBonusIssue: 1.05,
        .temettuAnnouncement: 1.0,
        .ihaleKazandi: 1.0,
        .ihaleIptal: 0.95,
        .spkAction: 1.05,
        .ortaklikAnlasmasi: 1.0,
        .borclanmaIhraci: 0.9,
        .karUyarisi: 1.1,
        .kurRiski: 0.95,
        .ihracatSiparisi: 1.0,
        .yatirimPlani: 0.95,
        .tesisAcilisi: 0.95,
        .sektorTesvik: 0.95,
        .davaOlumsuz: 0.95,
        .davaOlumlu: 1.0,
        .yonetimDegisim: 0.95,
        .operasyonelAriza: 0.9
    ]

    func analyzeEvents(articles: [NewsArticle], scope: HermesEventScope, isGeneral: Bool = false) async throws -> [HermesEvent] {
        guard !articles.isEmpty else { return [] }
        
        var results: [HermesEvent] = []
        var articlesToProcess: [NewsArticle] = []
        
        // Cache hit
        for article in articles {
            if let cached = eventStore.getEvent(for: article.id) {
                results.append(cached)
            } else {
                articlesToProcess.append(article)
            }
        }
        
        if articlesToProcess.isEmpty {
            return results
        }
        
        let chunkedArticles = Array(articlesToProcess.prefix(3))
        let promptText = buildEventPrompt(chunkedArticles, scope: scope, isGeneral: isGeneral)
        
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "Sen finansal haberleri etiketleyen bir analiz asistanisin. Sadece verilen JSON semasina uygun cikti uret."),
            .init(role: "user", content: promptText)
        ]
        
        let responseDTO: HermesEventExtractionResponse = try await GroqClient.shared.generateJSON(messages: messages, maxTokens: 1400)
        let analysisDate = Date()
        
        var mappedEvents: [HermesEvent] = []
        for item in responseDTO.results {
            guard let article = chunkedArticles.first(where: { $0.id == item.id }) else { continue }
            let targetSymbol = (isGeneral && !(item.detected_symbol ?? "").isEmpty) ? (item.detected_symbol ?? article.symbol) : article.symbol
            
            let eventType = HermesEventType(rawValue: item.event_type ?? "") ?? .macroShock
            let polarity = HermesEventPolarity(rawValue: item.polarity ?? "") ?? .mixed
            let horizon = HermesEventHorizon(rawValue: item.horizon_hint ?? "") ?? .shortTerm
            let flags = (item.risk_flags ?? []).compactMap { HermesRiskFlag(rawValue: $0) }
            
            let adjustments = applyKulisAdjustments(
                scope: scope,
                article: article,
                eventType: eventType,
                flags: flags,
                severity: item.severity ?? 50.0,
                confidence: item.confidence ?? 0.6
            )
            
            let sourceReliability = article.sourceReliability * 100.0
            let baseScore = HermesEventScoring.score(
                scope: scope,
                eventType: eventType,
                severity: adjustments.severity,
                confidence: adjustments.confidence,
                sourceReliability: sourceReliability,
                horizon: horizon,
                publishedAt: article.publishedAt,
                flags: adjustments.flags,
                analysisDate: analysisDate,
                extraMultiplier: adjustments.extraMultiplier
            )
            let finalScore = await HermesCalibrationService.shared.adjustedScore(
                for: baseScore,
                scope: scope,
                eventType: eventType,
                flags: adjustments.flags
            )
            let ingestDelayMinutes = max(0.0, analysisDate.timeIntervalSince(article.publishedAt) / 60.0)
            
            mappedEvents.append(
                HermesEvent(
                    scope: scope,
                    symbol: targetSymbol,
                    articleId: article.id,
                    headline: article.headline,
                    eventType: eventType,
                    polarity: polarity,
                    severity: adjustments.severity,
                    confidence: adjustments.confidence,
                    sentimentLabel: NewsSentiment(rawValue: item.sentiment_label ?? ""),
                    horizonHint: horizon,
                    rationaleShort: item.rationale_short ?? "Bu haberin piyasa etkisi analiz edildi.",
                    evidenceQuotes: Array((item.evidence_quotes ?? []).prefix(2)),
                    riskFlags: adjustments.flags,
                    sourceName: article.source,
                    sourceReliability: sourceReliability,
                    publishedAt: article.publishedAt,
                    ingestDelayMinutes: ingestDelayMinutes,
                    finalScore: finalScore,
                    articleUrl: article.url
                )
            )
            
            HermesDelayStatsService.shared.record(
                source: article.source,
                delayMinutes: ingestDelayMinutes,
                scope: scope
            )
        }
        
        eventStore.saveEvents(mappedEvents)
        for event in mappedEvents {
            Task.detached { await HermesCalibrationService.shared.enqueue(event: event) }
        }
        results.append(contentsOf: mappedEvents)
        return results
    }
    
    /// Batched Analysis using Groq
    /// - Parameter isGeneral: Global feed için true geçin, sembol tespiti yapılır
    func analyzeBatch(_ articles: [NewsArticle], isGeneral: Bool = false) async throws -> [HermesSummary] {
        if articles.isEmpty { return [] }
        
        var results: [HermesSummary] = []
        var articlesToProcess: [NewsArticle] = []
        
        // 1. Check Cache
        for article in articles {
            if let cached = cache[article.id] {
                // Check if cache entry is fresh (e.g. within 24 hours)? 
                // Currently indefinite cache for immutable news analysis.
                results.append(cached)
            } else {
                articlesToProcess.append(article)
            }
        }
        
        if articlesToProcess.isEmpty {
            return results
        }
        
        print("🧠 Hermes: Processing \(articlesToProcess.count) new articles (Cached: \(results.count))")
        
        // 2. Prepare Prompt for MISSING articles
        // Limit to 3 articles per batch (pagination logic should handle rest)
        let chunkedArticles = Array(articlesToProcess.prefix(3))
        let promptText = buildBatchPrompt(chunkedArticles, isGeneral: isGeneral)
        
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "You are a financial news analyst JSON generator. Always output valid JSON matching the schema."),
            .init(role: "user", content: promptText)
        ]
        
        // 3. Request via GroqClient
        do {
            let responseDTO: HermesBatchResponse = try await GroqClient.shared.generateJSON(
                messages: messages
            )
            
            // 4. Map to Model & Update Cache
            let newSummaries = responseDTO.results.compactMap { (item: HermesBatchItem) -> HermesSummary? in
                let originalArticle = chunkedArticles.first(where: { $0.id == item.id })
                
                let resolvedSymbol: String
                if isGeneral, let detectedSymbol = item.detected_symbol, !detectedSymbol.isEmpty {
                    resolvedSymbol = detectedSymbol
                } else {
                    resolvedSymbol = originalArticle?.symbol ?? "MARKET"
                }
                
                var correctedScore = item.impact_score
                if let sentiment = item.sentiment?.uppercased() {
                    if sentiment == "POSITIVE" && correctedScore < 55 {
                        correctedScore = min(65.0, correctedScore + 10.0)
                    } else if sentiment == "NEGATIVE" && correctedScore > 45 {
                        correctedScore = max(35.0, correctedScore - 10.0)
                    } else if sentiment == "NEUTRAL" && (correctedScore > 55 || correctedScore < 45) {
                        correctedScore = 50.0
                    }
                }
                
                let summary = HermesSummary(
                    id: item.id,
                    symbol: resolvedSymbol,
                    summaryTR: item.summary_tr,
                    impactCommentTR: item.impact_comment_tr,
                    impactScore: Int(correctedScore),
                    relatedSectors: item.related_sectors,
                    rippleEffectScore: Int(item.ripple_effect_score),
                    createdAt: Date(),
                    mode: .full,
                    publishedAt: originalArticle?.publishedAt,
                    sourceReliability: originalArticle?.sourceReliability
                )
                
                // Save to Cache
                self.cache[item.id] = summary
                return summary
            }
            
            self.persistCache()
            
            results.append(contentsOf: newSummaries)
            return results
            
        } catch {
            print("❌ Hermes Analysis Failed: \(error)")
            // Return whatever we have from cache if API fails
            if !results.isEmpty { return results }
            
            let nsError = error as NSError
            if nsError.code == 429 {
                throw HermesError.quotaExhausted
            }
            throw error
        }
    }
    
    // MARK: - Hermes V2: Quick Sentiment (Cache-Based)
    
    /// Gets quick sentiment score for a symbol using cached Hermes analysis
    /// Returns a score from 0-100 (50 = neutral)
    /// - Parameter symbol: Stock symbol (e.g. "AAPL", "THYAO.IS")
    /// - Returns: HermesQuickSentiment with score and news count
    func getQuickSentiment(for symbol: String) async -> HermesQuickSentiment {
        // Get all cached summaries for this symbol
        let symbolSummaries = cache.values.filter { 
            $0.symbol.uppercased() == symbol.uppercased() ||
            $0.symbol.uppercased() == symbol.replacingOccurrences(of: ".IS", with: "").uppercased()
        }
        
        guard !symbolSummaries.isEmpty else {
            // No cached data - return neutral
            return HermesQuickSentiment(
                symbol: symbol,
                score: 50,
                bullishPercent: 50,
                bearishPercent: 50,
                newsCount: 0,
                source: .fallback,
                lastUpdated: Date()
            )
        }
        
        // Calculate average sentiment from cached summaries
        let totalScore = symbolSummaries.reduce(0.0) { $0 + Double($1.impactScore) }
        let avgScore = totalScore / Double(symbolSummaries.count)
        
        // Calculate bullish/bearish percentages
        let positiveCount = symbolSummaries.filter { $0.impactScore >= 55 }.count
        let negativeCount = symbolSummaries.filter { $0.impactScore <= 45 }.count
        let total = symbolSummaries.count
        
        let bullishPercent = Double(positiveCount) / Double(total) * 100
        let bearishPercent = Double(negativeCount) / Double(total) * 100
        
        return HermesQuickSentiment(
            symbol: symbol,
            score: avgScore,
            bullishPercent: bullishPercent,
            bearishPercent: bearishPercent,
            newsCount: symbolSummaries.count,
            source: .llm,
            lastUpdated: symbolSummaries.first?.createdAt ?? Date()
        )
    }
    
    /// Gets recent news summaries for a symbol from cache
    func getCachedSummaries(for symbol: String, count: Int = 5) -> [HermesSummary] {
        let symbolSummaries = cache.values.filter { 
            $0.symbol.uppercased() == symbol.uppercased() ||
            $0.symbol.uppercased() == symbol.replacingOccurrences(of: ".IS", with: "").uppercased()
        }
        .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
        
        return Array(symbolSummaries.prefix(count))
    }
    
    private func persistCache() {
        let snapshot = self.cache
        Task {
            await ArgusDataStore.shared.save(snapshot, key: "argus_hermes_cache")
        }
    }

    func getCachedEvents(for symbol: String) -> [HermesEvent] {
        return eventStore.getEvents(for: symbol)
    }
    
    private func buildBatchPrompt(_ articles: [NewsArticle], isGeneral: Bool = false) -> String {
        var articlesText = ""
        for (index, article) in articles.enumerated() {
            articlesText += """
            [NEWS \(index + 1)]
            ID: \(article.id)
            Symbol: \(article.symbol)
            Headline: \(article.headline)
            Summary: \(article.summary ?? "")
            
            """
        }
        
        // Global feed için ek talimat
        let symbolInstruction = isGeneral ? """
        
        ÖNEMLİ - SEMBOL TESPİTİ:
        Bu haberler genel piyasa haberleri. Her haber için:
        1. Haberde bahsedilen ANA şirketi/ticker'ı tespit et (örn: "Apple" → "AAPL", "Tesla" → "TSLA")
        2. Eğer haber birden fazla şirketi ilgilendiriyorsa, en çok etkilenen şirketi seç
        3. Eğer belirli bir şirket yoksa, sektörü belirle (örn: "Tech", "Energy", "Crypto")
        4. JSON'da "detected_symbol" alanına tespit ettiğin ticker'ı yaz
        
        """ : ""
        
        return """
        Sen Argus Terminal içindeki Hermes v2.3 modülüsün.
        Görevin aşağıdaki haberleri finansal ve BAĞLAMSAL açıdan analiz etmek.
        \(symbolInstruction)
        GİRDİ:
        \(articlesText)
        
        GÖREV:
        Her bir haber için analiz yap ve JSON üret.
        
        PUANLAMA KURALLARI (KESİN UYULMALI):
        - POSITIVE: 65 - 100 arası. (65 = Hafif Olumlu, 100 = Game Changer)
        - NEGATIVE: 0 - 35 arası. (0 = İflas/Kriz, 35 = Hafif Olumsuz)
        - NEUTRAL: 45 - 55 arası. (Piyasayı etkilemez)
        * Asla Sentiment ile Puan çelişmemeli (Örn: Positive deyip 40 verme).
        
        KURALLAR:
        1. summary_tr: Türkçe 1 cümlelik net özet.
        2. impact_comment_tr: "Hisse için [olumlu/olumsuz/nötr] bir gelişme." şeklinde 1 cümlelik yorum.
        3. sentiment: "POSITIVE", "NEGATIVE" veya "NEUTRAL" (BÜYÜK HARF).
        4. impact_score: Yukarıdaki aralıklara göre bir tamsayı.
        5. related_sectors: İngilizce sektör etiketleri (Örn: "Energy", "Tech").
        6. ripple_effect_score: Piyasaya yayılma potansiyeli (0-100).
        7. detected_symbol: Haberin ilgili olduğu ticker (örn: "AAPL", "TSLA"). Belirsizse boş bırak.
        
        ÇIKTI FORMATI (JSON OBJE):
        {
          "results": [
            {
              "id": "Haber ID'si aynen kopyalanmalı",
              "detected_symbol": "AAPL",
              "summary_tr": "...",
              "impact_comment_tr": "...",
              "sentiment": "POSITIVE",
              "impact_score": 75,
              "related_sectors": ["Sector1"],
              "ripple_effect_score": 60
            }
          ]
        }
        """
    }

    private func buildEventPrompt(_ articles: [NewsArticle], scope: HermesEventScope, isGeneral: Bool) -> String {
        var articlesText = ""
        for (index, article) in articles.enumerated() {
            articlesText += """
            [HABER \(index + 1)]
            ID: \(article.id)
            Symbol: \(article.symbol)
            Headline: \(article.headline)
            Summary: \(article.summary ?? "")
            Source: \(article.source)
            PublishedAt: \(article.publishedAt)
            
            """
        }
        
        let eventList = (scope == .bist) ? HermesPromptLexicon.bistEventTypes : HermesPromptLexicon.globalEventTypes
        let eventListText = eventList.joined(separator: ", ")
        
        let symbolInstruction = isGeneral ? """
        
        HABER SEMBOL TESPITI:
        - Haberde en cok etkilenen ana sirketi/ticker'i tespit et.
        - Eger belirgin sirket yoksa "MARKET" yaz.
        
        """ : ""
        
        return """
        Hermes V3 icin haber etiketleme gorevi.
        \(symbolInstruction)
        Kullanilacak event_type listesi:
        \(eventListText)
        
        Beklenen JSON semasi:
        {
          "results": [
            {
              "id": "ARTICLE_ID",
              "detected_symbol": "AAPL",
              "event_type": "earnings_surprise",
              "polarity": "positive|negative|mixed",
              "sentiment_label": "strong_positive|weak_positive|neutral|weak_negative|strong_negative",
              "severity": 0-100,
              "confidence": 0.0-1.0,
              "horizon_hint": "intraday|1-3d|multiweek",
              "rationale_short": "en fazla 200 karakter",
              "evidence_quotes": ["max 160 karakter", "max 160 karakter"],
              "risk_flags": ["rumor","low_reliability","priced_in","regulatory_uncertainty"]
            }
          ]
        }
        
        KURALLAR:
        - sentiment_label, haberi okuyup etkisini yorumlayarak secilmeli.
        - sentiment_label, polarity ve severity ile celismemeli.
        - strong_* sadece gercekten guclu ve beklenmedik etki varsa kullanilmali.
        
        HABERLER:
        \(articlesText)
        """
    }
}

// MARK: - Hermes Prompt Lexicon

private enum HermesPromptLexicon {
    static let globalEventTypes: [String] = [
        "earnings_surprise", "guidance_raise", "guidance_cut", "revenue_miss", "margin_pressure",
        "buyback_announcement", "dividend_change", "m_and_a", "regulatory_action", "legal_risk",
        "product_launch", "supply_chain_disruption", "macro_shock", "rating_upgrade",
        "rating_downgrade", "insider_activity", "sector_rotation", "geopolitical_risk",
        "fraud_allegation", "leadership_change"
    ]
    
    static let bistEventTypes: [String] = [
        "kap_disclosure", "bedelli_capital_increase", "bedelsiz_bonus_issue", "temettu_announcement",
        "ihale_kazandi", "ihale_iptal", "spk_action", "ortaklik_anlasmasi", "borclanma_ihraci",
        "kar_uyarisi", "kur_riski", "ihracat_siparisi", "yatirim_plani", "tesis_acilisi",
        "sektor_tesvik", "dava_olumsuz", "dava_olumlu", "yonetim_degisim", "operasyonel_ariza"
    ]
}

private struct HermesEventExtractionResponse: Codable {
    let results: [HermesEventExtractionItem]
}

private struct HermesEventExtractionItem: Codable {
    let id: String
    let detected_symbol: String?
    let event_type: String?
    let polarity: String?
    let sentiment_label: String?
    let severity: Double?
    let confidence: Double?
    let horizon_hint: String?
    let rationale_short: String?
    let evidence_quotes: [String]?
    let risk_flags: [String]?
}
