import SwiftUI
import Combine

struct HermesFeedView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var feedState = HermesFeedState()
    @State private var selectedScope = 0

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
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
        .navigationTitle("HERMES")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if feedState.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(action: {
                        Task { await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist) }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(InstitutionalTheme.Colors.primary)
                    }
                }
            }
        }
        .task {
            await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist)
        }
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
                            NavigationLink(destination: StockDetailView(symbol: insight.symbol, viewModel: viewModel)) {
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

    private var accentColor: Color {
        switch event.polarity {
        case .positive: return InstitutionalTheme.Colors.positive
        case .negative: return InstitutionalTheme.Colors.negative
        case .mixed: return InstitutionalTheme.Colors.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.symbol)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                Text(timeAgo(event.publishedAt))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Text(event.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(event.eventType.displayTitleTR)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.7))

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                    Text(sentimentLabel())
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.1))
                .cornerRadius(6)
            }

            Text(event.summaryTRShort ?? event.rationaleShort)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.8))
                .lineLimit(3)

            HStack(spacing: 8) {
                tag("Skor: \(Int(event.finalScore))")
                tag("Güven: \(Int(event.confidence * 100))%")
                tag(event.horizonHint.rawValue)
            }
        }
        .padding(14)
        .institutionalCard(scale: .insight, elevated: false)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func sentimentLabel() -> String {
        if let label = event.sentimentLabel {
            return label.displayTitle.uppercased()
        }
        switch event.polarity {
        case .positive: return "OLUMLU"
        case .negative: return "OLUMSUZ"
        case .mixed: return "KARMA"
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(InstitutionalTheme.Colors.surface2)
            .cornerRadius(4)
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
            HStack {
                Text(insight.symbol)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(InstitutionalTheme.Colors.primary.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                Text(timeAgo(insight.createdAt))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Text(insight.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(2)

            if !insight.impactSentenceTR.isEmpty {
                Text(insight.impactSentenceTR)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.7))
                    .lineLimit(2)
            }

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForSentiment(insight.sentiment))
                        .frame(width: 6, height: 6)
                    Text(insight.sentiment.displayTitle)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(colorForSentiment(insight.sentiment))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(colorForSentiment(insight.sentiment).opacity(0.1))
                .cornerRadius(6)

                Spacer()

                Text("Etki: \(Int(insight.impactScore))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(insight.impactScore > 60 ? InstitutionalTheme.Colors.positive : (insight.impactScore < 40 ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textSecondary))
            }
        }
        .padding(14)
        .institutionalCard(scale: .insight, elevated: false)
    }

    private func colorForSentiment(_ s: NewsSentiment) -> Color {
        switch s {
        case .strongPositive: return InstitutionalTheme.Colors.positive
        case .weakPositive: return InstitutionalTheme.Colors.positive.opacity(0.7)
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .weakNegative: return InstitutionalTheme.Colors.negative.opacity(0.7)
        case .strongNegative: return InstitutionalTheme.Colors.negative
        }
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
            HStack {
                Text(article.symbol)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Spacer()
                Text(timeAgo(article.publishedAt))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Text(article.headline)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineLimit(3)

            Text(article.source)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding(12)
        .institutionalCard(scale: .micro, elevated: false)
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

            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 100, height: 100)
                    .blur(radius: 5)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundColor(InstitutionalTheme.Colors.primary.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("HABER AKIŞI TARANIYOR")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Text("Hermes yapay zekası haberleri analiz ediyor...")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            ProgressView()
                .scaleEffect(1.2)
                .tint(InstitutionalTheme.Colors.primary)

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

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(InstitutionalTheme.Colors.warning)

            Text(message)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("TEKRAR DENE")
                }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(InstitutionalTheme.Colors.primary)
                .cornerRadius(8)
            }

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

            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text(scope == 0 ? "TAKİP LİSTESİ BOŞ" : "HABER BULUNAMADI")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Text(scope == 0 ? "Takip listenizdeki hisseler için haber bulunamadı." : "Genel piyasa haberi bulunamadı.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("TARA")
                }
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(InstitutionalTheme.Colors.primary)
                .cornerRadius(8)
            }

            Spacer()
        }
    }
}

struct ScopeSelectorBar: View {
    @Binding var selectedScope: Int

    var body: some View {
        HStack(spacing: 0) {
            ScopeButton(title: "PORTFÖY & TAKİP", isSelected: selectedScope == 0) {
                withAnimation { selectedScope = 0 }
            }

            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(width: 1, height: 20)

            ScopeButton(title: "GENEL PİYASA", isSelected: selectedScope == 1) {
                withAnimation { selectedScope = 1 }
            }
        }
        .padding(4)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(10)
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
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(isSelected ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? InstitutionalTheme.Colors.primary.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? InstitutionalTheme.Colors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
    }
}
