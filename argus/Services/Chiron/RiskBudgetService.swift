import Foundation

/// Helper service (non-actor) to calculate risk metrics from Portfolio State.
/// Used by ExecutionGovernor.
class RiskBudgetService {
    
    /// Calculates the total "R-Risk" currently exposed in the portfolio.
    /// 1.0 R = Risking 1% of account on a single trade.
    /// Returns: Total R units exposed (e.g. 2.45)
    func calculateTotalRiskR(portfolio: [Trade], equity: Double) -> Double {
        guard equity > 0 else { return 0.0 }
        
        var totalR = 0.0
        
        for trade in portfolio where trade.isOpen {
            // How much money is at risk?
            // If StopLoss exists: Loss = (Entry - Stop) * Qty
            // If No StopLoss (Manual): Assume full value (Worst case) or fixed % estimate
            
            let riskMoney: Double
            if let sl = trade.stopLoss {
                let riskPerShare = max(0, trade.entryPrice - sl)
                riskMoney = riskPerShare * trade.quantity
            } else {
                // Should not happen in Argus V3, but as fallback:
                // Assume 10% risk estimate or use last price
                // Let's use 10% of notional as proxy risk
                riskMoney = (trade.entryPrice * trade.quantity) * 0.10
            }
            
            // Convert to R (Risk Unit)
            // Definition: 1R = 1% of Total Equity? 
            // Or usually R is just the "Risk Amount".
            // Here we want to know sum of R-units relative to account size.
            // Let's define: Total Risk % = (Total Risk Money / Equity) * 100
            // Then convert to "Units of 1%". e.g. 2.5% risk = 2.5R
            
            let riskPercent = (riskMoney / equity) * 100.0
            totalR += riskPercent
        }
        
        return totalR
    }
    
    /// Checks if a specific cluster (Sector) is saturated.
    func isClusterSaturated(symbol: String, portfolio: [Trade]) -> Bool {
        let targetCluster = ClusterMap.getCluster(for: symbol)
        
        // Count open trades in this cluster
        let openTradesInCluster = portfolio.filter {
            $0.isOpen && ClusterMap.getCluster(for: $0.symbol) == targetCluster
        }.count
        
        return openTradesInCluster >= RiskBudgetConfig.maxConcentrationPerCluster
    }
    
    /// Checks if we hit the hard cap on position count.
    func isMaxPositionsReached(portfolio: [Trade]) -> Bool {
        let openCount = portfolio.filter { $0.isOpen }.count
        return openCount >= RiskBudgetConfig.maxPositions
    }
}
