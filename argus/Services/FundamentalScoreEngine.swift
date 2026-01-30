import Foundation

// MARK: - Fundamental Score Engine
// FinancialsData -> FundamentalScoreResult
// 0-100 arası puanlama yapar.

class FundamentalScoreEngine {
    static let shared = FundamentalScoreEngine()
    
    private init() {}
    
    func calculate(data: FinancialsData, riskScore: Double? = nil) -> FundamentalScoreResult? {
        
        // SPECIAL HANDLING: ETF
        if data.isETF {
            return calculateETFScore(data: data, riskScore: riskScore)
        }
        
        // Kritik veriler yoksa hesaplama yapma
        // Gevşetilmiş kontrol: Sadece Revenue zorunlu (Yahoo/Finnhub için)
        guard let revenue = data.totalRevenue, revenue > 0 else {
            return nil
        }
        
        // Opsiyonel alanlar - nil olabilir
        let netIncome = data.netIncome ?? 0
        let equity = data.totalShareholderEquity ?? 1 // Sıfıra bölme önleme
        
        // --- Data Coverage Calculation ---
        var metricsUsed = 0.0
        let totalMetrics = 7.0
        
        // --- 1. Karlılık (Profitability) ---
        var profitScores: [Double] = []
        
        // Net Marj
        let netMargin = (netIncome / revenue) * 100
        profitScores.append(scoreMetric(value: netMargin, thresholds: [0, 5, 15, 25]))
        metricsUsed += 1
        
        // ROE
        if equity > 0 {
            let roe = (netIncome / equity) * 100
            profitScores.append(scoreMetric(value: roe, thresholds: [0, 10, 15, 25]))
            metricsUsed += 1
        }
        
        let scoreProfit: Double? = profitScores.isEmpty ? nil : average(profitScores)
        
        // --- 2. Büyüme (Growth) ---
        var growthScores: [Double] = []
        
        // Revenue CAGR (3 Yıl)
        if let cagr = calculateCAGR(history: data.revenueHistory) {
            growthScores.append(scoreMetric(value: cagr, thresholds: [0, 5, 10, 20]))
            metricsUsed += 1
        }
        
        // Net Income CAGR (3 Yıl)
        if let cagr = calculateCAGR(history: data.netIncomeHistory) {
            growthScores.append(scoreMetric(value: cagr, thresholds: [0, 5, 10, 20]))
            metricsUsed += 1
        }
        
        let scoreGrowth: Double? = growthScores.isEmpty ? nil : average(growthScores)
        
        // --- 3. Borç & Risk (Leverage) ---
        var leverageScores: [Double] = []
        
        // Debt / Equity
        let totalDebt = (data.shortTermDebt ?? 0) + (data.longTermDebt ?? 0)
        // Debt verisi var mı? (short veya long nil değilse var kabul edelim, ikisi de nil ise yok)
        let hasDebtData = data.shortTermDebt != nil || data.longTermDebt != nil
        
        if hasDebtData, equity > 0 {
            let deRatio = totalDebt / equity
            // Düşük olması iyi: <0.5 süper, >2.0 kötü
            leverageScores.append(scoreMetricReverse(value: deRatio, thresholds: [0.5, 1.0, 1.5, 2.0]))
            metricsUsed += 1
        }
        
        let scoreLeverage: Double? = leverageScores.isEmpty ? nil : average(leverageScores)
        
        // --- 4. Nakit Kalitesi (Cash Quality) ---
        var cashScores: [Double] = []
        
        // Operating Cash Flow / Net Income (>1 olması istenir)
        if let ocf = data.operatingCashflow, netIncome > 0 { // operatingCashflow (lowercase f)
            let ratio = ocf / netIncome
            cashScores.append(scoreMetric(value: ratio, thresholds: [0.5, 0.8, 1.0, 1.2]))
            metricsUsed += 1
        }
        
        // Free Cash Flow Pozitifliği
        var freeCashFlow: Double? = nil
        if let ocf = data.operatingCashflow, let capex = data.capitalExpenditures {
            let fcf = ocf - capex
            freeCashFlow = fcf
            cashScores.append(fcf > 0 ? 90.0 : 20.0)
            metricsUsed += 1
        }
        
        let scoreCash: Double? = cashScores.isEmpty ? nil : average(cashScores)
        
        // --- Data Coverage Check ---
        let coverage = (metricsUsed / totalMetrics) * 100.0
        if coverage < 40.0 {
            return nil // Yetersiz veri
        }
        
        // --- Realized Score Calculation (Dynamic Weights) ---
        // Base Weights: Profit 0.35, Growth 0.25, Leverage 0.25, Cash 0.15
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        if let s = scoreProfit {
            weightedSum += s * 0.35
            totalWeight += 0.35
        }
        if let s = scoreGrowth {
            weightedSum += s * 0.25
            totalWeight += 0.25
        }
        if let s = scoreLeverage {
            weightedSum += s * 0.25
            totalWeight += 0.25
        }
        if let s = scoreCash {
            weightedSum += s * 0.15
            totalWeight += 0.15
        }
        
        guard totalWeight > 0 else { return nil }
        
        let realizedScore = weightedSum / totalWeight
        
        // --- Forward Score (Beklenti) ---
        var forwardScore: Double? = nil
        if let fwdGrowth = data.forwardGrowthEstimate {
            // Beklenen büyüme %10 üstü ise iyi
            forwardScore = scoreMetric(value: fwdGrowth, thresholds: [0, 5, 10, 20])
        }
        
        // --- Total Score ---
        let totalScore: Double
        if let fwd = forwardScore {
            totalScore = (realizedScore * 0.80) + (fwd * 0.20)
        } else {
            totalScore = realizedScore
        }
        
        // --- Valuation Grade ---
        let valuationGrade = calculateValuationGrade(data: data)
        
        // --- Özet ---
        let summary = generateSummary(profit: scoreProfit, growth: scoreGrowth, leverage: scoreLeverage)
        let highlights = generateHighlights(data: data, profit: scoreProfit, growth: scoreGrowth, fcf: freeCashFlow, valuationGrade: valuationGrade)
        
        // --- Pro Insights (AI) ---
        let insights = generateProInsights(profit: scoreProfit, growth: scoreGrowth, leverage: scoreLeverage, cash: scoreCash, data: data, fcf: freeCashFlow, valuationGrade: valuationGrade, riskScore: riskScore)
        
        // --- Calculation Details ---
        let details = generateCalculationDetails(profit: scoreProfit, growth: scoreGrowth, leverage: scoreLeverage, cash: scoreCash, data: data, fcf: freeCashFlow, totalDebt: totalDebt)
        
        return FundamentalScoreResult(
            symbol: data.symbol,
            date: Date(),
            totalScore: totalScore,
            realizedScore: realizedScore,
            forwardScore: forwardScore,
            profitabilityScore: scoreProfit,
            growthScore: scoreGrowth,
            leverageScore: scoreLeverage,
            cashQualityScore: scoreCash,
            dataCoverage: coverage,
            summary: summary,
            highlights: highlights,
            proInsights: insights,
            calculationDetails: details,
            valuationGrade: valuationGrade,
            riskScore: riskScore,
            isETF: data.isETF,
            financials: data
        )
    }
    
    // MARK: - Helpers
    
    // Sektör ortalama P/E değerleri (2024 Q4 yaklaşık değerler)
    private let sectorAveragePE: [String: Double] = [
        "Technology": 30.0,
        "Communication Services": 22.0,
        "Consumer Discretionary": 25.0,
        "Consumer Staples": 20.0,
        "Energy": 12.0,
        "Financials": 14.0,
        "Healthcare": 22.0,
        "Industrials": 20.0,
        "Materials": 16.0,
        "Real Estate": 35.0,
        "Utilities": 18.0
    ]
    
    private func calculateValuationGrade(data: FinancialsData) -> String? {
        guard let pe = data.peRatio, pe > 0 else {
            // Fallback to P/B if no P/E
            if let pb = data.priceToBook {
                if pb < 1 { return "Defter Değerinin Altında" }
                else if pb <= 3 { return "Makul" }
                else { return "Pahalı" }
            }
            return nil
        }
        
        // TODO: Sector-relative P/E (requires sector field in FinancialsData)
        // When sector is available, compare against sectorAveragePE[sector]
        // For now, use absolute thresholds with more nuanced ranges
        
        // Enhanced Absolute P/E Thresholds
        if pe < 8 { return "Çok Ucuz" }
        else if pe < 15 { return "Ucuz" }
        else if pe <= 22 { return "Makul" }
        else if pe <= 35 { return "Pahalı" }
        else { return "Çok Pahalı" }
    }
    
    private func generateCalculationDetails(profit: Double?, growth: Double?, leverage: Double?, cash: Double?, data: FinancialsData, fcf: Double?, totalDebt: Double) -> String {
        var details = ""
        
        details += "📊 **SKOR HESAPLAMA DETAYLARI**\n\n"
        
        // 1. Karlılık (%35)
        if let p = profit {
            details += "1️⃣ **Karlılık**: \(Int(p))/100\n"
            if let nm = data.netIncome, let rev = data.totalRevenue, rev > 0 {
                let margin = (nm / rev) * 100
                details += "   • Net Marj: %\(String(format: "%.1f", margin)) (Hedef: >%15)\n"
            }
            if let equity = data.totalShareholderEquity, equity > 0, let ni = data.netIncome {
                let roe = (ni / equity) * 100
                details += "   • ROE (Özkaynak Karlılığı): %\(String(format: "%.1f", roe)) (Hedef: >%15)\n"
            }
        } else {
            details += "1️⃣ **Karlılık**: Veri Yok ❌\n"
        }
        details += "\n"
        
        // 2. Büyüme (%25)
        if let g = growth {
            details += "2️⃣ **Büyüme**: \(Int(g))/100\n"
            if let revHist = calculateCAGR(history: data.revenueHistory) {
                details += "   • Ciro Büyümesi (3 Yıllık): %\(String(format: "%.1f", revHist)) (Hedef: >%10)\n"
            }
            if let niHist = calculateCAGR(history: data.netIncomeHistory) {
                details += "   • Net Kar Büyümesi (3 Yıllık): %\(String(format: "%.1f", niHist)) (Hedef: >%10)\n"
            }
        } else {
            details += "2️⃣ **Büyüme**: Veri Yok ❌\n"
        }
        details += "\n"
        
        // 3. Risk & Borç (%25)
        if let l = leverage {
            details += "3️⃣ **Risk & Borç**: \(Int(l))/100\n"
            if let equity = data.totalShareholderEquity, equity > 0 {
                let de = totalDebt / equity
                details += "   • Borç/Özkaynak Oranı: \(String(format: "%.2f", de)) (Hedef: <1.0)\n"
            }
        } else {
            details += "3️⃣ **Risk & Borç**: Veri Yok ❌\n"
        }
        details += "\n"
        
        // 4. Nakit Kalitesi (%15)
        if let c = cash {
            details += "4️⃣ **Nakit Kalitesi**: \(Int(c))/100\n"
            if let ocf = data.operatingCashflow, let ni = data.netIncome, ni > 0 {
                let ratio = ocf / ni
                details += "   • Nakit Akışı / Net Kar: \(String(format: "%.2f", ratio)) (Hedef: >1.0)\n"
            }
            if let f = fcf {
                details += "   • Serbest Nakit Akışı: \(f > 0 ? "Pozitif ✅" : "Negatif ❌")\n"
            }
        } else {
            details += "4️⃣ **Nakit Kalitesi**: Veri Yok ❌\n"
        }
        
        return details
    }
    
    private func generateProInsights(profit: Double?, growth: Double?, leverage: Double?, cash: Double?, data: FinancialsData, fcf: Double?, valuationGrade: String?, riskScore: Double?) -> [String] {
        var insights: [String] = []
        
        // 1. Profitability Insight
        if let p = profit {
            if p >= 80 {
                insights.append("Şirket **yüksek karlılık** oranlarına sahip. Net kar marjı ve özkaynak karlılığı (ROE) güçlü, bu da yönetimin sermayeyi verimli kullandığını gösteriyor.")
            } else if p <= 40 {
                insights.append("Karlılık tarafında zayıflık görülüyor. Net kar marjındaki düşüş, artan maliyetlere veya rekabet baskısına işaret ediyor olabilir.")
            }
        }
        
        // 2. Growth Insight
        if let g = growth {
            if g >= 80 {
                insights.append("Büyüme ivmesi etkileyici. Hem ciro hem de net kar son 3 yılda istikrarlı bir artış trendinde.")
            } else if g <= 40 {
                insights.append("Büyüme hızında yavaşlama var. Şirketin cirosu veya net karı son dönemde ivme kaybetmiş.")
            }
        }
        
        // 3. Leverage (Risk) Insight
        if let l = leverage {
            if l >= 80 {
                insights.append("Finansal sağlık mükemmel. Borçluluk oranı çok düşük, bu da şirketi faiz artışlarına ve ekonomik dalgalanmalara karşı korunaklı kılıyor.")
            } else if l <= 40 {
                insights.append("⚠️ **Yüksek Borç Uyarısı:** Şirketin borç/özkaynak oranı yüksek seviyelerde. Bu durum finansal riskleri artırabilir.")
            }
        }
        
        // 4. Cash Flow Insight
        if let c = cash {
            if c >= 80 {
                insights.append("Nakit akışı çok güçlü. Şirket operasyonlarından bol miktarda nakit üretiyor, bu da temettü veya geri alım potansiyelini artırıyor.")
            } else if c <= 40 {
                insights.append("Nakit akışında sorunlar olabilir. Serbest nakit akışı negatif veya zayıf, bu da dış finansman ihtiyacı doğurabilir.")
            }
        }
        
        // 5. Valuation Insight
        if let grade = valuationGrade {
            insights.append("Değerleme tarafında hisse **\(grade)** görünüyor (F/K ve PD/DD oranlarına göre).")
        }
        
        // 6. Volatility (Risk) Insight
        if let risk = riskScore {
            if risk < 35 {
                insights.append("Volatilitesi görece düşük, fiyat hareketleri daha sakin seyrediyor.")
            } else if risk < 70 {
                insights.append("Orta düzey volatilite, dönemsel dalgalanmalar mevcut.")
            } else {
                insights.append("⚠️ **Yüksek Volatilite:** Fiyat hareketleri oldukça oynak, kısa vadede sert dalgalanma riski yüksek.")
            }
        }
        
        // 7. Forward Looking (Honest)
        if let fwd = data.forwardGrowthEstimate {
            if fwd > 15 {
                insights.append("🚀 **Büyüme Trendi:** Son dönemde gelir büyümesi %\(String(format: "%.1f", fwd)) civarında gerçekleşmiş, bu da güçlü bir ivmeye işaret ediyor.")
            } else if fwd < 0 {
                insights.append("Son dönemde gelirlerde daralma görülüyor (%\(String(format: "%.1f", fwd))).")
            }
        }
        
        if insights.isEmpty {
            return ["Şirket genel olarak dengeli bir finansal görünüme sahip, ancak öne çıkan belirgin bir güçlü veya zayıf yön bulunmuyor."]
        }
        
        return insights
    }

    private func calculateCAGR(history: [Double]) -> Double? {
        guard history.count >= 3, let last = history.first, let first = history.last, first > 0 else { return nil }
        // history: [2023, 2022, 2021] -> first=2023, last=2021 (API sırasına göre değişir, kontrol edelim)
        // Alpha Vantage annualReports genelde [newest, ..., oldest] döner.
        // Yani history[0] en yeni, history[last] en eski.
        
        let years = Double(history.count) - 1
        let cagr = (pow(last / first, 1.0 / years) - 1.0) * 100
        return cagr
    }
    
    private func average(_ scores: [Double]) -> Double {
        guard !scores.isEmpty else { return 0.0 } // Should not happen if checked before
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func scoreMetric(value: Double, thresholds: [Double]) -> Double {
        if value < thresholds[0] { return 20.0 }
        if value < thresholds[1] { return 40.0 }
        if value < thresholds[2] { return 60.0 }
        if value < thresholds[3] { return 80.0 }
        return 95.0
    }
    
    private func scoreMetricReverse(value: Double, thresholds: [Double]) -> Double {
        if value < thresholds[0] { return 95.0 }
        if value < thresholds[1] { return 80.0 }
        if value < thresholds[2] { return 60.0 }
        if value < thresholds[3] { return 40.0 }
        return 20.0
    }
    
    private func generateSummary(profit: Double?, growth: Double?, leverage: Double?) -> String {
        var parts: [String] = []
        if let p = profit {
            if p > 70 { parts.append("Karlılık güçlü") } else if p < 40 { parts.append("Karlılık zayıf") }
        }
        if let g = growth {
            if g > 70 { parts.append("büyüme yüksek") } else if g < 40 { parts.append("büyüme yavaş") }
        }
        if let l = leverage {
            if l > 70 { parts.append("borçluluk düşük") } else if l < 40 { parts.append("borç riski var") }
        }
        
        if parts.isEmpty { return "Dengeli bir görünüm." }
        return parts.joined(separator: ", ") + "."
    }
    
    private func generateHighlights(data: FinancialsData, profit: Double?, growth: Double?, fcf: Double?, valuationGrade: String?) -> [String] {
        var items: [String] = []
        
        // Valuation Grade Highlight
        if let grade = valuationGrade {
            items.append("Değerleme: \(grade)")
        }
        
        if let nm = data.netIncome, let rev = data.totalRevenue, rev > 0 {
            let margin = (nm / rev) * 100
            items.append("Net Marj: %\(String(format: "%.1f", margin))")
        }
        if let f = fcf, f > 0 {
            items.append("Pozitif Serbest Nakit Akışı")
        }
        
        // Valuation Highlights
        if let pe = data.peRatio {
            let label = (pe < 12) ? "(Ucuz)" : (pe > 25 ? "(Pahalı)" : "(Makul)")
            items.append("F/K: \(String(format: "%.2f", pe)) \(label)")
        } else if let pb = data.priceToBook {
            let label = (pb < 1) ? "(Ucuz)" : (pb > 3 ? "(Pahalı)" : "(Makul)")
            items.append("PD/DD: \(String(format: "%.2f", pb)) \(label)")
        }
        
        if let div = data.dividendYield {
            items.append("Temettü: %\(String(format: "%.2f", div * 100))")
        }
        
        return items
    }
    // MARK: - ETF Handling
    private func calculateETFScore(data: FinancialsData, riskScore: Double?) -> FundamentalScoreResult {
        // ETF Scoring Strategy (Pillar 4 Adapter)
        // ETFs don't have Revenue/Income in the same way.
        // We rely on: Performance, Risk, Expense (if avail), Dividends.
        
        var score = 50.0 // Base Neutral
        var notes: [String] = []
        
        // 1. Dividend Bonus
        if let div = data.dividendYield, div > 0.02 {
            score += 10
            notes.append("Temettü Verimi: %\(String(format: "%.2f", div*100)) (Pozitif)")
        }
        
        // 2. Risk Adjustment (Low Volatility is good for safe ETF, High Vol for leveraged)
        // Assuming generic ETF preference for stability in Atlas context
        if let risk = riskScore {
            if risk < 30 { score += 10; notes.append("Düşük Volatilite (+10)") }
            else if risk > 60 { score -= 10; notes.append("Yüksek Volatilite (-10)") }
        }
        
        // 3. PE Check (Some ETFs have PE)
        if let pe = data.peRatio {
            if pe > 0 && pe < 20 { score += 5; notes.append("Makul F/K Değeri (+5)") }
        }
        
        return FundamentalScoreResult(
            symbol: data.symbol,
            date: Date(),
            totalScore: min(90, max(30, score)),
            realizedScore: score,
            forwardScore: nil,
            profitabilityScore: nil,
            growthScore: nil,
            leverageScore: nil,
            cashQualityScore: nil,
            dataCoverage: 50.0,
            summary: "ETF Analizi (Temel Veriler Sınırlı)",
            highlights: notes,
            proInsights: ["Bu bir Borsa Yatırım Fonu (ETF). Klasik bilanço analizi yerine genel piyasa performansı ve maliyet yapısı öne çıkıyor.", "Atlas skoru nötr seviyeden başlatılarak temettü ve risk profiline göre ayarlandı."],
            calculationDetails: "ETF Puanlama Algoritması Kullanıldı.",
            valuationGrade: nil, // Can be refined
            riskScore: riskScore,
            isETF: true,
            financials: data
        )
    }
}
