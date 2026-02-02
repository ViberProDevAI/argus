import SwiftUI

struct MarketView: View {
    @EnvironmentObject var viewModel: TradingViewModel // Legacy (Geçiş döneminde korunuyor)
    @EnvironmentObject var watchlistVM: WatchlistViewModel // FAZ 2: Yeni modüler sistem
    @ObservedObject var notificationStore = NotificationStore.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Market Mode: Global veya BIST
    // Market Mode: Global veya BIST
    enum MarketMode: String { case global, bist } // String rawValue needed for AppStorage
    @AppStorage("MarketView_SelectedMarket") private var selectedMarket: MarketMode = .global
    @Namespace private var animation // For sliding tab effect
    
    // UI State
    @State private var showSearch = false // showAddSymbolSheet idi, showSearch yaptık
    @State private var showNotifications = false
    @State private var showAetherDetail = false
    @State private var showEducation = false // NEW
    @State private var showDiscover = false // NEW: Access to DiscoverView via Market Header
    @State private var showDrawer = false
    
    // Filtered Watchlist - ARTIK WatchlistViewModel'DEN OKUYOR (Performans iyileştirmesi)
    var filteredWatchlist: [String] {
        switch selectedMarket {
        case .global:
            return watchlistVM.watchlist.filter { !$0.uppercased().hasSuffix(".IS") }
        case .bist:
            return watchlistVM.watchlist.filter { $0.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. CUSTOM HEADER (Premium Toggle)
                    HStack {
                        marketTabButton(title: "GLOBAL", mode: .global)
                        marketTabButton(title: "SİRKİYE", mode: .bist)
                    }
                    .padding()
                    .background(Theme.secondaryBackground.opacity(0.5))
                    // Custom Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Piyasa")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // Tarih
                            Text(Date().formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            Button(action: { showDrawer = true }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title3)
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Button(action: { showDiscover = true }) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                    .foregroundColor(Theme.tint)
                            }
                            
                            Button(action: { showSearch = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("Hisse Ekle")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Theme.tint)
                            }
                            
                            Button(action: { showNotifications = true }) {
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    
                    // Main Content
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            
                            // Market Tab'a göre ilgili Cockpit'i göster
                            switch selectedMarket {
                            case .global:
                                // 1. Global Markets
                                GlobalCockpitView(
                                    viewModel: viewModel,
                                    watchlist: filteredWatchlist, // Zaten global filtrelenmiş
                                    showAetherDetail: $showAetherDetail,
                                    showEducation: $showEducation,
                                    deleteAction: { symbol in
                                        deleteSymbol(symbol)
                                    }
                                )
                                
                            case .bist:
                                // 2. Borsa Istanbul (Sirkiye en üstte)
                                BistCockpitView(
                                    viewModel: viewModel,
                                    watchlist: filteredWatchlist, // Zaten BIST filtrelenmiş
                                    deleteAction: { symbol in
                                       deleteSymbol(symbol)
                                    }
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
                
                // Navigation Link for Programmatic Navigation (DeepLinkManager)
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
                AddSymbolSheet() // Environment'tan alıyor
            }
            .sheet(isPresented: $showAetherDetail) {
                if let macro = viewModel.macroRating { ArgusAetherDetailView(rating: macro) }
            }
            .sheet(isPresented: $showEducation) {
                ChironEducationCard(result: ChironRegimeEngine.shared.lastResult, isPresented: $showEducation)
            }
            .sheet(isPresented: $showDiscover) {
                DiscoverView(viewModel: viewModel)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func deleteSymbol(_ symbol: String) {
        // HER İKİ SİSTEMDEN DE SİL (Geçiş dönemi senkronizasyonu)
        watchlistVM.removeSymbol(symbol)
        if let index = viewModel.watchlist.firstIndex(of: symbol) {
            viewModel.deleteFromWatchlist(at: IndexSet(integer: index))
        }
    }
    
    // Custom Tab Button
    @ViewBuilder
    func marketTabButton(title: String, mode: MarketMode) -> some View {
        Button(action: { withAnimation { selectedMarket = mode } }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(selectedMarket == mode ? .bold : .regular)
                    .foregroundColor(selectedMarket == mode ? .white : .gray)
                
                if selectedMarket == mode {
                    Rectangle()
                        .fill(mode == .global ? Theme.primary : Color.cyan)
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "TabUnderline", in: animation)
                } else {
                    Rectangle().fill(Color.clear).frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                    ArgusDrawerView.DrawerItem(title: "Terminal", subtitle: "Trader terminal", icon: "square.grid.2x2") {
                        deepLinkManager.navigate(to: .markets)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        deepLinkManager.navigate(to: .alkindus)
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
                    ArgusDrawerView.DrawerItem(title: "Egitim", subtitle: "Rejim ozeti", icon: "book") {
                        showEducation = true
                        showDrawer = false
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
    @ObservedObject var viewModel: TradingViewModel // Legacy (Aether, SmartTicker için)
    @EnvironmentObject var watchlistVM: WatchlistViewModel // Quotes için yeni sistem
    let watchlist: [String]
    @Binding var showAetherDetail: Bool
    @Binding var showEducation: Bool // NEW
    let deleteAction: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Aether HUD (New Futuristic Design)
            AetherDashboardHUD(
                rating: viewModel.macroRating,
                onTap: { showAetherDetail = true }
            )
            // PERFORMANS: Macro load artık background'da, Bootstrap'ta zaten çağrılıyor
            // Sadece cache boşsa lazy load yap
            .onAppear { 
                if viewModel.macroRating == nil { 
                    Task.detached(priority: .background) {
                        await MainActor.run { viewModel.loadMacroEnvironment() }
                    }
                } 
            }
            
            // CHIRON NEURAL LINK (PULSE) - NEW!
            ChironNeuralLink(showEducation: $showEducation)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            
            // ScoutStoriesBar REMOVED from here (Moved to Terminal)
            
            SmartTickerStrip(viewModel: viewModel)
                .padding(.top, 16)
            
            // Watchlist Header
            HStack {
                Text("GLOBAL İZLEME")
                    .font(.caption).bold().foregroundColor(Theme.textSecondary)
                Spacer()
                Text(viewModel.isLiveMode ? "LIVE" : "DELAY")
                    .font(.caption2).bold()
                    .foregroundColor(viewModel.isLiveMode ? .green : .gray)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            // Watchlist - QUOTES ARTIK WatchlistViewModel'DEN OKUNUYOR
            if watchlist.isEmpty {
                MarketEmptyStateView().padding(.top, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(watchlist, id: \.self) { symbol in
                        NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                            CrystalWatchlistRow(
                                symbol: symbol,
                                quote: watchlistVM.quotes[symbol], // Yeni sistem
                                candles: viewModel.candles[symbol], // Candles hala TradingVM'den
                                forecast: viewModel.prometheusForecastBySymbol[symbol] // Prometheus
                            )
                            .padding(.horizontal, 16).padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) { deleteAction(symbol) } label: { Label("Sil", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - BIST COCKPIT (SİRKİYE)
struct BistCockpitView: View {
    @ObservedObject var viewModel: TradingViewModel // Legacy (Orion, SirkiyeDashboard için)
    @EnvironmentObject var watchlistVM: WatchlistViewModel // Quotes için yeni sistem
    let watchlist: [String]
    let deleteAction: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Sirkiye Dashboard Header
            HStack {
                Text("SİRKİYE KOKPİTİ")
                    .font(.title3).bold()
                    .tracking(1)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "eye.fill")
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal)
            
            SirkiyeDashboardView(viewModel: viewModel)
                .padding(.bottom, 8)
            
            // Watchlist Header
            HStack {
                Text("BIST TAKİP (TL)")
                    .font(.caption).bold().foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            if watchlist.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48)).foregroundColor(Theme.textSecondary.opacity(0.3))
                    Text("BIST hissesi ekle")
                        .foregroundColor(Theme.textSecondary)
                }.padding(.top, 40)
            } else {
                // BIST icin de ayni Crystal tasarim
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
                                // Orion analizi yoksa yukle
                                if viewModel.orionScores[symbol] == nil {
                                    Task { await viewModel.loadOrionScore(for: symbol) }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) { deleteAction(symbol) } label: { Label("Sil", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }
}

// Keep Helper Views
// PILOT MIGRATION: AddSymbolSheet artık WatchlistViewModel kullanıyor
struct AddSymbolSheet: View {
    @EnvironmentObject var watchlistVM: WatchlistViewModel // Yeni sistem
    @EnvironmentObject var viewModel: TradingViewModel // Backward compatibility (search için)
    @Environment(\.presentationMode) var presentationMode
    @State private var symbol: String = ""
    @FocusState private var isFocused: Bool
    let popularSymbols = ["NVDA", "AMD", "TSLA", "AAPL", "MSFT", "META", "AMZN", "GOOGL", "NFLX", "COIN"]
    let popularBist = ["THYAO.IS", "ASELS.IS", "AKBNK.IS", "KCHOL.IS", "EREGL.IS"]
    @State private var searchBist = false
    
    var body: some View {
        NavigationView {
             ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    // Search Bar
                     HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.textSecondary)
                        TextField("Sembol Ara (Örn: \(searchBist ? "THYAO.IS" : "PLTR"))", text: $symbol)
                            .foregroundColor(Theme.textPrimary)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .onChange(of: symbol) { _, newValue in 
                                // Search: Her iki VM'de de çağır (geçiş dönemi)
                                watchlistVM.search(query: newValue)
                            }
                            .onSubmit { addAndDismiss(symbol) }
                        
                        if !symbol.isEmpty {
                            Button(action: { symbol = ""; watchlistVM.searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Toggle for Suggestions
                    Picker("Piyasa", selection: $searchBist) {
                        Text("Global").tag(false)
                        Text("BIST").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // WatchlistViewModel'den search results
                    if !symbol.isEmpty && !watchlistVM.searchResults.isEmpty {
                        List(watchlistVM.searchResults) { result in
                            Button(action: { addAndDismiss(result.symbol) }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.symbol).bold().foregroundColor(Theme.textPrimary)
                                        Text(result.description).font(.caption).foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundColor(Theme.primary)
                                }
                            }
                            .listRowBackground(Theme.secondaryBackground)
                        }
                        .listStyle(.plain)
                        .background(Theme.background)
                    } else {
                        VStack(alignment: .leading) {
                            Text("Popüler (\(searchBist ? "BIST" : "Global"))").font(.caption).foregroundColor(Theme.textSecondary).padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(searchBist ? popularBist : popularSymbols, id: \.self) { item in
                                        Button(action: { addAndDismiss(item) }) {
                                            Text(item).padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(Theme.secondaryBackground).foregroundColor(Theme.textPrimary).cornerRadius(20)
                                        }
                                    }
                                }.padding(.horizontal)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Hisse Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Kapat") { presentationMode.wrappedValue.dismiss() } } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true } }
        }
    }
    private func addAndDismiss(_ symbolToAdd: String) {
        if !symbolToAdd.isEmpty {
            // HER İKİ SİSTEME DE EKLE (Geçiş dönemi senkronizasyonu)
            watchlistVM.addSymbol(symbolToAdd)
            viewModel.addSymbol(symbolToAdd)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct MarketEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle").font(.system(size: 64)).foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("Takip listen boş").font(.headline).foregroundColor(Theme.textPrimary)
            Text("İzlemek istediğin hisseleri eklemek için\n+ butonuna bas.").font(.subheadline).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
        }
    }
}

// MARK: - BIST Crystal Row (Global ile ayni tasarim)
// CrystalWatchlistRow ile birebir ayni gorunum, BIST verileri icin

struct BistCrystalRow: View {
    let symbol: String
    let quote: Quote?
    let orionResult: OrionScoreResult?

    // Temiz sembol (.IS olmadan)
    private var cleanSymbol: String {
        symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
    }

    // Degisim rengi
    private var changeColor: Color {
        guard let q = quote else { return Theme.textSecondary }
        return q.change >= 0 ? Theme.positive : Theme.negative
    }

    // Şirket ismi (basit mapping)
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
            // 1. Logo + Kimlik (Global ile ayni)
            HStack(spacing: 12) {
                CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanSymbol)
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(Theme.textPrimary)

                    Text(companyName)
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 2. Orion Sinyal Badge (Prometheus yerine)
            if let result = orionResult {
                OrionSignalBadge(result: result)
                    .frame(width: 80, alignment: .center)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.3))
                    .frame(width: 80, alignment: .center)
            }

            // 3. Fiyat Pill (Global ile ayni)
            if let q = quote {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "₺%.2f", q.currentPrice))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(changeColor)
                        .cornerRadius(6)
                }
            } else {
                // Yukleniyor iskeleti
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 40, height: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Orion Sinyal Badge (BIST icin Prometheus yerine)

struct OrionSignalBadge: View {
    let result: OrionScoreResult

    private var signalColor: Color {
        let verdict = result.verdict.lowercased()
        if verdict.contains("al") || verdict.contains("buy") { return .green }
        if verdict.contains("sat") || verdict.contains("sell") { return .red }
        return .orange
    }

    private var signalIcon: String {
        let verdict = result.verdict.lowercased()
        if verdict.contains("al") || verdict.contains("buy") { return "arrow.up.circle.fill" }
        if verdict.contains("sat") || verdict.contains("sell") { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private var shortVerdict: String {
        let verdict = result.verdict.lowercased()
        if verdict.contains("guclu al") || verdict.contains("strong buy") { return "AL" }
        if verdict.contains("al") || verdict.contains("buy") { return "AL" }
        if verdict.contains("guclu sat") || verdict.contains("strong sell") { return "SAT" }
        if verdict.contains("sat") || verdict.contains("sell") { return "SAT" }
        return "TUT"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: signalIcon)
                .font(.system(size: 12))
                .foregroundColor(signalColor)

            Text(shortVerdict)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(signalColor)

            // Skor gostergesi
            Text("\(Int(result.score))")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(signalColor.opacity(DesignTokens.Opacity.glassCard))
        .cornerRadius(8)
    }
}
