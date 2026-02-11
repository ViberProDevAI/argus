import Foundation
import Combine

// MARK: - Expectations Store
// Kullanıcının girdiği ekonomik beklenti değerlerini saklar ve sürpriz hesaplar

@MainActor
class ExpectationsStore: ObservableObject {
    static let shared = ExpectationsStore()
    
    // Published for UI updates
    @Published var expectations: [String: ExpectationEntry] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "aether_expectations"
    
    init() {
        loadFromDisk()
    }
    
    // MARK: - Models
    
    struct ExpectationEntry: Codable, Identifiable {
        let id: String  // e.g. "CPI_2024_12"
        let indicator: EconomicIndicator
        let expectedValue: Double
        let enteredAt: Date
        var actualValue: Double?
        var announcedAt: Date?
        
        var surprise: Double? {
            guard let actual = actualValue else { return nil }
            return actual - expectedValue
        }
        
        var surprisePercent: Double? {
            guard let surprise = surprise else { return nil }
            guard expectedValue != 0 else { return nil }
            return (surprise / abs(expectedValue)) * 100
        }
        
        var isPositiveSurprise: Bool? {
            guard let surprise = surprise else { return nil }
            // For inverse indicators (like unemployment), negative surprise is good
            return indicator.isInverse ? (surprise < 0) : (surprise > 0)
        }
    }
    
    enum EconomicIndicator: String, Codable, CaseIterable, Identifiable {
        case cpi = "CPI"
        case unemployment = "UNRATE"
        case payrolls = "PAYEMS"
        case claims = "ICSA"
        case pce = "PCE"
        case gdp = "GDP"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .cpi: return "CPI (Enflasyon)"
            case .unemployment: return "İşsizlik Oranı"
            case .payrolls: return "Tarım Dışı İstihdam"
            case .claims: return "İşsizlik Başvuruları"
            case .pce: return "PCE Enflasyonu"
            case .gdp: return "GSYİH Büyümesi"
            }
        }
        
        var unit: String {
            switch self {
            case .cpi, .unemployment, .pce, .gdp: return "%"
            case .payrolls, .claims: return "K"
            }
        }
        
        var icon: String {
            switch self {
            case .cpi: return "cart.fill"
            case .unemployment: return "person.crop.circle.badge.xmark"
            case .payrolls: return "person.3.fill"
            case .claims: return "person.badge.minus"
            case .pce: return "creditcard.fill"
            case .gdp: return "chart.bar.fill"
            }
        }
        
        var isInverse: Bool {
            // True if LOWER is BETTER
            switch self {
            case .cpi, .unemployment, .claims, .pce: return true
            case .payrolls, .gdp: return false
            }
        }
        
        var placeholder: String {
            switch self {
            case .cpi: return "2.7"
            case .unemployment: return "4.2"
            case .payrolls: return "+180"
            case .claims: return "220"
            case .pce: return "2.5"
            case .gdp: return "2.8"
            }
        }
        
        var helpText: String {
            switch self {
            case .cpi: return "Örnek: 2.7 (yıllık % değişim)"
            case .unemployment: return "Örnek: 4.2 (%)"
            case .payrolls: return "Örnek: +180 (bin kişi)"
            case .claims: return "Örnek: 220 (bin başvuru)"
            case .pce: return "Örnek: 2.5 (yıllık % değişim)"
            case .gdp: return "Örnek: 2.8 (çeyreklik % büyüme)"
            }
        }
        
        var fredSeriesId: String {
            return rawValue
        }
    }
    
    // MARK: - Public API
    
    func setExpectation(indicator: EconomicIndicator, value: Double) {
        let id = makeId(for: indicator)
        let entry = ExpectationEntry(
            id: id,
            indicator: indicator,
            expectedValue: value,
            enteredAt: Date()
        )
        expectations[id] = entry
        saveToDisk()
        print("📝 Expectation set: \(indicator.displayName) = \(value)\(indicator.unit)")
    }
    
    func updateActual(indicator: EconomicIndicator, value: Double) {
        let id = makeId(for: indicator)
        guard var entry = expectations[id] else { return }
        entry.actualValue = value
        entry.announcedAt = Date()
        expectations[id] = entry
        saveToDisk()
        
        if let surprise = entry.surprise {
            let emoji = entry.isPositiveSurprise == true ? "✅" : "⚠️"
            print("\(emoji) Surprise: \(indicator.displayName) = \(value) vs \(entry.expectedValue) → \(String(format: "%+.2f", surprise))")
        }
    }
    
    func getExpectation(for indicator: EconomicIndicator) -> ExpectationEntry? {
        let id = makeId(for: indicator)
        return expectations[id]
    }
    
    func getSurprise(for indicator: EconomicIndicator) -> Double? {
        return getExpectation(for: indicator)?.surprise
    }
    
    func getSurpriseImpact(for indicator: EconomicIndicator) -> Double {
        // Returns score adjustment based on surprise
        guard let entry = getExpectation(for: indicator),
              let surprisePercent = entry.surprisePercent else { return 0 }
        
        // Cap at ±10 points
        let impact = min(10, max(-10, surprisePercent * 2))
        
        // Flip for inverse indicators
        return entry.indicator.isInverse ? -impact : impact
    }
    
    // MARK: - Senkron Erişim (MacroRegimeService için)
    // Bu fonksiyonlar cached verileri döndürür - thread-safe snapshot
    
    nonisolated func getSurpriseImpactSync(for indicator: EconomicIndicator) -> Double {
        // MainActor üzerinde çalışan asenkron bir fonksiyon, ama cached değer döndürür
        // Note: Bu bir snapshot'tır, anlık değer farklı olabilir
        return MainActor.assumeIsolated {
            self.getSurpriseImpact(for: indicator)
        }
    }
    
    func clearExpectation(for indicator: EconomicIndicator) {
        let id = makeId(for: indicator)
        expectations.removeValue(forKey: id)
        saveToDisk()
    }
    
    func clearAll() {
        expectations.removeAll()
        saveToDisk()
    }
    
    // MARK: - Recent Surprises
    
    func getRecentSurprises() -> [ExpectationEntry] {
        return expectations.values
            .filter { $0.actualValue != nil }
            .sorted { ($0.announcedAt ?? .distantPast) > ($1.announcedAt ?? .distantPast) }
    }
    
    func getPendingExpectations() -> [ExpectationEntry] {
        return expectations.values
            .filter { $0.actualValue == nil }
            .sorted { $0.enteredAt > $1.enteredAt }
    }
    
    // MARK: - Private
    
    private func makeId(for indicator: EconomicIndicator) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM"
        return "\(indicator.rawValue)_\(formatter.string(from: Date()))"
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(Array(expectations.values))
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save expectations: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            let entries = try JSONDecoder().decode([ExpectationEntry].self, from: data)
            expectations = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            print("📦 Loaded \(entries.count) expectations")
        } catch {
            print("❌ Failed to load expectations: \(error)")
        }
    }
}
