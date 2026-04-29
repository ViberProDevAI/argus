import Foundation

/// Phase 6 PR-B (2026-04-29) — Daily Candle Aggregation.
///
/// Yahoo `chart` endpoint'i tek-sembol-tek-interval. Tek hisse için 6 timeframe
/// (5m, 15m, 1h, 4h, 1d, 1wk) çekmek = 6 ayrı istek. Bunun büyük kısmı boşuna —
/// günlük tabanlı (1d, 1wk, 1mo, 3mo) tüm timeframe'ler **aynı kaynaktan**
/// (`interval=1d, range=max`) gelen daily seriden lokalde aggregate edilebilir.
///
/// Bu servis o aggregation'ı yapar:
///   • `1d / 1wk / 1mo / 3mo` ailesi → tek "daily-max" Yahoo isteği + lokal aggregate
///   • `5m / 15m / 1h / 4h` (intraday) → provider'a doğrudan pass-through (aggregation
///     kazancı küçük, intraday range zaten kısa)
///
/// Tek hisse açılışında daily ailesinde **6 → 1** istek azalması, `MarketDataStore`
/// üzerinde de tek cache slot tutuluyor (kanonik anahtar `_1day_master`).
/// Türetilmiş timeframe'ler kendi cache key'lerinde saklanmadan her seferinde
/// aggregate ediliyor — böylece "fresh master daily" güncellendiğinde türevler
/// otomatik tutarlı.
@MainActor
final class MultiTimeframeCandleService {
    static let shared = MultiTimeframeCandleService()

    private init() {}

    /// Daily ailesinden mi (master daily seriyi kullanan)?
    static func isDailyFamily(_ timeframe: String) -> Bool {
        let normalized = timeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1day", "1d", "1g", "daily", "d",
             "1week", "1wk", "1w", "weekly",
             "1month", "1mo", "1mon", "monthly",
             "3month", "3mo":
            return true
        default:
            return false
        }
    }

    /// Master daily seriden istenen timeframe için aggregate edilmiş candle
    /// listesini üretir. `daily` listesi **eskiden yeniye** sıralı varsayılır
    /// (Yahoo adapter'ı bu sırada veriyor).
    static func aggregate(daily: [Candle], to timeframe: String) -> [Candle] {
        let normalized = timeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1day", "1d", "1g", "daily", "d":
            return daily
        case "1week", "1wk", "1w", "weekly":
            return aggregate(daily, calendarComponent: .weekOfYear)
        case "1month", "1mo", "1mon", "monthly":
            return aggregate(daily, calendarComponent: .month)
        case "3month", "3mo":
            return aggregate(daily, calendarComponent: .quarter)
        default:
            // Daily ailesi olmayan bir timeframe yanlışlıkla geldiyse: ham döndür.
            return daily
        }
    }

    /// Generic gruplama: ardışık daily candle'ları takvim bileşenine göre
    /// gruplayıp her grubun açılışını/kapanışını/zirvesini/dibini/hacmini hesaplar.
    /// Calendar `.iso8601` kullanılıyor — ISO haftası Pazartesi başlar; uluslararası
    /// piyasalarda da tutarlı (Yahoo timestamp'leri UTC).
    private static func aggregate(_ daily: [Candle], calendarComponent: Calendar.Component) -> [Candle] {
        guard !daily.isEmpty else { return [] }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2 // Monday

        // (groupKey → bucket of candles). Sıralamayı korumak için ordered insertion:
        var groupOrder: [String] = []
        var groups: [String: [Candle]] = [:]

        for candle in daily {
            let key = bucketKey(for: candle.date, calendar: calendar, component: calendarComponent)
            if groups[key] == nil {
                groups[key] = [candle]
                groupOrder.append(key)
            } else {
                groups[key]?.append(candle)
            }
        }

        return groupOrder.compactMap { key -> Candle? in
            guard let bucket = groups[key], let first = bucket.first, let last = bucket.last else { return nil }
            let high = bucket.map(\.high).max() ?? last.high
            let low = bucket.map(\.low).min() ?? last.low
            let volume = bucket.map(\.volume).reduce(0, +)
            return Candle(
                date: first.date,    // Grup başı tarih (haftanın/ayın başlangıcı)
                open: first.open,
                high: high,
                low: low,
                close: last.close,   // Grup sonu kapanış
                volume: volume
            )
        }
    }

    /// Aynı haftaya/aya/çeyreğe düşen candle'lar için kararlı string anahtar.
    private static func bucketKey(for date: Date, calendar: Calendar, component: Calendar.Component) -> String {
        let comps: DateComponents
        switch component {
        case .weekOfYear:
            comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
        case .month:
            comps = calendar.dateComponents([.year, .month], from: date)
            return "\(comps.year ?? 0)-M\(comps.month ?? 0)"
        case .quarter:
            comps = calendar.dateComponents([.year, .month], from: date)
            let month = comps.month ?? 0
            let quarter = ((month - 1) / 3) + 1
            return "\(comps.year ?? 0)-Q\(quarter)"
        default:
            comps = calendar.dateComponents([.year, .month, .day], from: date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        }
    }
}
