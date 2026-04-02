import SwiftUI

// MARK: - Ticker Item Model

struct TickerItem: Identifiable {
    let id: String
    let label: String
    let price: Double?
    let percentChange: Double?
    let isSafeHavenCandidate: Bool
    let status: TickerStatus

    enum TickerStatus {
        case index              // Core market index (SPY, QQQ, VIX)
        case normal             // Regular watchlist item
        case safeRecommended    // ⚓ — working in current crisis
        case safeContraindicated // ✗ — NOT working despite being a "safe" asset
    }
}

// MARK: - Smart Ticker Strip

struct SmartTickerStrip: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var router = SafeHavenRouter.shared

    // Core indices always shown
    private let coreSymbols: [(symbol: String, label: String)] = [
        ("SPY",     "S&P"),
        ("QQQ",     "NQ"),
        ("^VIX",    "VIX"),
        ("GLD",     "GOLD"),
        ("BTC-USD", "BTC")
    ]

    // Safe haven candidates added to the strip
    private let safeHavenSymbols: [(symbol: String, label: String)] = [
        ("TLT",  "TLT"),
        ("IEF",  "IEF"),
        ("UUP",  "UUP"),
        ("XLU",  "XLU"),
        ("XLV",  "XLV"),
        ("SH",   "SH"),
        ("PSQ",  "PSQ"),
        ("VIXY", "VIXY"),
        ("USDTRY=X", "USD/TRY"),
        ("GC=F", "ALTIN")
    ]

    var tickerItems: [TickerItem] {
        var items: [TickerItem] = []

        // 1. Core indices
        for (symbol, label) in coreSymbols {
            let quote = viewModel.quotes[symbol]
            items.append(TickerItem(
                id: symbol,
                label: label,
                price: quote?.currentPrice,
                percentChange: quote?.percentChange,
                isSafeHavenCandidate: false,
                status: .index
            ))
        }

        // 2. Safe haven candidates — only show when router is active OR when quote is available
        for (symbol, label) in safeHavenSymbols {
            guard let quote = viewModel.quotes[symbol] else { continue }
            let status: TickerItem.TickerStatus
            if router.isActive {
                if router.isRecommended(symbol) {
                    status = .safeRecommended
                } else if router.isContraindicated(symbol) {
                    status = .safeContraindicated
                } else {
                    status = .normal
                }
            } else {
                status = .normal
            }

            items.append(TickerItem(
                id: symbol,
                label: label,
                price: quote.currentPrice,
                percentChange: quote.percentChange,
                isSafeHavenCandidate: true,
                status: status
            ))
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Safe haven status bar — slides in when active
            if router.isActive {
                SafeHavenStatusBar(router: router)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }

            // The marquee ticker
            MarqueeTicker(items: tickerItems)
        }
        .animation(.easeInOut(duration: 0.4), value: router.isActive)
        .onChange(of: viewModel.macroRating?.numericScore) { _ in
            router.evaluate(
                quotes: viewModel.quotes,
                aetherScore: viewModel.macroRating?.numericScore
            )
        }
        .onChange(of: viewModel.quotes.count) { _ in
            router.evaluate(
                quotes: viewModel.quotes,
                aetherScore: viewModel.macroRating?.numericScore
            )
        }
        .onAppear {
            router.evaluate(
                quotes: viewModel.quotes,
                aetherScore: viewModel.macroRating?.numericScore
            )
        }
    }
}

// MARK: - Safe Haven Status Bar

private struct SafeHavenStatusBar: View {
    @ObservedObject var router: SafeHavenRouter

    var body: some View {
        HStack(spacing: 8) {
            // Blinking dot
            BlinkingDot(color: alertColor)

            Text("⚓ GÜVENLİ LİMAN MODU")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(alertColor)
                .tracking(1.2)

            Text("·")
                .foregroundColor(alertColor.opacity(0.4))

            Text(router.crisisType.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(alertColor.opacity(0.85))
                .tracking(0.8)

            Spacer()

            // Top picks
            let tops = router.topRecommendations(limit: 2)
            if !tops.isEmpty {
                Text(tops.joined(separator: " · "))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.9))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(alertColor.opacity(0.06))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(alertColor.opacity(0.25))
                .frame(height: 0.5)
        }
    }

    private var alertColor: Color { Color(hex: router.crisisType.alertColor) }
}

// MARK: - Marquee Ticker

struct MarqueeTicker: View {
    let items: [TickerItem]
    let pixelsPerSecond: Double = 48

    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 1
    @State private var animating: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: "060c18")

            // Two copies side by side for seamless loop
            HStack(spacing: 0) {
                tickerRow(items: items)
                tickerRow(items: items)
            }
            .offset(x: offset)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TickerWidthKey.self, value: geo.size.width / 2)
                }
            )
        }
        .frame(height: 30)
        .clipped()
        .onPreferenceChange(TickerWidthKey.self) { width in
            guard width > 10 else { return }
            contentWidth = width
            restartAnimation(for: width)
        }
        .onChange(of: items.count) { _ in
            // Recompute when items change (safe haven mode activates/deactivates)
            withAnimation(nil) { offset = 0 }
            animating = false
            // Brief delay so layout can measure new width before restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                restartAnimation(for: contentWidth)
            }
        }
    }

    @ViewBuilder
    private func tickerRow(items: [TickerItem]) -> some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                TickerCell(item: item)
                tickerSeparator
            }
        }
    }

    private var tickerSeparator: some View {
        Text("·")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.12))
            .padding(.horizontal, 6)
    }

    private func restartAnimation(for width: CGFloat) {
        guard width > 10, !animating else { return }
        animating = true
        offset = 0
        let duration = width / pixelsPerSecond
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -width
        }
    }
}

// MARK: - Ticker Cell

private struct TickerCell: View {
    let item: TickerItem

    var body: some View {
        HStack(spacing: 5) {
            // Safe haven badge
            if item.isSafeHavenCandidate {
                switch item.status {
                case .safeRecommended:
                    Text("⚓")
                        .font(.system(size: 8))
                case .safeContraindicated:
                    Text("✗")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "ff3333"))
                default:
                    EmptyView()
                }
            }

            // Label
            Text(item.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(labelColor)

            // Value / Change
            if let pct = item.percentChange {
                Text(formattedChange(pct))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(changeColor(pct))
            } else {
                Text("···")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 8)
        .opacity(item.status == .safeContraindicated ? 0.45 : 1.0)
    }

    private var labelColor: Color {
        switch item.status {
        case .index:                return .white.opacity(0.9)
        case .safeRecommended:      return .green.opacity(0.9)
        case .safeContraindicated:  return .white.opacity(0.4)
        default:                    return .white.opacity(0.7)
        }
    }

    private func changeColor(_ pct: Double) -> Color {
        switch item.status {
        case .safeRecommended:
            return pct >= 0 ? Color(hex: "00e676") : Color(hex: "ff3333")
        case .safeContraindicated:
            return .gray.opacity(0.5)
        case .index where item.label == "VIX":
            // VIX is "good" when rising in a fear context — keep neutral
            return pct >= 0 ? Color(hex: "ff8c00") : Color(hex: "4caf50")
        default:
            return pct >= 0 ? Color(hex: "00e676") : Color(hex: "ff3333")
        }
    }

    private func formattedChange(_ pct: Double) -> String {
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }
}

// MARK: - Blinking Dot

private struct BlinkingDot: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Preference Key

private struct TickerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
