import SwiftUI

struct DebugPersistenceView: View {
    @State private var keys: [(String, String)] = []
    
    var body: some View {
        List {
            Section(header: Text("UserDefaults Inspection")) {
                if keys.isEmpty {
                    Text("Scanning UserDefaults...")
                } else {
                    ForEach(keys, id: \.0) { item in
                        VStack(alignment: .leading) {
                            Text(item.0)
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(item.1)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            scanKeys()
        }
    }
    
    func scanKeys() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        
        // Filter for relevant keys (exclude system keys)
        let relevant = defaults.compactMap { (key, value) -> (String, String)? in
            if key.starts(with: "Apple") || key.starts(with: "NS") { return nil }
            
            let sensitive = isSensitiveKey(key)

            // Try to describe content
            var desc = "\(type(of: value))"
            if let array = value as? [Any] {
                desc += " [Count: \(array.count)]"
            } else if let dict = value as? [String: Any] {
                desc += " [Keys: \(dict.count)]"
            } else if let data = value as? Data {
                desc += " [Size: \(data.count) bytes]"
            } else if let str = value as? String {
                if sensitive {
                    desc += " \"[REDACTED]\""
                } else {
                    desc += " \"\(str.prefix(50))...\""
                }
            }
            
            return (key, desc)
        }
        .sorted { $0.0 < $1.0 }
        
        self.keys = relevant
    }

    private func isSensitiveKey(_ key: String) -> Bool {
        let lowercasedKey = key.lowercased()
        return lowercasedKey.contains("key")
            || lowercasedKey.contains("token")
            || lowercasedKey.contains("secret")
            || lowercasedKey.contains("auth")
            || lowercasedKey.contains("password")
    }
}
