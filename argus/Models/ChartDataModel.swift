import Foundation
import SwiftUI

// MARK: - Chart Data Models
// Optimized structures for high-performance drawing

/// A single point on the chart, optimized for rendering
struct ChartPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    
    // Pre-calculated visual properties (can be expanded)
    var isBullish: Bool { close >= open }
}

/// Container for all chart data, including computed ranges
struct ChartData: Equatable {
    let symbol: String
    let points: [ChartPoint]
    let timeframe: String // e.g., "1D", "1H"
    
    // Data Bounds (Min/Max) for scaling
    var minPrice: Double
    var maxPrice: Double
    var minVolume: Double
    var maxVolume: Double
    
    init(symbol: String, points: [ChartPoint], timeframe: String) {
        self.symbol = symbol
        self.points = points
        self.timeframe = timeframe
        
        // Calculate bounds once during initialization for performance
        if points.isEmpty {
            self.minPrice = 0
            self.maxPrice = 1
            self.minVolume = 0
            self.maxVolume = 1
        } else {
            self.minPrice = points.map { $0.low }.min() ?? 0
            self.maxPrice = points.map { $0.high }.max() ?? 1
            self.minVolume = points.map { $0.volume }.min() ?? 0
            self.maxVolume = points.map { $0.volume }.max() ?? 1
        }
    }
    
    static let empty = ChartData(symbol: "", points: [], timeframe: "")
}

// MARK: - Extensions

extension Candle {
    /// Converts a standard Candle to a ChartPoint
    func toChartPoint() -> ChartPoint {
        return ChartPoint(
            timestamp: self.date,
            open: self.open,
            high: self.high,
            low: self.low,
            close: self.close,
            volume: Double(self.volume)
        )
    }
}
