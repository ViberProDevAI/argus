import Foundation
import Combine
import SwiftUI

// MARK: - Entry Store
// Symbol başına hesaplanan EntrySetup'ı tutar. OrionStore başarılı analiz ürettiğinde
// tetiklenir; EntrySetupEngine'i candles + quote + Orion günlük skoru ile çalıştırır.
//
// Expiry: EntrySetup.validUntil geçtiğinde cleanupExpired() sonucu drop edilir.
// UI (SanctumViewModel) $setups'ı dinler, kendi sembolünü map eder.

@MainActor
final class EntryStore: ObservableObject {
    static let shared = EntryStore()

    @Published var setups: [String: EntrySetup] = [:]

    private init() {}

    /// Orion analizi tamamlandıktan sonra EntrySetup'ı üretir.
    /// - Parameters:
    ///   - symbol: Analiz hedefi.
    ///   - analysis: MTF sonuç — .daily.score conviction gate için kullanılır.
    func computeSetup(for symbol: String, analysis: MultiTimeframeAnalysis) async {
        // Pencereye her girişte süresi dolmuş setup'ları temizle — stale veri UI'ya sızmasın.
        cleanupExpired()

        // 1. Daily candles — MarketDataStore cache'inden gelir (OrionStore az önce fetch'ledi).
        let candlesValue = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
        guard let candles = candlesValue.value, !candles.isEmpty else {
            self.setups[symbol] = dataRejectSetup(symbol: symbol, reason: "Günlük mum verisi alınamadı.")
            return
        }

        // 2. Quote — current price for entry calculation.
        let quoteValue = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        guard let quote = quoteValue.value, quote.currentPrice > 0 else {
            self.setups[symbol] = dataRejectSetup(symbol: symbol, reason: "Anlık fiyat alınamadı.")
            return
        }

        // 3. Engine çağrısı.
        let setup = EntrySetupEngine.evaluate(
            symbol: symbol,
            candles: candles,
            quote: quote,
            orionDailyScore: analysis.daily.score
        )

        self.setups[symbol] = setup
    }

    /// Süresi dolmuş setup'ları kaldırır — UI'ya eski veri sızmasın.
    func cleanupExpired() {
        let now = Date()
        setups = setups.filter { $0.value.validUntil > now }
    }

    // MARK: - Internals

    /// Veri katmanından kaynaklanan fail — kullanıcıya net sebep söyle.
    private func dataRejectSetup(symbol: String, reason: String) -> EntrySetup {
        let now = Date()
        return EntrySetup(
            symbol: symbol,
            grade: .reject(reason: reason),
            entryZone: nil,
            trigger: nil,
            stopPrice: nil,
            targets: [],
            rrRatio: nil,
            confluence: [],
            validUntil: now.addingTimeInterval(300), // Veri eksik — 5dk sonra tekrar dene.
            generatedAt: now,
            waitMessage: reason
        )
    }
}
