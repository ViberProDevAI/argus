import Foundation

// MARK: - Modeller

struct BistFaktorResult: Sendable {
    let symbol: String
    let totalScore: Double
    let factors: [BistFaktor]
    let timestamp: Date

    var verdict: String {
        switch totalScore {
        case 75...: return "Cok Guclu"
        case 60..<75: return "Guclu"
        case 45..<60: return "Notr"
        case 30..<45: return "Zayif"
        default: return "Cok Zayif"
        }
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 24 * 3600
    }
    
    var decayedScore: Double {
        // Basit zaman aşımı logic'i eklenebilir, şimdilik raw skoru döndür
        totalScore
    }
}

// Zenginleştirilmiş Veri Yapısı
struct AnalysisMetric: Sendable, Hashable, Identifiable {
    var id: String { label }
    let label: String       // Örn: "F/K"
    let value: String       // Örn: "4.5"
    let context: String     // Örn: "Sektör Ort: 12.0" veya "(Ucuz)"
    let scoreImpact: Double // Örn: +20
    let education: String   // Örn: "Düşük F/K ve Yüksek ROE, hissenin gerçek değerinin altında fiyatlandığını gösterir."
}

struct BistFaktor: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let score: Double
    let icon: String
    let color: String
    let metrics: [AnalysisMetric] // Eski 'details' string array'i yerine rich metrics
}

actor BistFaktorEngine {
    static let shared = BistFaktorEngine()
    private init() {}
    
    // MARK: - Ana Analiz
    func analyze(symbol: String, oracleSignals: [OracleEngine.OracleSignal] = []) async throws -> BistFaktorResult {
        let cleanSymbol = symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
        let financials = try await BorsaPyProvider.shared.getFinancialStatements(symbol: cleanSymbol)
        let quote = try? await BorsaPyProvider.shared.getBistQuote(symbol: cleanSymbol)
        let history = try? await BorsaPyProvider.shared.getBistHistory(symbol: cleanSymbol, days: 60)
        let dividends = try? await BorsaPyProvider.shared.getDividends(symbol: cleanSymbol)
        
        // Sektör bilgisini al
        let sectorCode = await BistSektorEngine.shared.getSector(for: cleanSymbol)
        
        let valueScore = calculateValueFactor(financials, quote: quote)
        let momentumScore = calculateMomentumFactor(history)
        let qualityScore = calculateQualityFactor(financials)
        let dividendScore = calculateDividendFactor(dividends, quote: quote, financials: financials)
        
        // Oracle Makro Analizi
        let oracleScore = calculateOracleFactor(symbol: cleanSymbol, sector: sectorCode, signals: oracleSignals)
        
        // Growth & CashFlow Engine'ler henüz Metric yapısına geçmedi, onları wrapper ile uyumlayacağım
        let growthResult = await BistGrowthEngine.shared.analyze(financials: financials)
        let cashResult = await BistCashFlowEngine.shared.analyze(financials: financials)
        
        // Geçici Wrapper: String detayları Metric'e çevir
        let growthMetrics = [
            AnalysisMetric(
                label: "Büyüme Verisi",
                value: growthResult.status.rawValue,
                context: growthResult.details,
                scoreImpact: 0,
                education: "İstikrarlı büyüme, şirketin pazar payını artırdığını gösterir."
            )
        ]
        
        let cashMetrics = [
            AnalysisMetric(
                label: "Nakit Akışı",
                value: cashResult.status.rawValue,
                context: cashResult.details,
                scoreImpact: 0,
                education: "Nakit akışı, şirketin faturalarını ödeme ve yatırım yapma gücünü gösterir."
            )
        ]
        
        let growthFactor = BistFaktor(
            name: "Büyüme (Growth)",
            score: growthResult.score,
            icon: "chart.line.uptrend.xyaxis",
            color: growthResult.status.color,
            metrics: growthMetrics
        )
        
        let cashFactor = BistFaktor(
            name: "Nakit (Cash Flow)",
            score: cashResult.score,
            icon: "dollarsign.circle",
            color: cashResult.status.color,
            metrics: cashMetrics
        )
        
        // Toplam Skor Hesabı (Oralce Eklendi: 7 Faktör)
        let totalScore = (valueScore.score + momentumScore.score + qualityScore.score + dividendScore.score + growthFactor.score + cashFactor.score + oracleScore.score) / 7
        
        return BistFaktorResult(
            symbol: cleanSymbol,
            totalScore: totalScore,
            factors: [valueScore, momentumScore, qualityScore, dividendScore, growthFactor, cashFactor, oracleScore],
            timestamp: Date()
        )
    }

    // MARK: - Value Logic
    private func calculateValueFactor(_ f: BistFinancials, quote: BistQuote?) -> BistFaktor {
        var score: Double = 50
        var metrics: [AnalysisMetric] = []
        
        let roe = f.roe ?? 0
        let hasGoodROE = roe >= 10
        let hasPositiveROE = roe > 0
        
        // F/K Analizi
        if let pe = f.pe, pe > 0 {
            if pe < BistThresholds.Valuation.deepValuePE { // < 5.0
                if hasGoodROE {
                    score += BistThresholds.Valuation.deepValuePEScore // +30
                    metrics.append(AnalysisMetric(
                        label: "Fiyat/Kazanç (F/K)",
                        value: String(format: "%.2f", pe),
                        context: "Çok Ucuz (< 5.0)",
                        scoreImpact: 30,
                        education: "Hisse fiyatı, şirketin elde ettiği kâra göre çok ucuz. Yüksek ROE ile birleşince 'Derin Değer' fırsatı sunuyor."
                    ))
                } else if hasPositiveROE {
                    score += 10
                    metrics.append(AnalysisMetric(
                        label: "Fiyat/Kazanç (F/K)",
                        value: String(format: "%.2f", pe),
                        context: "Ucuz ama Riskli",
                        scoreImpact: 10,
                        education: "Hisse ucuz görünüyor (F/K < 5) ancak kârlılık (ROE) düşük. Bu bir 'Değer Tuzağı' (Value Trap) olabilir."
                    ))
                } else {
                    score -= 10
                    metrics.append(AnalysisMetric(
                        label: "Fiyat/Kazanç (F/K)",
                        value: String(format: "%.2f", pe),
                        context: "Zarar Eden Şirket",
                        scoreImpact: -10,
                        education: "Şirket zarar ediyor veya kârlılığı sürdürülemez. Düşük çarpan aldatıcı olabilir."
                    ))
                }
            } else if pe < BistThresholds.Valuation.normalPE { // < 12.0
                metrics.append(AnalysisMetric(
                    label: "Fiyat/Kazanç (F/K)",
                    value: String(format: "%.2f", pe),
                    context: "Makul Seviye",
                    scoreImpact: 0,
                    education: "Hisse fiyatı, kârına oranla makul seviyede işlem görüyor."
                ))
            } else {
                score -= 10
                metrics.append(AnalysisMetric(
                    label: "Fiyat/Kazanç (F/K)",
                    value: String(format: "%.2f", pe),
                    context: "Pahalı (> 12.0)",
                    scoreImpact: -10,
                    education: "Piyasa bu şirketten yüksek büyüme bekliyor ve primli fiyatlıyor. Büyüme gelmezse sert düşüş olabilir."
                ))
            }
        }
        
        // PD/DD Analizi
        if let pb = f.pb, pb > 0 {
            if pb < 1.0 {
                if hasPositiveROE {
                    score += 20
                    metrics.append(AnalysisMetric(
                        label: "PD/DD",
                        value: String(format: "%.2f", pb),
                        context: "Defter Değerinin Altında",
                        scoreImpact: 20,
                        education: "Piyasa değeri, şirketin özsermayesinden daha düşük. Şirket tasfiye olsa bile paranızı alırsınız (Teorik olarak)."
                    ))
                } else {
                    metrics.append(AnalysisMetric(
                        label: "PD/DD",
                        value: String(format: "%.2f", pb),
                        context: "Riskli Ucuzluk",
                        scoreImpact: 0,
                        education: "Şirket özsermayesinden ucuza işlem görüyor ancak zarar ettiği için özsermaye eriyor olabilir."
                    ))
                }
            } else if pb > 5.0 {
                metrics.append(AnalysisMetric(
                    label: "PD/DD",
                    value: String(format: "%.2f", pb),
                    context: "Yüksek Prim",
                    scoreImpact: -5,
                    education: "Şirket defter değerinin 5 katı işlem görüyor. Bu primi hak etmek için çok yüksek ROE üretmeli."
                ))
            }
        }
        
        return BistFaktor(name: "Değer (Value)", score: min(100, max(0, score)), icon: "tag.fill", color: score > 60 ? "blue" : "orange", metrics: metrics)
    }
    
    // MARK: - Momentum Logic
    private func calculateMomentumFactor(_ history: [BorsaPyCandle]?) -> BistFaktor {
        var score: Double = 50
        var metrics: [AnalysisMetric] = []
        
        guard let candles = history, candles.count >= 20, let last = candles.last else {
             return BistFaktor(name: "Momentum", score: 50, icon: "arrow.up.right", color: "gray", metrics: [])
        }
        
        let current = last.close
        let past20 = candles[max(0, candles.count - 21)].close
        let ret20 = ((current - past20) / past20) * 100
        
        if ret20 > 10 {
            score += 20
            metrics.append(AnalysisMetric(
                label: "20 Günlük Getiri",
                value: "+\(String(format: "%.1f", ret20))%",
                context: "Güçlü Trend",
                scoreImpact: 20,
                education: "Hisse son bir ayda piyasadan pozitif ayrıştı. Trend dostunuzdur."
            ))
        } else if ret20 < -10 {
            score -= 20
            metrics.append(AnalysisMetric(
                label: "20 Günlük Getiri",
                value: "\(String(format: "%.1f", ret20))%",
                context: "Düşüş Trendi",
                scoreImpact: -20,
                education: "Hisse satış baskısı altında. 'Düşen bıçak' tutulmaz, dönüş sinyali bekle."
            ))
        } else {
             metrics.append(AnalysisMetric(
                label: "20 Günlük Getiri",
                value: "\(String(format: "%.1f", ret20))%",
                context: "Yatay / Nötr",
                scoreImpact: 0,
                education: "Belirgin bir trend yok. Piyasa yön arayışında."
            ))
        }
        
        return BistFaktor(name: "Momentum", score: min(100, max(0, score)), icon: "bolt.fill", color: score > 60 ? "green" : "red", metrics: metrics)
    }
    
    // MARK: - Quality Logic
    private func calculateQualityFactor(_ f: BistFinancials) -> BistFaktor {
        var score: Double = 50
        var metrics: [AnalysisMetric] = []
        
        if let roe = f.roe {
            if roe > 40 {
                score += 30
                metrics.append(AnalysisMetric(
                    label: "Özsermaye Kârlılığı (ROE)",
                    value: "\(String(format: "%.1f", roe))%",
                    context: "Mükemmel (>%40)",
                    scoreImpact: 30,
                    education: "Şirket yatırımcının parasını adeta bir para makinesi gibi çoğaltıyor. Warren Buffett kriteri."
                ))
            } else if roe > 20 {
                score += 15
                metrics.append(AnalysisMetric(
                    label: "Özsermaye Kârlılığı (ROE)",
                    value: "\(String(format: "%.1f", roe))%",
                    context: "İyi (>%20)",
                    scoreImpact: 15,
                    education: "Enflasyon üzerinde reel getiri üretme kapasitesi var."
                ))
            } else {
                score -= 10
                 metrics.append(AnalysisMetric(
                    label: "Özsermaye Kârlılığı (ROE)",
                    value: "\(String(format: "%.1f", roe))%",
                    context: "Düşük (<%20)",
                    scoreImpact: -10,
                    education: "Şirket sermayeyi verimli kullanamıyor. Mevduat faizinin altında kalabilir."
                ))
            }
        }
        
        if let margin = f.netMargin {
            metrics.append(AnalysisMetric(
                label: "Net Kâr Marjı",
                value: "\(String(format: "%.1f", margin))%",
                context: margin > 10 ? "Yüksek Marj" : "Düşük Marj",
                scoreImpact: margin > 10 ? 10 : 0,
                education: "Her 100 TL'lik satıştan ne kadarının kâr olarak kaldığını gösterir. Yüksek marj rekabet avantajıdır."
            ))
        }
        
        return BistFaktor(name: "Kalite (Quality)", score: min(100, max(0, score)), icon: "checkmark.seal.fill", color: score > 60 ? "purple" : "gray", metrics: metrics)
    }
    
    // MARK: - Dividend Logic
    private func calculateDividendFactor(_ dividends: [BistDividend]?, quote: BistQuote?, financials: BistFinancials?) -> BistFaktor {
        var score: Double = 40
        var metrics: [AnalysisMetric] = []
        
        if let divs = dividends, let first = divs.first, let price = quote?.last, price > 0 {
            let yield = (first.perShare / price) * 100
             metrics.append(AnalysisMetric(
                label: "Temettü Verimi",
                value: "\(String(format: "%.1f", yield))%",
                context: yield > 5 ? "Yüksek Verim" : "Düşük Verim",
                scoreImpact: yield > 5 ? 20 : 0,
                education: "Temettü, şirketin kârını sizinle paylaştığının kanıtıdır."
            ))
            
            if yield > 5 { score += 20 }
        } else {
             metrics.append(AnalysisMetric(
                label: "Temettü Politikası",
                value: "Yok",
                context: "-",
                scoreImpact: -10,
                education: "Şirket temettü dağıtmıyor veya veri yok."
            ))
        }
        
        return BistFaktor(name: "Temettü", score: min(100, max(0, score)), icon: "banknote.fill", color: score > 50 ? "yellow" : "gray", metrics: metrics)
    }
    // MARK: - Oracle Logic
    private func calculateOracleFactor(symbol: String, sector: String?, signals: [OracleEngine.OracleSignal]) -> BistFaktor {
        var score: Double = 50
        var metrics: [AnalysisMetric] = []
        
        // 1. Sinyal Duyarlılık Analizi
        var bullishCount = 0
        var bearishCount = 0
        
        for signal in signals {
            switch signal.sentiment {
            case .bullish:
                bullishCount += 1
                score += 5
            case .bearish:
                bearishCount += 1
                score -= 5
            case .neutral:
                break
            }
            
            // Sinyal Detayı
            metrics.append(AnalysisMetric(
                label: "Oracle Sinyali",
                value: signal.sentiment.rawValue.capitalized,
                context: signal.message,
                scoreImpact: signal.sentiment == .bullish ? 5 : (signal.sentiment == .bearish ? -5 : 0),
                education: "Oracle, makro-ekonomik verileri (TCMB, EVDS) analiz ederek piyasa yönünü tahmin eder."
            ))
        }
        
        // 2. Sektörel Etki (Basit Mantık)
        if let sec = sector {
            metrics.append(AnalysisMetric(
                label: "Sektör Durumu",
                value: sec,
                context: "Nötr",
                scoreImpact: 0,
                education: "Makro verilerin \(sec) sektörü üzerindeki etkisi izleniyor."
            ))
        }
        
        return BistFaktor(
            name: "Oracle",
            score: min(100, max(0, score)),
            icon: "eye.fill",
            color: score > 55 ? "cyan" : (score < 45 ? "red" : "gray"),
            metrics: metrics
        )
    }
}
