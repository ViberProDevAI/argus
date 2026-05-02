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

        // 4. Sort — 2026-04-30 H-51:
        // Eski: tüm skorlar 0 ise alfabetik kalıyor, sıralama anlamsız
        // görünüyordu. Yeni: skoru olmayan (0/nil) hisseleri liste sonuna
        // at, gerçek sıralama tepede çalışsın.
        items.sort { a, b in
            switch sortOption {
            case .councilScore:
                let av = a.councilScore ?? 0, bv = b.councilScore ?? 0
                if av == 0 && bv != 0 { return false }
                if bv == 0 && av != 0 { return true }
                return av > bv
            case .orion:
                let av = a.orionScore ?? 0, bv = b.orionScore ?? 0
                if av == 0 && bv != 0 { return false }
                if bv == 0 && av != 0 { return true }
                return av > bv
            case .atlas:
                let av = a.atlasScore ?? 0, bv = b.atlasScore ?? 0
                if av == 0 && bv != 0 { return false }
                if bv == 0 && av != 0 { return true }
                return av > bv
            case .prometheus:
                let av = a.forecast?.changePercent ?? -999
                let bv = b.forecast?.changePercent ?? -999
                if av == -999 && bv != -999 { return false }
                if bv == -999 && av != -999 { return true }
                return av > bv
            case .potential:
                return a.symbol < b.symbol
            }
        }
        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // 2026-04-30 H-54 — sade nav. SwiftUI toolbar (mono caps
                    // başlık + tinted ikon + 44×44 default item'lar) yerine
                    // Portfolio / MarketView / Trade Brain ile aynı dil:
                    // sol drawer + başlık + sağ refresh, hepsi 32×32 sade.
                    customTopBar

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    marketTabBar

                    if selectedMarket == .fonlar {
                        FundListView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // 2026-04-30 H-50 — Cockpit sade. Eski 5-katman
                                // (control bar + Scout stories + Chiron widget +
                                // Chiron feed + liste) → 3-katman (control bar +
                                // liste + boş hal). Scout stories Discover'a
                                // taşındı; Chiron widget/feed silindi (Alkindus
                                // dashboard kalibrasyon paneli aynı bilgiyi
                                // sağlıyor).
                                TerminalControlBar(
                                    sortOption: $sortOption,
                                    hideLowQualityData: $hideLowQualityData,
                                    count: terminalData.count,
                                    selectedMarket: selectedMarket
                                )

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
                .navigationBarHidden(true)
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
        }
        .task {
            await viewModel.bootstrapTerminalData()
        }
        .onChange(of: viewModel.watchlist) { _ in
            viewModel.refreshTerminal()
        }
    }

    // MARK: - Module Overlay

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

    // MARK: - Custom top bar (2026-04-30 H-54)
    //
    // SwiftUI toolbar'ın varsayılan davranışı (44×44 frame'siz item, mono
    // caps başlık, tinted ikon) Portfolio / MarketView / Trade Brain ile
    // tutarsızdı. Yerine sade nav: 32×32 sade ikonlar, sentence case 17pt
    // medium başlık, tek satır.
    private var customTopBar: some View {
        HStack(spacing: 8) {
            Button(action: { showDrawer = true }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menü")

            Text(toolbarTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: {
                switch selectedMarket {
                case .fonlar:
                    Task { await FundDataManager.shared.refresh() }
                default:
                    viewModel.refreshTerminal()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Yenile")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.background)
    }

    /// 2026-04-30 H-50 — sade. Mono caps tracking 1 + tab başına ayrı renk
    /// (mavi/kırmızı/yeşil) → MarketView ile aynı dil: 13pt sentence
    /// case + nötr beyaz altı çizgisi.
    @ViewBuilder
    private func tabButton(title: String, tab: MarketTab) -> some View {
        let isSelected = selectedMarket == tab
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedMarket = tab } }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected
                                     ? InstitutionalTheme.Colors.textPrimary
                                     : InstitutionalTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                Rectangle()
                    .fill(isSelected
                          ? InstitutionalTheme.Colors.textPrimary
                          : Color.clear)
                    .frame(height: 1.5)
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

    /// 2026-04-30 H-50 — caps "GLOBAL TERMINAL / SİRKİYE KOKPİTİ /
    /// TEFAS FONLARI" → sentence case "Tarama / Sirkiye / Fonlar".
    private var toolbarTitle: String {
        switch selectedMarket {
        case .global: return "Tarama"
        case .bist:   return "Sirkiye"
        case .fonlar: return "Fonlar"
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

    /// 2026-04-30 H-50 — sade. İki ayrı satır (count+tinted sort menü
    /// pill üstte, kalite toggle altta) → tek satır kompakt: sol "X hisse"
    /// muted, orta "Sırala" menü (sade text, capsule yok), sağ kalite
    /// toggle (label tek kelime). Padding küçüldü, hairline alt çizgisi
    /// kaldırıldı (Cockpit'in kendi tab bar'ı zaten ayraç koyuyor).
    var body: some View {
        HStack(spacing: 10) {
            Text("\(count) hisse")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .monospacedDigit()

            Spacer(minLength: 6)

            Menu {
                Picker("Sıralama", selection: $sortOption) {
                    ForEach(ArgusCockpitView.TerminalSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortLabel(for: sortOption))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Sıralama menüsü")

            Toggle(isOn: $hideLowQualityData) {
                Text("Kalite")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: InstitutionalTheme.Colors.aurora))
            .labelsHidden()
            .scaleEffect(0.85)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.background)
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

    /// 2026-04-30 H-51 — durumlu render. Console skoru 0 ise "Gözle 0%"
    /// gibi anlamsız bilgi yerine "Henüz analiz yok" muted; aksiyon ve
    /// score kolonları gizlenir. Sadece sembol/fiyat + günlük değişim
    /// kalır.
    var body: some View {
        HStack(spacing: 12) {
            symbolBlock
            if hasAnalysis {
                actionBlock
            } else {
                Text("Henüz analiz yok")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 4)
            dailyChangeBlock
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var hasAnalysis: Bool {
        // Council, orion ya da atlas skorundan en az biri varsa analiz
        // var sayılır. Üçü de 0/nil ise hisse henüz işlenmedi.
        let council = item.councilScore ?? 0
        let orion = item.orionScore ?? 0
        let atlas = item.atlasScore ?? 0
        return council > 0 || orion > 0 || atlas > 0
    }

    // MARK: - Symbol + price

    private var symbolBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.symbol.replacingOccurrences(of: ".IS", with: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(1)

            Text(priceText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 70, alignment: .leading)
    }

    private var priceText: String {
        guard item.price > 0 else { return "—" }
        let currency = item.currency == .TRY ? "₺" : "$"
        return String(format: "\(currency)%.2f", item.price)
    }

    // MARK: - Aksiyon + güven + iki score

    /// 2026-04-30 H-51 — sadece dolu skorları göster. Council 0 ise
    /// aksiyon satırı yerine ne varsa onu (T/B skoru) tek satır göster.
    /// "T —" / "B —" boş slotları gösterilmez.
    private var actionBlock: some View {
        let council = item.councilScore ?? 0
        let orion = item.orionScore ?? 0
        let atlas = item.atlasScore ?? 0

        return VStack(alignment: .leading, spacing: 2) {
            // Üst satır: aksiyon + güven (council varsa)
            if council > 0 {
                HStack(spacing: 6) {
                    Text(councilLabel(item.action))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(actionColor(item.action))
                    Text("\(Int(council * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .monospacedDigit()
                }
            }

            // Alt satır: sadece dolu skorlar
            HStack(spacing: 10) {
                if orion > 0 {
                    Button(action: onOrionTap) {
                        inlineScore(prefix: "T",
                                    score: orion,
                                    tone: InstitutionalTheme.Colors.Motors.orion)
                    }
                    .buttonStyle(.plain)
                }
                if atlas > 0 {
                    Button(action: onAtlasTap) {
                        inlineScore(prefix: "B",
                                    score: atlas,
                                    tone: InstitutionalTheme.Colors.Motors.atlas)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineScore(prefix: String, score: Double, tone: Color) -> some View {
        HStack(spacing: 3) {
            Text(prefix)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tone)
            Text("\(Int(score))")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .monospacedDigit()
        }
    }

    // MARK: - Günlük değişim

    private var dailyChangeBlock: some View {
        let change = item.dayChangePercent
        let color: Color = (change ?? 0) >= 0
            ? InstitutionalTheme.Colors.positive
            : InstitutionalTheme.Colors.negative
        return Group {
            if let c = change {
                Text(String(format: "%+.1f%%", c))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: Helpers

    func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate:    return InstitutionalTheme.Colors.primary
        case .neutral:       return InstitutionalTheme.Colors.textSecondary
        case .trim:          return InstitutionalTheme.Colors.warning
        case .liquidate:     return InstitutionalTheme.Colors.negative
        }
    }

    /// 2026-04-30 H-50 — "KONSEY HÜCUM" caps mono → sentence kısa kelime.
    /// "Konsey" prefix'i her satırda gereksiz tekrar olduğundan kaldırıldı.
    func councilLabel(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "Hücum"
        case .accumulate:    return "Topla"
        case .neutral:       return "Gözle"
        case .trim:          return "Azalt"
        case .liquidate:     return "Çık"
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
