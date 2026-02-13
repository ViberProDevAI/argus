import Foundation

enum EventType: String, Codable, CaseIterable {
    case fed = "FED Toplantisi"
    case earnings = "Kazanc Aciklamasi"
    case dividend = "Temettu"
    case ipo = "Halka Arz"
    case economicData = "Ekonomik Veri"
    case geopolitical = "Jeopolitik Olay"
}

enum ImpactLevel: String, Codable {
    case high = "Yuksek"
    case medium = "Orta"
    case low = "Dusuk"
}

enum ImpactDirection: String, Codable {
    case positive = "Pozitif"
    case negative = "Negatif"
    case neutral = "Notr"
}

struct MarketEvent: Identifiable, Codable {
    let id: String
    let symbol: String
    let eventType: EventType
    let eventDate: Date
    let expectedImpact: ImpactLevel
    let description: String
    
    var daysUntil: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: eventDate).day ?? 0
        if days < 0 { return "Gecti" }
        if days == 0 { return "Bugun" }
        if days == 1 { return "1 gun" }
        return "\(days) gun"
    }
    
    var isUpcoming: Bool {
        eventDate > Date()
    }
}

struct EventDecisionContext: Codable {
    let hasHighImpactEvent: Bool
    let riskScore: Double
    let warnings: [String]
    let eventCount: Int
}

actor EventMemoryService {
    static let shared = EventMemoryService()
    
    private var upcomingEvents: [MarketEvent] = []
    
    private init() {}
    
    func getUpcomingEvents(days: Int = 7) async -> [MarketEvent] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        return upcomingEvents.filter { event in
            event.eventDate <= endDate && event.isUpcoming
        }.sorted { $0.eventDate < $1.eventDate }
    }
    
    func getEventRiskScore(symbol: String) async -> Double {
        let events = await getUpcomingEvents(days: 7)
        let symbolEvents = events.filter { $0.symbol == symbol || $0.symbol == "GENERAL" }
        
        var riskScore = 0.0
        
        for event in symbolEvents {
            let impactWeight: Double
            switch event.expectedImpact {
            case .high: impactWeight = 0.3
            case .medium: impactWeight = 0.15
            case .low: impactWeight = 0.05
            }
            
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: event.eventDate).day ?? 7
            let proximityFactor = max(0, 1.0 - Double(daysUntil) / 7.0)
            
            riskScore += impactWeight * proximityFactor
        }
        
        return min(riskScore, 1.0)
    }
    
    func getEventContextForDecision(symbol: String) async -> EventDecisionContext {
        let events = await getUpcomingEvents(days: 7)
        let relevantEvents = events.filter { $0.symbol == symbol || $0.symbol == "GENERAL" }
        
        var warnings: [String] = []
        var riskScore = 0.0
        
        for event in relevantEvents {
            if event.expectedImpact == .high {
                warnings.append("\(event.eventType.rawValue) \(event.daysUntil)")
                riskScore += 0.25
            } else if event.expectedImpact == .medium {
                riskScore += 0.1
            }
        }
        
        return EventDecisionContext(
            hasHighImpactEvent: relevantEvents.contains { $0.expectedImpact == .high },
            riskScore: min(riskScore, 1.0),
            warnings: warnings,
            eventCount: relevantEvents.count
        )
    }
    
    func updateEventsFromCalendar(_ events: [MarketEvent]) {
        self.upcomingEvents = events
    }
}
