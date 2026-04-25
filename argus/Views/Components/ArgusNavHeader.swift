import SwiftUI

/// Argus V5 standart ekran başlığı — her ana ekranda üstte oturur.
///
/// 2026-04-22 Sprint 2.5: V5 mockup (`Argus_Mockup_V5.html` nav-header pattern)
/// birebir port. Her ekran kendi `topBar`/`commandHeader`'ını çizmek yerine
/// bunu çağırır; böylece tipografi, ikon rozeti boyutu, status satırı, geri
/// tuşu ve ekran-marketı segmenti her yerde aynı.
///
/// **İki ana varyant:**
///
///     ArgusNavHeader(
///         title: "PİYASA",
///         subtitle: "İZLEME · SİNYAL · KEŞİF",
///         leadingDeco: .bars3([.holo, .text, .text]),
///         segment: .tabs(["GLOBAL", "SİRKİYE"], selected: 0, onSelect: { idx in ... }),
///         actions: [.menu(onDrawerTap), .globe(onMarketTap), .plus(onAddTap), .bell(onAlertTap)],
///         status: .live(label: "PİYASA AKTİF", timestamp: "22 NİS · 18:42")
///     )
///
///     ArgusNavHeader(
///         title: "AAPL",
///         subtitle: "Apple Inc. · NASDAQ · GLOBAL",
///         leadingDeco: .back(onTap: { router.pop() }),
///         titlePill: .init(text: "AL", tone: .positive),
///         actions: [.bell(onAlertTap), .plus(onAddTap)]
///     )
///
/// **Dokunulmayan kontrat:**
/// - `NavigationRouter.pop()` / `AppStateCoordinator` imzalarını çağıran kod
///   aynı kalır; bu view sadece handler'ı tetikler.
/// - Drawer açma `onDrawerTap` closure'u üzerinden; `@Binding` kullanmaz, bu
///   sayede her ekran kendi `@State showDrawer`'ını yönetebilir.
struct ArgusNavHeader: View {
    // MARK: - Tipler

    enum LeadingDeco {
        /// V5: 3 bar dekor (piyasa başlığı yanında holo + 2 metin renkli)
        case bars3([BarTone])
        /// Geri tuşu — mirror chevron (V5'te scaleX(-1))
        case back(onTap: () -> Void)
        /// Dekor yok, sadece boşluk
        case none
    }

    enum BarTone {
        case holo, aurora, crimson, text
        var color: Color {
            switch self {
            case .holo:    return InstitutionalTheme.Colors.holo
            case .aurora:  return InstitutionalTheme.Colors.aurora
            case .crimson: return InstitutionalTheme.Colors.crimson
            case .text:    return InstitutionalTheme.Colors.textPrimary
            }
        }
    }

    enum Segment {
        case none
        case tabs([String], selected: Int, onSelect: (Int) -> Void)
    }

    struct TitlePill {
        let text: String
        let tone: ArgusChipTone
    }

    enum Action {
        case menu(() -> Void)
        case back(() -> Void)
        case globe(() -> Void)
        case plus(() -> Void)
        case bell(() -> Void)
        case search(() -> Void)
        case share(() -> Void)
        case more(() -> Void)
        case custom(sfSymbol: String, action: () -> Void)

        var sfSymbol: String {
            switch self {
            case .menu: return "line.3.horizontal"
            case .back: return "chevron.left"
            case .globe: return "globe"
            case .plus: return "plus"
            case .bell: return "bell"
            case .search: return "magnifyingglass"
            case .share: return "square.and.arrow.up"
            case .more: return "ellipsis"
            case .custom(let s, _): return s
            }
        }

        var action: () -> Void {
            switch self {
            case .menu(let a), .back(let a), .globe(let a), .plus(let a),
                 .bell(let a), .search(let a), .share(let a), .more(let a):
                return a
            case .custom(_, let a): return a
            }
        }
    }

    enum Status {
        case none
        case live(label: String, timestamp: String)
        case closed(label: String, timestamp: String)
        case custom(dotColor: Color, label: String, trailing: String)
    }

    // MARK: - Properties

    let title: String
    var subtitle: String? = nil
    var leadingDeco: LeadingDeco = .none
    var segment: Segment = .none
    var titlePill: TitlePill? = nil
    var actions: [Action] = []
    var status: Status = .none

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case let .tabs(labels, selected, onSelect) = segment {
                segmentRow(labels: labels, selected: selected, onSelect: onSelect)
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
            }

            titleRow
                .padding(.top, segment.isActive ? 12 : 0)
                .padding(.horizontal, 8)

            if case .none = status {
                EmptyView()
            } else {
                statusRow
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            InstitutionalTheme.Colors.surface1
                .overlay(
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Segment

    private func segmentRow(labels: [String], selected: Int, onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 40) {
            ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                Button { onSelect(idx) } label: {
                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 13,
                                          weight: idx == selected ? .black : .bold,
                                          design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(idx == selected
                                             ? InstitutionalTheme.Colors.holo
                                             : InstitutionalTheme.Colors.textTertiary)

                        Rectangle()
                            .fill(idx == selected ? InstitutionalTheme.Colors.holo : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack(spacing: 12) {
            leadingDecoView

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .black, design: .monospaced))
                        .tracking(titleTracking)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    if let pill = titlePill {
                        ArgusPill(pill.text, tone: pill.tone)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            Spacer(minLength: 8)

            if !actions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, act in
                        actionButton(act)
                    }
                }
            }
        }
    }

    private var titleSize: CGFloat {
        titlePill != nil ? 18 : 22
    }

    private var titleTracking: CGFloat {
        titlePill != nil ? 1.5 : 2.0
    }

    @ViewBuilder
    private var leadingDecoView: some View {
        switch leadingDeco {
        case .bars3(let tones):
            HStack(spacing: 2) {
                ForEach(Array(tones.enumerated()), id: \.offset) { _, tone in
                    Rectangle()
                        .fill(tone.color)
                        .frame(width: 3, height: 20)
                }
            }
        case .back(let onTap):
            Button(action: onTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(InstitutionalTheme.Colors.surface2)
                    )
            }
            .buttonStyle(.plain)
        case .none:
            EmptyView()
        }
    }

    private func actionButton(_ action: Action) -> some View {
        Button(action: action.action) {
            Image(systemName: action.sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status row

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .none:
            EmptyView()
        case .live(let label, let timestamp):
            statusBar(dotColor: InstitutionalTheme.Colors.aurora,
                      label: label,
                      trailing: timestamp,
                      primary: true)
        case .closed(let label, let timestamp):
            statusBar(dotColor: InstitutionalTheme.Colors.textTertiary,
                      label: label,
                      trailing: timestamp,
                      primary: false)
        case .custom(let dot, let label, let trailing):
            statusBar(dotColor: dot, label: label, trailing: trailing, primary: true)
        }
    }

    private func statusBar(dotColor: Color, label: String, trailing: String, primary: Bool) -> some View {
        HStack(spacing: 8) {
            ArgusDot(color: dotColor, size: 6)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(primary
                                 ? InstitutionalTheme.Colors.textPrimary
                                 : InstitutionalTheme.Colors.textSecondary)
            ArgusHair()
            Text(trailing)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Segment helpers

private extension ArgusNavHeader.Segment {
    var isActive: Bool {
        if case .tabs = self { return true }
        return false
    }
}

// MARK: - Preview

#Preview("Market header") {
    ZStack(alignment: .top) {
        InstitutionalTheme.Colors.backgroundDeep.ignoresSafeArea()
        VStack(spacing: 12) {
            ArgusNavHeader(
                title: "PİYASA",
                subtitle: "İZLEME · SİNYAL · KEŞİF",
                leadingDeco: .bars3([.holo, .text, .text]),
                segment: .tabs(["GLOBAL", "SİRKİYE"], selected: 0, onSelect: { _ in }),
                actions: [
                    .menu({}), .globe({}), .plus({}), .bell({})
                ],
                status: .live(label: "PİYASA AKTİF", timestamp: "22 NİS · 18:42")
            )
            ArgusNavHeader(
                title: "AAPL",
                subtitle: "Apple Inc. · NASDAQ · GLOBAL",
                leadingDeco: .back(onTap: {}),
                titlePill: .init(text: "AL", tone: .aurora),
                actions: [.bell({}), .plus({})]
            )
            ArgusNavHeader(
                title: "PORTFÖY",
                subtitle: "POZİSYON · P/L · DAYANIKLILIK",
                leadingDeco: .bars3([.aurora, .text, .text]),
                actions: [.menu({}), .search({}), .more({})],
                status: .custom(dotColor: InstitutionalTheme.Colors.aurora,
                                label: "7 POZİSYON · +₺84.2K",
                                trailing: "GÜNLÜK +2.3%")
            )
            Spacer()
        }
    }
}
