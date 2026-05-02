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
        NavigationStack {
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

            }
            .navigationBarHidden(true)
            // Programmatic Navigation (DeepLinkManager)
            // Modern API: navigationDestination(isPresented:) — iOS 16'da
            // NavigationLink(isActive:) deprecated. Hidden EmptyView trick'i
            // de gerekmiyor.
            .navigationDestination(
                isPresented: Binding(
                    get: { deepLinkManager.selectedStockSymbol != nil },
                    set: { if !$0 { deepLinkManager.selectedStockSymbol = nil } }
                )
            ) {
                ArgusSanctumView(
                    symbol: deepLinkManager.selectedStockSymbol ?? "",
                    viewModel: viewModel
                )
            }
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

    // 2026-04-30 H-49 — sade. İki ayrı surface1 katmanı (tab row ayrı,
    // command header ayrı) tek panele birleşti. Header ikon renkleri:
    // primary (mavi) keşfet/+ → tüm ikonlar textSecondary nötr.
    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Text("Piyasa")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                HStack(spacing: 0) {
                    headerIconButton(icon: "line.3.horizontal", label: "Menü") { showDrawer = true }
                    headerIconButton(icon: "globe", label: "Keşfet") { showDiscover = true }
                    headerIconButton(icon: "plus", label: "Hisse ekle") { showSearch = true }
                    headerIconButton(icon: "bell", label: "Bildirimler") { showNotifications = true }
                }
            }

            HStack(spacing: 0) {
                marketTabButton(title: "Global", mode: .global)
                marketTabButton(title: "Sirkiye", mode: .bist)
                Spacer()
                Circle()
                    .fill(InstitutionalTheme.Colors.aurora)
                    .frame(width: 6, height: 6)
                Text("Açık")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.leading, 6)
                    .padding(.trailing, 8)
                Text(Date().formatted(.dateTime.hour().minute()))
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func headerIconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Tab Button

    // 2026-04-30 H-49: Eski tam-genişlik 50/50 split (marketTabButton
    // her biri maxWidth:.infinity) yerine drawer/portfolio ile aynı sade
    // underline tab. Solda yan yana sıkışıyor, sağda status satırı var.
    @ViewBuilder
    private func marketTabButton(title: String, mode: MarketMode) -> some View {
        let isSelected = selectedMarket == mode
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedMarket = mode } }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected
                                     ? InstitutionalTheme.Colors.textPrimary
                                     : InstitutionalTheme.Colors.textSecondary)
                Rectangle()
                    .fill(isSelected
                          ? InstitutionalTheme.Colors.textPrimary
                          : Color.clear)
                    .frame(height: 1.5)
                    .matchedGeometryEffect(id: isSelected ? "TabUnderline" : "TabUnderlineHidden_\(mode.rawValue)", in: animation)
            }
            .padding(.horizontal, 8)
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
                title: "Ekranlar",
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
                title: "Piyasa",
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
            // 2026-04-24 H-30: Aether ve Chiron kartları "Piyasa" hibrit
            // kartında birleşti — anasayfada tek satır, sıfat zinciri ile
            // hem skor hem rejim hissi. ChironNeuralLink struct'ı kodda
            // duruyor, detay sayfası ya da ileriki bir kullanım için
            // hazır kalıyor; sadece anasayfa render'ından çıktı.
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

            // SmartTicker Strip
            SmartTickerStrip(viewModel: viewModel)
                .padding(.top, 16)

            // 2026-04-24 H-26: "GLOBAL İZLEME" mono caps + "LIVE" pill yerine
            // sade sentence-case başlık + canlılık dot'u. Bant zaten "CANLI"
            // pill'i taşıyor, ikinci kez tekrarlamaya gerek yok.
            HStack(spacing: 8) {
                Text("İzleme listesi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                if viewModel.isLiveMode {
                    ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Watchlist
            if watchlist.isEmpty {
                MarketEmptyStateView()
                    .padding(.top, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(watchlist, id: \.self) { symbol in
                        NavigationLink(destination: ArgusSanctumView(symbol: symbol, viewModel: viewModel)) {
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
            ArgusSectionHeader("Sirkiye kokpiti", subtitle: "Makro rejim + BIST canlı nabız") {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            SirkiyeDashboardView(viewModel: viewModel)

            // Watchlist Section
            ArgusSectionHeader("BIST takip", subtitle: "Türk lirası")
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
                        NavigationLink(destination: ArgusSanctumView(symbol: symbol, viewModel: viewModel)) {
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
        NavigationStack {
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

    // 2026-04-30 H-49 — sade. CrystalWatchlistRow ile tutarlı dile geçti:
    // şirket adı 14pt semibold üstte, sembol 11pt mono caption alt;
    // fiyat 14pt semibold (mono yerine standart), yüzde sade renkli text.
    var body: some View {
        HStack(spacing: 12) {
            // Kimlik
            HStack(spacing: 12) {
                CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                    .overlay(Circle().stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(companyName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(cleanSymbol)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Orion Sinyal
            if let result = orionResult {
                OrionSignalBadge(result: result)
            } else {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            // Fiyat + % Değişim
            if let q = quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "₺%.2f", q.currentPrice))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(String(format: "%+.2f%%", q.percentChange))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(q.percentChange >= 0
                                         ? InstitutionalTheme.Colors.aurora
                                         : InstitutionalTheme.Colors.crimson)
                }
                .frame(minWidth: 82, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 56, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 44, height: 12)
                }
                .frame(minWidth: 82, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(ArgusHair(), alignment: .bottom)
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

    /// 2026-04-30 H-49 — sade. "AL/SAT/TUT" caps mono tracking → sentence
    /// case "Al/Sat/Tut" (CrystalWatchlistRow actionPill ile aynı dil).
    private var shortVerdict: String {
        let v = result.verdict.lowercased()
        if v.contains("al") || v.contains("buy")   { return "Al" }
        if v.contains("sat") || v.contains("sell") { return "Sat" }
        return "Tut"
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(shortVerdict)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
            Text("\(Int(result.score))")
                .font(.system(size: 11))
                .foregroundColor(tint.opacity(0.75))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(tint.opacity(0.14))
        )
        .accessibilityLabel(Text("Orion sinyali \(shortVerdict), skor \(Int(result.score))"))
    }
}
