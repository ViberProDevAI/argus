import SwiftUI

struct APIKeyCenterView: View {
    private enum KeyFilter: String, CaseIterable, Identifiable {
        case all = "Tumunu Goster"
        case configured = "Tanimli"
        case missing = "Eksik"

        var id: String { rawValue }
    }

    private enum Category: String, CaseIterable, Identifiable {
        case market = "Piyasa Verisi"
        case macro = "Makro"
        case intelligence = "Yapay Zeka"
        case infrastructure = "Altyapi"

        var id: String { rawValue }
    }

    private enum Source {
        case provider(APIProvider)
        case customKey(String)
    }

    private enum TestMode {
        case heimdall(ArgusProvider)
        case tcmb
        case unsupported
    }

    private struct KeyEntry: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let placeholder: String
        let category: Category
        let source: Source
        let testMode: TestMode
    }

    private struct TestState {
        let success: Bool
        let message: String
    }

    @State private var searchText = ""
    @State private var filter: KeyFilter = .all
    @State private var categoryFilter: Category?
    @State private var drafts: [String: String] = [:]
    @State private var persisted: [String: String] = [:]
    @State private var revealed: Set<String> = []
    @State private var testing: Set<String> = []
    @State private var testStates: [String: TestState] = [:]

    private var entries: [KeyEntry] {
        [
            KeyEntry(
                id: "tcmb_evds",
                title: "TCMB EVDS",
                subtitle: "Turkiye makro veri kaynagi",
                placeholder: "TCMB API Key",
                category: .macro,
                source: .customKey("tcmb_evds_api_key"),
                testMode: .tcmb
            ),
            KeyEntry(
                id: "fred",
                title: "FRED",
                subtitle: "Kuresel makro indikatorler",
                placeholder: "FRED API Key",
                category: .macro,
                source: .provider(.fred),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "collectapi",
                title: "CollectAPI",
                subtitle: "BIST yardimci veri girisi",
                placeholder: "CollectAPI Key",
                category: .market,
                source: .customKey("collectapi_key"),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "fmp",
                title: "Financial Modeling Prep",
                subtitle: "Profil, haber ve finansal tablo verileri",
                placeholder: "FMP API Key",
                category: .market,
                source: .provider(.fmp),
                testMode: .heimdall(.fmp)
            ),
            KeyEntry(
                id: "twelve_data",
                title: "Twelve Data",
                subtitle: "Anlik fiyat ve zaman serisi",
                placeholder: "Twelve Data API Key",
                category: .market,
                source: .provider(.twelveData),
                testMode: .heimdall(.twelveData)
            ),
            KeyEntry(
                id: "tiingo",
                title: "Tiingo",
                subtitle: "Alternatif fiyat ve temel veri",
                placeholder: "Tiingo API Key",
                category: .market,
                source: .provider(.tiingo),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "eodhd",
                title: "EODHD",
                subtitle: "Global hisse/ETF ve screener",
                placeholder: "EODHD API Key",
                category: .market,
                source: .provider(.eodhd),
                testMode: .heimdall(.eodhd)
            ),
            KeyEntry(
                id: "alpha_vantage",
                title: "Alpha Vantage",
                subtitle: "Teknik ve temel veri",
                placeholder: "Alpha Vantage API Key",
                category: .market,
                source: .provider(.alphaVantage),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "marketstack",
                title: "MarketStack",
                subtitle: "Alternatif market feed",
                placeholder: "MarketStack API Key",
                category: .market,
                source: .provider(.marketstack),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "massive",
                title: "Massive",
                subtitle: "Opsiyon ve zincir verisi",
                placeholder: "Massive Token",
                category: .infrastructure,
                source: .provider(.massive),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "pinecone",
                title: "Pinecone",
                subtitle: "Vektor veritabani ulasimi",
                placeholder: "Pinecone API Key",
                category: .infrastructure,
                source: .provider(.pinecone),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "groq",
                title: "Groq",
                subtitle: "Llama tabanli model cagirilari",
                placeholder: "Groq API Key (gsk_...)",
                category: .intelligence,
                source: .provider(.groq),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "gemini",
                title: "Gemini",
                subtitle: "Google model ailesi",
                placeholder: "Gemini API Key (AIza...)",
                category: .intelligence,
                source: .provider(.gemini),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "glm",
                title: "GLM",
                subtitle: "Zhipu GLM erisimi",
                placeholder: "GLM API Key",
                category: .intelligence,
                source: .provider(.glm),
                testMode: .unsupported
            ),
            KeyEntry(
                id: "deepseek",
                title: "DeepSeek",
                subtitle: "DeepSeek model erisimi",
                placeholder: "DeepSeek API Key (sk_...)",
                category: .intelligence,
                source: .provider(.deepSeek),
                testMode: .unsupported
            )
        ]
    }

    private var filteredEntries: [KeyEntry] {
        entries.filter { entry in
            if let categoryFilter, entry.category != categoryFilter {
                return false
            }

            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesTitle = entry.title.lowercased().contains(query)
                let matchesSubtitle = entry.subtitle.lowercased().contains(query)
                if !matchesTitle && !matchesSubtitle {
                    return false
                }
            }

            let value = drafts[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            switch filter {
            case .all:
                return true
            case .configured:
                return !value.isEmpty
            case .missing:
                return value.isEmpty
            }
        }
    }

    private var groupedEntries: [Category: [KeyEntry]] {
        Dictionary(grouping: filteredEntries, by: { $0.category })
    }

    private var visibleCategories: [Category] {
        Category.allCases.filter { groupedEntries[$0] != nil }
    }

    private var configuredCount: Int {
        entries.reduce(0) { partialResult, entry in
            let key = persisted[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            return partialResult + (key.isEmpty ? 0 : 1)
        }
    }

    private var hasDirtyEdits: Bool {
        entries.contains { entry in
            drafts[entry.id, default: ""] != persisted[entry.id, default: ""]
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                summaryCard
                searchAndFilterArea

                ScrollView {
                    VStack(spacing: 16) {
                        categoryChips

                        ForEach(visibleCategories) { category in
                            if let categoryEntries = groupedEntries[category] {
                                TerminalSection(title: category.rawValue.uppercased()) {
                                    VStack(spacing: 12) {
                                        ForEach(categoryEntries) { entry in
                                            keyRow(for: entry)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationTitle("API Key Merkezi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadValuesFromStorage)
        .onReceive(NotificationCenter.default.publisher(for: .argusKeyStoreDidUpdate)) { _ in
            if !hasDirtyEdits {
                loadValuesFromStorage()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Merkezi Yonetim", systemImage: "key.horizontal.fill")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(configuredCount)/\(entries.count) TANIMLI")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(configuredCount == entries.count ? .green : .orange)
            }

            Text("Tum API anahtarlari tek ekranda yonetilir. Daginik ayar bloklari kaldirildi.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var searchAndFilterArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Saglayici ara", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)

            Picker("Filtre", selection: $filter) {
                ForEach(KeyFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Tum Kategoriler", isSelected: categoryFilter == nil) {
                    categoryFilter = nil
                }

                ForEach(Category.allCases) { category in
                    categoryChip(title: category.rawValue, isSelected: categoryFilter == category) {
                        categoryFilter = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan : Color.white.opacity(0.08))
                .cornerRadius(8)
        }
    }

    private func keyRow(for entry: KeyEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(entry.subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Spacer()

                let configured = !drafts[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Text(configured ? "TANIMLI" : "EKSIK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(configured ? .green : .red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background((configured ? Color.green : Color.red).opacity(0.15))
                    .cornerRadius(6)
            }

            HStack(spacing: 8) {
                Group {
                    if revealed.contains(entry.id) {
                        TextField(
                            entry.placeholder,
                            text: Binding(
                                get: { drafts[entry.id, default: ""] },
                                set: { drafts[entry.id] = $0 }
                            )
                        )
                    } else {
                        SecureField(
                            entry.placeholder,
                            text: Binding(
                                get: { drafts[entry.id, default: ""] },
                                set: { drafts[entry.id] = $0 }
                            )
                        )
                    }
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)

                Button(action: { toggleVisibility(for: entry.id) }) {
                    Image(systemName: revealed.contains(entry.id) ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            HStack(spacing: 8) {
                Button(action: { save(entry) }) {
                    Label("Kaydet", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .buttonStyle(.borderedProminent)
                .tint(isDirty(entry.id) ? .cyan : .gray)
                .disabled(!isDirty(entry.id))

                Button(action: { clear(entry) }) {
                    Label("Temizle", systemImage: "trash")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: { runTest(for: entry) }) {
                    if testing.contains(entry.id) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Label("Test", systemImage: "network")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .tint(.mint)
                .disabled(drafts[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let testState = testStates[entry.id] {
                Text(testState.message)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(testState.success ? .green : .orange)
                    .padding(.top, 2)
            }
        }
    }

    private func loadValuesFromStorage() {
        var snapshot: [String: String] = [:]
        for entry in entries {
            snapshot[entry.id] = readValue(for: entry)
        }
        drafts = snapshot
        persisted = snapshot
    }

    private func readValue(for entry: KeyEntry) -> String {
        switch entry.source {
        case .provider(let provider):
            return APIKeyStore.shared.getKey(for: provider) ?? ""
        case .customKey(let key):
            return APIKeyStore.shared.getCustomValue(for: key) ?? ""
        }
    }

    private func save(_ entry: KeyEntry) {
        let value = drafts[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        drafts[entry.id] = value

        switch entry.source {
        case .provider(let provider):
            APIKeyStore.shared.setKey(provider: provider, key: value)
        case .customKey(let key):
            APIKeyStore.shared.setCustomValue(value, for: key)
        }

        persisted[entry.id] = value
        testStates[entry.id] = nil
    }

    private func clear(_ entry: KeyEntry) {
        switch entry.source {
        case .provider(let provider):
            APIKeyStore.shared.deleteKey(provider: provider)
        case .customKey(let key):
            APIKeyStore.shared.deleteCustomValue(for: key)
        }

        drafts[entry.id] = ""
        persisted[entry.id] = ""
        testStates[entry.id] = nil
    }

    private func isDirty(_ id: String) -> Bool {
        drafts[id, default: ""] != persisted[id, default: ""]
    }

    private func toggleVisibility(for id: String) {
        if revealed.contains(id) {
            revealed.remove(id)
        } else {
            revealed.insert(id)
        }
    }

    private func runTest(for entry: KeyEntry) {
        let key = drafts[entry.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        testing.insert(entry.id)
        testStates[entry.id] = nil

        Task {
            let result: TestState

            switch entry.testMode {
            case .heimdall(let provider):
                let verification = await HeimdallProbe.shared.verifyKey(provider: provider, key: key)
                let message = verification.isValid ? "Dogrulama basarili." : "Dogrulama basarisiz."
                result = TestState(success: verification.isValid, message: message)

            case .tcmb:
                await TCMBDataService.shared.setAPIKey(key)
                let success = await TCMBDataService.shared.testConnection()
                result = TestState(
                    success: success,
                    message: success ? "TCMB baglantisi basarili." : "TCMB baglantisi basarisiz."
                )

            case .unsupported:
                result = TestState(
                    success: false,
                    message: "Bu saglayici icin otomatik test tanimli degil."
                )
            }

            await MainActor.run {
                testing.remove(entry.id)
                testStates[entry.id] = result
            }
        }
    }
}
