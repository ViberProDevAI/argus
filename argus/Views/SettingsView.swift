import SwiftUI

// MARK: - MAIN SETTINGS VIEW (ROUTER)
struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        NavigationView {
            ZStack {
                // Background: Pure Terminal Black
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - SYSTEM STATUS HEADER
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text("SİSTEM: ÇEVRİMİÇİ")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                Spacer()
                                Text("V.2024.1.0")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Divider().background(Color.gray.opacity(0.3))
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // MARK: - MODULE 1: CORTEX
                        TerminalSection(title: "CORTEX // ZEKA & ANALİZ") {
                            NavigationLink(destination: SettingsCortexView(settingsViewModel: settingsViewModel)) {
                                ArgusTerminalRow(label: "VERİ AKIŞI & API", value: "BAĞLI", icon: "server.rack", color: .cyan)
                            }
                            NavigationLink(destination: ChironInsightsView(symbol: nil)) {
                                ArgusTerminalRow(label: "CHIRON ÖĞRENME", value: "AKTİF", icon: "brain", color: .cyan)
                            }
                            NavigationLink(destination: AlkindusDashboardView()) {
                                ArgusTerminalRow(label: "ALKINDUS KALİBRASYON", value: "SHADOW", icon: "eye.circle", color: .purple)
                            }
                            NavigationLink(destination: StrategyDashboardView(viewModel: TradingViewModel())) {
                                ArgusTerminalRow(label: "STRATEJİ MERKEZİ", value: "YENİ", icon: "chart.bar.xaxis", color: .orange)
                            }
                            NavigationLink(destination: ArgusSimulatorView()) {
                                ArgusTerminalRow(label: "SİMÜLASYON LAB", value: "HAZIR", icon: "flask", color: .purple)
                            }
                        }
                        
                        // MARK: - MODULE 2: KERNEL
                        TerminalSection(title: "KERNEL // MOTOR AYARLARI") {
                            NavigationLink(destination: ArgusKernelView()) {
                                ArgusTerminalRow(label: "ÇEKİRDEK PARAMETRELERİ", value: "ÖZEL", icon: "cpu", color: .orange)
                            }
                        }
                        
                        // MARK: - MODULE 3: COMMS
                        TerminalSection(title: "COMMS // İLETİŞİM") {
                            NavigationLink(destination: SettingsCommsView(settingsViewModel: settingsViewModel)) {
                                ArgusTerminalRow(label: "BİLDİRİMLER", value: "AÇIK", icon: "antenna.radiowaves.left.and.right", color: .green)
                            }
                        }
                        
                        // MARK: - MODULE 4: CODEX
                        TerminalSection(title: "CODEX // KAYITLAR") {
                            NavigationLink(destination: SettingsCodexView(settingsViewModel: settingsViewModel)) {
                                ArgusTerminalRow(label: "SİSTEM LOGLARI", value: "GÖRÜNTÜLE", icon: "doc.text", color: .gray)
                            }
                        }
                        
                        // MARK: - QUICK CONFIG
                        TerminalSection(title: "AYARLAR") {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 12))
                                Text("KARANLIK MOD")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $isDarkMode)
                                    .labelsHidden()
                                    .tint(.purple)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // MARK: - STORAGE CLEANUP
                        StorageCleanupSection()
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - UI COMPONENT: TERMINAL SECTION
struct TerminalSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Color.gray.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(Color(white: 0.08)) // Dark gray background for blocks
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - UI COMPONENT: TERMINAL ROW
struct ArgusTerminalRow: View {
    let label: String
    let value: String?
    let icon: String
    let color: Color
    
    init(label: String, value: String?, icon: String, color: Color) {
        self.label = label
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            if let v = value {
                Text(v)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // Divider at bottom
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.1)),
            alignment: .bottom
        )
    }
}

// MARK: - MODULE: CORTEX (INTELLIGENCE)
struct SettingsCortexView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("tcmb_evds_api_key") private var tcmbApiKey: String = ""
    @AppStorage("collectapi_key") private var collectApiKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: String = ""
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 24) {
                    // TCMB EVDS API
                    TerminalSection(title: "TCMB EVDS API") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("API KEY")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                if tcmbApiKey.isEmpty {
                                    Text("TANIMLANMADI")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.red)
                                } else {
                                    Text("TANIMLI")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            SecureField("TCMB API Key", text: $tcmbApiKey)
                                .font(.system(size: 14, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            
                            HStack {
                                Button(action: testConnection) {
                                    HStack {
                                        if isTestingConnection {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "network")
                                        }
                                        Text("BAĞLANTI TEST")
                                            .font(.system(size: 10, design: .monospaced))
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.cyan.opacity(0.2))
                                    .cornerRadius(6)
                                }
                                .disabled(tcmbApiKey.isEmpty || isTestingConnection)
                                
                                if !connectionStatus.isEmpty {
                                    Text(connectionStatus)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(connectionStatus.contains("BAŞARILI") ? .green : .red)
                                }
                            }
                            
                            Text("evds2.tcmb.gov.tr adresinden ücretsiz alınır")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // COLLECTAPI (BIST Verileri)
                    TerminalSection(title: "COLLECTAPI // BIST") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("API KEY")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                if collectApiKey.isEmpty {
                                    Text("TANIMLANMADI")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.red)
                                } else {
                                    Text("TANIMLI")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            SecureField("CollectAPI Key", text: $collectApiKey)
                                .font(.system(size: 14, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            
                            Text("collectapi.com adresinden alinir (BIST hisse verileri)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // LLM API KEYS (NEW)
                    TerminalSection(title: "YAPAY ZEKA MOTORLARI (LLM)") {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            // GROQ
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("GROQ API (LLAMA 3.3)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !APIKeyStore.shared.groqApiKey.isEmpty {
                                        Text("AKTİF")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.green)
                                    }
                                }
                                SecureField("Groq API Key (gsk_...)", text: Binding(
                                    get: { APIKeyStore.shared.getKey(for: .groq) ?? "" },
                                    set: { APIKeyStore.shared.setKey(provider: .groq, key: $0) }
                                ))
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            }
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            // GEMINI
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("GOOGLE GEMINI PRO")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !APIKeyStore.shared.geminiApiKey.isEmpty {
                                        Text("AKTİF")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.green)
                                    }
                                }
                                SecureField("Gemini API Key (AIza...)", text: Binding(
                                    get: { APIKeyStore.shared.getKey(for: .gemini) ?? "" },
                                    set: { APIKeyStore.shared.setKey(provider: .gemini, key: $0) }
                                ))
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            }
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            // DEEPSEEK
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("DEEPSEEK V3")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !APIKeyStore.shared.deepSeekApiKey.isEmpty {
                                        Text("AKTİF")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.green)
                                    }
                                }
                                SecureField("DeepSeek API Key (sk_...)", text: Binding(
                                    get: { APIKeyStore.shared.getKey(for: .deepSeek) ?? "" },
                                    set: { APIKeyStore.shared.setKey(provider: .deepSeek, key: $0) }
                                ))
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            }
                            
                            Text("Bu anahtarlar cihazınızda yerel olarak saklanır. Çalışan bir API key girerek limit sorunlarını çözebilirsiniz.")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 4)
                            
                        }
                        .padding(.vertical, 8)
                    }
                    
                    TerminalSection(title: "VERI AKISLARI") {
                        NavigationLink(destination: ArgusDataHealthView()) {
                            ArgusTerminalRow(label: "API GECIDI", value: "AYARLAR", icon: "server.rack", color: .indigo)
                        }
                    }
                    
                    TerminalSection(title: "SINIR AGI") {
                        NavigationLink(destination: ChironInsightsView(symbol: nil)) {
                            ArgusTerminalRow(label: "CHIRON AGIRLIKLARI", value: "INCELE", icon: "network", color: .cyan)
                        }
                        NavigationLink(destination: ArgusSimulatorView()) {
                            ArgusTerminalRow(label: "SIMULASYON LAB", value: "BASLAT", icon: "flask.fill", color: .purple)
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("CORTEX")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = ""
        
        Task {
            let success = await TCMBDataService.shared.testConnection()
            await MainActor.run {
                isTestingConnection = false
                connectionStatus = success ? "BASARILI" : "HATA"
            }
        }
    }
}

// MARK: - MODULE: ARGUS KERNEL (ENGINE)
struct ArgusKernelView: View {
    @AppStorage("kernel_aggressiveness") private var aggressiveness: Double = 0.55
    @AppStorage("kernel_risk_tolerance") private var riskTolerance: Double = 0.05
    @AppStorage("kernel_authority_tech") private var authorityTech: Double = 0.85
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 24) {
                    
                    // AGGRESSIVENESS
                    TerminalSection(title: "SALDIRGANLIK FAKTÖRÜ") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("EŞİK SAPMASI")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.2f", aggressiveness))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            Slider(value: $aggressiveness, in: 0.50...0.80, step: 0.01)
                                .tint(.orange)
                            
                            HStack {
                                Text("MUHAFAZAKAR")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("AGRESİF")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // AUTHORITY
                    TerminalSection(title: "TEKNİK OTORİTE") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("AĞIRLIK ÇARPANI")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.2fx", authorityTech))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple)
                            }
                            Slider(value: $authorityTech, in: 0.5...1.5, step: 0.05)
                                .tint(.purple)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // RISK
                    TerminalSection(title: "RİSK PROTOKOLLERİ") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("STOP LOSS TOLERANSI")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.1f%%", riskTolerance * 100))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            Slider(value: $riskTolerance, in: 0.01...0.10, step: 0.005)
                                .tint(.red)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("KERNEL")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MODULE: COMMS
struct SettingsCommsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("notify_all_signals") private var notifyAllSignals = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 24) {
                    TerminalSection(title: "BİLDİRİM KANALLARI") {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.green)
                            Text("SİNYAL UYARILARI")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $notifyAllSignals)
                                .labelsHidden()
                                .tint(.green)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    TerminalSection(title: "WIDGET'LAR") {
                        NavigationLink(destination: WidgetListSettingsView()) {
                            ArgusTerminalRow(label: "ANA EKRAN WIDGET", value: "DÜZENLE", icon: "square.grid.2x2", color: .blue)
                        }
                    }
                    
                    TerminalSection(title: "FİYAT ALARMLARI") {
                         NavigationLink(destination: PriceAlertSettingsView()) {
                             ArgusTerminalRow(label: "İZLEME LİSTESİ ALARMLARI", value: "DÜZENLE", icon: "exclamationmark.bubble", color: .red)
                         }
                    }
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("COMMS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MODULE: CODEX
struct SettingsCodexView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showingExportSheet = false
    @State private var exportURL: URL? = nil
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 24) {
                    TerminalSection(title: "YASAL BELGELER") {
                        NavigationLink(destination: LegalDocumentView(document: settingsViewModel.privacyPolicy)) {
                            ArgusTerminalRow(label: "GİZLİLİK POLİTİKASI", value: nil, icon: "hand.raised", color: .gray)
                        }
                        NavigationLink(destination: LegalDocumentView(document: settingsViewModel.termsOfUse)) {
                             ArgusTerminalRow(label: "KULLANIM KOŞULLARI", value: nil, icon: "doc.text", color: .gray)
                        }
                        NavigationLink(destination: LegalDocumentView(document: settingsViewModel.riskDisclosure)) {
                             ArgusTerminalRow(label: "RİSK BİLDİRİMİ", value: nil, icon: "exclamationmark.triangle", color: .orange)
                         }
                    }
                    
                    TerminalSection(title: "HATA AYIKLAMA ARAÇLARI") {
                         Button(action: {
                            Task {
                                let logContent = await HeimdallDebugBundleExporter.shared.generateBundle()
                                let fileName = "Argus_System_Log_\(Date().timeIntervalSince1970).txt"
                                let tempDir = FileManager.default.temporaryDirectory
                                let fileURL = tempDir.appendingPathComponent(fileName)
                                do {
                                    try logContent.write(to: fileURL, atomically: true, encoding: .utf8)
                                    self.exportURL = fileURL
                                    self.showingExportSheet = true
                                } catch {
                                    print("Log export failed: \(error)")
                                }
                            }
                        }) {
                            ArgusTerminalRow(label: "SİSTEM DÖKÜMÜ İNDİR", value: "ÇALIŞTIR", icon: "arrow.up.doc", color: .blue)
                        }
                        .sheet(isPresented: $showingExportSheet) {
                            if let url = exportURL {
                                ArgusShareSheet(activityItems: [url])
                            } else {
                                Text("LOG OLUŞTURMA HATASI")
                            }
                        }
                    }
                    
                    // MARK: - VERİ İNDİRME
                    TerminalSection(title: "VERİ İNDİRME") {
                        // Trade History Export
                        Button(action: { exportTradeHistory() }) {
                            ArgusTerminalRow(label: "İŞLEM GEÇMİŞİ", value: "JSON", icon: "arrow.up.doc", color: .green)
                        }
                        
                        // Forward Test Export
                        Button(action: { exportForwardTests() }) {
                            ArgusTerminalRow(label: "FORWARD TEST SONUÇLARI", value: "JSON", icon: "lab.flask", color: .purple)
                        }
                        
                        // Decision Events Export
                        Button(action: { exportDecisionEvents() }) {
                            ArgusTerminalRow(label: "KARAR GEÇMİŞİ", value: "JSON", icon: "brain", color: .cyan)
                        }
                        
                        // Alkindus Calibration Export
                        Button(action: { exportAlkindusCalibration() }) {
                            ArgusTerminalRow(label: "ALKINDUS ÖĞRENMELERİ", value: "JSON", icon: "brain.head.profile", color: .yellow)
                        }
                    }
                    
                    // Footer
                    VStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.title)
                            .foregroundColor(Color.purple.opacity(0.3))
                        Text("ARGUS TERMINAL V1.1")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.3))
                    }
                    .padding(.top, 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("CODEX")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Bilgi", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Export Functions
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private func exportTradeHistory() {
        Task {
            let trades = await ChironDataLakeService.shared.loadAllTradeHistory()
            if trades.isEmpty {
                await MainActor.run {
                    alertMessage = "İşlem geçmişi boş. Henüz tamamlanmış işlem yok."
                    showingAlert = true
                }
                return
            }
            guard let data = try? JSONEncoder().encode(trades) else { return }
            let fileName = "Argus_TradeHistory_\(Date().timeIntervalSince1970).json"
            await MainActor.run {
                saveAndShare(data: data, fileName: fileName)
            }
        }
    }
    
    private func exportForwardTests() {
        // Export the ArgusLedger SQLite database directly
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = docsPath.appendingPathComponent("ArgusScience_V1.sqlite")
        
        if FileManager.default.fileExists(atPath: dbPath.path) {
            let fileName = "ArgusScience_\(Date().timeIntervalSince1970).sqlite"
            let tempDir = FileManager.default.temporaryDirectory
            let destPath = tempDir.appendingPathComponent(fileName)
            do {
                try FileManager.default.copyItem(at: dbPath, to: destPath)
                exportURL = destPath
                showingExportSheet = true
            } catch {
                alertMessage = "Database export hatası: \(error.localizedDescription)"
                showingAlert = true
            }
        } else {
            alertMessage = "Veritabanı dosyası bulunamadı."
            showingAlert = true
        }
    }
    
    private func exportDecisionEvents() {
        // Export ChironDataLake folder
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataLakePath = docsPath.appendingPathComponent("chiron_datalake")
        
        if FileManager.default.fileExists(atPath: dataLakePath.path) {
            // Create a zip or just share the folder path info
            let content = "ChironDataLake Path: \(dataLakePath.path)\n\nBu klasördeki dosyaları Files uygulamasından bulabilirsiniz."
            let fileName = "ChironDataLake_Info.txt"
            saveAndShare(data: Data(content.utf8), fileName: fileName)
        } else {
            alertMessage = "ChironDataLake klasörü bulunamadı."
            showingAlert = true
        }
    }
    
    private func exportAlkindusCalibration() {
        Task {
            let stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
            if stats.calibration.modules.isEmpty {
                await MainActor.run {
                    alertMessage = "Alkindus henüz veri toplamadı. Kararlar verildikçe burada istatistikler oluşacak."
                    showingAlert = true
                }
                return
            }
            guard let data = try? JSONEncoder().encode(stats.calibration) else { return }
            let fileName = "Alkindus_Calibration_\(Date().timeIntervalSince1970).json"
            await MainActor.run {
                saveAndShare(data: data, fileName: fileName)
            }
        }
    }
    
    private func saveAndShare(data: Data, fileName: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            self.exportURL = fileURL
            self.showingExportSheet = true
        } catch {
            alertMessage = "Export hatası: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - UTILITY: LEGAL DOCUMENT VIEWER
struct LegalDocumentView: View {
    let document: LegalDocument
    
    var body: some View {
        ScrollView {
            Text(document.content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .foregroundColor(.white)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle(document.title)
    }
}

// MARK: - UTILITY: SHARE SHEET
struct ArgusShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - STORAGE CLEANUP SECTION
struct StorageCleanupSection: View {
    @State private var isCleaningUp = false
    @State private var cleanupResult: String?
    @State private var storageSize: String = "Hesaplanıyor..."
    @State private var showCleanupConfirmation = false
    
    var body: some View {
        TerminalSection(title: "DEPOLAMA // TEMİZLİK") {
            VStack(alignment: .leading, spacing: 12) {
                // Current storage size
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("KULLANILAN ALAN")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(storageSize)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Cleanup button
                Button(action: { showCleanupConfirmation = true }) {
                    HStack {
                        if isCleaningUp {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.red)
                        } else {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                        Text(isCleaningUp ? "TEMİZLENİYOR..." : "Cache ve Geçici Verileri Temizle")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .disabled(isCleaningUp)
                .padding(.vertical, 8)
                
                // Result
                if let result = cleanupResult {
                    Text(result)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                // Warning
                Text("⚠️ Blob, cache ve eski event verileri silinir. Öğrenme verileri korunur.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            calculateStorageSize()
        }
        .alert("Emin misiniz?", isPresented: $showCleanupConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Temizle", role: .destructive) {
                performCleanup()
            }
        } message: {
            Text("Bu işlem sadece cache ve geçici dosyaları silecek. İşlem geçmişi ve öğrenme verileri korunacaktır.")
        }
    }
    
    private func calculateStorageSize() {
        Task {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            
            var totalSize: Int64 = 0
            
            if let docs = docsDir {
                totalSize += folderSize(url: docs)
            }
            if let caches = cachesDir {
                totalSize += folderSize(url: caches)
            }
            
            let mb = Double(totalSize) / 1024.0 / 1024.0
            let gb = mb / 1024.0
            
            await MainActor.run {
                if gb >= 1.0 {
                    storageSize = String(format: "%.2f GB", gb)
                } else {
                    storageSize = String(format: "%.0f MB", mb)
                }
            }
        }
    }
    
    private func folderSize(url: URL) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0
        
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize ?? 0)
                }
            }
        }
        return size
    }
    
    private func performCleanup() {
        isCleaningUp = true
        cleanupResult = nil
        
        Task {
            // 1. ArgusLedger cleanup
            let ledgerResult = await ArgusLedger.shared.aggressiveCleanup(maxBlobAgeDays: 0, maxEventAgeDays: 0)
            
            // 2. DiskCache cleanup
            DiskCacheService.shared.cleanup(maxAgeDays: 0)
            DiskCacheService.shared.clearAll()
            
            // 3. Clear Documents folder large files
            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fm = FileManager.default
                if let contents = try? fm.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil) {
                    let safeToCleanFiles: Set<String> = [
                        "ArgusScience_V1.sqlite",
                        "ArgusScience_V2.sqlite",
                        "forward_test_results.json",
                        "argus_data_export.zip"
                    ]
                    
                    for url in contents {
                        let name = url.lastPathComponent
                        
                        // Sadece tanımlı güvenli dosyaları sil
                        if let safeName = safeToCleanFiles.first(where: { name.contains($0) }) {
                            do {
                                try fm.removeItem(at: url)
                                print("✅ Deleted safe file: \(name)")
                            } catch {
                                print("❌ Failed to delete \(name): \(error)")
                            }
                        } else if name.hasSuffix(".sqlite") || name.hasSuffix(".json") || name.hasSuffix(".zip") {
                            print("⚠️ Skipped potentially important file: \(name)")
                        }
                    }
                }
            }
            
            await MainActor.run {
                isCleaningUp = false
                cleanupResult = ledgerResult.summary
                calculateStorageSize()
            }
        }
    }
}
