import Foundation
import Combine

// MARK: - Market Context Coordinator
//
// Harmony prensibi:
//   Aether, velocity, rejim dönüşümü, watchlist nabzı, Hermes haber akışı — bu
//   motorların hepsi Council'da karar verirken hesaplanıyor ama otopilot bu
//   olandan habersiz kalıyordu. Otopilot habersiz kalırsa sert dönüşümlerde
//   ne yapacağını bilemez: kapanış rallysinde agresif gitmez, çöküşte küçülmez.
//
//   MarketContextCoordinator **tek bilgi kaynağı**: rejim + pulse + velocity'yi
//   periyodik topluyor, herkesin (Settings UI, AutoPilotStore, TradeBrainExecutor)
//   aynı anlık görüntüyü okuduğu merkezi durum. Ek olarak Combine publisher
//   yayımlıyor; dinleyiciler değişimde kendi davranışını ayarlıyor.
//
//   **Kullanıcı yetkisine saygı:** Coordinator otopilotu KAPATIP AÇMAZ. Sadece
//   koruyucu/destekleyici **multiplier** verir. Kapalıysa kapalı kalır, açıksa
//   açık kalır; bu multiplier sadece aktif olduğunda pozisyon boyutunu ayarlar.

public final class MarketContextCoordinator: ObservableObject, @unchecked Sendable {
    public static let shared = MarketContextCoordinator()

    // MARK: - Public Snapshot

    public struct Snapshot: Sendable, Equatable {
        public let timestamp: Date

        // Core bileşenler
        public let aetherScore: Double
        public let aetherVelocity: Double
        public let aetherSignal: String          // recoveringFast / recovering / stable / deteriorating / deterioratingFast
        public let regimeDirection: String       // RISING / FALLING / STABLE
        public let regimeConfidence: Double
        public let regimeEvidence: [String]
        public let pulseIntensity: String        // DORMANT / NORMAL / STIRRING / SURGING / EXTREME
        public let pulseDirection: String        // UP / DOWN / MIXED
        public let pulseMoveRate: Double
        public let hermesPositive: Int
        public let hermesNegative: Int

        // Sistem çıkarımları — otopilot ve UI için hazır sinyaller

        /// Pozisyon çarpanı (0.0 – 1.2). Otopilot yeni pozisyon açarken base
        /// allocation'ı bununla çarpar. Hiçbir zaman 0 değil (kullanıcı açıksa
        /// küçük bir taban hep var, çünkü rejim dönüşümü kaçırmamak için).
        public let positionMultiplier: Double

        /// Koruyucu mod aktif mi? Pulse SURGING/EXTREME DOWN ise veya
        /// rejim FALLING + confidence ≥ 0.60 ise true. Otopilot yeni agresif
        /// alımları durdurur (ama kapanmaz, mevcut pozisyonlar değişmez).
        public let protectiveMode: Bool

        /// Fırsat modu aktif mi? turningUp + yüksek güven + pulse SURGING/EXTREME UP.
        /// Otopilot "bu bir dönüş penceresi" diye agresif pozisyon alır.
        public let opportunityMode: Bool

        /// İnsan-okunabilir özet — Settings'de "Otopilot ne görüyor?"
        public let humanSummary: String

        public static let empty = Snapshot(
            timestamp: Date(),
            aetherScore: 50, aetherVelocity: 0, aetherSignal: "stable",
            regimeDirection: "STABLE", regimeConfidence: 0, regimeEvidence: [],
            pulseIntensity: "DORMANT", pulseDirection: "MIXED", pulseMoveRate: 0,
            hermesPositive: 0, hermesNegative: 0,
            positionMultiplier: 1.0, protectiveMode: false, opportunityMode: false,
            humanSummary: "Henüz değerlendirilmedi"
        )
    }

    // MARK: - State

    @Published public private(set) var snapshot: Snapshot = .empty

    // Event stream — AutoPilot ve diğer servisler dinleyebilir
    public let events = PassthroughSubject<Snapshot, Never>()

    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 60.0 // her dakika

    // MARK: - Lifecycle

    private init() {}

    public func start() {
        guard updateTimer == nil else { return }
        ArgusLogger.info("MarketContextCoordinator başladı — her \(Int(updateInterval))sn piyasa bağlamı güncelleniyor", category: "CONTEXT")

        // İlk assess hemen
        Task.detached { [weak self] in
            await self?.refreshSnapshot()
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task.detached {
                await self?.refreshSnapshot()
            }
        }
    }

    public func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Manuel tetikleme — Settings yenile butonu gibi.
    public func refresh() async {
        await refreshSnapshot()
    }

    // MARK: - Core

    private func refreshSnapshot() async {
        // 1) Aether velocity
        let velocity = await AetherVelocityEngine.shared.analyze()

        // 2) Hermes sayımı
        let hermesPos = HermesEventStore.shared.countHighImpactEvents(polarity: .positive)
        let hermesNeg = HermesEventStore.shared.countHighImpactEvents(polarity: .negative)

        // 3) Piyasa breadth
        let watchlist = await MainActor.run { WatchlistStore.shared.items }
        let quotes = await MainActor.run { MarketDataStore.shared.quotes.compactMapValues { $0.value } }
        let candles = await MainActor.run { MarketDataStore.shared.candles.compactMapValues { $0.value } }
        let globalMomentum = await MarketMomentumGate.shared.assessGlobal(
            quotes: quotes, candles: candles, watchlistSymbols: watchlist
        )
        let bistMomentum = await MarketMomentumGate.shared.assessBist(
            quotes: quotes, candles: candles, watchlistSymbols: watchlist
        )

        // 4) Watchlist pulse
        let pulse = await WatchlistPulseMonitor.shared.assess(candlesBySymbol: candles)

        // 5) Rejim dönüşüm
        let transition = await AetherRegimeTransitionDetector.shared.analyze(
            velocity: velocity,
            recentPositiveHermesEvents: hermesPos,
            recentNegativeHermesEvents: hermesNeg,
            globalMomentumLevel: globalMomentum.level,
            bistMomentumLevel: bistMomentum.level,
            watchlistPulse: pulse
        )

        // 6) Çıkarım — otopilot davranış sinyalleri
        let inferences = inferBehavior(
            velocity: velocity,
            transition: transition,
            pulse: pulse
        )

        let summary = buildHumanSummary(
            velocity: velocity,
            transition: transition,
            pulse: pulse,
            inferences: inferences
        )

        let new = Snapshot(
            timestamp: Date(),
            aetherScore: velocity.currentScore,
            aetherVelocity: velocity.velocity,
            aetherSignal: velocity.signal.rawValue,
            regimeDirection: transition.direction.rawValue,
            regimeConfidence: transition.confidence,
            regimeEvidence: transition.evidence,
            pulseIntensity: pulse.intensity.rawValue,
            pulseDirection: pulse.direction.rawValue,
            pulseMoveRate: pulse.avgMoveRate,
            hermesPositive: hermesPos,
            hermesNegative: hermesNeg,
            positionMultiplier: inferences.multiplier,
            protectiveMode: inferences.protective,
            opportunityMode: inferences.opportunity,
            humanSummary: summary
        )

        await MainActor.run {
            self.snapshot = new
            self.events.send(new)
        }
    }

    // MARK: - Behavior Inference

    private struct Inferences {
        let multiplier: Double
        let protective: Bool
        let opportunity: Bool
    }

    private func inferBehavior(
        velocity: AetherVelocityEngine.VelocityAnalysis,
        transition: AetherRegimeTransitionDetector.Transition,
        pulse: WatchlistPulseMonitor.Pulse
    ) -> Inferences {
        // Koruyucu mod — yeni agresif alım durmalı
        let protective =
            (pulse.intensity == .surging || pulse.intensity == .extreme) && pulse.direction == .down
            || (transition.direction == .turningDown && transition.confidence >= 0.60)
            || velocity.signal == .deterioratingFast

        // Fırsat modu — rejim dönüşümü + nabız yukarı
        let opportunity =
            transition.direction == .turningUp && transition.confidence >= 0.50
            && ((pulse.intensity == .surging || pulse.intensity == .extreme) && pulse.direction == .up
                || velocity.signal == .recoveringFast)

        // Çarpan: koruyucu/fırsat'a göre base 1.0 etrafında
        var multiplier: Double = 1.0
        if opportunity { multiplier = 1.20 }
        else if transition.direction == .turningUp && transition.confidence >= 0.50 { multiplier = 1.10 }
        else if protective { multiplier = 0.50 }
        else if transition.direction == .turningDown && transition.confidence >= 0.40 { multiplier = 0.75 }
        else if pulse.intensity == .extreme && pulse.direction == .down { multiplier = 0.40 }

        return Inferences(multiplier: multiplier, protective: protective, opportunity: opportunity)
    }

    private func buildHumanSummary(
        velocity: AetherVelocityEngine.VelocityAnalysis,
        transition: AetherRegimeTransitionDetector.Transition,
        pulse: WatchlistPulseMonitor.Pulse,
        inferences: Inferences
    ) -> String {
        if inferences.opportunity {
            return "🚀 Fırsat penceresi — rejim dönüşümü + nabız yukarı. Otopilot agresif (×\(String(format: "%.2f", inferences.multiplier)))"
        }
        if inferences.protective {
            return "🛡️ Koruyucu mod — nabız/rejim aşağı. Otopilot yeni alımı frenliyor (×\(String(format: "%.2f", inferences.multiplier)))"
        }
        if transition.direction == .turningUp && transition.confidence >= 0.50 {
            return "📈 Rejim ısınıyor (%\(Int(transition.confidence * 100))) — otopilot hafif pozitif (×\(String(format: "%.2f", inferences.multiplier)))"
        }
        if transition.direction == .turningDown && transition.confidence >= 0.40 {
            return "📉 Rejim soğuyor (%\(Int(transition.confidence * 100))) — otopilot temkinli (×\(String(format: "%.2f", inferences.multiplier)))"
        }
        return "➡️ Normal seyir — otopilot standart (×1.00)"
    }
}
