import Foundation
import Combine
import SwiftUI

// MARK: - MODELS

/// Orion analiz pipeline'ının hangi durumda bittiğini kullanıcıya göstermek için.
enum OrionFailureReason: Equatable {
    case networkUnavailable
    case rateLimited
    case symbolInvalid
    case emptyData
    case providerError(String)

    var userTitle: String {
        switch self {
        case .networkUnavailable: return "Bağlantı yok"
        case .rateLimited: return "Sağlayıcı geçici olarak kilitli"
        case .symbolInvalid: return "Sembol bulunamadı"
        case .emptyData: return "Yeterli veri yok"
        case .providerError: return "Veri sağlayıcısı hata döndürdü"
        }
    }

    var userDetail: String {
        switch self {
        case .networkUnavailable:
            return "Heimdall Yahoo kanalına ulaşamadı. Ağ bağlantını kontrol edip tekrar dene."
        case .rateLimited:
            return "Yahoo kanalı art arda hata verdi ve kısa süreliğine devre dışı. 30-60 saniye sonra yenile."
        case .symbolInvalid:
            return "Yahoo bu sembolü tanımadı. BIST hisseleri için sonuna \".IS\" ekli olduğundan emin ol."
        case .emptyData:
            return "Sembol var ama mum verisi yok (yeni listeleme veya kapalı piyasa olabilir)."
        case .providerError(let detail):
            return "Sağlayıcı mesajı: \(detail)"
        }
    }
}

/// Analizin ne kadar sağlam veriye dayandığını ifade eder.
enum OrionSourceQuality: Equatable {
    case full                                 // 6/6 timeframe kendi verisinde
    case partial(missed: [TimeframeMode])     // ≥1 başarılı ama bazıları fallback
    case unavailable                          // 0 başarılı — analiz yok
}

/// Holds analysis results for multiple timeframes to enable strategic decision making.
struct MultiTimeframeAnalysis {
    let m5: OrionScoreResult
    let m15: OrionScoreResult
    let h1: OrionScoreResult
    let h4: OrionScoreResult
    let daily: OrionScoreResult
    let weekly: OrionScoreResult
    /// Timeframe button -> gerçek skorun üretildiği kaynak timeframe
    let sourceTimeframes: [TimeframeMode: TimeframeMode]
    /// Argus konsey kararında baz alınan teknik zaman dilimi.
    let argusReportingTimeframe: TimeframeMode
    let generatedAt: Date
    /// 6 timeframe'in kaçı orijinal verisiyle geldi.
    let sourceQuality: OrionSourceQuality
    
    // Legacy support
    var intraday: OrionScoreResult { h4 }

    // Timeframe accessor for dynamic selection
    func scoreFor(timeframe: TimeframeMode) -> OrionScoreResult {
        switch timeframe {
        case .m5: return m5
        case .m15: return m15
        case .h1: return h1
        case .h4: return h4
        case .daily: return daily
        case .weekly: return weekly
        }
    }

    func sourceFor(timeframe: TimeframeMode) -> TimeframeMode {
        sourceTimeframes[timeframe] ?? timeframe
    }

    func isFallback(timeframe: TimeframeMode) -> Bool {
        sourceFor(timeframe: timeframe) != timeframe
    }

    // Strategic Synthesis (The "Brain" Advice)
    var strategicAdvice: String {
        if daily.score > 60 && h4.score > 60 {
            return "Tam Gaz İleri: Hem ana trend hem kısa vade momentumu seni destekliyor."
        } else if daily.score > 60 && h4.score < 40 {
            return "Fırsat Kollama: Ana trend yukarı ama kısa vade düzeltmede. Dönüş bekle ve AL."
        } else if daily.score < 40 && h4.score > 60 {
            return "Tuzak Uyarısı: Ölü kedi sıçraması olabilir. Ana trend hala düşüşte."
        } else {
            return "Uzak Dur: Piyasa her vadede negatif."
        }
    }
}

// MARK: - STORE

/// Orion Store (State Layer) 🏛️
/// Manages Multi-Timeframe Technical Analysis.
@MainActor
final class OrionStore: ObservableObject {
    static let shared = OrionStore()
    
    // MARK: - State
    @Published var analysis: [String: MultiTimeframeAnalysis] = [:]
    @Published var isLoading: Bool = false
    /// Sembol bazlı son hata — başarılı analizden sonra temizlenir.
    @Published var lastFailureReason: [String: OrionFailureReason] = [:]

    private init() {}

    // MARK: - Actions

    /// Triggers a robust multi-timeframe analysis.
    /// - Parameter forceRefresh: true ise freshness check atlanır (retry butonu için).
    func ensureAnalysis(for symbol: String, forceRefresh: Bool = false) async {
        // 1. Freshness Check (5 mins)
        if !forceRefresh,
           let existing = analysis[symbol],
           Date().timeIntervalSince(existing.generatedAt) < 300 {
            return
        }

        self.isLoading = true
        defer { self.isLoading = false }

        // 2. Parallel Data Fetching & Analysis
        print("🧠 OrionStore: Starting MTF Analysis for \(symbol) (6 Timeframes)...")

        // Timeframes to fetch
        let timeframes: [(String, String)] = [
            ("m5", "5m"),
            ("m15", "15m"),
            ("h1", "1h"),
            ("h4", "4h"),
            ("daily", "1day"),
            ("weekly", "1week")
        ]

        // TaskGroup: her timeframe için (key, skor?, hata-sebep?) döner.
        // Sebep alanı sadece başarısız timeframe'lerde dolu.
        let outcomes = await withTaskGroup(of: (String, OrionScoreResult?, OrionFailureReason?).self) { group -> [(String, OrionScoreResult?, OrionFailureReason?)] in

            for (key, tfParam) in timeframes {
                group.addTask {
                    let dataValue = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: tfParam)
                    if let data = dataValue.value, !data.isEmpty {
                        let analysisCandles: [Candle]
                        if key == "h4" {
                            // Yahoo 4h native desteklemediği için 1h veriyi 4h barlara topluyoruz.
                            analysisCandles = OrionStore.aggregateCandles(data, bucketSize: 4)
                        } else {
                            analysisCandles = data
                        }

                        // SPY Benchmark only for Daily/Weekly
                        let spyTimeframe: String?
                        if key == "weekly" {
                            spyTimeframe = "1week"
                        } else if key == "daily" {
                            spyTimeframe = "1day"
                        } else {
                            spyTimeframe = nil
                        }
                        var spyCandles: [Candle]? = nil

                        if let spyTf = spyTimeframe {
                            spyCandles = await MarketDataStore.shared.ensureCandles(symbol: "SPY", timeframe: spyTf).value
                        }

                        let score = await OrionAnalysisService.shared.calculateOrionScoreAsync(
                            symbol: symbol,
                            candles: analysisCandles,
                            spyCandles: spyCandles
                        )
                        return (key, score, nil)
                    }

                    // Başarısız: hata sebebini sağlayıcının evidence metninden sınıflandır.
                    let detail = dataValue.provenance.evidence ?? ""
                    let reason: OrionFailureReason
                    if dataValue.value != nil {
                        // Value var ama boş array → mum üretilmemiş.
                        reason = .emptyData
                    } else {
                        reason = OrionStore.classifyFailure(detail: detail)
                    }
                    return (key, nil, reason)
                }
            }

            var collected: [(String, OrionScoreResult?, OrionFailureReason?)] = []
            for await outcome in group {
                collected.append(outcome)
            }
            return collected
        }

        // Başarılı skorları ve hata sebeplerini ayrıştır.
        var results: [String: OrionScoreResult] = [:]
        var failures: [String: OrionFailureReason] = [:]
        for (key, score, reason) in outcomes {
            if let score {
                results[key] = score
            } else if let reason {
                failures[key] = reason
            }
        }

        // 3. Fallback Logic (Per-timeframe nearest fallback; UI bu fallback'i görebilir)
        let keyToMode: [String: TimeframeMode] = [
            "m5": .m5,
            "m15": .m15,
            "h1": .h1,
            "h4": .h4,
            "daily": .daily,
            "weekly": .weekly
        ]
        let fallbackOrder: [String: [String]] = [
            "m5": ["m5", "m15", "h1", "h4", "daily", "weekly"],
            "m15": ["m15", "m5", "h1", "h4", "daily", "weekly"],
            "h1": ["h1", "m15", "h4", "daily", "weekly", "m5"],
            "h4": ["h4", "h1", "daily", "weekly", "m15", "m5"],
            "daily": ["daily", "h4", "h1", "weekly", "m15", "m5"],
            "weekly": ["weekly", "daily", "h4", "h1", "m15", "m5"]
        ]

        func resolved(for key: String) -> (score: OrionScoreResult, source: TimeframeMode)? {
            guard let order = fallbackOrder[key] else { return nil }
            for candidate in order {
                if let score = results[candidate], let sourceMode = keyToMode[candidate] {
                    return (score, sourceMode)
                }
            }
            return nil
        }

        guard
            let m5Resolved = resolved(for: "m5"),
            let m15Resolved = resolved(for: "m15"),
            let h1Resolved = resolved(for: "h1"),
            let h4Resolved = resolved(for: "h4"),
            let dailyResolved = resolved(for: "daily"),
            let weeklyResolved = resolved(for: "weekly")
        else {
            // Hiçbir timeframe kullanılabilir veri üretemedi → kullanıcıya sebebi söyle.
            let reason = OrionStore.dominantFailure(in: failures)
            self.lastFailureReason[symbol] = reason
            print("⚠️ OrionStore: \(symbol) analiz başarısız — \(reason.userTitle): \(reason.userDetail)")
            return
        }

        // Orijinal timeframe yerine fallback'a düşen var mı? (Kaynak kalitesi)
        let sourceMap: [TimeframeMode: TimeframeMode] = [
            .m5: m5Resolved.source,
            .m15: m15Resolved.source,
            .h1: h1Resolved.source,
            .h4: h4Resolved.source,
            .daily: dailyResolved.source,
            .weekly: weeklyResolved.source
        ]
        let missedOriginals = TimeframeMode.allCases.filter { mode in
            (sourceMap[mode] ?? mode) != mode
        }
        let sourceQuality: OrionSourceQuality = missedOriginals.isEmpty ? .full : .partial(missed: missedOriginals)

        let finalAnalysis = MultiTimeframeAnalysis(
            m5: m5Resolved.score,
            m15: m15Resolved.score,
            h1: h1Resolved.score,
            h4: h4Resolved.score,
            daily: dailyResolved.score,
            weekly: weeklyResolved.score,
            sourceTimeframes: sourceMap,
            argusReportingTimeframe: .daily,
            generatedAt: Date(),
            sourceQuality: sourceQuality
        )

        for mode in missedOriginals {
            let source = finalAnalysis.sourceFor(timeframe: mode)
            print("⚠️ OrionStore: \(symbol) \(mode.displayLabel) fallback -> \(source.displayLabel)")
        }

        self.analysis[symbol] = finalAnalysis
        self.lastFailureReason[symbol] = nil  // Başarılı analiz → eski hatayı temizle.

        // Sync with SignalStateViewModel for UI binding
        SignalStateViewModel.shared.orionAnalysis[symbol] = finalAnalysis

        // Entry setup hesapla — conviction "evet" dedi, şimdi "ne zaman/hangi fiyattan" sorusunu yanıtla.
        // Fire-and-forget: Orion senkron kalsın, setup biraz sonra UI'a düşsün.
        Task { [finalAnalysis] in
            await EntryStore.shared.computeSetup(for: symbol, analysis: finalAnalysis)
        }

        print("🧠 OrionStore: Logic Synthesis Complete. Advice: \(finalAnalysis.strategicAdvice)")
    }

    // MARK: - Failure Classification

    /// Sağlayıcıdan dönen düz metin hata mesajını kullanıcı odaklı kategoriye çevirir.
    private nonisolated static func classifyFailure(detail: String) -> OrionFailureReason {
        let lower = detail.lowercased()
        if lower.contains("circuit") || lower.contains("rate") || lower.contains("limit") || lower.contains("503") {
            return .rateLimited
        }
        if lower.contains("offline") || lower.contains("network") || lower.contains("timeout")
            || lower.contains("connection") || lower.contains("unreachable")
            || lower.contains("internet") || lower.contains("host") {
            return .networkUnavailable
        }
        if lower.contains("not found") || lower.contains("unknown symbol")
            || lower.contains("invalid symbol") || lower.contains("404") {
            return .symbolInvalid
        }
        if lower.isEmpty {
            return .emptyData
        }
        return .providerError(detail)
    }

    /// 6 timeframe'in hata dağılımından kullanıcıya gösterilecek ana sebebi seçer.
    /// Öncelik: rateLimited > networkUnavailable > symbolInvalid > providerError > emptyData.
    private nonisolated static func dominantFailure(in failures: [String: OrionFailureReason]) -> OrionFailureReason {
        let reasons = Array(failures.values)
        if reasons.isEmpty { return .emptyData }
        if reasons.contains(where: { $0 == .rateLimited }) { return .rateLimited }
        if reasons.contains(where: { $0 == .networkUnavailable }) { return .networkUnavailable }
        if reasons.contains(where: { $0 == .symbolInvalid }) { return .symbolInvalid }
        if let provider = reasons.first(where: { if case .providerError = $0 { return true } else { return false } }) {
            return provider
        }
        return .emptyData
    }
    
    // MARK: - Accessors
    
    func getAnalysis(for symbol: String) -> MultiTimeframeAnalysis? {
        return analysis[symbol]
    }

    private nonisolated static func aggregateCandles(_ candles: [Candle], bucketSize: Int) -> [Candle] {
        guard bucketSize > 1, candles.count >= bucketSize else { return candles }

        let sorted = candles.sorted { $0.date < $1.date }
        var aggregated: [Candle] = []
        aggregated.reserveCapacity(sorted.count / bucketSize + 1)

        var index = 0
        while index < sorted.count {
            let end = min(index + bucketSize, sorted.count)
            let slice = sorted[index..<end]
            guard let first = slice.first, let last = slice.last else { break }

            let high = slice.map(\.high).max() ?? first.high
            let low = slice.map(\.low).min() ?? first.low
            let volume = slice.reduce(0.0) { $0 + $1.volume }

            aggregated.append(
                Candle(
                    date: last.date,
                    open: first.open,
                    high: high,
                    low: low,
                    close: last.close,
                    volume: volume
                )
            )
            index += bucketSize
        }
        return aggregated
    }
}
