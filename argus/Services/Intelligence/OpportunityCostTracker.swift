import Foundation

// MARK: - Opportunity Cost Tracker
/// Nakitte beklerken "ne kaybettik?" sorusunu cevaplar.
/// Her döngüde: Bu sembolü alsaydık ne kazanırdık?
/// Bu veri:
///   1. Chiron'u besler (nakitte kalmanın ne kadar maliyeti var)
///   2. Kullanıcıya raporlanır ("Bu ay nakitte kalarak %8.3 fırsatı kaçırdınız")
///   3. Sistem kalibrasyonunu etkiler (çok temkinli mi davranıyoruz?)

actor OpportunityCostTracker {
    static let shared = OpportunityCostTracker()

    // MARK: - Modeller

    struct MissedOpportunity: Codable, Identifiable {
        let id: UUID
        let symbol: String
        let missedAt: Date              // Sistem "alım yapmamalı" dedi
        let priceAtMiss: Double
        let reasonSkipped: SkipReason
        let aetherScoreAtMiss: Double

        // Sonradan doldurulan alanlar
        var evaluatedAt: Date?
        var priceAtEvaluation: Double?
        var returnIfHeld: Double?       // % getiri (pozitif = kaçırdık, negatif = iyi ki almadık)
        var verdict: MissVerdict?

        enum SkipReason: String, Codable {
            case aetherTooLow      = "AETHER_DUSUK"
            case regimeBlocked     = "REJIM_BLOK"
            case lowConfidence     = "GUVENSIZ_SINYAL"
            case portfolioHot      = "PORTFOLYO_SICAK"
            case policyBlock       = "POLICY_BLOK"
        }

        enum MissVerdict: String, Codable {
            case goodSkip    = "İYİ_KARAR"   // Fiyat düştü, atlamak doğruydu
            case missedGain  = "KAÇIRILDI"   // Fiyat yükseldi, kaçırıldı
            case neutral     = "NÖTR"        // ±2% aralığında
        }

        var id_default: UUID { id }
    }

    struct OpportunityCostSummary {
        let period: String
        let totalMissed: Int
        let goodSkips: Int               // Haklı olarak atladık
        let missedGains: Int             // Gerçekten kaçırdık
        let avgMissedReturn: Double      // Ortalama kaçırılan getiri
        let totalMissedReturnPct: Double // Toplam kaçırılan portföy etkisi
        let topMissed: [MissedOpportunity]

        var skipAccuracy: Double {
            guard totalMissed > 0 else { return 0 }
            return Double(goodSkips) / Double(totalMissed)
        }

        var isTooCautious: Bool { skipAccuracy < 0.40 }  // %40'tan az haklı atlama = çok temkinli
        var isWellCalibrated: Bool { skipAccuracy >= 0.55 && skipAccuracy <= 0.75 }
    }

    // MARK: - State

    private var pendingOpportunities: [MissedOpportunity] = []  // Henüz değerlendirilmemiş
    private var evaluatedOpportunities: [MissedOpportunity] = [] // Değerlendirilen
    private let maxRecords = 200
    private let evaluationHorizon: TimeInterval = 7 * 86400 // 7 gün sonra değerlendir
    private let persistPath = FileManager.default.documentsURL
        .appendingPathComponent("opportunity_cost.json")

    private init() { loadFromDisk() }

    // MARK: - Kayıt

    /// Atlanmış fırsatı kaydet (TradeBrainExecutor her skip'te çağırır)
    func recordSkip(
        symbol: String,
        price: Double,
        reason: MissedOpportunity.SkipReason,
        aetherScore: Double
    ) {
        let opp = MissedOpportunity(
            id: UUID(),
            symbol: symbol,
            missedAt: Date(),
            priceAtMiss: price,
            reasonSkipped: reason,
            aetherScoreAtMiss: aetherScore,
            evaluatedAt: nil,
            priceAtEvaluation: nil,
            returnIfHeld: nil,
            verdict: nil
        )
        pendingOpportunities.append(opp)
        if pendingOpportunities.count > maxRecords {
            pendingOpportunities = Array(pendingOpportunities.suffix(maxRecords))
        }
        saveToDisk()
    }

    // MARK: - Değerlendirme

    /// Olgun fırsatları değerlendir (argusApp'te saatlik timer'da çağrılır)
    func evaluateMatureOpportunities(currentPrices: [String: Double]) async {
        let now = Date()
        var updated = false

        for i in pendingOpportunities.indices {
            let opp = pendingOpportunities[i]
            guard opp.evaluatedAt == nil,
                  now.timeIntervalSince(opp.missedAt) >= evaluationHorizon,
                  let currentPrice = currentPrices[opp.symbol] else { continue }

            let returnPct = (currentPrice - opp.priceAtMiss) / opp.priceAtMiss * 100

            let verdict: MissedOpportunity.MissVerdict
            switch returnPct {
            case ..<(-2): verdict = .goodSkip
            case -2...2:  verdict = .neutral
            default:      verdict = .missedGain
            }

            pendingOpportunities[i].evaluatedAt = now
            pendingOpportunities[i].priceAtEvaluation = currentPrice
            pendingOpportunities[i].returnIfHeld = returnPct
            pendingOpportunities[i].verdict = verdict

            evaluatedOpportunities.append(pendingOpportunities[i])
            updated = true
        }

        // Değerlendirilenlerı pending'den çıkar
        pendingOpportunities.removeAll { $0.evaluatedAt != nil }

        if updated {
            saveToDisk()
            logSummary()
        }
    }

    // MARK: - Raporlama

    func getSummary(lastNDays: Int = 30) -> OpportunityCostSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lastNDays, to: Date()) ?? Date()
        let recent = evaluatedOpportunities.filter {
            ($0.evaluatedAt ?? Date.distantPast) >= cutoff
        }

        let goodSkips  = recent.filter { $0.verdict == .goodSkip }.count
        let missedGains = recent.filter { $0.verdict == .missedGain }.count
        let missedReturns = recent.compactMap { $0.verdict == .missedGain ? $0.returnIfHeld : nil }
        let avgMissed = missedReturns.isEmpty ? 0 : missedReturns.reduce(0, +) / Double(missedReturns.count)
        let topMissed = recent
            .filter { $0.verdict == .missedGain }
            .sorted { ($0.returnIfHeld ?? 0) > ($1.returnIfHeld ?? 0) }
            .prefix(5).map { $0 }

        return OpportunityCostSummary(
            period: "\(lastNDays) Gün",
            totalMissed: recent.count,
            goodSkips: goodSkips,
            missedGains: missedGains,
            avgMissedReturn: avgMissed,
            totalMissedReturnPct: missedReturns.reduce(0, +),
            topMissed: topMissed
        )
    }

    func getPendingCount() -> Int { pendingOpportunities.count }
    func getEvaluatedCount() -> Int { evaluatedOpportunities.count }

    // MARK: - Chiron Feedback Signal

    /// Sistem çok temkinli mi? → Chiron'a signal
    func calibrationSignal() -> CalibrationSignal {
        let summary = getSummary(lastNDays: 30)
        guard summary.totalMissed >= 10 else { return .insufficientData }

        if summary.skipAccuracy < 0.35 {
            return .tooConservative(missRate: 1 - summary.skipAccuracy)
        } else if summary.skipAccuracy > 0.80 {
            return .tooAggressive(skipRate: summary.skipAccuracy)
        } else if summary.isWellCalibrated {
            return .wellCalibrated
        }
        return .slightlyConservative
    }

    enum CalibrationSignal {
        case tooConservative(missRate: Double)
        case slightlyConservative
        case wellCalibrated
        case tooAggressive(skipRate: Double)
        case insufficientData

        var description: String {
            switch self {
            case .tooConservative(let r): return "Çok temkinli: fırsatların \(Int(r*100))%'ini kaçırıyoruz"
            case .slightlyConservative:   return "Hafif temkinli: ayar gerekebilir"
            case .wellCalibrated:         return "İyi kalibre: doğru dengede"
            case .tooAggressive(let r):   return "Çok agresif: atladıklarımızın \(Int(r*100))%'i haklıydı"
            case .insufficientData:       return "Yeterli veri yok henüz"
            }
        }
    }

    // MARK: - Persistence

    private struct PersistModel: Codable {
        var pending: [MissedOpportunity]
        var evaluated: [MissedOpportunity]
    }

    private func saveToDisk() {
        let model = PersistModel(pending: pendingOpportunities, evaluated: evaluatedOpportunities)
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: persistPath)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: persistPath),
              let model = try? JSONDecoder().decode(PersistModel.self, from: data) else { return }
        pendingOpportunities = model.pending
        evaluatedOpportunities = Array(model.evaluated.suffix(maxRecords))
    }

    private func logSummary() {
        let s = getSummary(lastNDays: 30)
        print("💰 OpportunityCost [30g]: \(s.totalMissed) atlama | \(s.goodSkips) haklı | \(s.missedGains) kaçırılan | Ort:\(String(format: "%+.1f%%", s.avgMissedReturn))")
        print("💰 Kalibrasyon: \(calibrationSignal().description)")
    }
}
