import SwiftUI

/// V5 mockup'tan (`Argus_Mockup_V5.html`) türetilen reusable bileşenler.
///
/// Mevcut `ArgusDesignKit.swift` Card/KPI/DeltaPill/SignalBadge sunuyor;
/// bu dosya onun üzerine V5'te sık kullanılan küçük primitifleri ekler.
/// Dokunma alanları, renk ve tipografi hep `InstitutionalTheme`'den okunur.

// MARK: - Chip Tone
//
// V5 chip/pill palette'i. `motor(_:)` case'i ile otomatik motor renk eşleşmesi.

enum ArgusChipTone: Equatable {
    case holo
    case aurora
    case crimson
    case titan
    case neutral
    case motor(MotorEngine)
    case custom(Color)

    var foreground: Color {
        switch self {
        case .holo:      return InstitutionalTheme.Colors.holo
        case .aurora:    return InstitutionalTheme.Colors.aurora
        case .crimson:   return InstitutionalTheme.Colors.crimson
        case .titan:     return InstitutionalTheme.Colors.titan
        case .neutral:   return InstitutionalTheme.Colors.textSecondary
        case .motor(let e): return InstitutionalTheme.Colors.Motors.color(for: e)
        case .custom(let c): return c
        }
    }

    var background: Color { foreground.opacity(0.14) }
}

// MARK: - ArgusChip (V5 .chip — 3px 8px pad, radius 999, mono 9pt/700)

/// Küçük kategorize etiket. V5'te her yerde kullanılır.
///
/// Örnek:
///
///     ArgusChip("TOPLA", tone: .aurora)
///     ArgusChip("ORION 82", tone: .motor(.orion), icon: .orion)
struct ArgusChip: View {
    let text: String
    var tone: ArgusChipTone = .holo
    var icon: MotorEngine? = nil

    init(_ text: String, tone: ArgusChipTone = .holo, icon: MotorEngine? = nil) {
        self.text = text
        self.tone = tone
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                MotorLogo(icon, size: 10).tinted(tone.foreground)
            }
            Text(text)
                .font(InstitutionalTheme.Typography.dataMicro)
                .tracking(0.6)
                .foregroundStyle(tone.foreground)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(tone.background))
    }
}

// MARK: - ArgusPill (V5 .pill — radius 8, mono 10pt/700, daha büyük)

struct ArgusPill: View {
    let text: String
    var tone: ArgusChipTone = .holo
    var filled: Bool = true

    init(_ text: String, tone: ArgusChipTone = .holo, filled: Bool = true) {
        self.text = text
        self.tone = tone
        self.filled = filled
    }

    var body: some View {
        Text(text)
            .font(InstitutionalTheme.Typography.dataSmall)
            .tracking(0.5)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(filled ? tone.background : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .stroke(tone.foreground.opacity(filled ? 0 : 0.35), lineWidth: 1)
                    )
            )
    }
}

// MARK: - ArgusBar (V5 .bar — progress, 6pt height, radius 999)

struct ArgusBar: View {
    /// 0…1 aralığında normalize edilmiş değer (clamp edilir).
    let value: Double
    var color: Color = InstitutionalTheme.Colors.holo
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.surface3)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - ArgusDot (V5 .dot — 6px indicator)

struct ArgusDot: View {
    var color: Color = InstitutionalTheme.Colors.holo
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - ArgusHair (V5 .hair — 0.5pt divider)

struct ArgusHair: View {
    var body: some View {
        Rectangle()
            .fill(InstitutionalTheme.Colors.border)
            .frame(height: InstitutionalTheme.Spacing.hair)
    }
}

// MARK: - ArgusOrb (Sanctum'daki ring-orb — dairesel container, opsiyonel glow)

struct ArgusOrb<Content: View>: View {
    let size: CGFloat
    var ringColor: Color = InstitutionalTheme.Colors.border
    var glowColor: Color? = nil
    let content: () -> Content

    init(size: CGFloat,
         ringColor: Color = InstitutionalTheme.Colors.border,
         glowColor: Color? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.ringColor = ringColor
        self.glowColor = glowColor
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(InstitutionalTheme.Colors.surface2)
            Circle()
                .strokeBorder(ringColor, lineWidth: 1)
            if let glow = glowColor {
                Circle()
                    .strokeBorder(glow.opacity(0.35), lineWidth: 1)
                    .blur(radius: 6)
            }
            content()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - ArgusSectionCaption (V5 .sec-title — 10pt mono, letter 1.3)

struct ArgusSectionCaption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(InstitutionalTheme.Typography.dataSmall)
            .tracking(1.3)
            .foregroundStyle(InstitutionalTheme.Colors.textSecondary)
    }
}

// MARK: - ArgusIconButton (V5 .icon-btn — 44×44 tap-target + accessibility)
//
// 2026-04-23 V5.H erişilebilirlik: İkon-butonların tutarlı 44×44
// dokunma alanı ve anlamlı VoiceOver etiketi olması için tek bir
// yerden çizilir. WCAG 2.5.8 minimum 44×44 pt şartı karşılanır.
//
// Kullanım:
//
//     ArgusIconButton(
//         systemImage: "bell.fill",
//         label: "Bildirimleri aç",
//         tone: .motor(.hermes)
//     ) {
//         showNotifications = true
//     }
struct ArgusIconButton: View {
    let systemImage: String
    let label: String
    var tone: ArgusChipTone = .neutral
    var filled: Bool = false
    let action: () -> Void

    init(systemImage: String,
         label: String,
         tone: ArgusChipTone = .neutral,
         filled: Bool = false,
         action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.tone = tone
        self.filled = filled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tone.foreground)
                .frame(width: 44, height: 44) // WCAG 2.5.8 min target
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .fill(filled ? tone.background : InstitutionalTheme.Colors.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(tone.foreground.opacity(filled ? 0.4 : 0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Tap target extension
//
// SwiftUI'da `.frame(minWidth: 44, minHeight: 44)` her zaman yeterli
// olmayabiliyor (child content küçükse). Bu modifier hem görsel
// boyutu etkilemeden hem de tam 44×44 dokunma alanı garantisi
// sağlar (contentShape Rectangle ile).
extension View {
    /// WCAG 2.5.8 uyumlu minimum 44×44 dokunma alanı + opsiyonel
    /// VoiceOver etiketi. Görsel boyutu değiştirmez (contentShape).
    func argusTapTarget(_ label: String? = nil) -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .modifier(AccessibilityLabelIfPresent(label: label))
    }
}

private struct AccessibilityLabelIfPresent: ViewModifier {
    let label: String?
    func body(content: Content) -> some View {
        if let label, !label.isEmpty {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.backgroundDeep.ignoresSafeArea()

        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ArgusChip("TOPLA", tone: .aurora)
                ArgusChip("GÜVEN %88", tone: .holo)
                ArgusChip("ORION 82", tone: .motor(.orion), icon: .orion)
                ArgusChip("AETHER 68", tone: .motor(.aether), icon: .aether)
            }

            HStack(spacing: 10) {
                ArgusPill("KONSEY HÜCUM", tone: .aurora)
                ArgusPill("VERİ %100", tone: .holo, filled: false)
            }

            ArgusSectionCaption("ARGUS GÖRÜŞÜ")

            ArgusBar(value: 0.68, color: InstitutionalTheme.Colors.Motors.aether)
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                ArgusDot(color: InstitutionalTheme.Colors.aurora)
                Text("PİYASA AKTİF")
                    .font(InstitutionalTheme.Typography.dataMicro)
                    .foregroundStyle(InstitutionalTheme.Colors.textPrimary)
            }

            ArgusHair().padding(.horizontal, 40)

            ArgusOrb(size: 80,
                     ringColor: InstitutionalTheme.Colors.Motors.chiron,
                     glowColor: InstitutionalTheme.Colors.Motors.chiron) {
                MotorLogo(.chiron, size: 48)
            }
        }
        .padding()
    }
}
