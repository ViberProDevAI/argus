import SwiftUI

// MARK: - TRADER TERMINAL VIEW

// Global Scope Enum
enum MarketTab: String, CaseIterable {
    case global = "Global"
    case bist = "Sirkiye"
    case fonlar = "Fonlar"
}

// MARK: - TRADER TERMINAL VIEW

// MARK: - TRADER TERMINAL VIEW

struct ArgusCockpitView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Terminal State
    @State private var sortOption: TerminalSortOption = .councilScore
    @State private var hideLowQualityData: Bool = true
    @State private var searchText: String = ""
    @State private var selectedMarket: MarketTab = .global
    @State private var systemLogs: [ChironLearningEvent] = [] // Chiron Feed Data
    @State private var showDrawer = false
    
    // Overlay State
    @State private var selectedSymbolForModule: String? = nil
    @State private var selectedModuleType: ArgusSanctumView.ModuleType? = nil
    
    // Sort Options
    enum TerminalSortOption: String, CaseIterable, Identifiable {
        case councilScore = "Konsey / Divan"
        case orion = "Orion / Tahta"
        case atlas = "Atlas / Kasa"
        case prometheus = "Prometheus"
        case potential = "Potansiyel"
        
        var id: String { rawValue }
    }
    
    // Optimized List from ViewModel
    var terminalData: [TerminalItem] {
        var items = viewModel.terminalItems
        
        // 1. Market Filter (Type-Safe)
        switch selectedMarket {
        case .bist:
            items = items.filter { $0.market == .bist }
        case .global:
            items = items.filter { $0.market == .global }
        case .fonlar:
            return [] // Fonlar ayrı view
        }
        
        // 2. Search
        if !searchText.isEmpty {
            items = items.filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 3. Quality Filter
        if hideLowQualityData {
            items = items.filter { $0.dataQuality >= 50 }
        }
        
        // 4. Sort (Pre-calculated values)
        items.sort { item1, item2 in
            switch sortOption {
            case .councilScore:
                return (item1.councilScore ?? 0) > (item2.councilScore ?? 0)
            case .orion:
                return (item1.orionScore ?? 0) > (item2.orionScore ?? 0)
            case .atlas:
                return (item1.atlasScore ?? 0) > (item2.atlasScore ?? 0)
            case .prometheus:
                return (item1.forecast?.changePercent ?? -999) > (item2.forecast?.changePercent ?? -999)
            case .potential:
                return item1.symbol < item2.symbol
            }
        }
        
        return items
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    // MARK: - Market Tab Selector
                    marketTabBar
                    
                    // Content based on selected tab
                    if selectedMarket == .fonlar {
                        // RESTORED: Funds Module
                        FundListView()
                    } else {
                            // Unified Scroll View for Whole Page Scrolling
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    // Control Bar
                                    TerminalControlBar(
                                        sortOption: $sortOption,
                                        hideLowQualityData: $hideLowQualityData,
                                        count: terminalData.count,
                                        selectedMarket: selectedMarket
                                    )
                                    
                                    // MARK: - SCOUT STORIES (INTELLIGENCE HUB)
                                    ScoutStoriesBar()
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                    
                                    // MARK: - Chiron Widget
                                    ChironCockpitWidget()
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "080b14"))
                                    
                                    // MARK: - SYSTEM INTELLIGENCE FEED
                                    ChironTerminalFeed(events: systemLogs)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                    
                                    // Terminal List
                                    if terminalData.isEmpty {
                                        ContentUnavailableView(
                                            "Veri Bulunamadı",
                                            systemImage: "antenna.radiowaves.left.and.right.slash",
                                            description: Text("Kriterlere uygun hisse bulunamadı.")
                                        )
                                        .padding(.top, 40)
                                    } else {
                                        ForEach(terminalData) { item in
                                            NavigationLink(destination: StockDetailView(symbol: item.symbol, viewModel: viewModel)) {
                                                TerminalStockRow(
                                                    item: item,
                                                    onOrionTap: {
                                                        openModule(.orion, for: item.symbol)
                                                    },
                                                    onAtlasTap: {
                                                        openModule(.atlas, for: item.symbol)
                                                    }
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.leading, 16)
                                        }
                                    }
                                }
                                .padding(.bottom, 80) // Add padding for bottom floaters
                            }
                    }
                }
                .background(Color(hex: "080b14").ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                     ToolbarItem(placement: .navigationBarLeading) {
                         Button(action: { showDrawer = true }) {
                             Image(systemName: "line.3.horizontal")
                                 .foregroundColor(.white.opacity(0.8))
                         }
                     }
                     ToolbarItem(placement: .principal) {
                         HStack(spacing: 4) {
                             Image(systemName: toolbarIcon)
                                 .foregroundColor(toolbarColor)
                             Text(toolbarTitle)
                                 .font(.system(.headline, design: .monospaced))
                                 .bold()
                                 .foregroundColor(.white)
                         }
                     }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                viewModel.refreshTerminal()
                                await loadLogs()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                        }
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
             // View açıldığında veriyi tazele
             viewModel.refreshTerminal()
             Task { await loadLogs() }
        }
        .task {
            await viewModel.bootstrapTerminalData()
            await loadLogs()
        }
        // Watchlist değişirse terminali güncelle
        .onChange(of: viewModel.watchlist) { _ in
            viewModel.refreshTerminal()
        }
    }
    
    private func loadLogs() async {
        systemLogs = await ChironDataLakeService.shared.loadLearningEvents()
    }
    
    private func openModule(_ type: ArgusSanctumView.ModuleType, for symbol: String) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedSymbolForModule = symbol
            selectedModuleType = type
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
                        deepLinkManager.navigate(to: .home)
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
                title: "TERMINAL",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Pazar: Global", subtitle: "Global liste", icon: "globe.asia.australia") {
                        selectedMarket = .global
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: BIST", subtitle: "Sirkiye liste", icon: "chart.bar") {
                        selectedMarket = .bist
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Pazar: Fonlar", subtitle: "Fon listesi", icon: "rectangle.stack") {
                        selectedMarket = .fonlar
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Konsey", subtitle: "Konsey skoru", icon: "crown") {
                        sortOption = .councilScore
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Orion", subtitle: "Teknik skor", icon: "waveform.path.ecg") {
                        sortOption = .orion
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Atlas", subtitle: "Temel skor", icon: "chart.bar") {
                        sortOption = .atlas
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Siralama: Potansiyel", subtitle: "Sembol bazli", icon: "sparkles") {
                        sortOption = .potential
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Kalite Filtresi", subtitle: hideLowQualityData ? "Acik" : "Kapali", icon: "line.3.horizontal.decrease.circle") {
                        hideLowQualityData.toggle()
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
    
    // Tab Button Helper
    @ViewBuilder
    func tabButton(title: String, tab: MarketTab) -> some View {
        Button(action: { withAnimation { selectedMarket = tab } }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(selectedMarket == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                
                Rectangle()
                    .fill(selectedMarket == tab ? tabColor(for: tab) : Color.clear)
                    .frame(height: 2)
            }
        }
    }
    
    // MARK: - Market Tab Bar
    private var marketTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Global", tab: .global)
            tabButton(title: "Sirkiye", tab: .bist)
            tabButton(title: "Fonlar", tab: .fonlar)
        }
        .background(Color(hex: "10141f"))
    }
    
    // Tab color helper
    private func tabColor(for tab: MarketTab) -> Color {
        switch tab {
        case .global: return .cyan
        case .bist: return .red
        case .fonlar: return .green
        }
    }
    
    // Toolbar helpers
    private var toolbarIcon: String {
        switch selectedMarket {
        case .global: return "globe"
        case .bist: return "building.columns.fill"
        case .fonlar: return "chart.pie.fill"
        }
    }
    
    private var toolbarColor: Color {
        tabColor(for: selectedMarket)
    }
    
    private var toolbarTitle: String {
        switch selectedMarket {
        case .global: return "GLOBAL TERMINAL"
        case .bist: return "SİRKİYE KOKPİTİ"
        case .fonlar: return "TEFAS FONLARI"
        }
    }
}

// ... FundListEmbeddedView ... (Aynı kalabilir veya ayrı dosyaya alınabilir, şimdilik burada tutuyoruz ama sadeleştirilmiş)

// MARK: - SUBCOMPONENTS

struct TerminalControlBar: View {
    @Binding var sortOption: ArgusCockpitView.TerminalSortOption
    @Binding var hideLowQualityData: Bool
    let count: Int
    let selectedMarket: MarketTab
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(count) \(selectedMarket == .bist ? "HİSSE" : "TICKER")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                
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
                            .font(.caption)
                        Text(sortLabel(for: sortOption))
                            .font(.caption)
                            .bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(selectedMarket == .bist ? .red : .cyan)
                }
            }
            
            HStack {
                Toggle(isOn: $hideLowQualityData) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(hideLowQualityData ? .orange : .gray)
                        Text("Düşük Kaliteyi Gizle")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(hex: "10141f"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.05)), alignment: .bottom)
    }
    
    func sortLabel(for option: ArgusCockpitView.TerminalSortOption) -> String {
        guard selectedMarket == .bist else { return option.rawValue }
        switch option {
        case .councilScore: return "Divan Puani"
        case .orion: return "Tahta (Teknik)"
        case .atlas: return "Kasa (Temel)"
        case .prometheus: return "Prometheus"
        case .potential: return "Potansiyel"
        }
    }
}

// DUMB COMPONENT
struct TerminalStockRow: View {
    let item: TerminalItem // Artık tüm hesaplanmış veri burada
    var onOrionTap: () -> Void
    var onAtlasTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Ticker & Price
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.symbol.replacingOccurrences(of: ".IS", with: ""))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if item.market == .bist {
                        Text("TR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1))
                    }
                }
                
                Text(item.price > 0 
                     ? String(format: item.currency == .TRY ? "₺%.2f" : "$%.2f", item.price)
                     : "---")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(width: 80, alignment: .leading)
            
            // Scores
            let isBist = (item.market == .bist)
            HStack(spacing: 12) {
                Button(action: onOrionTap) {
                    TerminalScoreBadge(label: isBist ? "T" : "O", score: item.orionScore ?? 0, color: .cyan)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onAtlasTap) {
                    TerminalScoreBadge(label: isBist ? "K" : "A", score: item.atlasScore ?? 0, color: .yellow)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Council (Confidence) -> 0.75 -> 75
                TerminalScoreBadge(label: "★", score: (item.councilScore ?? 0) * 100, color: .green)
            }
            
            Spacer()
            
            // Prometheus
            PrometheusBadge(forecast: item.forecast)
            
            Spacer()
            
            // Action Signal + Chimera Badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(actionLocalizedString(item.action))
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(actionColor(item.action).opacity(0.2))
                    .foregroundColor(actionColor(item.action))
                    .cornerRadius(4)
                
                // Chimera Signal Badge (Deep Value, Bull Trap, etc.)
                if let signal = item.chimeraSignal {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(signal.severity > 0.7 ? Color.red : Color.orange)
                            .frame(width: 5, height: 5)
                        Text(signal.title)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(signal.severity > 0.7 ? .red : .orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                }
                
                if item.dataQuality < 100 {
                    HStack(spacing: 2) {
                        Image(systemName: "wifi.exclamationmark")
                        Text("%\(item.dataQuality)")
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return .green
        case .accumulate: return .mint
        case .neutral: return .gray
        case .trim: return .orange
        case .liquidate: return .red
        }
    }
    
    func actionLocalizedString(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "HÜCUM"
        case .accumulate: return "TOPLA"
        case .neutral: return "GÖZLE"
        case .trim: return "AZALT"
        case .liquidate: return "ÇIK"
        }
    }
}

// Terminal-specific simple score badge (doesn't use CompositeScore)
struct TerminalScoreBadge: View {
    let label: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(score > 0 ? .white : .gray)
            }
        }
    }
}
