import Foundation

// MARK: - Portfolio Actions
enum PortfolioAction {
    case buy(symbol: String, score: Double)
    case sell(symbol: String, reason: String)
    case swap(sellSymbol: String, buySymbol: String, reason: String)
    case hold(reason: String)
}

class AutoPilotPortfolioManager {
    static let shared = AutoPilotPortfolioManager()
    
    // Constants (User Defined)
    private let minCashPercentage: Double = 0.20 // 20% Cash Rule
    private let commissionFee: Double = 1.50 // Midas Fixed Fee
    private let swapScoreBuffer: Double = 15.0 // Need +15 points to justify a swap
    
    // MARK: - Decision Making
    
    func evaluateOpportunity(
        newSymbol: String,
        newScore: Double,
        cashBalance: Double,
        totalPortfolioValue: Double, // Cash + Equity
        holdings: [String: Double] // Symbol : Current Argus Score
    ) -> PortfolioAction {
        
        let currentCashRatio = totalPortfolioValue > 0 ? (cashBalance / totalPortfolioValue) : 0
        
        // 1. Check Cash Availability (The 80/20 Rule)
        if currentCashRatio > minCashPercentage {
            // We have excess cash (> 20%). We can buy directly.
            // But only if score is decent (Standard logic usually handles > 70/80)
            if newScore >= 75 {
                return .buy(symbol: newSymbol, score: newScore)
            } else {
                return .hold(reason: "Yeterli puan değil (\(Int(newScore)))")
            }
        }
        
        // 2. Cash is Tight (<= 20%). Enter "Scarcity Mode".
        // We can only trade if we find a swap that is SIGNIFICANTLY better.
        
        // Must be a "Super Opportunity" first
        if newScore < 85 {
            return .hold(reason: "Nakit az, fırsat yeterince büyük değil (< 85)")
        }
        
        // Find optimal candidate to sell (Lowest Score)
        // Sort holdings by Score (Ascending)
        let sortedHoldings = holdings.sorted { $0.value < $1.value }
        
        if let worstHolding = sortedHoldings.first {
            let worstSymbol = worstHolding.key
            let worstScore = worstHolding.value
            
            // 3. The Swap Logic
            // New Score must be > Worst Score + Buffer
            if newScore > (worstScore + swapScoreBuffer) {
                return .swap(
                    sellSymbol: worstSymbol,
                    buySymbol: newSymbol,
                    reason: "Upgrade: \(Int(newScore)) vs \(Int(worstScore)) (+\(Int(newScore - worstScore)) Puan)"
                )
            } else {
                 return .hold(reason: "Değişim için fark yetersiz (Gereken: +15, Mevcut: +\(Int(newScore - worstScore)))")
            }
        }
        
        return .hold(reason: "Satılacak hisse bulunamadı")
    }
    
    // Helper to calculate transaction cost impact
    func calculateCommissionImpact(price: Double, quantity: Int) -> Double {
        // $1.50 fixed
        let fee = commissionFee
        let total = price * Double(quantity)
        return (fee / total) * 100.0 // Percentage impact
    }
}
