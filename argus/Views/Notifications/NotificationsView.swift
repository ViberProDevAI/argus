import SwiftUI

struct NotificationsView: View {
    @ObservedObject var store = NotificationStore.shared
    @State private var selectedNotification: ArgusNotification?
    @ObservedObject var viewModel: TradingViewModel // Needed for execution
    var deepLinkID: String? = nil // Deep Link Parameter
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if store.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.textSecondary)
                        Text("Henüz bildirim yok.")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        Text("Argus gözcüsü arka planda fırsat arıyor.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
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
                        // Delay slightly to ensure view is ready
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
                            .foregroundColor(.white)
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

// MARK: - Row Component
struct NotificationRow: View {
    let notification: ArgusNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type == .buyOpportunity ? Theme.positive.opacity(0.2) : (notification.type == .sellWarning ? Theme.negative.opacity(0.2) : Color.blue.opacity(0.2)))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName(for: notification.type))
                    .foregroundColor(notification.type == .buyOpportunity ? Theme.positive : (notification.type == .sellWarning ? Theme.negative : Color.blue))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.headline)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.summary)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                
                Text(notification.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(notification.isRead ? Theme.background : Theme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 0.5)
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

// MARK: - Detail Sheet (Persuasion Engine UI)
struct ArgusReportDetailView: View {
    let notification: ArgusNotification
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    CompanyLogoView(symbol: notification.symbol, size: 48)
                    VStack(alignment: .leading) {
                        Text(notification.symbol)
                            .font(.title)
                            .bold()
                        Text(notification.timestamp.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom)
                
                // Report Content (Markdown Rendering)
                Text(LocalizedStringKey(notification.detailedReport))
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(.all, 12)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                
                Spacer(minLength: 40)
                
                // ACTION BUTTON (The "Uygula" Button)
                if notification.type == .buyOpportunity || notification.type == .sellWarning {
                    Button(action: {
                        executeAction()
                    }) {
                        HStack {
                            Image(systemName: notification.type == .buyOpportunity ? "bolt.fill" : "xmark.circle.fill")
                            Text(notification.type == .buyOpportunity ? "Sinyali Uygula: 1000$ AL" : "Sinyali Uygula: SAT")
                                .font(.headline)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(notification.type == .buyOpportunity ? Theme.positive : Theme.negative)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
    }
    
    private func executeAction() {
        if notification.type == .buyOpportunity {
            // Fetch current price safely?
            // Since we are in Report view, we might not have live price, but ViewModel has quotes
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
