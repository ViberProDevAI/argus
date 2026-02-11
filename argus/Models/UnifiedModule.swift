import Foundation

/// Uygulama genelindeki modülleri ve veri kaynaklarını standardize eder.
enum UnifiedModule: String, CaseIterable, Identifiable {
    case bist = "BIST"
    case global = "Global"
    case crypto = "Kripto"
    case forex = "Forex"
    case emtia = "Emtia"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .bist: return "building.columns.fill"
        case .global: return "globe"
        case .crypto: return "bitcoinsign.circle.fill"
        case .forex: return "banknote.fill"
        case .emtia: return "drop.fill" // Petrol/Altın vb. için
        }
    }
    
    var color: String {
        switch self {
        case .bist: return "Red" // BIST genelde kırmızı/beyaz tema ile anılır ama app temasında primary
        case .global: return "Blue"
        case .crypto: return "Orange"
        case .forex: return "Green"
        case .emtia: return "Yellow"
        }
    }
}
