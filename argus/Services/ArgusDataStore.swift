import Foundation

/// Background Actor for handling heavy I/O and JSON Encoding/Decoding
/// Prevents Main Thread Hangs when saving large datasets (e.g. Argus Lab Events).
actor ArgusDataStore {
    static let shared = ArgusDataStore()
    
    // Constants
    private let suiteName = "group.com.yourcompany.argus"
    
    private init() {}
    
    /// Saves a Codable object to UserDefaults asynchronously
    func save<T: Codable>(_ object: T, key: String) {
        // Encoding happens HERE (on background actor), not on Main Thread
        if let data = try? JSONEncoder().encode(object) {
            UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
        }
    }
    
    /// Loads a Codable object from UserDefaults asynchronously
    func load<T: Codable>(key: String) -> T? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
