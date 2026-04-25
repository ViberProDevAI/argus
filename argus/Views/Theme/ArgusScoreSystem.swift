import SwiftUI

struct ArgusScoreSystem {
    
    // MARK: - Score Ranges & Labels
    
    static func label(for score: Double) -> String {
        switch score {
        case 85...100: return "AŞIRI GÜÇLÜ AL"
        case 75..<85:  return "GÜÇLÜ AL"
        case 65..<75:  return "AL"
        case 55..<65:  return "BEKLE"
        case 40..<55:  return "ZAYIF / RİSKLİ"
        case 0..<40:   return "SAT"
        default:       return "BELİRSİZ"
        }
    }
    
    static func shortLabel(for score: Double) -> String {
        switch score {
        case 65...100: return "AL"
        case 55..<65:  return "TUT"
        case 0..<55:   return "SAT"
        default:       return "-"
        }
    }
    
    // MARK: - Colors
    
    static func color(for score: Double) -> Color {
        switch score {
        case 85...100: return Color.teal // Neon/Strong
        case 75..<85:  return Color.green // Strong Green
        case 65..<75:  return Color.green.opacity(0.8) // Light Green
        case 55..<64:  return Color.yellow // Amber/Neutral
        case 40..<55:  return Color.orange // Risky
        case 0..<40:   return Color.red // Sell
        default:       return Color.gray
        }
    }
    
    // MARK: - Module Names
    
    static func moduleTitle(_ module: ArgusModule) -> String {
        switch module {
        case .atlas: return "Atlas"
        case .orion: return "Orion"
        case .aether: return "Aether"
        case .hermes: return "Hermes"
        default: return module.rawValue.capitalized
        }
    }
    
    static func moduleSubtitle(_ module: ArgusModule) -> String {
        switch module {
        case .atlas: return "Temel"
        case .orion: return "Teknik"
        case .aether: return "Makro"
        case .hermes: return "Haber"
        default: return ""
        }
    }
}
