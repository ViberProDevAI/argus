import SwiftUI
import Combine

/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (bars3 holo/text
/// deco + back + refresh action, status satırı scope + yüklenme durumunu
/// gösteriyor). Scope toggle, feed içerikleri ve `HermesFeedState` veri akışı
/// dokunulmadı.
struct HermesFeedView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var feedState = HermesFeedState()
    @State private var selectedScope = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ArgusNavHeader(
                    title: "HERMES",
                    subtitle: "HABER · OLAY · ANALİZ",
                    leadingDeco: .back(onTap: { dismiss() }),
                    titlePill: .init(text: "AKIŞ", tone: .motor(.hermes)),
                    actions: [
                        .custom(sfSymbol: "arrow.clockwise",
                                action: {
                                    Task { await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist) }
                                })
                    ],
                    status: headerStatus
                )

                ScopeSelectorBar(selectedScope: $selectedScope)
                    .padding(.vertical, 12)
                    .background(InstitutionalTheme.Colors.background)
                    .onChange(of: selectedScope) { _, newValue in
                        Task { await feedState.loadFeed(scope: newValue, watchlist: viewModel.watchlist) }
                    }

                if feedState.isLoading {
                    LoadingStateView()
                } else if let error = feedState.errorMessage {
                    ErrorStateView(message: error) {
                        Task { await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist) }
                    }
                } else if feedState.insights.isEmpty && feedState.events.isEmpty && feedState.rawArticles.isEmpty {
                    EmptyFeedView(scope: selectedScope) {
                        Task { await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist) }
                    }
                } else {
                    feedContent
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist)
        }
    }

    private var headerStatus: ArgusNavHeader.Status {
        if feedState.isLoading {
            return .custom(dotColor: InstitutionalTheme.Colors.Motors.hermes,
                           label: "TARANIYOR",
                           trailing: scopeLabel)
        }
        if feedState.errorMessage != nil {
            return .custom(dotColor: InstitutionalTheme.Colors.crimson,
                           label: "HATA",
                           trailing: scopeLabel)
        }
        let total = feedState.events.count + feedState.insights.count + feedState.rawArticles.count
        if total == 0 {
            return .custom(dotColor: InstitutionalTheme.Colors.textTertiary,
                           label: "AKIŞ BOŞ",
                           trailing: scopeLabel)
        }
        return .custom(dotColor: InstitutionalTheme.Colors.Motors.hermes,
                       label: "\(total) KAYIT",
                       trailing: scopeLabel)
    }

    private var scopeLabel: String {
        selectedScope == 0 ? "TAKİP · PORTFÖY" : "GENEL PİYASA"
    }

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !feedState.events.isEmpty {
                    ForEach(feedState.events) { event in
                        HermesEventCompactCard(event: event)
                            .padding(.horizontal)
                    }
                }

                if !feedState.insights.isEmpty && feedState.events.isEmpty {
                    ForEach(feedState.insights) { insight in
                        if insight.symbol != "MARKET" && insight.symbol != "GENERAL" {
                            NavigationLink(destination: ArgusSanctumView(symbol: insight.symbol, viewModel: viewModel)) {
                                HermesInsightCard(insight: insight)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            HermesInsightCard(insight: insight)
                        }
                    }
                    .padding(.horizontal)
                }

                if feedState.events.isEmpty && feedState.insights.isEmpty && !feedState.rawArticles.isEmpty {
                    ForEach(feedState.rawArticles.prefix(40)) { article in
                        RawNewsCard(article: article)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .refreshable {
            await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist)
        }
    }
}

@MainActor
class HermesFeedState: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var events: [HermesEvent] = []
    @Published var insights: [NewsInsight] = []
    @Published var rawArticles: [NewsArticle] = []

    func loadFeed(scope: Int, watchlist: [String]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if scope == 0 {
                await loadWatchlistFeed(watchlist: watchlist)
            } else {
                await loadGeneralFeed()
            }
        }
    }

    private func loadWatchlistFeed(watchlist: [String]) async {
        guard !watchlist.isEmpty else {
            errorMessage = "Takip listeniz boş. Önce hisse ekleyin."
            return
        }

        var allEvents: [HermesEvent] = []
        var allInsights: [NewsInsight] = []
        var allRawArticles: [NewsArticle] = []

        let hermesVM = HermesStateViewModel.shared

        for symbol in watchlist {
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            
            if let cachedRaw = hermesVM.newsBySymbol[symbol], !cachedRaw.isEmpty {
                allRawArticles.append(contentsOf: cachedRaw)
            }

            if isBist {
                if let cached = hermesVM.kulisEventsBySymbol[symbol], !cached.isEmpty {
                    allEvents.append(contentsOf: cached)
                    continue
                }
            } else {
                if let cached = hermesVM.hermesEventsBySymbol[symbol], !cached.isEmpty {
                    allEvents.append(contentsOf: cached)
                    continue
                }
            }

            if let cachedInsights = hermesVM.newsInsightsBySymbol[symbol], !cachedInsights.isEmpty {
                allInsights.append(contentsOf: cachedInsights)
                continue
            }

            do {
                let articles: [NewsArticle]
                if isBist {
                    articles = try await RSSNewsProvider().fetchNews(symbol: symbol, limit: 10)
                } else {
                    articles = try await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 8)
                }

                guard !articles.isEmpty else { continue }
                allRawArticles.append(contentsOf: articles)
                hermesVM.newsBySymbol[symbol] = articles

                let scope: HermesEventScope = isBist ? .bist : .global
                let events = try await HermesLLMService.shared.analyzeEvents(
                    articles: articles,
                    scope: scope,
                    isGeneral: false
                )

                allEvents.append(contentsOf: events)

                if isBist {
                    hermesVM.kulisEventsBySymbol[symbol] = events
                } else {
                    hermesVM.hermesEventsBySymbol[symbol] = events
                }

                print("✅ HermesFeed: \(symbol) için \(events.count) event yüklendi")

            } catch {
                print("⚠️ HermesFeed: \(symbol) hatası: \(error.localizedDescription)")
            }
        }

        self.events = allEvents.sorted { $0.publishedAt > $1.publishedAt }
        self.insights = allInsights.sorted { $0.createdAt > $1.createdAt }
        self.rawArticles = Array(Dictionary(grouping: allRawArticles, by: { $0.id }).values.compactMap { $0.first })
            .sorted { $0.publishedAt > $1.publishedAt }

        if events.isEmpty && insights.isEmpty && rawArticles.isEmpty {
            errorMessage = "Takip listenizdeki hisseler için haber bulunamadı."
        }
    }

    private func loadGeneralFeed() async {
        do {
            let articles = try await RSSNewsProvider().fetchNews(symbol: "GENERAL", limit: 25)
            self.rawArticles = articles.sorted { $0.publishedAt > $1.publishedAt }

            guard !articles.isEmpty else {
                errorMessage = "Genel piyasa haberi bulunamadı."
                return
            }

            do {
                let events = try await HermesLLMService.shared.analyzeEvents(
                    articles: articles,
                    scope: .bist,
                    isGeneral: true
                )

                self.events = events.sorted { $0.publishedAt > $1.publishedAt }
                HermesStateViewModel.shared.hermesEventsBySymbol["GENERAL"] = events

                print("✅ HermesFeed: Genel piyasa için \(events.count) event yüklendi")
            } catch {
                self.events = []
                self.errorMessage = nil
                print("⚠️ HermesFeed: Genel piyasa analiz katmanı hatası, ham haberler listeleniyor: \(error.localizedDescription)")
            }

        } catch {
            errorMessage = "Haber analizi yapılamadı: \(error.localizedDescription)"
            print("❌ HermesFeed: Genel piyasa hatası: \(error)")
        }
    }
}

struct HermesEventCompactCard: View {
    let event: HermesEvent

    private var tone: ArgusChipTone {
        switch event.polarity {
        case .positive: return .aurora
        case .negative: return .crimson
        case .mixed:    return .titan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ArgusChip(event.symbol.uppercased(), tone: tone)
                Spacer()
                Text(timeAgo(event.publishedAt))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Text(event.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(event.eventType.displayTitleTR.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                HStack(spacing: 5) {
                    ArgusDot(color: tone.foreground, size: 5)
                    Text(sentimentLabel())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundColor(tone.foreground)
                }
            }

            Text(event.summaryTRShort ?? event.rationaleShort)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .lineLimit(3)

            HStack(spacing: 6) {
                tag("SKOR %\(Int(event.finalScore))", tone: tone)
                tag("GÜVEN %\(Int(event.confidence * 100))", tone: .holo)
                tag(event.horizonHint.rawValue.uppercased(), tone: .neutral)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(tone.foreground.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private func sentimentLabel() -> String {
        if let label = event.sentimentLabel { return label.displayTitle.uppercased() }
        switch event.polarity {
        case .positive: return "OLUMLU"
        case .negative: return "OLUMSUZ"
        case .mixed:    return "KARMA"
        }
    }

    private func tag(_ text: String, tone: ArgusChipTone) -> some View {
        ArgusChip(text, tone: tone)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct HermesInsightCard: View {
    let insight: NewsInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ArgusChip(insight.symbol.uppercased(), tone: .motor(.hermes), icon: .hermes)
                Spacer()
                Text(timeAgo(insight.createdAt))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Text(insight.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(2)

            if !insight.impactSentenceTR.isEmpty {
                Text(insight.impactSentenceTR)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    ArgusDot(color: sentimentTone(insight.sentiment).foreground, size: 5)
                    Text(insight.sentiment.displayTitle.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundColor(sentimentTone(insight.sentiment).foreground)
                }
                Spacer()
                Text("ETKİ · %\(Int(insight.impactScore))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(impactColor(insight.impactScore))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(impactColor(insight.impactScore).opacity(0.18))
                    )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private func sentimentTone(_ s: NewsSentiment) -> ArgusChipTone {
        switch s {
        case .strongPositive: return .aurora
        case .weakPositive:   return .aurora
        case .neutral:        return .neutral
        case .weakNegative:   return .crimson
        case .strongNegative: return .crimson
        }
    }

    private func impactColor(_ score: Double) -> Color {
        if score > 60 { return InstitutionalTheme.Colors.aurora }
        if score < 40 { return InstitutionalTheme.Colors.crimson }
        return InstitutionalTheme.Colors.textSecondary
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RawNewsCard: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ArgusChip(article.symbol.uppercased(), tone: .motor(.hermes))
                Spacer()
                Text(timeAgo(article.publishedAt))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Text(article.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(3)

            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(article.source.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ArgusOrb(size: 96,
                     ringColor: InstitutionalTheme.Colors.Motors.hermes,
                     glowColor: InstitutionalTheme.Colors.Motors.hermes) {
                MotorLogo(.hermes, size: 48)
            }

            VStack(spacing: 4) {
                Text("HABER AKIŞI TARANIYOR")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
                Text("Hermes yapay zekası haberleri analiz ediyor…")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            ProgressView()
                .scaleEffect(1.1)
                .tint(InstitutionalTheme.Colors.Motors.hermes)

            Spacer()
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ArgusOrb(size: 80,
                     ringColor: InstitutionalTheme.Colors.crimson,
                     glowColor: InstitutionalTheme.Colors.crimson) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
            }

            Text(message)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            v5FeedActionButton(icon: "arrow.clockwise",
                               label: "TEKRAR DENE",
                               tone: .motor(.hermes),
                               action: onRetry)

            Spacer()
        }
    }
}

struct EmptyFeedView: View {
    let scope: Int
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ArgusOrb(size: 80,
                     ringColor: InstitutionalTheme.Colors.border,
                     glowColor: nil) {
                Image(systemName: "newspaper")
                    .font(.system(size: 30))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            VStack(spacing: 6) {
                Text(scope == 0 ? "TAKİP LİSTESİ BOŞ" : "HABER BULUNAMADI")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(scope == 0 ? "Takip listenizdeki hisseler için haber bulunamadı."
                                : "Genel piyasa haberi bulunamadı.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            v5FeedActionButton(icon: "magnifyingglass",
                               label: "TARA",
                               tone: .motor(.hermes),
                               action: onRetry)

            Spacer()
        }
    }
}

/// V5 aksiyon butonu — mono caps + motor renkli kenarlık + dolgu.
private struct v5FeedActionButton: View {
    let icon: String
    let label: String
    let tone: ArgusChipTone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundColor(tone.foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(tone.foreground.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScopeSelectorBar: View {
    @Binding var selectedScope: Int

    var body: some View {
        // V5 pill toggle — market/portföy toggle ile aynı dil.
        HStack(spacing: 4) {
            ScopeButton(title: "PORTFÖY & TAKİP", isSelected: selectedScope == 0) {
                withAnimation(.spring(response: 0.3)) { selectedScope = 0 }
            }
            ScopeButton(title: "GENEL PİYASA", isSelected: selectedScope == 1) {
                withAnimation(.spring(response: 0.3)) { selectedScope = 1 }
            }
        }
        .padding(4)
        .background(
            Capsule().fill(InstitutionalTheme.Colors.surface2)
                .overlay(Capsule().stroke(InstitutionalTheme.Colors.border, lineWidth: 1))
        )
        .padding(.horizontal)
    }
}

struct ScopeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(isSelected ? .white : InstitutionalTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(InstitutionalTheme.Colors.Motors.hermes)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
