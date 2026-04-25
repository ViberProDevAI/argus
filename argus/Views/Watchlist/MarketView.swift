import SwiftUI

// MARK: - MarketView (in-place refactor — ArgusDesignKit v1)
//
// Kural:
//   • Demo veri yok — tüm liste/kart WatchlistViewModel + TradingViewModel'den.
//   • View imzaları aynı: ContentView MarketView() olarak çağırıyor, değişmiyor.
//   • Tab (Global / SİRKİYE) davranışı + AppStorage anahtarı korunuyor.
//   • ArgusDrawerView, Search, Notifications, AetherDetail, Education, Discover sheet'leri değişmedi.
//   • BistCrystalRow/OrionSignalBadge görsel olarak tokenize edildi, logic değişmedi.

struct MarketView: View {
    @EnvironmentObject var viewModel: TradingViewModel       // Legacy (geçiş döneminde korunuyor)
    @EnvironmentObject var watchlistVM: WatchlistViewModel   // FAZ 2: Modüler sistem
    @ObservedObject var notificationStore = NotificationStore.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    // Market Mode: Global veya BIST
    enum MarketMode: String { case global, bist } // String rawValue needed for AppStorage
    @AppStorage("MarketView_SelectedMarket") private var selectedMarket: MarketMode = .global
    @Namespace private var animation // For sliding tab effect

    // UI State (davranış aynen korunuyor)
    @State private var showSearch = false
    @State private var showNotifications = false
    @State private var showAetherDetail = false
    @State private var showEducation = false
    @State private var showDiscover = false
    @State private var showDrawer = false

    // Filtered Watchlist — WatchlistViewModel tek kaynak
    var filteredWatchlist: [String] {
        switch selectedMarket {
        case .global:
            return watchlistVM.watchlist.filter { !$0.uppercased().hasSuffix(".IS") }
        case .bist:
            return watchlistVM.watchlist.filter {
                $0.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ScrollView {
                        LazyVStack(spacing: 24) {
                            switch selectedMarket {
                            case .global:
                                GlobalCockpitView(
                                    viewModel: viewModel,
                                    watchlist: filteredWatchlist,
                                    showAetherDetail: $showAetherDetail,
                                    showEducation: $showEducation,
                                    deleteAction: { symbol in deleteSymbol(symbol) }
                                )
                            case .bist:
                                BistCockpitView(
                                    viewModel: viewModel,
                                    watchlist: filteredWatchlist,
                                    deleteAction: { symbol in deleteSymbol(symbol) }
                                )
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(200)
                }

                // Programmatic Navigation (DeepLinkManager)
                NavigationLink(
                    destination: StockDetailView(
                        symbol: deepLinkManager.selectedStockSymbol ?? "",
                        viewModel: viewModel
                    ),
                    isActive: Binding(
                        get: { deepLinkManager.selectedStockSymbol != nil },
                        set: { if !$0 { deepLinkManager.selectedStockSymbol = nil } }
                    )
                ) { EmptyView() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearch) {
                AddSymbolSheet()
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAetherDetail) {
                if let macro = viewModel.macroRating {
                    ArgusAetherDetailView(rating: macro)
                        .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: $showEducation) {
                ChironEducationCard(result: ChironRegimeEngine.shared.lastResult, isPresented: $showEducation)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showDiscover) {
                DiscoverView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .onAppear { applyLaunchOverrideIfNeeded() }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Top Bar (Tab row + command header)

    private var topBar: some View {
        VStack(spacing: 0) {
            // Tab Row: GLOBAL / SİRKİYE
            HStack(spacing: 0) {
                marketTabButton(title: "GLOBAL", mode: .global)
                marketTabButton(title: "SİRKİYE", mode: .bist)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(InstitutionalTheme.Colors.surface1)

            // Command Header — Ayarlar ile bütüncül dil (kompakt, tek satırda sığar)
            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.primary)
                                .frame(width: 3, height: 20)
                            Text("PİYASA")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .tracking(2)
                        }
                        Text("İZLEME · SİNYAL · KEŞİF")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        headerIconButton(
                            icon: "line.3.horizontal",
                            tint: InstitutionalTheme.Colors.textSecondary,
                            label: "Menü"
                        ) { showDrawer = true }

                        headerIconButton(
                            icon: "globe",
                            tint: InstitutionalTheme.Colors.primary,
                            label: "Keşfet"
                        ) { showDiscover = true }

                        headerIconButton(
                            icon: "plus.circle.fill",
                            tint: InstitutionalTheme.Colors.primary,
                            label: "Hisse ekle"
                        ) { showSearch = true }

                        headerIconButton(
                            icon: "bell.fill",
                            tint: InstitutionalTheme.Colors.textSecondary,
                            label: "Bildirimler"
                        ) { showNotifications = true }
                    }
                }

                // V5 Pulse şeridi — ArgusDot + ArgusHair + tarih
                HStack(spacing: 8) {
                    ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 6)
                    Text("PİYASA AKTİF")
                        .font(InstitutionalTheme.Typography.dataMicro)
                        .tracking(1.2)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .layoutPriority(1)
                    ArgusHair()
                    Text(Date().formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(InstitutionalTheme.Typography.dataMicro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private func headerIconButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(.title3, design: .default))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func marketTabButton(title: String, mode: MarketMode) -> some View {
        let isSelected = selectedMarket == mode
        let indicatorTint: Color = (mode == .global)
            ? InstitutionalTheme.Colors.primary
            : InstitutionalTheme.Colors.negative

        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedMarket = mode } }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(isSelected ? .bold : .medium)
                    .tracking(1.1)
                    .foregroundColor(
                        isSelected
                            ? InstitutionalTheme.Colors.textPrimary
                            : InstitutionalTheme.Colors.textSecondary
                    )

                if isSelected {
                    Rectangle()
                        .fill(indicatorTint)
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "TabUnderline", in: animation)
                } else {
                    Rectangle().fill(Color.clear).frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) piyasa sekmesi")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Launch Override

    private func applyLaunchOverrideIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let openArgument = arguments.first(where: { $0.hasPrefix("--argus-open=") }) else {
            return
        }

        let openValue = openArgument.replacingOccurrences(of: "--argus-open=", with: "")
        switch openValue {
        case "discover":
            showDiscover = true
        case "sanctum":
            guard let symbolArgument = arguments.first(where: { $0.hasPrefix("--argus-symbol=") }) else {
                return
            }
            let symbol = symbolArgument
                .replacingOccurrences(of: "--argus-symbol=", with: "")
                .uppercased()
            guard !symbol.isEmpty else { return }
            if symbol.hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                selectedMarket = .bist
            } else {
                selectedMarket = .global
            }
            deepLinkManager.selectedStockSymbol = symbol
        default:
            break
        }
    }

    private func deleteSymbol(_ symbol: String) {
        // HER İKİ SİSTEMDEN DE SİL (geçiş dönemi senkronizasyonu)
        watchlistVM.removeSymbol(symbol)
        if let index = viewModel.watchlist.firstIndex(of: symbol) {
            viewModel.deleteFromWatchlist(at: IndexSet(integer: index))
        }
    }

    // MARK: - Drawer Sections

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
                    ArgusDrawerView.DrawerItem(title: "Terminal", subtitle: "Trader terminal", icon: "square.grid.2x2") {
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
                title: "PIYASA",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Hisse Ekle", subtitle: "Listeye sembol ekle", icon: "plus.circle") {
                        showSearch = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Kesfet", subtitle: "Piyasa taramasi", icon: "globe") {
                        showDiscover = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Bildirimler", subtitle: "Son uyarilar", icon: "bell") {
                        showNotifications = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Aether Detay", subtitle: "Makro rejim", icon: "sparkles") {
                        showAetherDetail = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Egitim", subtitle: "Argus akademi", icon: "book") {
                        openSheet(.academyHub)
                    },
                    ArgusDrawerView.DrawerItem(title: "Global Piyasa", subtitle: "Market degistir", icon: "globe.asia.australia") {
                        selectedMarket = .global
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "BIST Piyasa", subtitle: "Market degistir", icon: "chart.bar") {
                        selectedMarket = .bist
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

// MARK: - GLOBAL COCKPIT

struct GlobalCockpitView: View {
    @ObservedObject var viewModel: TradingViewModel
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    let watchlist: [String]
    @Binding var showAetherDetail: Bool
    @Binding var showEducation: Bool
    let deleteAction: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Aether HUD
            AetherDashboardHUD(
                rating: viewModel.macroRating,
                onTap: { showAetherDetail = true }
            )
            .onAppear {
                if viewModel.macroRating == nil {
                    Task(priority: .background) {
                        viewModel.loadMacroEnvironment(forceRefresh: false)
                    }
                }
            }

            // Chiron Neural Link
            ChironNeuralLink(showEducation: $showEducation)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // SmartTicker Strip
            SmartTickerStrip(viewModel: viewModel)
                .padding(.top, 16)

            // Watchlist Section Header: GLOBAL İZLEME + LIVE/DELAY pill
            ArgusSectionHeader("GLOBAL İZLEME") {
                LiveStatusPill(isLive: viewModel.isLiveMode)
            }
            .padding(.top, 12)

            // Watchlist
            if watchlist.isEmpty {
                MarketEmptyStateView()
                    .padding(.top, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(watchlist, id: \.self) { symbol in
                        NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                            CrystalWatchlistRow(
                                symbol: symbol,
                                quote: watchlistVM.quotes[symbol],
                                candles: viewModel.candles[symbol],
                                forecast: viewModel.prometheusForecastBySymbol[symbol],
                                signal: viewModel.aiSignals.first(where: { $0.symbol == symbol })
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) { deleteAction(symbol) } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - BIST COCKPIT (SİRKİYE)

struct BistCockpitView: View {
    @ObservedObject var viewModel: TradingViewModel
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    let watchlist: [String]
    let deleteAction: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Sirkiye Cockpit Header (SirkiyeDashboardView zaten "SİRKİYE KORTEKS" başlığını kendi kartında sunuyor,
            // burada yalnızca grup başlığı koruyoruz)
            ArgusSectionHeader("SİRKİYE KOKPİTİ", subtitle: "Makro rejim + BIST canlı nabız") {
                Image(systemName: "eye.fill")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
            }

            SirkiyeDashboardView(viewModel: viewModel)

            // Watchlist Section
            ArgusSectionHeader("BIST TAKİP (TL)")
                .padding(.top, 8)

            if watchlist.isEmpty {
                ArgusEmptyState(
                    icon: "chart.bar.doc.horizontal",
                    title: "BIST listesi boş",
                    message: "Takip etmek istediğin BIST hisselerini 'Hisse' butonundan ekle."
                )
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(watchlist, id: \.self) { symbol in
                        NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                            BistCrystalRow(
                                symbol: symbol,
                                quote: watchlistVM.quotes[symbol],
                                orionResult: viewModel.orionScores[symbol]
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .onAppear {
                                if viewModel.orionScores[symbol] == nil {
                                    Task { await viewModel.loadOrionScore(for: symbol) }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) { deleteAction(symbol) } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - LIVE / DELAY Pill (cockpit trailing)

private struct LiveStatusPill: View {
    let isLive: Bool

    private var tint: Color {
        isLive ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.neutral
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(isLive ? "LIVE" : "DELAY")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel(isLive ? "Canlı veri" : "Gecikmeli veri")
    }
}

// MARK: - AddSymbolSheet
// PILOT MIGRATION: WatchlistViewModel kullanıyor; davranış aynı.

struct AddSymbolSheet: View {
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    @EnvironmentObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var symbol: String = ""
    @FocusState private var isFocused: Bool
    let popularSymbols = ["NVDA", "AMD", "TSLA", "AAPL", "MSFT", "META", "AMZN", "GOOGL", "NFLX", "COIN"]
    let popularBist = ["THYAO.IS", "ASELS.IS", "AKBNK.IS", "KCHOL.IS", "EREGL.IS"]
    @State private var searchBist = false

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        TextField("Sembol ara (Örn: \(searchBist ? "THYAO.IS" : "PLTR"))", text: $symbol)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .onChange(of: symbol) { _, newValue in
                                watchlistVM.search(query: newValue)
                            }
                            .onSubmit { addAndDismiss(symbol) }

                        if !symbol.isEmpty {
                            Button(action: {
                                symbol = ""
                                watchlistVM.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Aramayı temizle")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .fill(InstitutionalTheme.Colors.surface1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Piyasa Toggle
                    Picker("Piyasa", selection: $searchBist) {
                        Text("Global").tag(false)
                        Text("BIST").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)

                    // Search Results / Popular
                    if !symbol.isEmpty && !watchlistVM.searchResults.isEmpty {
                        List(watchlistVM.searchResults) { result in
                            Button(action: { addAndDismiss(result.symbol) }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.symbol)
                                            .font(.system(.callout, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        Text(result.description)
                                            .font(.caption)
                                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(InstitutionalTheme.Colors.primary)
                                }
                                .frame(minHeight: 44)
                            }
                            .listRowBackground(InstitutionalTheme.Colors.surface1)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(InstitutionalTheme.Colors.background)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Popüler (\(searchBist ? "BIST" : "Global"))")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .tracking(1.2)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(searchBist ? popularBist : popularSymbols, id: \.self) { item in
                                        Button(action: { addAndDismiss(item) }) {
                                            Text(item)
                                                .font(.system(.caption, design: .monospaced))
                                                .fontWeight(.semibold)
                                                .tracking(0.8)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .frame(minHeight: 44)
                                                .background(
                                                    Capsule().fill(InstitutionalTheme.Colors.surface1)
                                                )
                                                .overlay(
                                                    Capsule().stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                                                )
                                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Hisse Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true }
            }
        }
    }

    private func addAndDismiss(_ symbolToAdd: String) {
        if !symbolToAdd.isEmpty {
            // HER İKİ SİSTEME DE EKLE (geçiş dönemi senkronizasyonu)
            watchlistVM.addSymbol(symbolToAdd)
            viewModel.addSymbol(symbolToAdd)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Empty State

struct MarketEmptyStateView: View {
    var body: some View {
        ArgusEmptyState(
            icon: "magnifyingglass.circle",
            title: "Takip listen boş",
            message: "İzlemek istediğin hisseleri eklemek için üstteki 'Hisse' butonuna bas."
        )
    }
}

// MARK: - BIST Crystal Row (Global ile aynı tasarım dili, tokenize)

struct BistCrystalRow: View {
    let symbol: String
    let quote: Quote?
    let orionResult: OrionScoreResult?

    private var cleanSymbol: String {
        symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
    }

    private var companyName: String {
        let names: [String: String] = [
            "THYAO": "Türk Hava Yolları",
            "ASELS": "Aselsan",
            "KCHOL": "Koç Holding",
            "AKBNK": "Akbank",
            "GARAN": "Garanti BBVA",
            "SAHOL": "Sabancı Holding",
            "TUPRS": "Tüpraş",
            "EREGL": "Erdemir",
            "BIMAS": "BİM Mağazaları",
            "SISE": "Şişecam",
            "FROTO": "Ford Otosan",
            "TOASO": "Tofaş",
            "TCELL": "Turkcell",
            "TTKOM": "Türk Telekom",
            "PGSUS": "Pegasus",
            "ARCLK": "Arçelik",
            "MGROS": "Migros",
            "ISCTR": "İş Bankası",
            "YKBNK": "Yapı Kredi",
            "VAKBN": "Vakıfbank",
            "HALKB": "Halkbank",
            "PETKM": "Petkim",
            "SASA": "SASA Polyester",
            "ENKAI": "Enka İnşaat",
            "TAVHL": "TAV Havalimanları",
            "KOZAL": "Koza Altın",
            "TKFEN": "Tekfen Holding",
            "SOKM": "Şok Marketler",
            "AEFES": "Anadolu Efes",
            "GUBRF": "Gübre Fabrikaları"
        ]
        return names[cleanSymbol] ?? cleanSymbol
    }

    var body: some View {
        HStack(spacing: 12) {
            // Kimlik
            HStack(spacing: 12) {
                CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                    .overlay(Circle().stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanSymbol)
                        .font(.system(.callout, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(companyName)
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Orion Sinyal
            if let result = orionResult {
                OrionSignalBadge(result: result)
                    .frame(width: 84, alignment: .center)
            } else {
                Text("—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .frame(width: 84, alignment: .center)
            }

            // Fiyat + % Değişim
            if let q = quote {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "₺%.2f", q.currentPrice))
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    ArgusDeltaPill(delta: q.percentChange, isPercent: true, compact: true)
                }
                .frame(minWidth: 84, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 56, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 44, height: 12)
                }
                .frame(minWidth: 84, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Orion Sinyal Badge (tokenize)

struct OrionSignalBadge: View {
    let result: OrionScoreResult

    private var tint: Color {
        let v = result.verdict.lowercased()
        if v.contains("al") || v.contains("buy")  { return InstitutionalTheme.Colors.positive }
        if v.contains("sat") || v.contains("sell") { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.neutral
    }

    private var icon: String {
        let v = result.verdict.lowercased()
        if v.contains("al") || v.contains("buy")  { return "arrow.up.circle.fill" }
        if v.contains("sat") || v.contains("sell") { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private var shortVerdict: String {
        let v = result.verdict.lowercased()
        if v.contains("al") || v.contains("buy")   { return "AL" }
        if v.contains("sat") || v.contains("sell") { return "SAT" }
        return "TUT"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(.caption, design: .default))
                .foregroundColor(tint)

            Text(shortVerdict)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(tint)

            Text("\(Int(result.score))")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(tint.opacity(0.14))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityLabel(Text("Orion sinyali \(shortVerdict), skor \(Int(result.score))"))
    }
}
