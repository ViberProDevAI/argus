import Foundation

// MARK: - Event Calendar Service
/// Kritik finansal olayları takip eden takvim servisi

class EventCalendarService {
    static let shared = EventCalendarService()
    
    // MARK: - Event Types
    
    enum EventType: String, Codable {
        case earnings = "BİLANÇO"
        case dividend = "TEMETTÜ"
        case fedMeeting = "FED"
        case splitExDate = "BÖLÜNME"
        case ipoLockup = "HALKA ARZ KİLİT"
        case custom = "ÖZEL"
        
        var emoji: String {
            switch self {
            case .earnings: return "📊"
            case .dividend: return "💰"
            case .fedMeeting: return "🏛️"
            case .splitExDate: return "✂️"
            case .ipoLockup: return "🔓"
            case .custom: return "📌"
            }
        }
        
        var riskLevel: RiskLevel {
            switch self {
            case .earnings: return .high
            case .fedMeeting: return .high
            case .dividend: return .low
            case .splitExDate: return .medium
            case .ipoLockup: return .high
            case .custom: return .medium
            }
        }
    }
    
    enum RiskLevel: String, Codable {
        case low = "DÜŞÜK"
        case medium = "ORTA"
        case high = "YÜKSEK"
    }
    
    struct MarketEvent: Codable, Identifiable {
        let id: UUID
        let symbol: String?         // nil = market-wide event (Fed)
        let type: EventType
        let date: Date
        let title: String
        let description: String?
        let isConfirmed: Bool       // Kesin tarih mi?
        
        init(symbol: String?, type: EventType, date: Date, title: String, description: String? = nil, isConfirmed: Bool = true) {
            self.id = UUID()
            self.symbol = symbol
            self.type = type
            self.date = date
            self.title = title
            self.description = description
            self.isConfirmed = isConfirmed
        }
    }
    
    // MARK: - Storage
    
    private var events: [MarketEvent] = []
    private let persistenceKey = "ArgusEventCalendar"
    
    private init() {
        loadEvents()
        addDefaultFedMeetings()
    }
    
    // MARK: - Public API
    
    /// Yaklaşan olayları getir
    func getUpcomingEvents(for symbol: String? = nil, days: Int = 7) -> [MarketEvent] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now)!
        
        return events.filter { event in
            // Tarih kontrolü
            guard event.date >= now && event.date <= futureDate else { return false }
            
            // Sembol kontrolü
            if let targetSymbol = symbol {
                // Sembol bazlı veya market-wide olay
                return event.symbol == nil || event.symbol == targetSymbol
            }
            
            return true
        }.sorted { $0.date < $1.date }
    }
    
    /// Sembol için kritik olay var mı?
    func hasCriticalEvent(for symbol: String, withinDays days: Int = 3) -> (hasEvent: Bool, event: MarketEvent?) {
        let upcoming = getUpcomingEvents(for: symbol, days: days)
        
        // Yüksek riskli olay var mı?
        if let critical = upcoming.first(where: { $0.type.riskLevel == .high }) {
            return (true, critical)
        }
        
        return (false, nil)
    }
    
    /// Bilanço tarihi kontrol
    func hasEarningsWithin(symbol: String, days: Int = 5) -> (hasEarnings: Bool, date: Date?) {
        let upcoming = getUpcomingEvents(for: symbol, days: days)
        
        if let earnings = upcoming.first(where: { $0.type == .earnings }) {
            return (true, earnings.date)
        }
        
        return (false, nil)
    }
    
    /// Olay ekle
    func addEvent(_ event: MarketEvent) {
        // Duplicate kontrolü
        let isDuplicate = events.contains { existing in
            existing.symbol == event.symbol &&
            existing.type == event.type &&
            Calendar.current.isDate(existing.date, inSameDayAs: event.date)
        }
        
        guard !isDuplicate else { return }
        
        events.append(event)
        saveEvents()
    }
    
    /// Bilanço tarihi ekle (kolay API)
    func addEarningsDate(symbol: String, date: Date, isConfirmed: Bool = true) {
        let event = MarketEvent(
            symbol: symbol,
            type: .earnings,
            date: date,
            title: "\(symbol) Bilanço Açıklaması",
            description: isConfirmed ? "Kesin tarih" : "Tahmini tarih",
            isConfirmed: isConfirmed
        )
        addEvent(event)
    }
    
    /// Temettü tarihi ekle
    func addDividendDate(symbol: String, exDate: Date, amount: Double? = nil) {
        let desc = amount != nil ? "Temettü: $\(String(format: "%.2f", amount!))" : nil
        let event = MarketEvent(
            symbol: symbol,
            type: .dividend,
            date: exDate,
            title: "\(symbol) Temettü Ex-Tarihi",
            description: desc,
            isConfirmed: true
        )
        addEvent(event)
    }
    
    // MARK: - Risk Assessment
    
    struct EventRiskAssessment {
        let shouldAvoidNewPosition: Bool
        let shouldReducePosition: Bool
        let warnings: [String]
        let upcomingEvents: [MarketEvent]
    }
    
    /// Pozisyon riski değerlendirmesi
    func assessPositionRisk(symbol: String) -> EventRiskAssessment {
        var warnings: [String] = []
        var shouldAvoid = false
        var shouldReduce = false
        
        let upcoming = getUpcomingEvents(for: symbol, days: 7)
        
        // Bilanço kontrolü
        let earnings = hasEarningsWithin(symbol: symbol, days: 3)
        if earnings.hasEarnings, let date = earnings.date {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            
            if daysUntil <= 1 {
                shouldAvoid = true
                shouldReduce = true
                warnings.append("⚠️ Bilanço yarın/bugün! Yeni pozisyon açmayın.")
            } else if daysUntil <= 3 {
                shouldAvoid = true
                warnings.append("📊 Bilanço \(daysUntil) gün içinde. Dikkatli olun.")
            }
        }
        
        // Fed kontrolü
        let fedEvents = upcoming.filter { $0.type == .fedMeeting }
        if let fed = fedEvents.first {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: fed.date).day ?? 0
            if daysUntil <= 1 {
                warnings.append("🏛️ Fed toplantısı yarın/bugün. Volatilite artabilir.")
            }
        }
        
        return EventRiskAssessment(
            shouldAvoidNewPosition: shouldAvoid,
            shouldReducePosition: shouldReduce,
            warnings: warnings,
            upcomingEvents: upcoming
        )
    }
    
    // MARK: - Default Fed Meetings (2026)
    
    private func addDefaultFedMeetings() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let fedDates = [
            "2026-01-28", "2026-01-29",
            "2026-03-17", "2026-03-18",
            "2026-04-28", "2026-04-29",
            "2026-06-09", "2026-06-10",
            "2026-07-28", "2026-07-29",
            "2026-09-15", "2026-09-16",
            "2026-11-03", "2026-11-04",
            "2026-12-15", "2026-12-16"
        ]
        
        for dateStr in fedDates {
            if let date = formatter.date(from: dateStr) {
                let event = MarketEvent(
                    symbol: nil,
                    type: .fedMeeting,
                    date: date,
                    title: "FOMC Toplantısı",
                    description: "Federal Reserve faiz kararı",
                    isConfirmed: true
                )
                
                // Duplicate kontrolü ile ekle
                let exists = events.contains { e in
                    e.type == .fedMeeting && Calendar.current.isDate(e.date, inSameDayAs: date)
                }
                if !exists {
                    events.append(event)
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ Event kaydetme hatası: \(error)")
        }
    }
    
    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            events = try JSONDecoder().decode([MarketEvent].self, from: data)
            print("📅 \(events.count) olay yüklendi")
        } catch {
            print("❌ Event yükleme hatası: \(error)")
        }
    }
    
    // MARK: - Debug
    
    func printUpcomingEvents(days: Int = 7) {
        let upcoming = getUpcomingEvents(days: days)
        
        print("═══════════════════════════════════════")
        print("📅 YAKLAŞAN OLAYLAR (\(days) gün)")
        print("═══════════════════════════════════════")
        
        if upcoming.isEmpty {
            print("Yaklaşan olay yok.")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM"
            
            for event in upcoming {
                let dateStr = formatter.string(from: event.date)
                let symbolStr = event.symbol ?? "MARKET"
                print("\(event.type.emoji) [\(dateStr)] \(symbolStr): \(event.title)")
            }
        }
        print("═══════════════════════════════════════")
    }
}
