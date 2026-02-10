import Foundation

enum MarketStatus {
    case open
    case closed(reason: String)
    case preMarket
    case afterHours
}

enum MarketType {
    case global
    case bist
}

class MarketStatusService {
    static let shared = MarketStatusService()
    
    private let calendar = Calendar(identifier: .gregorian)
    private let usTimeZone = TimeZone(identifier: "America/New_York")!
    private let trTimeZone = TimeZone(identifier: "Europe/Istanbul")!
    
    // US Market Hours (ET)
    private let marketOpenHour = 9
    private let marketOpenMinute = 30
    private let marketCloseHour = 16
    private let marketCloseMinute = 0
    
    // BIST Market Hours (TR Time)
    private let bistOpenHour = 10
    private let bistOpenMinute = 0
    private let bistCloseHour = 18
    private let bistCloseMinute = 10
    
    // MARK: - US Market Status
    func getMarketStatus() -> MarketStatus {
        let now = Date()

        // 1. Check Weekend — haftasonu kapalı
        if isWeekend(now, timeZone: usTimeZone) {
            return .closed(reason: "Haftasonu")
        }

        // 2. Hafta içi — ABD piyasası her zaman açık (premarket + afterhours dahil)
        // Eğitici uygulama: kullanıcılar istedikleri zaman işlem yapabilmeli
        let components = calendar.dateComponents(in: usTimeZone, from: now)
        guard let hour = components.hour, let minute = components.minute else {
            return .closed(reason: "Zaman Hatası")
        }

        let currentMinutes = hour * 60 + minute
        let openMinutes = marketOpenHour * 60 + marketOpenMinute
        let closeMinutes = marketCloseHour * 60 + marketCloseMinute

        if currentMinutes >= openMinutes && currentMinutes < closeMinutes {
            return .open
        } else if currentMinutes >= (4 * 60) && currentMinutes < openMinutes {
            return .preMarket
        } else {
            return .afterHours // Hafta içi gece dahil açık
        }
    }
    
    // MARK: - BIST Market Status
    func getBistMarketStatus() -> MarketStatus {
        let now = Date()
        
        // 1. Check Weekend (Turkey time)
        if isWeekend(now, timeZone: trTimeZone) {
            return .closed(reason: "Haftasonu")
        }
        
        // 2. Check Time in Istanbul
        let components = calendar.dateComponents(in: trTimeZone, from: now)
        guard let hour = components.hour, let minute = components.minute else {
            return .closed(reason: "Zaman Hatası")
        }
        
        let currentMinutes = hour * 60 + minute
        let openMinutes = bistOpenHour * 60 + bistOpenMinute
        let closeMinutes = bistCloseHour * 60 + bistCloseMinute
        
        if currentMinutes < openMinutes {
            return .closed(reason: "BIST Açılmadı")
        } else if currentMinutes >= closeMinutes {
            return .closed(reason: "BIST Kapandı")
        }
        
        return .open
    }
    
    // MARK: - Unified Trade Check
    func canTrade() -> Bool {
        // Legacy: US Market only
        switch getMarketStatus() {
        case .open, .preMarket, .afterHours: return true
        default: return false
        }
    }
    
    func canTrade(for market: MarketType) -> Bool {
        switch market {
        case .global:
            switch getMarketStatus() {
            case .open, .preMarket, .afterHours: return true
            default: return false
            }
        case .bist:
            switch getBistMarketStatus() {
            case .open: return true
            default: return false
            }
        }
    }
    
    func isBistOpen() -> Bool {
        switch getBistMarketStatus() {
        case .open: return true
        default: return false
        }
    }
    
    private func isWeekend(_ date: Date, timeZone: TimeZone) -> Bool {
        let components = calendar.dateComponents(in: timeZone, from: date)
        // 1 = Sunday, 7 = Saturday
        return components.weekday == 1 || components.weekday == 7
    }
    
    // Formatted Time for UI
    func getNYTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = usTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    func getIstanbulTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = trTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
