import Foundation

/// Backtest sonuçlarını JSON olarak cache'leyen servis
/// Hisse başına kayıt, 24 saat geçerlilik
@MainActor
final class BacktestCacheService {
    static let shared = BacktestCacheService()
    
    private let fileManager = FileManager.default
    private let cacheValidityHours: Double = 24
    
    private var cacheDirectory: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("BacktestCache")
    }
    
    private init() {
        createCacheDirectoryIfNeeded()
    }
    
    // MARK: - Public API
    
    /// Cache'den backtest sonuçlarını oku
    func getCache(for symbol: String) -> BacktestCacheEntry? {
        guard let url = cacheFileURL(for: symbol) else { return nil }
        
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let entry = try JSONDecoder().decode(BacktestCacheEntry.self, from: data)
            
            // Cache geçerlilik kontrolü (24 saat)
            let hoursSinceUpdate = Date().timeIntervalSince(entry.lastUpdated) / 3600
            if hoursSinceUpdate > cacheValidityHours {
                // Cache eskimiş, sil
                try? fileManager.removeItem(at: url)
                return nil
            }
            
            return entry
        } catch {
            print("⚠️ [BacktestCache] Okuma hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Orion backtest sonucunu cache'e yaz
    func saveOrionResult(symbol: String, result: ModuleBacktestSummary) {
        var entry = getCache(for: symbol) ?? BacktestCacheEntry(symbol: symbol, lastUpdated: Date(), orion: nil, phoenix: nil)
        entry = BacktestCacheEntry(
            symbol: symbol,
            lastUpdated: Date(),
            orion: result,
            phoenix: entry.phoenix
        )
        saveEntry(entry)
    }
    
    /// Phoenix backtest sonucunu cache'e yaz
    func savePhoenixResult(symbol: String, result: ModuleBacktestSummary) {
        var entry = getCache(for: symbol) ?? BacktestCacheEntry(symbol: symbol, lastUpdated: Date(), orion: nil, phoenix: nil)
        entry = BacktestCacheEntry(
            symbol: symbol,
            lastUpdated: Date(),
            orion: entry.orion,
            phoenix: result
        )
        saveEntry(entry)
    }
    
    /// Belirli bir sembolün cache'ini sil
    func clearCache(for symbol: String) {
        guard let url = cacheFileURL(for: symbol) else { return }
        try? fileManager.removeItem(at: url)
        print("🗑️ [BacktestCache] Silindi: \(symbol)")
    }
    
    /// Tüm cache'i temizle
    func clearAllCache() {
        guard let dir = cacheDirectory else { return }
        try? fileManager.removeItem(at: dir)
        createCacheDirectoryIfNeeded()
        print("🗑️ [BacktestCache] Tüm cache temizlendi")
    }
    
    /// Tüm cache'lenmiş sembolleri listele
    func allCachedSymbols() -> [String] {
        guard let dir = cacheDirectory else { return [] }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { $0.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_backtest", with: "") }
        } catch {
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    private func createCacheDirectoryIfNeeded() {
        if let dir = cacheDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func cacheFileURL(for symbol: String) -> URL? {
        let sanitized = symbol.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return cacheDirectory?.appendingPathComponent("\(sanitized)_backtest.json")
    }
    
    private func saveEntry(_ entry: BacktestCacheEntry) {
        guard let url = cacheFileURL(for: entry.symbol) else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entry)
            try data.write(to: url)
            print("✅ [BacktestCache] Kaydedildi: \(entry.symbol)")
        } catch {
            print("⚠️ [BacktestCache] Yazma hatası: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct BacktestCacheEntry: Codable, Sendable {
    let symbol: String
    let lastUpdated: Date
    let orion: ModuleBacktestSummary?
    let phoenix: ModuleBacktestSummary?
}

struct ModuleBacktestSummary: Codable, Sendable {
    let winRate: Double        // 0-100
    let tradeCount: Int
    let totalReturn: Double    // Percentage
    let maxDrawdown: Double    // Percentage
    let profitFactor: Double   // Wins / Losses
    
    // Opsiyonel detaylar
    var avgHoldingDays: Double?
    var bestTrade: Double?
    var worstTrade: Double?
}
