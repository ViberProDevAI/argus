import SwiftUI

struct AlkindusDashboardView: View {
    @State private var stats: AlkindusStats?
    @State private var isLoading = true
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalToProcess = 0
    @State private var processingResult: ProcessingResult?
    @State private var dbSizeMB: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(InstitutionalTheme.Colors.primary)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerCard(stats: stats)
                            insightsSection
                            dataToolsSection
                            correlationsSection
                            moduleCalibrationSection(stats: stats)
                            regimeInsightsSection(stats: stats)
                            AlkindusTimeCard()
                            marketComparisonSection
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
                            .foregroundColor(InstitutionalTheme.Colors.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(InstitutionalTheme.Colors.primary)
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
                        deepLinkManager.navigate(to: .kokpit)
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
    
    private func headerCard(stats: AlkindusStats) -> some View {
        VStack(spacing: 16) {
            HStack {
                AlkindusAvatarView(size: 24, isThinking: isProcessing, hasIdea: false)
                    .font(.system(size: 40))
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALKINDUS")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .tracking(2)
                    Text("Meta-Zeka Kalibrasyon")
                        .font(InstitutionalTheme.Typography.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Shadow Mode")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(InstitutionalTheme.Colors.primary.opacity(0.2))
                        .cornerRadius(6)
                    
                    Text("\(stats.pendingCount) bekleyen")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            HStack(spacing: 20) {
                if let top = stats.topModule {
                    miniStat(title: "En İyi Modül", value: top.name.capitalized, rate: top.hitRate, color: InstitutionalTheme.Colors.positive)
                }
                
                if let weak = stats.weakestModule {
                    miniStat(title: "En Zayıf", value: weak.name.capitalized, rate: weak.hitRate, color: InstitutionalTheme.Colors.negative)
                }
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
    }
    
    private func miniStat(title: String, value: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            HStack {
                Text(value)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(String(format: "%.0f%%", rate * 100))
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func moduleCalibrationSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODÜL KALİBRASYONU")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            ForEach(stats.calibration.modules.sorted(by: { $0.key < $1.key }), id: \.key) { module, cal in
                moduleCard(name: module, calibration: cal)
            }
            
            if stats.calibration.modules.isEmpty {
                Text("Henüz veri yok. Kararlar verildikçe burası dolacak.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding()
            }
        }
    }
    
    private func moduleCard(name: String, calibration: ModuleCalibration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name.uppercased())
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            
            ForEach(calibration.brackets.sorted(by: { $0.key > $1.key }), id: \.key) { bracket, bstats in
                HStack {
                    Text(bracket)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    
                    ProgressView(value: bstats.hitRate)
                        .tint(colorForHitRate(bstats.hitRate))
                    
                    Text(String(format: "%.0f%%", bstats.hitRate * 100))
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(colorForHitRate(bstats.hitRate))
                        .frame(width: 40)
                    
                    Text("(\(bstats.attempts))")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
        }
        .padding()
        .institutionalCard(scale: .standard, elevated: false)
    }
    
    private func colorForHitRate(_ rate: Double) -> Color {
        if rate >= 0.6 { return InstitutionalTheme.Colors.positive }
        if rate >= 0.45 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
    
    private func regimeInsightsSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REJİM BAZLI PERFORMANS")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            ForEach(stats.calibration.regimes.sorted(by: { $0.key < $1.key }), id: \.key) { regime, insight in
                VStack(alignment: .leading, spacing: 8) {
                    Text(regime.capitalized)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    
                    ForEach(insight.moduleAttempts.sorted(by: { $0.key < $1.key }), id: \.key) { module, attempts in
                        let rate = insight.hitRate(for: module)
                        HStack {
                            Text(module.capitalized)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(colorForHitRate(rate))
                        }
                    }
                }
                .padding()
                .institutionalCard(scale: .standard, elevated: false)
            }
            
            if stats.calibration.regimes.isEmpty {
                Text("Rejim verisi henüz yok.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding()
            }
        }
    }
    
    private func pendingSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BEKLEYEN GÖZLEMLER")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Text("\(stats.pendingCount) karar olgunlaşma bekliyor")
                    .font(InstitutionalTheme.Typography.body)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .institutionalCard(scale: .standard, elevated: false)
        }
    }
    
    @State private var insights: [AlkindusInsightGenerator.Insight] = []
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(" BUGÜN ÖĞRENDİKLERİM")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1)
                Spacer()
                Button(action: refreshInsights) {
                    Image(systemName: "sparkles")
                        .foregroundColor(InstitutionalTheme.Colors.warning)
                        .font(.caption)
                }
            }
            
            if insights.isEmpty {
                Text("Henüz günlük insight yok. 'Eventlerden Öğren' butonuna bas.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
                    .font(InstitutionalTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(insight.detail)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding()
        .institutionalCard(scale: .micro, elevated: false)
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
        case .critical: return InstitutionalTheme.Colors.negative
        case .high: return InstitutionalTheme.Colors.warning
        case .medium: return InstitutionalTheme.Colors.primary
        case .low: return InstitutionalTheme.Colors.textTertiary
        }
    }
    
    @State private var topCorrelations: [(key: String, hitRate: Double, attempts: Int)] = []
    
    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(" EN BAŞARILI KOMBİNASYONLAR")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            if topCorrelations.isEmpty {
                Text("Henüz korelasyon verisi yok.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(topCorrelations, id: \.key) { corr in
                        HStack {
                            Text(formatCorrelationKey(corr.key))
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(corr.hitRate * 100))%")
                                .font(InstitutionalTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(colorForHitRate(corr.hitRate))
                            Text("(\(corr.attempts))")
                                .font(InstitutionalTheme.Typography.micro)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .institutionalCard(scale: .nano, elevated: false)
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
    
    @State private var marketComparison: (bist: Double, global: Double)?
    
    private var marketComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(" MARKET KARŞILAŞTIRMASI")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            if let comparison = marketComparison {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("BIST")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("\(Int(comparison.bist * 100))%")
                            .font(InstitutionalTheme.Typography.title)
                            .fontWeight(.bold)
                            .foregroundColor(colorForHitRate(comparison.bist))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 4) {
                        Text("GLOBAL")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("\(Int(comparison.global * 100))%")
                            .font(InstitutionalTheme.Typography.title)
                            .fontWeight(.bold)
                            .foregroundColor(colorForHitRate(comparison.global))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .institutionalCard(scale: .standard, elevated: false)
            } else {
                Text("Henüz BIST/Global karşılaştırma verisi yok")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding()
            }
        }
        .task {
            marketComparison = await AlkindusSymbolLearner.shared.getMarketComparison()
        }
    }
    
    private var dataToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VERİ ARAÇLARI")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Veritabanı Boyutu:")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f MB", dbSizeMB))
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(dbSizeMB > 100 ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textPrimary)
                }
                
                if isProcessing {
                    VStack(spacing: 8) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(InstitutionalTheme.Colors.primary)
                            Text("İşleniyor: \(processedCount)/\(totalToProcess)")
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.primary)
                        }
                        ProgressView(value: {
                            let v = totalToProcess > 0 ? Double(processedCount) / Double(totalToProcess) : 0
                            return min(max(v, 0), 1)
                        }())
                            .tint(InstitutionalTheme.Colors.primary)
                    }
                }
                
                if let result = processingResult {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                        Text("\(result.eventsProcessed) event işlendi, \(result.patternsExtracted) pattern çıkarıldı")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                    }
                    Text("Öğrenilen: \(result.modulesLearned.joined(separator: ", "))")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                
                HStack(spacing: 12) {
                    Button(action: processEvents) {
                        HStack {
                            AlkindusAvatarView(size: 16, isThinking: false, hasIdea: false)
                            Text("Eventlerden Öğren")
                        }
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(InstitutionalTheme.Colors.primary.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                    
                    Button(action: cleanupBlobs) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Blob Temizle")
                        }
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(InstitutionalTheme.Colors.negative.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                }
            }
            .padding()
            .institutionalCard(scale: .standard, elevated: false)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            AlkindusAvatarView(size: 40, isThinking: true, hasIdea: false)
                .font(.system(size: 60))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Alkindus henüz veri toplamadı")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Kararlar verildikçe burada istatistikler görünecek.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }
    
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
