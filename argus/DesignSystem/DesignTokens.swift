import SwiftUI

/// Argus Design System Tokens
/// Renk, Font ve Spacing standartlarını belirler.
enum DesignTokens {
    
    // MARK: - Colors
    enum Colors {
        static let background = Color.black
        static let secondaryBackground = Color(red: 0.1, green: 0.1, blue: 0.12) // Koyu gri/lacivert
        static let primary = Color.cyan // Cyberpunk/Neon tema
        static let secondary = Color.purple
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
        static let border = Color.gray.opacity(0.3)

        // Glass morphism colors
        static let glassBase = Color.white.opacity(0.1)
        static let glassBorder = Color.white.opacity(0.2)
        static let glassHover = Color.white.opacity(0.15)
    }
    
    // MARK: - Fonts (Modern Premium Typography)
    enum Fonts {
        // Display & Headlines
        static let display = Font.system(size: 32, weight: .bold, design: .default)
        static let headline = Font.system(size: 24, weight: .bold, design: .default)

        // Body & Content
        static let title = Font.system(size: 20, weight: .semibold, design: .default)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)

        // UI & Controls
        static let tabLabel = Font.system(size: 12, weight: .semibold, design: .default)
        static let caption = Font.system(size: 11, weight: .medium, design: .default)
        static let micro = Font.system(size: 10, weight: .regular, design: .default)

        // Bloomberg Terminal monospace
        static let monospace = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let monospaceBold = Font.system(size: 13, weight: .semibold, design: .monospaced)

        static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return Font.system(size: size, weight: weight, design: .default)
        }
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
    
    // MARK: - Radius
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    // MARK: - Opacity
    enum Opacity {
        static let glassCard: Double = 0.15
        static let glassCardHover: Double = 0.25
        static let overlay: Double = 0.1
        static let border: Double = 0.2
        static let buttonDisabled: Double = 0.3
    }
}
