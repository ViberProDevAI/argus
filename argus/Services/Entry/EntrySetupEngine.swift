import Foundation

// MARK: - Entry Setup Engine (Orchestrator)
// KeyLevelsEngine + PullbackDetector + R:R + grading'i birleştirir.
// Tek public entry point: evaluate(symbol:candles:quote:orionDailyScore:) → EntrySetup.
//
// Grade kriterleri (PullbackDetector primary confluence'ı ekler → count ≥ 1 her zaman):
//   A: R:R ≥ 3.0 AND confluence ≥ 3  (primary + 2 ekstra teyit)
//   B: R:R ≥ 2.5 AND confluence ≥ 2  (primary + 1 ekstra teyit)
//   C: R:R ≥ 2.0                     (sadece EMA retest, ekstra teyit zayıf)
//
// R:R < 2.0 → reject (fırsat-risk dengesizliği).
// TP1 = recentHigh90d (doğal direnç). TP2 = entry + reward × 1.5 (uzatma hedefi).
// Stop = entryZone.lowerBound − 0.5 × ATR (zon altı + ATR nefesi).

enum EntrySetupEngine {

    /// Setup TTL: 2 iş günü. Pazartesi analiz edilen Çarşamba günü invalid.
    static let validityWindow: TimeInterval = 2 * 24 * 3600

    static func evaluate(
        symbol: String,
        candles: [Candle],
        quote: Quote,
        orionDailyScore: Double
    ) -> EntrySetup {
        let now = Date()
        let validUntil = now.addingTimeInterval(validityWindow)

        // Phase 0 — Key levels. Yetmezse erken reject.
        guard let keyLevels = KeyLevelsEngine.extract(candles: candles) else {
            return rejectSetup(
                symbol: symbol,
                reason: "Yetersiz tarih (setup için min 60 gün).",
                generatedAt: now,
                validUntil: validUntil
            )
        }

        // Phase 1 — Pullback detection.
        let outcome = PullbackDetector.evaluate(
            candles: candles,
            currentPrice: quote.currentPrice,
            keyLevels: keyLevels,
            orionDailyScore: orionDailyScore
        )

        switch outcome {
        case .rejected(let reason):
            return rejectSetup(symbol: symbol, reason: reason, generatedAt: now, validUntil: validUntil)

        case .waitingForPullback(let targetZone, let level):
            let msg = String(
                format: "Trend sağlam. %@ retest bekleniyor (%.2f – %.2f).",
                level, targetZone.lowerBound, targetZone.upperBound
            )
            // entryZone INFORMATIONAL: grade reject → isActionable = false kalır.
            return EntrySetup(
                symbol: symbol,
                grade: .reject(reason: msg),
                entryZone: targetZone,
                trigger: nil,
                stopPrice: nil,
                targets: [],
                rrRatio: nil,
                confluence: [],
                validUntil: validUntil,
                generatedAt: now,
                waitMessage: msg
            )

        case .ready(let result):
            return buildReadySetup(
                symbol: symbol,
                result: result,
                keyLevels: keyLevels,
                quote: quote,
                generatedAt: now,
                validUntil: validUntil
            )
        }
    }

    // MARK: - Ready path: R:R + grading

    private static func buildReadySetup(
        symbol: String,
        result: PullbackResult,
        keyLevels: KeyLevels,
        quote: Quote,
        generatedAt: Date,
        validUntil: Date
    ) -> EntrySetup {

        guard let atr = keyLevels.atr14, atr > 0 else {
            return rejectSetup(symbol: symbol, reason: "ATR hesaplanamadı.", generatedAt: generatedAt, validUntil: validUntil)
        }

        let entry = quote.currentPrice
        let stop = result.entryZone.lowerBound - 0.5 * atr
        let risk = entry - stop
        guard risk > 0 else {
            return rejectSetup(
                symbol: symbol,
                reason: "Stop/giriş mesafesi tutarsız — setup iptal.",
                generatedAt: generatedAt,
                validUntil: validUntil
            )
        }

        // TP1 = yakın direnç (son 90g high). Yoksa setup kurulamaz.
        guard let tp1 = keyLevels.recentHigh90d, tp1 > entry else {
            return rejectSetup(
                symbol: symbol,
                reason: "Üstte belirgin direnç yok — hedef tanımsız, R:R ölçülemez.",
                generatedAt: generatedAt,
                validUntil: validUntil
            )
        }

        let reward = tp1 - entry
        let rr = reward / risk
        guard rr >= 2.0 else {
            return rejectSetup(
                symbol: symbol,
                reason: String(
                    format: "R:R yetersiz (%.2f / 2.00). Fiyat dirence çok yakın, kazanç dar.",
                    rr
                ),
                generatedAt: generatedAt,
                validUntil: validUntil
            )
        }

        let tp2 = entry + reward * 1.5
        let grade = grade(rr: rr, confluenceCount: result.confluence.count)

        return EntrySetup(
            symbol: symbol,
            grade: grade,
            entryZone: result.entryZone,
            trigger: result.trigger,
            stopPrice: stop,
            targets: [tp1, tp2],
            rrRatio: rr,
            confluence: result.confluence,
            validUntil: validUntil,
            generatedAt: generatedAt,
            waitMessage: nil
        )
    }

    private static func grade(rr: Double, confluenceCount: Int) -> EntryGrade {
        if rr >= 3.0 && confluenceCount >= 3 { return .a }
        if rr >= 2.5 && confluenceCount >= 2 { return .b }
        return .c
    }

    // MARK: - Reject helper

    private static func rejectSetup(
        symbol: String,
        reason: String,
        generatedAt: Date,
        validUntil: Date
    ) -> EntrySetup {
        EntrySetup(
            symbol: symbol,
            grade: .reject(reason: reason),
            entryZone: nil,
            trigger: nil,
            stopPrice: nil,
            targets: [],
            rrRatio: nil,
            confluence: [],
            validUntil: validUntil,
            generatedAt: generatedAt,
            waitMessage: reason
        )
    }
}
