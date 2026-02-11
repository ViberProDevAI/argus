import Foundation

// MARK: - Alkindus Memory Store
/// Manages persistent storage for Alkindus calibration data.
/// Uses JSON files to store aggregated statistics (not raw events).

actor AlkindusMemoryStore {
    static let shared = AlkindusMemoryStore()
    
    // MARK: - Paths
    private let basePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory")
    }()
    
    private var calibrationPath: URL { basePath.appendingPathComponent("calibration.json") }
    private var pendingPath: URL { basePath.appendingPathComponent("pending_observations.json") }
    
    private init() {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
    }
    
    // MARK: - Load Calibration Data
    func loadCalibration() async -> CalibrationData {
        guard let data = try? Data(contentsOf: calibrationPath),
              let decoded = try? JSONDecoder().decode(CalibrationData.self, from: data) else {
            return CalibrationData.empty
        }
        return decoded
    }
    
    // MARK: - Save Calibration Data
    func saveCalibration(_ data: CalibrationData) async {
        var updated = data
        updated.lastUpdated = Date()
        
        if let encoded = try? JSONEncoder().encode(updated) {
            try? encoded.write(to: calibrationPath)
        }
    }
    
    // MARK: - Pending Observations (Awaiting Maturation)
    func loadPendingObservations() async -> [PendingObservation] {
        guard let data = try? Data(contentsOf: pendingPath),
              let decoded = try? JSONDecoder().decode([PendingObservation].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func savePendingObservations(_ observations: [PendingObservation]) async {
        if let encoded = try? JSONEncoder().encode(observations) {
            try? encoded.write(to: pendingPath)
        }
    }

    /// Atomically appends a new observation to pending list (prevents race conditions)
    func appendPendingObservation(_ observation: PendingObservation) async {
        var pending = await loadPendingObservations()
        pending.append(observation)
        await savePendingObservations(pending)
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

    var hitRate: Double {
        guard attempts > 0 else { return 0 }
        return correct / attempts
    }

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
    
    init(symbol: String, decisionDate: Date, action: String, moduleScores: [String: Double], regime: String, priceAtDecision: Double, horizons: [Int] = [7, 15], evaluatedHorizons: [Int] = []) {
        self.id = UUID()
        self.symbol = symbol
        self.decisionDate = decisionDate
        self.action = action
        self.moduleScores = moduleScores
        self.regime = regime
        self.priceAtDecision = priceAtDecision
        self.horizons = horizons
        self.evaluatedHorizons = evaluatedHorizons
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
