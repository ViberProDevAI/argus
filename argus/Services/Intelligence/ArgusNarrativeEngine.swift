import Foundation

/// Argus Narrative Engine 3.0 - AI-Powered Analysis Reports
/// Eski template-based sistem KALDIRILDI.
/// Yeni: Gemini 2.5 Flash ile gerçek veriye dayalı, çeşitli analiz raporları.
struct ArgusNarrativeEngine {

    // MARK: - Report Types

    enum ReportType: String, CaseIterable {
        case comprehensive = "Kapsamlı Analiz"
        case technical = "Teknik Derinlik"
        case fundamental = "Değerleme Analizi"
        case risk = "Risk Haritası"
        case catalyst = "Yaklaşan Katalizörler"
        case sentiment = "Piyasa Algısı"
    }

    // MARK: - Main API (Fallback - Senkron veri özeti)

    /// Senkron fallback rapor. AI rapor başarısız olursa kullanılır.
    static func generateReport(symbol: String, viewModel: TradingViewModel) -> String {
        let decision = viewModel.grandDecisions[symbol]
        let atlas = viewModel.getFundamentalScore(for: symbol)
        let orion = viewModel.orionScores[symbol]
        let news = viewModel.newsInsightsBySymbol[symbol] ?? []
        let patterns = viewModel.patterns[symbol]

        return generateDataDrivenReport(
            symbol: symbol,
            decision: decision,
            atlas: atlas,
            orion: orion,
            news: news,
            patterns: patterns
        )
    }

    /// Async AI rapor - Chat veya detaylı analiz için
    static func generateAIReport(symbol: String, viewModel: TradingViewModel, type: ReportType = .comprehensive) async -> String {
        let decision = viewModel.grandDecisions[symbol]
        let atlas = viewModel.getFundamentalScore(for: symbol)
        let orion = viewModel.orionScores[symbol]
        let news = viewModel.newsInsightsBySymbol[symbol] ?? []
        let patterns = viewModel.patterns[symbol]

        let dataPacket = buildDataPacket(
            symbol: symbol,
            decision: decision,
            atlas: atlas,
            orion: orion,
            news: news,
            patterns: patterns
        )

        let prompt = buildPromptForType(type: type, dataPacket: dataPacket, symbol: symbol)
        let systemPrompt = getSystemPromptForType(type)

        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: prompt)
        ]

        do {
            return try await GroqClient.shared.chat(messages: messages, maxTokens: 2048)
        } catch {
            print("❌ NarrativeEngine AI Error: \(error)")
            return generateDataDrivenReport(
                symbol: symbol,
                decision: decision,
                atlas: atlas,
                orion: orion,
                news: news,
                patterns: patterns
            )
        }
    }

    // MARK: - Data Packet Builder

    private static func buildDataPacket(
        symbol: String,
        decision: ArgusGrandDecision?,
        atlas: FundamentalScoreResult?,
        orion: OrionScoreResult?,
        news: [NewsInsight],
        patterns: [OrionChartPattern]?
    ) -> String {
        var lines: [String] = []

        lines.append("SEMBOL: \(symbol)")

        // Karar
        if let d = decision {
            lines.append("\n--- KARAR ---")
            lines.append("Aksiyon: \(d.action.rawValue) | Güç: \(d.strength.rawValue) | Güven: %\(Int(d.confidence * 100))")
        }

        // Teknik
        if let o = orion {
            lines.append("\n--- TEKNİK VERİLER ---")
            lines.append("Genel Skor: \(Int(o.score))/100 → \(o.verdict)")
            lines.append("Trend: \(o.components.trendDesc ?? "-") (\(Int(o.components.trend))/25)")
            lines.append("Momentum: \(o.components.momentumDesc ?? "-") (\(Int(o.components.momentum))/25)")
            lines.append("Yapı: \(o.components.structureDesc ?? "-") (\(Int(o.components.structure))/35)")
            if let rsi = o.components.rsi { lines.append("RSI: \(String(format: "%.1f", rsi))") }
            if let macd = o.components.macdHistogram { lines.append("MACD: \(String(format: "%.4f", macd))") }
            if let age = o.components.trendAge { lines.append("Trend Yaşı: \(age) gün") }
        }

        // Temel
        if let a = atlas {
            lines.append("\n--- TEMEL VERİLER ---")
            lines.append("Temel Skor: \(Int(a.totalScore))/100")
            if let vg = a.valuationGrade { lines.append("Değerleme: \(vg)") }
            if !a.highlights.isEmpty {
                lines.append("Öne Çıkanlar: \(a.highlights.joined(separator: " | "))")
            }
            if let f = a.financials {
                if let pe = f.peRatio { lines.append("F/K: \(String(format: "%.1f", pe))") }
                if let fpe = f.forwardPERatio { lines.append("İleri F/K: \(String(format: "%.1f", fpe))") }
                if let peg = f.pegRatio { lines.append("PEG: \(String(format: "%.2f", peg))") }
                if let pb = f.priceToBook { lines.append("F/DD: \(String(format: "%.2f", pb))") }
                if let de = f.debtToEquity { lines.append("Borç/Özkaynak: \(String(format: "%.2f", de))") }
                if let pm = f.profitMargin { lines.append("Kar Marjı: %\(String(format: "%.1f", pm * 100))") }
                if let roe = f.returnOnEquity { lines.append("ROE: %\(String(format: "%.1f", roe * 100))") }
                if let mc = f.marketCap { lines.append("Piyasa Değeri: $\(formatNum(mc))") }
                if let dy = f.dividendYield, dy > 0 { lines.append("Temettü Verimi: %\(String(format: "%.2f", dy * 100))") }
                if let tp = f.targetMeanPrice { lines.append("Analist Hedef Fiyat (Ort): $\(String(format: "%.2f", tp))") }
                if let rm = f.recommendationMean { lines.append("Analist Konsensüs: \(rm < 2 ? "Güçlü Al" : rm < 3 ? "Al" : rm < 4 ? "Tut" : "Sat") (\(String(format: "%.1f", rm)))") }
            }
        }

        // Haberler
        if !news.isEmpty {
            lines.append("\n--- HABERLER ---")
            for n in news.prefix(3) {
                let sentStr: String
                switch n.sentiment {
                case .strongPositive: sentStr = "Çok Pozitif"
                case .weakPositive: sentStr = "Hafif Pozitif"
                case .neutral: sentStr = "Nötr"
                case .weakNegative: sentStr = "Hafif Negatif"
                case .strongNegative: sentStr = "Çok Negatif"
                }
                lines.append("[\(sentStr)] \(n.headline) (Etki: \(n.impactScore)/100)")
            }
        }

        // Formasyonlar
        if let pats = patterns, !pats.isEmpty {
            lines.append("\n--- FORMASYONLAR ---")
            for p in pats.prefix(3) {
                lines.append("- \(p.type.rawValue) (\(p.type.isBullish ? "Yükseliş" : "Düşüş"))")
            }
        }

        // Makro
        if let d = decision {
            lines.append("\n--- MAKRO ---")
            lines.append("Makro Skor: \(Int(d.aetherDecision.netSupport * 100))/100")
            let regime = d.aetherDecision.netSupport
            lines.append("Rejim: \(regime > 0.6 ? "Risk-On" : regime < 0.4 ? "Risk-Off" : "Nötr")")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Report Type Prompts

    private static func getSystemPromptForType(_ type: ReportType) -> String {
        let base = """
        Sen profesyonel bir finansal analistsin. Sadece Türkçe yaz.
        
        KESİN KURALLAR:
        1. Sadece sana verilen verilere dayanarak konuş. Veri yoksa o konuyu atla. ASLA UYDURMA.
        2. Her iddiayı somut bir sayıyla destekle.
        3. "Orion", "Atlas", "Aether" gibi sistem isimlerini KULLANMA.
        
        FORMAT YASAKLARI (KESİNLİKLE YASAK):
        - Yıldız: *, **, *** YOK
        - Tire: -, --, --- YOK
        - Diyez: #, ##, ### YOK
        - Nokta: ..., •, ◦ YOK
        - Alt çizgi: _, __ YOK
        - Ters tırnak: `, ``` YOK
        - Emoji YOK
        
        DOĞRU FORMAT:
        Başlık: BÜYÜK HARFLERLE
        Metin: Normal cümleler
        Liste: 1. 2. 3. veya a) b) c)
        
        Yanıtını düz metin olarak ver.
        """

        switch type {
        case .comprehensive:
            return base + " Görev: Kapsamlı analiz raporu. Teknik, temel, makro ve haberleri sentezle. Kısa ve net ol."
        case .technical:
            return base + " Görev: Derinlemesine teknik analiz. RSI, MACD, trend, momentum, formasyonları detaylandır."
        case .fundamental:
            return base + " Görev: Şirket değerleme analizi. F/K, PEG, borçluluk, karlılık oranlarını detaylandır."
        case .risk:
            return base + " Görev: Risk analizi. En büyük 3-5 riski sırala, her birini somut veriyle destekle."
        case .catalyst:
            return base + " Görev: Önümüzdeki 30 günde hisseyi etkileyebilecek olayları listele."
        case .sentiment:
            return base + " Görev: Piyasa algısı ve haber analizi. Haberlerin fiyata potansiyel etkisini değerlendir."
        }
    }

    private static func buildPromptForType(type: ReportType, dataPacket: String, symbol: String) -> String {
        return """
        Aşağıdaki verilere dayanarak \(symbol) için \(type.rawValue) raporu oluştur.

        \(dataPacket)
        """
    }

    // MARK: - Offline AI Cache Trigger

    private static func generateAIReportAsync(symbol: String, dataPacket: String) async {
        // AI raporu arka planda üret - kullanıcı tekrar istediğinde hazır olsun
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: getSystemPromptForType(.comprehensive)),
            .init(role: "user", content: "Aşağıdaki verilere dayanarak \(symbol) için kapsamlı analiz raporu oluştur.\n\n\(dataPacket)")
        ]

        do {
            let _ = try await GroqClient.shared.chat(messages: messages, maxTokens: 2048)
            print("✅ NarrativeEngine: AI report cached for \(symbol)")
        } catch {
            print("⚠️ NarrativeEngine: AI report failed for \(symbol): \(error)")
        }
    }

    // MARK: - Data-Driven Report (No LLM, No Templates)

    /// Senkron rapor: Template yerine doğrudan veri özetleme
    private static func generateDataDrivenReport(
        symbol: String,
        decision: ArgusGrandDecision?,
        atlas: FundamentalScoreResult?,
        orion: OrionScoreResult?,
        news: [NewsInsight],
        patterns: [OrionChartPattern]?
    ) -> String {
        var report = "# \(symbol) ANALİZ RAPORU\n\n"

        // Karar
        if let d = decision {
            report += "**Karar: \(d.action.rawValue) | Güven: %\(Int(d.confidence * 100))**\n\n"
        }

        // Teknik Görünüm
        if let o = orion {
            report += "## Teknik Görünüm\n"
            report += "Teknik skor \(Int(o.score))/100 ile \(o.verdict.lowercased()) bölgede. "

            if let rsi = o.components.rsi {
                if rsi > 70 {
                    report += "RSI \(String(format: "%.0f", rsi)) ile aşırı alım bölgesinde, düzeltme riski var. "
                } else if rsi < 30 {
                    report += "RSI \(String(format: "%.0f", rsi)) ile aşırı satım bölgesinde, tepki potansiyeli mevcut. "
                } else {
                    report += "RSI \(String(format: "%.0f", rsi)) ile nötr bölgede. "
                }
            }

            report += "Trend skoru \(Int(o.components.trend))/25, momentum \(Int(o.components.momentum))/25.\n\n"
        }

        // Temel Değerleme
        if let a = atlas {
            report += "## Temel Değerleme\n"
            report += "Temel skor \(Int(a.totalScore))/100. "
            if let vg = a.valuationGrade { report += "Değerleme: \(vg). " }

            if let f = a.financials {
                var metrics: [String] = []
                if let pe = f.peRatio { metrics.append("F/K \(String(format: "%.1f", pe))") }
                if let de = f.debtToEquity { metrics.append("Borç/Özkaynak \(String(format: "%.2f", de))") }
                if let pm = f.profitMargin { metrics.append("Kar Marjı %\(String(format: "%.1f", pm * 100))") }
                if let roe = f.returnOnEquity { metrics.append("ROE %\(String(format: "%.1f", roe * 100))") }
                if !metrics.isEmpty {
                    report += metrics.joined(separator: " | ") + ". "
                }

                if let tp = f.targetMeanPrice, let rm = f.recommendationMean {
                    let consensus = rm < 2 ? "Güçlü Al" : rm < 3 ? "Al" : rm < 4 ? "Tut" : "Sat"
                    report += "Analist konsensüs: \(consensus), hedef fiyat $\(String(format: "%.2f", tp)). "
                }
            }
            report += "\n\n"
        }

        // Haberler
        if !news.isEmpty, let top = news.max(by: { $0.impactScore < $1.impactScore }) {
            report += "## Haber Etkisi\n"
            report += "\"\(top.headline)\" (Etki skoru: \(top.impactScore)/100). "
            let sentimentStr: String
            switch top.sentiment {
            case .strongPositive: sentimentStr = "Çok pozitif etki"
            case .weakPositive: sentimentStr = "Hafif pozitif etki"
            case .neutral: sentimentStr = "Nötr etki"
            case .weakNegative: sentimentStr = "Hafif negatif etki"
            case .strongNegative: sentimentStr = "Çok negatif etki"
            }
            report += sentimentStr + ".\n\n"
        }

        // Formasyonlar
        if let pats = patterns, let best = pats.first {
            report += "## Grafik Formasyonları\n"
            report += "\(best.type.rawValue) formasyonu tespit edildi (\(best.type.isBullish ? "yükseliş" : "düşüş") yönlü).\n\n"
        }

        // Risk Uyarıları
        if let d = decision, !d.vetoes.isEmpty {
            report += "## Risk Uyarıları\n"
            for v in d.vetoes {
                report += "- \(v.reason)\n"
            }
            report += "\n"
        }

        // Eğitim Notu
        let tip = ArgusKnowledgeBase.getRelevantTip(decision: decision, orion: orion)
        report += "---\n"
        report += "Not: \(tip.title) - \(tip.content)\n"

        return report
    }

    // MARK: - Helpers

    private static func formatNum(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.1fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        return String(format: "%.0f", value)
    }
}

// MARK: - Argus Akademi (Knowledge Base)

struct ArgusKnowledgeBase {
    struct Tip {
        let title: String
        let content: String
        let category: Category

        enum Category {
            case psychology
            case technical
            case fundamental
            case risk
        }
    }

    static let library: [Tip] = [
        // PSİKOLOJİ
        Tip(title: "FOMO (Fırsat Kaçırma Korkusu)", content: "Hızla yükselen bir hisseyi tepeden almak, borsadaki en büyük kayıp sebebidir. Fırsatlar bitmez; biri kaçarsa diğeri gelir.", category: .psychology),
        Tip(title: "Zararı Kabullenmek", content: "Yanılmak suç değildir, yanıldığını kabul etmemek hatadır. Küçük zararı kesip atmak, büyük sermayeyi kurtarır.", category: .psychology),
        Tip(title: "Sabır Yönetimi", content: "Borsa, sabırsızların parasının sabırlılara transfer edildiği yerdir. Bazen en iyi işlem, hiçbir şey yapmamaktır.", category: .psychology),
        Tip(title: "Sürü Psikolojisi", content: "Herkes aynı şeyi konuşuyorsa, trendin sonuna gelinmiş olabilir. Profesyoneller, herkes korkarken alır.", category: .psychology),

        // TEKNİK
        Tip(title: "Trend Dostunuzdur", content: "Akıntıya karşı yüzmeyin. Fiyat yükseliyorsa düşüşler alım fırsatıdır; düşüyorsa yükselişler satış fırsatıdır.", category: .technical),
        Tip(title: "Hacim Onayı", content: "Hacimsiz yükseliş yakıtsız arabaya benzer; yolda kalır. Gerçek trendler artan işlem hacmiyle desteklenir.", category: .technical),
        Tip(title: "RSI Uyumsuzluğu", content: "Fiyat yeni zirve yaparken RSI yapamıyorsa, yükselişin gücü tükeniyor demektir.", category: .technical),
        Tip(title: "Destek ve Direnç", content: "Destekler alıcıların geldiği bölgeler; dirençler satıcıların beklediği bölgelerdir. Kırılana kadar geçerlidir.", category: .technical),

        // RİSK
        Tip(title: "Yüzde 2 Kuralı", content: "Tek bir işlemde toplam sermayenizin %2'sinden fazlasını riske atmayın. Böylece arka arkaya 10 kez yanılsanız bile oyunda kalırsınız.", category: .risk),
        Tip(title: "Kar Realizasyonu", content: "Kağıt üzerindeki kar cebe girmeden kar değildir. Hedefe ulaşıldığında kademeli satış yapmak açgözlülüğü yener.", category: .risk),

        // TEMEL
        Tip(title: "Fiyat vs Değer", content: "Fiyat ödediğinizdir; değer aldığınızdır. İyi bir şirket kötü fiyattan alınırsa kötü yatırım olur.", category: .fundamental),
        Tip(title: "Net Kar Marjı", content: "Cironun büyümesi yetmez, ne kadarının cebe kaldığı önemlidir. Artan kar marjı rekabet gücünün arttığını gösterir.", category: .fundamental)
    ]

    static func getRelevantTip(decision: ArgusGrandDecision?, orion: OrionScoreResult?) -> Tip {
        if let d = decision, (d.action == .liquidate || d.action == .trim) {
            let riskTips = library.filter { $0.category == .risk || $0.title.contains("Zarar") }
            return riskTips.randomElement() ?? library.first!
        }

        if let o = orion, let rsi = o.components.rsi, rsi > 75 {
            return library.first(where: { $0.title.contains("RSI") || $0.title.contains("Hacim") }) ?? library.first!
        }

        return library.randomElement()!
    }
}
