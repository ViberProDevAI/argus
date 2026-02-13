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

    // MARK: - System Prompt (V5 - Clean Output)

    private let systemPrompt = """
    Sen profesyonel bir finansal analistsin. Adın Argus.

    ### KESİN KURALLAR:
    1. SADECE sana verilen verilere dayanarak konuş. Veri yoksa "Bu bilgi elimde yok" de. ASLA UYDURMA.
    2. Her iddiayı bir sayıyla destekle: "Değerleme ucuz" değil, "F/K 8.5 ile sektör ortalaması 18'in çok altında" de.
    3. "Orion", "Atlas", "Aether", "Hermes" gibi sistem isimlerini KULLANMA. Bunlar iç modül isimleri, kullanıcıyı ilgilendirmez.
    4. Kısa ve net yaz. Paragrafları 3-4 cümleyi geçirme.
    5. SADECE TÜRKÇE yaz. Profesyonel, doğrudan, net.
    6. Spekülatif cümlelerden kaçın. "Olabilir", "belki" yerine verinin ne söylediğini yaz.

    ### FORMAT YASAKLARI (KESİNLİKLE YASAK):
    - Yıldız KULLANMA: *, **, ***, hiçbir yıldız karakteri yok
    - Tire KULLANMA: -, --, ---, madde işareti olarak tire yok
    - Diyez KULLANMA: #, ##, ###, markdown başlık yok
    - Nokta KULLANMA: ..., •, ◦, özel madde işaretleri yok
    - Alt çizgi KULLANMA: _, __
    - Ters tırnak KULLANMA: `, ```
    - Emoji KULLANMA

    ### DOĞRU FORMAT:
    Başlık: BÜYÜK HARFLERLE YAZ
    Alt başlık: İlk harfler büyük
    Metin: Normal cümleler, düz yazı
    Liste: 1. 2. 3. veya a) b) c) şeklinde numaralandır

    Yanıtını düz metin olarak ver. Hiçbir formatlama karakteri kullanma.

    ### ÖNEMLİ:
    - Veri yoksa o bölümü YAZMA, atla.
    - Eğer karar "GÖZLE" ise neden beklemek gerektiğini somut verilerle açıkla.
    - Eğer teknik ve temel çelişiyorsa bunu açıkça belirt.
    """

    // MARK: - Public API

    /// Ana rapor üretimi - Veri-odaklı, sallamasız.
    func askArgus(question: String, context: ArgusContext) async -> String {
        do {
            let structuredData = buildStructuredContext(context)

            let fullPrompt = """
            ### VERİ PAKETİ:
            \(structuredData)

            ### KULLANICI SORUSU:
            "\(question)"
            """

            let messages: [GroqClient.ChatMessage] = [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: fullPrompt)
            ]

            let rawResponse = try await GroqClient.shared.chat(messages: messages, maxTokens: 2048)

            // SPK Compliance
            let isRisky = context.symbol.lowercased().contains("btc") || context.symbol.lowercased().contains("eth")
            return await SPKRegulatoryEngine.shared.ensureCompliance(content: rawResponse, isHighRisk: isRisky)
        } catch {
            print("❌ Argus Voice Error: \(error)")
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
    private func buildStructuredContext(_ context: ArgusContext) -> String {
        var parts: [String] = []

        parts.append("SEMBOL: \(context.symbol)")
        if let price = context.price {
            parts.append("GÜNCEL FİYAT: $\(String(format: "%.2f", price))")
        }

        guard let d = context.decision else {
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

        // Makro Ortam
        let aether = d.aetherDecision
        parts.append("")
        parts.append("=== MAKRO ORTAM ===")
        parts.append("Makro Skor: \(Int(aether.netSupport * 100))/100")
        parts.append("Rejim: \(aether.netSupport > 0.6 ? "Risk-On (Destekleyici)" : aether.netSupport < 0.4 ? "Risk-Off (Baskılayıcı)" : "Nötr")")
        if let proposal = aether.winningProposal {
            parts.append("Makro Değerlendirme: \(proposal.reasoning)")
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
    
    /// Uygulamanın tam durumunu çeker - Voice'un her şeye erişimi var
    func buildFullAppContext(symbol: String? = nil) async -> ArgusContext {
        let regimeContext = await RegimeMemoryService.shared.getRegimeContext()
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
            
            return ArgusContext(
                symbol: symbol ?? "GENEL",
                price: symbol.flatMap { MarketDataStore.shared.liveQuotes[$0]?.currentPrice },
                decision: decision ?? nil,
                demeter: nil,
                userQuery: nil,
                portfolio: portfolio,
                marketState: market,
                watchlist: watchlist,
                recentTrades: Array(recentTrades),
                tradeBrainState: tbState
            )
        }
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

        // Try to pass through compliance engine if available; otherwise return raw report.
        do {
            // If the compliance engine is async, we await here because this function supports async.
            return try await SPKRegulatoryEngine.shared.ensureCompliance(content: report, isHighRisk: false)
        } catch {
            // In case the compliance engine cannot be awaited or throws, return the raw report to avoid build-time async errors.
            return report
        }
    }

    // MARK: - Helpers

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.1fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        return String(format: "%.0f", value)
    }
}
