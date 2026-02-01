import SwiftUI

struct DiscoverView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false
    
    // Grid adaptation for horizontal scroll if needed, but HStacks work better for single row carousels.
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background: Pure Black
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // MARK: - 1. Top Gainers (Momentum)
                        VStack(alignment: .leading, spacing: 16) {
                            DiscoverSectionHeader(title: "Yükselenler", subtitle: "Günün momentum liderleri")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.topGainers, id: \.symbol) { quote in
                                        NavigationLink(destination: StockDetailView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
                                            DiscoverMarketCard(
                                                quote: quote,
                                                type: .gainer,
                                                onAddToWatchlist: { symbol in
                                                    viewModel.addToWatchlist(symbol: symbol)
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // MARK: - 2. Top Losers (Dip Opportunities)
                        VStack(alignment: .leading, spacing: 16) {
                            DiscoverSectionHeader(title: "Düşenler", subtitle: "Olası Phoenix adayları")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.topLosers, id: \.symbol) { quote in
                                        NavigationLink(destination: StockDetailView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
                                            DiscoverMarketCard(
                                                quote: quote,
                                                type: .loser,
                                                onAddToWatchlist: { symbol in
                                                    viewModel.addToWatchlist(symbol: symbol)
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // MARK: - 3. Most Active (Volume Leaders)
                        VStack(alignment: .leading, spacing: 16) {
                            DiscoverSectionHeader(title: "En Hareketliler", subtitle: "Hacim liderleri")
                                .padding(.bottom, 4)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.mostActive, id: \.symbol) { quote in
                                    NavigationLink(destination: StockDetailView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
                                        DiscoverMarketRow(quote: quote)
                                    }
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 70)
                                }
                            }
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1)) // Slightly lighter black for list
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Bottom Padding for TabBar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Keşfet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadDiscoverData() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .onAppear {
                viewModel.loadDiscoverData()
            }
            .refreshable {
                viewModel.loadDiscoverData()
            }
        }
        .preferredColorScheme(.dark) // Force Dark Mode for this view
        .overlay {
            if showDrawer {
                ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                    drawerSections(openSheet: openSheet)
                }
                .zIndex(200)
            }
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
                title: "KESFET",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Yenile", subtitle: "Listeyi guncelle", icon: "arrow.clockwise") {
                        viewModel.loadDiscoverData()
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "ARACLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                        openSheet(.calendar)
                    },
                    ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                        openSheet(.dictionary)
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

// MARK: - Components

struct DiscoverSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Color.gray)
        }
        .padding(.horizontal)
    }
}

enum MarketCardType {
    case gainer
    case loser
}

struct DiscoverMarketCard: View {
    let quote: Quote
    let type: MarketCardType
    let onAddToWatchlist: (String) -> Void
    
    var cardColor: Color {
        switch type {
        case .gainer: return Theme.positive
        case .loser: return Theme.negative
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon / Badge
            HStack {
                Circle()
                    .fill(cardColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: type == .gainer ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption).bold()
                            .foregroundColor(cardColor)
                    )
                Spacer()
                
                // Percent Badge
                Text(String(format: "%.2f%%", quote.percentChange))
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cardColor)
                    .foregroundColor(.white) // Text on solid color
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Symbol & Price
            VStack(alignment: .leading, spacing: 2) {
                Text(quote.symbol ?? "---")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
        }
        .padding(12)
        .frame(width: 140, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12)) // Dark gray card
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardColor.opacity(0.3), lineWidth: 1) // Neon border effect
        )
        .contextMenu {
            Button {
                if let symbol = quote.symbol, !symbol.isEmpty {
                    onAddToWatchlist(symbol)
                }
            } label: {
                Label("İzlemeye Ekle", systemImage: "eye.fill")
            }
        }
    }
}

struct DiscoverMarketRow: View {
    let quote: Quote
    
    // Helper for approximate volume string
    // Yahoo Quote struct doesn't strictly have volume in this simplified model usually, 
    // but assuming Quote struct might have it. 
    // If Quote struct in this project doesn't have `volume`, we omit it.
    // Let's check previously viewed code. `Quote` struct in `FundamentalModels.swift`.
    // Wait, `fetchQuote` returns `Quote`.
    // I recall `Quote` having `c`, `d`, `dp`.
    // If it doesn't have volume, we can simply show price.
    // I'll show symbol name/price.
    
    var body: some View {
        HStack(spacing: 16) {
            // Logo / Initial
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 40, height: 40)
                Text((quote.symbol ?? "?").prefix(1))
                    .bold()
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.symbol ?? "---")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                if let name = quote.shortName, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: quote.change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%.2f%%", quote.percentChange))
                        .font(.caption)
                        .bold()
                }
                .foregroundColor(quote.change >= 0 ? Theme.positive : Theme.negative)
            }
        }
        .padding()
        .background(Color.clear) // Transparent, container has background
    }
}
