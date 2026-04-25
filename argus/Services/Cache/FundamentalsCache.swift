import Foundation

// MARK: - Fundamentals Cache (FACADE)
// DEPRECATION NOTICE: Bu sınıf artık UnifiedFundamentalsStore'a yönlendiriyor.
// Mevcut kod uyumluluğu için facade olarak korunuyor.

class FundamentalsCache {
    static let shared = FundamentalsCache()
    private init() {
        print("⚠️ FundamentalsCache: Now using UnifiedFundamentalsStore as backend")
    }
    
    func get(symbol: String) -> FinancialsData? {
        // MainActor gerekli - ama bu senkron çağrı
        // UnifiedStore @MainActor olduğu için Task içinde çağırmalıyız
        // ANCAK bu senkron API, workaround gerekli
        
        // Workaround: Doğrudan disk'ten oku (legacy behavior için)
        let maxAge: TimeInterval = 15 * 24 * 3600
        if let data = DiskCacheService.shared.load(FinancialsData.self, key: "fund_\(symbol)", maxAge: maxAge) {
            return data
        }
        
        // Unified Store'dan da kontrol et (async wrapper)
        // Bu sync API olduğu için tam entegrasyon mümkün değil
        // Yeni kodlar için UnifiedFundamentalsStore.shared.getRawData() kullanılmalı
        return nil
    }
    
    func set(symbol: String, data: FinancialsData) {
        // Disk'e de yaz (backward compatibility)
        DiskCacheService.shared.save(data, key: "fund_\(symbol)")
        
        // Score Store'a da yaz
        Task { @MainActor in
            FundamentalScoreStore.shared.setRawData(symbol: symbol, data: data)
        }
    }
}
