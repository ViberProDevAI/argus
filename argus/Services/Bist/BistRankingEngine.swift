import Foundation

// MARK: - BIST Ranking Engine
// Goreceli siralama sistemi
// Mutlak skorlar yerine semboller birbirine gore siralanir
// Yakin zamanda islem yapilmis sembollere ceza uygulanir

actor BistRankingEngine {
    static let shared = BistRankingEngine()

    private init() {}

    // MARK: - Recently Traded Tracking

    private var recentlyTraded: [String: Date] = [:]

    /// Islem yapildi - sembolu kaydet
    func markTraded(symbol: String) {
        recentlyTraded[symbol] = Date()
    }

    /// Eski kayitlari temizle (30 gun oncesi)
    func cleanupOldEntries() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        recentlyTraded = recentlyTraded.filter { $0.value > cutoff }
    }

    // MARK: - Relative Ranking

    struct RankedSymbol: Sendable {
        let symbol: String
        let rawScore: Double              // Orijinal BistFaktor skoru
        let decayedScore: Double          // Zaman curumeli skor
        let percentileRank: Double        // Goreceli siralama (0-100)
        let recentlyTradedPenalty: Double // Yakin zamanda islem cezasi
        let finalRank: Double             // Son siralama skoru
        let factors: [BistFaktor]
        let timestamp: Date

        var isRecommended: Bool {
            finalRank >= 60 && recentlyTradedPenalty < 0.5
        }
    }

    /// Sembolleri goreceli olarak sirala
    func rank(results: [BistFaktorResult]) -> [RankedSymbol] {
        guard !results.isEmpty else { return [] }

        // 1. Gecersiz sinyalleri filtrele
        let validResults = results.filter { !$0.isExpired }
        guard !validResults.isEmpty else { return [] }

        // 2. Decayed skorlari hesapla
        let decayedScores = validResults.map { ($0, $0.decayedScore) }

        // 3. Skorlari sirala (yuksekten dusuge)
        let sorted = decayedScores.sorted { $0.1 > $1.1 }

        // 4. Percentile hesapla
        let total = Double(sorted.count)
        var ranked: [RankedSymbol] = []

        for (index, item) in sorted.enumerated() {
            let result = item.0
            let decayed = item.1

            // Percentile: En yuksek skor = 100, en dusuk = 0
            let percentile = ((total - Double(index)) / total) * 100.0

            // Recently traded penalty
            let penalty = calculateRecentlyTradedPenalty(symbol: result.symbol)

            // Final rank = Percentile * (1 - penalty)
            // Eger yakin zamanda islem yapildiysa rank duser
            let finalRank = percentile * (1.0 - penalty)

            ranked.append(RankedSymbol(
                symbol: result.symbol,
                rawScore: result.totalScore,
                decayedScore: decayed,
                percentileRank: percentile,
                recentlyTradedPenalty: penalty,
                finalRank: finalRank,
                factors: result.factors,
                timestamp: result.timestamp
            ))
        }

        // 5. Final rank'a gore tekrar sirala
        return ranked.sorted { $0.finalRank > $1.finalRank }
    }

    /// En iyi N sembolu getir
    func topPicks(from results: [BistFaktorResult], limit: Int = 5) -> [RankedSymbol] {
        let ranked = rank(results: results)
        return Array(ranked.prefix(limit))
    }

    /// Onerilen sembolleri getir (threshold ustundeki)
    func recommendations(from results: [BistFaktorResult], minRank: Double = 60) -> [RankedSymbol] {
        let ranked = rank(results: results)
        return ranked.filter { $0.finalRank >= minRank && $0.isRecommended }
    }

    // MARK: - Private Helpers

    private func calculateRecentlyTradedPenalty(symbol: String) -> Double {
        guard let lastTraded = recentlyTraded[symbol] else {
            return 0.0 // Hic islem yapilmamis = ceza yok
        }

        let daysSince = SignalTimeDecay.ageInDays(from: lastTraded)

        // Ceza eslikleri
        if daysSince < 3 {
            return 0.8  // Son 3 gun = %80 ceza (neredeyse disarida)
        } else if daysSince < 7 {
            return 0.5  // Son 1 hafta = %50 ceza
        } else if daysSince < 14 {
            return 0.25 // Son 2 hafta = %25 ceza
        } else if daysSince < 30 {
            return 0.1  // Son 1 ay = %10 ceza
        }

        return 0.0 // 1 aydan eski = ceza yok
    }

    // MARK: - Diversity Score

    /// Sektor cesitliligini hesapla (0-100)
    func diversityScore(symbols: [String], sectorMap: [String: String]) -> Double {
        guard !symbols.isEmpty else { return 0 }

        var sectorCounts: [String: Int] = [:]
        for symbol in symbols {
            let sector = sectorMap[symbol] ?? "Bilinmiyor"
            sectorCounts[sector, default: 0] += 1
        }

        // Herfindahl-Hirschman Index (HHI) benzeri
        // HHI = sum of squared market shares
        // Lower HHI = more diverse
        let total = Double(symbols.count)
        var hhi = 0.0
        for (_, count) in sectorCounts {
            let share = Double(count) / total
            hhi += share * share
        }

        // HHI 1/n ile 1 arasinda degisir
        // 1/n = tam cesitlilik, 1 = tek sektor
        let minHHI = 1.0 / Double(max(sectorCounts.count, 1))
        let maxHHI = 1.0

        // Normalize to 0-100 (higher = more diverse)
        let normalized = (maxHHI - hhi) / (maxHHI - minHHI)
        return min(100, max(0, normalized * 100))
    }
}

// MARK: - BistFaktorEngine Extension

extension BistFaktorEngine {

    /// Birden fazla sembolu analiz et ve goreceli sirala
    func analyzeAndRank(symbols: [String]) async -> [BistRankingEngine.RankedSymbol] {
        var results: [BistFaktorResult] = []

        for symbol in symbols {
            do {
                let result = try await analyze(symbol: symbol)
                results.append(result)
            } catch {
                // Hata olan sembolu atla
                print("[BIST] Analiz hatasi \(symbol): \(error.localizedDescription)")
            }
        }

        return await BistRankingEngine.shared.rank(results: results)
    }
}
