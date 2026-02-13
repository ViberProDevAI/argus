import SwiftUI

struct NotificationsView: View {
    @ObservedObject var store = NotificationStore.shared
    @State private var selectedNotification: ArgusNotification?
    @ObservedObject var viewModel: TradingViewModel
    var deepLinkID: String? = nil
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                
                if store.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("Henüz bildirim yok.")
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("Argus gözcüsü arka planda fırsat arıyor.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.notifications) { note in
                                NotificationRow(notification: note)
                                    .onTapGesture {
                                        selectedNotification = note
                                        store.markAsRead(note)
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                if let idString = deepLinkID, let id = UUID(uuidString: idString) {
                    if let note = store.notifications.first(where: { $0.id == id }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedNotification = note
                            store.markAsRead(note)
                        }
                    }
                }
            }
            .navigationTitle("Argus Gelen Kutusu")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.notifications.isEmpty {
                        Button("Tümünü Oku") {
                            store.markAllRead()
                        }
                    }
                }
            }
            .sheet(item: $selectedNotification) { note in
                ArgusReportDetailView(notification: note, viewModel: viewModel)
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
                title: "BILDIRIMLER",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Tumunu Oku", subtitle: "Tum bildirimleri temizle", icon: "checkmark.circle") {
                        store.markAllRead()
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

struct NotificationRow: View {
    let notification: ArgusNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(notification.type == .buyOpportunity ? InstitutionalTheme.Colors.positive.opacity(0.2) : (notification.type == .sellWarning ? InstitutionalTheme.Colors.negative.opacity(0.2) : InstitutionalTheme.Colors.primary.opacity(0.2)))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName(for: notification.type))
                    .foregroundColor(notification.type == .buyOpportunity ? InstitutionalTheme.Colors.positive : (notification.type == .sellWarning ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.primary))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.headline)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(InstitutionalTheme.Colors.negative)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.summary)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                Text(notification.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(notification.isRead ? InstitutionalTheme.Colors.background : InstitutionalTheme.Colors.surface1)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
    
    func iconName(for type: ArgusNotification.NotificationType) -> String {
        switch type {
        case .buyOpportunity: return "arrow.up.right.circle.fill"
        case .sellWarning: return "exclamationmark.triangle.fill"
        case .marketUpdate: return "chart.bar.doc.horizontal"
        case .tradeExecuted: return "checkmark.circle.fill"
        case .positionClosed: return "xmark.circle.fill"
        case .alert: return "bell.fill"
        case .dailyReport: return "doc.text.fill"
        case .weeklyReport: return "calendar.badge.checkmark"
        }
    }
}

struct ArgusReportDetailView: View {
    let notification: ArgusNotification
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CompanyLogoView(symbol: notification.symbol, size: 48)
                    VStack(alignment: .leading) {
                        Text(notification.symbol)
                            .font(InstitutionalTheme.Typography.title)
                            .bold()
                        Text(notification.timestamp.formatted())
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .padding(.bottom)
                
                Text(LocalizedStringKey(notification.detailedReport))
                    .font(InstitutionalTheme.Typography.body)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .institutionalCard(scale: .standard, elevated: false)
                
                Spacer(minLength: 40)
                
                if notification.type == .buyOpportunity || notification.type == .sellWarning {
                    Button(action: {
                        executeAction()
                    }) {
                        HStack {
                            Image(systemName: notification.type == .buyOpportunity ? "bolt.fill" : "xmark.circle.fill")
                            Text(notification.type == .buyOpportunity ? "Sinyali Uygula: 1000$ AL" : "Sinyali Uygula: SAT")
                                .font(InstitutionalTheme.Typography.bodyStrong)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(notification.type == .buyOpportunity ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                }
            }
            .padding()
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
    }
    
    private func executeAction() {
        if notification.type == .buyOpportunity {
            if let quote = viewModel.quotes[notification.symbol] {
                let price = quote.currentPrice
                if price > 0 {
                    let qty = 1000.0 / price
                    viewModel.buy(symbol: notification.symbol, quantity: qty, source: .autoPilot, rationale: "Argus Raporu Onayı (\(notification.headline))")
                }
            }
        } else if notification.type == .sellWarning {
            viewModel.closeAllPositions(for: notification.symbol)
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}
