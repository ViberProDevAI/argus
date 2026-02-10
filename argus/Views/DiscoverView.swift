import SwiftUI

struct DiscoverView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false
    
    // Grid adaptation for horizontal scroll if needed, but HStacks work better for single row carousels.
    
    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                
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
                                        .background(InstitutionalTheme.Colors.borderSubtle)
                                        .padding(.leading, 70)
                                }
                            }
                            .background(InstitutionalTheme.Colors.surface1)
                            .cornerRadius(InstitutionalTheme.Radius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                            )
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
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadDiscoverData() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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

// MARK: - Components

struct DiscoverSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(InstitutionalTheme.Typography.headline)
                .bold()
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(subtitle)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
        case .gainer: return InstitutionalTheme.Colors.positive
        case .loser: return InstitutionalTheme.Colors.negative
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
                    .font(InstitutionalTheme.Typography.micro)
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
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .bold()
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 140, height: 110)
        .institutionalCard(scale: .micro)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(cardColor.opacity(0.45), lineWidth: 1)
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
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 40, height: 40)
                Text((quote.symbol ?? "?").prefix(1))
                    .bold()
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.symbol ?? "---")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .bold()
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                if let name = quote.shortName, !name.isEmpty {
                    Text(name)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                    .font(InstitutionalTheme.Typography.data)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: quote.change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%.2f%%", quote.percentChange))
                        .font(.caption)
                        .bold()
                }
                .foregroundColor(quote.change >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
            }
        }
        .padding()
        .background(Color.clear)
    }
}
