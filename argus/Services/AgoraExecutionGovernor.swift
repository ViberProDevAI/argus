import Foundation
import CryptoKit

/// AGORA: The Execution Governor
/// Denetçi katman. Sinyalleri "onaylar" veya "reddeder".
class AgoraExecutionGovernor {
    static let shared = AgoraExecutionGovernor()
    private let config = TradingGuardsConfig.shared
    
    private init() {}
    
    // Idempotency Cache: Key = SHA-256 Hash, Value = Timestamp
    private var processedSignals: [String: Date] = [:]
    
    // TTL for processed signals (15 minutes)
    private let signalTTL: TimeInterval = 15 * 60
    
    /// Cleans up expired signals from the cache.
    private func cleanupExpiredSignals() {
        let now = Date()
        processedSignals = processedSignals.filter { now.timeIntervalSince($0.value) < signalTTL }
    }
    
    /// Main Audit Function (Decision V2)
    /// Returns a Snapshot which contains the Action (Approved/Rejected) and the Explanation.
    func audit(
        decision: ArgusDecisionResult,
        currentPrice: Double,
        portfolio: [Trade],
        lastTradeTime: Date?,
        lastActionPrice: Double?
    ) -> DecisionSnapshot {
        
        // --- BIST DELEGATION (YERLİ VALİ) ---
        if let bistData = decision.bistDetails {
            return BistExecutionGovernor.shared.audit(
                decision: bistData,
                grandDecisionID: decision.id,
                currentPrice: currentPrice,
                portfolio: portfolio,
                lastTradeTime: lastTradeTime
            )
        }
        
        let symbol = decision.symbol
        let proposedAction = decision.finalActionCore // Base your audit on the Core action
        
        // 1. Build Base Context & Evidence
        var evidence: [SnapshotEvidence] = []
        
        // V2 Evidence: Rules, not just scores
        // Atlas Rule
        if decision.atlasScore > 60 {
            evidence.append(SnapshotEvidence(module: "Atlas", claim: "Güçlü Temel Veriler (Büyüme/Kârlılık)", confidence: decision.atlasScore/100.0, direction: "POSITIVE"))
        } else if decision.atlasScore < 40 {
             evidence.append(SnapshotEvidence(module: "Atlas", claim: "Zayıf Temel Görünüm", confidence: (100-decision.atlasScore)/100.0, direction: "NEGATIVE"))
        }
        
        // Orion Rule
        if decision.orionScore > 60 {
             evidence.append(SnapshotEvidence(module: "Orion", claim: "Yükseliş Trendi ve Pozitif Momentum", confidence: decision.orionScore/100.0, direction: "POSITIVE"))
        } else if decision.orionScore < 40 {
             evidence.append(SnapshotEvidence(module: "Orion", claim: "Düşüş Trendi veya Zayıf Momentum", confidence: (100-decision.orionScore)/100.0, direction: "NEGATIVE"))
        }
        
        // Aether / Regime Rule
        if decision.aetherScore > 60 {
            evidence.append(SnapshotEvidence(module: "Aether", claim: "Makro Risk İştahı Yüksek (Risk-On)", confidence: decision.aetherScore/100.0, direction: "POSITIVE"))
        } else if decision.aetherScore < 40 {
            evidence.append(SnapshotEvidence(module: "Aether", claim: "Makro Risk Algısı Negatif (Risk-Off)", confidence: (100-decision.aetherScore)/100.0, direction: "NEGATIVE"))
        }
        
        // Hermes Rule
        if decision.hermesScore > 60 {
            evidence.append(SnapshotEvidence(module: "Hermes", claim: "Haber Akışı Pozitif", confidence: decision.hermesScore/100.0, direction: "POSITIVE"))
        } else if decision.hermesScore > 0 && decision.hermesScore < 40 {
             evidence.append(SnapshotEvidence(module: "Hermes", claim: "Negatif Haber Akışı", confidence: (100-decision.hermesScore)/100.0, direction: "NEGATIVE"))
        }
        
        // Risk Context
        let riskContext = SnapshotRiskContext(
            regime: decision.chironResult?.regime.descriptor ?? "Unknown",
            aetherScore: decision.aetherScore,
            chironState: "Risk Active"
        )
        
        // Phoenix Integration
        var phSnapshot: PhoenixSnapshot? = nil
        if let ph = decision.phoenixAdvice {
            phSnapshot = PhoenixSnapshot(
                timeframe: ph.timeframe.rawValue,
                activeSignal: true,
                confidence: ph.confidence,
                lowerBand: ph.entryZoneLow ?? 0.0, // Mapping best effort
                upperBand: ph.entryZoneHigh ?? 0.0,
                midLine: ((ph.entryZoneLow ?? 0.0) + (ph.entryZoneHigh ?? 0.0))/2,
                distanceToLow: nil
            )
            
            // Add Evidence
            // "Seviye Haritası (Güven 78)" format requested
            evidence.append(SnapshotEvidence(
                module: "Phoenix",
                claim: "Seviye Haritası (Güven \(Int(ph.confidence))) - \(ph.reasonShort)",
                confidence: ph.confidence / 100.0,
                direction: ph.confidence >= 70 ? "POSITIVE" : (ph.confidence < 40 ? "NEGATIVE" : "NEUTRAL")
            ))
        }
        
        // 2. Check Locks (Churn Protection)
        var locks = AgoraLocksSnapshot(isLocked: false, reasons: [], cooldownUntil: nil, minHoldUntil: nil)
        var rejectionReason: String? = nil
        
        // IDEMPOTENCY CHECK (Signal Deduplication) - V2 with SHA-256
        // Build inputs digest from module scores
        let inputsDigest = SignalHasher.inputsDigest(
            atlas: decision.atlasScore,
            orion: decision.orionScore,
            aether: decision.aetherScore,
            hermes: decision.hermesScore,
            phoenix: decision.phoenixAdvice?.confidence
        )
        
        // Determine timeframe (default to "1h" if not available from Phoenix)
        let timeframe = decision.phoenixAdvice?.timeframe.yahooInterval ?? "1h"
        
        // Create deterministic SHA-256 hash
        let finalActionString = proposedAction == .buy ? "BUY" : (proposedAction == .sell ? "SELL" : "HOLD")
        let signalHash = SignalHasher.hash(
            symbol: symbol,
            timeframe: timeframe,
            barCloseTime: Date(), // Use current time rounded to minute
            action: finalActionString,
            inputsDigest: inputsDigest
        )
        
        // Cleanup expired signals before checking
        cleanupExpiredSignals()
        
        // Feature Flag Check
        if config.decisionV2Enabled && (proposedAction == .buy || proposedAction == .sell) {
             
            // Idempotency: Reject duplicate signals within TTL
            if let lastTime = processedSignals[signalHash], Date().timeIntervalSince(lastTime) < signalTTL {
                 locks = AgoraLocksSnapshot(isLocked: true, reasons: ["Duplicate Signal"], cooldownUntil: nil, minHoldUntil: nil)
                 rejectionReason = "Duplicate Signal: Already processed execution this block"
            } else {
                 // Register new signal
                 processedSignals[signalHash] = Date()
            }
            
            // If not already rejected by idempotency...
            if rejectionReason == nil, let lastTime = lastTradeTime {
                let timeSince = Date().timeIntervalSince(lastTime)
                
                // Cooldown (Anti-Churn)
                if timeSince < config.minTimeBetweenTradesSameSymbol {
                    // Locked!
                    let unlockDate = lastTime.addingTimeInterval(config.minTimeBetweenTradesSameSymbol)
                    locks = AgoraLocksSnapshot(isLocked: true, reasons: ["Cooldown"], cooldownUntil: unlockDate, minHoldUntil: locks.minHoldUntil)
                    rejectionReason = "Cooldown Active (Wait \(Int(config.minTimeBetweenTradesSameSymbol - timeSince))s)"
                }
                
                // Min Hold (for Sell)
                if proposedAction == .sell {
                    // Find oldest open
                     if let oldest = portfolio.filter({ $0.symbol == symbol && $0.isOpen }).sorted(by: { $0.entryDate < $1.entryDate }).first {
                        let holdTime = Date().timeIntervalSince(oldest.entryDate)
                        if holdTime < config.minHoldTime {
                             let unlockDate = oldest.entryDate.addingTimeInterval(config.minHoldTime)
                             locks = AgoraLocksSnapshot(isLocked: true, reasons: ["MinHold"], cooldownUntil: locks.cooldownUntil, minHoldUntil: unlockDate)
                             rejectionReason = "Minimum Hold Time Block (\(Int(config.minHoldTime - holdTime))s left)"
                        }
                    }
                }
                
                // Re-Entry Cooldown (for Buy)
                 if proposedAction == .buy {
                    if timeSince < config.cooldownAfterSell {
                        let unlockDate = lastTime.addingTimeInterval(config.cooldownAfterSell)
                        locks = AgoraLocksSnapshot(isLocked: true, reasons: ["ReEntryCooldown"], cooldownUntil: unlockDate, minHoldUntil: nil)
                        rejectionReason = "Re-Entry Cooldown (Wait \(Int(config.cooldownAfterSell - timeSince))s)"
                    }
                }
            }
        }
        
        // 3. Finalize Decision
        if let limitReason = rejectionReason {
            // Add Locking Evidence
            evidence.append(SnapshotEvidence(module: "Agora", claim: limitReason, confidence: 1.0, direction: "NEGATIVE"))
        }

        let oneLiner = rejectionReason != nil 
            ? "İşlem koruma kalkanına takıldı: \(rejectionReason!)"
            : (proposedAction == .hold ? "Bekle modunda." : "İşlem kriterleri karşılandı.")

        let conflicts = rejectionReason != nil ? [DecisionConflict(moduleA: "Argus", moduleB: "Agora", topic: "Lock", severity: 1.0)] : []
        
        return DecisionSnapshot(
            symbol: symbol,
            action: proposedAction,
            reason: oneLiner,
            evidence: evidence,
            riskContext: riskContext,
            locks: locks,
            phoenix: phSnapshot,
            standardizedOutputs: decision.standardizedOutputs,
            dominantSignals: [],
            conflicts: conflicts
        )
    }
}

// MARK: - BIST EXECUTION GOVERNOR (YERLİ VALİ)
class BistExecutionGovernor {
    static let shared = BistExecutionGovernor()
    private let config = TradingGuardsConfig.shared
    
    private init() {}
    
    func audit(
        decision: BistDecisionResult,
        grandDecisionID: UUID,
        currentPrice: Double,
        portfolio: [Trade],
        lastTradeTime: Date?
    ) -> DecisionSnapshot {
        // 1. Evidence Building (Data Storytelling map)
        var evidence: [SnapshotEvidence] = []
        
        let modules = [decision.grafik, decision.bilanco, decision.rejim, decision.faktor, decision.sektor, decision.akis, decision.kulis]
        
        for mod in modules {
            let direction = mod.supportLevel > 0.1 ? "POSITIVE" : (mod.supportLevel < -0.1 ? "NEGATIVE" : "NEUTRAL")
            evidence.append(SnapshotEvidence(
                module: mod.name,
                claim: mod.commentary,
                confidence: abs(mod.supportLevel), // 0-1 range approx
                direction: direction
            ))
        }
        
        // 2. BIST Specific Rules (The "Vali" Logic)
        var rejectionReason: String? = nil
        var locks = AgoraLocksSnapshot(isLocked: false, reasons: [], cooldownUntil: nil, minHoldUntil: nil)
        
        // Rule 1: Akış Veto (Yabancı kaçıyorsa alma)
        // Eğer aggressive buy ise ve akış < -0.5 ise durdur.
        if decision.action == .aggressiveBuy || decision.action == .accumulate {
            if decision.akis.supportLevel < -0.5 {
                rejectionReason = "Yabancı çıkışı var (Akış negatif), alım durduruldu."
            }
        }
        
        // Rule 2: Cooldown (BIST specific cooldown might be longer to prevent micro-trading)
        if let lastTime = lastTradeTime {
             let timeSince = Date().timeIntervalSince(lastTime)
             // BIST Cooldown: 15 mins (900s) default
             if timeSince < 900 {
                 let unlockDate = lastTime.addingTimeInterval(900)
                 locks = AgoraLocksSnapshot(isLocked: true, reasons: ["BistCooldown"], cooldownUntil: unlockDate, minHoldUntil: nil)
                 rejectionReason = "BIST Emir Soğuması (Kalan: \(Int(900 - timeSince))s)"
             }
        }
        
        // Rule 3: Konsey Güveni Yetersiz
        if decision.confidence < 25.0 && decision.action != .liquidate && decision.action != .neutral {
            rejectionReason = "Konsey güvenoyu yeterli değil (Güven: %\(Int(decision.confidence)))"
        }

        // Return Snapshot
        let oneLiner = rejectionReason ?? decision.reasoning.components(separatedBy: "\n").first ?? "İşlem onaylandı."
        
        // Map ArgusAction to SignalAction
        var mappedAction: SignalAction = .hold
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            mappedAction = .buy
        case .liquidate, .trim:
            mappedAction = .sell
        default:
            mappedAction = .hold
        }
        
        let finalAction = rejectionReason != nil ? .hold : mappedAction
        
        return DecisionSnapshot(
            symbol: decision.symbol,
            action: finalAction, // Override to Hold if rejected
            reason: rejectionReason != nil ? "VALİ VETOSU: \(rejectionReason!)" : oneLiner,
            evidence: evidence,
            riskContext: SnapshotRiskContext(regime: decision.rejim.commentary, aetherScore: decision.rejim.score, chironState: "BIST Active"),
            locks: locks,
            phoenix: nil,
            standardizedOutputs: [:],
            dominantSignals: [],
            conflicts: rejectionReason != nil ? [DecisionConflict(moduleA: "BistCouncil", moduleB: "BistGovernor", topic: "Veto", severity: 1.0)] : []
        )
    }
}
