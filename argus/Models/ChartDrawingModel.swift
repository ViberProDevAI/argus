import Foundation
import SwiftUI

// MARK: - Chart Drawing Models

enum DrawingType: String, Codable, CaseIterable {
    case trendLine
    case fibonacci
    
    var icon: String {
        switch self {
        case .trendLine: return "line.diagonal"
        case .fibonacci: return "f.cursive"
        }
    }
}

/// A generic point in chart space (Time & Price), not screen pixels.
struct ChartDrawingPoint: Codable, Equatable {
    let date: Date
    let price: Double
}

/// Represents a single drawing on the chart
struct ChartDrawing: Identifiable, Codable, Equatable {
    let id: UUID
    let type: DrawingType
    var points: [ChartDrawingPoint] // Usually 2 points (Start, End)
    var colorHex: String
    var lineWidth: CGFloat
    
    // Helper for SwiftUI Color
    var color: Color {
        get { Color(hex: colorHex) ?? .blue }
        set { colorHex = newValue.toHex() ?? "#0000FF" }
    }
    
    init(type: DrawingType, points: [ChartDrawingPoint], color: Color = .blue, lineWidth: CGFloat = 2.0) {
        self.id = UUID()
        self.type = type
        self.points = points
        self.colorHex = color.toHex() ?? "#0000FF"
        self.lineWidth = lineWidth
    }
}

// MARK: - Persistence Manager

class DrawingPersistence {
    static let shared = DrawingPersistence()
    private let keyPrefix = "ArgusChartDrawings_"
    
    func saveDrawings(_ drawings: [ChartDrawing], for symbol: String) {
        if let data = try? JSONEncoder().encode(drawings) {
            UserDefaults.standard.set(data, forKey: keyPrefix + symbol)
        }
    }
    
    func loadDrawings(for symbol: String) -> [ChartDrawing] {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + symbol),
              let drawings = try? JSONDecoder().decode([ChartDrawing].self, from: data) else {
            return []
        }
        return drawings
    }
}

// MARK: - Color Extensions for Hex Support

extension Color {
    // init(hex:) is defined in Extensions/Color+Hex.swift

    func toHex() -> String? {
        // Simple implementation - getting correct components from SwiftUI Color is tricky depending on environment
        // For simplicity, we'll try to get CGColor components
        guard let components = self.cgColor?.components, components.count >= 3 else {
            return "#0000FF"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
