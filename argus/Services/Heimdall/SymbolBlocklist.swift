import Foundation

/// Phase 7 PR-3 (2026-04-29) — Yahoo'nun sembol-spesifik paywall'ına karşı savunma.
///
/// **Sorun**: Yahoo bazı sembolleri (TSLA, SPGI, TXN, VLO, NKE, AZN, BABA...)
/// chart endpoint'inde bile **HTTP 401 "User is unable to access this feature"**
/// ile reddediyor. Bu sembollar her watchlist refresh'te yeniden denenip yine
/// 401 yiyor — IP'yi flag'liyor, log'u kirletiyor, kullanıcı UX'ini bozuyor
/// ve circuit breaker'ı **gereksiz yere** tetikliyor.
///
/// **Çözüm**: 2 ardışık `authInvalid` veya `entitlementDenied` yiyen sembolü
/// 24 saat boyunca **sessize al**. O sembol için yeni network isteği atılmaz;
/// MarketDataStore stale cache veya "blokede" durumu döndürür. Cooldown
/// dolduktan sonra otomatik olarak yeniden denenebilir.
///
/// **Tek-sefer 401 block YANLIŞ** çünkü transient auth/crumb sorunu olabilir
/// (Yahoo crumb'ı 5-15 dk'da bir eskiyor). 2 ardışık başarısızlık eşiği
/// "gerçek paywall" ile "geçici auth boşluğu"nu ayırır.
///
/// **Persistence**: UserDefaults — app restart'ında kara liste yaşar; cooldown
/// timer'ı yeniden hesaplanır.
actor SymbolBlocklist {
    static let shared = SymbolBlocklist()

    private struct Entry: Codable {
        let symbol: String
        let blockedAt: Date
        let expiresAt: Date
        let reason: String
    }

    /// Kara listedeki semboller (symbol → entry).
    private var blocked: [String: Entry] = [:]

    /// Sembol başına ardışık başarısızlık sayacı. 2 → block.
    private var consecutiveFailures: [String: Int] = [:]

    // 2026-05-02: 2-strike + 24h çok agresifti — Yahoo crumb geçici hatalarında
    // (5-15 dk'lık eski crumb pencerelerinde) iki ardışık 401 yiyen sembol
    // 24 saat boyunca komple ölüyordu. Kullanıcı global hisse açtığında veri
    // gelmemesinin baş sebebi buydu.
    // Yeni: 5 ardışık hata + 6 saat block. Gerçek Yahoo paywall'larını yine
    // engeller (her seferinde 401 yer), ama transient hata penceresinde
    // sembolleri ölü duruma düşürmez.
    private let blockDuration: TimeInterval = 6 * 60 * 60 // 6 saat
    private let blockThreshold: Int = 5

    private static let storageKey = "ArgusSymbolBlocklist.v1"

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// Sembol şu an kara listede mi (cooldown geçerli mi)?
    func isBlocked(_ symbol: String) -> Bool {
        guard let entry = blocked[symbol] else { return false }
        if entry.expiresAt < Date() {
            // Cooldown doldu — temizle.
            blocked.removeValue(forKey: symbol)
            consecutiveFailures.removeValue(forKey: symbol)
            persistToDisk()
            return false
        }
        return true
    }

    /// Authentication / entitlement hatası sonrası çağrılır.
    /// 2 ardışık hatadan sonra sembol 24 saatlik kara listeye alınır.
    func reportFailure(symbol: String, reason: String) {
        // Eğer zaten blokede ise kontrol etme.
        if let entry = blocked[symbol], entry.expiresAt > Date() { return }

        let count = (consecutiveFailures[symbol] ?? 0) + 1
        consecutiveFailures[symbol] = count

        if count >= blockThreshold {
            let now = Date()
            blocked[symbol] = Entry(
                symbol: symbol,
                blockedAt: now,
                expiresAt: now.addingTimeInterval(blockDuration),
                reason: reason
            )
            consecutiveFailures.removeValue(forKey: symbol)
            persistToDisk()
            print("🚫 SymbolBlocklist: \(symbol) 24 saat sessizleştirildi (sebep: \(reason))")
        }
    }

    /// Başarılı response sonrası ardışık sayacı sıfırla.
    func reportSuccess(symbol: String) {
        consecutiveFailures.removeValue(forKey: symbol)
    }

    /// Manuel temizleme — UI'dan "tekrar dene" butonu için.
    func unblock(_ symbol: String) {
        blocked.removeValue(forKey: symbol)
        consecutiveFailures.removeValue(forKey: symbol)
        persistToDisk()
    }

    /// Telemetri / UI için kara liste sebebi.
    func reasonFor(_ symbol: String) -> String? {
        blocked[symbol]?.reason
    }

    /// Kullanıcıya gösterilecek "ne kadar sonra çözülecek" bilgisi.
    func remainingCooldown(_ symbol: String) -> TimeInterval? {
        guard let entry = blocked[symbol] else { return nil }
        let remaining = entry.expiresAt.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// UI/Settings için: bloke sembol listesi.
    func currentlyBlocked() -> [(symbol: String, reason: String, expiresIn: TimeInterval)] {
        let now = Date()
        return blocked.values
            .filter { $0.expiresAt > now }
            .map { ($0.symbol, $0.reason, $0.expiresAt.timeIntervalSince(now)) }
            .sorted { $0.symbol < $1.symbol }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        // Yüklenirken expired olanları at.
        let now = Date()
        blocked = decoded.filter { $0.value.expiresAt > now }
        if blocked.count != decoded.count {
            persistToDisk() // Temizlenmişleri yaz.
        }
    }

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(blocked) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
