import Foundation

// MARK: - BIST MoneyFlow Engine
// Hacim analizi ve para akışı tespiti
// Kurumsal/yabancı akış göstergeleri

actor BistMoneyFlowEngine {
    static let shared = BistMoneyFlowEngine()
    
    private init() {}
    
    // MARK: - Sembol Bazlı Analiz
    
    func analyze(symbol: String) async throws -> BistMoneyFlowResult {
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
        
        // Verileri Çek
        let history = try await BorsaPyProvider.shared.getBistHistory(symbol: cleanSymbol, days: 30)
        let quote = try? await BorsaPyProvider.shared.getBistQuote(symbol: cleanSymbol)
        
        guard history.count >= 5 else {
            throw MoneyFlowError.insufficientData
        }
        
        // Göstergeleri Hesapla
        let volumeAnalysis = analyzeVolume(history)
        let priceVolumeRelation = analyzePriceVolumeRelation(history)
        let accumulationDistribution = calculateADIndicator(history)
        
        // Toplam Skor
        var totalScore: Double = 50
        var signals: [MoneyFlowSignal] = []
        
        // Flow Status Hesapla (A/D ve Hacim bazlı)
        let flowStatus: FlowStatus
        if accumulationDistribution > BistThresholds.MoneyFlow.inflowAD && volumeAnalysis.volumeRatio > BistThresholds.MoneyFlow.criticalVolumeRatio {
            flowStatus = .strongInflow
            totalScore += BistThresholds.MoneyFlow.strongScore
        } else if accumulationDistribution > BistThresholds.MoneyFlow.neutralADUpper {
            flowStatus = .inflow
            totalScore += BistThresholds.MoneyFlow.normalScore
        } else if accumulationDistribution < BistThresholds.MoneyFlow.outflowAD && volumeAnalysis.volumeRatio > BistThresholds.MoneyFlow.criticalVolumeRatio {
            flowStatus = .strongOutflow
            totalScore -= BistThresholds.MoneyFlow.strongScore
        } else if accumulationDistribution < 0 {
            flowStatus = .outflow
            totalScore -= BistThresholds.MoneyFlow.normalScore
        } else {
            flowStatus = .neutral
        }
        
        // Analysis Metrics Oluştur
        var metrics: [AnalysisMetric] = []
        
        // 1. Hacim Metriği
        metrics.append(AnalysisMetric(
            label: "Hacim Çarpanı",
            value: "\(String(format: "%.1f", volumeAnalysis.volumeRatio))x",
            context: volumeAnalysis.volumeRatio > 1.2 ? "Ortalama Üzeri" : "Normal",
            scoreImpact: 0,
            education: "Hacim, fiyat hareketinin yakıtıdır. Yüksek hacimle gerçekleşen yükselişler daha güvenilirdir. Mevcut hacim 20 günlük ortalamanın \(String(format: "%.1f", volumeAnalysis.volumeRatio)) katı."
        ))
        
        // 2. Fiyat-Hacim Metriği
        let pvText: String
        let pvEdu: String
        switch priceVolumeRelation {
        case .accumulation:
            pvText = "Birikim (Alım)"
            pvEdu = "Fiyat yükselirken hacim artıyor. Bu, 'Akıllı Para'nın mal topladığını gösterir."
        case .distribution:
            pvText = "Dağıtım (Satış)"
            pvEdu = "Fiyat düşerken hacim artıyor. Büyük oyuncular ellerindeki malı satıyor olabilir."
        case .weakRally:
            pvText = "Zayıf Yükseliş"
            pvEdu = "Fiyat yükseliyor ama hacim düşüyor. Bu yükselişin devamı gelmeyebilir (Boğa Tuzağı)."
        case .weakDecline:
            pvText = "Zayıf Düşüş"
            pvEdu = "Fiyat düşüyor ama hacim zayıf. Satıcılar isteksiz, düşüş trendi sonlanabilir."
        case .neutral:
            pvText = "Nötr"
            pvEdu = "Fiyat ve hacim arasında belirgin bir uyumsuzluk veya trend sinyali yok."
        }
        metrics.append(AnalysisMetric(
            label: "Fiyat/Hacim İlişkisi",
            value: pvText,
            context: "Trend Sinyali",
            scoreImpact: 0,
            education: pvEdu
        ))
        
        // 3. A/D (Para Akışı) Metriği
        metrics.append(AnalysisMetric(
            label: "Para Akış Endeksi (A/D)",
            value: String(format: "%.2f", accumulationDistribution),
            context: accumulationDistribution > 0 ? "Pozitif" : "Negatif",
            scoreImpact: 0,
            education: "Accumulation/Distribution göstergesi, paranın hisseye girip girmediğini ölçer. Sıfırın üzeri para girişini işaret eder."
        ))
        
        return BistMoneyFlowResult(
            symbol: cleanSymbol,
            score: min(100, max(0, totalScore)),
            flowStatus: flowStatus,
            volumeRatio: volumeAnalysis.volumeRatio,
            avgVolume: volumeAnalysis.avgVolume,
            todayVolume: quote?.volume ?? 0,
            signals: signals,
            metrics: metrics, // NEW
            timestamp: Date()
        )
    }
    
    // MARK: - Hacim Analizi
    
    private func analyzeVolume(_ candles: [BorsaPyCandle]) -> (volumeRatio: Double, avgVolume: Double) {
        guard candles.count >= 5, let lastCandle = candles.last else {
            return (1.0, 0)
        }

        // Son 20 günün ortalama hacmi
        let recentCandles = Array(candles.suffix(min(20, candles.count)))
        let divisor = max(1, recentCandles.count - 1)
        let avgVolume = recentCandles.dropLast().map { $0.volume }.reduce(0, +) / Double(divisor)

        // Bugünkü hacim / ortalama (division by zero koruması)
        let todayVolume = lastCandle.volume
        let ratio = avgVolume > 0 ? todayVolume / avgVolume : 1.0

        return (ratio, avgVolume)
    }
    
    // MARK: - Fiyat-Hacim İlişkisi
    
    private func analyzePriceVolumeRelation(_ candles: [BorsaPyCandle]) -> PriceVolumeRelation {
        guard candles.count >= 5 else { return .neutral }

        let recent = Array(candles.suffix(5))

        // Güvenli erişim
        guard let lastCandle = recent.last,
              let firstCandle = recent.first,
              firstCandle.close > 0 else {
            return .neutral
        }

        // Son 5 günün fiyat ve hacim değişimi (division by zero koruması)
        let priceChange = (lastCandle.close - firstCandle.close) / firstCandle.close
        let volumeChange = firstCandle.volume > 0
            ? (lastCandle.volume - firstCandle.volume) / firstCandle.volume
            : 0
        
        if priceChange > BistThresholds.MoneyFlow.priceChangeSignificant && volumeChange > BistThresholds.MoneyFlow.volumeChangeSignificant {
            return .accumulation // Fiyat↑ Hacim↑ = Birikim
        } else if priceChange < -BistThresholds.MoneyFlow.priceChangeSignificant && volumeChange > BistThresholds.MoneyFlow.volumeChangeSignificant {
            return .distribution // Fiyat↓ Hacim↑ = Dağıtım
        } else if priceChange > BistThresholds.MoneyFlow.priceChangeSignificant && volumeChange < -BistThresholds.MoneyFlow.volumeChangeSignificant {
            return .weakRally // Fiyat↑ Hacim↓ = Zayıf Yükseliş
        } else if priceChange < -BistThresholds.MoneyFlow.priceChangeSignificant && volumeChange < -BistThresholds.MoneyFlow.volumeChangeSignificant {
            return .weakDecline // Fiyat↓ Hacim↓ = Zayıf Düşüş
        }
        
        return .neutral
    }
    
    // MARK: - A/D Göstergesi
    
    private func calculateADIndicator(_ candles: [BorsaPyCandle]) -> Double {
        guard candles.count >= 10 else { return 0 }
        
        var adValues: [Double] = []
        
        for candle in candles.suffix(10) {
            let range = candle.high - candle.low
            guard range > 0 else { continue }
            
            // Money Flow Multiplier: ((Close - Low) - (High - Close)) / (High - Low)
            let mfm = ((candle.close - candle.low) - (candle.high - candle.close)) / range
            adValues.append(mfm)
        }
        
        // Ortalama
        return adValues.isEmpty ? 0 : adValues.reduce(0, +) / Double(adValues.count)
    }
    
    enum MoneyFlowError: Error {
        case insufficientData
    }
}

// MARK: - Modeller

struct BistMoneyFlowResult: Sendable {
    let symbol: String
    let score: Double
    let flowStatus: FlowStatus
    let volumeRatio: Double
    let avgVolume: Double
    let todayVolume: Double
    let signals: [MoneyFlowSignal]
    let metrics: [AnalysisMetric] // NEW
    let timestamp: Date
}

struct MoneyFlowSignal: Sendable, Identifiable {
    var id: String { type.rawValue }
    let type: MoneyFlowSignalType
    let description: String
}

enum MoneyFlowSignalType: String, Sendable {
    case highVolume = "Yüksek Hacim"
    case risingVolume = "Artan Hacim"
    case lowVolume = "Düşük Hacim"
    case accumulation = "Birikim"
    case distribution = "Dağıtım"
    case bullishFlow = "Pozitif Akış"
    case bearishFlow = "Negatif Akış"
}

enum FlowStatus: String, Sendable {
    case strongInflow = "Güçlü Giriş"
    case inflow = "Para Girişi"
    case neutral = "Nötr"
    case outflow = "Para Çıkışı"
    case strongOutflow = "Güçlü Çıkış"
    
    var color: String {
        switch self {
        case .strongInflow: return "green"
        case .inflow: return "mint"
        case .neutral: return "yellow"
        case .outflow: return "orange"
        case .strongOutflow: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .strongInflow, .inflow: return "arrow.down.circle.fill"
        case .neutral: return "equal.circle.fill"
        case .outflow, .strongOutflow: return "arrow.up.circle.fill"
        }
    }
}

enum PriceVolumeRelation {
    case accumulation  // Fiyat↑ Hacim↑
    case distribution  // Fiyat↓ Hacim↑
    case weakRally     // Fiyat↑ Hacim↓
    case weakDecline   // Fiyat↓ Hacim↓
    case neutral
}
