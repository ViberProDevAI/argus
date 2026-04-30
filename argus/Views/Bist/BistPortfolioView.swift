import SwiftUI

// MARK: - BIST Portfolio View (Refactored to use main PortfolioEngine)
// MARK: - BIST Portfolio View (Refactored to use main PortfolioStore)
// Artık TradingViewModel ve PortfolioStore kullanıyor

struct BistPortfolioView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @State private var showSearch = false
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // BIST trades from PortfolioStore
    var bistTrades: [Trade] {
        PortfolioStore.shared.bistOpenTrades
    }
    
    var bistBalance: Double {
        PortfolioStore.shared.bistBalance
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ArgusNavHeader(
                    title: "BIST PORTFÖY",
                    subtitle: "NAKİT · HİSSE · OTOPİLOT",
                    leadingDeco: .bars3([.holo, .text, .text]),
                    actions: [
                        .menu({ showDrawer = true }),
                        .plus({ showSearch = true })
                    ]
                )
                ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Balance Card (V5)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            MotorLogo(.aether, size: 14)
                            ArgusSectionCaption("BIST DEĞERİ")
                            Spacer()
                            ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 5)
                            Text("TL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }

                        Text("₺\(String(format: "%.2f", bistBalance + portfolioValue))")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        ArgusHair()

                        HStack(spacing: 8) {
                            v5StatTile(title: "NAKİT",
                                       value: "₺\(String(format: "%.2f", bistBalance))",
                                       tone: InstitutionalTheme.Colors.textPrimary)
                            v5StatTile(title: "HİSSE DEĞERİ",
                                       value: "₺\(String(format: "%.2f", portfolioValue))",
                                       tone: InstitutionalTheme.Colors.Motors.aether)
                        }

                        ArgusHair()

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ARGUS BIST YÖNETİCİSİ")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                Text(viewModel.isAutoPilotEnabled
                                     ? "Aktif · Piyasa taranıyor"
                                     : "Pasif · Manuel mod")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(viewModel.isAutoPilotEnabled
                                                     ? InstitutionalTheme.Colors.aurora
                                                     : InstitutionalTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.isAutoPilotEnabled)
                                .labelsHidden()
                                .tint(InstitutionalTheme.Colors.aurora)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(InstitutionalTheme.Colors.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
                    .padding(.horizontal)
                    
                    // MARK: - Portfolio List (V5)
                    if bistTrades.isEmpty {
                        VStack(spacing: 18) {
                            ArgusOrb(size: 80,
                                     ringColor: InstitutionalTheme.Colors.Motors.aether,
                                     glowColor: nil) {
                                Image(systemName: "case.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                            }
                            VStack(spacing: 4) {
                                Text("PORTFÖYÜN BOŞ")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text("BIST hisseleri ekleyerek başla.")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            Button(action: { showSearch = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("HİSSE EKLE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                }
                                .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                        .fill(InstitutionalTheme.Colors.Motors.aether.opacity(0.14))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                        .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(bistTrades) { trade in
                                UnifiedPositionCard(
                                    trade: trade,
                                    currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice,
                                    market: .bist,
                                    onEdit: {
                                        // Plan düzenleme sayfasına git (TODO)
                                        print("Edit plan for \(trade.symbol)")
                                    },
                                    onSell: {
                                        // Satış işlemi (TODO)
                                        print("Sell \(trade.symbol)")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                }
            }
            .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearch) {
                BistMarketView()
                    .environmentObject(viewModel)
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
    
    // Computed
    var portfolioValue: Double {
        bistTrades.reduce(0) { total, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return total + (trade.quantity * price)
        }
    }

    /// V5 stat tile — NAKİT / HİSSE DEĞERİ karşılaştırması
    private func v5StatTile(title: String, value: String, tone: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
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
                title: "BIST portföyü",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Hisse Ekle", subtitle: "BIST hissesi ekle", icon: "plus.circle") {
                        showSearch = true
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

// MARK: - Subviews
// MARK: - Subviews Removed (Replaced by UnifiedPositionCard)

