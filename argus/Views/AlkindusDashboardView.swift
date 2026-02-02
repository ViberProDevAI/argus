import SwiftUI

// MARK: - Alkindus Dashboard View
/// Displays calibration statistics and module performance insights.
/// Phase 1: Shadow Mode - Read-only observation statistics.

struct AlkindusDashboardView: View {
    @State private var stats: AlkindusStats?
    @State private var isLoading = true
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Processing State
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalToProcess = 0
    @State private var processingResult: ProcessingResult?
    @State private var dbSizeMB: Double = 0
    
    // Theme
    private let bgColor = Color(red: 0.02, green: 0.02, blue: 0.04)
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(cyan)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header Card
                            headerCard(stats: stats)
                            
                            //  Today's Insights (Phase 2)
                            insightsSection
                            
                            // Data Tools (Processing & Cleanup)
                            dataToolsSection
                            
                            //  Correlations (Phase 2)
                            correlationsSection
                            
                            // Module Calibration Table
                            moduleCalibrationSection(stats: stats)
                            
                            // Regime Insights
                            regimeInsightsSection(stats: stats)
                            
                            // ⏰ Temporal Insights (Phase 3)
                            AlkindusTimeCard()
                            
                            //  Market Comparison (Phase 3)  
                            marketComparisonSection
                            
                            // Pending Observations
                            pendingSection(stats: stats)
                            
                            Spacer(minLength: 50)
                        }
                        .padding()
                    }
                } else {
                    emptyState
                }
                
                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(200)
                }
            }
            .navigationTitle("Alkindus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(cyan)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(cyan)
                    }
                }
            }
        }
        .task {
            await loadStats()
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
                        deepLinkManager.navigate(to: .markets)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portfoy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "ALKINDUS",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Yenile", subtitle: "Istatistikleri guncelle", icon: "arrow.clockwise") {
                        refresh()
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sistem Rehberi", subtitle: "Argus isleyisi", icon: "doc.text") {
                        openSheet(.systemGuide)
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus Rehberi", subtitle: "Motor aciklamasi", icon: "book") {
                        openSheet(.alkindusGuide)
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
    
    // MARK: - Header Card
    private func headerCard(stats: AlkindusStats) -> some View {
        VStack(spacing: 16) {
            HStack {
                AlkindusAvatarView(size: 24, isThinking: isProcessing, hasIdea: false)
                    .font(.system(size: 40))
                    .foregroundColor(gold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALKINDUS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                    Text("Meta-Zeka Kalibrasyon")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Shadow Mode")
                        .font(.caption)
                        .foregroundColor(cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cyan.opacity(0.2))
                        .cornerRadius(6)
                    
                    Text("\(stats.pendingCount) bekleyen")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Top/Weak Module
            HStack(spacing: 20) {
                if let top = stats.topModule {
                    miniStat(title: "En İyi Modül", value: top.name.capitalized, rate: top.hitRate, color: green)
                }
                
                if let weak = stats.weakestModule {
                    miniStat(title: "En Zayıf", value: weak.name.capitalized, rate: weak.hitRate, color: red)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(16)
    }
    
    private func miniStat(title: String, value: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            HStack {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(String(format: "%.0f%%", rate * 100))
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Module Calibration Section
    private func moduleCalibrationSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODÜL KALİBRASYONU")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            ForEach(stats.calibration.modules.sorted(by: { $0.key < $1.key }), id: \.key) { module, cal in
                moduleCard(name: module, calibration: cal)
            }
            
            if stats.calibration.modules.isEmpty {
                Text("Henüz veri yok. Kararlar verildikçe burası dolacak.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
    
    private func moduleCard(name: String, calibration: ModuleCalibration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            ForEach(calibration.brackets.sorted(by: { $0.key > $1.key }), id: \.key) { bracket, bstats in
                HStack {
                    Text(bracket)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    ProgressView(value: bstats.hitRate)
                        .tint(colorForHitRate(bstats.hitRate))
                    
                    Text(String(format: "%.0f%%", bstats.hitRate * 100))
                        .font(.caption)
                        .foregroundColor(colorForHitRate(bstats.hitRate))
                        .frame(width: 40)
                    
                    Text("(\(bstats.attempts))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    private func colorForHitRate(_ rate: Double) -> Color {
        if rate >= 0.6 { return green }
        if rate >= 0.45 { return .orange }
        return red
    }
    
    // MARK: - Regime Insights Section
    private func regimeInsightsSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REJİM BAZLI PERFORMANS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            ForEach(stats.calibration.regimes.sorted(by: { $0.key < $1.key }), id: \.key) { regime, insight in
                VStack(alignment: .leading, spacing: 8) {
                    Text(regime.capitalized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(insight.moduleAttempts.sorted(by: { $0.key < $1.key }), id: \.key) { module, attempts in
                        let rate = insight.hitRate(for: module)
                        HStack {
                            Text(module.capitalized)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(.caption)
                                .foregroundColor(colorForHitRate(rate))
                        }
                    }
                }
                .padding()
                .background(cardBg)
                .cornerRadius(12)
            }
            
            if stats.calibration.regimes.isEmpty {
                Text("Rejim verisi henüz yok.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
    
    // MARK: - Pending Section
    private func pendingSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BEKLEYEN GÖZLEMLER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(cyan)
                Text("\(stats.pendingCount) karar olgunlaşma bekliyor")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Insights Section (Phase 2)
    @State private var insights: [AlkindusInsightGenerator.Insight] = []
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(" BUGÜN ÖĞRENDİKLERİM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
                Button(action: refreshInsights) {
                    Image(systemName: "sparkles")
                        .foregroundColor(gold)
                        .font(.caption)
                }
            }
            
            if insights.isEmpty {
                Text("Henüz günlük insight yok. 'Eventlerden Öğren' butonuna bas.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(insights.prefix(5)) { insight in
                        insightCard(insight: insight)
                    }
                }
            }
        }
    }
    
    private func insightCard(insight: AlkindusInsightGenerator.Insight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForCategory(insight.category))
                .foregroundColor(colorForImportance(insight.importance))
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(insight.detail)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(cardBg)
        .cornerRadius(10)
    }
    
    private func iconForCategory(_ category: AlkindusInsightGenerator.InsightCategory) -> String {
        switch category {
        case .correlation: return "link"
        case .anomaly: return "exclamationmark.triangle"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .performance: return "chart.bar"
        case .regime: return "waveform"
        case .warning: return "exclamationmark.circle"
        case .discovery: return "sparkle"
        }
    }
    
    private func colorForImportance(_ importance: AlkindusInsightGenerator.InsightImportance) -> Color {
        switch importance {
        case .critical: return red
        case .high: return .orange
        case .medium: return cyan
        case .low: return .gray
        }
    }
    
    // MARK: - Correlations Section (Phase 2)
    @State private var topCorrelations: [(key: String, hitRate: Double, attempts: Int)] = []
    
    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(" EN BAŞARILI KOMBİNASYONLAR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            if topCorrelations.isEmpty {
                Text("Henüz korelasyon verisi yok.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(topCorrelations, id: \.key) { corr in
                        HStack {
                            Text(formatCorrelationKey(corr.key))
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(corr.hitRate * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(colorForHitRate(corr.hitRate))
                            Text("(\(corr.attempts))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(cardBg)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func formatCorrelationKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "80+", with: "↑")
            .replacingOccurrences(of: "60+", with: "→")
            .capitalized
    }
    
    // MARK: - Market Comparison Section (Phase 3)
    @State private var marketComparison: (bist: Double, global: Double)?
    
    private var marketComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(" MARKET KARŞILAŞTIRMASI")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            if let comparison = marketComparison {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("BIST")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(comparison.bist * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorForHitRate(comparison.bist))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 4) {
                        Text("GLOBAL")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(comparison.global * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorForHitRate(comparison.global))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(cardBg)
                .cornerRadius(12)
            } else {
                Text("Henüz BIST/Global karşılaştırma verisi yok")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .task {
            marketComparison = await AlkindusSymbolLearner.shared.getMarketComparison()
        }
    }
    
    // MARK: - Data Tools Section
    private var dataToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VERİ ARAÇLARI")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            VStack(spacing: 12) {
                // Database Size
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.gray)
                    Text("Veritabanı Boyutu:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.1f MB", dbSizeMB))
                        .font(.caption)
                        .foregroundColor(dbSizeMB > 100 ? red : .white)
                }
                
                // Processing Progress
                if isProcessing {
                    VStack(spacing: 8) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(cyan)
                            Text("İşleniyor: \(processedCount)/\(totalToProcess)")
                                .font(.caption)
                                .foregroundColor(cyan)
                        }
                        ProgressView(value: {
                            let v = totalToProcess > 0 ? Double(processedCount) / Double(totalToProcess) : 0
                            return min(max(v, 0), 1)
                        }())
                            .tint(cyan)
                    }
                }
                
                // Processing Result
                if let result = processingResult {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(green)
                        Text("\(result.eventsProcessed) event işlendi, \(result.patternsExtracted) pattern çıkarıldı")
                            .font(.caption)
                            .foregroundColor(green)
                    }
                    Text("Öğrenilen: \(result.modulesLearned.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Buttons
                HStack(spacing: 12) {
                    Button(action: processEvents) {
                        HStack {
                            AlkindusAvatarView(size: 16, isThinking: false, hasIdea: false)
                            Text("Eventlerden Öğren")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(cyan.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                    
                    Button(action: cleanupBlobs) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Blob Temizle")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(red.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                }
            }
            .padding()
            .background(cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            AlkindusAvatarView(size: 40, isThinking: true, hasIdea: false)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Alkindus henüz veri toplamadı")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Kararlar verildikçe burada istatistikler görünecek.")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Actions
    private func loadStats() async {
        isLoading = true
        stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
        updateDbSize()
        loadPhase2Data()
        isLoading = false
    }
    
    private func refresh() {
        Task {
            await loadStats()
        }
    }
    
    private func updateDbSize() {
        dbSizeMB = AlkindusEventProcessor.shared.getDatabaseSizeMB()
    }
    
    private func processEvents() {
        isProcessing = true
        processedCount = 0
        processingResult = nil
        
        Task {
            let result = await AlkindusEventProcessor.shared.processHistoricalEvents { processed, total in
                DispatchQueue.main.async {
                    self.processedCount = processed
                    self.totalToProcess = total
                }
            }
            
            DispatchQueue.main.async {
                self.processingResult = result
                self.isProcessing = false
                self.refresh()
            }
        }
    }
    
    private func cleanupBlobs() {
        Task {
            AlkindusEventProcessor.shared.deleteProcessedBlobs()
            DispatchQueue.main.async {
                self.updateDbSize()
            }
        }
    }
    
    private func refreshInsights() {
        Task {
            let newInsights = await AlkindusInsightGenerator.shared.generateDailyInsights()
            DispatchQueue.main.async {
                self.insights = newInsights
            }
        }
    }
    
    private func refreshCorrelations() {
        Task {
            let correlations = await AlkindusCorrelationTracker.shared.getTopCorrelations(count: 5)
            DispatchQueue.main.async {
                self.topCorrelations = correlations
            }
        }
    }
    
    private func loadPhase2Data() {
        refreshInsights()
        refreshCorrelations()
    }
}

#Preview {
    AlkindusDashboardView()
}
