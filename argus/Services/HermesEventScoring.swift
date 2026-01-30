import Foundation

// MARK: - Hermes Event Scoring (V3)

enum HermesEventScoring {
    static func baseWeight(for eventType: HermesEventType, scope: HermesEventScope) -> Double {
        switch scope {
        case .global:
            return globalWeights[eventType] ?? 50.0
        case .bist:
            return bistWeights[eventType] ?? 50.0
        }
    }
    
    static func delayFactor(ageMinutes: Double) -> Double {
        switch ageMinutes {
        case ..<15: return 1.0
        case 15..<60: return 0.9
        case 60..<180: return 0.8
        case 180..<1440: return 0.7
        default: return 0.6
        }
    }
    
    static func timeDecay(horizon: HermesEventHorizon, ageMinutes: Double) -> Double {
        let hours = ageMinutes / 60.0
        switch horizon {
        case .intraday:
            return max(0.5, 1.0 - (hours / 12.0))
        case .shortTerm:
            return max(0.6, 1.0 - (hours / 72.0))
        case .multiweek:
            return max(0.7, 1.0 - (hours / 168.0))
        }
    }
    
    static func riskPenalty(flags: [HermesRiskFlag]) -> Double {
        var penalty = 1.0
        for flag in flags {
            switch flag {
            case .rumor: penalty *= 0.85
            case .lowReliability: penalty *= 0.8
            case .pricedIn: penalty *= 0.75
            case .regulatoryUncertainty: penalty *= 0.9
            }
        }
        return penalty
    }
    
    static func score(
        scope: HermesEventScope,
        eventType: HermesEventType,
        severity: Double,
        confidence: Double,
        sourceReliability: Double,
        horizon: HermesEventHorizon,
        publishedAt: Date,
        flags: [HermesRiskFlag],
        analysisDate: Date = Date(),
        extraMultiplier: Double = 1.0
    ) -> Double {
        let base = baseWeight(for: eventType, scope: scope)
        let normalizedSeverity = max(0.0, min(severity, 100.0)) / 100.0
        let normalizedConfidence = max(0.0, min(confidence, 1.0))
        let sourceAdj = max(0.0, min(sourceReliability, 100.0)) / 100.0
        
        let ageMinutes = max(0.0, analysisDate.timeIntervalSince(publishedAt) / 60.0)
        let delay = delayFactor(ageMinutes: ageMinutes)
        let decay = timeDecay(horizon: horizon, ageMinutes: ageMinutes)
        let risk = riskPenalty(flags: flags)
        
        let raw = base * normalizedSeverity * normalizedConfidence * extraMultiplier
        let final = raw * sourceAdj * delay * decay * risk
        return max(0.0, min(final, 100.0))
    }
    
    private static let globalWeights: [HermesEventType: Double] = [
        .earningsSurprise: 85,
        .guidanceRaise: 80,
        .guidanceCut: 85,
        .revenueMiss: 70,
        .marginPressure: 65,
        .buybackAnnouncement: 60,
        .dividendChange: 55,
        .mergerAcquisition: 75,
        .regulatoryAction: 70,
        .legalRisk: 60,
        .productLaunch: 50,
        .supplyChainDisruption: 60,
        .macroShock: 70,
        .ratingUpgrade: 55,
        .ratingDowngrade: 60,
        .insiderActivity: 50,
        .sectorRotation: 50,
        .geopoliticalRisk: 65,
        .fraudAllegation: 80,
        .leadershipChange: 45
    ]
    
    private static let bistWeights: [HermesEventType: Double] = [
        .kapDisclosure: 70,
        .bedelliCapitalIncrease: 75,
        .bedelsizBonusIssue: 65,
        .temettuAnnouncement: 60,
        .ihaleKazandi: 70,
        .ihaleIptal: 70,
        .spkAction: 75,
        .ortaklikAnlasmasi: 65,
        .borclanmaIhraci: 55,
        .karUyarisi: 80,
        .kurRiski: 60,
        .ihracatSiparisi: 60,
        .yatirimPlani: 55,
        .tesisAcilisi: 50,
        .sektorTesvik: 55,
        .davaOlumsuz: 70,
        .davaOlumlu: 55,
        .yonetimDegisim: 45,
        .operasyonelAriza: 65
    ]
}
