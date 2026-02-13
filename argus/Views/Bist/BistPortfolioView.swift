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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Balance Card (TL)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Toplam Varlık (TL)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack(alignment: .lastTextBaseline) {
                                    Text("₺")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(String(format: "%.2f", bistBalance + portfolioValue))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                            Image(systemName: "turkishlirasign.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Nakit")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("₺\(String(format: "%.2f", bistBalance))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Hisse Değeri")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("₺\(String(format: "%.2f", portfolioValue))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Argus Auto-Pilot (BIST Mode)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Argus BIST Yöneticisi")
                                    .font(.caption).bold()
                                    .foregroundColor(.white)
                                Text(viewModel.isAutoPilotEnabled ? "Aktif: Piyasa taranıyor..." : "Pasif: Manuel Mod")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.isAutoPilotEnabled)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Theme.bistAccent.opacity(0.9), Theme.bistSecondary.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: Theme.bistAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // MARK: - Portfolio List
                    if bistTrades.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "case.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Portföyün Boş")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("BIST hisseleri ekleyerek başla.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: { showSearch = true }) {
                                Text("Hisse Ekle")
                                    .bold()
                                    .padding()
                                    .background(Theme.tint)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
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
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("BIST Portföy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                    }
                }
            }
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
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "brain.head.profile") {
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
                title: "BIST PORTFOY",
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

// MARK: - Subviews
// MARK: - Subviews Removed (Replaced by UnifiedPositionCard)
