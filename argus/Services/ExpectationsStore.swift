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

        /// Beklenti "tuttu mu"? Sapma göstergeye özgü eşiğin altındaysa doğru sayılır.
        /// actualValue yoksa nil döner (henüz sonuç çıkmamış).
        var isCorrect: Bool? {
            guard let surprise = surprise else { return nil }
            return abs(surprise) <= indicator.correctThreshold
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

        /// Beklentinin "tutmuş" sayılması için tahmin ile gerçek arasındaki kabul edilebilir sapma.
        /// Yüzde göstergeleri için puan cinsinden (örn. beklenti 2.7 — gerçek 2.5 ile 2.9 arası = doğru).
        /// Payrolls/claims için bin kişi cinsinden.
        var correctThreshold: Double {
            switch self {
            case .cpi, .pce: return 0.2        // %0.2 puan
            case .unemployment: return 0.15     // %0.15 puan
            case .gdp: return 0.3               // %0.3 puan (çeyreklik)
            case .payrolls: return 30           // 30K iş
            case .claims: return 15             // 15K başvuru
            }
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

    /// Gerçek değer FRED'den geldiğinde, takvim hizasından bağımsız olarak
    /// bekleyen en yeni tahmini bulup işaretler. Aynı göstergenin daha sonraki
    /// çağrılarında tekrar eşleşme olmasın diye actualValue dolu kayıtlar atlanır.
    /// `observationDate` kontrolü: tahmin bu gözlem tarihinden önce girilmiş olmalı.
    /// 45 gün grace period uygulanır (kullanıcı gözlem tarihine yakın tahmin
    /// yazabilir; FRED gecikmeli açıklıyor — Nov verisi ~Dec 12'de gelir).
    @discardableResult
    func matchAndUpdateActual(indicator: EconomicIndicator, value: Double, observationDate: Date) -> Bool {
        let gracePeriod: TimeInterval = 60 * 60 * 24 * 45 // 45 gün
        let cutoff = observationDate.addingTimeInterval(gracePeriod)

        let candidates = expectations.values
            .filter {
                $0.indicator == indicator
                && $0.actualValue == nil
                && $0.enteredAt <= cutoff
            }
            .sorted { $0.enteredAt > $1.enteredAt } // En son girilen önce

        guard var entry = candidates.first else { return false }

        // İdempotency: Aynı observationDate ile tekrar çağrılırsa no-op.
        // (enteredAt observationDate'ten sonra ise kullanıcı yeni bir tahmin girmiş,
        //  eski gözlem için işaretleme yapmayalım.)

        entry.actualValue = value
        entry.announcedAt = observationDate
        expectations[entry.id] = entry
        saveToDisk()

        if let surprise = entry.surprise {
            let mark: String
            if entry.isCorrect == true {
                mark = "🎯"
            } else if entry.isPositiveSurprise == true {
                mark = "✅"
            } else {
                mark = "⚠️"
            }
            let correctTag = entry.isCorrect == true ? " (TUTTU)" : " (sapma)"
            print("\(mark) \(indicator.displayName)\(correctTag): Beklenti=\(entry.expectedValue) Gerçek=\(value) Δ=\(String(format: "%+.2f", surprise))\(indicator.unit)")
        }
        return true
    }

    /// Mevcut tahminin sadece expectedValue'sini günceller; actualValue/announcedAt korunur.
    /// Kayıt yoksa yeni bir tahmin olarak oluşturur. (UI'da tahmini düzenleme bug fix.)
    func updateExpectedValue(indicator: EconomicIndicator, newValue: Double) {
        let id = makeId(for: indicator)
        if let existing = expectations[id] {
            let updated = ExpectationEntry(
                id: existing.id,
                indicator: existing.indicator,
                expectedValue: newValue,
                enteredAt: Date(),
                actualValue: existing.actualValue,
                announcedAt: existing.announcedAt
            )
            expectations[id] = updated
            saveToDisk()
            print("✏️ Expectation updated: \(indicator.displayName) = \(newValue)\(indicator.unit)")
        } else {
            setExpectation(indicator: indicator, value: newValue)
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

    /// Nonisolated wrapper — engine (MacroRegimeService) MainActor üzerinde değil,
    /// ama FRED fetch tamamlandığında tahminleri güncellemesi lazım.
    @discardableResult
    nonisolated func matchAndUpdateActualSync(indicator: EconomicIndicator, value: Double, observationDate: Date) -> Bool {
        return MainActor.assumeIsolated {
            self.matchAndUpdateActual(indicator: indicator, value: value, observationDate: observationDate)
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

    // MARK: - Accuracy Summary

    struct AccuracySummary {
        let total: Int
        let correct: Int
        var accuracy: Double {
            guard total > 0 else { return 0 }
            return Double(correct) / Double(total) * 100
        }
        var display: String {
            guard total > 0 else { return "—" }
            return String(format: "%d/%d (%.0f%%)", correct, total, accuracy)
        }
    }

    /// Belirli gösterge için son N tahmin arasında kaç tanesi tuttu?
    func getAccuracySummary(for indicator: EconomicIndicator, lastN: Int = 10) -> AccuracySummary? {
        let resolved = expectations.values
            .filter { $0.indicator == indicator && $0.actualValue != nil }
            .sorted { ($0.announcedAt ?? .distantPast) > ($1.announcedAt ?? .distantPast) }
            .prefix(lastN)

        guard !resolved.isEmpty else { return nil }
        let correct = resolved.filter { $0.isCorrect == true }.count
        return AccuracySummary(total: resolved.count, correct: correct)
    }

    /// Tüm göstergeler genelinde tahmin doğruluğu (son N).
    func getOverallAccuracy(lastN: Int = 20) -> AccuracySummary? {
        let resolved = expectations.values
            .filter { $0.actualValue != nil }
            .sorted { ($0.announcedAt ?? .distantPast) > ($1.announcedAt ?? .distantPast) }
            .prefix(lastN)

        guard !resolved.isEmpty else { return nil }
        let correct = resolved.filter { $0.isCorrect == true }.count
        return AccuracySummary(total: resolved.count, correct: correct)
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
