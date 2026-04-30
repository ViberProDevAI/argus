import SwiftUI

// MARK: - ArgusCockpitView (in-place refactor — ArgusDesignKit v1)
//
// Trader Terminal: Global / Sirkiye (BIST) / Fonlar sekmesi + terminal listesi.
// Veri: viewModel.terminalItems (TerminalItem pre-calculated), ChironDataLakeService (loadLearningEvents).
// Korunur:
//   • ScoutStoriesBar, ChironCockpitWidget, ChironTerminalFeed, FundListView, ModuleHoloSheet
//   • TerminalControlBar / TerminalStockRow / TerminalScoreBadge alt bileşen imzaları
//   • MarketTab enum (dışarıdan referans edilebilir)
//   • Drawer tüm item'ları ile aynı
// Demo veri yok — boş liste ArgusEmptyState ile ifade edilir.

// Global Scope Enum (dışarıdan referans ediliyor)
enum MarketTab: String, CaseIterable {
    case global  = "Global"
    case bist    = "Sirkiye"
    case fonlar  = "Fonlar"
}

struct ArgusCockpitView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    // Terminal State
    @State private var sortOption: TerminalSortOption = .councilScore
    @State private var hideLowQualityData: Bool = true
    @State private var searchText: String = ""
    @State private var selectedMarket: MarketTab = .global
    @State private var systemLogs: [ChironLearningEvent] = []
    @State private var showDrawer = false

    // Overlay State
    @State private var selectedSymbolForModule: String? = nil
    @State private var selectedModuleType: ArgusSanctumView.ModuleType? = nil

    // Sort Options
    enum TerminalSortOption: String, CaseIterable, Identifiable {
        case councilScore = "Konsey / Divan"
        case orion        = "Orion / Tahta"
        case atlas        = "Atlas / Kasa"
        case prometheus   = "Prometheus"
        case potential    = "Potansiyel"

        var id: String { rawValue }
    }

    // Terminal liste — ViewModel'den
    var terminalData: [TerminalItem] {
        var items = viewModel.terminalItems

        // 1. Market Filter
        switch selectedMarket {
        case .bist:   items = items.filter { $0.market == .bist }
        case .global: items = items.filter { $0.market == .global }
        case .fonlar: return []
        }

        // 2. Search
        if !searchText.isEmpty {
            items = items.filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }
        }

        // 3. Quality Filter
        if hideLowQualityData {
            items = items.filter { $0.dataQuality >= 50 }
        }

        // 4. Sort
        items.sort { a, b in
            switch sortOption {
            case .councilScore: return (a.councilScore ?? 0) > (b.councilScore ?? 0)
            case .orion:        return (a.orionScore ?? 0)   > (b.orionScore ?? 0)
            case .atlas:        return (a.atlasScore ?? 0)   > (b.atlasScore ?? 0)
            case .prometheus:
                return (a.forecast?.changePercent ?? -999) > (b.forecast?.changePercent ?? -999)
            case .potential:    return a.symbol < b.symbol
            }
        }
        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    marketTabBar

                    if selectedMarket == .fonlar {
                        FundListView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                TerminalControlBar(
                                    sortOption: $sortOption,
                                    hideLowQualityData: $hideLowQualityData,
                                    count: terminalData.count,
                                    selectedMarket: selectedMarket
                                )

                                ScoutStoriesBar()
                                    .padding(.top, 8)
                                    .padding(.bottom, 8)

                                ChironCockpitWidget()
                                    .padding(.vertical, 8)
                                    .background(InstitutionalTheme.Colors.surface1)

                                ChironTerminalFeed(events: systemLogs)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)

                                // Terminal Listesi
                                if terminalData.isEmpty {
                                    ArgusEmptyState(
                                        icon: "antenna.radiowaves.left.and.right.slash",
                                        title: "Veri bulunamadı",
                                        message: "Kriterlere uygun hisse bulunamadı. Kalite filtresini veya arama terimini değiştirmeyi dene."
                                    )
                                    .padding(.top, 16)
                                } else {
                                    ForEach(terminalData) { item in
                                        NavigationLink(destination: ArgusSanctumView(symbol: item.symbol, viewModel: viewModel)) {
                                            TerminalStockRow(
                                                item: item,
                                                onOrionTap: { openModule(.orion, for: item.symbol) },
                                                onAtlasTap: { openModule(.atlas, for: item.symbol) }
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        Rectangle()
                                            .fill(InstitutionalTheme.Colors.borderSubtle)
                                            .frame(height: 0.5)
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .padding(.bottom, 80)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showDrawer = true }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Menü")
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: toolbarIcon)
                                .foregroundColor(toolbarColor)
                            Text(toolbarTitle)
                                .font(.system(.headline, design: .monospaced))
                                .fontWeight(.bold)
                                .tracking(1)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                viewModel.refreshTerminal()
                                await loadLogs()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Terminali yenile")
                    }
                }
            }

            if showDrawer {
                ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                    drawerSections(openSheet: openSheet)
                }
                .zIndex(200)
            }

            // Holo Overlay
            if let module = selectedModuleType, let symbol = selectedSymbolForModule {
                ModuleHoloSheet(
                    module: module,
                    viewModel: viewModel,
                    symbol: symbol,
                    onClose: {
                        withAnimation {
                            selectedModuleType = nil
                            selectedSymbolForModule = nil
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            viewModel.refreshTerminal()
            Task { await loadLogs() }
        }
        .task {
            await viewModel.bootstrapTerminalData()
            await loadLogs()
        }
        .onChange(of: viewModel.watchlist) { _ in
            viewModel.refreshTerminal()
        }
    }

    // MARK: - Logs & Module Overlay

    private func loadLogs() async {
        systemLogs = await ChironDataLakeService.shared.loadLearningEvents()
    }

    private func openModule(_ type: ArgusSanctumView.ModuleType, for symbol: String) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedSymbolForModule = symbol
            selectedModuleType = type
        }
    }

    // MARK: - Drawer

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home); showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit); showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAlkindusDashboard"), object: nil)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portfoy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio); showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings); showDrawer = false
                    }
                ]
            )
        )

        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Terminal",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Pazar: Global", subtitle: "Global liste", icon: "globe.asia.australia") {
                        selectedMarket = .global; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: BIST", subtitle: "Sirkiye liste", icon: "chart.bar") {
                        selectedMarket = .bist; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: Fonlar", subtitle: "Fon listesi", icon: "rectangle.stack") {
                        selectedMarket = .fonlar; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Konsey", subtitle: "Konsey skoru", icon: "crown") {
                        sortOption = .councilScore; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Orion", subtitle: "Teknik skor", icon: "waveform.path.ecg") {
                        sortOption = .orion; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Atlas", subtitle: "Temel skor", icon: "chart.bar") {
                        sortOption = .atlas; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Potansiyel", subtitle: "Sembol bazli", icon: "sparkles") {
                        sortOption = .potential; showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(
                        title: "Kalite Filtresi",
                        subtitle: hideLowQualityData ? "Acik" : "Kapali",
                        icon: "line.3.horizontal.decrease.circle"
                    ) {
                        hideLowQualityData.toggle(); showDrawer = false
                    }
                ]
            )
        )

        sections.append(commonToolsSection(openSheet: openSheet))
        return sections
    }

    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "Araçlar",
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

    // MARK: - Market Tab Bar

    @ViewBuilder
    private func tabButton(title: String, tab: MarketTab) -> some View {
        let isSelected = selectedMarket == tab
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedMarket = tab } }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(isSelected ? .bold : .medium)
                    .tracking(1)
                    .foregroundColor(
                        isSelected
                            ? InstitutionalTheme.Colors.textPrimary
                            : InstitutionalTheme.Colors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Rectangle()
                    .fill(isSelected ? tabColor(for: tab) : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) sekmesi")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var marketTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Global",  tab: .global)
            tabButton(title: "Sirkiye", tab: .bist)
            tabButton(title: "Fonlar",  tab: .fonlar)
        }
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    // Tab renk eşleşmesi
    private func tabColor(for tab: MarketTab) -> Color {
        switch tab {
        case .global: return InstitutionalTheme.Colors.primary
        case .bist:   return InstitutionalTheme.Colors.negative   // BIST kimliği — kırmızı
        case .fonlar: return InstitutionalTheme.Colors.positive
        }
    }

    // Toolbar helpers
    private var toolbarIcon: String {
        switch selectedMarket {
        case .global: return "globe"
        case .bist:   return "building.columns.fill"
        case .fonlar: return "chart.pie.fill"
        }
    }
    private var toolbarColor: Color { tabColor(for: selectedMarket) }
    private var toolbarTitle: String {
        switch selectedMarket {
        case .global: return "GLOBAL TERMINAL"
        case .bist:   return "SİRKİYE KOKPİTİ"
        case .fonlar: return "TEFAS FONLARI"
        }
    }
}

// MARK: - TerminalControlBar

struct TerminalControlBar: View {
    @Binding var sortOption: ArgusCockpitView.TerminalSortOption
    @Binding var hideLowQualityData: Bool
    let count: Int
    let selectedMarket: MarketTab

    private var accent: Color {
        selectedMarket == .bist
            ? InstitutionalTheme.Colors.negative
            : InstitutionalTheme.Colors.primary
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(count) \(selectedMarket == .bist ? "HİSSE" : "TICKER")")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .monospacedDigit()

                Spacer()

                Menu {
                    Picker("Sıralama", selection: $sortOption) {
                        ForEach(ArgusCockpitView.TerminalSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(.caption, design: .default))
                        Text(sortLabel(for: sortOption))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(0.6)
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 36)
                    .background(
                        Capsule().fill(accent.opacity(0.14))
                    )
                    .overlay(
                        Capsule().stroke(accent.opacity(0.35), lineWidth: 0.5)
                    )
                }
                .accessibilityLabel("Sıralama menüsü")
            }

            HStack {
                Toggle(isOn: $hideLowQualityData) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(
                                hideLowQualityData
                                    ? InstitutionalTheme.Colors.neutral
                                    : InstitutionalTheme.Colors.textTertiary
                            )
                        Text("Düşük Kaliteyi Gizle")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: accent))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    func sortLabel(for option: ArgusCockpitView.TerminalSortOption) -> String {
        guard selectedMarket == .bist else { return option.rawValue }
        switch option {
        case .councilScore: return "Divan Puani"
        case .orion:        return "Tahta (Teknik)"
        case .atlas:        return "Kasa (Temel)"
        case .prometheus:   return "Prometheus"
        case .potential:    return "Potansiyel"
        }
    }
}

// MARK: - TerminalStockRow (dumb component)

struct TerminalStockRow: View {
    let item: TerminalItem
    var onOrionTap: () -> Void
    var onAtlasTap: () -> Void

    var body: some View {
        // V5 mockup "02 · Kokpit" kompakt satır (HTML 538-552):
        // [sembol + fiyat alt satır] [3 mini skor chip] [sağda konsey chip + %]
        HStack(spacing: 8) {
            symbolBlock
            scoreChips
            Spacer(minLength: 4)
            councilBlock
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Symbol + price

    private var symbolBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.symbol.replacingOccurrences(of: ".IS", with: ""))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(1)

            Text(priceText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(minWidth: 58, alignment: .leading)
    }

    private var priceText: String {
        guard item.price > 0 else { return "—" }
        let currency = item.currency == .TRY ? "₺" : "$"
        return String(format: "\(currency)%.2f", item.price)
    }

    // MARK: - 3 mini skor chip (O / A / ★)

    private var scoreChips: some View {
        HStack(spacing: 4) {
            Button(action: onOrionTap) {
                miniScoreChip(
                    prefix: item.market == .bist ? "T" : "O",
                    score: item.orionScore,
                    tone: InstitutionalTheme.Colors.Motors.orion
                )
            }
            .buttonStyle(.plain)

            Button(action: onAtlasTap) {
                miniScoreChip(
                    prefix: item.market == .bist ? "K" : "A",
                    score: item.atlasScore,
                    tone: InstitutionalTheme.Colors.textSecondary
                )
            }
            .buttonStyle(.plain)

            miniScoreChip(
                prefix: "★",
                score: (item.councilScore ?? 0) * 100,
                tone: InstitutionalTheme.Colors.aurora
            )
        }
    }

    private func miniScoreChip(prefix: String, score: Double?, tone: Color) -> some View {
        let text: String
        if let s = score, s > 0 {
            text = "\(prefix)\(Int(s))"
        } else {
            text = "\(prefix)—"
        }
        return Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(tone)
            .frame(width: 36, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tone.opacity(0.14))
            )
    }

    // MARK: - Council chip + confidence

    private var councilBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(councilLabel(item.action))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(actionColor(item.action))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 999)
                        .fill(actionColor(item.action).opacity(0.2))
                )

            Text("%\(Int((item.councilScore ?? 0) * 100))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }

    // MARK: Helpers

    func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate:    return InstitutionalTheme.Colors.primary
        case .neutral:       return InstitutionalTheme.Colors.textSecondary
        case .trim:          return InstitutionalTheme.Colors.neutral
        case .liquidate:     return InstitutionalTheme.Colors.negative
        }
    }

    func councilLabel(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "KONSEY HÜCUM"
        case .accumulate:    return "KONSEY TOPLA"
        case .neutral:       return "KONSEY GÖZLE"
        case .trim:          return "KONSEY AZALT"
        case .liquidate:     return "KONSEY ÇIK"
        }
    }

    // Legacy helpers (başka yerde kullanılıyor olabilir — korunuyor)
    func educationLevel(_ item: TerminalItem) -> Int {
        let confidence = max(0, min(item.councilScore ?? 0, 1))
        var level: Int
        switch confidence {
        case ..<0.20: level = 1
        case ..<0.40: level = 2
        case ..<0.60: level = 3
        case ..<0.80: level = 4
        default:      level = 5
        }
        if item.action == .neutral {
            level = min(level, 3)
        }
        return level
    }

    func educationTitle(_ level: Int) -> String {
        switch level {
        case 1: return "VERI ZAYIF"
        case 2: return "ERKEN SINYAL"
        case 3: return "KARISIK"
        case 4: return "GUCLU"
        default: return "TEYITLI"
        }
    }

    func educationColor(_ level: Int) -> Color {
        switch level {
        case 1: return InstitutionalTheme.Colors.negative
        case 2: return InstitutionalTheme.Colors.neutral
        case 3: return InstitutionalTheme.Colors.textSecondary
        case 4: return InstitutionalTheme.Colors.primary
        default: return InstitutionalTheme.Colors.positive
        }
    }
}

// MARK: - TerminalScoreBadge

struct TerminalScoreBadge: View {
    let label: String
    let score: Double
    let color: Color
    var motor: MotorEngine? = nil

    var body: some View {
        // V5: label/motor üstte, skor alt orb'da. Motor verilirse logo,
        // yoksa label text (legacy çağrılar için geri uyumluluk).
        VStack(spacing: 2) {
            if let motor {
                MotorLogo(motor, size: 12)
            } else {
                Text(label)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            ZStack {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 28, height: 28)

                Text(score > 0 ? "\(Int(score))" : "—")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(
                        score > 0
                            ? InstitutionalTheme.Colors.textPrimary
                            : InstitutionalTheme.Colors.textTertiary
                    )
            }
        }
        .accessibilityLabel(Text("\(label) skoru \(score > 0 ? "\(Int(score))" : "yok")"))
    }
}
