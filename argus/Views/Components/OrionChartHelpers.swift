import Foundation
import SwiftUI

// MARK: - Orion Chart Helpers
// Lightweight logic to prepare chart data points from Candle arrays.

struct OrionChartHelpers {
    
    // Normalize data points to 0-1 range for drawing in a Path
    static func normalize(_ values: [Double]) -> [Double] {
        guard let min = values.min(), let max = values.max(), max > min else { return values.map { _ in 0.5 } }
        return values.map { ($0 - min) / (max - min) }
    }
    
    // Calculate Simple Moving Average
    static func calculateSMA(period: Int, prices: [Double]) -> [Double] {
        var smaValues: [Double] = []
        for i in 0..<prices.count {
            if i < period - 1 {
                smaValues.append(prices[i]) // Pad/Fallback
                continue
            }
            let slice = prices[(i - period + 1)...i]
            let sum = slice.reduce(0, +)
            smaValues.append(sum / Double(period))
        }
        return smaValues
    }
    
    // Calculate RSI (Simplified for visual chart)
    static func calculateRSI(period: Int, prices: [Double]) -> [Double] {
        guard prices.count > period else { return prices.map { _ in 50.0 } }
        
        var rsiValues: [Double] = []
        // Fill initial with 50
        for _ in 0..<period { rsiValues.append(50.0) }
        
        // Simple RSI logic loop (Not efficient for massive data but fine for UI)
        for i in period..<prices.count {
            let changes = zip(prices.dropFirst(i-period), prices.dropFirst(i-period+1)).map { $1 - $0 }
            let gains = changes.filter { $0 > 0 }.reduce(0, +)
            let losses = abs(changes.filter { $0 < 0 }.reduce(0, +))
            
            if losses == 0 {
                rsiValues.append(100.0)
            } else {
                let rs = gains / losses
                rsiValues.append(100.0 - (100.0 / (1.0 + rs)))
            }
        }
        return rsiValues
    }
}
