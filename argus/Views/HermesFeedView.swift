import SwiftUI
import Combine

// MARK: - HERMES FEED VIEW (Refactored)
// Direct connection to HermesStateViewModel + HermesLLMService
// No more dependency on broken TradingViewModel functions

struct HermesFeedView: View {
    @ObservedObject var viewModel: TradingViewModel
    @StateObject private var feedState = HermesFeedState()
    @State private var selectedScope = 0 // 0: Takip Listem, 1: Genel Piyasa

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scope Selector
                ScopeSelectorBar(selectedScope: $selectedScope)
                    .padding(.vertical, 12)
                    .background(Theme.background)
                    .onChange(of: selectedScope) { _, newValue in
                        Task { await feedState.loadFeed(scope: newValue, watchlist: viewModel.watchlist) }
                    }

                // Content
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
                            .foregroundColor(Theme.tint)
                    }
                }
            }
        }
        .task {
            // Auto-load on appear
            await feedState.loadFeed(scope: selectedScope, watchlist: viewModel.watchlist)
        }
    }

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Show Events (from AI analysis)
                if !feedState.events.isEmpty {
                    ForEach(feedState.events) { event in
                        HermesEventCompactCard(event: event)
                            .padding(.horizontal)
                    }
                }

                // Show Insights (from previous analyses)
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

                // Raw News fallback (to verify fetch even if analysis layer fails)
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

// MARK: - Feed State Manager
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
                // Watchlist Feed
                await loadWatchlistFeed(watchlist: watchlist)
            } else {
                // General Market Feed
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

        // Load from HermesStateViewModel cache first
        let hermesVM = HermesStateViewModel.shared

        for symbol in watchlist {
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            
            if let cachedRaw = hermesVM.newsBySymbol[symbol], !cachedRaw.isEmpty {
                allRawArticles.append(contentsOf: cachedRaw)
            }

            // Check cache
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

            // Check insights cache
            if let cachedInsights = hermesVM.newsInsightsBySymbol[symbol], !cachedInsights.isEmpty {
                allInsights.append(contentsOf: cachedInsights)
                continue
            }

            // Fetch fresh data for this symbol
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

                // Analyze with LLM
                let scope: HermesEventScope = isBist ? .bist : .global
                let events = try await HermesLLMService.shared.analyzeEvents(
                    articles: articles,
                    scope: scope,
                    isGeneral: false
                )

                allEvents.append(contentsOf: events)

                // Cache results
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

        // Sort by date
        self.events = allEvents.sorted { $0.publishedAt > $1.publishedAt }
        self.insights = allInsights.sorted { $0.createdAt > $1.createdAt }
        self.rawArticles = Array(Dictionary(grouping: allRawArticles, by: { $0.id }).values.compactMap { $0.first })
            .sorted { $0.publishedAt > $1.publishedAt }

        if events.isEmpty && insights.isEmpty && rawArticles.isEmpty {
            errorMessage = "Takip listenizdeki hisseler için haber bulunamadı."
        }
    }

    private func loadGeneralFeed() async {
        // Fetch general market news
        do {
            let articles = try await RSSNewsProvider().fetchNews(symbol: "GENERAL", limit: 25)
            self.rawArticles = articles.sorted { $0.publishedAt > $1.publishedAt }

            guard !articles.isEmpty else {
                errorMessage = "Genel piyasa haberi bulunamadı."
                return
            }

            do {
                // Analyze with LLM
                let events = try await HermesLLMService.shared.analyzeEvents(
                    articles: articles,
                    scope: .bist,
                    isGeneral: true
                )

                self.events = events.sorted { $0.publishedAt > $1.publishedAt }

                // Cache
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

// MARK: - Event Compact Card
struct HermesEventCompactCard: View {
    let event: HermesEvent

    private var accentColor: Color {
        switch event.polarity {
        case .positive: return .green
        case .negative: return .red
        case .mixed: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(event.symbol)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                Text(timeAgo(event.publishedAt))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }

            // Headline
            Text(event.headline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            // Event Type
            HStack(spacing: 8) {
                Text(event.eventType.displayTitleTR)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Sentiment Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                    Text(sentimentLabel())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.1))
                .cornerRadius(6)
            }

            // Rationale
            Text(event.summaryTRShort ?? event.rationaleShort)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)

            // Tags
            HStack(spacing: 8) {
                tag("Skor: \(Int(event.finalScore))")
                tag("Güven: \(Int(event.confidence * 100))%")
                tag(event.horizonHint.rawValue)
            }
        }
        .padding(14)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Insight Card
struct HermesInsightCard: View {
    let insight: NewsInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(insight.symbol)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.tint.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                Text(timeAgo(insight.createdAt))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Text(insight.headline)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            if !insight.impactSentenceTR.isEmpty {
                Text(insight.impactSentenceTR)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForSentiment(insight.sentiment))
                        .frame(width: 6, height: 6)
                    Text(insight.sentiment.displayTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(colorForSentiment(insight.sentiment))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(colorForSentiment(insight.sentiment).opacity(0.1))
                .cornerRadius(6)

                Spacer()

                Text("Etki: \(Int(insight.impactScore))")
                    .font(.caption2)
                    .foregroundColor(insight.impactScore > 60 ? .green : (insight.impactScore < 40 ? .red : .gray))
            }
        }
        .padding(14)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(12)
    }

    private func colorForSentiment(_ s: NewsSentiment) -> Color {
        switch s {
        case .strongPositive: return .green
        case .weakPositive: return Color.green.opacity(0.7)
        case .neutral: return .gray
        case .weakNegative: return Color.red.opacity(0.7)
        case .strongNegative: return .red
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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.tint)
                Spacer()
                Text(timeAgo(article.publishedAt))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Text(article.headline)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)

            Text(article.source)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.9))
        }
        .padding(12)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(10)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - State Views

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.secondaryBackground)
                    .frame(width: 100, height: 100)
                    .blur(radius: 5)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.tint.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("HABER AKIŞI TARANIYOR")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("Hermes yapay zekası haberleri analiz ediyor...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            ProgressView()
                .scaleEffect(1.2)
                .tint(Theme.tint)

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
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("TEKRAR DENE")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.tint)
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
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text(scope == 0 ? "TAKİP LİSTESİ BOŞ" : "HABER BULUNAMADI")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(scope == 0 ? "Takip listenizdeki hisseler için haber bulunamadı." : "Genel piyasa haberi bulunamadı.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("TARA")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.tint)
                .cornerRadius(8)
            }

            Spacer()
        }
    }
}

// MARK: - Scope Selector (Preserved)
struct ScopeSelectorBar: View {
    @Binding var selectedScope: Int

    var body: some View {
        HStack(spacing: 0) {
            ScopeButton(title: "PORTFÖY & TAKİP", isSelected: selectedScope == 0) {
                withAnimation { selectedScope = 0 }
            }

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 20)

            ScopeButton(title: "GENEL PİYASA", isSelected: selectedScope == 1) {
                withAnimation { selectedScope = 1 }
            }
        }
        .padding(4)
        .background(Theme.secondaryBackground.opacity(0.5))
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
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.tint.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Theme.tint.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
    }
}
