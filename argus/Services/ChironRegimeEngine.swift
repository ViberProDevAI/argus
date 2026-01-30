import Foundation
import Combine



/// Represents the detected market condition for a specific asset.
enum MarketRegime: String, Codable, Sendable {
    case neutral = "Neutral"
    case trend = "Trend"
    case chop = "Chop"
    case riskOff = "Risk-Off"
    case newsShock = "News Shock"
    
    var descriptor: String {
        switch self {
        case .neutral: return "Dengeli Piyasa"
        case .trend: return "Güçlü Trend"
        case .chop: return "Yatay / Testere"
        case .riskOff: return "Riskten Kaçış (Defansif)"
        case .newsShock: return "Haber Şoku"
        }
    }
}

/// Dynamic weights for the Argus modules (7 Modül - Cronos kaldırıldı).
struct ModuleWeights: Codable, Sendable {
    let atlas: Double   // Fundamental (Stock)
    let orion: Double   // Technical (Stock)
    let aether: Double  // Macro (Global)
    let demeter: Double? // Sector (Flow)
    let phoenix: Double? // Price Action (Trend)
    let hermes: Double?  // News
    let athena: Double?  // Factors
    
    /// Returns a normalized version where weights sum to 1.0.
    var normalized: ModuleWeights {
        let d = demeter ?? 0.0
        let p = phoenix ?? 0.0
        let h = hermes ?? 0.0
        let ath = athena ?? 0.0
        
        let sum = atlas + orion + aether + d + p + h + ath
        guard sum > 0 else {
            // Fallback: Safe Fundamentals + Macro Dominance
            return ModuleWeights(atlas: 0.3, orion: 0.2, aether: 0.2, demeter: 0.1, phoenix: 0.1, hermes: 0.05, athena: 0.05)
        }
        
        return ModuleWeights(
            atlas: atlas / sum,
            orion: orion / sum,
            aether: aether / sum,
            demeter: d / sum,
            phoenix: p / sum,
            hermes: h / sum,
            athena: ath / sum
        )
    }
}

/// The context snapshot required by Chiron to make a decision.
struct ChironContext: Codable, Sendable {
    let atlasScore: Double?
    let orionScore: Double?
    let aetherScore: Double?
    let demeterScore: Double?  // Sector Score
    let phoenixScore: Double?  // PA Score
    let hermesScore: Double?
    let athenaScore: Double?
    let symbol: String?
    
    // Detailed Context
    let orionTrendStrength: Double?
    let chopIndex: Double?
    let volatilityHint: Double?
    
    let isHermesAvailable: Bool
}

/// The output of the Chiron Engine.
struct ChironResult: Codable, Sendable {
    let regime: MarketRegime
    let coreWeights: ModuleWeights
    let pulseWeights: ModuleWeights
    
    let explanationTitle: String
    let explanationBody: String
    let learningNotes: [String]?
}

// MARK: - Chiron Regime Engine

final class ChironRegimeEngine: ObservableObject, @unchecked Sendable {
    static let shared = ChironRegimeEngine()
    
    private var _dynamicConfig: ChironOptimizationOutput?
    private let lock = NSLock()
    
    private var dynamicConfig: ChironOptimizationOutput? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _dynamicConfig
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _dynamicConfig = newValue
        }
    }

    private let persistenceKey = "ChironLearnedWeights"
    private let regimePersistenceKey = "ChironLastRegimeResult"
    
    // MARK: - Logger
    private func log(_ message: String, level: ArgusLogger.LogLevel = .info) {
        Task { await ArgusLogger.shared.log(message, level: level, category: "CHIRON") }
    }
    
    init() {
        loadFromDisk()
        loadRegimeFromDisk()
    }
    
    func loadDynamicWeights(_ config: ChironOptimizationOutput) {
        self.dynamicConfig = config
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        guard let config = dynamicConfig else { return }
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let config = try? JSONDecoder().decode(ChironOptimizationOutput.self, from: data) {
            self.dynamicConfig = config
            print("💾 Chiron: Loaded learned weights from disk.")
        }
    }
    
    private func saveRegimeToDisk(_ result: ChironResult) {
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: regimePersistenceKey)
        }
    }
    
    private func loadRegimeFromDisk() {
        if let data = UserDefaults.standard.data(forKey: regimePersistenceKey),
           let result = try? JSONDecoder().decode(ChironResult.self, from: data) {
            
            // VALIDATE: Ağırlık toplamı 0 ise bozuk veri - kullanma
            let pulseSum = result.pulseWeights.orion + result.pulseWeights.atlas + result.pulseWeights.aether
            let coreSum = result.coreWeights.orion + result.coreWeights.atlas + result.coreWeights.aether
            
            guard pulseSum > 0.01 && coreSum > 0.01 else {
                log("⚠️ Chiron: Disk'ten gelen ağırlıklar bozuk (toplam=0), default kullanılıyor.", level: .warning)
                // Bozuk veriyi siliyoruz
                UserDefaults.standard.removeObject(forKey: regimePersistenceKey)
                return
            }
            
            lock.lock()
            _lastGlobalResult = result
            lock.unlock()
            
            // Notify UI
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            print("💾 Chiron: Loaded last regime result from disk.")
        }
    }
    
    // MARK: - State Management (Global vs Local)
    
    // UI için Global Piyasa Durumu (Neural Link buna bağlanacak)
    private var _lastGlobalResult: ChironResult = ChironResult(
        regime: .neutral,
        coreWeights: ModuleWeights(atlas: 0.3, orion: 0.2, aether: 0.2, demeter: 0.1, phoenix: 0.1, hermes: 0.05, athena: 0.05),
        pulseWeights: ModuleWeights(atlas: 0.1, orion: 0.3, aether: 0.1, demeter: 0.1, phoenix: 0.2, hermes: 0.15, athena: 0.05),
        explanationTitle: "SİSTEM BAŞLATILIYOR",
        explanationBody: "Global analiz motoru veri akışını bekliyor...",
        learningNotes: []
    )
    
    // UI Erişimi
    public var globalResult: ChironResult {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastGlobalResult
        }
    }
    
    // Deprecated: Use globalResult for UI, or use return value for Logic
    public var lastResult: ChironResult { globalResult }
    
    // MARK: - Evaluation Methods
    
    /// Global Piyasa Analizi (Tek seferde tüm sistemi etkiler)
    /// Genellikle Aether (Makro) ve VIX değiştiğinde çağrılır.
    func evaluateGlobal(context: ChironContext) -> ChironResult {
        let result = internalEvaluate(context: context)
        
        lock.lock()
        _lastGlobalResult = result
        lock.unlock()
        
        saveRegimeToDisk(result)
        
        // UI'ı Güncelle
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        return result
    }
    
    /// Lokal Hisse Analizi (Sadece o hisse için karar üretir, Global UI'ı bozmaz)
    /// ArgusDecisionEngine tarafından her hisse için ayrı çağrılır.
    func evaluate(context: ChironContext) -> ChironResult {
        return internalEvaluate(context: context)
    }
    
    private func internalEvaluate(context: ChironContext) -> ChironResult {
        // 1. Detect Regime (Local or Global based on context)
        let regime = detectRegime(context: context)
        
        // 2. Select Base Weights
        var baseWeights = getBaseWeights(for: regime)
        
        // 2.1 Apply Dynamic Logic
        if let dynamic = determineDynamicWeights() {
            baseWeights.core = blend(w1: baseWeights.core, w2: dynamic.core, factor: 0.6)
            baseWeights.pulse = blend(w1: baseWeights.pulse, w2: dynamic.pulse, factor: 0.6)
        }
        
        // 3. Adjust for Availability
        let adjCore = adjustWeights(baseWeights.core, context: context)
        let adjPulse = adjustWeights(baseWeights.pulse, context: context)
        
        // 4. Normalize
        let finalCore = adjCore.normalized
        let finalPulse = adjPulse.normalized
        
        // 5. Generate Explanation
        let (title, body) = generateExplanation(regime: regime, context: context, finalCore: finalCore)
        
        return ChironResult(
            regime: regime,
            coreWeights: finalCore,
            pulseWeights: finalPulse,
            explanationTitle: title,
            explanationBody: body,
            learningNotes: dynamicConfig?.learningNotes
        )
    }
    
    // MARK: - Logic Internals
    
    private func detectRegime(context: ChironContext) -> MarketRegime {
        let orion = context.orionScore ?? 50
        let aether = context.aetherScore ?? 50
        // Demeter (Sector) is integrated via Aether Macro risk currently
        let hermes = context.hermesScore ?? 50
        let chop = context.chopIndex ?? 50
        let vol = context.volatilityHint ?? 0
        
        // 1. Risk-Off
        // Check Macro (Aether) and Volatility (Orion-based Vol or VIX)
        // Aether 30'un altındaysa (Kötü Makro) veya Volatilite 25'in üstündeyse (Yüksek Volatilite) Risk-Off
        if aether < 30 || vol > 25.0 { return .riskOff }
        
        // 2. News Shock
        if context.isHermesAvailable && hermes >= 75 { return .newsShock }
        
        // 3. Trend
        // Tuned: Lowered threshold to 60 to catch trends earlier
        if orion >= 60 && chop < 45 { return .trend }
        
        // 4. Chop
        if chop > 60 || (orion > 40 && orion < 60) { return .chop }
        
        return .neutral
    }
    
    private func getBaseWeights(for regime: MarketRegime) -> (core: ModuleWeights, pulse: ModuleWeights) {
        // Core: Long Term (Atlas, Aether, Demeter, Athena)
        // Pulse: Short Term (Orion, Phoenix, Hermes, Cronos)
        
        // Demeter (Sector) is usually Core/Strategic but can be Pulse/Tactical. Let's put it in Core.
        
        switch regime {
        case .neutral:
            return (
                core: ModuleWeights(atlas: 0.25, orion: 0.15, aether: 0.20, demeter: 0.15, phoenix: 0.05, hermes: 0.05, athena: 0.15),
                pulse: ModuleWeights(atlas: 0.05, orion: 0.25, aether: 0.10, demeter: 0.10, phoenix: 0.15, hermes: 0.20, athena: 0.05)
            )
        case .trend:
            return (
                core: ModuleWeights(atlas: 0.20, orion: 0.25, aether: 0.10, demeter: 0.15, phoenix: 0.20, hermes: 0.05, athena: 0.05),
                pulse: ModuleWeights(atlas: 0.0, orion: 0.35, aether: 0.05, demeter: 0.05, phoenix: 0.35, hermes: 0.10, athena: 0.0)
            )
        case .chop:
            return (
                core: ModuleWeights(atlas: 0.30, orion: 0.10, aether: 0.20, demeter: 0.20, phoenix: 0.05, hermes: 0.05, athena: 0.10),
                pulse: ModuleWeights(atlas: 0.10, orion: 0.10, aether: 0.20, demeter: 0.15, phoenix: 0.10, hermes: 0.10, athena: 0.10)
            )
        case .riskOff:
            return (
                core: ModuleWeights(atlas: 0.35, orion: 0.05, aether: 0.30, demeter: 0.15, phoenix: 0.0, hermes: 0.0, athena: 0.15),
                pulse: ModuleWeights(atlas: 0.20, orion: 0.05, aether: 0.40, demeter: 0.15, phoenix: 0.05, hermes: 0.05, athena: 0.10)
            )
        case .newsShock:
            return (
                core: ModuleWeights(atlas: 0.20, orion: 0.10, aether: 0.15, demeter: 0.10, phoenix: 0.05, hermes: 0.30, athena: 0.10),
                pulse: ModuleWeights(atlas: 0.0, orion: 0.10, aether: 0.10, demeter: 0.05, phoenix: 0.05, hermes: 0.50, athena: 0.0)
            )
        }
    }
    
    private func adjustWeights(_ weights: ModuleWeights, context: ChironContext) -> ModuleWeights {
        var wAtlas = weights.atlas
        var wOrion = weights.orion
        var wAether = weights.aether
        var wDemeter = weights.demeter ?? 0.0
        var wPhoenix = weights.phoenix ?? 0.0
        var wHermes = weights.hermes ?? 0.0
        var wAthena = weights.athena ?? 0.0
        
        // 1. Missing Hermes
        if !context.isHermesAvailable || context.hermesScore == nil {
            let redistributed = wHermes
            wHermes = 0
            wAether += redistributed * 0.30
            wDemeter += redistributed * 0.20
            wAtlas += redistributed * 0.25
            wOrion += redistributed * 0.25
        }
        
        // 2. Missing Scores = Zero Weight
        if context.atlasScore == nil { wAtlas = 0 }
        if context.orionScore == nil { wOrion = 0 }
        if context.aetherScore == nil { wAether = 0 }
        if context.demeterScore == nil { wDemeter = 0 }
        if context.phoenixScore == nil { wPhoenix = 0 }
        if context.athenaScore == nil { wAthena = 0 }
        
        return ModuleWeights(atlas: wAtlas, orion: wOrion, aether: wAether, demeter: wDemeter, phoenix: wPhoenix, hermes: wHermes, athena: wAthena)
    }
    
    private func generateExplanation(regime: MarketRegime, context: ChironContext, finalCore: ModuleWeights) -> (String, String) {
        var title = ""
        var body = ""
        
        switch regime {
        case .trend:
            title = "Adaptif Trend Modu – Akıllı Takip"
            body = "Orion ve Phoenix trendi teyit ediyor. FreqAI tabanlı adaptif ağırlıklandırma ile trend takipçileri (Orion) güçlendirildi."
        case .riskOff:
            title = "Risk-Off Modu – Defansif Duruş"
            body = "Volatilite veya Makro (Aether) riskleri yüksek. Sermayeyi korumak için Atlas ve Aether ağırlıklarını artırdım."
        case .chop:
            title = "Testere Modu – Temkinli Yaklaşım"
            body = "Piyasa kararsız. Yanıltıcı teknik sinyallerden kaçınmak için temel ve makro verilere odaklanıyorum."
        case .newsShock:
            title = "Haber Şoku – Hermes Devrede"
            body = "Güçlü haber akışı tespit edildi. Kısa vadeli hareketlerde Hermes'in etkisini artırdım."
        case .neutral:
            title = "Dengeli Piyasa – Standart Dağılım"
            body = "Piyasa koşulları normal seyrediyor. Standart ağırlık dağılımı uygulandı."
        }
        
        if !context.isHermesAvailable {
            body += " (Hermes verisi yok, ağırlığı diğer modüllere dağıtıldı.)"
        }
        
        return (title, body)
    }
    // MARK: - Dynamic Optimization
    
    private func blendWithDynamicConfig(base: (core: ModuleWeights, pulse: ModuleWeights), config: ChironOptimizationOutput, regime: MarketRegime) -> (core: ModuleWeights, pulse: ModuleWeights) {
        // Strategy:
        // Use a blend factor. 
        // 0.0 = Pure Hardcoded (Safe)
        // 1.0 = Pure AI Learned (Risky if AI hallucinates)
        // We use 0.5 to allow the AI to 'pull' the weights but keep the regime character.
        let blendFactor = 0.5
        
        // Extract Learned Weights (Global)
        // The optimization model uses nested structs, we map them to our internal ModuleWeights.
        // Note: ChironOptimizationModels struct names map: atlas, orion, etc.
        
        let learnedCore = config.newArgusWeights.core
        let learnedPulse = config.newArgusWeights.pulse
        
        let newCore = blend(w1: base.core, w2: learnedCore, factor: blendFactor)
        let newPulse = blend(w1: base.pulse, w2: learnedPulse, factor: blendFactor)
        
        return (newCore, newPulse)
    }
    
    private func blend(w1: ModuleWeights, w2: ModuleWeights, factor: Double) -> ModuleWeights {
        let d1 = w1.demeter ?? 0.0
        let d2 = w2.demeter ?? 0.0
        let p1 = w1.phoenix ?? 0.0
        let p2 = w2.phoenix ?? 0.0
        let h1 = w1.hermes ?? 0.0
        let h2 = w2.hermes ?? 0.0
        let ath1 = w1.athena ?? 0.0
        let ath2 = w2.athena ?? 0.0
        
        return ModuleWeights(
            atlas: w1.atlas * (1 - factor) + w2.atlas * factor,
            orion: w1.orion * (1 - factor) + w2.orion * factor,
            aether: w1.aether * (1 - factor) + w2.aether * factor,
            demeter: d1 * (1 - factor) + d2 * factor,
            phoenix: p1 * (1 - factor) + p2 * factor,
            hermes: h1 * (1 - factor) + h2 * factor,
            athena: ath1 * (1 - factor) + ath2 * factor
        )
    }

    // MARK: - Chiron Learning Logic (Pillar 8)
    
    /// Determines the optimal weight distribution based on history and market context (Adaptive Learning).
    private func determineDynamicWeights() -> (core: ModuleWeights, pulse: ModuleWeights)? {
        let logs = TradeLogStore.shared.fetchLogs()
        // let vix = MacroRegimeService.shared.getCurrentVix() ?? 20.0 (Unused for now) 
        
        // 1. Phase: Pain Awareness (Bleeding Check)
        // If portfolio is heavily bleeding, reduce exposure to high-beta (Pulse) modules.
        let portfolio = ArgusStorage.shared.loadPortfolio()
        let openTrades = portfolio.filter { $0.isOpen }
        let totalUnrealizedPnL = openTrades.reduce(0.0) { $0 + $1.profit }
        
        var (core, pulse) = calculateAdaptiveWeights(from: logs)
        
        if totalUnrealizedPnL < -20.0 { // Sensitivity Threshold
            print("🩸 Chiron Pain: Portfolio Bleeding (\(totalUnrealizedPnL))$. Reducing Pulse weights.")
            // Penalize Momentum/Pulse modules (Orion, Herems)
            let penaltyFactor = 0.7
            
            pulse = ModuleWeights(
                atlas: pulse.atlas * 1.5, // Shift to Safety
                orion: pulse.orion * penaltyFactor,
                aether: pulse.aether * 1.2,
                demeter: pulse.demeter,
                phoenix: pulse.phoenix,
                hermes: (pulse.hermes ?? 0.0) * penaltyFactor,
                athena: pulse.athena
            ).normalized
        }
        
        // 2. Phase: Market Condition Adaptation (FreqAI Style)
        // If historical trades show Orion failed in Chop markets, reduce Orion weight.
        // If Phoenix succeeded in Trend markets, boost Phoenix weight.
        
        // Simulating "Market State Awareness" from FreqAI logic
        // This acts as a multiplier based on recent Success Rate of modules
        let recentLogs = logs.suffix(20) // Look at last 20 trades
        if !recentLogs.isEmpty {
            let orionSuccess = recentLogs.filter { $0.entryOrionScore > 60 && $0.pnlPercent > 0 }.count
            let orionAttempts = recentLogs.filter { $0.entryOrionScore > 60 }.count
            
            if orionAttempts > 5 {
                let successRate = Double(orionSuccess) / Double(orionAttempts)
                if successRate > 0.6 {
                    pulse = ModuleWeights(
                        atlas: pulse.atlas,
                        orion: pulse.orion * 1.2, // Boost Orion
                        aether: pulse.aether,
                        demeter: pulse.demeter,
                        phoenix: pulse.phoenix,
                        hermes: pulse.hermes,
                        athena: pulse.athena
                    ).normalized
                    print("🧠 Chiron Adaptive: Orion is hot (Win Rate \(Int(successRate*100))%). Boosting weight.")
                } else if successRate < 0.4 {
                    pulse = ModuleWeights(
                        atlas: pulse.atlas,
                        orion: pulse.orion * 0.8, // Penalize Orion
                        aether: pulse.aether,
                        demeter: pulse.demeter,
                        phoenix: pulse.phoenix,
                        hermes: pulse.hermes,
                        athena: pulse.athena
                    ).normalized
                    print("🧠 Chiron Adaptive: Orion is cold (Win Rate \(Int(successRate*100))%). Reducing weight.")
                }
            }
        }

        // 3. Cold Start Bypass
        if logs.count < 10 {
           // Keep calculated defaults if low data
        }
        
        return (core, pulse)
    }
    
    /// Calculates weights based on past performance attribution.
    private func calculateAdaptiveWeights(from logs: [TradeLog]) -> (core: ModuleWeights, pulse: ModuleWeights) {
        var orionPnL = 0.0
        var atlasPnL = 0.0
        
        for log in logs {
            if log.entryOrionScore > 60 { orionPnL += log.pnlPercent }
            if log.entryAtlasScore > 60 { atlasPnL += log.pnlPercent }
        }
        
        let totalInfluence = abs(orionPnL) + abs(atlasPnL) + 0.001
        let orionShare = abs(orionPnL) / totalInfluence
        let atlasShare = abs(atlasPnL) / totalInfluence
        
        var targetOrion = max(0.2, min(0.6, orionShare)) // Cap Orion to 60%
        var targetAtlas = max(0.2, min(0.6, atlasShare))
        var targetPhoenix = 0.1 // Default Phoenix
        
        // MARK: - Backtest Cache Adaptive Weighting (NEW)
        // Read cached backtest results and adjust weights based on win rates
        // This runs synchronously but cache is pre-loaded
        // Note: Actor isolation workaround - we use a cached snapshot
        if let cachedOrionWinRate = ChironBacktestCache.shared.getOrionWinRate(),
           let cachedPhoenixWinRate = ChironBacktestCache.shared.getPhoenixWinRate() {
            
            // Boost Orion if backtest shows >60% win rate
            if cachedOrionWinRate > 60 {
                let boost = (cachedOrionWinRate - 60) / 100.0 * 0.2 // Max +0.08 boost
                targetOrion = min(0.7, targetOrion + boost)
                print("📈 Chiron: Orion backtest başarılı (\(Int(cachedOrionWinRate))%), ağırlık artırıldı: \(targetOrion)")
            } else if cachedOrionWinRate < 40 {
                targetOrion = max(0.1, targetOrion * 0.7) // Reduce by 30%
                print("📉 Chiron: Orion backtest zayıf (\(Int(cachedOrionWinRate))%), ağırlık azaltıldı: \(targetOrion)")
            }
            
            // Boost Phoenix if backtest shows >60% win rate
            if cachedPhoenixWinRate > 60 {
                let boost = (cachedPhoenixWinRate - 60) / 100.0 * 0.15
                targetPhoenix = min(0.3, targetPhoenix + boost)
                print("📈 Chiron: Phoenix backtest başarılı (\(Int(cachedPhoenixWinRate))%), ağırlık artırıldı: \(targetPhoenix)")
            } else if cachedPhoenixWinRate < 40 {
                targetPhoenix = max(0.0, targetPhoenix * 0.5)
                print("📉 Chiron: Phoenix backtest zayıf (\(Int(cachedPhoenixWinRate))%), ağırlık azaltıldı: \(targetPhoenix)")
            }
        }
        
        // Remainder for Supporting Modules (Aether, Demeter, Hermes, Athena)
        let remainder = max(0.0, 1.0 - (targetAtlas + targetOrion + targetPhoenix))
        
        // Distribution: Aether (40%), Demeter (20%), Hermes (20%), Athena (20%)
        let wAether = remainder * 0.40
        let wDemeter = remainder * 0.20
        let wHermes = remainder * 0.20
        let wAthena = remainder * 0.20
        
        let core = ModuleWeights(
            atlas: targetAtlas,
            orion: targetOrion,
            aether: wAether,
            demeter: wDemeter,
            phoenix: targetPhoenix,
            hermes: wHermes,
            athena: wAthena
        ).normalized
        
        let pulse = ModuleWeights(
            atlas: targetAtlas * 0.2,
            orion: targetOrion + 0.2,
            aether: wAether,
            demeter: wDemeter,
            phoenix: targetPhoenix + 0.1,
            hermes: wHermes + 0.1,
            athena: wAthena
        ).normalized
        
        return (core, pulse)
    }

    // MARK: - Chiron Risk Governor (R-Model)
    
    /// Audits a proposed trade against the Risk Budget (R-Model).
    /// - Parameters:
    ///   - aetherScore: The current Macro Score (0-100) to determine dynamic ceiling.
    func auditRisk(
        action: SignalAction,
        entryPrice: Double,
        stopLoss: Double?,
        quantity: Double,
        equity: Double,
        currentPortfolioRiskR: Double,
        aetherScore: Double // Aether remains Macro Risk Driver
    ) -> RiskGateResult {
        
        let maxRiskR = RiskBudgetConfig.dynamicMaxRiskR(aetherScore: aetherScore)
        
        // 1. Exemption: Closing acts (SELL/REDUCE) are always allowed (Risk Reduction).
        if action == .sell {
            return RiskGateResult(
                isApproved: true,
                riskBudgetR: currentPortfolioRiskR,
                deltaR: 0.0, // Sell strictly reduces or neutralizes
                maxR: maxRiskR,
                reason: "Satış işlemi risk düşürücüdür. Onaylandı."
            )
        }
        
        // 2. Calculate Delta R for this trade
        
        guard let sl = stopLoss, equity > 0 else {
            // Fallback: If no SL provided, assume worst case or block?
            // For now, let's assume a "Default Volatility Risk" of 5% distance if SL missing.
            let simulatedRiskAmt = entryPrice * 0.05 * quantity
            let simulatedR = (simulatedRiskAmt / equity) * 100
            
            return RiskGateResult(
                isApproved: false, // Default to FALSE to force SL
                riskBudgetR: currentPortfolioRiskR,
                deltaR: simulatedR,
                maxR: maxRiskR,
                reason: "Stop-Loss belirtilmediği için risk hesaplanamadı."
            )
        }
        
        let riskPerShare = max(0.0, entryPrice - sl)
        let totalRiskAmount = riskPerShare * quantity
        let deltaR = (totalRiskAmount / equity) * 100.0
        
        // 3. Evaluate Total Risk
        let potentialTotalR = currentPortfolioRiskR + deltaR
        
        if potentialTotalR > maxRiskR {
            return RiskGateResult(
                isApproved: false,
                riskBudgetR: currentPortfolioRiskR,
                deltaR: deltaR,
                maxR: maxRiskR,
                reason: "Risk Bütçesi Dolu: Mevcut \(String(format: "%.1f", currentPortfolioRiskR))R + Yeni \(String(format: "%.1f", deltaR))R > Limit \(maxRiskR)R (Makro Skor: \(Int(aetherScore)))"
            )
        }
        
        return RiskGateResult(
            isApproved: true,
            riskBudgetR: currentPortfolioRiskR,
            deltaR: deltaR,
            maxR: maxRiskR,
            reason: "Risk bütçesi uygun (\(String(format: "%.1f", potentialTotalR))R / \(maxRiskR)R)."
        )
    }
}

// MARK: - UI Helpers for ChironInsightsView
extension ChironRegimeEngine {
    
    /// Returns the learned Orion weights for a given symbol, or global defaults.
    /// Note: Maps older Optimization Model to newer Orion V2 Snapshot if needed.
    func getLearnedOrionWeights(symbol: String) -> OrionWeightSnapshot? {
        // 1. Try to find per-symbol override
        if let output = dynamicConfig,
           let overrides = output.perSymbolOverrides,
           let specific = overrides.first(where: { $0.symbol == symbol }) {
            
            // Map dictionary to Snapshot
            // Assuming dictionary keys match "trend", "momentum", etc.
            let dict = specific.orionLocalWeights
            return OrionWeightSnapshot(
                structure: dict["structure"] ?? 0.30,
                trend: dict["trend"] ?? 0.30,
                momentum: dict["momentum"] ?? 0.25,
                pattern: dict["pattern"] ?? 0.10,
                volatility: dict["volatility"] ?? 0.05
            ).normalized()
        }
        
        // 2. Global AI Weights
        if let output = dynamicConfig {
            let ai = output.newOrionWeights
            // Mapping AI (v1/1.5) to Orion V2
            // AI output treats 'relStrength' and others. We map available ones and default Structure/Pattern.
            return OrionWeightSnapshot(
                structure: 0.30, // Not currently optimized by AI Main Loop
                trend: ai.trend,
                momentum: ai.momentum,
                pattern: 0.10, // Not currently optimized
                volatility: ai.volatility
            ).normalized()
        }
        
        // 3. Fallback
        return OrionWeightSnapshot.default
    }
    
    /// Returns the learning status for UI display.
    /// Returns: (hasLearning, confidence 0-1, note)
    func getLearningStatus(symbol: String?) -> (Bool, Double, String) {
        let logs = TradeLogStore.shared.fetchLogs()
        
        if let sym = symbol {
            let symbolLogs = logs.filter { $0.symbol == sym }
            let count = symbolLogs.count
            
            if count < 5 {
                return (false, 0.0, "Yetersiz veri (\(count)/5 trade).")
            } else {
                let confidence = min(Double(count) / 20.0, 1.0)
                return (true, confidence, "\(count) işlem analiz edildi.")
            }
        } else {
            // Global Status
            let count = logs.count
            if count < 10 {
                return (false, 0.0, "Global havuzda yetersiz veri.")
            } else {
                let confidence = min(Double(count) / 50.0, 1.0)
                return (true, confidence, "Global havuz aktif (\(count) işlem).")
            }
        }
    }
}
