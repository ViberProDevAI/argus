import SwiftUI

struct Theme {
    // MARK: - Argus Palette (Google Stitch v2)
    // MARK: - Argus Design System (ADS) Palette
    
    // 2. Backgrounds (Deep Space)
    static let background = Color(hex: "050505") // Void Black
    static let secondaryBackground = Color(hex: "0A0A0E") // Deep Nebula
    static let cardBackground = Color(hex: "121212") // Glass Base
    static let surface = Color(hex: "1E1E22") // Surface Grey
    static let surface2 = Color(hex: "2A2A30") // Elevated Surface

    static let border = Color(hex: "2D3748").opacity(0.3)
    static let groupedBackground = background

    
    // 2. Brand Identity
    static let primary = Color(hex: "FFD700") // Argus Gold (Wisdom/High Tier)
    static let accent = Color(hex: "00A8FF") // Cyber Blue (Tech/Data)
    static let tint = primary
    
    // 3. Typography Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8A8F98") // Stardust Gray
    
    // 4. Signal Colors (Neon)
    static let positive = Color(hex: "00FFA3") // Cyber Green
    static let negative = Color(hex: "FF2E55") // Crimson Red
    static let warning = Color(hex: "FFD740") // Amber
    static let neutral = Color(hex: "565E6D") // Steel Gray
    
    static let chartUp = positive
    static let chartDown = negative
    
    // 5. BIST Market Colors
    static let bistAccent = Color(hex: "FF3B30") // Borsa Kırmızısı
    static let bistSecondary = Color(hex: "8B0000") // Dark Red
    static let bistPositive = positive // Aynı pozitif renk
    static let bistNegative = negative // Aynı negatif renk
    
    // MARK: - Layout Constants
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }
    
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 999
    }
    
    // MARK: - Helpers
    static func colorForScore(_ score: Double) -> Color {
        if score >= 50 { return positive }
        else if score <= -50 { return negative }
        else { return neutral }
    }
    
    static func colorForAction(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return positive
        case .sell: return negative
        case .hold: return neutral
        case .wait: return neutral
        case .skip: return neutral
        }
    }
    
    static func colorForAction(_ action: LabAction) -> Color {
        switch action {
        case .buy: return positive
        case .sell: return negative
        case .hold: return neutral
        case .avoid: return Color.gray
        case .riskOff: return Color.purple
        case .riskOn: return Color.orange
        case .unknown: return Color.secondary
        }
    }
}
