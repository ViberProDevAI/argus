import SwiftUI

/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (bars3 holo deco,
/// menu + checkmark action, okunmamış sayısı status satırında). Row stili ve
/// sheet akışı (ArgusReportDetailView) korunur; `NotificationStore.shared`
/// veri imzası aynı.
struct NotificationsView: View {
    @ObservedObject var store = NotificationStore.shared
    @State private var selectedNotification: ArgusNotification?
    @ObservedObject var viewModel: TradingViewModel
    var deepLinkID: String? = nil
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @State private var showDrawer = false

    private var unreadCount: Int {
        store.notifications.filter { !$0.isRead }.count
    }

    private var headerActions: [ArgusNavHeader.Action] {
        var list: [ArgusNavHeader.Action] = [.menu({ showDrawer = true })]
        if !store.notifications.isEmpty {
            list.append(.custom(sfSymbol: "checkmark.circle",
                                action: { store.markAllRead() }))
        }
        return list
    }

    private var headerStatus: ArgusNavHeader.Status {
        if store.notifications.isEmpty {
            return .custom(dotColor: InstitutionalTheme.Colors.textTertiary,
                           label: "GÖZCÜ HAZIR",
                           trailing: "SİNYAL BEKLENİYOR")
        }
        if unreadCount == 0 {
            return .custom(dotColor: InstitutionalTheme.Colors.aurora,
                           label: "TÜM RAPORLAR OKUNDU",
                           trailing: "\(store.notifications.count) KAYIT")
        }
        return .custom(dotColor: InstitutionalTheme.Colors.crimson,
                       label: "\(unreadCount) OKUNMAMIŞ",
                       trailing: "\(store.notifications.count) KAYIT")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "GELEN KUTUSU",
                        subtitle: "SİNYAL · UYARI · RAPOR",
                        leadingDeco: .bars3([.holo, .text, .text]),
                        actions: headerActions,
                        status: headerStatus
                    )

                    if store.notifications.isEmpty {
                        Spacer()
                        VStack(spacing: 18) {
                            ArgusOrb(size: 80,
                                     ringColor: InstitutionalTheme.Colors.border,
                                     glowColor: nil) {
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 30))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            VStack(spacing: 4) {
                                Text("HENÜZ BİLDİRİM YOK")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text("Argus gözcüsü arka planda fırsat arıyor.")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        Spacer()
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
            .navigationBarHidden(true)
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
                title: "Bildirimler",
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

struct NotificationRow: View {
    let notification: ArgusNotification

    private var tone: ArgusChipTone {
        switch notification.type {
        case .buyOpportunity:  return .aurora
        case .sellWarning:     return .crimson
        case .tradeExecuted:   return .aurora
        case .positionClosed:  return .neutral
        case .alert:           return .titan
        case .marketUpdate:    return .holo
        case .dailyReport,
             .weeklyReport:    return .motor(.alkindus)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tone.foreground.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName(for: notification.type))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tone.foreground)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(notification.headline)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !notification.isRead {
                        ArgusDot(color: InstitutionalTheme.Colors.crimson, size: 7)
                    }
                }

                Text(notification.summary)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ArgusChip(categoryLabel(notification.type), tone: tone)
                    Spacer(minLength: 4)
                    Text(notification.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notification.isRead
                    ? InstitutionalTheme.Colors.background
                    : InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(notification.isRead
                        ? InstitutionalTheme.Colors.border
                        : tone.foreground.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    func iconName(for type: ArgusNotification.NotificationType) -> String {
        switch type {
        case .buyOpportunity: return "arrow.up.right.circle.fill"
        case .sellWarning:    return "exclamationmark.triangle.fill"
        case .marketUpdate:   return "chart.bar.doc.horizontal"
        case .tradeExecuted:  return "checkmark.circle.fill"
        case .positionClosed: return "xmark.circle.fill"
        case .alert:          return "bell.fill"
        case .dailyReport:    return "doc.text.fill"
        case .weeklyReport:   return "calendar.badge.checkmark"
        }
    }

    func categoryLabel(_ type: ArgusNotification.NotificationType) -> String {
        switch type {
        case .buyOpportunity: return "AL FIRSATI"
        case .sellWarning:    return "SAT UYARISI"
        case .marketUpdate:   return "PİYASA"
        case .tradeExecuted:  return "İŞLEM"
        case .positionClosed: return "KAPANIŞ"
        case .alert:          return "UYARI"
        case .dailyReport:    return "GÜNLÜK"
        case .weeklyReport:   return "HAFTALIK"
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
