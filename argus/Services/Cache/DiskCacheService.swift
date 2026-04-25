import Foundation
import CommonCrypto

/// "The Vault" - Disk-Based Caching Layer (Pillar 3 & Hydra Cache)
/// Persists expensive API responses to disk to honor strict quotas and enable offline capability.
/// Includes Data Harvesting for historical dataset building.
final class DiskCacheService: Sendable {
    static let shared = DiskCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let harvestDirectory: URL
    
    // Serial Queue for Thread Safety (File Ops)
    private let queue = DispatchQueue(label: "com.argus.diskcache")
    
    private init() {
        // Setup Cache Dir: Library/Caches/ArgusData
        let libUrls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let root = libUrls.first ?? URL(fileURLWithPath: "/tmp")
        self.cacheDirectory = root.appendingPathComponent("ArgusData")
        
        // Setup Harvest Dir: Documents/ArgusHistory (Permanent)
        let docUrls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docRoot = docUrls.first ?? URL(fileURLWithPath: "/tmp")
        self.harvestDirectory = docRoot.appendingPathComponent("ArgusHistory")
        
        createDirectories()
    }
    
    private func createDirectories() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: harvestDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Core API (The Vault)
    
    /// Retrieves item from cache if it exists and is not expired.
    func get<T: Codable>(key: String, type: T.Type, maxAge: TimeInterval) -> T? {
        let filename = sanitize(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // 1. Check Existence
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        // 2. Check TTL
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                if Date().timeIntervalSince(modificationDate) > maxAge {
                    // print("🐢 Cache: Expired key \(key) (Age: \(Int(Date().timeIntervalSince(modificationDate)))s)")
                    // Optional: Delete immediately, or lazily. Removing helps keep cache clean.
                    try? fileManager.removeItem(at: fileURL)
                    return nil
                }
            }
        } catch {
            return nil
        }
        
        // 3. Decode
        do {
            let data = try Data(contentsOf: fileURL)
            let object = try JSONDecoder().decode(T.self, from: data)
            // print("⚡️ Cache: Hit [\(key)]")
            return object
        } catch {
            print("❌ Cache: Corrupt file for \(key). Deleting.")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    /// Saves item to cache and harvests if flagged.
    func save<T: Codable>(key: String, data: T, harvest: Bool = false) {
        queue.async {
            do {
                let filename = self.sanitize(key) + ".json"
                let fileURL = self.cacheDirectory.appendingPathComponent(filename)
                
                let encoded = try JSONEncoder().encode(data)
                try encoded.write(to: fileURL)
                
                if harvest {
                    self.harvestData(key: key, data: encoded)
                }
            } catch {
                print("❌ Cache: Write failed for \(key) - \(error)")
            }
        }
    }
    
    // MARK: - Data Harvesting
    
    /// Appends data to a permanent historical log.
    private func harvestData(key: String, data: Data) {
        // Appends timestamped snapshot to permanent storage
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(sanitize(key))_\(timestamp).json"
        let harvestURL = harvestDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: harvestURL)
            // print("🚜 Harvested Data: \(filename)")
        } catch {
            print("❌ Harvest Failed: \(error)")
        }
    }
    
    // MARK: - Legacy Compatibility Shims (For existing Caches)
    
    func load<T: Codable>(_ type: T.Type, key: String, maxAge: TimeInterval) -> T? {
        return get(key: key, type: type, maxAge: maxAge)
    }
    
    func save<T: Codable>(_ value: T, key: String) {
        save(key: key, data: value, harvest: false)
    }
    
    func clear(key: String) {
        let filename = sanitize(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearAll() {
        queue.async {
            do {
                let urls = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for url in urls {
                    try? self.fileManager.removeItem(at: url)
                }
                print("🧹 Cache: All items cleared.")
            } catch {
                print("❌ Cache: Clear All failed - \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sanitize(_ key: String) -> String {
        // Simple sanitization to safe filename characters
        let safe = key.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        return safe
    }
    
    // MARK: - Cleanup
    
    /// Eski cache ve harvest dosyalarını siler
    func cleanup(maxAgeDays: Int = 3) {
        queue.async {
            let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
            var deletedCount = 0
            var freedBytes: Int64 = 0
            
            // Cache temizliği
            if let urls = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) {
                for url in urls {
                    if let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       modDate < cutoff {
                        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            freedBytes += Int64(size ?? 0)
                        }
                        try? self.fileManager.removeItem(at: url)
                        deletedCount += 1
                    }
                }
            }
            
            // Harvest temizliği (daha agresif - 1 gün)
            let harvestCutoff = Date().addingTimeInterval(-1 * 24 * 60 * 60)
            if let urls = try? self.fileManager.contentsOfDirectory(at: self.harvestDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) {
                for url in urls {
                    if let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       modDate < harvestCutoff {
                        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            freedBytes += Int64(size ?? 0)
                        }
                        try? self.fileManager.removeItem(at: url)
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                print("🧹 DiskCache Cleanup: \(deletedCount) files, ~\(freedBytes / 1024 / 1024)MB freed.")
            }
        }
    }
}
