//
//  ArgusDesignKit.swift
//  argus
//
//  Ortak tasarım dili — tüm ekranlar buradan beslenir.
//  Kural: tek token kaynağı (InstitutionalTheme), Dynamic Type, 8pt grid, dark-only.
//  Yeni bir design token sistemi açma, buradan genişlet.
//
//  İçindekiler:
//    • ArgusCard            — kart kapsayıcı (flat / elevated / inset / outlined)
//    • ArgusSectionHeader   — bölüm başlığı + alt etiket + trailing slot
//    • ArgusKPI             — label + value + delta + opsiyonel sparkline
//    • ArgusDeltaPill       — %+2.14 yeşil / %-1.45 kırmızı, tutarlı biçim
//    • ArgusSignalBadge     — BUY/SELL/WAIT/ACCUMULATE/REDUCE/EXIT rozeti
//    • ArgusEmptyState      — veri yok iskeleti
//    • ArgusLoadingState    — skeleton shimmer
//    • ArgusErrorState      — hata + retry
//    • ArgusDataGrid        — tablo satırları (sembol / fiyat / %)
//

import SwiftUI

// MARK: - 1) ArgusCard

enum ArgusCardStyle {
    case flat       // surface1, ince border
    case elevated   // surface2, gölge
    case inset      // surface background, daha koyu border
    case outlined   // transparan, sadece border
}

struct ArgusCard<Content: View>: View {
    let style: ArgusCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let content: () -> Content

    init(
        style: ArgusCardStyle = .flat,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = InstitutionalTheme.Radius.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(fill)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    @ViewBuilder private var fill: some View {
        switch style {
        case .flat:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface1)
        case .elevated:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface2)
        case .inset:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(InstitutionalTheme.Colors.background)
        case .outlined:
            Color.clear
        }
    }

    @ViewBuilder private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                style == .elevated
                    ? InstitutionalTheme.Colors.borderStrong
                    : InstitutionalTheme.Colors.borderSubtle,
                lineWidth: 1
            )
    }

    private var shadowColor: Color {
        switch style {
        case .elevated: return Color.black.opacity(0.28)
        case .flat:     return Color.black.opacity(0.12)
        default:        return .clear
        }
    }
    private var shadowRadius: CGFloat { style == .elevated ? 14 : 6 }
    private var shadowY: CGFloat { style == .elevated ? 8 : 3 }
}

// MARK: - 2) ArgusSectionHeader

struct ArgusSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: () -> Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    // 2026-04-24 H-27: Eski header `title.uppercased()` + mono caps + tracking
    // 1.4 ile tüm uygulamada başlık formatını dikte ediyordu — call site
    // "İzleme listesi" yazsa bile "İZLEME LİSTESİ" çıkıyordu. Yeni hâl
    // input'a saygı gösterir: ne yazarsan onu çizer. Tipografi 14pt
    // semibold, mono yok, tracking yok. Eski ALL CAPS string'li çağrılar
    // (örn. "GLOBAL İZLEME") yine ALL CAPS görünür ama mono'dan kurtulur —
    // yumuşak geçiş.
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

extension ArgusSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

// MARK: - 3) ArgusKPI

/// Label + value + opsiyonel delta + opsiyonel sparkline.
/// Sayısal değerler monospacedDigit; etiket Dynamic Type.
struct ArgusKPI: View {
    let label: String
    let value: String
    let delta: Double?           // %+x.xx — nil ise gösterilmez
    let isPercentDelta: Bool
    let sparkline: [Double]?     // nil ise çizilmez

    init(
        label: String,
        value: String,
        delta: Double? = nil,
        isPercentDelta: Bool = true,
        sparkline: [Double]? = nil
    ) {
        self.label = label
        self.value = value
        self.delta = delta
        self.isPercentDelta = isPercentDelta
        self.sparkline = sparkline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .tracking(1.1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.heavy)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let delta {
                    ArgusDeltaPill(delta: delta, isPercent: isPercentDelta, compact: true)
                }
            }

            if let sparkline, sparkline.count >= 2 {
                ArgusMiniSparkline(data: sparkline)
                    .frame(height: 18)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 4) ArgusDeltaPill

struct ArgusDeltaPill: View {
    let delta: Double
    let isPercent: Bool
    let compact: Bool

    init(delta: Double, isPercent: Bool = true, compact: Bool = false) {
        self.delta = delta
        self.isPercent = isPercent
        self.compact = compact
    }

    private var isPositive: Bool { delta >= 0 }
    private var tint: Color {
        isPositive ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }
    private var text: String {
        let sign = isPositive ? "+" : ""
        let formatted = String(format: "%.2f", delta)
        return "\(sign)\(formatted)\(isPercent ? "%" : "")"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text(text)
                .font(.system(compact ? .caption2 : .caption, design: .monospaced))
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .foregroundColor(tint)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel(Text("\(isPositive ? "yükseliş" : "düşüş") \(text)"))
    }
}

// MARK: - 5) ArgusSignalBadge

enum ArgusSignal {
    case aggressiveBuy
    case buy
    case accumulate
    case wait
    case hold
    case reduce
    case sell
    case exit

    var label: String {
        switch self {
        case .aggressiveBuy: return "AGRESİF AL"
        case .buy:           return "AL"
        case .accumulate:    return "KADEMELİ"
        case .wait:          return "BEKLE"
        case .hold:          return "GÖZLE"
        case .reduce:        return "AZALT"
        case .sell:          return "SAT"
        case .exit:          return "ÇIK"
        }
    }

    var tint: Color {
        switch self {
        case .aggressiveBuy, .buy, .accumulate: return InstitutionalTheme.Colors.positive
        case .wait, .hold:                      return InstitutionalTheme.Colors.primary
        case .reduce:                           return InstitutionalTheme.Colors.neutral
        case .sell, .exit:                      return InstitutionalTheme.Colors.negative
        }
    }

    var icon: String {
        switch self {
        case .aggressiveBuy: return "bolt.fill"
        case .buy:           return "arrow.up.right.circle.fill"
        case .accumulate:    return "plus.circle.fill"
        case .wait:          return "hourglass"
        case .hold:          return "eye.fill"
        case .reduce:        return "minus.circle.fill"
        case .sell:          return "arrow.down.right.circle.fill"
        case .exit:          return "xmark.circle.fill"
        }
    }
}

struct ArgusSignalBadge: View {
    let signal: ArgusSignal
    let confidence: Double?      // 0..1, nil ise gösterilmez
    let compact: Bool

    init(_ signal: ArgusSignal, confidence: Double? = nil, compact: Bool = false) {
        self.signal = signal
        self.confidence = confidence
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: signal.icon)
                .font(.system(size: compact ? 10 : 12, weight: .bold))
            Text(signal.label)
                .font(.system(compact ? .caption2 : .caption, design: .monospaced))
                .fontWeight(.black)
                .tracking(1)
            if let c = confidence {
                Text("· \(Int(c * 100))%")
                    .font(.system(compact ? .caption2 : .caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .opacity(0.85)
            }
        }
        .foregroundColor(signal.tint)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule().fill(signal.tint.opacity(0.14))
        )
        .overlay(
            Capsule().stroke(signal.tint.opacity(0.4), lineWidth: 0.5)
        )
        .accessibilityLabel(Text("\(signal.label)\(confidence.map { " %\(Int($0*100)) güven" } ?? "")"))
    }
}

// MARK: - 6) ArgusEmptyState

struct ArgusEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String = "tray",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.bottom, 4)

            Text(title)
                .font(.headline)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.semibold)
                        .tracking(1)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(InstitutionalTheme.Colors.primary.opacity(0.14))
                        )
                        .overlay(
                            Capsule().stroke(InstitutionalTheme.Colors.primary.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(actionTitle))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 7) ArgusLoadingState (skeleton shimmer)

struct ArgusLoadingState: View {
    let rows: Int
    let message: String?

    init(rows: Int = 3, message: String? = nil) {
        self.rows = rows
        self.message = message
    }

    @State private var shimmerX: CGFloat = -1

    var body: some View {
        VStack(spacing: 12) {
            if let message {
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            ForEach(0..<max(1, rows), id: \.self) { i in
                skeletonBar(widthFactor: i == 0 ? 0.9 : (i == 1 ? 0.7 : 0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerX = 1
            }
        }
        .accessibilityLabel(Text(message ?? "Yükleniyor"))
    }

    private func skeletonBar(widthFactor: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                LinearGradient(
                    colors: [
                        Color.clear,
                        InstitutionalTheme.Colors.surface3.opacity(0.7),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: shimmerX * geo.size.width)
            }
            .frame(width: geo.size.width * widthFactor)
        }
        .frame(height: 14)
    }
}

// MARK: - 8) ArgusErrorState

struct ArgusErrorState: View {
    let icon: String
    let title: String
    let message: String
    let retryTitle: String
    let onRetry: (() -> Void)?

    init(
        icon: String = "exclamationmark.triangle.fill",
        title: String = "Bir şeyler ters gitti",
        message: String,
        retryTitle: String = "Tekrar dene",
        onRetry: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.negative)

            Text(title)
                .font(.headline)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            if let onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text(retryTitle)
                            .font(.system(.callout, design: .monospaced))
                            .fontWeight(.semibold)
                            .tracking(1)
                    }
                    .foregroundColor(InstitutionalTheme.Colors.negative)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(InstitutionalTheme.Colors.negative.opacity(0.12)))
                    .overlay(Capsule().stroke(InstitutionalTheme.Colors.negative.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(retryTitle))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - 9) ArgusDataGrid

/// Basit, genel amaçlı tablo. Başlık + satır (label, value, opsiyonel delta).
struct ArgusDataGrid: View {
    struct Row: Identifiable {
        let id: String
        let label: String
        let value: String
        let delta: Double?
        let isPercentDelta: Bool

        init(
            id: String? = nil,
            label: String,
            value: String,
            delta: Double? = nil,
            isPercentDelta: Bool = true
        ) {
            self.id = id ?? label
            self.label = label
            self.value = value
            self.delta = delta
            self.isPercentDelta = isPercentDelta
        }
    }

    let header: (label: String, value: String, delta: String?)?
    let rows: [Row]

    init(header: (label: String, value: String, delta: String?)? = nil, rows: [Row]) {
        self.header = header
        self.rows = rows
    }

    var body: some View {
        VStack(spacing: 0) {
            if let h = header {
                HStack {
                    Text(h.label.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(1.2)
                    Spacer()
                    Text(h.value.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(1.2)
                    if let d = h.delta {
                        Text(d.uppercased())
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(1.2)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(InstitutionalTheme.Colors.surface2)
            }

            if rows.isEmpty {
                ArgusEmptyState(
                    icon: "tablecells",
                    title: "Veri yok",
                    message: "Gösterilecek satır bulunamadı."
                )
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .font(.callout)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(row.value)
                            .font(.system(.callout, design: .monospaced))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(1)
                        if let d = row.delta {
                            ArgusDeltaPill(delta: d, isPercent: row.isPercentDelta, compact: true)
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .overlay(
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - ArgusMiniSparkline (ArgusKPI içi yardımcı — public kalmasın lazım değil)

struct ArgusMiniSparkline: View {
    let data: [Double]
    let strokeWidth: CGFloat
    let tint: Color?

    init(data: [Double], strokeWidth: CGFloat = 1.2, tint: Color? = nil) {
        self.data = data
        self.strokeWidth = strokeWidth
        self.tint = tint
    }

    private var effectiveTint: Color {
        if let tint { return tint }
        guard data.count >= 2 else { return InstitutionalTheme.Colors.textSecondary }
        return data.last! >= data.first!
            ? InstitutionalTheme.Colors.positive
            : InstitutionalTheme.Colors.negative
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lo = data.min() ?? 0
            let hi = data.max() ?? 1
            let span = max(hi - lo, 0.0001)
            let step = data.count > 1 ? w / CGFloat(data.count - 1) : w

            if data.count >= 2 {
                Path { p in
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - CGFloat((v - lo) / span) * h
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(effectiveTint, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
