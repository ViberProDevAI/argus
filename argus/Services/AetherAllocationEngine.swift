import Foundation

struct TargetAllocation: Equatable, Codable {
    let equity: Double // 0.0 - 1.0
    let bond: Double   // 0.0 - 1.0 (Safe Universe)
    let gold: Double   // 0.0 - 1.0 (Safe Universe)
    let cash: Double   // 0.0 - 1.0 (Safe Universe / Pure Cash)
    
    // Helper to ensure sum is 1.0 (approximately)
    var isValid: Bool {
        abs((equity + bond + gold + cash) - 1.0) < 0.01
    }
}

enum DetailedRegime: String, Codable {
    case euphoria = "Euphoria (Extreme Bull)"
    case riskOn = "Risk On (Bull)"
    case neutral = "Neutral (Uncertain)"
    case mildRiskOff = "Mild Risk Off (Caution)"
    case deepRiskOff = "Deep Risk Off (Bear)"
}

final class AetherAllocationEngine {
    static let shared = AetherAllocationEngine()
    
    private init() {}
    
    func determineAllocation(aetherScore: Double) -> (DetailedRegime, TargetAllocation) {
        switch aetherScore {
        case 85...100:
            return (.euphoria, TargetAllocation(equity: 0.80, bond: 0.10, gold: 0.10, cash: 0.0))
            
        case 65..<85:
            return (.riskOn, TargetAllocation(equity: 0.95, bond: 0.0, gold: 0.05, cash: 0.0))
            
        case 45..<65:
            return (.neutral, TargetAllocation(equity: 0.60, bond: 0.20, gold: 0.10, cash: 0.10))
            
        case 30..<45:
            return (.mildRiskOff, TargetAllocation(equity: 0.35, bond: 0.40, gold: 0.20, cash: 0.05))
            
        default: // 0..<30
            return (.deepRiskOff, TargetAllocation(equity: 0.15, bond: 0.40, gold: 0.35, cash: 0.10))
        }
    }
    
    // Optional: User Risk Profile Adjustments
    func adjustForRiskProfile(allocation: TargetAllocation, profile: String) -> TargetAllocation {
        // Simple shift based on profile
        // Conservative: Shift 10% from Equity to Bond/Gold
        // Aggressive: Shift 10% from Bond to Equity
        
        var adjEquity = allocation.equity
        var adjBond = allocation.bond
        
        if profile == "Conservative" {
            let shift = adjEquity * 0.20 // Reduce equity by 20%
            adjEquity -= shift
            adjBond += shift
        } else if profile == "Aggressive" {
            let shift = adjBond * 0.50 // Move half of bonds to equity
            adjBond -= shift
            adjEquity += shift
        }
        
        // Re-normalize just in case
        let total = adjEquity + adjBond + allocation.gold + allocation.cash
        return TargetAllocation(
            equity: adjEquity / total,
            bond: adjBond / total,
            gold: allocation.gold / total,
            cash: allocation.cash / total
        )
    }
}
