import Foundation

/// Strategy pattern for different decision-making approaches
protocol DecisionStrategy {
    func evaluate(
        leader: ModuleOpinion,
        allOpinions: [ModuleOpinion],
        config: ArgusConfig,
        consensusScore: Double,
        consensusQuality: Double
    ) -> (action: SignalAction, isApproved: Bool, rationale: String, sizeR: Double)
}

/// Standard consensus-based decision strategy
struct StandardConsensusStrategy: DecisionStrategy {
    func evaluate(
        leader: ModuleOpinion,
        allOpinions: [ModuleOpinion],
        config: ArgusConfig,
        consensusScore: Double,
        consensusQuality: Double
    ) -> (action: SignalAction, isApproved: Bool, rationale: String, sizeR: Double) {
        let supporters = allOpinions.filter { $0.stance == .support }
        let objectors = allOpinions.filter { $0.stance == .object }
        let claimAction = leader.preferredAction
        
        func determineTier(score: Double, isBuy: Bool, quality: Double) -> (tier: String, size: Double, approved: Bool) {
            let s = isBuy ? score : (100.0 - score)
            
            if quality < config.qualityGateMinimum {
                return ("RED (Düşük Veri Kalitesi: \(Int(quality*100))%)", 0.0, false)
            }
            
            let maxTierAllowed = (quality >= config.qualityGateTier1) ? 1 : (quality >= config.qualityGateTier2 ? 2 : 3)
            
            if s >= config.tier1Threshold {
                if maxTierAllowed <= 1 { return ("BANKO (Tier 1)", 1.0, true) }
                return ("BANKO -> STANDART (Veri Kalitesi Düşük)", 0.5, true)
            }
            if s >= config.tier2Threshold {
                if maxTierAllowed <= 2 { return ("STANDART (Tier 2)", 0.5, true) }
                return ("STANDART -> SPEKÜLATİF (Veri Kalitesi Düşük)", 0.25, true)
            }
            if s >= config.tier3Threshold { return ("SPEKÜLATİF (Tier 3)", 0.25, true) }
            
            return ("YETERSİZ GÜÇ", 0.0, false)
        }
        
        var finalAction: SignalAction = .hold
        var isApproved = false
        var targetSizeR = 0.0
        var rationale = ""
        
        if claimAction == .buy {
            let tier = determineTier(score: consensusScore, isBuy: true, quality: consensusQuality)
            
            let strongTechObjectors = objectors.filter {
                ($0.module == .orion || $0.module == .phoenix) && $0.strength > config.strongTechObjectionThreshold
            }
            let technicalVeto = !strongTechObjectors.isEmpty
            
            let weakTechObjectors = objectors.filter {
                ($0.module == .orion || $0.module == .phoenix) && $0.strength <= config.strongTechObjectionThreshold && $0.strength > config.weakTechObjectionThreshold
            }
            
            if tier.approved {
                if technicalVeto {
                    finalAction = .hold
                    isApproved = false
                    targetSizeR = 0.0
                    
                    let vetoers = strongTechObjectors.map { "\($0.module.rawValue) (\(Int($0.strength)))" }.joined(separator: " & ")
                    rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "REDDEDİLDİ (Teknik Veto: \(vetoers))")
                } else {
                    finalAction = .buy
                    isApproved = true
                    targetSizeR = tier.size
                    
                    var sizeReductionReason = ""
                    
                    if !weakTechObjectors.isEmpty {
                        targetSizeR = min(targetSizeR, config.sizeReductionThreshold)
                        let techNames = weakTechObjectors.map { $0.module.rawValue }.joined(separator: ", ")
                        sizeReductionReason = "Zayıf Teknik İtiraz: \(techNames)"
                    }
                    
                    let objectionPower = objectors.reduce(0.0) { $0 + $1.strength }
                    if objectionPower >= 0.5 && targetSizeR > config.sizeReductionThreshold {
                        targetSizeR = config.sizeReductionThreshold
                        if sizeReductionReason.isEmpty {
                            sizeReductionReason = "Genel İtiraz"
                        }
                    }
                    
                    if sizeReductionReason.isEmpty {
                        rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM ONAYLANDI (\(tier.tier))")
                    } else {
                        rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM ONAYLANDI (\(tier.tier)) - Risk Düşürüldü: \(sizeReductionReason)")
                    }
                }
            } else {
                finalAction = .hold
                rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM REDDEDİLDİ (\(tier.tier))")
            }
        } else if claimAction == .sell {
            let tier = determineTier(score: consensusScore, isBuy: false, quality: consensusQuality)
            
            if tier.approved {
                finalAction = .sell
                isApproved = true
                targetSizeR = tier.size
                rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "SATIŞ ONAYLANDI (\(tier.tier))")
            } else {
                finalAction = .hold
                rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "SATIŞ REDDEDİLDİ (Puan: \(Int(consensusScore)))")
            }
        } else {
            rationale = "Konsey Beklemede."
        }
        
        return (finalAction, isApproved, rationale, targetSizeR)
    }
    
    private func generateConsensusText(claimant: ModuleOpinion, supporters: [ModuleOpinion], objectors: [ModuleOpinion], result: String) -> String {
        var text = ""
        
        if result.contains("REDDEDİLDİ") {
            text += "⛔️ \(result)\n\n"
        } else {
            text += "✅ \(result)\n\n"
        }
        
        switch claimant.module {
        case .orion:
            text += "Orion teknik göstergelerde belirgin bir yükseliş trendi tespit etti. "
        case .atlas:
            text += "Atlas, şirketin temel verilerini ve değerlemesini son derece cazip buldu. "
        case .phoenix:
            text += "Phoenix yapay zeka senaryoları yukarı yönlü bir hareket öngörüyor. "
        case .hermes:
            text += "Hermes, hisse ile ilgili kritik derecede olumlu bir haber akışı yakaladı. "
        default:
            text += "\(claimant.module.rawValue) alım fırsatı görüyor. "
        }
        
        if !supporters.isEmpty {
            let names = supporters.map { $0.module.rawValue }.joined(separator: ", ")
            text += "Bu analiz \(names) tarafından da teyit edildi."
        }
        
        if !objectors.isEmpty {
            text += "\n\n⚠️ Risk Notları: "
            for obj in objectors {
                let reason = obj.evidence.first ?? "Belirsiz risk"
                text += "\(obj.module.rawValue) bu karara şerh düştü: \(reason). "
            }
        }
        
        return text
    }
}
