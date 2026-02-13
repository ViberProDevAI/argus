import SwiftUI

enum InstitutionalTheme {
    enum Colors {
        static let background = Color(hex: "07090C")
        static let surface1 = Color(hex: "0F141B")
        static let surface2 = Color(hex: "151C26")
        static let surface3 = Color(hex: "1B2430")

        static let primary = Color(hex: "3B82F6")      // Mavi
        static let positive = Color(hex: "16A34A")    // Yeşil
        static let negative = Color(hex: "DC2626")    // Kırmızı
        static let neutral = Color(hex: "64748B")      // Slate gri (nötr)
        static let warning = neutral                   // Deprecated: Artık neutral kullanılıyor

        static let textPrimary = Color(hex: "E5E7EB")
        static let textSecondary = Color(hex: "9CA3AF")
        static let textTertiary = Color(hex: "6B7280")

        static let borderSubtle = Color.white.opacity(0.08)
        static let borderStrong = Color.white.opacity(0.14)
    }

    enum Typography {
        static let display = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 18, weight: .semibold, design: .default)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let bodyStrong = Font.system(size: 15, weight: .semibold, design: .default)
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        static let micro = Font.system(size: 11, weight: .semibold, design: .default)
        static let data = Font.system(size: 14, weight: .semibold, design: .monospaced)
        static let dataSmall = Font.system(size: 12, weight: .semibold, design: .monospaced)
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
    }
    
    // MARK: - Helper Functions
    static func colorForScore(_ score: Double) -> Color {
        if score >= 70 { return Colors.positive }
        if score >= 40 { return Colors.neutral }
        return Colors.negative
    }
}

enum InstitutionalCardScale {
    case nano
    case micro
    case standard
    case insight
    case hero

    var padding: CGFloat {
        switch self {
        case .nano: return 8
        case .micro: return 10
        case .standard: return 14
        case .insight: return 16
        case .hero: return 18
        }
    }

    var radius: CGFloat {
        switch self {
        case .nano: return InstitutionalTheme.Radius.sm
        case .micro: return InstitutionalTheme.Radius.md
        case .standard: return InstitutionalTheme.Radius.md
        case .insight: return InstitutionalTheme.Radius.lg
        case .hero: return InstitutionalTheme.Radius.xl
        }
    }
}

private struct InstitutionalCardModifier: ViewModifier {
    let scale: InstitutionalCardScale
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: scale.radius, style: .continuous)
                    .fill(elevated ? InstitutionalTheme.Colors.surface2 : InstitutionalTheme.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: scale.radius, style: .continuous)
                    .stroke(
                        elevated ? InstitutionalTheme.Colors.borderStrong : InstitutionalTheme.Colors.borderSubtle,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(elevated ? 0.28 : 0.18),
                radius: elevated ? 16 : 8,
                x: 0,
                y: elevated ? 10 : 4
            )
    }
}

private struct InstitutionalScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
            .tint(InstitutionalTheme.Colors.primary)
    }
}

extension View {
    func institutionalCard(scale: InstitutionalCardScale = .standard, elevated: Bool = false) -> some View {
        modifier(InstitutionalCardModifier(scale: scale, elevated: elevated))
    }

    func institutionalScreenBackground() -> some View {
        modifier(InstitutionalScreenBackgroundModifier())
    }
}

struct NanoMetricCard: View {
    let label: String
    let value: String
    let trendUp: Bool?

    var body: some View {
        HStack(spacing: InstitutionalTheme.Spacing.xs) {
            if let trendUp {
                Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(trendUp ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .lineLimit(1)

                Text(value)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(InstitutionalCardScale.nano.padding)
        .institutionalCard(scale: .nano)
    }
}
