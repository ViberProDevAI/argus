import SwiftUI

// MARK: - Premium Color System
enum PremiumColors {
    // Primary Colors
    static let background = Color(hex: "0A0A0B")
    static let surface = Color(hex: "161618")
    static let surface2 = Color(hex: "1E1E22")
    static let surface3 = Color(hex: "2A2A30")
    
    // Accent Colors
    static let primary = Color(hex: "4A9FFF")
    static let primaryLight = Color(hex: "6BB6FF")
    static let primaryDark = Color(hex: "2F7BD6")
    
    // Status Colors
    static let success = Color(hex: "00C853")
    static let successLight = Color(hex: "00E676")
    static let successDark = Color(hex: "009624")
    
    static let warning = Color(hex: "FFB800")
    static let warningLight = Color(hex: "FFCA28")
    static let warningDark = Color(hex: "C68000")
    
    static let error = Color(hex: "FF4757")
    static let errorLight = Color(hex: "FF7884")
    static let errorDark = Color(hex: "C21834")
    
    // Market Colors
    static let gain = Color(hex: "00E676")
    static let loss = Color(hex: "FF5252")
    
    // Text Colors
    static let text = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "A0A0A0")
    static let textTertiary = Color(hex: "606060")
    
    // Special Colors
    static let cardBackground = Color(hex: "1E1E22")
    static let divider = Color(hex: "2A2A30")
    static let shimmer = Color(hex: "2A2A30")
}

// MARK: - Premium Typography System
enum PremiumTypography {
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 22, weight: .semibold)
    static let headline = Font.system(size: 18, weight: .semibold)
    static let subheadline = Font.system(size: 16, weight: .medium)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 14, weight: .medium)
    static let small = Font.system(size: 12, weight: .regular)
    static let tiny = Font.system(size: 11, weight: .medium)
}

// MARK: - Premium Spacing System
enum PremiumSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Premium Corner Radius System
enum PremiumCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
}

// MARK: - Premium Animation System
enum PremiumAnimation {
    static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let smoothFade = Animation.easeOut(duration: 0.3)
    static let quickFade = Animation.easeOut(duration: 0.2)
    static let scale = Animation.spring(response: 0.4, dampingFraction: 0.9)
    static let slide = Animation.spring(response: 0.5, dampingFraction: 0.85)
}

// MARK: - Premium Shadow System
enum PremiumShadow {
    static let card: (radius: CGFloat, x: CGFloat, y: CGFloat) = (radius: 8, x: 0, y: 2)
    static let cardElevated: (radius: CGFloat, x: CGFloat, y: CGFloat) = (radius: 12, x: 0, y: 4)
    static let floating: (radius: CGFloat, x: CGFloat, y: CGFloat) = (radius: 16, x: 0, y: 8)
    static let glow: (radius: CGFloat, x: CGFloat, y: CGFloat) = (radius: 20, x: 0, y: 0)
}

// MARK: - Extensions
extension Color {
    // NOT: init(hex:) zaten Color+Hex.swift'te tanımlı
    
    static func gradient(from start: Color, to end: Color) -> LinearGradient {
        LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Premium View Modifiers
extension View {
    func premiumCard() -> some View {
        self
            .background(PremiumColors.cardBackground)
            .cornerRadius(PremiumCornerRadius.medium)
            .shadow(color: Color.black.opacity(0.3), radius: PremiumShadow.card.radius, x: PremiumShadow.card.x, y: PremiumShadow.card.y)
    }
    
    func premiumShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.25), radius: PremiumShadow.card.radius, x: PremiumShadow.card.x, y: PremiumShadow.card.y)
    }
    
    func premiumFadeIn() -> some View {
        self
            .opacity(0)
            .onAppear {
                withAnimation(PremiumAnimation.smoothFade) {
                    // This needs @State binding
                }
            }
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    
    enum ButtonVariant {
        case primary
        case secondary
        case success
        case warning
        case danger
        case ghost
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PremiumTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, PremiumSpacing.md)
            .padding(.vertical, PremiumSpacing.sm)
            .background(backgroundColor)
            .cornerRadius(PremiumCornerRadius.small)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(PremiumAnimation.scale, value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary: return PremiumColors.primary
        case .secondary: return PremiumColors.surface2
        case .success: return PremiumColors.success
        case .warning: return PremiumColors.warning
        case .danger: return PremiumColors.error
        case .ghost: return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary, .success, .warning, .danger: return .white
        case .secondary, .ghost: return PremiumColors.text
        }
    }
}

// MARK: - Premium Glass Effect
struct PremiumGlass: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                Color.white.opacity(opacity)
                    .blur(radius: blurRadius)
            )
    }
}

extension View {
    func premiumGlass(opacity: Double = 0.1, blurRadius: CGFloat = 20) -> some View {
        self.modifier(PremiumGlass(opacity: opacity, blurRadius: blurRadius))
    }
}
