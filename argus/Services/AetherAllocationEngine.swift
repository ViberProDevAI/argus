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
        // Shift mantığı:
        //  - Conservative: equity'den bond'a %20 transfer
        //  - Aggressive: bond'un yarısını equity'ye transfer
        //
        // Normalizasyon düzeltmesi: Eski sürüm adjusted değerleri ve orijinal
        // gold/cash değerleri toplayıp tüm alanları bu toplama bölüyordu; ancak
        // gold/cash adjusted değildi → toplam 1.0'a eşitse hiçbir değişiklik olmuyor,
        // değilse yanlış yeniden ölçekleme yapılıyordu. Yeni mantık: adjusted ikili
        // (equity/bond) ve orijinal sabit ikili (gold/cash) zaten toplamda 1.0 olduğundan
        // yeniden normalize etmek gerekmiyor; sadece negatif kayma ihtimaline karşı clamp.

        var adjEquity = allocation.equity
        var adjBond = allocation.bond

        if profile == "Conservative" {
            let shift = adjEquity * 0.20 // %20 equity → bond
            adjEquity -= shift
            adjBond += shift
        } else if profile == "Aggressive" {
            let shift = adjBond * 0.50 // bond'un yarısı → equity
            adjBond -= shift
            adjEquity += shift
        }

        // Guard: float drift veya negatif değer gelirse clamp et
        adjEquity = max(0, adjEquity)
        adjBond   = max(0, adjBond)
        let gold  = max(0, allocation.gold)
        let cash  = max(0, allocation.cash)

        // Toplam 0'a düşmüş olmamalı (all zero) ama güvenli bölüm için koruma
        let total = adjEquity + adjBond + gold + cash
        guard total > 0 else {
            return allocation
        }

        return TargetAllocation(
            equity: adjEquity / total,
            bond:   adjBond   / total,
            gold:   gold      / total,
            cash:   cash      / total
        )
    }
}
