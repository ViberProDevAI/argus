import Foundation

class MacroCache {
    static let shared = MacroCache()
    private init() {}
    
    func get() -> MacroData? {
        // Pillar 3: 12-hour expiry
        let maxAge: TimeInterval = 12 * 3600
        return DiskCacheService.shared.load(MacroData.self, key: "macro_snapshot", maxAge: maxAge)
    }
    
    func save(_ data: MacroData) {
        DiskCacheService.shared.save(data, key: "macro_snapshot")
    }
}
