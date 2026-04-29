import SwiftUI

/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (bars3 deco +
/// menu/refresh action). Yükselenler/Düşenler/En Hareketliler bölümleri ve
/// card/row bileşenleri zaten V5 tokenize olduğundan korunur.
/// Veri imzası değişmez: `viewModel.topGainers/topLosers/mostActive` +
/// `viewModel.loadDiscoverData()`; drawer + deep link akışı dokunulmadı.
struct DiscoverView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false

    // Grid adaptation for horizontal scroll if needed, but HStacks work better for single row carousels.

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "KEŞFET",
                        subtitle: "MOMENTUM · DİBE VURAN · HACİM",
                        leadingDeco: .bars3([.holo, .text, .text]),
                        actions: [
                            .menu({ showDrawer = true }),
                            .custom(sfSymbol: "arrow.clockwise",
                                    action: { viewModel.loadDiscoverData() })
                        ]
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {

                        // MARK: - 1. Top Gainers (Momentum)
                        VStack(alignment: .leading, spacing: 16) {
                            DiscoverSectionHeader(title: "Yükselenler", subtitle: "Günün momentum liderleri")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.topGainers, id: \.symbol) { quote in
                                        NavigationLink(destination: ArgusSanctumView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
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
                                        NavigationLink(destination: ArgusSanctumView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
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
                                    NavigationLink(destination: ArgusSanctumView(symbol: quote.symbol ?? "---", viewModel: viewModel)) {
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
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
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
            ArgusSectionCaption(title)
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

    var tone: ArgusChipTone {
        type == .gainer ? .aurora : .crimson
    }
    var cardColor: Color { tone.foreground }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: type == .gainer ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(cardColor)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(cardColor.opacity(0.18)))
                Spacer()
                Text(String(format: "%+.2f%%", quote.percentChange))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(cardColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(cardColor.opacity(0.18))
                    )
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(quote.symbol ?? "---")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.2f" : "$%.2f", quote.currentPrice))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 142, height: 112)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(cardColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
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
        let changeColor: Color = quote.change >= 0
            ? InstitutionalTheme.Colors.aurora
            : InstitutionalTheme.Colors.crimson

        return HStack(spacing: 14) {
            // 2026-04-22 logo-fix-4: Dairesel CompanyLogoView kullan —
            // gradient fallback onun içinde; logo gelirse üstüne oturur.
            CompanyLogoView(symbol: quote.symbol ?? "?", size: 36, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(quote.symbol ?? "---")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                if let name = quote.shortName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                let isBist = (quote.symbol ?? "").uppercased().hasSuffix(".IS")
                Text(String(format: isBist ? "₺%.2f" : "$%.2f", quote.currentPrice))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Text(String(format: "%+.2f%%", quote.percentChange))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(changeColor.opacity(0.18))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(ArgusHair(), alignment: .bottom)
        .contentShape(Rectangle())
    }
}
