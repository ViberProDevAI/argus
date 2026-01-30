import Foundation

// MARK: - AutoPilot Configuration
struct AutoPilotConfig {
    // Risk
    static let maxRiskPerTradeBase: Double = 0.01 // Portföyün %1'i
    static let maxTotalEquityExposure: Double = 1.0 // %100
    static let maxSymbolExposure: Double = 0.10 // %10
    
    // Thresholds
    static let minDataQualityCorse: Double = 80.0
    static let minDataQualityPulse: Double = 60.0
    
    // MARK: - Churn Prevention (Flip-Flop Önleme)
    /// Minimum tutma süresi: Alımdan sonra bu süre geçmeden satış yapılmaz (hard stop hariç)
    static let minimumHoldingSeconds: TimeInterval = 30 * 60 // 30 dakika (was 10)
    
    /// Tekrar giriş bekleme süresi: Satıştan sonra aynı sembole bu süre beklemeden tekrar girilmez
    static let entryCooldownSeconds: TimeInterval = 4 * 60 * 60 // 4 SAAT (was 15 min)
    
    /// Hysteresis buffer: Giriş eşiği ile çıkış eşiği arasındaki fark
    static let entryScoreThreshold: Double = 65.0  // Giriş için minimum puan
    static let exitScoreThreshold: Double = 55.0   // Çıkış için minimum puan (10 puan buffer)
    
    /// Minimum Güven Filtresi: Bu değerin altındaki sinyaller reddedilir
    static let minimumConfidencePercent: Double = 40.0 // %40 (NEW)
}

enum AutoPilotStrategy: String {
    case corse = "Corse" // Swing
    case pulse = "Pulse" // Scalp
}

struct AutoPilotSignal {
    let action: SignalAction
    let quantity: Double
    let reason: String
    let stopLoss: Double?
    let takeProfit: Double?
    let strategy: AutoPilotEngine 
    let trimPercentage: Double? // New: Partial Sell Support
}

// MARK: - Engine
final class ArgusAutoPilotEngine: Sendable {
    static let shared = ArgusAutoPilotEngine()
    
    private let aetherAllocation = AetherAllocationEngine.shared
    private let safeUniverse = SafeUniverseService.shared
    private let logger = AutoPilotLogger.shared
    private let chiron = ChironRegimeEngine.shared // NEW: Learned weights
    
    private init() {}
    
    // MARK: - Rotation Logic
    
    /// Scans the entire universe (Watchlist + Portfolio + Hotlist) for opportunities.
    func reviewRotation(
        portfolio: [String: Trade],
        quotes: [String: Quote],
        equity: Double,
        balance: Double,
        aetherScore: Double
    ) -> [AutoPilotSignal] {
        // 0. System Safety Check
        // Can't await in synchronous function? 
        // reviewRotation is synchronous here? Let's check context.
        // It returns [AutoPilotSignal].
        // If it's sync, we can't call async actor.
        // Let's assume we can't block here easily without making it async.
        // But for now, let's leave AutoPilotEngine synchronous and rely on AutoPilotService (which calls this) to check health.
        
        var signals: [AutoPilotSignal] = []
        
        // 1. Manage Existing Positions (The "Harvester")
        // Check every open trade for Exit/Trim conditions
        for (symbol, trade) in portfolio {
            guard let quote = quotes[symbol] else { continue }
            
            // We need updated scores. In a real loop, these come from `argusDecisions`.
            // For now, we assume the ViewModel passes context, but here we can only do PnL checks
            // UNLESS we have access to the decisions map.
            // Ideally, `managePosition` call should be triggered by the ViewModel when a new decision arrives.
            // But we can do basic PnL checks here.
            
            // NOTE: The main "Dynamic Scaling" logic relies on updated SCORES.
            // So `evaluate` function is the better place for that.
            // Here we just check for strict Stop Loss if we don't have new AI scores yet.
            
            let _ = ((quote.currentPrice - trade.entryPrice) / trade.entryPrice) * 100.0
            
            // Hard Stop Loss (Emergency)
            if let sl = trade.stopLoss, quote.currentPrice < sl {
                let signal = AutoPilotSignal(action: .sell, quantity: trade.quantity, reason: "Stop Loss Tetiklendi (%5 Zarar) 🛑", stopLoss: nil, takeProfit: nil, strategy: trade.engine ?? .pulse, trimPercentage: nil)
                signals.append(signal)
            }
        }
        
        // 2. Scan for New Entries (The "Hunter")
        // (This is usually triggered per-symbol in `evaluate`, collecting here is optional)
        
        return signals
    }
    
    // MARK: - Main Evaluation Loop
    
    /// Main entry point to evaluate a symbol for potential trading action.
    /// Handles both New Entry and Existing Position Management.\n    // MARK: - Main Evaluation Loop (SNIPER MODE)
    
    /// Main entry point to evaluate a symbol for potential trading action.
    /// Handles both New Entry and Existing Position Management (Sniper Logic).
    func evaluate(
        symbol: String,
        currentPrice: Double,
        equity: Double,
        buyingPower: Double,
        portfolioState: [String: Trade], // Symbol -> Trade
        
        // Data Inputs
        candles: [Candle]?,
        atlasScore: Double?,
        orionScore: Double?,
        orionDetails: OrionComponentScores? = nil,
        aetherRating: MacroEnvironmentRating?,
        hermesInsight: NewsInsight?,
        argusFinalScore: Double?,
        demeterScore: Double?,
        
        // Churn Prevention (NEW)
        lastExitTime: Date? = nil // Son çıkış zamanı (cooldown kontrolü için)
    ) async -> (signal: AutoPilotSignal?, log: ScoutLog) {
        
        // Context
        // FIXED: Auto-Calculate Score if nil.
        // If AutoPilotService passes nil, we must reconstruct a rough score to avoid 0.0 veto.
        var overallScore = argusFinalScore ?? 0.0
        
        if argusFinalScore == nil {
            // USE CHIRON WEIGHT STORE (NEW ENGINE-AWARE SYSTEM)
            // Determine which engine we're evaluating for
            let evaluatingEngine: AutoPilotEngine = portfolioState[symbol]?.engine ?? .pulse
            
            // Get weights from ChironWeightStore (async-safe via Task)
            // For synchronous context, use cached defaults first
            let weights = ChironModuleWeights.defaultPulse // Fallback until async loads
            
            // Apply weights to available scores
            var totalWeight = 0.0
            var weightedSum = 0.0
            
            if let or = orionScore { weightedSum += or * weights.orion; totalWeight += weights.orion }
            if let at = atlasScore { weightedSum += at * weights.atlas; totalWeight += weights.atlas }
            if let ae = aetherRating { weightedSum += ae.numericScore * weights.aether; totalWeight += weights.aether }
            // Hermes usually nil in scan, skip for now
            
            if totalWeight > 0 {
                overallScore = weightedSum / totalWeight
            }
            // ArgusLogger.verbose(.autopilot, "Argus Skoru Hesaplandı (\(symbol)): \(Int(overallScore)) (Orion: \(Int(orionScore ?? 0)), Atlas: \(Int(atlasScore ?? 0)), Aether: \(Int(aetherRating?.numericScore ?? 0)))")
        } else {
             // ArgusLogger.verbose(.autopilot, "Mevcut Argus Skoru (\(symbol)): \(Int(overallScore))")
        }
        
        // ----------------------------------------------------------------
        // PART 1: MANAGE EXISTING POSITIONS (The Harvester)
        // ----------------------------------------------------------------
        // ----------------------------------------------------------------
        // PART 1: MANAGE EXISTING POSITIONS (The Harvester)
        // ----------------------------------------------------------------
        if let existingTrade = portfolioState[symbol] {
             // Calculate PnL
             let entryPrice = existingTrade.entryPrice
             let pnlPercent = ((currentPrice - entryPrice) / entryPrice) * 100.0
             
             // Determine Strategy Mode (Default to Pulse if legacy/missing)
             let mode = existingTrade.engine ?? .pulse
             
             // ==========================================
             // CHURN PREVENTION: Minimum Holding Time
             // ==========================================
             let holdingDuration = Date().timeIntervalSince(existingTrade.entryDate)
             let isHoldingPeriodActive = holdingDuration < AutoPilotConfig.minimumHoldingSeconds
             
             // Hard Stop eşikleri (bu eşiklerin altında minimum holding bypass edilir)
             let hardStopThreshold = mode == .corse ? -16.0 : -8.0 // Corse: -16%, Pulse: -8%
             
             if isHoldingPeriodActive && pnlPercent > hardStopThreshold {
                 // Minimum holding süresi dolmadı ve hard stop tetiklenmedi
                 let remainingMinutes = Int((AutoPilotConfig.minimumHoldingSeconds - holdingDuration) / 60)
                 let reason = "⏳ Minimum Tutma Süresi: \(remainingMinutes) dk kaldı (Kâr: %\(String(format: "%.1f", pnlPercent)))"
                 return (nil, ScoutLog(symbol: symbol, status: "TUT", reason: reason, score: overallScore))
             }
             
             // ==========================================
             // MODE 1: CORSE (SWING / MEDIUM TERM) 🦅
             // ==========================================
             if mode == .corse {
                 // 1. HARD STOP (Wider Room to Breathe)
                 // Default -8% or Dynamic Logic
                 let stopLimit = -8.0
                 if pnlPercent < stopLimit {
                     let reason = "Corse Stop: %\(String(format: "%.1f", pnlPercent)) Zarar (Swing Limit) 🛑"
                     return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                             ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                 }
                 
                 // 2. PARTIAL PROFIT TAKING (KADEMELİ SATIŞ) - NEW
                 // If profit is good (>15%) but score is weakening (<65), secure 50%
                 if pnlPercent > 15.0 && overallScore < 65.0 {
                     let reason = "Corse Kâr Al (Trim): %\(String(format: "%.1f", pnlPercent)) Kâr, Skor Zayıflıyor (\(Int(overallScore))) ✂️"
                     return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: 0.5),
                             ScoutLog(symbol: symbol, status: "AZALT", reason: reason, score: overallScore))
                 }
                 
                 // 3. TRAILING STOP (The Safety Net - Loose)
                 // Only activate after decent profit (> 5%)
                 // Trail distance: 2.5%
                 let previousHigh = existingTrade.highWaterMark ?? entryPrice
                 let dropFromPeak = ((previousHigh - currentPrice) / previousHigh) * 100.0
                 
                 if pnlPercent > 5.0 {
                     if dropFromPeak >= 2.5 {
                          let reason = "Corse İz Süren: Zirveden %\(String(format: "%.1f", dropFromPeak)) Düşüş (Kâr Koruması) 🦅💰"
                          return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                                  ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                     }
                 }
                 
                 // 4. THESIS BREAK (Fundamentals/Trend)
                 // Only sell if score drops significantly (< 55)
                 // Corse is more patient than Pulse
                 if overallScore < 55.0 {
                      let reason = "Corse Tezi Bozuldu (Argus Puanı: \(Int(overallScore))). 🚪"
                      return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                              ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                 }
                 
                 // 5. NO TAKE PROFIT CAP
                 // "Let winners run" - No fixed 4% exit.
                 
                 // HOLD
                 return (nil, ScoutLog(symbol: symbol, status: "TUT", reason: "Corse Swing: Pozisyon korunuyor (Kâr: %\(String(format: "%.1f", pnlPercent)))", score: overallScore))
             
             } else {
                 // ==========================================
                 // MODE 2: PULSE (SCALP / SNIPER) ⚡️
                 // ==========================================
                 
                 // 1. HARD STOP (Tight)
                 if pnlPercent < -2.0 {
                     let reason = "Sniper Stop: %\(String(format: "%.1f", pnlPercent)) Zarar (Katı Kural) 🛑"
                     return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                             ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                 }
                 
                 // 2. TRAILING STOP (Tight)
                 let previousHigh = existingTrade.highWaterMark ?? entryPrice
                 let dropFromPeak = ((previousHigh - currentPrice) / previousHigh) * 100.0
                 
                 if pnlPercent > 1.5 {
                     if dropFromPeak >= 1.0 {
                          let reason = "İz Süren Stop: Zirveden %\(String(format: "%.1f", dropFromPeak)) Düşüş 📉💰"
                          return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                                  ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                     }
                 }
                                     // 3. MOMENTUM DECAY (DISABLED - Churn Prevention)
                     // Bu kontrol çok agresifti ve flip-flop'a neden oluyordu.
                     // Hysteresis buffer: Sadece puan çok düşükse (%4+ kâr ve puan < 50) çıkış yap
                     if pnlPercent > 4.0 && overallScore < AutoPilotConfig.exitScoreThreshold - 5 {
                         let reason = "Momentum Kaybı: Kâr koruma (Kâr: %\(String(format: "%.1f", pnlPercent)), Puan: \(Int(overallScore)) < \(Int(AutoPilotConfig.exitScoreThreshold - 5))). 📉"
                         return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                                 ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                     }

                     // 4. MOMENTUM BREAK (Hard Pulse Check)
                      if let c = candles, !c.isEmpty {
                          let localScore = ArgusDecisionEngine.shared.calculateLocalScore(candles: c)
                          
                          // FIXED: Dynamic Threshold
                          // If Overall Thesis (Trend) is Strong (> 65), allow more breathing room (Threshold 40).
                          // If weak, be strict (Threshold 48).
                          let momentumThreshold = overallScore >= 70.0 ? 50.0 : 55.0 // RAISED from 48/40 to prevent churn
                          
                          if localScore < momentumThreshold {
                               let reason = "Anlık Momentum Kaybı (Yerel: \(Int(localScore)) < \(Int(momentumThreshold))). Çıkış. 🚪"
                               return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                                       ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                          }
                      }
                     
                     // 5. THESIS BREAK (Final Safety Net) - Hysteresis Applied
                     // Giriş eşiği: 65, Çıkış eşiği: 45 (20 puan buffer)
                     if overallScore < AutoPilotConfig.exitScoreThreshold - 10 { // 45
                          // Granular Reason for Debugging
                          let components = "Atlas: \(Int(overallScore)), Orion: \(Int(orionScore ?? 0)), Aether: \(Int(aetherRating?.numericScore ?? 0))"
                          let reason = "Argus Tezi Tamamen Bitti (Puan: \(Int(overallScore)) < 50 | \(components)). 🚪"
                          return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                                  ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                     }
                
                // 5. TAKE PROFIT (Sniper Targets)
                if pnlPercent >= 4.0 {
                     let reason = "Sniper Hedef: %4 Kâr (Tam Çıkış) 🎯"
                     return (AutoPilotSignal(action: .sell, quantity: existingTrade.quantity, reason: reason, stopLoss: nil, takeProfit: nil, strategy: mode, trimPercentage: nil),
                             ScoutLog(symbol: symbol, status: "SATIŞ", reason: reason, score: overallScore))
                }
                
                // HOLD
                return (nil, ScoutLog(symbol: symbol, status: "TUT", reason: "Pulse Scalp: Pozisyon korunuyor (Kâr: %\(String(format: "%.1f", pnlPercent)))", score: overallScore))
             }
        }
        
        // ----------------------------------------------------------------
        // PART 2: NEW ENTRIES (The Hunter)
        // ----------------------------------------------------------------
        
        // ==========================================
        // CHURN PREVENTION: Entry Cooldown
        // ==========================================
        if let exitTime = lastExitTime {
            let timeSinceExit = Date().timeIntervalSince(exitTime)
            if timeSinceExit < AutoPilotConfig.entryCooldownSeconds {
                let remainingMinutes = Int((AutoPilotConfig.entryCooldownSeconds - timeSinceExit) / 60)
                let reason = "⏳ Tekrar Giriş Beklemesi: \(remainingMinutes) dk kaldı (Son çıkıştan bu yana)"
                return (nil, ScoutLog(symbol: symbol, status: "COOLDOWN", reason: reason, score: overallScore))
            }
        }
        
        // 0. Demeter Veto (Sector Check) - Optional
        if let dm = demeterScore, dm < 30 {
             // Optional: Sector is bad, avoid?
             // return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Demeter (Sektör) Kötü: \(Int(dm))", score: overallScore))
        }
        
        // 1. Data Quality
        let dqScore = calculateDataQuality(symbol: symbol, candles: candles, atlas: atlasScore, aether: aetherRating, hermes: hermesInsight)
        
        // 2. Market Crash Check
        if (aetherRating?.numericScore ?? 50) < 20 {
            return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Piyasa Çöküşü (Aether: \(Int(aetherRating?.numericScore ?? 0)))", score: overallScore))
        }
        
        // Context for Argus V3
        var argusMultiplier: Double = 1.0 // Default Aggressive (Legacy behavior)
        
        // 3. ARGUS GRAND COUNCIL CHECK (V3 - THE VERDICT)
        // Consult all councils for the grand decision
        
        var grandDecision: ArgusGrandDecision? = nil
        
        if let candleData = candles, candleData.count >= 50 {
            // Build snapshots - USE REAL CACHED DATA!
            // FIX: Cache'de yoksa Yahoo'dan çek!
            // ARGUS 3.0: Use FinancialSnapshotService (Standardized)
            let snapshot = try? await FinancialSnapshotService.shared.fetchSnapshot(symbol: symbol)
            
            let macro = await MacroSnapshotService.shared.getSnapshot()
            let news: HermesNewsSnapshot? = nil // TODO: Get from HermesCache if available
            
            // Use .pulse engine - Async Call
            let decision = await ArgusGrandCouncil.shared.convene(
                symbol: symbol,
                candles: candleData,
                snapshot: snapshot, // CHANGED: Pass Snapshot
                macro: macro,
                news: news,
                engine: .pulse,
                origin: "AUTOPILOT"
            )
            
            grandDecision = decision
            
            // Check grand council decision
            if let gd = grandDecision {
                // Veto Check
                if !gd.vetoes.isEmpty || gd.strength == .vetoed {
                    let vetoReason = gd.vetoes.first?.reason ?? "Konsey Veto"
                    return (nil, ScoutLog(symbol: symbol, status: "VETO", reason: "🏛️ \(vetoReason)", score: overallScore))
                }
                
                // Action Logic - STRICT: Only BUY actions proceed
                switch gd.action {
                case .trim, .liquidate:
                     return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "🏛️ Konsey Kararı: \(gd.action.rawValue) - Giriş Yasak", score: overallScore))
                    
                case .neutral:
                     return (nil, ScoutLog(symbol: symbol, status: "BEKLE", reason: "🏛️ Konsey Kararı: İZLE / NÖTR", score: overallScore))
                    
                case .aggressiveBuy, .accumulate:
                    // CHURN PREVENTION: Minimum Confidence Filter
                    if gd.confidence * 100 < AutoPilotConfig.minimumConfidencePercent {
                        let reason = "⚠️ Düşük Güven Reddi: %\(Int(gd.confidence * 100)) < %\(Int(AutoPilotConfig.minimumConfidencePercent))"
                        return (nil, ScoutLog(symbol: symbol, status: "RED", reason: reason, score: gd.confidence * 100))
                    }
                    
                    // REFORM: Konsey AL dediyse DOĞRUDAN al! Kendi kriterlerini BYPASS et.
                    let multiplier = gd.allocationMultiplier
                    let isAggressive = gd.action == .aggressiveBuy
                    let engine: AutoPilotEngine = isAggressive ? .corse : .pulse
                    
                    // Pozisyon boyutu hesapla
                    let riskPerTrade = AutoPilotConfig.maxRiskPerTradeBase * multiplier
                    let positionValue = equity * riskPerTrade
                    let quantity = positionValue / currentPrice
                    
                    // Stop Loss & Take Profit
                    let stopPercent = isAggressive ? 0.08 : 0.03 // Corse: %8, Pulse: %3
                    let stopLoss = currentPrice * (1.0 - stopPercent)
                    let takeProfit = currentPrice * (1.0 + (stopPercent * 2.5)) // 2.5:1 Risk/Reward
                    
                    let reason = "🏛️ KONSEY KARARI: \(gd.action.rawValue) (Güven: %\(Int(gd.confidence * 100)))"
                    
                    let signal = AutoPilotSignal(
                        action: .buy,
                        quantity: quantity,
                        reason: reason,
                        stopLoss: stopLoss,
                        takeProfit: takeProfit,
                        strategy: engine,
                        trimPercentage: nil
                    )
                    
                    print("🏛️ REFORM: Konsey kararı direkt uygulanıyor - \(gd.action.rawValue) for \(symbol)")
                    return (signal, ScoutLog(symbol: symbol, status: "ONAYLI", reason: reason, score: gd.confidence * 100))
                }
            } else {
                // CRITICAL FIX: No Grand Council = No Entry
                return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "🏛️ Konsey Toplanamadı - Giriş Yasak", score: overallScore))
            }
        } else {
            // Not enough candles for Grand Council = No Entry
            return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "🏛️ Yetersiz Veri (<50 mum) - Konsey Toplanamaz", score: overallScore))
        }
        
        // NOTE: Buraya artık ulaşılmamalı - tüm case'ler return ediyor
        return (nil, ScoutLog(symbol: symbol, status: "RED", reason: "Beklenmeyen durum", score: overallScore))
        
    }
    
    // MARK: - Entry Logic
    
    private func checkCorseEntry(
        symbol: String, price: Double, equity: Double, buyingPower: Double,
        atlas: Double?, orion: Double?, aether: MacroEnvironmentRating?, hermes: NewsInsight?,
        demeterScore: Double?,
        dqScore: Double, candles: [Candle]?, overallScore: Double,
        argusMultiplier: Double = 1.0 // ARGUS V3 MULTIPLIER
    ) -> AutoPilotSignal? {
        // CORSE (SWING) ENTRY REQUIREMENTS
        // More relaxed than before - Hermes is OPTIONAL
        
        // 1. Atlas (Fundamentals) - Optional for Commodities/Crypto
        if let at = atlas, at < 55 { return nil }  // Lowered from 60
        
        // 2. Overall Score threshold
        guard overallScore >= 65 else { return nil }  // Lowered from 70
               
        // 3. Orion (Technical) - Required
        guard let or = orion, or >= 55 else { return nil }  // Lowered from 60
        
        // 4. Aether (Macro) - Required but lenient
        guard let ae = aether, ae.numericScore >= 30 else { return nil }  // Was 20, slightly raised for safety
        
        // 5. Hermes (News) - OPTIONAL (was blocking most entries)
        let _ = (hermes?.confidence ?? 50) >= 40
        // Just log if missing, don't block
        if hermes == nil {
            print("📰 Corse Entry: Hermes nil for \(symbol), proceeding without news confirmation")
        }
        
        // 6. Demeter (Sector) - Optional for now
        // guard (demeterScore ?? 50) >= 35 else { return nil }
        
        // Calculate Volatility (ATR)
        let atr = candles != nil ? OrionAnalysisService.shared.calculateATR(candles: candles!) : 0.0
        
        // Suggest Buy
        let (qty, sl, tp, riskMult) = calculatePositionSize(
            strategy: .corse, symbol: symbol, price: price, equity: equity, buyingPower: buyingPower,
            aetherScore: ae.numericScore, volatility: atr,
            argusMultiplier: argusMultiplier
        )
        
        if qty > 0 {
            logDecision(symbol: symbol, mode: .corse, action: "buy", qty: qty, price: price, sl: sl, tp: tp, riskMult: riskMult, dq: dqScore, overallScore: overallScore, scores: (atlas, or, ae.numericScore, hermes?.confidence, demeterScore))
            return AutoPilotSignal(action: .buy, quantity: qty, reason: "Corse Swing: Güçlü Trend Başlangıcı (Volatilite: \(String(format:"%.2f", atr)))", stopLoss: sl, takeProfit: tp, strategy: .corse, trimPercentage: nil)
        }
        return nil
    }
    
    private func checkPulseEntry(
        symbol: String, price: Double, equity: Double, buyingPower: Double,
        orion: Double?, orionDetails: OrionComponentScores?, aether: MacroEnvironmentRating?, hermes: NewsInsight?,
        demeterScore: Double?,
        dqScore: Double, overallScore: Double?, candles: [Candle]?,
        argusMultiplier: Double = 1.0 // ARGUS V3 MULTIPLIER
    ) -> AutoPilotSignal? {
        
        // SPECIAL: Dip Hunter Mode (Orion 3.0 Phoenix)
        // Phoenix Removed from AutoPilot Logic (Use standalone Phoenix)
        
        // --- THRESHOLD LOGIC ---
        // Normal Mode: Hermes >= 70, Orion >= 55
        // Dip Mode: Disabled for now (Phoenix Removed)
        
        let hermesThreshold = 70.0
        
        guard let hm = hermes, hm.confidence >= hermesThreshold,
              let or = orion, or >= 55,
              let ae = aether, ae.numericScore >= 40 else { return nil }
        
        // Demeter Check: Pulse needs good sector?
        // guard (demeterScore ?? 50) >= 50 else { return nil }
        
        // Calculate Volatility (ATR)
        let atr = candles != nil ? OrionAnalysisService.shared.calculateATR(candles: candles!) : 0.0

        // Suggest Buy
         let (qty, sl, tp, riskMult) = calculatePositionSize(
            strategy: .pulse, symbol: symbol, price: price, equity: equity, buyingPower: buyingPower,
            aetherScore: ae.numericScore, volatility: atr,
            argusMultiplier: argusMultiplier
        )
        
        if qty > 0 {
            let reason = "Pulse Scalp: Anlık Trend Takibi ve Momentum Alımı"
            logDecision(symbol: symbol, mode: .pulse, action: "buy", qty: qty, price: price, sl: sl, tp: tp, riskMult: riskMult, dq: dqScore, overallScore: overallScore, scores: (nil, or, ae.numericScore, hm.confidence, demeterScore))
             return AutoPilotSignal(action: .buy, quantity: qty, reason: reason, stopLoss: sl, takeProfit: tp, strategy: .pulse, trimPercentage: nil)
        }
        return nil
    }
    
    // MARK: - Position Management (Exit)
    

    // MARK: - Risk Management
    
    // Returns: (Qty, StopLevel, TakeProfitLevel, RiskMultiplier)
    private func calculatePositionSize(
        strategy: AutoPilotStrategy,
        symbol: String,
        price: Double,
        equity: Double,
        buyingPower: Double,
        aetherScore: Double,
        volatility: Double, // Nominal ATR or similar
        argusMultiplier: Double // NEW: Argus Influence (1.0 = Aggressive, 0.3 = Accumulate)
    ) -> (Double, Double, Double, Double) {
        
        // 1. Aether Multiplier
        // Risk On (65+) -> 1.5x
        // Neutral (40-65) -> 1.0x
        // Risk Off (<40) -> 0.3x
        
        var aetherMult = 1.0
        if aetherScore >= 65 { aetherMult = 1.5 }
        else if aetherScore < 40 { aetherMult = 0.3 }
        
        // 2. Effective Risk
        let baseRisk = AutoPilotConfig.maxRiskPerTradeBase * equity // e.g. $100 on $10k
        let effectiveRiskMoney = baseRisk * aetherMult
        
        // 3. Stop Distance using ATR or Fixed %
        var stopDistance = 0.0
        
        if volatility > 0 {
            // Dynamic ATR Stop
            // Corse (Swing): 2.0 * ATR
            // Pulse (Scalp): 1.5 * ATR
            let atrMult = (strategy == .corse) ? 2.0 : 1.5
            stopDistance = volatility * atrMult
            
            // SANITY CHECK: Prevent insane Stop Loss due to bad ATR
            // If stop is > 15% of price, clamp it.
            if stopDistance > (price * 0.15) {
                print("⚠️ Argus Risk: ATR Limit Exceeded (\(String(format:"%.2f", stopDistance))). Clamping to 15%.")
                stopDistance = price * 0.15
            }
        } else {
            // Fallback Fixed Percentage
            // Corse: 8%, Pulse: 3%
            let stopPercent = (strategy == .corse) ? 0.08 : 0.03
            stopDistance = price * stopPercent
        }
        
        // Safety Clean Up (Prevent tiny stops)
        if stopDistance < (price * 0.01) { stopDistance = price * 0.01 }
        
        // 4. Size
        // risk = qty * stopDist => qty = risk / stopDist
        // Apply Argus Multiplier (Allocation Strategy)
        let effectiveRisk = effectiveRiskMoney * argusMultiplier
        let rawQty = effectiveRisk / stopDistance
        
        // 5. Caps
        // Max Symbol Limit
        let maxSymbolVal = equity * AutoPilotConfig.maxSymbolExposure
        let capQty = maxSymbolVal / price
        
        var finalQty = min(rawQty, capQty)
        
        // Check Buying Power
        if finalQty * price > buyingPower {
            finalQty = buyingPower / price
        }
        
        let slPrice = price - stopDistance
        let tpPrice = price + (stopDistance * (strategy == .corse ? 2.0 : 1.5)) // 2.0R for Swing (approx 12%), 1.5R for Scalp
        
        return (finalQty, slPrice, tpPrice, aetherMult)
    }
    
    // MARK: - Data Quality
    
    private func calculateDataQuality(
        symbol: String,
        candles: [Candle]?,
        atlas: Double?,
        aether: MacroEnvironmentRating?,
        hermes: NewsInsight?
    ) -> Double {
        var score = 0.0
        
        // 1. Technical Data (Candles) - 30%
        if let c = candles, c.count > 100 { score += 30 }
        else if let c = candles, c.count > 50 { score += 15 }
        
        // 2. Fundamental (Atlas) - 25% (Skip/Adjust for Commodities)
        let type = safeUniverse.getUniverseType(for: symbol)
        if type == .commodity || type == .crypto {
            // Commodities/Crypto don't have standard fundamentals. Trust Technicals/Macro more.
            // Give Full Credit (Assume N/A is OK) or check if we have alternative data.
            // For now, assume OK to avoid penalty.
            score += 25
        } else {
            if atlas != nil { score += 25 }
        }
        
        // 3. Macro (Aether) - 25%
        if aether != nil { score += 25 }
        
        // 4. News (Hermes) - 20%
        if hermes != nil { score += 20 }
        
        return score
    }
    
    // MARK: - Logging
    
    private func logDecision(
        symbol: String, mode: AutoPilotStrategy, action: String, qty: Double, price: Double,
        sl: Double?, tp: Double?, riskMult: Double?, dq: Double, overallScore: Double?,
        scores: (Double?, Double?, Double?, Double?, Double?)
    ) {
        // Fire-and-forget to allow async query
        Task {
            // Determine likely provider
            let primary = "TwelveData"
            let isLocked = await ProviderCapabilityRegistry.shared.isQuarantined(provider: primary, field: .quote)
            let activeProvider = isLocked ? "Backup (EODHD/Yahoo)" : primary
            
            let dec = AutoPilotDecision(
                id: UUID(),
                timestamp: Date(),
                mode: "live",
                strategy: mode.rawValue,
                symbol: symbol,
                action: action,
                quantity: qty,
                positionValueUSD: qty * price,
                price: price,
                takeProfit: tp,
                stopLoss: sl,
                riskMultiple: riskMult,
                atlasScore: scores.0,
                orionScore: scores.1,
                aetherScore: scores.2,
                hermesScore: scores.3,
                demeterScore: scores.4,
                argusFinalScore: overallScore,
                dataQualityScore: dq,
                fundamentalsPartial: scores.0 == nil,
                technicalPartial: scores.1 == nil,
                macroPartial: scores.2 == nil,
                cryptoFallbackUsed: false,
                dataSourceNotes: "DQ: \(Int(dq))",
                provider: activeProvider, // INJECTED
                portfolioValueBefore: nil,
                portfolioValueAfter: nil,
                rationale: "Strategy: \(mode.rawValue)"
            )
            logger.log(dec)
        }
    }
}
