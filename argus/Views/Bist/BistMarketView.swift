import SwiftUI

// MARK: - BIST Market View (Refactored to use main TradingViewModel)
// Artık TradingViewModel ve PortfolioEngine kullanıyor

struct BistMarketView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
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
        NavigationView {
            VStack {
                searchBar
                stockList
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("BIST Piyasa")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("BIST Hissesi Ara (örn: THYAO)", text: $searchText)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding()
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
    
    // MARK: - Stock Row
    @ViewBuilder
    private func stockRow(symbol: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(symbol.replacingOccurrences(of: ".IS", with: ""))
                        .font(.headline)
                        .bold()
                    
                    // Score Badges (Grafik, Rejim)
                    HStack(spacing: 2) {
                        if let faktorScore = viewModel.orionScores[symbol]?.score {
                            TerminalScoreBadge(label: "G", score: faktorScore, color: .cyan)
                        }
                        if let rejimScore = viewModel.orionScores[symbol]?.score {
                            TerminalScoreBadge(label: "R", score: rejimScore, color: .red)
                        }
                    }
                }
                
                Text(universe[symbol] ?? symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let q = viewModel.quotes[symbol] {
                VStack(alignment: .trailing) {
                    Text("₺\(String(format: "%.2f", q.currentPrice))")
                        .bold()
                    
                    let change = q.percentChange
                    Text("\(change >= 0 ? "+" : "")%\(String(format: "%.2f", change))")
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                        .padding(4)
                        .background(change >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // Hızlı Al Butonu
            Button(action: {
                buyStock(symbol: symbol)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.tint)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
        .onAppear {
            Task {
                await viewModel.ensureOrionAnalysis(for: symbol)
            }
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
            print("⚠️ Quote not available for \(symbol)")
            return
        }
        
        let success = PortfolioStore.shared.buy(
            symbol: symbol,
            quantity: 1,
            price: quote.currentPrice,
            source: .user
        )
        
        if success != nil {
            print("✅ BIST Alım Başarılı: \(symbol)")
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
}

// ScoreBadge kaldırıldı - TerminalScoreBadge kullanılıyor (ArgusCockpitView'dan)
