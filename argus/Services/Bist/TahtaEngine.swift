import Foundation

/// TAHTA: Birleşik Teknik Analiz Motoru (BIST ve Global için)
/// OrionBistEngine (SAR, TSI) + BistMoneyFlowEngine (Hacim, A/D) + OrionRelativeStrengthEngine (RS, Beta, Momentum)
/// Hem BIST hem Global sembollerde çalışır.

actor TahtaEngine {
    static let shared = TahtaEngine()

    private init() {}

    // MARK: - Ana Analiz Fonksiyonu (BIST ve Global)

    func analyze(symbol: String) async throws -> TahtaResult {
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")

        // MARK: - Domain Tespiti (BIST vs Global)
        let isBIST = symbol.contains(".IS") || symbol.contains("-IS") || symbol.contains(".TR") || symbol.contains("-TR")

        // MARK: - Veri Çekme

        var candles: [Candle] = []
        var benchmarkCandles: [Candle]? = nil

        if isBIST {
            // BIST için BorsaPy öncelikli
            var bistCandles: [BistCandle] = []
            do {
                let rawData = try await BorsaPyProvider.shared.getBistHistory(symbol: cleanSymbol, days: 60)
                bistCandles = rawData.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                
                if !bistCandles.isEmpty {
                    candles = bistCandles.map {
                        Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume)
                    }
                }
            } catch {
                print("TahtaEngine: BorsaPy başarısız, Heimdall'a fallback...")
            }

            // Fallback: Heimdall (Yahoo)
            if candles.isEmpty {
                do {
                    candles = try await HeimdallOrchestrator.shared.requestCandles(
                        symbol: cleanSymbol,
                        timeframe: "1D",
                        limit: 60
                    )
                } catch {
                    throw TahtaError.dataUnavailable
                }
            }

            // XU100 benchmark (sadece BIST için)
            if let xu100Data = try? await BorsaPyProvider.shared.getBistHistory(symbol: "XU100", days: 60) {
                benchmarkCandles = xu100Data.map {
                    Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume)
                }
            }
        } else {
            // Global için Heimdall (Yahoo/FMP/Alternatif)
            do {
                candles = try await HeimdallOrchestrator.shared.requestCandles(
                    symbol: cleanSymbol,
                    timeframe: "1D",
                    limit: 60
                )
            } catch {
                print("TahtaEngine: Heimdall başarısız, alternatif deneniyor...")
                throw TahtaError.dataUnavailable
            }

            // SPY benchmark (sadece Global için)
            if let spyData = try? await HeimdallOrchestrator.shared.requestCandles(symbol: "SPY", timeframe: "1D", limit: 60) {
                benchmarkCandles = spyData
            }
        }

        guard candles.count >= 30 else {
            throw TahtaError.insufficientData
        }

        // MARK: - Alt Engine Analizleri

        // 4a. OrionBist (SAR, TSI)
        let orionResult: OrionBistResult
        if isBIST {
            // BIST için BistCandle'a dönüştür
            let bistCandlesFormatted = candles.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            orionResult = OrionBistEngine.shared.analyze(candles: bistCandlesFormatted)
        } else {
            // Global için basit Orion analizi
            orionResult = performGlobalOrionAnalysis(candles: candles)
        }

        // 4b. MoneyFlow (sadece BIST)
        let moneyFlowResult: BistMoneyFlowResult?
        if isBIST {
            do {
                moneyFlowResult = try await BistMoneyFlowEngine.shared.analyze(symbol: cleanSymbol)
            } catch {
                moneyFlowResult = nil
            }
        } else {
            moneyFlowResult = nil
        }

        // 4c. RelativeStrength (RS, Beta, Momentum)
        let rsResult: RelativeStrengthResult?
        if let benchmark = benchmarkCandles {
            do {
                if isBIST {
                    rsResult = try await OrionRelativeStrengthEngine.shared.analyze(
                        symbol: cleanSymbol,
                        candles: candles,
                        benchmarkCandles: benchmark
                    )
                } else {
                    // Global için basit relative strength hesapla
                    rsResult = performGlobalRelativeStrength(
                        symbol: cleanSymbol,
                        candles: candles,
                        benchmarkCandles: benchmark
                    )
                }
            } catch {
                rsResult = nil
            }
        } else {
            rsResult = nil
        }

        // 4d. RSI Hesapla
        let closes = candles.map { $0.close }
        let rsiValues = await IndicatorService.calculateRSI(values: closes, period: 14)
        let rsi = rsiValues.last.flatMap { $0 } ?? 50.0

        // MARK: - Birleşik Skor Hesaplama (Ağırlıklı)

        var totalScore: Double = 0
        var componentCount = 0
        var supportingIndicators = 0
        var totalIndicators = 0

        // OrionBist (SAR + TSI): %40 ağırlık
        let orionWeight = 0.40
        totalScore += orionResult.score * orionWeight
        componentCount += 1

        // Orion destekliyor mu?
        totalIndicators += 2 // SAR ve TSI
        if orionResult.signal == .buy {
            supportingIndicators += 2
        } else if orionResult.signal == .hold {
            supportingIndicators += 1
        }

        // MoneyFlow: %30 ağırlık (sadece BIST)
        if let mf = moneyFlowResult {
            let moneyFlowWeight = 0.30
            totalScore += mf.score * moneyFlowWeight
            componentCount += 1

            totalIndicators += 1 // Para Akışı
            if mf.flowStatus == .strongInflow || mf.flowStatus == .inflow {
                supportingIndicators += 1
            }
        }

        // RelativeStrength: %30 ağırlık
        if let rs = rsResult {
            let rsWeight = 0.30
            totalScore += rs.totalScore * rsWeight
            componentCount += 1

            totalIndicators += 3 // RS, Beta, Momentum
            if rs.status == .outperforming {
                supportingIndicators += 3
            } else if rs.status == .stable {
                supportingIndicators += 2
            }
        }

        // Ağırlıkları normalize et
        let normalizationFactor = componentCount > 0 ? (1.0 / Double(componentCount)) * 3.0 : 1.0
        let normalizedScore = min(100, max(0, totalScore * normalizationFactor))

        // MARK: - Birleşik Sinyal Belirleme

        let signal: TahtaSignal
        let confidence: Double

        switch orionResult.signal {
        case .buy:
            let moneyFlowConfirms = moneyFlowResult?.flowStatus == .strongInflow || moneyFlowResult?.flowStatus == .inflow
            let rsConfirms = rsResult?.status == .outperforming

            if moneyFlowConfirms == true && rsConfirms == true {
                signal = .gucluAl
                confidence = min(95, normalizedScore + 15)
            } else if moneyFlowConfirms == true || rsConfirms == true {
                signal = .al
                confidence = normalizedScore
            } else {
                signal = .al
                confidence = max(60, normalizedScore - 10)
            }

        case .sell:
            let moneyFlowConfirms = moneyFlowResult?.flowStatus == .strongOutflow || moneyFlowResult?.flowStatus == .outflow
            let rsConfirms = rsResult?.status == .underperforming

            if moneyFlowConfirms == true && rsConfirms == true {
                signal = .gucluSat
                confidence = min(95, 100 - normalizedScore + 15)
            } else if moneyFlowConfirms == true || rsConfirms == true {
                signal = .sat
                confidence = 100 - normalizedScore
            } else {
                signal = .sat
                confidence = max(60, 100 - normalizedScore - 10)
            }

        case .hold:
            signal = .tut
            confidence = 50 + abs(normalizedScore - 50) * 0.3
        }

        // MARK: - Özet Metin Oluştur

        let summary = generateSummary(
            orion: orionResult,
            moneyFlow: moneyFlowResult,
            rs: rsResult,
            rsi: rsi,
            signal: signal,
            isBIST: isBIST
        )

        // MARK: - Metrikler Listesi

        var metrics: [TahtaMetric] = []

        // SAR
        metrics.append(TahtaMetric(
            name: "SAR",
            value: orionResult.sarStatus,
            icon: "arrow.triangle.swap",
            color: orionResult.sarStatus.contains("AL") ? "green" : "red",
            education: "Parabolic SAR trend yönünü gösterir. SAR AL = Yükseliş, SAR SAT = Düşüş."
        ))

        // TSI
        metrics.append(TahtaMetric(
            name: "TSI",
            value: String(format: "%.1f", orionResult.tsiValue),
            icon: "gauge.with.dots.needle.50percent",
            color: orionResult.tsiValue > 0 ? "green" : "red",
            education: "True Strength Index momentum göstergesidir. >20 güçlü alım, <-20 güçlü satım."
        ))

        // RSI
        metrics.append(TahtaMetric(
            name: "RSI (14)",
            value: String(format: "%.0f", rsi),
            icon: "speedometer",
            color: rsi > 70 ? "red" : (rsi < 30 ? "green" : "yellow"),
            education: "RSI >70 aşırı alım (satış fırsatı), <30 aşırı satım (alım fırsatı) gösterir."
        ))

        // Para Akışı (sadece BIST)
        if let mf = moneyFlowResult {
            metrics.append(TahtaMetric(
                name: "Para Akışı",
                value: mf.flowStatus.rawValue,
                icon: mf.flowStatus.icon,
                color: mf.flowStatus.color,
                education: "Hacim ve A/D bazlı para giriş-çıkış durumu. Giriş = Kurumsal alım sinyali."
            ))

            metrics.append(TahtaMetric(
                name: "Hacim",
                value: "\(String(format: "%.1f", mf.volumeRatio))x",
                icon: "chart.bar.fill",
                color: mf.volumeRatio > 1.2 ? "green" : "gray",
                education: "Güncel hacim / 20 günlük ortalama. >1.2x yüksek ilgi demektir."
            ))
        }

        // RS (varsa)
        if let rs = rsResult {
            metrics.append(TahtaMetric(
                name: "Rölatif Güç",
                value: String(format: "%.2f", rs.relativeStrength),
                icon: "chart.line.uptrend.xyaxis",
                color: rs.relativeStrength > 1.05 ? "green" : (rs.relativeStrength < 0.95 ? "red" : "yellow"),
                education: isBIST ? "XU100'e göre performans. >1.05 endeksi yeniyor, <0.95 endeksin gerisinde." : "Benchmark'a göre performans. >1.05 yeniyor, <0.95 geride kalıyor."
            ))

            metrics.append(TahtaMetric(
                name: "Beta",
                value: String(format: "%.2f", rs.beta),
                icon: "waveform.path.ecg",
                color: rs.beta < 1.0 ? "blue" : "orange",
                education: isBIST ? "Endekse göre volatilite. <1 defansif (düşük risk), >1 agresif (yüksek risk)." : "Piyasa volatilitesine göre risk. <1 defansif, >1 agresif."
            ))

            metrics.append(TahtaMetric(
                name: "Momentum",
                value: String(format: "%+.1f%%", rs.momentum),
                icon: "arrow.up.right",
                color: rs.momentum > 5 ? "green" : (rs.momentum < -5 ? "red" : "yellow"),
                education: "20 günlük fiyat değişimi. >5% güçlü yükseliş, <-5% güçlü düşüş."
            ))
        }

        return TahtaResult(
            symbol: cleanSymbol,
            signal: signal,
            confidence: confidence,
            totalScore: normalizedScore,
            supportCount: supportingIndicators,
            totalIndicators: totalIndicators,
            summary: summary,
            metrics: metrics,
            orionResult: orionResult,
            moneyFlowResult: moneyFlowResult,
            rsResult: rsResult,
            rsi: rsi,
            isBIST: isBIST,
            benchmarkName: isBIST ? "XU100" : "SPY",
            timestamp: Date()
        )
    }

    // MARK: - Global Orion Analizi

    private func performGlobalOrionAnalysis(candles: [Candle]) -> OrionBistResult {
        guard candles.count > 50 else {
            return OrionBistResult(
                score: 0,
                signal: .hold,
                tsiValue: 0,
                sarStatus: "N/A",
                description: "Yetersiz Veri"
            )
        }

        let closes = candles.map { $0.close }
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }

        // TSI hesapla
        let tsi = calculateTSI(closes: closes)
        let currentTSI = tsi.last ?? 0.0

        // Slope hesapla
        let slope = calculateLinearSlope(data: tsi, length: 10)

        // SAR hesapla (basitleştirilmiş global versiyon)
        let sarValues = calculateSAR(highs: highs, lows: lows)
        let currentSAR = sarValues.last ?? 0.0
        let currentClose = closes.last ?? 0.0
        let isSarUp = currentClose > currentSAR

        // Skorlama
        var score: Double = 50.0
        if currentTSI > 0 { score += 10 }
        if currentTSI > 20 { score += 10 }
        else if currentTSI < -20 { score -= 10 }

        if slope > 0 { score += 20 }
        else { score -= 20 }

        if isSarUp { score += 30 }
        else { score -= 30 }

        score = max(0, min(100, score))

        let signal: OrionBistSignal
        if score >= 80 { signal = .buy }
        else if score <= 20 { signal = .sell }
        else { signal = .hold }

        let sarStr = isSarUp ? "SAR AL" : "SAR SAT"
        let tsiStr = String(format: "TSI: %.1f", currentTSI)
        let slopeStr = slope > 0 ? "Momentum Artıyor" : "Momentum Zayıf"

        return OrionBistResult(
            score: score,
            signal: signal,
            tsiValue: currentTSI,
            sarStatus: sarStr,
            description: "\(sarStr) | \(tsiStr) | \(slopeStr)"
        )
    }

    // MARK: - Global Relative Strength

    private func performGlobalRelativeStrength(
        symbol: String,
        candles: [Candle],
        benchmarkCandles: [Candle]
    ) -> RelativeStrengthResult {
        guard candles.count == benchmarkCandles.count && candles.count >= 20 else {
            return RelativeStrengthResult(
                symbol: symbol,
                relativeStrength: 1.0,
                beta: 1.0,
                momentum: 0,
                sector: "Global",
                status: .neutral,
                totalScore: 50,
                metrics: [],
                timestamp: Date()
            )
        }

        let symbolCloses = candles.map { $0.close }
        let benchmarkCloses = benchmarkCandles.map { $0.close }

        // Relative Strength hesapla
        let startPriceIndex = candles.count - 21
        let symbolStartPrice = symbolCloses[startPriceIndex]
        let symbolReturn = (symbolCloses.last! - symbolStartPrice) / symbolStartPrice
        
        let benchmarkStartPrice = benchmarkCloses[startPriceIndex]
        let benchmarkReturn = (benchmarkCloses.last! - benchmarkStartPrice) / benchmarkStartPrice
        
        let relativeStrength: Double
        if benchmarkReturn > 0 {
            relativeStrength = symbolReturn / benchmarkReturn
        } else {
            relativeStrength = 1.0
        }

        // Beta hesapla
        var beta = 1.0
        if benchmarkCloses.count >= 20 {
            let symbolReturns = calculateReturns(closes: symbolCloses)
            let benchmarkReturns = calculateReturns(closes: benchmarkCloses)

            if !benchmarkReturns.isEmpty {
                let cov = zip(symbolReturns, benchmarkReturns).map { $0 * $1 }.reduce(0.0, +)
                let covariance = cov / Double(benchmarkReturns.count)
                
                let benchmarkVarSum = benchmarkReturns.map { $0 * $0 }.reduce(0.0, +)
                let benchmarkVariance = benchmarkVarSum / Double(benchmarkReturns.count)
                
                beta = benchmarkVariance > 0 ? covariance / benchmarkVariance : 1.0
            }
        }

        // Momentum (20 günlük)
        let momentum = (symbolCloses.last! - symbolStartPrice) / symbolStartPrice * 100.0

        let status: RSStatus
        if relativeStrength > 1.1 {
            status = .outperforming
        } else if relativeStrength < 0.9 {
            status = .underperforming
        } else {
            status = .stable
        }

        let totalScore = 50 + (relativeStrength - 1.0) * 20 + (beta < 1.0 ? 10 : -10) + (momentum > 5 ? 10 : (momentum < -5 ? -10 : 0))

        return RelativeStrengthResult(
            symbol: symbol,
            relativeStrength: relativeStrength,
            beta: max(0.5, min(3.0, beta)),
            momentum: momentum,
            sector: "Global",
            status: status,
            totalScore: max(0, min(100, totalScore)),
            metrics: [],
            timestamp: Date()
        )
    }

    private func calculateReturns(closes: [Double]) -> [Double] {
        guard closes.count > 1 else { return [] }
        var returns: [Double] = []
        for i in 1..<closes.count {
            let ret = (closes[i] - closes[i-1]) / closes[i-1]
            returns.append(ret)
        }
        return returns
    }

    // MARK: - Yardımcı Fonksiyonlar (TSI, Slope, SAR)

    private func calculateTSI(closes: [Double], long: Int = 9, short: Int = 3) -> [Double] {
        guard closes.count > long + short else { return [] }
        var pc: [Double] = []
        for i in 1..<closes.count {
            pc.append(closes[i] - closes[i-1])
        }

        let emaLong = ema(data: pc, period: long)
        let emaShort = ema(data: pc, period: short)

        var tsiValues: [Double] = []
        for i in 0..<emaLong.count {
            let value = 25 * (emaLong[i] / (abs(emaLong[i]) + 0.00001)) * (emaShort[i] / (abs(emaShort[i]) + 0.00001))
            tsiValues.append(value)
        }

        return tsiValues
    }

    private func calculateLinearSlope(data: [Double], length: Int) -> Double {
        guard data.count >= length else { return 0 }
        let recentData = Array(data.suffix(length))

        let n = Double(recentData.count)
        let sumX = (0..<recentData.count).reduce(0.0) { $0 + Double($1) }
        let sumY = recentData.reduce(0.0, +)
        let sumXY = zip(0..<recentData.count, recentData).map { Double($0) * $1 }.reduce(0.0, +)
        let sumX2 = (0..<recentData.count).map { Double($0) * Double($0) }.reduce(0.0, +)

        let denominator = (n * sumX2) - (sumX * sumX)
        return denominator != 0 ? ((n * sumXY) - (sumX * sumY)) / denominator : 0
    }

    private func calculateSAR(highs: [Double], lows: [Double], afStart: Double = 0.02, afInc: Double = 0.02, afMax: Double = 0.2) -> [Double] {
        guard highs.count == lows.count && !highs.isEmpty else { return [] }
        var sarValues: [Double] = []
        var isUp = true
        var ep = highs[0]
        var af = afStart

        for i in 0..<highs.count {
            let high = highs[i]
            let low = lows[i]

            if isUp {
                ep = max(ep, high)
            } else {
                ep = min(ep, low)
            }

            let sar = ep + af * (ep - (sarValues.last ?? ep))

            if high == ep {
                isUp = true
            } else if low == ep {
                isUp = false
            }

            if isUp {
                af = min(af + afInc, afMax)
            } else {
                af = min(af + afInc * 2.0, afMax)
            }

            sarValues.append(sar)
        }

        return sarValues
    }

    private func ema(data: [Double], period: Int) -> [Double] {
        guard data.count >= period else { return data }

        var emaValues: [Double] = []
        var ema = data[0]

        for i in 0..<data.count {
            if i >= period {
                ema = (data[i] - ema) * (2.0 / Double(period + 1)) + ema
            }
            emaValues.append(ema)
        }

        return emaValues
    }

    // MARK: - Özet Metin Üreteci

    private func generateSummary(
        orion: OrionBistResult,
        moneyFlow: BistMoneyFlowResult?,
        rs: RelativeStrengthResult?,
        rsi: Double,
        signal: TahtaSignal,
        isBIST: Bool
    ) -> String {
        var parts: [String] = []

        let domain = isBIST ? "BIST" : "Global"
        parts.append("Teknik analiz (\(domain)):")

        // Ana sinyal
        switch signal {
        case .gucluAl:
            parts.append("Tüm göstergeler uyumlu: GÜÇLÜ ALIM fırsatı.")
        case .al:
            parts.append("Teknik görünüm olumlu: ALIM yönünde sinyal.")
        case .gucluSat:
            parts.append("Tüm göstergeler uyumsuz: GÜÇLÜ SATIŞ sinyali.")
        case .sat:
            parts.append("Teknik görünüm olumsuz: SATIŞ yönünde sinyal.")
        case .tut:
            parts.append("Kararsız piyasa: BEKLE/TUT önerisi.")
        }

        // TSI durumu
        if orion.tsiValue > 20 {
            parts.append("Momentum güçlü.")
        } else if orion.tsiValue < -20 {
            parts.append("Momentum zayıf.")
        }

        // RSI uyarıları
        if rsi > 70 {
            parts.append("RSI aşırı alım bölgesinde - düzeltme riski.")
        } else if rsi < 30 {
            parts.append("RSI aşırı satım bölgesinde - tepki potansiyeli.")
        }

        // Para akışı (sadece BIST)
        if let mf = moneyFlow {
            switch mf.flowStatus {
            case .strongInflow:
                parts.append("Güçlü kurumsal alım tespit edildi.")
            case .inflow:
                parts.append("Para girişi devam ediyor.")
            case .strongOutflow:
                parts.append("Yoğun satış baskısı mevcut.")
            case .outflow:
                parts.append("Para çıkışı gözlemleniyor.")
            case .neutral:
                break
            }
        }

        // RS durumu
        if let rs = rs {
            switch rs.status {
            case .outperforming:
                parts.append(isBIST ? "Endeksi yeniyor." : "Benchmark'u yeniyor.")
            case .underperforming:
                parts.append(isBIST ? "Endeksin gerisinde." : "Benchmark'un gerisinde kalıyor.")
            case .stable:
                parts.append("Benchmark ile paralel performans.")
            default:
                break
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Errors

    enum TahtaError: Error {
        case dataUnavailable
        case insufficientData
    }
}

// MARK: - Models

enum TahtaSignal: String, Sendable {
    case gucluAl = "GÜÇLÜ AL"
    case al = "AL"
    case tut = "TUT"
    case sat = "SAT"
    case gucluSat = "GÜÇLÜ SAT"

    var color: String {
        switch self {
        case .gucluAl: return "green"
        case .al: return "mint"
        case .tut: return "yellow"
        case .sat: return "orange"
        case .gucluSat: return "red"
        }
    }

    var icon: String {
        switch self {
        case .gucluAl: return "arrow.up.circle.fill"
        case .al: return "arrow.up.right.circle"
        case .tut: return "pause.circle"
        case .sat: return "arrow.down.right.circle"
        case .gucluSat: return "arrow.down.circle.fill"
        }
    }
}

struct TahtaResult: Sendable {
    let symbol: String
    let signal: TahtaSignal
    let confidence: Double
    let totalScore: Double
    let supportCount: Int
    let totalIndicators: Int
    let summary: String
    let metrics: [TahtaMetric]

    // Alt bileşen sonuçları
    let orionResult: OrionBistResult
    let moneyFlowResult: BistMoneyFlowResult?
    let rsResult: RelativeStrengthResult?
    let rsi: Double

    // Yeni alanlar
    let isBIST: Bool
    let benchmarkName: String
    let timestamp: Date

    var supportRatio: String {
        return "\(supportCount)/\(totalIndicators)"
    }
}

struct TahtaMetric: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let value: String
    let icon: String
    let color: String
    let education: String
}
