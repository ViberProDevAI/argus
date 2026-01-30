import Foundation

class TimeSeriesModelService {
    
    // MARK: - Configuration
    private let buyThreshold: Double = 0.015 // %1.5 Beklenen Getiri Eşiği
    private let sellThreshold: Double = -0.015 // -%1.5 Beklenen Getiri Eşiği
    private let minConfidence: Double = 0.60 // %60 Minimum Güven
    
    // MARK: - Main Analysis Method
    
    func analyze(candles: [Candle]) -> Signal? {
        // Yeterli veri yoksa analiz yapma
        guard candles.count >= 30 else { return nil }
        
        // 1. Feature Engineering (Özellik Çıkarımı)
        let features = extractFeatures(candles: candles)
        
        // 2. Model Inference (Tahminleme)
        // Gerçek hayatta burası CoreML modelini çağırır.
        let prediction = runDummyModel(features: features)
        
        // 3. Decision Logic (Karar Mekanizması)
        return createSignal(from: prediction)
    }
    
    // MARK: - Feature Engineering
    
    private struct ModelFeatures {
        let momentum: Double
        let volatility: Double
        let rsi: Double
        let trendStrength: Double
    }
    
    private func extractFeatures(candles: [Candle]) -> ModelFeatures {
        let prices = candles.map { $0.close }
        let lastPrice = prices.last ?? 0
        let prevPrice = prices.dropLast().last ?? 0
        
        // Feature 1: Momentum (Son 5 barın değişimi)
        let momentum = (lastPrice - prevPrice) / prevPrice
        
        // Feature 2: Volatility (Son 10 barın standart sapması / ortalama)
        let recentPrices = prices.suffix(10)
        let mean = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let sumSquaredDiff = recentPrices.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(recentPrices.count))
        let volatility = stdDev / mean
        
        // Feature 3: RSI (Basitleştirilmiş)
        // Not: Gerçek RSI hesaplaması AnalysisService'de var, burada model için
        // hızlı bir feature olarak tekrar hesaplıyoruz veya oradan alabiliriz.
        // Bağımsız olması için basitçe hesaplayalım.
        let rsi = calculateSimpleRSI(prices: prices)
        
        // Feature 4: Trend Strength (SMA farkı)
        let smaShort = prices.suffix(10).reduce(0, +) / 10.0
        let smaLong = prices.suffix(30).reduce(0, +) / 30.0
        let trendStrength = (smaShort - smaLong) / smaLong
        
        return ModelFeatures(
            momentum: momentum,
            volatility: volatility,
            rsi: rsi,
            trendStrength: trendStrength
        )
    }
    
    // MARK: - Dummy Model (Inference)
    
    private struct Prediction {
        let expectedReturn: Double // Örn: 0.02 (%2)
        let confidence: Double     // Örn: 0.75 (%75)
    }
    
    private func runDummyModel(features: ModelFeatures) -> Prediction {
        // BURASI DUMMY MODEL KATMANIDIR
        // Gerçekte: let output = coreMLModel.prediction(input: features)
        
        // Basit bir deterministik mantık kuralım:
        
        // 1. Beklenen Getiri Hesabı:
        // Momentum pozitifse ve Trend pozitifse getiri beklentisi artar.
        // RSI aşırı satımdaysa (düşükse) tepki yükselişi beklentisi artar (mean reversion).
        
        var expectedReturn = 0.0
        
        // Trend Katkısı
        expectedReturn += features.trendStrength * 0.5
        
        // Mean Reversion Katkısı (RSI)
        if features.rsi < 30 {
            expectedReturn += 0.02 // Tepki alımı bekleniyor
        } else if features.rsi > 70 {
            expectedReturn -= 0.02 // Düzeltme bekleniyor
        }
        
        // Momentum Katkısı
        expectedReturn += features.momentum * 0.2
        
        // 2. Güven Skoru Hesabı:
        // Volatilite düşükse güven artar.
        // Trend güçlüyse güven artar.
        
        var confidence = 0.50 // Baz güven
        
        if features.volatility < 0.01 { confidence += 0.20 } // Düşük volatilite = Yüksek güven
        if abs(features.trendStrength) > 0.02 { confidence += 0.15 } // Güçlü trend = Yüksek güven
        
        // Sınırlandırma
        confidence = min(max(confidence, 0.0), 1.0)
        
        return Prediction(expectedReturn: expectedReturn, confidence: confidence)
    }
    
    // MARK: - Signal Generation
    
    private func createSignal(from prediction: Prediction) -> Signal? {
        var action: SignalAction = .hold
        var reason = ""
        
        let expReturnPercent = prediction.expectedReturn * 100
        let confPercent = prediction.confidence * 100
        
        // Karar Mantığı
        if prediction.expectedReturn > buyThreshold && prediction.confidence > minConfidence {
            action = .buy
            reason = String(format: "Model, önümüzdeki periyot için %%%.2f pozitif getiri bekliyor (Güven: %%%.0f). Trend ve momentum verileri yükselişi destekliyor.", expReturnPercent, confPercent)
        } else if prediction.expectedReturn < sellThreshold && prediction.confidence > minConfidence {
            action = .sell
            reason = String(format: "Model, önümüzdeki periyot için %%%.2f negatif getiri (düşüş) bekliyor (Güven: %%%.0f). Aşırı alım veya negatif trend tespit edildi.", expReturnPercent, confPercent)
        } else {
            action = .hold
            reason = String(format: "Modelin getiri beklentisi (%%%.2f) veya güven seviyesi (%%%.0f) işlem açmak için yeterli eşiğe ulaşmadı.", expReturnPercent, confPercent)
        }
        
        return Signal(
            strategyName: "AI Zaman Serisi Modeli",
            action: action,
            confidence: confPercent,
            reason: reason,
            indicatorValues: [
                "Exp. Return": String(format: "%%%.2f", expReturnPercent),
                "Confidence": String(format: "%%%.0f", confPercent)
            ],
            logic: "Son 30 barın fiyat, hacim ve volatilite verilerini analiz ederek bir sonraki barın kapanışını istatistiksel olarak tahmin eder.",
            successContext: "Yüksek hacimli ve trend yapan piyasalarda, klasik indikatörlerin geciktiği durumlarda erken sinyal üretebilir.",
            simplifiedExplanation: "Bu strateji, geçmiş fiyat hareketlerini inceleyen bir Yapay Zeka modelidir.\n\n• Model, geleceği tahmin etmeye çalışır.\n• Eğer fiyatın yükseleceğinden çok eminse (%60+ Güven) ve getiri beklentisi yüksekse (>%1.5) AL der.\n• Tam tersi durumda SAT der.\n• Emin değilse BEKLE der."
        )
    }
    
    // MARK: - Helpers
    
    private func calculateSimpleRSI(prices: [Double]) -> Double {
        guard prices.count > 14 else { return 50 }
        // Basit RSI implementasyonu (AnalysisService'den bağımsız)
        // ... (Buraya gerekirse kod eklenebilir, şimdilik dummy 50 dönelim veya basit hesap yapalım)
        // Hızlıca son 14 bar için:
        let period = 14
        let changes = zip(prices.dropFirst(), prices).map { $0 - $1 }
        let gains = changes.map { max($0, 0) }
        let losses = changes.map { max(-$0, 0) }
        
        let avgGain = gains.suffix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.suffix(period).reduce(0, +) / Double(period)
        
        if avgLoss == 0 { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
}
