import Foundation

actor DataCacheService {
    static let shared = DataCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Use Caches directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ArgusDataCache", isDirectory: true)
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Private Shadow Struct (Fix MainActor Conformance Issue)
    private struct _CachedDataEntry: Codable {
        let data: Data
        let source: String
        let receivedAt: Date
        let symbol: String
        let kind: DataFieldKind
    }

    // MARK: - API
    
    /// Save a value to the cache
    /// Fire-and-forget style (internally detached).
    nonisolated func save<T: Codable>(value: T, kind: DataFieldKind, symbol: String, source: String = "Unknown") {
        let timestamp = Date()
        
        // 1. Encode value to Data
        guard let valueData = try? JSONEncoder().encode(value) else { return }
        
        // 2. Wrap in Shadow Struct
        let wrapper = _CachedDataEntry(
            data: valueData,
            source: source,
            receivedAt: timestamp,
            symbol: symbol,
            kind: kind
        )

        Task.detached(priority: .background) {
            let filename = self.makeFilename(kind: kind, symbol: symbol)
            let cacheURL = self.cacheDirectory.appendingPathComponent(filename)
            
            do {
                // 3. Encode Wrapper
                let wrapperData = try JSONEncoder().encode(wrapper)
                try wrapperData.write(to: cacheURL, options: .atomic)
             } catch {
                print("Cache Save Error: \(error)")
            }
        }
    }
    
    func getEntry(kind: DataFieldKind, symbol: String) -> CachedDataEntry? {
        let filename = makeFilename(kind: kind, symbol: symbol)
        let cacheURL = cacheDirectory.appendingPathComponent(filename)
        
        // Read Data
        guard let wrapperData = try? Data(contentsOf: cacheURL) else { return nil }
        
        // Decode Wrapper (Shadow)
        guard let shadow = try? JSONDecoder().decode(_CachedDataEntry.self, from: wrapperData) else { return nil }
        
        // Convert to Public Model
        return CachedDataEntry(
            data: shadow.data,
            source: shadow.source,
            receivedAt: shadow.receivedAt,
            symbol: shadow.symbol,
            kind: shadow.kind
        )
    }
    
    /// Clear cache for a specific symbol (optional utility)
    func clearCache(for symbol: String) {
        // Not implementing full directory scan for simplicity, but could be added.
    }
    
    // MARK: - Helpers
    
    private nonisolated func makeFilename(kind: DataFieldKind, symbol: String) -> String {
        // Safe filename: remove special chars
        let safeSymbol = symbol.replacingOccurrences(of: "/", with: "_")
                               .replacingOccurrences(of: ":", with: "_")
        return "\(safeSymbol)_\(kind.rawValue).json"
    }
}
