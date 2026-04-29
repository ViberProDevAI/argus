import SwiftUI
import Combine

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
    @State private var refreshTimer: Timer?

    // Core indices always shown — 6 adet (V5 bant için yeterli hareket).
    private let coreSymbols: [(symbol: String, label: String)] = [
        ("SPY",     "S&P"),
        ("QQQ",     "NDX"),
        ("^VIX",    "VIX"),
        ("GLD",     "GOLD"),
        ("BTC-USD", "BTC"),
        ("ETH-USD", "ETH")
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
            // İlk yüklemede core indeksleri çek.
            ensureCoreQuotesLoaded()
            startPeriodicRefresh()
        }
        .onDisappear { stopPeriodicRefresh() }
    }

    /// Core indeksleri eksikse TradingViewModel üstünden tazeler.
    /// Zaten cache'deyse refreshSymbol no-op.
    private func ensureCoreQuotesLoaded() {
        let all = coreSymbols.map(\.symbol) + safeHavenSymbols.map(\.symbol)
        for symbol in all {
            // Quote yoksa VEYA 2 dk'dan eskiyse yenile.
            let shouldRefresh: Bool = {
                guard let q = viewModel.quotes[symbol] else { return true }
                // Quote.timestamp varsa onu kullan, yoksa koşulsuz refresh
                return q.currentPrice <= 0
            }()
            if shouldRefresh {
                viewModel.refreshSymbol(symbol)
            }
        }
    }

    /// Kayar bantı canlı tutmak için 60 sn'de bir core indeksleri tazele.
    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            ensureCoreQuotesLoaded()
        }
    }

    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
//
// 2026-04-25 — Sıfırdan yeniden yazım. Önceki üç deneme (V5.H-23, H-18,
// H-17 fix) ortak bir tuzağa düşmüştü:
//  • Ayrı bir "ölçüm katmanı" (opacity 0) + ayrı animasyon katmanı.
//  • Ölçüm her veri tick'inde yeniden width emit ediyor, küçük tolerans
//    bile aşılınca @State startDate sıfırlanıyor → animasyon her saniye
//    en başa dönüyor, gözle "kaymıyor" görünüyor.
//  • truncatingRemainder + Date() referans noktası uzun süreçte
//    Double presisyon kaybı.
//
// Yeni pattern (kanonik):
//  • Tek render path. tickerRow'un birinci kopyası background GeometryReader
//    ile kendi genişliğini ölçer; ikinci kopya yan yana basılır. ÖLÇÜM
//    ANİMASYONA GÖMÜLÜ.
//  • Offset, sistem zamanı (timeIntervalSince1970) modulo contentWidth
//    olarak hesaplanır. State sıfırlama yok, kullanıcı sayfaya geri
//    döndüğünde animasyon "kaldığı yerden" devam eder.
//  • CANLI pill ZStack içinde ÜSTTE çizilir; kayan içeriğin başına 56pt
//    leading boşluk içerikten geliyor (pill'in altına denk gelmesin).

struct MarqueeTicker: View {
    let items: [TickerItem]
    private let pixelsPerSecond: Double = 42

    // 2026-04-25 H-31 — `.task { }` async loop. Önceki üç deneme
    // (CADisplayLink, withAnimation.repeatForever, TimelineView) bu
    // view hierarchy'de bir şekilde state cycle'a değişiklik
    // iletemiyordu. async loop main actor üzerinde Task.sleep
    // ritmiyle offset @State'ini sürekli günceller — SwiftUI her
    // mutation'da redraw mecbur. View ekrandan kalkınca .task
    // otomatik iptal eder, leak yok.
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    /// GeometryReader ölçümü çalışmaması durumunda bantın hareketsiz
    /// kalmaması için fallback. Tahmini her item ~140pt + 56pt leading
    /// buffer; gerçek ölçüm gelince üzerine yazılır.
    private var effectiveContentWidth: CGFloat {
        if contentWidth > 10 { return contentWidth }
        let estimated = CGFloat(displayItems.count) * 140 + 56
        return max(estimated, 600)
    }

    private var displayItems: [TickerItem] {
        items.isEmpty ? Self.placeholderItems : items
    }

    private static let placeholderItems: [TickerItem] = [
        .init(id: "_SPY_PH", label: "S&P", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
        .init(id: "_QQQ_PH", label: "NDX", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
        .init(id: "_VIX_PH", label: "VIX", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
        .init(id: "_GLD_PH", label: "GOLD", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
        .init(id: "_BTC_PH", label: "BTC", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
        .init(id: "_ETH_PH", label: "ETH", price: nil, percentChange: nil,
              isSafeHavenCandidate: false, status: .index),
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            InstitutionalTheme.Colors.surface1

            // KAYAN İÇERİK — iki yan yana kopya, offset @State ile sola itilir.
            // İlk kopyanın altında GeometryReader contentWidth'i ölçer;
            // .task async loop offset'i 60fps ritmiyle azaltır, contentWidth'e
            // ulaşınca wrap eder.
            HStack(spacing: 0) {
                tickerRow(items: displayItems)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TickerWidthKey.self,
                                value: geo.size.width
                            )
                        }
                    )
                tickerRow(items: displayItems)
            }
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: offset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.04),
                        .init(color: .black, location: 0.96),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )

            // 2026-04-25 H-31 (T2 visual): "CANLI" mono caps pill kaldırıldı.
            // Yerine sadece küçük bir dot — bandın canlı veri taşıdığı bir
            // bakışta okunur, ama yazı/kutu/border yok. Sade.
            ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 6)
                .padding(.leading, 14)
        }
        .frame(height: 36)
        .clipped()
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.border)
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .onPreferenceChange(TickerWidthKey.self) { width in
            // İlk geçerli ölçümde set; mikro varyasyon (5px<) görmezden gel
            // ki text içeriği değiştikçe contentWidth flicker etmesin.
            guard width > 10 else { return }
            if contentWidth == 0 || abs(width - contentWidth) > 5 {
                contentWidth = width
            }
        }
        .task {
            // Async animasyon loop — view ekranda olduğu sürece çalışır,
            // ekrandan kalkınca SwiftUI Task'ı otomatik iptal eder.
            // Task.sleep ile ~60fps ritim, dt-based offset.
            let frameNs: UInt64 = 16_666_666 // ~16.67ms = 60fps
            var lastTime = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: frameNs)
                let now = Date()
                let dt = now.timeIntervalSince(lastTime)
                lastTime = now

                let width = effectiveContentWidth
                guard width > 10 else { continue }

                let dx = CGFloat(dt * pixelsPerSecond)
                offset -= dx
                if offset <= -width {
                    offset += width
                }
            }
        }
    }

    @ViewBuilder
    private func tickerRow(items: [TickerItem]) -> some View {
        HStack(spacing: 0) {
            // Sol kenar dot'unun altına denk gelmesin diye küçük leading buffer.
            Spacer().frame(width: 28)
            ForEach(items) { item in
                TickerCell(item: item)
                tickerSeparator
            }
        }
    }

    private var tickerSeparator: some View {
        Rectangle()
            .fill(InstitutionalTheme.Colors.border)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 10)
    }
}

// MARK: - Ticker Cell

private struct TickerCell: View {
    let item: TickerItem

    // 2026-04-25 H-31 (T2): leading arrow + ⚓ emoji + percent kapsülü kaldırıldı.
    // Sembol mono medium, fiyat mono regular, yüzde değişim sadece renkli text
    // (kapsülsüz). Safe haven recommended → sembol aurora; contraindicated →
    // sembol soluk; renk dilini emojinin yerine geçirdi.
    var body: some View {
        HStack(spacing: 6) {
            Text(item.label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(labelColor)

            if let price = item.price, price > 0 {
                Text(formatPrice(price))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            if let pct = item.percentChange {
                Text(formattedChange(pct))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(changeColor(pct))
            } else {
                Text("—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .opacity(item.status == .safeContraindicated ? 0.5 : 1.0)
    }

    private var labelColor: Color {
        switch item.status {
        case .index:                return InstitutionalTheme.Colors.textPrimary
        case .safeRecommended:      return InstitutionalTheme.Colors.aurora
        case .safeContraindicated:  return InstitutionalTheme.Colors.textTertiary
        default:                    return InstitutionalTheme.Colors.textSecondary
        }
    }

    private func changeColor(_ pct: Double) -> Color {
        switch item.status {
        case .safeRecommended:
            return pct >= 0 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson
        case .safeContraindicated:
            return InstitutionalTheme.Colors.textTertiary
        case .index where item.label == "VIX":
            // VIX için yön-tersi: yükseliş korku demek, turuncu/crimson
            return pct >= 0 ? InstitutionalTheme.Colors.titan : InstitutionalTheme.Colors.aurora
        default:
            return pct >= 0 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 10_000 { return String(format: "%.0f", price) }
        if price >= 1_000  { return String(format: "%.0f", price) }
        if price >= 100    { return String(format: "%.2f", price) }
        if price >= 1      { return String(format: "%.2f", price) }
        return String(format: "%.4f", price)
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
