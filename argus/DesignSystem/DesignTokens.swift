import SwiftUI

/// Argus Design System Tokens
/// Tek doğruluk kaynağı: renk, font, spacing, radius, opacity, animation.
///
/// Prensipler:
///  - Gri tonları 9 kademeli kanonik palet olarak tanımlanır (`Gray.g50..g900`).
///    Inline `.gray.opacity(X)` kullanımı yerine `DesignTokens.Colors.Gray.gXXX` tercih edilmelidir.
///  - Semantik renkler (`textPrimary`, `surface`, `border`) palet üstüne inşa edilir;
///    tema değişimi yalnızca bu seviyede yapılır.
///  - Font ölçekleri sabit px değil, Dynamic Type destekli `relativeTo:` parametresiyle tanımlanır.
enum DesignTokens {

    // MARK: - Colors

    enum Colors {

        // MARK: Kanonik gri paleti (koyu tema için ayarlanmış)
        /// Tüm gri kullanımları bu palete mecbur edilmelidir.
        /// `.gray.opacity(0.X)` inline ifadeleri yerine bunları kullanın.
        enum Gray {
            static let g50  = Color(red: 0.97, green: 0.97, blue: 0.98)  // neredeyse beyaz
            static let g100 = Color(red: 0.92, green: 0.92, blue: 0.94)  // açık metin
            static let g200 = Color(red: 0.82, green: 0.82, blue: 0.85)  // secondary metin
            static let g300 = Color(red: 0.65, green: 0.65, blue: 0.70)  // tertiary metin
            static let g400 = Color(red: 0.50, green: 0.50, blue: 0.55)  // disabled metin
            static let g500 = Color(red: 0.35, green: 0.35, blue: 0.40)  // divider güçlü
            static let g600 = Color(red: 0.22, green: 0.22, blue: 0.26)  // border
            static let g700 = Color(red: 0.14, green: 0.14, blue: 0.17)  // elevated surface
            static let g800 = Color(red: 0.08, green: 0.08, blue: 0.10)  // surface
            static let g900 = Color(red: 0.03, green: 0.03, blue: 0.05)  // background
        }

        // MARK: Semantik — arka plan ve yüzey
        static let background         = Gray.g900
        static let surface            = Gray.g800
        static let surfaceElevated    = Gray.g700
        static let secondaryBackground = Gray.g800   // geriye uyumluluk

        // MARK: Semantik — metin
        static let textPrimary        = Gray.g50
        static let textSecondary      = Gray.g200
        static let textTertiary       = Gray.g300
        static let textDisabled       = Gray.g400

        // MARK: Semantik — border ve ayraç
        static let border             = Gray.g600
        static let borderSubtle       = Gray.g700
        static let divider            = Gray.g700

        // MARK: Semantik — marka
        static let primary            = Color(red: 0.38, green: 0.82, blue: 0.96)  // cyan 400
        static let primaryMuted       = Color(red: 0.38, green: 0.82, blue: 0.96).opacity(0.20)
        static let secondary          = Color(red: 0.72, green: 0.54, blue: 0.98)  // purple 400
        static let accent             = Color(red: 0.98, green: 0.75, blue: 0.38)  // amber 400

        // MARK: Semantik — durum (AA kontrast için canlı tonlar)
        static let success            = Color(red: 0.22, green: 0.83, blue: 0.54)  // emerald 500
        static let successMuted       = Color(red: 0.22, green: 0.83, blue: 0.54).opacity(0.18)
        static let warning            = Color(red: 0.98, green: 0.70, blue: 0.27)  // amber 500
        static let warningMuted       = Color(red: 0.98, green: 0.70, blue: 0.27).opacity(0.18)
        static let error              = Color(red: 0.96, green: 0.36, blue: 0.40)  // rose 500
        static let errorMuted         = Color(red: 0.96, green: 0.36, blue: 0.40).opacity(0.18)
        static let info               = Color(red: 0.38, green: 0.65, blue: 0.96)  // blue 400
        static let infoMuted          = Color(red: 0.38, green: 0.65, blue: 0.96).opacity(0.18)

        // MARK: Tazelik (StaleDataRegistry UI karşılığı)
        static let fresh              = success
        static let aging              = warning
        static let stale              = error
        static let unknownFreshness   = Gray.g400

        // MARK: Glass morphism (premium katmanlar için)
        static let glassBase          = Color.white.opacity(0.08)
        static let glassBorder        = Color.white.opacity(0.14)
        static let glassHover         = Color.white.opacity(0.12)
    }

    // MARK: - Fonts (Dynamic Type destekli)

    enum Fonts {
        /// Büyük sayısal ekranlar için (Aether skoru, pnl vb.)
        static let display      = Font.system(size: 32, weight: .bold, design: .default)
        static let headline     = Font.system(.title2, design: .default).weight(.bold)
        static let title        = Font.system(.title3, design: .default).weight(.semibold)
        static let body         = Font.system(.body,  design: .default)
        static let bodyMedium   = Font.system(.callout, design: .default).weight(.medium)
        static let tabLabel     = Font.system(.caption, design: .default).weight(.semibold)
        static let caption      = Font.system(.caption, design: .default).weight(.medium)
        static let micro        = Font.system(.caption2, design: .default)

        // Bloomberg-terminal tarzı bölümler için monospace
        static let monospace     = Font.system(.footnote, design: .monospaced)
        static let monospaceBold = Font.system(.footnote, design: .monospaced).weight(.semibold)

        static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return Font.system(size: size, weight: weight, design: .default)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48

        // Geriye uyumluluk
        static let small      = sm
        static let medium     = lg
        static let large      = xl
        static let extraLarge = xxl
    }

    // MARK: - Radius

    enum Radius {
        static let xs:      CGFloat = 4
        static let sm:      CGFloat = 8
        static let md:      CGFloat = 12
        static let lg:      CGFloat = 16
        static let xl:      CGFloat = 20
        static let pill:    CGFloat = 999

        // Geriye uyumluluk
        static let small    = sm
        static let medium   = md
        static let large    = lg
    }

    // MARK: - Opacity

    enum Opacity {
        static let glassCard:        Double = 0.10
        static let glassCardHover:   Double = 0.18
        static let overlay:          Double = 0.10
        static let border:           Double = 0.20
        static let buttonDisabled:   Double = 0.30
    }

    // MARK: - Shadow

    enum Shadow {
        static let subtle  = (color: Color.black.opacity(0.15), radius: CGFloat(4),  x: CGFloat(0), y: CGFloat(2))
        static let medium  = (color: Color.black.opacity(0.20), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
        static let strong  = (color: Color.black.opacity(0.30), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(10))
    }

    // MARK: - Motion

    enum Motion {
        static let quick   = Animation.easeOut(duration: 0.18)
        static let natural = Animation.easeInOut(duration: 0.26)
        static let slow    = Animation.easeInOut(duration: 0.42)
        static let springy = Animation.spring(response: 0.42, dampingFraction: 0.82)
    }

    // MARK: - Hit Targets (WCAG 2.5.8)

    enum HitTarget {
        /// Minimum dokunulabilir alan — WCAG 2.2 AA 44×44pt şartı.
        static let minimum: CGFloat = 44
    }
}

// MARK: - View Modifiers

extension View {
    /// 44×44pt minimum dokunulabilir alan — erişilebilirlik zorunluluğu.
    func tapTarget() -> some View {
        self.frame(
            minWidth: DesignTokens.HitTarget.minimum,
            minHeight: DesignTokens.HitTarget.minimum
        )
        .contentShape(Rectangle())
    }

    /// Premium kart yüzeyi: yüzey rengi + ince kenarlık + yumuşak gölge.
    func argusCard(padding: CGFloat = DesignTokens.Spacing.lg,
                   cornerRadius: CGFloat = DesignTokens.Radius.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignTokens.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.border, lineWidth: 0.5)
            )
            .shadow(
                color: DesignTokens.Shadow.subtle.color,
                radius: DesignTokens.Shadow.subtle.radius,
                x:      DesignTokens.Shadow.subtle.x,
                y:      DesignTokens.Shadow.subtle.y
            )
    }
}
