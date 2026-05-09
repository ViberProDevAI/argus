import Foundation

// MARK: - Alkindus Memory Store
/// Manages persistent storage for Alkindus calibration data.
/// Uses JSON files to store aggregated statistics (not raw events).

actor AlkindusMemoryStore {
    static let shared = AlkindusMemoryStore()
    
    // MARK: - Paths
    private let basePath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("alkindus_memory")
    }()
    
    private var calibrationPath: URL { basePath.appendingPathComponent("calibration.json") }
    private var pendingPath: URL { basePath.appendingPathComponent("pending_observations.json") }
    private var verdictsPath: URL { basePath.appendingPathComponent("alkindus_verdicts.json") }
    
    private init() {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
    }
    
    // MARK: - Load Calibration Data
    // Eski sürümde tüm load/save fonksiyonları `try?` ile sessiz hata yutuyordu →
    // disk dolu, izin hatası, JSON corrupt → her hata görünmez, dosya yazılmıyor,
    // bir sonraki turda boş veri yükleniyor, "hiçbir şey öğrenmiyor" şikayeti ortaya
    // çıkıyordu. Şimdi ilk açılış (fileReadNoSuchFile) sessiz, diğer hatalar loglanıyor.
    func loadCalibration() async -> CalibrationData {
        do {
            let data = try Data(contentsOf: calibrationPath)
            return try JSONDecoder().decode(CalibrationData.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return CalibrationData.empty
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return CalibrationData.empty
        } catch {
            print("❌ Alkindus: calibration.json okuma hatası: \(error.localizedDescription)")
            return CalibrationData.empty
        }
    }

    // MARK: - Save Calibration Data
    func saveCalibration(_ data: CalibrationData) async {
        var updated = data
        updated.lastUpdated = Date()

        do {
            let encoded = try JSONEncoder().encode(updated)
            try encoded.write(to: calibrationPath)
        } catch let encodingError as EncodingError {
            print("❌ Alkindus: calibration encode hatası: \(encodingError)")
        } catch {
            print("❌ Alkindus: calibration.json yazma hatası: \(error.localizedDescription)")
        }
    }

    // MARK: - Pending Observations (Awaiting Maturation)
    func loadPendingObservations() async -> [PendingObservation] {
        do {
            let data = try Data(contentsOf: pendingPath)
            return try JSONDecoder().decode([PendingObservation].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return []
        } catch {
            print("❌ Alkindus: pending_observations.json okuma hatası: \(error.localizedDescription)")
            return []
        }
    }

    func savePendingObservations(_ observations: [PendingObservation]) async {
        do {
            let encoded = try JSONEncoder().encode(observations)
            try encoded.write(to: pendingPath)
        } catch let encodingError as EncodingError {
            print("❌ Alkindus: pending observations encode hatası: \(encodingError)")
        } catch {
            print("❌ Alkindus: pending_observations.json yazma hatası: \(error.localizedDescription)")
        }
    }

    // MARK: - Verdicts (Post-Mortem Results)

    func loadVerdicts() async -> [AlkindusVerdict] {
        do {
            let data = try Data(contentsOf: verdictsPath)
            return try JSONDecoder().decode([AlkindusVerdict].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return []
        } catch {
            print("❌ Alkindus: alkindus_verdicts.json okuma hatası: \(error.localizedDescription)")
            return []
        }
    }

    func saveVerdict(_ verdict: AlkindusVerdict) async {
        var verdicts = await loadVerdicts()
        verdicts.append(verdict)
        // 2026-05-09: 200 → 2000.
        // 200 cap ~8 günlük history idi (ortalama 25 sembol × 2 horizon).
        // UI'da "neden öğrenmiyor?" izlenimini güçlendiriyordu.
        // 2000 verdict ≈ birkaç MB JSON, 80+ gün history.
        if verdicts.count > 2000 {
            verdicts = Array(verdicts.suffix(2000))
        }
        do {
            let encoded = try JSONEncoder().encode(verdicts)
            try encoded.write(to: verdictsPath)
        } catch let encodingError as EncodingError {
            print("❌ Alkindus: verdict encode hatası: \(encodingError)")
        } catch {
            print("❌ Alkindus: alkindus_verdicts.json yazma hatası: \(error.localizedDescription)")
        }
    }

    func loadVerdicts(for symbol: String) async -> [AlkindusVerdict] {
        let all = await loadVerdicts()
        return all.filter { $0.symbol == symbol }.sorted { $0.evaluationDate > $1.evaluationDate }
    }

    /// Atomically appends a new observation to pending list (prevents race conditions)
    func appendPendingObservation(_ observation: PendingObservation) async {
        var pending = await loadPendingObservations()
        pending.append(observation)
        await savePendingObservations(pending)
    }

    /// 2026-05-09: Sembol-başı-tek-slot modeli.
    /// Aynı sembol için zaten olgunlaşmamış (henüz T+15'i tamamlamamış)
    /// pending observation varsa yeni kayıt eklemez.
    /// Eski sürümde her `observe()` çağrısı yeni kayıt açıyordu; otopilot
    /// saatlik tarama ile aynı sembol için günde 24 paralel observation
    /// üretip 500'lük FIFO cap'i tetikliyor, T+15 dolmadan eskiler atılıyordu.
    /// Yeni davranış: aktif test bitene kadar (verdict üretip silinene kadar)
    /// aynı sembol için yeni test açılmaz. Test bitince bir sonraki observe()
    /// otomatik olarak yeni testi başlatır → kesintisiz öğrenme döngüsü.
    /// Returns true if observation was added, false if symbol already tracked.
    @discardableResult
    func appendPendingObservationIfAbsent(_ observation: PendingObservation) async -> Bool {
        var pending = await loadPendingObservations()
        let alreadyTracked = pending.contains { $0.symbol == observation.symbol && !$0.isFullyEvaluated }
        if alreadyTracked {
            return false
        }
        pending.append(observation)
        await savePendingObservations(pending)
        return true
    }

    // MARK: - Reset Learning
    //
    // 2026-05-09: Eski FIFO cap'i pending observation'ları olgunlaşmadan
    // budadığı için aylardır bozuk veri birikmişti. "Öğrenmeyi sıfırla"
    // butonu bu bozuk veriyi temizleyip Alkindus'a temiz başlangıç verir.
    // Calibration brackets ve regime insights da silinir — yeni 15-günlük
    // döngüden öğrenmeye baştan başlar.
    func resetLearning() async {
        try? FileManager.default.removeItem(at: pendingPath)
        try? FileManager.default.removeItem(at: verdictsPath)
        try? FileManager.default.removeItem(at: calibrationPath)
        // Klasör hâlâ var; bir sonraki save'de dosyalar yeniden oluşur.
    }
    
    // MARK: - Update Module Calibration
    func recordOutcome(module: String, scoreBracket: String, wasCorrect: Bool, regime: String) async {
        var data = await loadCalibration()

        // Update module bracket
        if data.modules[module] == nil {
            data.modules[module] = ModuleCalibration(brackets: [:])
        }

        if data.modules[module]?.brackets[scoreBracket] == nil {
            data.modules[module]?.brackets[scoreBracket] = BracketStats(attempts: 0, correct: 0)
        }

        data.modules[module]?.brackets[scoreBracket]?.attempts += 1
        if wasCorrect {
            data.modules[module]?.brackets[scoreBracket]?.correct += 1
        }

        // Update regime insight
        if data.regimes[regime] == nil {
            data.regimes[regime] = RegimeInsight(moduleAttempts: [:], moduleCorrect: [:])
        }

        data.regimes[regime]?.moduleAttempts[module, default: 0] += 1
        if wasCorrect {
            data.regimes[regime]?.moduleCorrect[module, default: 0] += 1
        }

        await saveCalibration(data)
    }

    /// Records outcome with weighted contribution (for soft bracket boundaries)
    func recordOutcomeWeighted(module: String, scoreBracket: String, wasCorrect: Bool, weight: Double, regime: String) async {
        var data = await loadCalibration()

        // Update module bracket with weighted contribution
        if data.modules[module] == nil {
            data.modules[module] = ModuleCalibration(brackets: [:])
        }

        if data.modules[module]?.brackets[scoreBracket] == nil {
            data.modules[module]?.brackets[scoreBracket] = BracketStats(attempts: 0, correct: 0)
        }

        data.modules[module]?.brackets[scoreBracket]?.updateWeighted(correct: wasCorrect, weight: weight)

        // Update regime insight (using integer approximation for regime tracking)
        // Only count full contributions to regime stats to avoid fractional counts
        if weight >= 0.5 {
            if data.regimes[regime] == nil {
                data.regimes[regime] = RegimeInsight(moduleAttempts: [:], moduleCorrect: [:])
            }

            data.regimes[regime]?.moduleAttempts[module, default: 0] += 1
            if wasCorrect {
                data.regimes[regime]?.moduleCorrect[module, default: 0] += 1
            }
        }

        await saveCalibration(data)
    }
    
    // MARK: - Get Hit Rate
    func getHitRate(module: String, scoreBracket: String) async -> Double? {
        let data = await loadCalibration()
        guard let stats = data.modules[module]?.brackets[scoreBracket] else { return nil }
        return stats.hitRate
    }
    
    // MARK: - Bootstrap Import
    /// Imports bootstrap calibration data from bundled JSON file.
    /// Should be called once on first launch or when resetting Alkindus.
    func importBootstrapCalibration() async -> Bool {
        // Check if calibration already exists
        let existing = await loadCalibration()
        if !existing.modules.isEmpty {
            print("👁️ Alkindus: Calibration already exists, skipping bootstrap")
            return false
        }
        
        // Find bootstrap file
        guard let bundlePath = Bundle.main.path(forResource: "alkindus_bootstrap_calibration", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)) else {
            print("👁️ Alkindus: Bootstrap file not found in bundle")
            return false
        }
        
        // Parse bootstrap data
        guard let bootstrap = try? JSONDecoder().decode(BootstrapCalibration.self, from: data) else {
            print("👁️ Alkindus: Failed to decode bootstrap data")
            return false
        }
        
        // Convert to CalibrationData
        var calibration = CalibrationData.empty
        calibration.version = bootstrap.version
        
        for (moduleName, moduleData) in bootstrap.modules {
            var moduleCalibration = ModuleCalibration(brackets: [:])
            for (bracket, stats) in moduleData.brackets {
                moduleCalibration.brackets[bracket] = BracketStats(
                    attempts: stats.attempts,
                    correct: stats.correct
                )
            }
            calibration.modules[moduleName] = moduleCalibration
        }
        
        await saveCalibration(calibration)
        print("👁️ Alkindus: Bootstrap calibration imported successfully!")
        return true
    }
    
    /// Checks if bootstrap needs to be run (empty calibration)
    func needsBootstrap() async -> Bool {
        let existing = await loadCalibration()
        return existing.modules.isEmpty
    }

    // MARK: - Test Helper Methods (DEBUG only)
    #if DEBUG
    /// Forces save of current calibration to disk (test helper)
    func saveToDisk() async {
        let data = await loadCalibration()
        await saveCalibration(data)
    }

    /// Forces reload from disk (test helper)
    func loadFromDisk() async {
        // This is a no-op since loadCalibration() always reads from disk
        // But it's here for semantic clarity in tests
        _ = await loadCalibration()
    }

    /// Removes a pending observation at the specified index (test helper)
    func removePendingObservation(at index: Int) async {
        var pending = await loadPendingObservations()
        guard index >= 0 && index < pending.count else { return }
        pending.remove(at: index)
        await savePendingObservations(pending)
    }
    #endif
}

// MARK: - Bootstrap Data Model
private struct BootstrapCalibration: Codable {
    let version: String
    let bootstrapDate: String
    let source: String
    let modules: [String: BootstrapModule]
}

private struct BootstrapModule: Codable {
    let brackets: [String: BootstrapBracket]
}

private struct BootstrapBracket: Codable {
    let attempts: Int
    let correct: Int
    let hitRate: Double
}

// MARK: - Data Models

struct CalibrationData: Codable {
    var modules: [String: ModuleCalibration]
    var regimes: [String: RegimeInsight]
    var lastUpdated: Date
    var version: String
    
    static var empty: CalibrationData {
        CalibrationData(
            modules: [:],
            regimes: [:],
            lastUpdated: Date(),
            version: "1.0"
        )
    }
}

struct ModuleCalibration: Codable {
    var brackets: [String: BracketStats] // "70-80", "80-100", etc.
}

struct BracketStats: Codable {
    var attempts: Double
    var correct: Double

    init(attempts: Int, correct: Int) {
        self.attempts = Double(attempts)
        self.correct = Double(correct)
    }

    init(attempts: Double, correct: Double) {
        self.attempts = attempts
        self.correct = correct
    }

    /// Ham (smoothed olmayan) hit rate — UI'da gerçek sayıyı göstermek için.
    /// Örnek boyutu küçükse uçuk yüzdeler verebilir (3/3 = %100).
    var hitRate: Double {
        guard attempts > 0 else { return 0 }
        return correct / attempts
    }

    /// 2026-05-09 Faz D — Laplace smoothing.
    /// Bayesian prior: her bracket başlangıçta 5 deneme/2.5 doğru varsayılır
    /// (yani %50, n=5 prior). Bu, az örnekli durumlarda uçuk yüzdeleri önler:
    ///   • 3/3 = %100 yerine (3+2.5)/(3+5) = %68.75
    ///   • 0/3 = %0 yerine (0+2.5)/(3+5) = %31.25
    /// Çok örnekle (n>>5) gerçek hit rate'e yaklaşır. Karar mekanizması bu
    /// "smooth" değeri kullanarak istatistiksel olarak savunulabilir kararlar
    /// verir; UI ham `hitRate` ve `attempts` ile şeffaflığı korur.
    var smoothedHitRate: Double {
        let priorAttempts: Double = 5
        let priorCorrect: Double = 2.5
        return (correct + priorCorrect) / (attempts + priorAttempts)
    }

    /// 2026-05-09 Faz D — Wilson skor güven aralığı (%95).
    /// Düşük örnek boyutunda ham orana göre çok daha sağlam alt/üst sınır.
    /// Returns (lower, upper). Karar verirken alt sınırı kullanmak (kötümser
    /// tahmin) güvenli — "en kötü ihtimalle %X doğru" garantisi.
    var wilsonInterval95: (lower: Double, upper: Double) {
        guard attempts > 0 else { return (0, 1) }
        let z: Double = 1.96  // %95 güven
        let n = attempts
        let p = correct / attempts
        let denominator = 1 + (z * z) / n
        let center = p + (z * z) / (2 * n)
        let spread = z * sqrt((p * (1 - p) / n) + (z * z) / (4 * n * n))
        let lower = max(0, (center - spread) / denominator)
        let upper = min(1, (center + spread) / denominator)
        return (lower, upper)
    }

    /// Örnek boyutu yeterli mi? Karar mekanizması az örnekte nötr (0.5)
    /// ağırlık katsayısı kullanmalı, çok örnekte gerçek smoothedHitRate'e
    /// güvenmeli.
    var sampleSizeReliable: Bool { attempts >= 10 }

    mutating func updateWeighted(correct isCorrect: Bool, weight: Double) {
        attempts += weight
        if isCorrect {
            correct += weight
        }
    }
}

struct RegimeInsight: Codable {
    var moduleAttempts: [String: Int]
    var moduleCorrect: [String: Int]
    
    func hitRate(for module: String) -> Double {
        let attempts = moduleAttempts[module] ?? 0
        let correct = moduleCorrect[module] ?? 0
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }
}

// MARK: - Alkindus Verdict (Post-Mortem)

struct AlkindusVerdict: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let action: String          // "BUY" / "SELL"
    let decisionDate: Date
    let evaluationDate: Date
    let horizon: Int            // 7 or 15
    let wasCorrect: Bool
    let priceChange: Double     // % change (e.g. +4.2 or -8.3)
    let regime: String
    let moduleVerdicts: [ModuleVerdict]
    let originalReasoning: String

    init(
        symbol: String,
        action: String,
        decisionDate: Date,
        evaluationDate: Date = Date(),
        horizon: Int,
        wasCorrect: Bool,
        priceChange: Double,
        regime: String,
        moduleVerdicts: [ModuleVerdict],
        originalReasoning: String
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.action = action
        self.decisionDate = decisionDate
        self.evaluationDate = evaluationDate
        self.horizon = horizon
        self.wasCorrect = wasCorrect
        self.priceChange = priceChange
        self.regime = regime
        self.moduleVerdicts = moduleVerdicts
        self.originalReasoning = originalReasoning
    }
}

struct ModuleVerdict: Codable {
    let module: String
    let score: Double
    let wasCorrect: Bool
}

struct PendingObservation: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let decisionDate: Date
    let action: String
    let moduleScores: [String: Double]
    let regime: String
    let priceAtDecision: Double
    let horizons: [Int] // [7, 15]
    var evaluatedHorizons: [Int] // Horizons already evaluated
    let reasoning: String // Konseyin karar anındaki gerekçesi

    init(symbol: String, decisionDate: Date, action: String, moduleScores: [String: Double], regime: String, priceAtDecision: Double, horizons: [Int] = [7, 15], evaluatedHorizons: [Int] = [], reasoning: String = "") {
        self.id = UUID()
        self.symbol = symbol
        self.decisionDate = decisionDate
        self.action = action
        self.moduleScores = moduleScores
        self.regime = regime
        self.priceAtDecision = priceAtDecision
        self.horizons = horizons
        self.evaluatedHorizons = evaluatedHorizons
        self.reasoning = reasoning
    }
    
    // Check if a horizon is ready to be evaluated
    func isHorizonMature(_ horizon: Int, currentDate: Date = Date()) -> Bool {
        let targetDate = Calendar.current.date(byAdding: .day, value: horizon, to: decisionDate) ?? decisionDate
        return currentDate >= targetDate && !evaluatedHorizons.contains(horizon)
    }
    
    // All horizons evaluated?
    var isFullyEvaluated: Bool {
        Set(evaluatedHorizons) == Set(horizons)
    }
}
