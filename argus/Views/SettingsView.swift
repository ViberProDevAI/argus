import SwiftUI
import UniformTypeIdentifiers

// MARK: - MAIN SETTINGS VIEW (ROUTER)
struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var activeSettingsSheet: SettingsSheet?
    @State private var chironTradeCount = 0
    @State private var chironEventCount = 0
    @State private var chironWinRate = 0

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - SYSTEM STATUS HEADER
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(InstitutionalTheme.Colors.positive).frame(width: 8, height: 8)
                                Text("SİSTEM: ÇEVRİMİÇİ")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.positive)
                                Spacer()
                                Button(action: { showDrawer = true }) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 12))
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                                Text("V.2024.1.0")
                                    .font(InstitutionalTheme.Typography.micro)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            Divider().background(InstitutionalTheme.Colors.borderSubtle)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // MARK: - MODULE 1: CORTEX
                        TerminalSection(title: "CORTEX // ZEKA & ANALİZ") {
                            NavigationLink(destination: SettingsCortexView(settingsViewModel: settingsViewModel)) {
                                ArgusTerminalRow(label: "VERİ AKIŞI & API", value: "BAĞLI", icon: "server.rack", color: .cyan)
                            }
                            NavigationLink(destination: ChironDetailView()) {
                                ArgusTerminalRow(
                                    label: "CHIRON KOKPİT",
                                    value: "WR %\(chironWinRate) | T \(chironTradeCount)",
                                    icon: "brain",
                                    color: .cyan
                                )
                            }
                            NavigationLink(destination: ChironPerformanceView()) {
                                ArgusTerminalRow(
                                    label: "CHIRON PERFORMANS",
                                    value: "EVENT \(chironEventCount)",
                                    icon: "chart.bar.xaxis",
                                    color: .green
                                )
                            }
                            NavigationLink(destination: ChironInsightsView(symbol: nil)) {
                                ArgusTerminalRow(label: "CHIRON İNSIGHT", value: "DETAY", icon: "waveform.path.ecg", color: .purple)
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
                                    .foregroundColor(InstitutionalTheme.Colors.primary)
                                    .font(.system(size: 12))
                                Text("KARANLIK MOD")
                                    .font(InstitutionalTheme.Typography.body)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Spacer()
                                Toggle("", isOn: $isDarkMode)
                                    .labelsHidden()
                                    .tint(InstitutionalTheme.Colors.primary)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // MARK: - STORAGE CLEANUP
                        StorageCleanupSection()
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                
                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(200)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await refreshChironSnapshot()
        }
        .sheet(item: $activeSettingsSheet) { sheet in
            settingsSheetView(for: sheet)
        }
    }

    private func refreshChironSnapshot() async {
        let trades = await ChironDataLakeService.shared.loadAllTradeHistory()
        let events = await ChironDataLakeService.shared.loadLearningEvents()

        chironTradeCount = trades.count
        chironEventCount = events.count

        guard !trades.isEmpty else {
            chironWinRate = 0
            return
        }

        let wins = trades.filter { $0.pnlPercent > 0 }.count
        chironWinRate = Int((Double(wins) / Double(trades.count)) * 100)
    }
}

// MARK: - Settings Drawer Support
extension SettingsView {
    enum SettingsSheet: Identifiable {
        case priceAlerts
        case dataHealth
        case serviceHealth
        case apiKeys
        case guide
        case signals
        case chironCockpit
        
        var id: String {
            switch self {
            case .priceAlerts: return "priceAlerts"
            case .dataHealth: return "dataHealth"
            case .serviceHealth: return "serviceHealth"
            case .apiKeys: return "apiKeys"
            case .guide: return "guide"
            case .signals: return "signals"
            case .chironCockpit: return "chironCockpit"
            }
        }
    }
    
    @ViewBuilder
    private func settingsSheetView(for sheet: SettingsSheet) -> some View {
        switch sheet {
        case .priceAlerts:
            NavigationView { PriceAlertSettingsView() }
        case .dataHealth:
            NavigationView { ArgusDataHealthView() }
        case .serviceHealth:
            NavigationView { ServiceHealthView() }
        case .apiKeys:
            NavigationView { APIKeyCenterView() }
        case .guide:
            NavigationView { ArgusGuideView() }
        case .signals:
            NavigationView { SettingsSignalsView() }
        case .chironCockpit:
            NavigationView { ChironDetailView() }
        }
    }
    
    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "EKRANLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAlkindusDashboard"), object: nil)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portfoy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "AYARLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Fiyat Alarmlari", subtitle: "Alarm ayarlari", icon: "bell") {
                        activeSettingsSheet = .priceAlerts
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Veri Sagligi", subtitle: "Kaynak durumu", icon: "waveform.path.ecg") {
                        activeSettingsSheet = .dataHealth
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "API Key Merkezi", subtitle: "Tek ekran yonetim", icon: "key.fill") {
                        activeSettingsSheet = .apiKeys
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Servis Durumu", subtitle: "API sagligi", icon: "shield") {
                        activeSettingsSheet = .serviceHealth
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Argus Rehberi", subtitle: "Kullanim kilavuzu", icon: "book") {
                        activeSettingsSheet = .guide
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sinyal Ayarlari", subtitle: "Bildirim ve sinyal", icon: "slider.horizontal.3") {
                        activeSettingsSheet = .signals
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Chiron Kokpit", subtitle: "Ogrenme ve agirliklar", icon: "brain.head.profile") {
                        activeSettingsSheet = .chironCockpit
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(commonToolsSection(openSheet: openSheet))
        
        return sections
    }
    
    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "ARACLAR",
            items: [
                ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                    openSheet(.calendar)
                },
                ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                    openSheet(.dictionary)
                },
                ArgusDrawerView.DrawerItem(title: "Unlu Finans Sozleri", subtitle: "Finans alintilari", icon: "quote.opening") {
                    openSheet(.financeWisdom)
                },
                ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sagligi", icon: "waveform.path.ecg") {
                    openSheet(.systemHealth)
                },
                ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                    openSheet(.feedback)
                }
            ]
        )
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
                .font(InstitutionalTheme.Typography.micro)
                .tracking(1.5)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
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
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            
            Spacer()
            
            if let v = value {
                Text(v)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(color.opacity(0.8))
            }
            
            Image(systemName: "chevron.right")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.7))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // Divider at bottom
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(InstitutionalTheme.Colors.borderSubtle),
            alignment: .bottom
        )
    }
}

// MARK: - MODULE: CORTEX (INTELLIGENCE)
struct SettingsCortexView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 24) {
                    TerminalSection(title: "API ANAHTAR MERKEZI") {
                        NavigationLink(destination: APIKeyCenterView()) {
                            ArgusTerminalRow(label: "MERKEZI API YONETIMI", value: "GELISMIS", icon: "key.fill", color: .cyan)
                        }

                        Text("Tum API anahtarlari tek ekrandan yonetilir. Cift kayit ve daginik ayarlar kaldirildi.")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
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
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var importResult: String? = nil
    @State private var isMigrationExporting = false

    private var migrationStatsText: String {
        let stats = LearningDataMigrationService.shared.getLearningDataStats()
        return "\(stats.totalFiles) DOSYA"
    }

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
                    
                    // MARK: - VERİ TAŞIMA (Migration)
                    TerminalSection(title: "ESKİ UYGULAMADAN VERİ AKTAR") {
                        // Import butonu
                        Button(action: { showingFileImporter = true }) {
                            ArgusTerminalRow(
                                label: "ÖĞRENMELERİ İÇE AKTAR",
                                value: isImporting ? "AKTARILIYOR..." : "DOSYA SEÇ",
                                icon: "arrow.down.doc.fill",
                                color: Color(red: 1.0, green: 0.8, blue: 0.2)
                            )
                        }
                        .disabled(isImporting)

                        // Import sonucu
                        if let result = importResult {
                            HStack(spacing: 8) {
                                Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.contains("✅") ? .green : .red)
                                Text(result)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(result.contains("✅") ? .green : .red)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }

                        // Mevcut veri durumu
                        VStack(alignment: .leading, spacing: 4) {
                            let stats = LearningDataMigrationService.shared.getLearningDataStats()
                            Text("Mevcut Chiron: \(stats.chironWeightSymbols) sembol, \(stats.chironTradeFiles) işlem dosyası")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("Mevcut Alkindus: \(stats.alkindusFilesFound) kalibrasyon dosyası")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        // Export butonu (mevcut veriyi dışa aktar)
                        Button(action: { exportAllLearningData() }) {
                            ArgusTerminalRow(
                                label: "TÜM ÖĞRENMELERİ DIŞA AKTAR",
                                value: isMigrationExporting ? "HAZIRLANIYOR..." : migrationStatsText,
                                icon: "arrow.up.doc.on.clipboard",
                                color: .blue
                            )
                        }
                        .disabled(isMigrationExporting)
                    }
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        handleFileImport(result)
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
    
    // MARK: - Migration Import
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            isImporting = true
            importResult = nil

            // Dosyaya erişim izni al
            guard selectedURL.startAccessingSecurityScopedResource() else {
                importResult = "❌ Dosya erişim hatası"
                isImporting = false
                return
            }

            Task {
                do {
                    let stats = try await LearningDataMigrationService.shared.importLearningData(from: selectedURL)
                    selectedURL.stopAccessingSecurityScopedResource()
                    await MainActor.run {
                        isImporting = false
                        importResult = "✅ \(stats.totalFiles) dosya içe aktarıldı! Chiron: \(stats.chironWeightSymbols) sembol, Alkindus: \(stats.alkindusFilesFound) dosya"
                    }
                } catch {
                    selectedURL.stopAccessingSecurityScopedResource()
                    await MainActor.run {
                        isImporting = false
                        importResult = "❌ Hata: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            importResult = "❌ Dosya seçim hatası: \(error.localizedDescription)"
        }
    }

    // MARK: - Migration Export
    private func exportAllLearningData() {
        isMigrationExporting = true
        Task {
            do {
                let url = try await LearningDataMigrationService.shared.exportAllLearningData()
                await MainActor.run {
                    isMigrationExporting = false
                    self.exportURL = url
                    self.showingExportSheet = true
                }
            } catch {
                await MainActor.run {
                    isMigrationExporting = false
                    alertMessage = "Migration export hatası: \(error.localizedDescription)"
                    showingAlert = true
                }
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
