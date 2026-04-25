import Foundation
import Combine

class NotificationStore: ObservableObject {
    static let shared = NotificationStore()
    
    @Published var notifications: [ArgusNotification] = []
    
    private let persistenceKey = "ArgusNotificationInbox"
    private let throttleKey = "ArgusNotificationThrottle"
    
    // THROTTLE SETTINGS
    private let symbolCooldownMinutes: TimeInterval = 30 // Aynı sembol için 30dk bekle
    private let dailyNotificationLimit: Int = 10 // Günlük maksimum bildirim
    
    // In-memory throttle tracking
    private var lastNotificationTime: [String: Date] = [:] // symbol -> last time
    private var dailyNotificationCount: Int = 0
    private var lastResetDate: Date = Date()
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private init() {
        loadNotifications()
        loadThrottleState()
    }
    
    // MARK: - Add Notification (Push only for Reports)
    func addNotification(_ notification: ArgusNotification) {
        DispatchQueue.main.async {
            // Her zaman store'a ekle
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
            
            // Push bildirim SADECE rapor tipleri için gönderilir
            let shouldPush = notification.type == ArgusNotification.NotificationType.dailyReport ||
                             notification.type == ArgusNotification.NotificationType.weeklyReport
            
            if shouldPush {
                NotificationManager.shared.sendNotification(
                    title: notification.headline,
                    body: notification.summary,
                    userInfo: ["notificationId": notification.id.uuidString]
                )
                print("📬 Rapor bildirimi gönderildi: \(notification.headline)")
            } else {
                print("📥 Gelen kutusuna kaydedildi (push yok): \(notification.headline)")
            }
        }
    }
    
    private func addToStoreOnly(_ notification: ArgusNotification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
        }
    }
    
    private func sendNotification(_ notification: ArgusNotification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
            self.dailyNotificationCount += 1
            self.saveThrottleState()
            
            // Push notification
            NotificationManager.shared.sendNotification(
                title: notification.headline,
                body: notification.summary,
                userInfo: ["notificationId": notification.id.uuidString]
            )
        }
    }
    
    // MARK: - Daily Reset
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyNotificationCount = 0
            lastResetDate = Date()
            lastNotificationTime.removeAll()
            saveThrottleState()
        }
    }
    
    // MARK: - Read/Delete
    func markAsRead(_ notification: ArgusNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            DispatchQueue.main.async {
                self.notifications[index].isRead = true
                self.saveNotifications()
            }
        }
    }
    
    func markAllRead() {
        DispatchQueue.main.async {
            for i in 0..<self.notifications.count {
                self.notifications[i].isRead = true
            }
            self.saveNotifications()
        }
    }
    
    func deleteNotification(id: UUID) {
        DispatchQueue.main.async {
            self.notifications.removeAll { $0.id == id }
            self.saveNotifications()
        }
    }
    
    // MARK: - Persistence
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let items = try? JSONDecoder().decode([ArgusNotification].self, from: data) {
            self.notifications = items
        }
    }
    
    private func saveThrottleState() {
        UserDefaults.standard.set(dailyNotificationCount, forKey: "\(throttleKey)_count")
        UserDefaults.standard.set(lastResetDate.timeIntervalSince1970, forKey: "\(throttleKey)_date")
    }
    
    private func loadThrottleState() {
        dailyNotificationCount = UserDefaults.standard.integer(forKey: "\(throttleKey)_count")
        let timestamp = UserDefaults.standard.double(forKey: "\(throttleKey)_date")
        if timestamp > 0 {
            lastResetDate = Date(timeIntervalSince1970: timestamp)
        }
        resetDailyCountIfNeeded()
    }
}

