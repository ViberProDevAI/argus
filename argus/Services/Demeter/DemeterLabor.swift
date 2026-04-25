import Foundation

/// Demeter Labor: Pure Logic Worker (Strictly Non-Isolated)
/// Consolidates Math, Config, and Rules to bypass Swift 6 Actor Isolation issues.
struct DemeterLabor: Sendable {
    
    // MARK: - Constants & Config
    struct Config: Sendable {
        struct Symbols: Sendable {
            nonisolated static let oil = "CL=F"
            nonisolated static let rates = "^TNX"
            nonisolated static let dollar = "DX-Y.NYB"
            nonisolated static let vix = "^VIX"
            nonisolated static let spy = "SPY"
        }
        
        struct Thresholds: Sendable {
            nonisolated static let oilShockUp: Double = 0.25
            nonisolated static let oilShockDown: Double = -0.25
            
            nonisolated static let rateShockUp: Double = 1.0
            nonisolated static let rateShockDown: Double = -1.0
            
            nonisolated static let dollarShockUp: Double = 0.07
            nonisolated static let dollarShockDown: Double = -0.07
            
            nonisolated static let volShockStress: Double = 25.0
            nonisolated static let volShockPanic: Double = 35.0
        }
        
        struct Lookback: Sendable {
            nonisolated static let oil: Int = 30
            nonisolated static let rates: Int = 60
            nonisolated static let dollar: Int = 30
            nonisolated static let momentumShort: Int = 20
            nonisolated static let momentumLong: Int = 60
        }
    }
    
    // MARK: - Safe Logic (Impact Matrix)
    nonisolated static func getImpact(for shock: ShockType, direction: ShockDirection) -> [SectorETF: Double] {
        switch shock {
        case .energy:
            if direction == .positive {
                return [.XLE: 25.0, .XLI: -10.0, .XLY: -15.0, .XLB: 5.0]
            } else {
                return [.XLE: -25.0, .XLY: 10.0, .XLI: 10.0]
            }
        case .rates:
            if direction == .positive {
                return [.XLK: -15.0, .XLRE: -20.0, .XLU: -15.0, .XLF: 10.0, .XLP: -5.0]
            } else {
                return [.XLK: 15.0, .XLRE: 20.0, .XLU: 10.0, .XLF: -5.0]
            }
        case .dollar:
            if direction == .positive {
                return [.XLB: -15.0, .XLI: -10.0, .XLK: -5.0]
            } else {
                return [.XLB: 15.0, .XLI: 10.0, .XLK: 5.0]
            }
        case .vol:
            if direction == .positive {
                return [.XLP: 15.0, .XLV: 15.0, .XLU: 15.0, .XLY: -20.0, .XLF: -15.0, .XLK: -15.0]
            }
            return [:]
        case .credit, .liquidity:
            return [:]
        }
    }
    
    // MARK: - Text Logic
    nonisolated static func getAdvice(for sector: SectorETF, score: Double, shocks: [ShockFlag]) -> String {
        if shocks.isEmpty {
            if score > 70 { return "Sektör momentumu güçlü, makro rüzgar nötr." }
            if score < 30 { return "Sektör zayıf, katalizör eksik." }
            return "Piyasa genelini takip ediyor."
        }
        if score < 40 {
            return "Aktif şoklar (\(shocks.map { $0.type.displayName }.joined(separator: ", "))) bu sektörü baskılıyor. Dikkatli olun."
        } else if score > 70 {
            return "Şoklara rağmen (veya sayesinde) sektör güçlü duruyor. Pozitif ayrışma."
        } else {
            return "Makro şoklar belirsizlik yaratıyor. Volatilite beklenebilir."
        }
    }
    
    // MARK: - Safe Math
    nonisolated static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, !x.isEmpty else { return 0.0 }
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXSquare = x.map { $0 * $0 }.reduce(0, +)
        let sumYSquare = y.map { $0 * $0 }.reduce(0, +)
        let num = (n * sumXY) - (sumX * sumY)
        let den = sqrt(((n * sumXSquare) - (sumX * sumX)) * ((n * sumYSquare) - (sumY * sumY)))
        return den == 0 ? 0.0 : num / den
    }
    
    nonisolated static func logReturns(_ prices: [Double]) -> [Double] {
        guard prices.count > 1 else { return [] }
        var res: [Double] = []
        for i in 1..<prices.count {
            let p = prices[i-1]
            let c = prices[i]
            res.append((p > 0 && c > 0) ? log(c/p) : 0.0)
        }
        return res
    }
    
    nonisolated static func relativeStrengthRatio(asset: [Double], benchmark: [Double]) -> [Double] {
        let count = min(asset.count, benchmark.count)
        guard count > 0 else { return [] }
        let a = asset.suffix(count)
        let b = benchmark.suffix(count)
        return zip(a, b).map { $1 > 0 ? $0 / $1 : 0.0 }
    }
    
    nonisolated static func slope(_ series: [Double]) -> Double {
        guard series.count > 1 else { return 0.0 }
        let n = Double(series.count)
        let x = Array(0..<series.count).map { Double($0) }
        let sumX = x.reduce(0, +)
        let sumY = series.reduce(0, +)
        let sumXY = zip(x, series).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let num = (n * sumXY) - (sumX * sumY)
        let den = (n * sumX2) - (sumX * sumX)
        return den == 0 ? 0.0 : num / den
    }
}
