import SwiftUI

struct HeimdallKeysView: View {
    @StateObject private var store = APIKeyStore.shared
    @State private var showingAddSheet = false
    @State private var selectedProvider: APIProvider = .fred
    @State private var newKey = ""
    
    var body: some View {
        List {
            Section(header: Text("Kayıtlı Anahtarlar (SSoT)")) {
                if store.keys.isEmpty {
                    Text("Hiç anahtar bulunamadı. Migration bekleniyor veya manuel ekleyin.")
                        .foregroundColor(.secondary)
                    
                    // Debug: Provider listesi
                    Text("Toplam Provider Sayısı: \(APIProvider.allCases.count)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text("- \(provider.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Map dictionary to array
                    let keysArray = store.keys.map { $0 }.sorted { $0.key.rawValue < $1.key.rawValue }
                    
                    ForEach(keysArray, id: \.key) { (provider, key) in
                        KeyRow(provider: provider, key: key)
                            .swipeActions {
                                Button("Sil", role: .destructive) {
                                    Task { store.deleteKey(provider: provider) }
                                }
                            }
                    }
                }
            }
            
            Section(header: Text("Yeni Anahtar Ekle")) {
                Picker("Sağlayıcı", selection: $selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { prov in
                        Text(prov.rawValue).tag(prov)
                    }
                }
                
                TextField("API Key Yapıştır", text: $newKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Anahtarı Kaydet") {
                    guard !newKey.isEmpty else { return }
                    Task {
                        store.setKey(provider: selectedProvider, key: newKey)
                        newKey = ""
                    }
                }
                .disabled(newKey.isEmpty)
            }
            
            Section(footer: Text("SSoT: Single Source of Truth. Bu veriler Keychain'de şifreli saklanır ve tüm uygulama tarafından tek kaynak olarak kullanılır.")) {
                EmptyView()
            }
        }
        .navigationTitle("Anahtar Kasası")
    }
}

struct KeyRow: View {
    let provider: APIProvider
    let key: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(provider.rawValue)
                    .font(.headline)
                Text(key.count > 4 ? String(key.prefix(4)) + "..." : "****")
                    .font(.monospaced(.caption)())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Label("Aktif", systemImage: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}
