import Foundation

// MARK: - Argus Validator (Scientific Verification)
/// "Forward Test Processor" makes way for "Argus Validator".
/// Bilimsel doğrulama motoru. Kararları (Hypothesis) gerçekleşen piyasa verisiyle (Observation) kıyaslar.
/// Sharpe Ratio, Max Drawdown ve Profit Factor gibi ileri düzey metrikleri hesaplar.
// MARK: - Argus Validator (Scientific Verification)
/// "Forward Test Processor" makes way for "Argus Validator".
/// Bilimsel doğrulama motoru. Kararları (Hypothesis) gerçekleşen piyasa verisiyle (Observation) kıyaslar.
/// Sharpe Ratio, Max Drawdown ve Profit Factor gibi ileri düzey metrikleri hesaplar.
@MainActor
class ArgusValidator {
    static let shared = ArgusValidator()
    
    private var ledger: ArgusLedger { ArgusLedger.shared }
    private var chiron: ChironDataLakeService { ChironDataLakeService.shared }
    private var marketStore: MarketDataStore { MarketDataStore.shared }
    
    // Doğrulama süreleri (Horizon)
    private let prometheusDaysToMature = 5  // Prometheus 5 gün sonra doğrulanır
    private let argusDaysToMature = 7       // Argus kararları 7 gün sonra doğrulanır
    
    // MARK: - Public API
    
    /// Olgunlaşmış (vadesi dolmuş) tüm testleri işler ve sonuçları üretir.
    /// Bilimsel Süreç: Hypothesis (Karar) -> Experiment (Zaman) -> Observation (Fiyat) -> Conclusion (Result)
    func validateMaturedHypotheses() async -> [ForwardTestResult] {
        var results: [ForwardTestResult] = []
        
        // 1. Prometheus Tahminlerini Doğrula
        let prometheusResults = await validatePrometheusForecasts()
        results.append(contentsOf: prometheusResults)
        
        // 2. Argus Kararlarını Doğrula
        let argusResults = await validateArgusDecisions()
        results.append(contentsOf: argusResults)
        
        // 3. Sonuçları Chiron'a (Öğrenme Motoru) Besle
        if !results.isEmpty {
            await feedResultsToChiron(results)
        }
        
        return results
    }
    
    /// İstatistikleri ve Bilimsel Metrikleri Hesaplar
    func calculateScientificMetrics() async -> ScientificStats {
        let results = await loadProcessedResults()
        
        guard !results.isEmpty else {
            return .empty
        }
        
        // Temel Metrikler
        let total = Double(results.count)
        let wins = results.filter { $0.wasCorrect }
        let winRate = Double(wins.count) / total
        
        // PnL Analizi (Sadece Argus Kararları için anlamlıdır, Prometheus sadece yön tahminidir)
        // Ancak genelleştirilmiş bir "Change Analysis" yapabiliriz.
        let returns = results.map { $0.actualChange }
        let totalReturn = returns.reduce(0, +)
        let averageReturn = totalReturn / total
        
        // Sharpe Ratio (Basitleştirilmiş: Risk Free Rate = 0 kabul edilerek)
        // Std Dev of Returns
        let sumSquaredDiffs = returns.map { pow($0 - averageReturn, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiffs / total)
        let sharpeRatio = stdDev == 0 ? 0 : (averageReturn / stdDev)
        
        // Maximum Drawdown (Kümülatif Getiri Eğrisinden)
        var peak = -Double.infinity
        var maxDrawdown = 0.0
        var cumulative = 0.0
        
        for ret in returns {
            cumulative += ret
            if cumulative > peak { peak = cumulative }
            let drawdown = peak - cumulative
            if drawdown > maxDrawdown { maxDrawdown = drawdown }
        }
        
        // Profit Factor (Brüt Kar / Brüt Zarar)
        let grossProfit = returns.filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(returns.filter { $0 < 0 }.reduce(0, +))
        let profitFactor = grossLoss == 0 ? grossProfit : grossProfit / grossLoss
        
        return ScientificStats(
            totalHypotheses: Int(total),
            validatedHypotheses: Int(total), // Şimdilik hepsi
            winRate: winRate,
            averageReturn: averageReturn,
            sharpeRatio: sharpeRatio,
            maxDrawdown: maxDrawdown,
            profitFactor: profitFactor,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Validation Logic
    
    private func validatePrometheusForecasts() async -> [ForwardTestResult] {
        let forecasts = await ledger.getUnprocessedForecasts()
        var results: [ForwardTestResult] = []
        
        for forecast in forecasts {
            // Horizon kontrolü
            guard let maturityDate = Calendar.current.date(byAdding: .day, value: prometheusDaysToMature, to: forecast.eventDate),
                  Date() >= maturityDate else {
                continue
            }
            
            // "Observation": Vade tarihindeki gerçek kapanış fiyatını bul
            // Eğer vade bugün ise, bugünün verisi (henüz kapanmadıysa son fiyat) veya dünün kapanışı.
            // fetchHistoricalClose mantığı bunu halleder.
            guard let actualPrice = await marketStore.fetchHistoricalClose(symbol: forecast.symbol, targetDate: maturityDate) else {
                // Veri henüz hazır değil veya eksik
                continue
            }
            
            let actualChange: Double = ((actualPrice - forecast.currentPrice) / forecast.currentPrice) * 100.0
            let predictedChange: Double = ((forecast.predictedPrice - forecast.currentPrice) / forecast.currentPrice) * 100.0
            
            // Doğruluk: Yön (Sign) eşleşmesi
            let wasCorrect = (predictedChange * actualChange) > 0
            
            // Accuracy: Hata payı (0-100)
            let errorPercent = abs(actualChange - predictedChange)
            let accuracy = max(0.0, 100.0 - errorPercent * 10.0)
            
            let result = ForwardTestResult(
                id: UUID(),
                symbol: forecast.symbol,
                testType: .prometheusforecast,
                eventDate: forecast.eventDate,
                verificationDate: Date(),
                originalPrice: forecast.currentPrice,
                predictedPrice: forecast.predictedPrice,
                predictedAction: nil,
                actualPrice: actualPrice,
                actualChange: actualChange,
                wasCorrect: wasCorrect,
                accuracy: accuracy,
                moduleScores: nil,
                notes: "Horizon: \(prometheusDaysToMature) Gün. Tahmin: \(String(format: "%.1f", predictedChange))%, Gerçek: \(String(format: "%.1f", actualChange))%"
            )
            
            results.append(result)
            await ledger.markEventProcessed(eventId: forecast.eventId)
        }
        
        return results
    }
    
    private func validateArgusDecisions() async -> [ForwardTestResult] {
        let decisions = await ledger.getUnprocessedDecisions()
        var results: [ForwardTestResult] = []
        
        for decision in decisions {
            // Horizon kontrolü
            guard let maturityDate = Calendar.current.date(byAdding: .day, value: argusDaysToMature, to: decision.eventDate),
                  Date() >= maturityDate else {
                continue
            }
            
            guard let actualPrice = await marketStore.fetchHistoricalClose(symbol: decision.symbol, targetDate: maturityDate) else {
                continue
            }
            
            let actualChange: Double = ((actualPrice - decision.currentPrice) / decision.currentPrice) * 100.0
            
            // Doğruluk: Karar yönü ile fiyat hareketi uyumlu mu?
            let wasCorrect: Bool
            let action = decision.action.uppercased()
            
            if ["BUY", "AGGRESSIVE_BUY", "ACCUMULATE"].contains(action) {
                wasCorrect = actualChange > 0.5 // Komisyon vb. için minör buffer
            } else if ["SELL", "LIQUIDATE", "TRIM"].contains(action) {
                // Sell kararı, düşüşten kaçınmak veya kar realize etmektir.
                // Eğer fiyat düştüyse (veya çok az arttıysa) karar doğrudur.
                // Basitlik için: Short mantığı gibi düşünelim; düşüş = başarı
                // Veya "Opportunity Cost" analizi gerekir ama şimdilik basit tutalım.
                wasCorrect = actualChange < -0.5
            } else {
                // HOLD / NEUTRAL
                // Fiyat yatay gittiyse (%-2 ile %+2 arası) başarılıdır
                wasCorrect = abs(actualChange) < 2.0
            }
            
            // Accuracy: Basit bir skorlama
            let accuracy = wasCorrect ? min(100.0, 50.0 + abs(actualChange) * 5.0) : max(0.0, 50.0 - abs(actualChange) * 5.0)
            
            let result = ForwardTestResult(
                id: UUID(),
                symbol: decision.symbol,
                testType: .argusDecision,
                eventDate: decision.eventDate,
                verificationDate: Date(),
                originalPrice: decision.currentPrice,
                predictedPrice: nil,
                predictedAction: decision.action,
                actualPrice: actualPrice,
                actualChange: actualChange,
                wasCorrect: wasCorrect,
                accuracy: accuracy,
                moduleScores: decision.moduleScores,
                notes: "Horizon: \(argusDaysToMature) Gün. Aksiyon: \(action), Sonuç: \(String(format: "%.1f", actualChange))%"
            )
            
            results.append(result)
            await ledger.markEventProcessed(eventId: decision.eventId)
        }
        
        return results
    }
    
    // MARK: - Chiron Integration
    
    private func feedResultsToChiron(_ results: [ForwardTestResult]) async {
        for result in results {
            // 1. Log Learning Event
            let event = ChironLearningEvent(
                id: UUID(),
                date: result.verificationDate,
                eventType: .forwardTest,
                symbol: result.symbol,
                engine: nil,
                description: result.wasCorrect ? "Doğrulama Başarılı" : "Doğrulama Başarısız",
                reasoning: result.notes ?? "",
                confidence: result.accuracy / 100.0
            )
            await chiron.logLearningEvent(event)
            
            // 2. Log Module Predictions (Attribution)
            if let scores = result.moduleScores {
                for (module, score) in scores {
                    // Attribution Logic:
                    // Eğer modül skoru yüksekse (>50) ve sonuç doğruysa -> Modül Başarılı
                    // Eğer modül skoru düşükse (<50) ve sonuç yanlışsa -> Modül Başarılı (Doğru çekimserlik)
                    // Buna "Signal Agreement" diyoruz.
                    
                    let signalAgreement: Bool
                    if score >= 50 {
                        signalAgreement = result.wasCorrect
                    } else {
                        // Skor düşük, yani modül "girme" dedi. Eğer sonuç kötüyse (fiyat düştüyse/zarar yazdıysa), modül haklıdır.
                        // Ancak burada result.wasCorrect "Kararın" doğruluğu.
                        // Eğer Karar = BUY ve Sonuç = Kötü ise wasCorrect = False.
                        // Modül Score = 30 ise (Desteklemedi), Modül haklı çıktı.
                        signalAgreement = !result.wasCorrect
                    }
                    
                    let prediction = ModulePredictionRecord(
                        id: UUID(),
                        module: module,
                        symbol: result.symbol,
                        date: result.eventDate,
                        signal: score >= 50 ? "SUPPORT" : "ABSTAIN",
                        scoreAtTime: score,
                        wasCorrect: signalAgreement,
                        actualPnl: result.actualChange
                    )
                    
                    await chiron.logModulePrediction(prediction)
                }
            }
        }
        
        // Sonuçları yerel diske de yedekleyelim (Analiz UI'ı için)
        await saveResults(results)
    }
    
    // MARK: - Persistence (Validation Cache)
    
    private func loadProcessedResults() async -> [ForwardTestResult] {
        let path = getResultsFilePath()
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ForwardTestResult].self, from: data)
        } catch {
            return []
        }
    }
    
    private func saveResults(_ results: [ForwardTestResult]) async {
        var existing = await loadProcessedResults()
        existing.append(contentsOf: results)
        if existing.count > 2000 { existing = Array(existing.suffix(2000)) } // Keep last 2000
        
        let path = getResultsFilePath()
        try? JSONEncoder().encode(existing).write(to: path)
    }
    
    private func getResultsFilePath() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ArgusScientificResults.json")
    }
    
    // MARK: - UI Helpers
    
    /// Bekleyen testleri listeler (UI için)
    func getPendingHypotheses() async -> [PendingForwardTest] {
        var pending: [PendingForwardTest] = []
        
        // Prometheus
        let forecasts = await ledger.getUnprocessedForecasts()
        for f in forecasts {
            let daysSince = Calendar.current.dateComponents([.day], from: f.eventDate, to: Date()).day ?? 0
            pending.append(PendingForwardTest(
                id: f.eventId,
                symbol: f.symbol,
                testType: .prometheusforecast,
                eventDate: f.eventDate,
                originalPrice: f.currentPrice,
                predictedPrice: f.predictedPrice,
                predictedAction: nil,
                daysUntilMature: max(0, prometheusDaysToMature - daysSince)
            ))
        }
        
        // Argus
        let decisions = await ledger.getUnprocessedDecisions()
        for d in decisions {
            let daysSince = Calendar.current.dateComponents([.day], from: d.eventDate, to: Date()).day ?? 0
            pending.append(PendingForwardTest(
                id: d.eventId,
                symbol: d.symbol,
                testType: .argusDecision,
                eventDate: d.eventDate,
                originalPrice: d.currentPrice,
                predictedPrice: nil,
                predictedAction: d.action,
                daysUntilMature: max(0, argusDaysToMature - daysSince)
            ))
        }
        
        return pending.sorted { $0.eventDate > $1.eventDate }
    }
}

// MARK: - Scientific Models

struct ScientificStats: Sendable {
    let totalHypotheses: Int
    let validatedHypotheses: Int
    let winRate: Double
    let averageReturn: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let profitFactor: Double
    let lastUpdated: Date
    
    static let empty = ScientificStats(totalHypotheses: 0, validatedHypotheses: 0, winRate: 0, averageReturn: 0, sharpeRatio: 0, maxDrawdown: 0, profitFactor: 0, lastUpdated: Date())
}
