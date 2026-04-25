import Foundation

// MARK: - Atlas BIST Scoring Engine
// BIST hisseleri için özel temel analiz ve değerleme motoru
// BorsaPy verilerini kullanarak kapsamlı puanlama yapar

actor AtlasBistScoringEngine {
    static let shared = AtlasBistScoringEngine()
    
    private init() {}
    
    // MARK: - Ana Analiz Fonksiyonu
    
    /// BIST hissesi için kapsamlı temel analiz yapar
    func analyze(symbol: String) async throws -> AtlasBistResult {
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
        
        // 1. Mali Tabloları Çek
        let financials = try await BorsaPyProvider.shared.getFinancialStatements(symbol: cleanSymbol)
        
        // 2. Temettü Geçmişi
        let dividends = try? await BorsaPyProvider.shared.getDividends(symbol: cleanSymbol)
        
        // 3. Güncel Fiyat
        let quote = try? await BorsaPyProvider.shared.getBistQuote(symbol: cleanSymbol)
        
        // 4. Analist Konsensüsü
        let analysts = try? await BorsaPyProvider.shared.getAnalystRecommendations(symbol: cleanSymbol)
        
        // 5. Puanlama Hesapla
        let profitabilityScore = calculateProfitabilityScore(financials)
        let debtScore = calculateDebtScore(financials)
        let valuationScore = calculateValuationScore(financials, quote: quote)
        let dividendScore = calculateDividendScore(dividends, quote: quote, financials: financials)
        let analystScore = calculateAnalystScore(analysts, quote: quote)
        
        // 6. Toplam Skor
        let totalScore = (profitabilityScore.score * 0.30) +
                         (debtScore.score * 0.20) +
                         (valuationScore.score * 0.25) +
                         (dividendScore.score * 0.10) +
                         (analystScore.score * 0.15)
        
        // 7. Kalite Bandı
        let qualityBand: String
        switch totalScore {
        case 80...: qualityBand = "A+ (Mükemmel)"
        case 70..<80: qualityBand = "A (Çok İyi)"
        case 60..<70: qualityBand = "B (İyi)"
        case 50..<60: qualityBand = "C (Orta)"
        case 40..<50: qualityBand = "D (Zayıf)"
        default: qualityBand = "F (Riskli)"
        }
        
        return AtlasBistResult(
            symbol: cleanSymbol,
            totalScore: totalScore,
            qualityBand: qualityBand,
            components: AtlasBistComponents(
                profitability: profitabilityScore,
                debt: debtScore,
                valuation: valuationScore,
                dividend: dividendScore,
                analyst: analystScore
            ),
            financials: financials,
            analystConsensus: analysts,
            timestamp: Date()
        )
    }
    
    // MARK: - Karlılık Puanı (%30)
    
    private func calculateProfitabilityScore(_ f: BistFinancials) -> AtlasBistScoreComponent {
        var metrics: [AtlasBistMetric] = []
        var totalPoints: Double = 0
        let maxPoints: Double = 100
        
        // ROE (Özkaynak Karlılığı) - Max 30 puan
        if let roe = f.roe {
            let roeScore: Double
            let roeExplanation: String
            switch roe {
            case 25...: roeScore = 30; roeExplanation = "Mükemmel - Sermayeyi çok verimli kullanıyor"
            case 20..<25: roeScore = 25; roeExplanation = "Çok iyi - Sektör ortalamasının üzerinde"
            case 15..<20: roeScore = 20; roeExplanation = "İyi - Kabul edilebilir getiri"
            case 10..<15: roeScore = 15; roeExplanation = "Orta - İyileştirme gerekli"
            case 5..<10: roeScore = 10; roeExplanation = "Zayıf - Düşük verimlilik"
            default: roeScore = 5; roeExplanation = "Kritik - Zarar veya çok düşük getiri"
            }
            metrics.append(AtlasBistMetric(
                name: "Özkaynak Karlılığı (ROE)",
                value: roe,
                score: roeScore,
                maxScore: 30,
                explanation: roeExplanation,
                formula: "Net Kar / Özkaynaklar × 100"
            ))
            totalPoints += roeScore
        }
        
        // Net Kar Marjı - Max 25 puan
        if let netMargin = f.netMargin {
            let marginScore: Double
            let marginExplanation: String
            switch netMargin {
            case 20...: marginScore = 25; marginExplanation = "Mükemmel kar marjı"
            case 15..<20: marginScore = 20; marginExplanation = "Yüksek kar marjı"
            case 10..<15: marginScore = 15; marginExplanation = "Sağlıklı kar marjı"
            case 5..<10: marginScore = 10; marginExplanation = "Düşük kar marjı"
            default: marginScore = 5; marginExplanation = "Çok düşük veya negatif"
            }
            metrics.append(AtlasBistMetric(
                name: "Net Kar Marjı",
                value: netMargin,
                score: marginScore,
                maxScore: 25,
                explanation: marginExplanation,
                formula: "Net Kar / Satışlar × 100"
            ))
            totalPoints += marginScore
        }
        
        // ROA (Aktif Karlılığı) - Max 20 puan
        if let roa = f.roa {
            let roaScore: Double
            let roaExplanation: String
            switch roa {
            case 15...: roaScore = 20; roaExplanation = "Varlıkları çok verimli kullanıyor"
            case 10..<15: roaScore = 16; roaExplanation = "İyi varlık verimliliği"
            case 5..<10: roaScore = 12; roaExplanation = "Orta düzey verimlilik"
            case 2..<5: roaScore = 8; roaExplanation = "Düşük verimlilik"
            default: roaScore = 4; roaExplanation = "Çok düşük veya negatif"
            }
            metrics.append(AtlasBistMetric(
                name: "Aktif Karlılığı (ROA)",
                value: roa,
                score: roaScore,
                maxScore: 20,
                explanation: roaExplanation,
                formula: "Net Kar / Toplam Aktif × 100"
            ))
            totalPoints += roaScore
        }
        
        // FAVÖK Marjı - Max 25 puan
        if let ebitda = f.ebitda, let revenue = f.revenue, revenue > 0 {
            let ebitdaMargin = (ebitda / revenue) * 100
            let ebitdaScore: Double
            let ebitdaExplanation: String
            switch ebitdaMargin {
            case 30...: ebitdaScore = 25; ebitdaExplanation = "Güçlü operasyonel performans"
            case 20..<30: ebitdaScore = 20; ebitdaExplanation = "İyi FAVÖK marjı"
            case 15..<20: ebitdaScore = 15; ebitdaExplanation = "Kabul edilebilir"
            case 10..<15: ebitdaScore = 10; ebitdaExplanation = "Düşük marj"
            default: ebitdaScore = 5; ebitdaExplanation = "Zayıf operasyonel karlılık"
            }
            metrics.append(AtlasBistMetric(
                name: "FAVÖK Marjı",
                value: ebitdaMargin,
                score: ebitdaScore,
                maxScore: 25,
                explanation: ebitdaExplanation,
                formula: "FAVÖK / Satışlar × 100"
            ))
            totalPoints += ebitdaScore
        }
        
        let normalizedScore = metrics.isEmpty ? 50 : (totalPoints / maxPoints) * 100
        
        return AtlasBistScoreComponent(
            name: "Karlılık",
            score: normalizedScore,
            weight: 0.30,
            metrics: metrics,
            summary: "Şirketin kar elde etme gücünü ölçer"
        )
    }
    
    // MARK: - Borç/Risk Puanı (%20)
    
    private func calculateDebtScore(_ f: BistFinancials) -> AtlasBistScoreComponent {
        var metrics: [AtlasBistMetric] = []
        var totalPoints: Double = 0
        let maxPoints: Double = 100
        
        // Borç/Özkaynak - Max 40 puan
        if let de = f.debtToEquity {
            let deScore: Double
            let deExplanation: String
            switch de {
            case ...0.3: deScore = 40; deExplanation = "Çok düşük borç - Finansal güç"
            case 0.3..<0.5: deScore = 35; deExplanation = "Düşük borç - Sağlıklı"
            case 0.5..<0.8: deScore = 30; deExplanation = "Orta düzey borç"
            case 0.8..<1.0: deScore = 20; deExplanation = "Yüksek borç - Dikkat"
            case 1.0..<1.5: deScore = 10; deExplanation = "Çok yüksek borç - Risk"
            default: deScore = 5; deExplanation = "Kritik borç seviyesi"
            }
            metrics.append(AtlasBistMetric(
                name: "Borç/Özkaynak",
                value: de,
                score: deScore,
                maxScore: 40,
                explanation: deExplanation,
                formula: "Toplam Borç / Özkaynaklar"
            ))
            totalPoints += deScore
        }
        
        // Cari Oran - Max 35 puan
        if let cr = f.currentRatio {
            let crScore: Double
            let crExplanation: String
            switch cr {
            case 2.0...: crScore = 35; crExplanation = "Güçlü likidite"
            case 1.5..<2.0: crScore = 30; crExplanation = "Sağlıklı likidite"
            case 1.2..<1.5: crScore = 25; crExplanation = "Yeterli likidite"
            case 1.0..<1.2: crScore = 15; crExplanation = "Sınırda likidite"
            case 0.8..<1.0: crScore = 10; crExplanation = "Likidite riski"
            default: crScore = 5; crExplanation = "Likidite krizi"
            }
            metrics.append(AtlasBistMetric(
                name: "Cari Oran",
                value: cr,
                score: crScore,
                maxScore: 35,
                explanation: crExplanation,
                formula: "Dönen Varlık / Kısa Vadeli Borç"
            ))
            totalPoints += crScore
        }
        
        // Nakit Oran - Max 25 puan
        if let cashR = f.cashRatio {
            let cashScore: Double
            let cashExplanation: String
            switch cashR {
            case 0.5...: cashScore = 25; cashExplanation = "Güçlü nakit pozisyonu"
            case 0.3..<0.5: cashScore = 20; cashExplanation = "İyi nakit durumu"
            case 0.2..<0.3: cashScore = 15; cashExplanation = "Yeterli nakit"
            case 0.1..<0.2: cashScore = 10; cashExplanation = "Düşük nakit"
            default: cashScore = 5; cashExplanation = "Nakit sıkıntısı"
            }
            metrics.append(AtlasBistMetric(
                name: "Nakit Oran",
                value: cashR,
                score: cashScore,
                maxScore: 25,
                explanation: cashExplanation,
                formula: "Nakit / Kısa Vadeli Borç"
            ))
            totalPoints += cashScore
        }
        
        let normalizedScore = metrics.isEmpty ? 50 : (totalPoints / maxPoints) * 100
        
        return AtlasBistScoreComponent(
            name: "Borç & Risk",
            score: normalizedScore,
            weight: 0.20,
            metrics: metrics,
            summary: "Şirketin finansal sağlamlığını ölçer"
        )
    }
    
    // MARK: - Değerleme Puanı (%25)
    
    private func calculateValuationScore(_ f: BistFinancials, quote: BistQuote?) -> AtlasBistScoreComponent {
        var metrics: [AtlasBistMetric] = []
        var totalPoints: Double = 0
        let maxPoints: Double = 100
        
        // F/K (P/E) - Max 50 puan
        if let pe = f.pe, pe > 0 {
            let peScore: Double
            let peExplanation: String
            switch pe {
            case ...5: peScore = 50; peExplanation = "Çok ucuz - Derin değer"
            case 5..<10: peScore = 45; peExplanation = "Ucuz - Değer fırsatı"
            case 10..<15: peScore = 35; peExplanation = "Uygun fiyatlı"
            case 15..<20: peScore = 25; peExplanation = "Adil değer"
            case 20..<30: peScore = 15; peExplanation = "Biraz pahalı"
            case 30..<50: peScore = 10; peExplanation = "Pahalı"
            default: peScore = 5; peExplanation = "Çok pahalı"
            }
            metrics.append(AtlasBistMetric(
                name: "F/K (Fiyat/Kazanç)",
                value: pe,
                score: peScore,
                maxScore: 50,
                explanation: peExplanation,
                formula: "Hisse Fiyatı / Hisse Başına Kar"
            ))
            totalPoints += peScore
        }
        
        // PD/DD (P/B) - Max 50 puan + VALUE TRAP KONTROLÜ
        if let pb = f.pb, pb > 0 {
            var pbScore: Double
            var pbExplanation: String

            // Düşük P/B için ROE kontrolü (Value Trap tespiti)
            if pb <= 0.5 {
                if let roe = f.roe, roe >= 10 {
                    // ROE yüksek = Gerçek deep value
                    pbScore = 50
                    pbExplanation = "Defter değerinin altında (ROE: %\(Int(roe)) - Gerçek Değer)"
                } else if let roe = f.roe {
                    // ROE düşük = Value Trap riski
                    pbScore = 15
                    pbExplanation = "⚠️ VALUE TRAP: Düşük P/B ama ROE yetersiz (%\(Int(roe)))"
                } else {
                    // ROE verisi yok, dikkatli ol
                    pbScore = 30
                    pbExplanation = "Defter değerinin altında (ROE verisi yok - dikkatli ol)"
                }
            } else {
                // Normal P/B aralıkları
                switch pb {
                case 0.5..<1.0: pbScore = 45; pbExplanation = "Ucuz - Defter değerine yakın"
                case 1.0..<1.5: pbScore = 35; pbExplanation = "Makul değerleme"
                case 1.5..<2.0: pbScore = 25; pbExplanation = "Adil değer"
                case 2.0..<3.0: pbScore = 15; pbExplanation = "Prim içeriyor"
                case 3.0..<5.0: pbScore = 10; pbExplanation = "Yüksek prim"
                default: pbScore = 5; pbExplanation = "Aşırı primli"
                }
            }

            metrics.append(AtlasBistMetric(
                name: "PD/DD (Piyasa/Defter Değeri)",
                value: pb,
                score: pbScore,
                maxScore: 50,
                explanation: pbExplanation,
                formula: "Piyasa Değeri / Defter Değeri"
            ))
            totalPoints += pbScore
        }
        
        let normalizedScore = metrics.isEmpty ? 50 : (totalPoints / maxPoints) * 100
        
        return AtlasBistScoreComponent(
            name: "Değerleme",
            score: normalizedScore,
            weight: 0.25,
            metrics: metrics,
            summary: "Hissenin ucuz mu pahalı mı olduğunu ölçer"
        )
    }
    
    // MARK: - Temettü Puanı (%10)

    private func calculateDividendScore(_ dividends: [BistDividend]?, quote: BistQuote?, financials: BistFinancials?) -> AtlasBistScoreComponent {
        var metrics: [AtlasBistMetric] = []
        var totalPoints: Double = 0
        let maxPoints: Double = 100

        guard let divs = dividends, let lastDiv = divs.first, let price = quote?.last, price > 0 else {
            return AtlasBistScoreComponent(
                name: "Temettü",
                score: 25, // Temettü yoksa düşük puan
                weight: 0.10,
                metrics: [AtlasBistMetric(
                    name: "Temettü Verimi",
                    value: 0,
                    score: 25,
                    maxScore: 60,
                    explanation: "Bu hisse temettü dağıtmıyor veya veri yok",
                    formula: "Yıllık Temettü / Fiyat × 100"
                )],
                summary: "Hisseden elde edilen temettü gelirini ölçer"
            )
        }

        // Son Temettü Verimi - Max 60 puan + SÜRDÜRÜLEBİLİRLİK KONTROLÜ
        let divYield = (lastDiv.perShare / price) * 100

        var yieldScore: Double
        var yieldExplanation: String

        // Yüksek temettü verimi için nakit akışı kontrolü (Value Trap tespiti)
        if divYield >= 10 {
            // Çok yüksek verim - sürdürülebilir mi kontrol et
            if let netProfit = financials?.netProfit,
               let equity = financials?.totalEquity,
               equity > 0 {
                // Temettü ödeme oranı kontrolü (payout ratio)
                let payoutRatio = (lastDiv.perShare * (equity / (netProfit > 0 ? netProfit : 1))) / 100

                if payoutRatio < 0.7 && netProfit > 0 {
                    // Kar yeterli, ödeme oranı makul
                    yieldScore = 60
                    yieldExplanation = "Çok yüksek temettü verimi - Sürdürülebilir görünüyor"
                } else if payoutRatio < 1.0 && netProfit > 0 {
                    // Kar sınırda
                    yieldScore = 45
                    yieldExplanation = "Yüksek temettü verimi - Dikkatli ol (ödeme oranı yüksek)"
                } else {
                    // Kar yetersiz veya zarar
                    yieldScore = 20
                    yieldExplanation = "⚠️ SÜRDÜRÜLEMEZ: Yüksek verim ama kâr yetersiz"
                }
            } else {
                // Finansal veri yok
                yieldScore = 35
                yieldExplanation = "Çok yüksek temettü verimi (doğrulama yapılamadı)"
            }
        } else {
            // Normal temettü aralıkları
            switch divYield {
            case 7..<10: yieldScore = 50; yieldExplanation = "Yüksek temettü verimi"
            case 5..<7: yieldScore = 40; yieldExplanation = "İyi temettü verimi"
            case 3..<5: yieldScore = 30; yieldExplanation = "Orta düzey verim"
            case 1..<3: yieldScore = 20; yieldExplanation = "Düşük temettü verimi"
            default: yieldScore = 10; yieldExplanation = "Çok düşük verim"
            }
        }

        metrics.append(AtlasBistMetric(
            name: "Temettü Verimi",
            value: divYield,
            score: yieldScore,
            maxScore: 60,
            explanation: yieldExplanation,
            formula: "Hisse Başına Temettü / Fiyat × 100"
        ))
        totalPoints += yieldScore
        
        // Temettü Sürekliliği - Max 40 puan (son 5 yıl)
        let recentYears = Set(divs.prefix(5).map { $0.year })
        let continuityScore = Double(recentYears.count) * 8 // Her yıl 8 puan
        let continuityExplanation: String
        switch recentYears.count {
        case 5: continuityExplanation = "5 yıl üst üste temettü - Güvenilir"
        case 4: continuityExplanation = "Son 5 yılda 4 kez temettü"
        case 3: continuityExplanation = "Son 5 yılda 3 kez temettü"
        case 2: continuityExplanation = "Düzensiz temettü ödemesi"
        default: continuityExplanation = "Temettü sürekliliği düşük"
        }
        metrics.append(AtlasBistMetric(
            name: "Temettü Sürekliliği",
            value: Double(recentYears.count),
            score: continuityScore,
            maxScore: 40,
            explanation: continuityExplanation,
            formula: "Son 5 yılda temettü ödenen yıl sayısı"
        ))
        totalPoints += continuityScore
        
        let normalizedScore = (totalPoints / maxPoints) * 100
        
        return AtlasBistScoreComponent(
            name: "Temettü",
            score: normalizedScore,
            weight: 0.10,
            metrics: metrics,
            summary: "Hisseden elde edilen temettü gelirini ölçer"
        )
    }
    
    // MARK: - Analist Puanı (%15)
    
    private func calculateAnalystScore(_ consensus: BistAnalystConsensus?, quote: BistQuote?) -> AtlasBistScoreComponent {
        var metrics: [AtlasBistMetric] = []
        var totalPoints: Double = 0
        let maxPoints: Double = 100
        
        guard let analysts = consensus, analysts.totalAnalysts > 0 else {
            return AtlasBistScoreComponent(
                name: "Analist Konsensüsü",
                score: 50, // Veri yoksa nötr
                weight: 0.15,
                metrics: [AtlasBistMetric(
                    name: "Analist Önerisi",
                    value: 0,
                    score: 50,
                    maxScore: 50,
                    explanation: "Analist verisi mevcut değil",
                    formula: "(AL - SAT) / Toplam Analist"
                )],
                summary: "Profesyonel analistlerin görüşlerini ölçer"
            )
        }
        
        // Konsensüs Skoru - Max 50 puan
        let consensusVal = analysts.consensusScore
        let consensusScore: Double
        let consensusExplanation: String
        switch consensusVal {
        case 0.7...: consensusScore = 50; consensusExplanation = "Güçlü AL konsensüsü"
        case 0.4..<0.7: consensusScore = 40; consensusExplanation = "AL ağırlıklı"
        case 0.1..<0.4: consensusScore = 30; consensusExplanation = "Hafif pozitif"
        case -0.1..<0.1: consensusScore = 25; consensusExplanation = "Nötr görüş"
        case -0.4..<(-0.1): consensusScore = 20; consensusExplanation = "Hafif negatif"
        case -0.7..<(-0.4): consensusScore = 10; consensusExplanation = "SAT ağırlıklı"
        default: consensusScore = 5; consensusExplanation = "Güçlü SAT konsensüsü"
        }
        metrics.append(AtlasBistMetric(
            name: "Analist Konsensüsü",
            value: consensusVal * 100, // Yüzde olarak göster
            score: consensusScore,
            maxScore: 50,
            explanation: consensusExplanation + " (\(analysts.buyCount) AL / \(analysts.holdCount) TUT / \(analysts.sellCount) SAT)",
            formula: "(AL Sayısı - SAT Sayısı) / Toplam Analist"
        ))
        totalPoints += consensusScore
        
        // Hedef Fiyat Potansiyeli - Max 50 puan
        if let price = quote?.last, let upside = analysts.upsidePotential(currentPrice: price) {
            let upsideScore: Double
            let upsideExplanation: String
            switch upside {
            case 50...: upsideScore = 50; upsideExplanation = "Çok yüksek yükseliş potansiyeli"
            case 30..<50: upsideScore = 45; upsideExplanation = "Yüksek potansiyel"
            case 20..<30: upsideScore = 35; upsideExplanation = "İyi potansiyel"
            case 10..<20: upsideScore = 25; upsideExplanation = "Orta potansiyel"
            case 0..<10: upsideScore = 15; upsideExplanation = "Düşük potansiyel"
            case -10..<0: upsideScore = 10; upsideExplanation = "Hedefe yakın"
            default: upsideScore = 5; upsideExplanation = "Hedefin üzerinde - Aşırı değerli"
            }
            metrics.append(AtlasBistMetric(
                name: "Hedef Fiyat Potansiyeli",
                value: upside,
                score: upsideScore,
                maxScore: 50,
                explanation: upsideExplanation + " (Hedef: ₺\(String(format: "%.2f", analysts.averageTargetPrice ?? 0)))",
                formula: "(Hedef Fiyat - Güncel Fiyat) / Güncel Fiyat × 100"
            ))
            totalPoints += upsideScore
        }
        
        let normalizedScore = metrics.count == 1 ? consensusScore * 2 : (totalPoints / maxPoints) * 100
        
        return AtlasBistScoreComponent(
            name: "Analist Konsensüsü",
            score: normalizedScore,
            weight: 0.15,
            metrics: metrics,
            summary: "Profesyonel analistlerin görüşlerini ölçer"
        )
    }
}

// MARK: - Atlas BIST Modelleri

struct AtlasBistResult: Sendable {
    let symbol: String
    let totalScore: Double
    let qualityBand: String
    let components: AtlasBistComponents
    let financials: BistFinancials
    let analystConsensus: BistAnalystConsensus?
    let timestamp: Date
    
    var verdict: String {
        switch totalScore {
        case 70...: return "Güçlü AL"
        case 60..<70: return "AL"
        case 50..<60: return "TUT"
        case 40..<50: return "Dikkatli TUT"
        default: return "UZAK DUR"
        }
    }
}

struct AtlasBistComponents: Sendable {
    let profitability: AtlasBistScoreComponent
    let debt: AtlasBistScoreComponent
    let valuation: AtlasBistScoreComponent
    let dividend: AtlasBistScoreComponent
    let analyst: AtlasBistScoreComponent
    
    var all: [AtlasBistScoreComponent] {
        [profitability, debt, valuation, dividend, analyst]
    }
}

struct AtlasBistScoreComponent: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let score: Double
    let weight: Double
    let metrics: [AtlasBistMetric]
    let summary: String
    
    var weightedScore: Double { score * weight }
}

struct AtlasBistMetric: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let score: Double
    let maxScore: Double
    let explanation: String
    let formula: String
    
    var percentage: Double { (score / maxScore) * 100 }
}
