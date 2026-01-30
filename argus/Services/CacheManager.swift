import Foundation
import Combine

// MARK: - Cache Manager: Redis-like in-memory cache with persistence
actor CacheManager {
    static let shared = CacheManager()
    
    // MARK: - Cache Entry
    
    struct CacheEntry: Sendable {
        let key: String
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        var accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    // MARK: - State
    
    private var memoryCache: [String: CacheEntry] = [:]
    private var pendingWrites: [String: CacheEntry] = [:]
    private let persistenceQueue = DispatchQueue(label: "com.argus.cache.persistence", qos: .utility)
    
    // MARK: - Main Functions
    
    func get<T: Codable>(_ key: String, type: T.Type) async throws -> T? {
        guard let entry = memoryCache[key] else {
            return nil
        }
        
        // Check expiration
        if entry.isExpired {
            memoryCache.removeValue(forKey: key)
            await persist(key, nil)
            return nil
        }
        
        // Decode
        var mutableEntry = entry
        mutableEntry.accessCount += 1
        memoryCache[key] = mutableEntry
        
        let decoded = try JSONDecoder().decode(type, from: mutableEntry.data)
        
        return decoded
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval) async {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let entry = CacheEntry(
            key: key,
            data: data,
            timestamp: Date(),
            ttl: ttl,
            accessCount: 0
        )
        
        // Update memory cache
        memoryCache[key] = entry
        
        // Schedule persistence
        pendingWrites[key] = entry
        await flushPendingWrites()
    }
    
    func remove(_ key: String) async {
        memoryCache.removeValue(forKey: key)
        await persist(key, nil)
    }
    
    func clearAll() async {
        memoryCache.removeAll()
        await persistAll()
        
        print("💾 CACHE: All entries cleared")
    }
    
    func getStats() -> CacheStats {
        let now = Date()
        let expiredCount = memoryCache.values.filter { $0.isExpired }.count
        let totalSize = memoryCache.values.reduce(0) { $0 + $1.data.count }
        
        return CacheStats(
            totalEntries: memoryCache.count,
            expiredEntries: expiredCount,
            totalSizeBytes: totalSize,
            memoryUsageMB: Double(totalSize) / 1_048_576 // Convert to MB
        )
    }
    
    func invalidateByPrefix(_ prefix: String) async {
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(prefix) }
        
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
            await persist(key, nil)
        }
        
        print("💾 CACHE: Invalidated \(keysToRemove.count) entries with prefix '\(prefix)'")
    }
    
    // MARK: - Smart TTL
    
    func calculateSmartTTL(dataType: DataType) -> TimeInterval {
        switch dataType {
        case .quote:
            return 60 // 1 dakika - Anlık fiyatlar
        case .candle:
            return 300 // 5 dakika - Grafik verileri
        case .fundamentals:
            return 3600 // 1 saat - Temel analiz
        case .news:
            return 1800 // 30 dakika - Haberler
        case .backtest:
            return 86400 // 24 saat - Backtest sonuçları
        }
    }
    
    // MARK: - Batch Loading
    
    func batchLoad<T: Codable>(_ keys: [String], type: T.Type) async -> [String: T] {
        var results: [(String, T)] = []
        
        for key in keys {
            if let value: T = try? await get(key, type: type) {
                results.append((key, value))
            }
        }
        
        return Dictionary(uniqueKeysWithValues: results)
    }
    
    // MARK: - Persistence
    
    private func persist(_ key: String, _ value: CacheEntry?) async {
        persistenceQueue.async {
            if let entry = value {
                UserDefaults.standard.set(entry.data, forKey: "cache_\(key)")
                UserDefaults.standard.set(entry.timestamp.timeIntervalSince1970, forKey: "cache_\(key)_timestamp")
                UserDefaults.standard.set(entry.ttl, forKey: "cache_\(key)_ttl")
            } else {
                UserDefaults.standard.removeObject(forKey: "cache_\(key)")
                UserDefaults.standard.removeObject(forKey: "cache_\(key)_timestamp")
                UserDefaults.standard.removeObject(forKey: "cache_\(key)_ttl")
            }
        }
    }
    
    private func persistAll() async {
        persistenceQueue.async {
            do {
                for (key, entry) in self.memoryCache {
                    UserDefaults.standard.set(entry.data, forKey: "cache_\(key)")
                    UserDefaults.standard.set(entry.timestamp.timeIntervalSince1970, forKey: "cache_\(key)_timestamp")
                    UserDefaults.standard.set(entry.ttl, forKey: "cache_\(key)_ttl")
                }
            } catch {
                print("⚠️ CACHE: Failed to persist cache: \(error)")
            }
        }
    }
    
    private func loadFromDisk() async {
        // await MainActor.run {
            let keys = UserDefaults.standard.string(forKey: "cache_keys")?.components(separatedBy: ",") ?? []
            
            var loadedEntries: [String: CacheEntry] = [:]
            
            for key in keys {
                if let data = UserDefaults.standard.data(forKey: "cache_\(key)") {
                   let timestamp = UserDefaults.standard.double(forKey: "cache_\(key)_timestamp")
                   let ttl = UserDefaults.standard.double(forKey: "cache_\(key)_ttl")
                   
                   loadedEntries[key] = CacheEntry(
                        key: key,
                        data: data,
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        ttl: ttl,
                        accessCount: 0
                   )
                }
            }
            
            memoryCache = loadedEntries
            
            print("💾 CACHE: Loaded \(loadedEntries.count) entries from disk")
        // } // Removed MainActor.run
    }
    
    private func flushPendingWrites() async {
        let writesToFlush = pendingWrites
        pendingWrites = [:]
        
        for (key, entry) in writesToFlush {
            await persist(key, entry)
        }
    }
}

// MARK: - Models

enum DataType: String, CaseIterable {
    case quote = "Quote"
    case candle = "Candle"
    case fundamentals = "Fundamentals"
    case news = "News"
    case backtest = "Backtest"
}

struct CacheStats: Sendable {
    let totalEntries: Int
    let expiredEntries: Int
    let totalSizeBytes: Int
    let memoryUsageMB: Double
}