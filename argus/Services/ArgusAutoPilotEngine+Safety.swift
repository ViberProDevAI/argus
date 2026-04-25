import Foundation

extension ArgusAutoPilotEngine {

    /// Earnings/event risk guard.
    ///
    /// Mevcut durum: `AutoPilotConfig.earningsGuardEnabled == false` (default).
    /// Bu iken fonksiyon hep PASS (`true`) döner — yani earnings kontrolü yok.
    /// Bu karar bilinçli; gerçek bir earnings provider bağlı değilken
    /// false döndürmek tüm alımları durdururdu.
    ///
    /// Flag `true` yapıldığında: provider bağlanana kadar fail-safe davranış
    /// uygulanır — güvenli tarafta kalıp `false` döner (alım reddedilir).
    /// Gerçek implementasyon (EODHD / Yahoo earnings calendar) bağlandığında
    /// buradaki `return false` yerine provider çağrısı gelmeli.
    func checkSafety(symbol: String) async -> Bool {
        guard AutoPilotConfig.earningsGuardEnabled else {
            return true
        }
        ArgusLogger.warn(
            "Earnings guard etkin ama provider bağlı değil — \(symbol) fail-safe reject",
            category: "SAFETY"
        )
        return false
    }
}
