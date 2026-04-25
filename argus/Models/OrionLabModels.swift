import Foundation

struct OrionSnapshot: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let date: Date
    let price: Double
    let orionScore: Double
    let orionLetter: String
    
    // Components
    let argusScore: Double?
    let techScore: Double?
    let aetherScore: Double?
    
    let mode: OrionMode
}

struct OrionGradeStats: Identifiable {
    let id = UUID()
    let letter: String
    let count: Int
    
    // Performance Metrics
    let avgReturn1D: Double?
    let avgReturn5D: Double?
    let avgReturn20D: Double?
    let hitRate5D: Double?
}
