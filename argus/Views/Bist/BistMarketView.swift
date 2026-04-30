import SwiftUI

// MARK: - BIST Market View (Refactored to use main TradingViewModel)
// Artık TradingViewModel ve PortfolioEngine kullanıyor

struct BistMarketView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Sabit BIST Listesi
    let universe: [String: String] = [
        "THYAO.IS": "Türk Hava Yolları",
        "ASELS.IS": "Aselsan",
        "KCHOL.IS": "Koç Holding",
        "AKBNK.IS": "Akbank",
        "GARAN.IS": "Garanti BBVA",
        "SAHOL.IS": "Sabancı Holding",
        "TUPRS.IS": "Tüpraş",
        "EREGL.IS": "Erdemir",
        "BIMAS.IS": "BİM Mağazaları",
        "SISE.IS": "Şişecam",
        "PETKM.IS": "Petkim",
        "SASA.IS": "SASA Polyester",
        "HEKTS.IS": "Hektaş",
        "FROTO.IS": "Ford Otosan",
        "TOASO.IS": "Tofaş",
        "ENKAI.IS": "Enka İnşaat",
        "ISCTR.IS": "İş Bankası (C)",
        "YKBNK.IS": "Yapı Kredi",
        "VAKBN.IS": "Vakıfbank",
        "HALKB.IS": "Halkbank",
        "PGSUS.IS": "Pegasus",
        "TAVHL.IS": "TAV Havalimanları",
        "TCELL.IS": "Turkcell",
        "TTKOM.IS": "Türk Telekom",
        "KOZAL.IS": "Koza Altın",
        "KOZAA.IS": "Koza Madencilik",
        "TKFEN.IS": "Tekfen Holding",
        "MGROS.IS": "Migros",
        "SOKM.IS": "Şok Marketler",
        "AEFES.IS": "Anadolu Efes",
        "ARCLK.IS": "Arçelik",
        "ALARK.IS": "Alarko Holding",
        "ASTOR.IS": "Astor Enerji",
        "GUBRF.IS": "Gübre Fabrikaları",
        "ISMEN.IS": "İş Yatırım"
    ]
    
    // BIST Watchlist from TradingViewModel
    private var bistWatchlist: [String] {
        viewModel.watchlist.filter { $0.hasSuffix(".IS") }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "BIST PİYASA",
                        subtitle: "İZLE · ARA · EKLE",
                        leadingDeco: .bars3([.holo, .text, .text]),
                        actions: [
                            .menu({ showDrawer = true }),
                            .custom(sfSymbol: "xmark", action: { dismiss() })
                        ]
                    )
                    searchBar
                    stockList
                }
            }
            .navigationBarHidden(true)
        }
        .overlay {
            if showDrawer {
                ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                    drawerSections(openSheet: openSheet)
                }
                .zIndex(200)
            }
        }
    }
    
    // MARK: - Search Bar (V5)
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .font(.system(size: 13, weight: .semibold))
            TextField("BIST hissesi ara · THYAO, ASELS…", text: $searchText)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Stock List
    private var stockList: some View {
        List {
            // Watchlist Section
            if searchText.isEmpty {
                Section(header: Text("Takip Listem")) {
                    ForEach(bistWatchlist, id: \.self) { symbol in
                        stockRow(symbol: symbol)
                    }
                    .onDelete(perform: deleteFromWatchlist)
                }
            }
            
            // Search Results
            if !searchText.isEmpty {
                Section(header: Text("Arama Sonuçları")) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        stockRow(symbol: symbol)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Stock Row (V5)
    @ViewBuilder
    private func stockRow(symbol: String) -> some View {
        HStack(spacing: 12) {
            CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(symbol.replacingOccurrences(of: ".IS", with: ""))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    if let score = viewModel.orionScores[symbol]?.score {
                        ArgusChip("ORION \(Int(score))",
                                  tone: score >= 60 ? .aurora :
                                        (score <= 40 ? .crimson : .titan))
                    }
                }
                Text(universe[symbol] ?? symbol)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if let q = viewModel.quotes[symbol] {
                let change = q.percentChange
                let changeColor: Color = change >= 0
                    ? InstitutionalTheme.Colors.aurora
                    : InstitutionalTheme.Colors.crimson
                VStack(alignment: .trailing, spacing: 4) {
                    Text("₺\(String(format: "%.2f", q.currentPrice))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(changeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(changeColor.opacity(0.18))
                        )
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(InstitutionalTheme.Colors.Motors.aether)
            }

            Button(action: { buyStock(symbol: symbol) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.vertical, 8)
        .onAppear {
            Task { await viewModel.ensureOrionAnalysis(for: symbol) }
        }
    }
    
    var filteredSymbols: [String] {
        if searchText.isEmpty { return [] }
        return universe.keys.filter {
            $0.contains(searchText.uppercased()) ||
            (universe[$0]?.uppercased().contains(searchText.uppercased()) ?? false)
        }.sorted()
    }
    
    func deleteFromWatchlist(at offsets: IndexSet) {
        let symbolsToRemove = offsets.map { bistWatchlist[$0] }
        viewModel.watchlist.removeAll { symbolsToRemove.contains($0) }
    }
    
    // Buy using PortfolioEngine
    private func buyStock(symbol: String) {
        // Add to watchlist if not present
        if !viewModel.watchlist.contains(symbol) {
            viewModel.watchlist.append(symbol)
        }
        
        guard let quote = viewModel.quotes[symbol] else {
            print("Quote not available for \(symbol)")
            return
        }
        
        let success = PortfolioStore.shared.buy(
            symbol: symbol,
            quantity: 1,
            price: quote.currentPrice,
            source: .user
        )
        
        if success != nil {
            print("BIST alim basarili: \(symbol)")
        }
    }
    
    private func scoreLabel(_ score: Double) -> String {
        if score >= 70 { return "AL" }
        if score <= 30 { return "SAT" }
        return "TUT"
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score <= 30 { return .red }
        return .orange
    }

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Alkindus Merkez", subtitle: "Yapay zeka ana sayfa", icon: "AlkindusIcon") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Kokpit ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portföy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
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
                title: "BIST",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Arama Temizle", subtitle: "Filtreyi sifirla", icon: "xmark.circle") {
                        searchText = ""
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Takip Listem", subtitle: "Izleme listesi", icon: "eye") {
                        searchText = ""
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Kapat", subtitle: "Pencereyi kapat", icon: "xmark") {
                        dismiss()
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
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
        )
        
        return sections
    }
}

// ScoreBadge kaldırıldı - TerminalScoreBadge kullanılıyor (ArgusCockpitView'dan)
