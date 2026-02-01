import Foundation

// MARK: - Economic Calendar Service
// ABD ekonomik veri açıklama takvimini takip eder
// Yaklaşan verileri tespit eder ve beklenti hatırlatması gönderir

class EconomicCalendarService {
    static let shared = EconomicCalendarService()
    
    private init() {}
    
    // MARK: - Market Calendar (Real Data)
    
    enum CalendarFetchError: Error {
        case missingApiKey
        case invalidResponse
    }
    
    struct CalendarEvent: Identifiable {
        let id = UUID()
        let date: Date
        let title: String
        let country: String?
        let impact: String?
        let actual: String?
        let forecast: String?
        let previous: String?
        let unit: String?
        let source: String
    }
    
    // MARK: - Economic Event Model
    
    struct EconomicEvent: Identifiable {
        let id = UUID()
        let indicator: ExpectationsStore.EconomicIndicator
        let releaseDate: Date
        let displayName: String
        let importance: Importance
        
        enum Importance: String {
            case high = "Yüksek"
            case medium = "Orta"
            case low = "Düşük"
        }
        
        var daysUntilRelease: Int {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let release = calendar.startOfDay(for: releaseDate)
            return calendar.dateComponents([.day], from: today, to: release).day ?? 0
        }
        
        var isToday: Bool { daysUntilRelease == 0 }
        var isTomorrow: Bool { daysUntilRelease == 1 }
        var isThisWeek: Bool { daysUntilRelease >= 0 && daysUntilRelease <= 7 }
    }
    
    // MARK: - Calendar Data (2025 ABD Ekonomik Takvimi)
    
    /// ABD ekonomik verileri için yaklaşık açıklama tarihleri
    /// Gerçek takvim her ay güncellenir
    private func getCalendarEvents() -> [EconomicEvent] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        var events: [EconomicEvent] = []
        
        // CPI: Genellikle ayın 10-15'i arası (Çarşamba)
        if let cpiDate = createDate(year: year, month: month, day: 12) {
            events.append(EconomicEvent(
                indicator: .cpi,
                releaseDate: cpiDate,
                displayName: "CPI Enflasyon Verisi",
                importance: .high
            ))
        }
        
        // İşsizlik + Payrolls: Ayın ilk Cuma günü
        if let jobsDate = getFirstFriday(year: year, month: month) {
            events.append(EconomicEvent(
                indicator: .unemployment,
                releaseDate: jobsDate,
                displayName: "İşsizlik Oranı",
                importance: .high
            ))
            events.append(EconomicEvent(
                indicator: .payrolls,
                releaseDate: jobsDate,
                displayName: "Tarım Dışı İstihdam (NFP)",
                importance: .high
            ))
        }
        
        // Initial Claims: Her Perşembe
        if let claimsDate = getNextThursday(from: now) {
            events.append(EconomicEvent(
                indicator: .claims,
                releaseDate: claimsDate,
                displayName: "Haftalık İşsizlik Başvuruları",
                importance: .medium
            ))
        }
        
        // PCE: Ayın son haftası
        if let pceDate = createDate(year: year, month: month, day: 28) {
            events.append(EconomicEvent(
                indicator: .pce,
                releaseDate: pceDate,
                displayName: "PCE Enflasyonu",
                importance: .high
            ))
        }
        
        // GDP: Çeyrek sonu (Mart, Haziran, Eylül, Aralık)
        if [3, 6, 9, 12].contains(month) {
            if let gdpDate = createDate(year: year, month: month, day: 25) {
                events.append(EconomicEvent(
                    indicator: .gdp,
                    releaseDate: gdpDate,
                    displayName: "GSYİH Büyümesi",
                    importance: .high
                ))
            }
        }
        
        // Sonraki ay için de ekle (hafta içinde ise)
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        
        if let nextCpi = createDate(year: nextYear, month: nextMonth, day: 12) {
            events.append(EconomicEvent(
                indicator: .cpi,
                releaseDate: nextCpi,
                displayName: "CPI Enflasyon Verisi",
                importance: .high
            ))
        }
        
        return events.sorted { $0.releaseDate < $1.releaseDate }
    }
    
    // MARK: - Public API
    
    /// Yaklaşan ekonomik olayları döndürür
    func getUpcomingEvents(withinDays days: Int = 7) -> [EconomicEvent] {
        return getCalendarEvents().filter { event in
            event.daysUntilRelease >= 0 && event.daysUntilRelease <= days
        }
    }
    
    /// Yarın veya bugün açıklanacak verileri döndürür
    func getImmediateEvents() -> [EconomicEvent] {
        return getCalendarEvents().filter { $0.isToday || $0.isTomorrow }
    }
    
    /// Eksik beklentileri kontrol et ve bildirim gönder
    @MainActor
    func checkAndNotifyMissingExpectations() {
        Task {
            do {
                let calendarEvents = try await fetchUpcomingCalendarEvents(days: 2)
                let indicators = calendarEvents.compactMap { mapIndicator(from: $0.title) }
                for indicator in indicators {
                    if ExpectationsStore.shared.getExpectation(for: indicator) == nil {
                        sendMissingExpectationNotification(for: indicator)
                    }
                }
            } catch {
                // Gercek veri cekilemediyse bildirim gonderme
            }
        }
    }
    
    @MainActor
    private func sendMissingExpectationNotification(for indicator: ExpectationsStore.EconomicIndicator) {
        let timeStr = "Yakinda"
        
        let notification = ArgusNotification(
            symbol: "AETHER",
            headline: "\(timeStr) \(indicator.displayName) Açıklanıyor",
            summary: "Henüz beklenti girmediniz. Sürpriz etkisini yakalamak için şimdi girin.",
            detailedReport: """
            ## Ekonomik Veri Hatırlatması
            
            **\(indicator.displayName)** \(timeStr.lowercased()) açıklanacak.
            
            ### Neden Önemli?
            Beklenti girdiğinizde, gerçekleşen veri ile karşılaştırılır ve sürpriz etkisi Aether skoruna yansır.
            
            - Pozitif sürpriz = Puan artışı
            - Negatif sürpriz = Puan düşüşü
            
            ### Nasıl Girilir?
            1. Aether detay sayfasına gidin
            2. "Beklentiler" bölümünü açın
            3. **\(indicator.displayName)** için tahmininizi girin
            
            **İpucu**: Bloomberg, Investing.com veya Trading Economics'ten konsensüs beklentisini bulabilirsiniz.
            """,
            score: 0,
            type: .alert
        )
        
        // Aynı bildirim zaten varsa tekrar gönderme
        let isDuplicate = NotificationStore.shared.notifications.contains { existing in
            existing.headline == notification.headline &&
            Calendar.current.isDateInToday(existing.timestamp)
        }
        
        if !isDuplicate {
            NotificationStore.shared.addNotification(notification)
            print("[AETHER] Beklenti hatırlatması gönderildi - \(indicator.displayName)")
        }
    }

    private func mapIndicator(from title: String) -> ExpectationsStore.EconomicIndicator? {
        let normalized = title.lowercased()
        if normalized.contains("cpi") || normalized.contains("enflasyon") {
            return .cpi
        }
        if normalized.contains("unemployment") || normalized.contains("işsizlik") || normalized.contains("issizlik") {
            return .unemployment
        }
        if normalized.contains("nonfarm") || normalized.contains("payroll") || normalized.contains("istihdam") {
            return .payrolls
        }
        if normalized.contains("jobless") || normalized.contains("claims") || normalized.contains("basvuru") {
            return .claims
        }
        if normalized.contains("pce") {
            return .pce
        }
        if normalized.contains("gdp") || normalized.contains("gsyih") {
            return .gdp
        }
        return nil
    }
    
    // MARK: - External Calendar Fetch (FMP)
    
    func fetchUpcomingCalendarEvents(days: Int = 14) async throws -> [CalendarEvent] {
        let apiKey = APIKeyStore.shared.getKey(for: .fmp) ?? ""
        guard !apiKey.isEmpty else {
            throw CalendarFetchError.missingApiKey
        }
        
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: days, to: now) else {
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let fromStr = dateFormatter.string(from: now)
        let toStr = dateFormatter.string(from: endDate)
        
        var components = URLComponents(string: "https://financialmodelingprep.com/stable/economic-calendar")
        components?.queryItems = [
            URLQueryItem(name: "from", value: fromStr),
            URLQueryItem(name: "to", value: toStr),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        guard let url = components?.url else { throw CalendarFetchError.invalidResponse }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CalendarFetchError.invalidResponse
        }
        
        guard let rawArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CalendarFetchError.invalidResponse
        }
        
        let events: [CalendarEvent] = rawArray.compactMap { item in
            guard let title = stringValue(item["event"]) ?? stringValue(item["title"]) ?? stringValue(item["indicator"]) else {
                return nil
            }
            let dateString = stringValue(item["date"]) ?? stringValue(item["datetime"]) ?? stringValue(item["releaseDate"])
            guard let date = parseCalendarDate(dateString) else { return nil }
            
            return CalendarEvent(
                date: date,
                title: title,
                country: stringValue(item["country"]) ?? stringValue(item["countryCode"]),
                impact: stringValue(item["impact"]) ?? stringValue(item["importance"]),
                actual: stringValue(item["actual"]),
                forecast: stringValue(item["forecast"]),
                previous: stringValue(item["previous"]),
                unit: stringValue(item["unit"]),
                source: "FMP"
            )
        }
        
        return events.sorted { $0.date < $1.date }
    }
    
    private func parseCalendarDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }
        
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: value) {
                return date
            }
        }
        
        return nil
    }
    
    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let str as String:
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        case let num as NSNumber:
            return num.stringValue
        default:
            return nil
        }
    }
    
    // MARK: - Date Helpers
    
    private func createDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 15 // ABD saati varsayımı
        components.minute = 30
        return Calendar.current.date(from: components)
    }
    
    private func getFirstFriday(year: Int, month: Int) -> Date? {
        guard let firstDay = createDate(year: year, month: month, day: 1) else { return nil }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: firstDay)
        
        // Cuma = 6 (1=Pazar, 7=Cumartesi)
        var daysToAdd = (6 - weekday + 7) % 7
        if daysToAdd == 0 { daysToAdd = 0 } // İlk gün Cuma ise
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: firstDay)
    }
    
    private func getNextThursday(from date: Date) -> Date? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Perşembe = 5
        var daysToAdd = (5 - weekday + 7) % 7
        if daysToAdd == 0 { daysToAdd = 7 } // Bugün Perşembe ise gelecek Perşembe
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
}
