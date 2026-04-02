import Foundation

/// Portföydeki unrealized zarar oranına göre yeni alım boyutunu kısıtlar.
/// Portföy "ısındıkça" pozisyon boyutu küçülür; kritik seviyede yeni alım durur.
struct PortfolioHeatGate: Sendable {

    enum HeatLevel: String {
        case cool     = "SERIN"    // < -4%: normal
        case warm     = "SICAK"    // -4% ile -8% arası: %50 küçült
        case hot      = "KÖZ"      // -8% ile -12% arası: %80 küçült
        case critical = "KRİTİK"  // < -12%: yeni alım durdur
    }

    /// Açık pozisyonların unrealized PnL oranını hesaplar ve ısı seviyesini döner.
    static func assess(portfolio: [Trade], quotes: [String: Quote], equity: Double) -> HeatLevel {
        guard equity > 0 else { return .cool }

        let unrealizedPnL = portfolio
            .filter { $0.isOpen }
            .reduce(0.0) { sum, trade in
                let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
                return sum + ((currentPrice - trade.entryPrice) * trade.quantity)
            }

        let drawdownPct = (unrealizedPnL / equity) * 100

        switch drawdownPct {
        case ..<(-12): return .critical
        case ..<(-8):  return .hot
        case ..<(-4):  return .warm
        default:       return .cool
        }
    }

    /// Isı seviyesine göre pozisyon boyutu çarpanı döner.
    static func positionMultiplier(for heatLevel: HeatLevel) -> Double {
        switch heatLevel {
        case .cool:     return 1.0
        case .warm:     return 0.5
        case .hot:      return 0.2
        case .critical: return 0.0
        }
    }
}
