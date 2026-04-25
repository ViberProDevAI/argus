import Foundation

/// Y7: TradeBrain → ExecutionState priced handoff.
///
/// Karar katmanı (TradeBrain) bu intent'i construct eder; icra katmanı
/// (ExecutionStateViewModel) intent içindeki fiyatı otoritatif olarak
/// kullanır. Amaç: "karar fiyatı = icra fiyatı" invariantını korumak.
///
/// **Eski akış:** TradeBrain "al" derken fiyatı `quotes[symbol]?.currentPrice`
/// ile okur, Notification payload'ında `"price": Double` olarak taşırdı.
/// ExecutionState.buy() ise `MarketDataStore.getQuote(...)` ile fiyatı
/// YENİDEN fetch ederdi — TradeBrain'in fiyatı sadece fallback olurdu.
/// Sonuç: karar saniyeler önceki fiyat üzerinden, icra farklı fiyat
/// üzerinden; risk/reward hesabı kalibre olmuyor, stale karar sessiz
/// icra ediliyordu.
///
/// **Yeni akış:** Intent fiyatı otoritatif. ExecutionState intent.price'ı
/// kullanır, canlı quote'a dönmez. `isStale(maxAge:)` ile belli bir yaştan
/// eski intent'ler reddedilir; icra etmek yerine drop + log.
struct PricedOrderIntent {
    /// Intent'in tetikleyeceği aksiyon. TradeBrain farklı yerlerden farklı
    /// tipte emir gönderiyor (sembol bazlı buy, trade-id bazlı sell/trim);
    /// bu enum üç şeklin tip-güvenli union'u.
    enum Action: Equatable {
        /// Yeni pozisyon açma — sembol + miktar.
        case buy(symbol: String, quantity: Double)

        /// Pozisyonu tamamen kapatma (liquidate) — tradeId ile spesifik trade.
        case closeAll(tradeId: UUID)

        /// Kısmi çıkış — pozisyonun `percentage` kadarını sat (1 < % < 100).
        case trim(tradeId: UUID, percentage: Double)
    }

    /// Hangi aksiyonun tetikleneceği.
    let action: Action

    /// Karar anında bilinen fiyat. Icra bu fiyatta olur (re-fetch yok).
    let price: Double

    /// Fiyatın hangi anda sample edildiği. ExecutionState `now - priceAsOf`
    /// delta'sına bakarak stale intent'i reddeder.
    let priceAsOf: Date

    /// Karar sebebi — log, plan rasyonalı, UI göstergeleri için.
    /// Buy notification'larındaki "rationale" ve sell'lerdeki "reason" bu
    /// tek alanda birleştirilir.
    let rationale: String

    /// Intent'in construct edildiği an. Notification + handler latency'sini
    /// ölçmek için priceAsOf'tan ayrı tutulur — fiyat cache'ten gelmiş olup
    /// karar anı ile arada saniyeler fark olabilir.
    let issuedAt: Date

    init(
        action: Action,
        price: Double,
        priceAsOf: Date,
        rationale: String,
        issuedAt: Date = Date()
    ) {
        self.action = action
        self.price = price
        self.priceAsOf = priceAsOf
        self.rationale = rationale
        self.issuedAt = issuedAt
    }

    /// Intent fiyat snapshot'ının yaşı (saniye).
    var priceAgeSeconds: TimeInterval {
        Date().timeIntervalSince(priceAsOf)
    }

    /// Intent belirlenen maksimum yaşı aştı mı?
    ///
    /// **Default 10s:** TradeBrain döngüsü + NotificationCenter latency +
    /// handler başlama süresi için makul üst sınır. Bundan eskisi icra
    /// edilirse kararın dayandığı risk/reward hesabı geçersiz sayılır;
    /// paper-trade için 10s, daha agresif setup'larda 5s daha uygun olabilir.
    func isStale(maxAge: TimeInterval = 10.0, now: Date = Date()) -> Bool {
        now.timeIntervalSince(priceAsOf) > maxAge
    }
}

extension PricedOrderIntent {
    /// NotificationCenter userInfo dict'inde intent'i taşıyan anahtar.
    /// Tek kelime sabit — post ve handler taraflarında aynı sembol
    /// kullanıldığı sürece string literal duplication olmaz.
    static let userInfoKey = "pricedOrderIntent"
}
