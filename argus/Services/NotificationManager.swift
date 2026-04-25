import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleDailyMarketNotifications() {
        // Remove existing to avoid duplicates
        removeAllPendingNotifications()
        
        let center = UNUserNotificationCenter.current()
        
        // 1. Market Open (+10 min) -> Approx 16:40 TR Time
        var dateComponentsOpen = DateComponents()
        dateComponentsOpen.hour = 16
        dateComponentsOpen.minute = 40
        
        let triggerOpen = UNCalendarNotificationTrigger(dateMatching: dateComponentsOpen, repeats: true)
        let contentOpen = UNMutableNotificationContent()
        contentOpen.title = "Argus Orion Güncellemesi"
        contentOpen.body = "ABD seansı açıldı. Aether ve Orion skorlarını güncellemek için dokun."
        contentOpen.sound = .default
        
        let requestOpen = UNNotificationRequest(identifier: "market_open_notification", content: contentOpen, trigger: triggerOpen)
        center.add(requestOpen)
        
        // 2. Market Close (+10 min) -> Approx 23:10 TR Time
        var dateComponentsClose = DateComponents()
        dateComponentsClose.hour = 23
        dateComponentsClose.minute = 10
        
        let triggerClose = UNCalendarNotificationTrigger(dateMatching: dateComponentsClose, repeats: true)
        let contentClose = UNMutableNotificationContent()
        contentClose.title = "Argus Orion Güncellemesi"
        contentClose.body = "ABD seansı kapandı. Gün sonu Aether ve Orion rejimini kontrol et."
        contentClose.sound = .default
        
        let requestClose = UNNotificationRequest(identifier: "market_close_notification", content: contentClose, trigger: triggerClose)
        center.add(requestClose)
        
        print("🔔 Daily market notifications scheduled (16:40 & 23:10)")
    }
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func rescheduleAll() {
        let isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        
        if isEnabled {
            scheduleDailyMarketNotifications()
        } else {
            removeAllPendingNotifications()
        }
    }
    
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.requestAuthorization()
            } else if settings.authorizationStatus == .authorized {
                self.rescheduleAll()
            }
        }
    }

    func sendNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendSignalNotification(symbol: String, signal: String, score: Double) {
        // Check if notifications are enabled in Settings (via UserDefaults for quick access)
        let isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 Yeni Sinyal: \(symbol)"
        content.body = "\(signal) Sinyali Tespit Edildi! Skor: \(Int(score))"
        content.sound = .default
        
        // Add a unique ID so notifications don't overwrite each other immediately
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // nil trigger = deliver immediately
        
        UNUserNotificationCenter.current().add(request)
    }
    func sendTradeNotification(transaction: Transaction, trace: AgoraTrace?) {
        let isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard isEnabled else { return }
        
        // Format: "SYMBOL: ALIM approved (Tier X) • Claimant: Y • Itiraz: Z • Risk: Pass"
        let action = transaction.type == .buy ? "ALIM" : "SATIM"
        
        // Derive Tier from SizeR
        var tier = "Standart"
        if let sizeR = trace?.finalDecision.executionPlan?.targetSizeR {
            if sizeR >= 1.0 { tier = "Tier 1 (Banko)" }
            else if sizeR >= 0.5 { tier = "Tier 2 (Standart)" }
            else { tier = "Tier 3 (Spekülatif)" }
        }
        
        // Claimant Name
        let claimant = trace?.debate.claimant?.module.rawValue ?? "AutoPilot"
        
        // Objection Count (Filter for Objectors)
        let objectionCount = trace?.debate.opinions.filter { $0.stance == .object }.count ?? 0
        
        // Risk Status
        let riskStatus = (trace?.riskEvaluation.isApproved == true) ? "Pass" : "VETO"
        
        let title = "\(transaction.symbol): \(action) Onaylandı (\(tier))"
        let body = "Claimant: \(claimant) • İtiraz: \(objectionCount) • Risk: \(riskStatus)"
        
        sendNotification(title: title, body: body)
    }
    
    func sendVetoNotification(symbol: String, reason: String) {
        let isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard isEnabled else { return }
        
        let title = "\(symbol): İşlem Reddedildi (VETO)"
        let body = "Gerekçe: \(reason) • Risk Protokolü Devrede"
        
        sendNotification(title: title, body: body)
    }
    
    func sendReportNotification(type: String) {
        // "Günlük Rapor Hazır"
        sendNotification(title: "📝 Argus \(type) Raporu Hazır", body: "Piyasa analizi ve işlem özetini incelemek için dokun.")
    }
}
