import SwiftUI

/// Argus institutional tema sistemi.
///
/// 2026-04-22 Sprint 1: V5 mockup (`Argus_Mockup_V5.html`) paletine hizalandı.
/// Mevcut token isimleri korundu, sadece hex değerleri V5 spec'ine çekildi.
/// Yeni eklentiler: `backgroundDeep`, `border`, `holo/aurora/crimson/titan`
/// semantic alias'ları ve `Motors` namespace'i (14 motor rengi + council/argus).
enum InstitutionalTheme {
    enum Colors {
        // MARK: - Zemin / yüzey (V5 --bg, --surface1..3)
        static let background     = Color(hex: "060C18")
        static let backgroundDeep = Color(hex: "03060D")   // V5 --bg-deep
        static let surface1       = Color(hex: "0B1426")
        static let surface2       = Color(hex: "111D35")
        static let surface3       = Color(hex: "18284A")

        // MARK: - Semantik (V5 --holo, --aurora, --crimson, --titan)
        static let primary  = Color(hex: "3B82F6")   // V5 --holo
        static let positive = Color(hex: "22C55E")   // V5 --aurora
        static let negative = Color(hex: "EF4444")   // V5 --crimson
        static let neutral  = Color(hex: "64748B")   // Slate gri (nötr)
        static let warning  = neutral                 // Deprecated: neutral kullanın

        // V5 semantic alias'ları (yeni kod bunları kullanır, mevcut kod `primary`
        // vb. ile okumaya devam eder)
        static let holo    = primary
        static let aurora  = positive
        static let crimson = negative
        static let titan   = Color(hex: "F5C244")    // V5 --titan

        // MARK: - Metin
        static let textPrimary   = Color(hex: "E8EDF6")
        static let textSecondary = Color(hex: "8A97B2")
        static let textTertiary  = Color(hex: "5B6782")

        // MARK: - Kenarlıklar (V5 --border, --border-strong — solid renk)
        static let border         = Color(hex: "1E2A44")   // V5 --border
        static let borderStrong   = Color(hex: "2A3A5B")   // V5 --border-strong
        /// Deprecated alias — eski kod `borderSubtle` kullanıyorsa `border`'a
        /// map olur. Yeni kodda doğrudan `border` tercih edin.
        static let borderSubtle   = border

        // MARK: - Motor paleti (V5 motor renkleri)
        //
        // 2026-04-24 H-25: "AI-tell" renkleri yasaklandı. Mor (chiron lavanta,
        // chronos soluk lavanta) ve magenta-pembe (hermes) palettden çıkarıldı;
        // SaaS/AI brand'lerini çağrıştırmayan, daha grounded enstitüsyonel
        // tonlarla değiştirildi. Diğer renkler kullanıcı UI'sinde görünüyordu;
        // bu kayıtlar tek source-of-truth — tüm uygulamaya otomatik yayılır.
        enum Motors {
            static let orion       = Color(hex: "60A5FA")  // mavi
            static let atlas       = Color(hex: "93C5FD")  // açık mavi
            static let aether      = Color(hex: "22D3EE")  // cyan
            static let hermes      = Color(hex: "E5A47B")  // terracotta (eski: F472B6 magenta — AI-tell)
            static let athena      = Color(hex: "FDE68A")  // soluk altın
            static let demeter     = Color(hex: "84CC16")  // lime
            static let chiron      = Color(hex: "C8A971")  // warm tan/parchment (eski: A78BFA mor — AI-tell)
            static let prometheus  = Color(hex: "FB923C")  // turuncu
            static let alkindus    = Color(hex: "94A3B8")  // slate
            /// V5'te ayrık asset yok, Prometheus alevi reuse.
            static let phoenix     = prometheus
            static let council     = primary
            static let argus       = primary

            /// Motor adından renge çevirici — `MotorLogo` view'ı bunu kullanır.
            static func color(for engine: MotorEngine) -> Color {
                switch engine {
                case .orion:      return orion
                case .atlas:      return atlas
                case .aether:     return aether
                case .hermes:     return hermes
                case .athena:     return athena
                case .demeter:    return demeter
                case .chiron:     return chiron
                case .prometheus: return prometheus
                case .alkindus:   return alkindus
                case .phoenix:    return phoenix
                case .council:    return council
                case .argus:      return argus
                // Rezerv motorlar — V5'te asset yok, mantıksal tercihler:
                case .poseidon:   return Color(hex: "38BDF8") // açık turkuaz
                case .titan:      return titan                  // altın
                case .chronos:    return Color(hex: "B0C4D4") // soluk steel mavi (eski: E0E7FF lavanta — AI-tell)
                case .hephaestus: return Color(hex: "F97316") // kızıl turuncu
                }
            }
        }
    }

    enum Typography {
        // V5 tipografi ölçeği — SF Pro (default) + SF Mono (monospaced).
        // V5'te Inter + JetBrains Mono kullanılıyor; iOS muadili SF Pro + SF Mono.
        static let display     = Font.system(size: 22, weight: .black,    design: .default)
        static let title       = Font.system(size: 18, weight: .bold,     design: .default)
        static let headline    = Font.system(size: 16, weight: .semibold, design: .default)
        static let body        = Font.system(size: 14, weight: .regular,  design: .default)
        static let bodyStrong  = Font.system(size: 14, weight: .semibold, design: .default)
        static let caption     = Font.system(size: 11, weight: .medium,   design: .default)
        static let micro       = Font.system(size:  9, weight: .bold,     design: .default)
        // Monospaced — veri rakamları, chip/pill
        static let data        = Font.system(size: 13, weight: .semibold, design: .monospaced)
        static let dataSmall   = Font.system(size: 10, weight: .bold,     design: .monospaced)
        static let dataMicro   = Font.system(size:  9, weight: .bold,     design: .monospaced)
    }

    enum Spacing {
        static let hair: CGFloat = 0.5    // V5 .hair divider
        static let xxs:  CGFloat = 2
        static let xs:   CGFloat = 6
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 24
        static let xxl:  CGFloat = 32
    }

    enum Radius {
        static let sm:     CGFloat = 8      // V5 pill
        static let md:     CGFloat = 10     // iç elementler
        static let lg:     CGFloat = 14     // V5 card / card-2
        static let xl:     CGFloat = 22
        static let tabbar: CGFloat = 32     // V5 .tabbar
        static let pill:   CGFloat = 999
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
                        elevated ? InstitutionalTheme.Colors.borderStrong : InstitutionalTheme.Colors.border,
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
