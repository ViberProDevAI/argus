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

    // O3: BIST sabit tarihli resmi tatiller.
    //
    // Not: Dini bayramlar (Ramazan/Kurban) Hicri takvime bağlı olduğundan
    // yıldan yıla farklı Gregoryen tarihlere denk gelir. Yanlış sabit tarih
    // gömmek susulmuş bir bug yaratır — örneğin 2027'de Ramazan 8 Mart,
    // 2028'de 26 Şubat. Bu nedenle dini bayramlar burada tutulmuyor;
    // gerekirse yıllık güncellenen ayrı bir config (remote JSON ya da
    // Hijri calendar hesabı) ile eklenmeli. Şu an sadece sabit tarihli
    // ulusal bayramları kapatıyoruz — yanlış "açık" raporlamaktansa
    // tanımlı tatilleri en azından doğru kapatmak.
    private struct MonthDay: Hashable {
        let month: Int
        let day: Int
    }

    private let bistFixedHolidays: Set<MonthDay> = [
        MonthDay(month: 1, day: 1),    // Yılbaşı
        MonthDay(month: 4, day: 23),   // Ulusal Egemenlik ve Çocuk Bayramı
        MonthDay(month: 5, day: 1),    // Emek ve Dayanışma Günü
        MonthDay(month: 5, day: 19),   // Atatürk'ü Anma, Gençlik ve Spor Bayramı
        MonthDay(month: 7, day: 15),   // Demokrasi ve Millî Birlik Günü
        MonthDay(month: 8, day: 30),   // Zafer Bayramı
        MonthDay(month: 10, day: 29),  // Cumhuriyet Bayramı
    ]

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

        // 2. Check fixed-date Turkish holidays (Istanbul time)
        if isBistFixedHoliday(now) {
            return .closed(reason: "Resmi Tatil")
        }

        // 3. Check Time in Istanbul
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

    // O3: BIST'in tatil olduğu ay/gün kombinasyonunu Istanbul saatine göre değerlendir.
    // TimeZone kritik — UTC ya da cihaz saatiyle ölçülürse yurt dışından giriş yapan
    // kullanıcıda 29 Ekim gece yarısı hatalı raporlanabilir.
    private func isBistFixedHoliday(_ date: Date) -> Bool {
        let components = calendar.dateComponents(in: trTimeZone, from: date)
        guard let month = components.month, let day = components.day else {
            return false
        }
        return bistFixedHolidays.contains(MonthDay(month: month, day: day))
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
