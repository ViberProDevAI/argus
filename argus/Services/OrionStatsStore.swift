import Foundation

class OrionStatsStore {
    static let shared = OrionStatsStore()
    
    private let storageKey = "OrionSnapshots"
    private let fileName = "OrionSnapshots.json"
    private var snapshots: [OrionSnapshot] = []
    private let queue = DispatchQueue(label: "com.algotrading.orionstats", attributes: .concurrent)
    
    private init() {
        migrateFromUserDefaults()
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func record(_ snapshot: OrionSnapshot) {
        queue.async(flags: .barrier) {
            // Check for duplicate (Same symbol, same day)
            if !self.hasSnapshotForToday(symbol: snapshot.symbol) {
                self.snapshots.append(snapshot)
                self.save()
                print("📝 Argus Lab: Snapshot recorded for \(snapshot.symbol) (Grade: \(snapshot.orionLetter))")
            } else {
                // Optional: Update existing? For now, we keep the first one of the day.
                print("ℹ️ Argus Lab: Snapshot already exists for \(snapshot.symbol) today. Skipping.")
            }
        }
    }
    
    func loadAll() -> [OrionSnapshot] {
        var result: [OrionSnapshot] = []
        queue.sync {
            result = self.snapshots
        }
        return result
    }
    
    func load(for symbol: String) -> [OrionSnapshot] {
        var result: [OrionSnapshot] = []
        queue.sync {
            result = self.snapshots.filter { $0.symbol == symbol }
        }
        return result
    }
    
    func clearAll() {
        queue.async(flags: .barrier) {
            self.snapshots.removeAll()
            self.save()
        }
    }
    
    // MARK: - Private Helpers
    
    private func hasSnapshotForToday(symbol: String) -> Bool {
        let calendar = Calendar.current
        return snapshots.contains { s in
            s.symbol == symbol && calendar.isDateInToday(s.date)
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: getFileURL())
        } catch {
            print("❌ Argus Lab: Failed to save snapshots to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        let url = getFileURL()
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([OrionSnapshot].self, from: data)
            self.snapshots = decoded
            print("✅ Argus Lab: Loaded \(decoded.count) snapshots from disk.")
        } catch {
            print("⚠️ Argus Lab: Failed to load snapshots (New or Corrupt): \(error)")
        }
    }
    
    private func migrateFromUserDefaults() {
        // Check if data exists in UserDefaults
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            print("🔄 Argus Lab: Found legacy data in UserDefaults. Migrating...")
            if let decoded = try? JSONDecoder().decode([OrionSnapshot].self, from: data) {
                self.snapshots = decoded
                save() // Save to file system
                UserDefaults.standard.removeObject(forKey: storageKey) // Clear legacy
                print("✅ Argus Lab: Migration complete. \(decoded.count) items moved.")
            } else {
                print("❌ Argus Lab: Failed to decode legacy data.")
            }
        }
    }
}
