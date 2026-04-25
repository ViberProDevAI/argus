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
    let pixelsPerSecond: Double = 42

    @State private var contentWidth: CGFloat = 0

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

            // KAYAN İÇERİK + ÖLÇÜM TEK KATMANDA.
            // GeometryReader sadece ilk kopyaya bağlı; ikinci kopya görsel.
            // TimelineView her display refresh'te yeni context.date verir;
            // offset bu zaman üzerinden matematiksel olarak hesaplanır,
            // state mutation yok → reset/flicker yok.
            TimelineView(.animation) { context in
                let cycleOffset: CGFloat = {
                    guard contentWidth > 10 else { return 0 }
                    let secs = context.date.timeIntervalSince1970
                    let total = secs * pixelsPerSecond
                    let mod = total.truncatingRemainder(dividingBy: Double(contentWidth))
                    return CGFloat(-mod)
                }()

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
                .offset(x: cycleOffset)
            }
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

            // Sol köşe sabit "CANLI" pill — scroll etmez, üstte kalır.
            HStack(spacing: 5) {
                ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 5)
                Text("CANLI")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(InstitutionalTheme.Colors.aurora)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(InstitutionalTheme.Colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.aurora.opacity(0.35), lineWidth: 0.5)
            )
            .padding(.leading, 8)
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
    }

    @ViewBuilder
    private func tickerRow(items: [TickerItem]) -> some View {
        HStack(spacing: 0) {
            // CANLI pill'in altında okunamayacak içerik için leading buffer.
            Spacer().frame(width: 56)
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

    var body: some View {
        HStack(spacing: 6) {
            // Safe haven rozet (⚓ / ✗) veya durum dotu
            leadingBadge

            // Label (büyük, mono caps)
            Text(item.label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundColor(labelColor)

            // Fiyat (varsa)
            if let price = item.price, price > 0 {
                Text(formatPrice(price))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            // Yüzde pill
            if let pct = item.percentChange {
                Text(formattedChange(pct))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(changeColor(pct))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(changeColor(pct).opacity(0.16))
                    )
            } else {
                Text("—")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .opacity(item.status == .safeContraindicated ? 0.5 : 1.0)
    }

    @ViewBuilder
    private var leadingBadge: some View {
        if item.isSafeHavenCandidate {
            switch item.status {
            case .safeRecommended:
                Text("⚓")
                    .font(.system(size: 9))
                    .foregroundColor(InstitutionalTheme.Colors.aurora)
            case .safeContraindicated:
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
            default:
                ArgusDot(color: InstitutionalTheme.Colors.textTertiary, size: 4)
            }
        } else {
            // Core indeks — yukarı/aşağı minik ok
            if let pct = item.percentChange {
                Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(changeColor(pct))
            } else {
                ArgusDot(color: InstitutionalTheme.Colors.textTertiary, size: 4)
            }
        }
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
