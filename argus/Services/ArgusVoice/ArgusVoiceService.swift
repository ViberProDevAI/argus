import Foundation

// MARK: - Argus Voice Service (V4 - Data-Driven Analyst)

/// The Voice of Argus - Gerçek veriye dayalı, sallamayan, profesyonel analist.
/// V4: "Orion dedi, Atlas karşı çıktı" formatı KALDIRILDI.
/// Yerine: Somut sayılar, karşılaştırmalar, risk analizi.
actor ArgusVoiceService {
    static let shared = ArgusVoiceService()

    private init() {}

    // MARK: - Context Model

    struct ArgusContext: Codable {
        let symbol: String
        let price: Double?
        let decision: ArgusGrandDecision?
        let demeter: DemeterScore?
        let userQuery: String?

        // MARK: - Extended App Context (V5)
        var portfolio: PortfolioContext?
        var marketState: MarketContext?
        var watchlist: [String]?
        var recentTrades: [TradeContext]?
        var tradeBrainState: TradeBrainContext?

        // MARK: - V6 (Phase 7+, 2026-04-30): LLM bilgi setini zenginleştirme
        /// Prometheus 5-günlük tahmin sonucu (varsa). LLM'in sayısal projeksiyon
        /// kullanabilmesi için kritik — eskiden hiç gönderilmiyordu.
        var prometheus: PrometheusVoiceSummary?
        /// Chiron piyasa rejimi (trend/chop/risk-off/news-shock/neutral) + açıklama.
        var chironRegime: ChironRegimeSummary?
        /// Risk/volatilite metrikleri — daily candle'lardan türetilir.
        var risk: RiskVoiceSummary?
        /// Sembol metadata: market (US/BIST/Crypto/Forex/Futures), currency.
        var symbolMeta: SymbolMetaSummary?
        /// Veri kalitesi notları: blocklist durumu, son fetch yaşı, kaynak.
        var dataHealth: DataHealthSummary?
    }

    struct PrometheusVoiceSummary: Codable {
        let predictedPrice: Double
        let changePercent: Double
        let trend: String              // "Güçlü Yükseliş", "Yatay", vb.
        let recommendation: String     // "AL" / "BEKLE" / "SAT"
        let confidence: Double         // 0-100
        let confidenceLevel: String    // "Yüksek" / "Orta" / "Düşük" / "Çok Düşük"
        let horizonDays: Int
        let mape: Double               // walk-forward MAPE %
        let directionalAccuracy: Double // 0-1
        let modelVersion: String
        let rationale: [String]        // motor açıklaması (alpha/beta/phi vb)
    }

    struct ChironRegimeSummary: Codable {
        let regime: String             // "Trend", "Chop", "Risk-Off", "News Shock", "Neutral"
        let explanation: String        // ChironResult.explanationBody
    }

    struct RiskVoiceSummary: Codable {
        let dailyVolatilityPct: Double?  // son 20 günün getiri stdDev'i, %
        let weekHigh52: Double?
        let weekLow52: Double?
        let distanceFromHighPct: Double? // current price vs 52w high, %
        let distanceFromLowPct: Double?
        let avgDailyRangePct: Double?    // ATR yaklaşık, %
    }

    struct SymbolMetaSummary: Codable {
        let market: String         // "US", "BIST", "Crypto", "Forex", "Futures"
        let currency: String       // "USD", "TRY", "BTC", vs.
        let currencySymbol: String // "$", "₺", "₿"
    }

    struct DataHealthSummary: Codable {
        let isBlocked: Bool                // sembol kara listede mi
        let blockReason: String?           // "auth/paywall" gibi
        let blockExpiresInHours: Double?
        let quoteAgeSeconds: Double?       // quote cache yaşı
        let candleAgeSeconds: Double?      // daily candle cache yaşı
        let quoteSource: String?           // "Yahoo", "Derived-Candle", vb.
    }
    
    struct PortfolioContext: Codable {
        let totalEquity: Double
        let cashBalance: Double
        let bistBalance: Double
        let openPositionCount: Int
        let totalPnL: Double
        let totalPnLPercent: Double
        let positions: [PositionSummary]
    }
    
    struct PositionSummary: Codable {
        let symbol: String
        let quantity: Double
        let entryPrice: Double
        let currentPrice: Double
        let pnlPercent: Double
        let holdingDays: Int
    }
    
    struct MarketContext: Codable {
        let vix: Double?
        let fearGreedIndex: Int?
        let regime: String?
        let spyChange: Double?
        let marketStatus: String
    }
    
    struct TradeContext: Codable {
        let symbol: String
        let action: String
        let quantity: Double
        let price: Double
        let pnl: Double
        let date: Date
    }
    
    struct TradeBrainContext: Codable {
        let lastScanTime: Date?
        let pendingSignals: Int
        let autopilotEnabled: Bool
        let recentAlerts: [String]
    }

    // MARK: - System Prompt (V6, Phase 7+, 2026-04-30)

    private let systemPrompt = """
    Sen profesyonel bir finansal analistsin. Adın Argus.

    ### KESİN KURALLAR:
    1. SADECE sana verilen VERİ PAKETİ'ndeki sayılara dayanarak konuş. Veri yoksa "Bu bilgi elimde yok" de. ASLA UYDURMA.
    2. Her iddiayı somut bir sayıyla destekle: "Değerleme ucuz" değil, "F/K 8.5 ile sektör ortalaması 18'in çok altında". "Tahmin pozitif" değil, "5 günlük projeksiyon %3.2 yukarı, model güveni %62".
    3. Sistem/modül isimlerini KULLANMA: "Orion", "Atlas", "Aether", "Hermes", "Demeter", "Chiron", "Prometheus" — kullanıcı bunları bilmez. Yerine kavramsal terim kullan: teknik analiz, temel analiz, makro ortam, haber sentiment, sektör momentumu, piyasa rejimi, kısa vadeli projeksiyon.
    4. Kısa ve net. Paragraf 3-4 cümle, toplam yanıt 8-12 cümle.
    5. SADECE TÜRKÇE. Profesyonel, doğrudan, net.
    6. "Olabilir", "belki", "muhtemelen" yerine verinin söylediğini yaz. Belirsizlik varsa belirsizliği SAYI ile söyle: "model güveni düşük (%37)".

    ### VERİ KALİTESİ DUYARLILIĞI:
    - VERİ PAKETİ'nde "VERİ KALİTESİ" bölümünde sembol kara listede ise (paywall): "Bu hisse için Yahoo verisi kısıtlı, son güncel veri X saat önce" diye uyar.
    - Quote/candle yaşı 1 saatten fazla ise: "Veriler X dakika eski" notunu ekle.
    - Veri yoksa SUS, uydurma.

    ### FİYAT FORMATI:
    - Sembol metadata'sından gelen `currencySymbol` kullan ("$", "₺", "₿").
    - BIST sembolleri (.IS) için ₺ kullan. ABD hisseleri için $. Crypto için $.

    ### TEKNİK + TEMEL + TAHMİN ÇELİŞKİSİ:
    Eğer teknik analiz "AL" ama temel "satış baskısı" diyorsa açıkça belirt:
    "Teknik resim güçlü (skor 78/100, RSI 58) ama temellerde zayıflık var (Borç/Özkaynak 2.4 yüksek). Kısa vade pozitif olsa da uzun vadede risk."
    Eğer 5-günlük projeksiyon (Prometheus tahmini) işlem maliyetinin altındaysa "BEKLE" önerisini gerekçelendir.

    ### FORMAT YASAKLARI (KESİNLİKLE YASAK):
    - Yıldız (*, **, ***), tire (-, --, ---), diyez (#, ##, ###), nokta (..., •, ◦), alt çizgi (_, __), ters tırnak (`, ```), emoji.
    Bunlar markdown render'lanmıyor; düz metin gönderilecek.

    ### DOĞRU FORMAT:
    - Başlık: BÜYÜK HARFLERLE YAZ
    - Alt başlık: İlk harfler büyük
    - Liste: 1. 2. 3. veya a) b) c) şeklinde numaralandır
    - Metin: Normal cümleler, düz yazı

    ### ÖNEMLİ:
    - Veri yoksa o bölümü atla.
    - Karar "GÖZLE/BEKLE" ise SOMUT VERİYLE ne beklemek gerektiğini açıkla (örn. "RSI 70'in üstünde, geri çekilme bekleniyor").
    - Risk metrikleri (volatilite, 52w high/low) verilmişse bunları kullan.
    - Sembol kullanıcının portföyündeyse ("Pozisyonlar"da geçiyorsa) mevcut pozisyonun durumunu da yorumla.
    """

    // MARK: - Public API

    /// Ana rapor üretimi - Veri-odaklı, sallamasız.
    /// V6 (Phase 7+): Token tracking + latency telemetri.
    func askArgus(question: String, context: ArgusContext) async -> String {
        let startedAt = Date()
        do {
            let structuredData = buildStructuredContext(context)

            let fullPrompt = """
            ### VERİ PAKETİ:
            \(structuredData)

            ### KULLANICI SORUSU:
            "\(question)"
            """

            // Token usage (proxy: ~1 token / 4 char) — gerçek tokenizer
            // Groq/Gemini SDK döndürmüyorsa lokal tahmin yeterli, kosit izleme için.
            let promptCharCount = systemPrompt.count + fullPrompt.count
            let estimatedPromptTokens = promptCharCount / 4

            let messages: [GroqClient.ChatMessage] = [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: fullPrompt)
            ]

            let rawResponse = try await GroqClient.shared.chat(messages: messages, maxTokens: 2048)
            let estimatedResponseTokens = rawResponse.count / 4
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("🗣️ ArgusVoice [\(context.symbol)] prompt~\(estimatedPromptTokens)tk, response~\(estimatedResponseTokens)tk, \(elapsedMs)ms")

            // SPK Compliance — ensureCompliance non-async, non-throwing.
            let isRisky = context.symbol.lowercased().contains("btc") || context.symbol.lowercased().contains("eth")
            return SPKRegulatoryEngine.shared.ensureCompliance(content: rawResponse, isHighRisk: isRisky)
        } catch {
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("❌ ArgusVoice Error [\(context.symbol)] (\(elapsedMs)ms): \(error)")
            return await generateOfflineReport(context: context)
        }
    }

    /// Grand Decision'dan rapor üret
    func generateReport(decision: ArgusGrandDecision) async -> String {
        let context = ArgusContext(
            symbol: decision.symbol,
            price: nil,
            decision: decision,
            demeter: nil,
            userQuery: "Bu hisse için detaylı analiz raporu oluştur."
        )
        return await askArgus(question: context.userQuery!, context: context)
    }

    /// Legacy snapshot desteği
    func generateReport(from snapshot: DecisionSnapshot) async -> String {
        return "Rapor oluşturulamadı: Lütfen güncel analiz verisi kullanın."
    }

    /// Demeter sektör insight'ı
    func generateDemeterInsight(score: DemeterScore) async -> String {
        let taskPrompt = """
        Aşağıdaki sektör verisini 2-3 cümleyle özetle. Sistem ismi kullanma, sadece veriyle konuş.

        Sektör: \(score.sector.rawValue) (\(score.sector.name))
        Toplam Puan: \(Int(score.totalScore))/100 (Derece: \(score.grade))
        Momentum: \(Int(score.momentumScore))/100
        Şok Etkisi: \(Int(score.shockImpactScore))/100 (düşükse olumsuz şok var)
        Rejim Uyumu: \(Int(score.regimeScore))/100
        Aktif Şoklar: \(score.activeShocks.map{"\($0.type.displayName) (\($0.direction.symbol))"}.joined(separator: ", "))
        """

        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "Sen kısa ve net konuşan bir sektör analistisin. Sadece Türkçe yaz. Sistem ismi kullanma."),
            .init(role: "user", content: taskPrompt)
        ]

        do {
            return try await GroqClient.shared.chat(messages: messages)
        } catch {
            return "Sektör analizi oluşturulamadı."
        }
    }

    // MARK: - Structured Context Builder

    /// JSON yerine okunabilir, yapılandırılmış metin üretir.
    /// LLM'in sallamaması için her veriyi açıkça etiketler.
    /// V6 (Phase 7+, 2026-04-30): Prometheus, Chiron, Risk, DataHealth, SymbolMeta blokları eklendi.
    private func buildStructuredContext(_ context: ArgusContext) -> String {
        var parts: [String] = []

        // Sembol metadata (currency-aware)
        let currencySymbol = context.symbolMeta?.currencySymbol ?? "$"
        parts.append("SEMBOL: \(context.symbol)")
        if let meta = context.symbolMeta {
            parts.append("PİYASA: \(meta.market) (\(meta.currency))")
        }
        if let price = context.price {
            parts.append("GÜNCEL FİYAT: \(currencySymbol)\(String(format: "%.2f", price))")
        }

        // Veri Kalitesi — kara liste / freshness uyarıları LLM'in başında
        if let health = context.dataHealth {
            parts.append("")
            parts.append("=== VERİ KALİTESİ ===")
            if health.isBlocked {
                let reason = health.blockReason ?? "auth/paywall"
                let hours = health.blockExpiresInHours.map { String(format: "%.1f", $0) } ?? "?"
                parts.append("⚠ Bu sembolde sağlayıcı erişimi kısıtlı: \(reason) (yenilemeye \(hours) saat kaldı). Mevcut veriler eski olabilir.")
            }
            if let qAge = health.quoteAgeSeconds, qAge > 60 {
                parts.append("Quote yaşı: \(Int(qAge)) sn")
            }
            if let cAge = health.candleAgeSeconds, cAge > 600 {
                parts.append("Daily candle yaşı: \(Int(cAge / 60)) dk")
            }
            if let src = health.quoteSource {
                parts.append("Quote kaynağı: \(src)")
            }
        }

        // Prometheus 5-günlük projeksiyon — V6: kritik yeni blok
        if let p = context.prometheus {
            parts.append("")
            parts.append("=== KISA VADELİ PROJEKSİYON (\(p.horizonDays) GÜN) ===")
            parts.append("Tahmini Fiyat: \(currencySymbol)\(String(format: "%.2f", p.predictedPrice))")
            parts.append("Beklenen Değişim: \(p.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", p.changePercent))%")
            parts.append("Yön: \(p.trend)")
            parts.append("Model Önerisi: \(p.recommendation)")
            parts.append("Güven: %\(Int(p.confidence)) (\(p.confidenceLevel))")
            parts.append("Walk-Forward Doğruluk: MAPE %\(String(format: "%.2f", p.mape)), Yön İsabeti %\(String(format: "%.1f", p.directionalAccuracy * 100))")
            if !p.rationale.isEmpty {
                parts.append("Model Notu: \(p.rationale.last ?? "")")
            }
        }

        guard let d = context.decision else {
            // Karar yoksa Prometheus + meta zaten dolu, yeterli context çıkmış olabilir.
            // Geri kalan bloklar için karar şart.
            return parts.joined(separator: "\n")
        }

        // Karar
        parts.append("")
        parts.append("=== KARAR ===")
        parts.append("Aksiyon: \(d.action.rawValue)")
        parts.append("Güç: \(d.strength.rawValue)")
        parts.append("Güven: %\(Int(d.confidence * 100))")

        // Teknik Veriler
        if let orion = d.orionDetails {
            parts.append("")
            parts.append("=== TEKNİK ANALİZ ===")
            parts.append("Genel Skor: \(Int(orion.score))/100")
            parts.append("Trend: \(orion.components.trendDesc) (Skor: \(Int(orion.components.trend))/25)")
            parts.append("Momentum: \(orion.components.momentumDesc) (Skor: \(Int(orion.components.momentum))/25)")
            parts.append("Yapı: \(orion.components.structureDesc) (Skor: \(Int(orion.components.structure))/35)")

            if let rsi = orion.components.rsi {
                parts.append("RSI: \(String(format: "%.1f", rsi))\(rsi > 70 ? " (Aşırı Alım)" : rsi < 30 ? " (Aşırı Satım)" : "")")
            }
            if let macd = orion.components.macdHistogram {
                parts.append("MACD Histogram: \(String(format: "%.4f", macd)) (\(macd > 0 ? "Pozitif" : "Negatif"))")
            }
            if let trendAge = orion.components.trendAge {
                parts.append("Trend Yaşı: \(trendAge) gün")
            }
            parts.append("Sonuç: \(orion.verdict)")
        }

        // Temel Veriler
        if let fin = d.financialDetails {
            parts.append("")
            parts.append("=== TEMEL ANALİZ ===")
            if let pe = fin.peRatio { parts.append("F/K (P/E): \(String(format: "%.1f", pe))") }
            if let fpe = fin.forwardPE { parts.append("İleri F/K: \(String(format: "%.1f", fpe))") }
            if let pb = fin.pbRatio { parts.append("F/DD (P/B): \(String(format: "%.2f", pb))") }
            if let de = fin.debtToEquity { parts.append("Borç/Özkaynak: \(String(format: "%.2f", de))") }
            if let mc = fin.marketCap { parts.append("Piyasa Değeri: $\(formatLargeNumber(mc))") }
        }

        // Atlas detayları (varsa)
        if let atlas = d.atlasDecision {
            parts.append("Temel Skor: \(Int(atlas.netSupport * 100))/100")
            if let proposal = atlas.winningProposal {
                parts.append("Temel Değerlendirme: \(proposal.reasoning)")
            }
        }

        // Risk / Volatilite — V6: pozisyon boyutlandırma + stop önerisi için kritik
        if let r = context.risk {
            parts.append("")
            parts.append("=== RİSK / VOLATİLİTE ===")
            if let v = r.dailyVolatilityPct {
                let tier = v < 1.5 ? "Düşük" : v < 3.0 ? "Orta" : "Yüksek"
                parts.append("Günlük Volatilite (20g σ): %\(String(format: "%.2f", v)) (\(tier))")
            }
            if let high = r.weekHigh52, let low = r.weekLow52 {
                parts.append("52 Hafta Aralığı: \(currencySymbol)\(String(format: "%.2f", low)) - \(currencySymbol)\(String(format: "%.2f", high))")
            }
            if let dh = r.distanceFromHighPct {
                parts.append("52w Tepe'den Uzaklık: \(String(format: "%.1f", dh))%")
            }
            if let dl = r.distanceFromLowPct {
                parts.append("52w Dip'ten Uzaklık: +\(String(format: "%.1f", dl))%")
            }
            if let adr = r.avgDailyRangePct {
                parts.append("Ortalama Günlük Aralık (ATR-yakın): %\(String(format: "%.2f", adr))")
            }
        }

        // Makro Ortam
        let aether = d.aetherDecision
        parts.append("")
        parts.append("=== MAKRO ORTAM ===")
        parts.append("Makro Skor: \(Int(aether.netSupport * 100))/100")
        parts.append("Rejim: \(aether.netSupport > 0.6 ? "Risk-On (Destekleyici)" : aether.netSupport < 0.4 ? "Risk-Off (Baskılayıcı)" : "Nötr")")
        if let proposal = aether.winningProposal {
            parts.append("Makro Değerlendirme: \(proposal.reasoning)")
        }

        // Piyasa Rejimi (Chiron) — V6
        if let chiron = context.chironRegime {
            parts.append("")
            parts.append("=== PİYASA REJİMİ ===")
            parts.append("Aktif Rejim: \(chiron.regime)")
            if !chiron.explanation.isEmpty {
                parts.append("Açıklama: \(chiron.explanation)")
            }
        }

        // Sektör Skoru (Demeter) — V6: askArgus'a girmiyordu, şimdi giriyor
        if let dem = context.demeter {
            parts.append("")
            parts.append("=== SEKTÖR SKORU ===")
            parts.append("Sektör: \(dem.sector.name)")
            parts.append("Toplam Puan: \(Int(dem.totalScore))/100 (Derece: \(dem.grade))")
            parts.append("Momentum: \(Int(dem.momentumScore))/100")
            parts.append("Şok Etkisi: \(Int(dem.shockImpactScore))/100")
            parts.append("Rejim Uyumu: \(Int(dem.regimeScore))/100")
            if !dem.activeShocks.isEmpty {
                let shocks = dem.activeShocks.map { "\($0.type.displayName) \($0.direction.symbol)" }.joined(separator: ", ")
                parts.append("Aktif Şoklar: \(shocks)")
            }
        }

        // Haberler
        if let hermes = d.hermesDecision {
            parts.append("")
            parts.append("=== HABER ANALİZİ ===")
            parts.append("Haber Sentiment Skoru: \(Int(hermes.netSupport * 100))/100")
            if let proposal = hermes.winningProposal {
                parts.append("Haber Özeti: \(proposal.reasoning)")
            }
        }

        // Chart Patterns
        if let patterns = d.patterns, !patterns.isEmpty {
            parts.append("")
            parts.append("=== GRAFİK FORMASYONLARI ===")
            for p in patterns.prefix(3) {
                let direction = p.type.rawValue.contains("Bullish") || p.type.rawValue.contains("AL") ? "Yükseliş" : "Düşüş"
                parts.append("- \(p.type.rawValue): \(direction) formasyonu")
            }
        }

        // Vetolar ve Çelişkiler
        if !d.vetoes.isEmpty {
            parts.append("")
            parts.append("=== UYARILAR / VETOLAR ===")
            for veto in d.vetoes {
                parts.append("- \(veto.reason)")
            }
        }

        // Katkıda Bulunan Modüller
        if !d.contributors.isEmpty {
            parts.append("")
            parts.append("=== MODÜL OY DAĞILIMI ===")
            for c in d.contributors {
                let voteStr: String
                switch c.action {
                case .buy: voteStr = "AL"
                case .sell: voteStr = "SAT"
                case .hold: voteStr = "TUT"
                }
                parts.append("- \(c.module): \(voteStr) (Güven: %\(Int(c.confidence * 100)))")
            }
        }
        
        // MARK: - Extended App Context (V5)
        
        // Portföy Durumu
        if let portfolio = context.portfolio {
            parts.append("")
            parts.append("=== PORTFÖY DURUMU ===")
            parts.append("Toplam Varlık: $\(String(format: "%.2f", portfolio.totalEquity))")
            parts.append("Nakit Bakiye (Global): $\(String(format: "%.2f", portfolio.cashBalance))")
            parts.append("Nakit Bakiye (BIST): ₺\(String(format: "%.2f", portfolio.bistBalance))")
            parts.append("Açık Pozisyon Sayısı: \(portfolio.openPositionCount)")
            parts.append("Toplam Kar/Zarar: \(portfolio.totalPnL >= 0 ? "+" : "")$\(String(format: "%.2f", portfolio.totalPnL)) (%\(String(format: "%.1f", portfolio.totalPnLPercent)))")
            
            if !portfolio.positions.isEmpty {
                parts.append("Pozisyonlar:")
                for pos in portfolio.positions.prefix(5) {
                    parts.append("  \(pos.symbol): \(String(format: "%.0f", pos.quantity)) adet @ $\(String(format: "%.2f", pos.entryPrice)) → \(pos.pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pos.pnlPercent))%")
                }
            }
        }
        
        // Pazar Durumu
        if let market = context.marketState {
            parts.append("")
            parts.append("=== PAZAR DURUMU ===")
            parts.append("Piyasa Durumu: \(market.marketStatus)")
            if let vix = market.vix {
                parts.append("VIX: \(String(format: "%.1f", vix))\(vix > 25 ? " (Yüksek Volatilite)" : vix < 15 ? " (Düşük Volatilite)" : "")")
            }
            if let fg = market.fearGreedIndex {
                parts.append("Fear/Greed Index: \(fg)\(fg < 30 ? " (Korku)" : fg > 70 ? " (Açgözlülük)" : "")")
            }
            if let regime = market.regime {
                parts.append("Piyasa Rejimi: \(regime)")
            }
            if let spy = market.spyChange {
                parts.append("S&P 500 Günlük: \(spy >= 0 ? "+" : "")\(String(format: "%.2f", spy))%")
            }
        }
        
        // Watchlist
        if let watchlist = context.watchlist, !watchlist.isEmpty {
            parts.append("")
            parts.append("=== İZLEME LİSTESİ ===")
            parts.append("Takip Edilen Hisseler: \(watchlist.prefix(10).joined(separator: ", "))")
        }
        
        // Son İşlemler
        if let trades = context.recentTrades, !trades.isEmpty {
            parts.append("")
            parts.append("=== SON İŞLEMLER ===")
            for trade in trades.prefix(5) {
                parts.append("  \(trade.date.formatted(.dateTime.day().month())): \(trade.action) \(String(format: "%.0f", trade.quantity)) \(trade.symbol) @ $\(String(format: "%.2f", trade.price))")
            }
        }
        
        // Trade Brain Durumu
        if let tb = context.tradeBrainState {
            parts.append("")
            parts.append("=== TRADE BRAIN DURUMU ===")
            parts.append("AutoPilot: \(tb.autopilotEnabled ? "AKTİF" : "PASİF")")
            parts.append("Bekleyen Sinyal: \(tb.pendingSignals)")
            if !tb.recentAlerts.isEmpty {
                parts.append("Son Uyarılar:")
                for alert in tb.recentAlerts.prefix(3) {
                    parts.append("  - \(alert)")
                }
            }
        }

        return parts.joined(separator: "\n")
    }
    
    // MARK: - Full App Context Builder
    
    /// Uygulamanın tam durumunu çeker - Voice'un her şeye erişimi var.
    /// V6 (Phase 7+, 2026-04-30): Prometheus tahmini, Chiron rejim, risk metrikleri,
    /// sembol metadata ve veri kalitesi de toplanıyor.
    func buildFullAppContext(symbol: String? = nil) async -> ArgusContext {
        // Async store'lardan veri çek (MainActor.run dışında — actor cross-hop).
        let regimeContext = await RegimeMemoryService.shared.getRegimeContext()
        let chironResult: ChironResult? = await MainActor.run { ChironRegimeEngine.shared.globalResult }
        let blockData: (isBlocked: Bool, reason: String?, expiresInHours: Double?) = await {
            guard let s = symbol else { return (false, nil, nil) }
            let blocked = await SymbolBlocklist.shared.isBlocked(s)
            guard blocked else { return (false, nil, nil) }
            let reason = await SymbolBlocklist.shared.reasonFor(s)
            let cooldown = await SymbolBlocklist.shared.remainingCooldown(s)
            return (true, reason, cooldown.map { $0 / 3600.0 })
        }()
        return await MainActor.run { () -> ArgusContext in
            // Portföy
            let portfolioStore = PortfolioStore.shared
            let openTrades = portfolioStore.trades.filter { $0.isOpen }
            
            let positions = openTrades.map { trade in
                PositionSummary(
                    symbol: trade.symbol,
                    quantity: trade.quantity,
                    entryPrice: trade.entryPrice,
                    currentPrice: (MarketDataStore.shared.liveQuotes[trade.symbol]?.currentPrice) ?? trade.entryPrice,
                    pnlPercent: trade.profitPercentage,
                    holdingDays: Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
                )
            }
            
            let portfolio = PortfolioContext(
                totalEquity: portfolioStore.getGlobalEquity(quotes: [:]) + portfolioStore.getBistEquity(quotes: [:]),
                cashBalance: portfolioStore.globalBalance,
                bistBalance: portfolioStore.bistBalance,
                openPositionCount: openTrades.count,
                totalPnL: openTrades.reduce(0) { $0 + $1.profit },
                totalPnLPercent: openTrades.isEmpty ? 0 : openTrades.reduce(0) { $0 + $1.profitPercentage } / Double(openTrades.count),
                positions: positions
            )
            
            // Market State
            let market = MarketContext(
                vix: regimeContext.vix,
                fearGreedIndex: 50,
                regime: regimeContext.regime,
                spyChange: nil,
                marketStatus: "Kapalı"
            )
            
            // Watchlist
            let watchlist = WatchlistStore.shared.items
            
            // Recent Trades
            let recentTrades = portfolioStore.trades
                .filter { !$0.isOpen }
                .sorted { ($0.exitDate ?? Date.distantPast) > ($1.exitDate ?? Date.distantPast) }
                .prefix(5)
                .map { TradeContext(
                    symbol: $0.symbol,
                    action: $0.quantity > 0 ? "ALIM" : "SATIM",
                    quantity: abs($0.quantity),
                    price: $0.exitPrice ?? $0.entryPrice,
                    pnl: $0.profit,
                    date: $0.exitDate ?? $0.entryDate
                )}
            
            // Trade Brain State
            let tbState = TradeBrainContext(
                lastScanTime: nil,
                pendingSignals: AutoPilotStore.shared.scoutingCandidates.count,
                autopilotEnabled: AutoPilotStore.shared.isAutoPilotEnabled,
                recentAlerts: []
            )
            
            // Decision for symbol if provided
            let decision = symbol.map { SignalStateViewModel.shared.grandDecisions[$0] }

            // V6: Prometheus forecast — SignalViewModel'da @Published.
            let prometheusSummary: PrometheusVoiceSummary? = {
                guard let s = symbol,
                      let f = SignalViewModel.shared.prometheusForecastBySymbol[s],
                      f.isValid else { return nil }
                return PrometheusVoiceSummary(
                    predictedPrice: f.predictedPrice,
                    changePercent: f.changePercent,
                    trend: f.trend.rawValue,
                    recommendation: f.recommendation.rawValue,
                    confidence: f.confidence,
                    confidenceLevel: f.confidenceLevel,
                    horizonDays: f.horizonDays,
                    mape: f.validationMAPE,
                    directionalAccuracy: f.directionalAccuracy,
                    modelVersion: f.modelVersion,
                    rationale: f.rationale
                )
            }()

            // V6: Demeter sektör skoru.
            // Demeter list'i sektör bazında; sembol→sektör mapping ileride
            // SymbolResolver üzerinden bağlanmalı. Şimdilik genel piyasa görünümü
            // olarak en güçlü ve en zayıf sektörü gösterebilmek için ilk skoru
            // taşıyoruz; gerçek symbol-aware mapping eklendiğinde güncellenir.
            let demeterSummary: DemeterScore? = symbol.flatMap { _ in
                SignalStateViewModel.shared.demeterScores.first
            }

            // V6: Chiron rejim
            let chironSummary: ChironRegimeSummary? = chironResult.map {
                ChironRegimeSummary(regime: $0.regime.rawValue, explanation: $0.explanationBody)
            }

            // V6: Risk metrikleri — daily candle'lardan hesapla.
            let riskSummary: RiskVoiceSummary? = symbol.flatMap { sym in
                Self.computeRiskSummary(symbol: sym)
            }

            // V6: Sembol metadata
            let symbolMetaSummary: SymbolMetaSummary? = symbol.map { Self.inferSymbolMeta(symbol: $0) }

            // V6: Veri kalitesi (blocklist + cache yaşları)
            let dataHealthSummary: DataHealthSummary? = symbol.map { sym in
                let quoteAge: Double? = MarketDataStore.shared.quotes[sym]?.provenance.fetchedAt.timeIntervalSinceNow.magnitude
                let candleAge: Double? = MarketDataStore.shared.candles["\(sym)_1day"]?.provenance.fetchedAt.timeIntervalSinceNow.magnitude
                let quoteSrc: String? = MarketDataStore.shared.quotes[sym]?.provenance.source
                return DataHealthSummary(
                    isBlocked: blockData.isBlocked,
                    blockReason: blockData.reason,
                    blockExpiresInHours: blockData.expiresInHours,
                    quoteAgeSeconds: quoteAge,
                    candleAgeSeconds: candleAge,
                    quoteSource: quoteSrc
                )
            }

            return ArgusContext(
                symbol: symbol ?? "GENEL",
                price: symbol.flatMap { MarketDataStore.shared.liveQuotes[$0]?.currentPrice },
                decision: decision ?? nil,
                demeter: demeterSummary,
                userQuery: nil,
                portfolio: portfolio,
                marketState: market,
                watchlist: watchlist,
                recentTrades: Array(recentTrades),
                tradeBrainState: tbState,
                prometheus: prometheusSummary,
                chironRegime: chironSummary,
                risk: riskSummary,
                symbolMeta: symbolMetaSummary,
                dataHealth: dataHealthSummary
            )
        }
    }

    // MARK: - V6 Helpers (Phase 7+, 2026-04-30)

    /// Sembol pattern'inden market + currency infer eder.
    /// `.IS` → BIST/TRY, `-USD` → Crypto/USD, `=X` → Forex/USD, `=F` → Futures/USD,
    /// `^` prefix → Index/USD, default → US/USD.
    private static func inferSymbolMeta(symbol: String) -> SymbolMetaSummary {
        let upper = symbol.uppercased()
        if upper.hasSuffix(".IS") {
            return SymbolMetaSummary(market: "BIST", currency: "TRY", currencySymbol: "₺")
        }
        if upper.hasSuffix("-USD") {
            return SymbolMetaSummary(market: "Crypto", currency: "USD", currencySymbol: "$")
        }
        if upper.hasSuffix("=X") {
            return SymbolMetaSummary(market: "Forex", currency: "USD", currencySymbol: "$")
        }
        if upper.hasSuffix("=F") {
            return SymbolMetaSummary(market: "Futures", currency: "USD", currencySymbol: "$")
        }
        if upper.hasPrefix("^") {
            return SymbolMetaSummary(market: "Index", currency: "USD", currencySymbol: "$")
        }
        return SymbolMetaSummary(market: "US", currency: "USD", currencySymbol: "$")
    }

    /// Daily candle cache'inden risk/volatilite metrikleri hesaplar.
    /// MainActor.run içinde çağrıldığı için isolation güvenli.
    @MainActor
    private static func computeRiskSummary(symbol: String) -> RiskVoiceSummary? {
        let key = "\(symbol)_1day"
        guard let candles = MarketDataStore.shared.candles[key]?.value, candles.count >= 20 else {
            return nil
        }

        // Günlük volatilite — son 20 günün getiri stdDev'i, %.
        let tail = Array(candles.suffix(21))
        var returns: [Double] = []
        for i in 1..<tail.count where tail[i - 1].close > 0 {
            returns.append((tail[i].close - tail[i - 1].close) / tail[i - 1].close)
        }
        let dailyVolatilityPct: Double? = {
            guard returns.count >= 2 else { return nil }
            let mean = returns.reduce(0, +) / Double(returns.count)
            let variance = returns.reduce(0) { $0 + pow($1 - mean, 2) } / Double(returns.count - 1)
            return sqrt(variance) * 100.0
        }()

        // 52-week high / low — son 252 bar (yaklaşık 1 yıl).
        let yearWindow = candles.suffix(252)
        let weekHigh52 = yearWindow.map(\.high).max()
        let weekLow52 = yearWindow.map(\.low).min()
        let lastClose = candles.last?.close

        let distanceFromHighPct: Double? = {
            guard let h = weekHigh52, let c = lastClose, h > 0 else { return nil }
            return ((c - h) / h) * 100.0
        }()
        let distanceFromLowPct: Double? = {
            guard let l = weekLow52, let c = lastClose, l > 0 else { return nil }
            return ((c - l) / l) * 100.0
        }()

        // Ortalama günlük aralık (ATR-yakın) — son 14 günün (high-low)/close ortalaması, %.
        let atrWindow = Array(candles.suffix(14))
        let avgDailyRangePct: Double? = {
            let ranges = atrWindow.compactMap { c -> Double? in
                guard c.close > 0 else { return nil }
                return ((c.high - c.low) / c.close) * 100.0
            }
            guard !ranges.isEmpty else { return nil }
            return ranges.reduce(0, +) / Double(ranges.count)
        }()

        return RiskVoiceSummary(
            dailyVolatilityPct: dailyVolatilityPct,
            weekHigh52: weekHigh52,
            weekLow52: weekLow52,
            distanceFromHighPct: distanceFromHighPct,
            distanceFromLowPct: distanceFromLowPct,
            avgDailyRangePct: avgDailyRangePct
        )
    }

    // MARK: - Offline Fallback (Veri-Odaklı, Sallamasız)

    private func generateOfflineReport(context: ArgusContext) async -> String {
        guard let d = context.decision else { return "Analiz verisi henüz mevcut değil." }

        var report = "\(context.symbol) ANALİZ RAPORU\n\n"
        report += "Karar: \(d.action.rawValue) | Güven: %\(Int(d.confidence * 100))\n\n"

        // Teknik
        if let orion = d.orionDetails {
            report += "Teknik Görünüm: Skor \(Int(orion.score))/100"
            if let rsi = orion.components.rsi {
                report += ", RSI \(String(format: "%.0f", rsi))"
            }
            report += ". \(orion.verdict)\n\n"
        }

        // Temel
        if let fin = d.financialDetails {
            report += "Temel Değerleme:"
            if let pe = fin.peRatio { report += " F/K \(String(format: "%.1f", pe))" }
            if let de = fin.debtToEquity { report += ", Borç/Özkaynak \(String(format: "%.2f", de))" }
            report += "\n\n"
        }

        // Makro
        let aetherScore = Int(d.aetherDecision.netSupport * 100)
        report += "Makro Ortam: \(aetherScore > 60 ? "Destekleyici" : aetherScore < 40 ? "Baskılayıcı" : "Nötr") (%\(aetherScore))\n\n"

        // Vetolar
        if !d.vetoes.isEmpty {
            report += "Uyarılar:\n"
            for v in d.vetoes { report += "- \(v.reason)\n" }
        }

        // Compliance engine non-async, non-throwing.
        return SPKRegulatoryEngine.shared.ensureCompliance(content: report, isHighRisk: false)
    }

    // MARK: - Helpers

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.1fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        return String(format: "%.0f", value)
    }
}
