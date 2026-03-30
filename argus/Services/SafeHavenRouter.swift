import Foundation
import Combine

// MARK: - Crisis Type

enum CrisisType: String {
    case none            = "Normal"
    case elevated        = "Dikkat"
    case liquidityCrunch = "Likidite Krizi"
    case inflationFear   = "Enflasyon Korkusu"
    case rateFear        = "Faiz Korkusu"
    case recessionFear   = "Resesyon Korkusu"
    case geopolitical    = "Jeopolitik Şok"
    case tryWeakness     = "TRY Krizi"

    var emoji: String {
        switch self {
        case .none:            return "✓"
        case .elevated:        return "⚠"
        case .liquidityCrunch: return "🔴"
        case .inflationFear:   return "📈"
        case .rateFear:        return "📊"
        case .recessionFear:   return "📉"
        case .geopolitical:    return "⚡"
        case .tryWeakness:     return "🇹🇷"
        }
    }

    var alertColor: String {
        switch self {
        case .none:            return "4caf50"
        case .elevated:        return "ffcc00"
        case .liquidityCrunch: return "ff1744"
        case .inflationFear:   return "ff6d00"
        case .rateFear:        return "ff6b35"
        case .recessionFear:   return "e53935"
        case .geopolitical:    return "ff8f00"
        case .tryWeakness:     return "e53935"
        }
    }
}

// MARK: - Safe Haven Router

/// Evaluates which safe-haven assets are actually working in the current crisis.
/// Drives both the SmartTickerStrip visual treatment and AutoPilot rotation logic.
final class SafeHavenRouter: ObservableObject {
    static let shared = SafeHavenRouter()

    @Published var crisisType: CrisisType = .none
    @Published var isActive: Bool = false
    @Published var scores: [String: Int] = [:]  // symbol → 0-100

    // Global safe haven candidates (scored at runtime)
    let globalCandidates = [
        "GLD", "GC=F",        // Gold
        "TLT", "IEF",         // Treasuries
        "UUP",                // Dollar ETF
        "XLU", "XLV", "XLP", // Defensive sectors
        "SLV",                // Silver
        "SH", "PSQ",          // Inverse ETFs
        "VIXY"                // Volatility
    ]

    // BIST / Turkey candidates
    let bistCandidates = [
        "USDTRY=X",  // USD/TRY
        "EURTRY=X",  // EUR/TRY
        "GC=F"       // Gold (TRY terms via rate conversion)
    ]

    private init() {}

    // MARK: - Main Evaluation

    func evaluate(quotes: [String: Quote], aetherScore: Double?) {
        let aether = aetherScore ?? 50.0
        let vix = vixValue(from: quotes)

        let shouldBeActive = aether < 35 || vix > 27
        guard shouldBeActive else {
            if isActive {
                isActive = false
                crisisType = .none
                scores = [:]
            }
            return
        }

        isActive = true
        crisisType = detectCrisisType(quotes: quotes, vix: vix, aether: aether)

        var newScores: [String: Int] = [:]
        for symbol in (globalCandidates + bistCandidates) {
            newScores[symbol] = scoreAsset(symbol: symbol, quotes: quotes, crisisType: crisisType, vix: vix)
        }
        scores = newScores
    }

    // MARK: - Convenience

    func isRecommended(_ symbol: String) -> Bool {
        guard isActive else { return false }
        return (scores[symbol] ?? 0) >= 65
    }

    func isContraindicated(_ symbol: String) -> Bool {
        guard isActive else { return false }
        let score = scores[symbol] ?? 50
        return score < 38
    }

    func topRecommendations(limit: Int = 3) -> [String] {
        scores
            .filter { $0.value >= 65 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Crisis Detection

    private func detectCrisisType(quotes: [String: Quote], vix: Double, aether: Double) -> CrisisType {
        let tltChange    = quotes["TLT"]?.percentChange     ?? 0
        let gldChange    = (quotes["GLD"] ?? quotes["GC=F"])?.percentChange ?? 0
        let dxyChange    = (quotes["DXY"] ?? quotes["UUP"])?.percentChange  ?? 0
        let usdtryChange = quotes["USDTRY=X"]?.percentChange ?? 0

        // TRY specific — trumps everything for BIST context
        if usdtryChange > 1.5 { return .tryWeakness }

        // Panic liquidation — even gold falls
        if vix > 42 && gldChange < -0.5 { return .liquidityCrunch }

        // Recession fear — flight to bonds AND gold simultaneously
        if tltChange > 0.5 && gldChange > 0.3 { return .recessionFear }

        // Rate fear — bonds selling, dollar rising
        if tltChange < -0.7 && dxyChange > 0.3 { return .rateFear }

        // Inflation fear — gold rising but bonds falling
        if gldChange > 0.8 && tltChange < 0.0 { return .inflationFear }

        // Geopolitical — VIX spike but gold leading
        if vix > 30 && gldChange > 1.0 { return .geopolitical }

        return .elevated
    }

    // MARK: - Asset Scoring

    private func scoreAsset(symbol: String, quotes: [String: Quote], crisisType: CrisisType, vix: Double) -> Int {
        guard let quote = quotes[symbol] else { return 0 }

        let momentum = quote.percentChange

        // Momentum score: is it actually moving in the right direction today?
        var score = 50
        if      momentum >  1.5 { score += 32 }
        else if momentum >  0.5 { score += 18 }
        else if momentum >  0.1 { score +=  8 }
        else if momentum < -1.5 { score -= 32 }
        else if momentum < -0.5 { score -= 18 }
        else if momentum < -0.1 { score -=  8 }

        // Crisis fit — does this asset class work in this type of crisis?
        score += crisisFitBonus(symbol: symbol, crisisType: crisisType)

        return max(0, min(100, score))
    }

    private func crisisFitBonus(symbol: String, crisisType: CrisisType) -> Int {
        switch symbol {

        case "GLD", "GC=F":
            switch crisisType {
            case .inflationFear, .geopolitical:  return 28
            case .recessionFear:                  return 20
            case .tryWeakness:                    return 25
            case .liquidityCrunch:                return -18  // Sells off in panic
            default:                              return 5
            }

        case "TLT", "IEF":
            switch crisisType {
            case .recessionFear:                  return 28
            case .rateFear:                       return -32  // Bonds crash when rates rise
            case .liquidityCrunch:                return -10
            default:                              return 5
            }

        case "UUP":
            switch crisisType {
            case .liquidityCrunch, .rateFear:     return 28
            case .recessionFear:                  return 12
            case .tryWeakness:                    return -5   // Not helpful for TRY investors
            default:                              return 8
            }

        case "XLU", "XLV", "XLP":
            switch crisisType {
            case .recessionFear, .elevated:       return 20
            case .liquidityCrunch:                return -8
            default:                              return 8
            }

        case "SLV":
            switch crisisType {
            case .inflationFear:                  return 22
            case .liquidityCrunch:                return -20  // Industrial component sells off
            default:                              return 5
            }

        case "VIXY":
            // Volatility rises in ALL crises but decays fast — tactical only
            switch crisisType {
            case .liquidityCrunch:                return 30
            case .elevated, .geopolitical:        return 18
            default:                              return 12
            }

        case "SH", "PSQ":
            // Short ETFs — work in any sustained bear
            switch crisisType {
            case .recessionFear, .liquidityCrunch: return 22
            case .inflationFear:                   return 15
            default:                               return 8
            }

        case "USDTRY=X":
            switch crisisType {
            case .tryWeakness:                    return 40
            case .liquidityCrunch:                return 20
            default:                              return 0
            }

        case "EURTRY=X":
            switch crisisType {
            case .tryWeakness:                    return 35
            default:                              return 0
            }

        default:
            return 0
        }
    }

    // MARK: - Helpers

    private func vixValue(from quotes: [String: Quote]) -> Double {
        return quotes["^VIX"]?.currentPrice
            ?? quotes["VIX"]?.currentPrice
            ?? 18.0
    }
}
