import SwiftUI

// MARK: - Atlas (Argus Core) Sheet
struct ArgusAtlasSheet: View {
    let score: FundamentalScoreResult?
    let symbol: String
    
    var body: some View {
        NavigationStack {
            // 🆕 BIST vs Global kontrolü (.IS suffix veya bilinen BIST sembolü)
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                BISTBilancoDetailView(sembol: symbol.uppercased())
            } else {
                AtlasV2DetailView(symbol: symbol)
            }
        }
    }
}

// MARK: - Orion Sheet (Orion 2.0 Motherboard)
struct ArgusOrionSheet: View {
    let symbol: String
    let orion: OrionScoreResult?
    let candles: [Candle]?
    let patterns: [OrionChartPattern]? // Orion V3
    var viewModel: TradingViewModel? = nil // Optional for backward compatibility

    // Dedicated SanctumViewModel for reactive timeframe updates
    @StateObject private var sanctumVM: SanctumViewModel

    init(symbol: String, orion: OrionScoreResult? = nil, candles: [Candle]? = nil, patterns: [OrionChartPattern]? = nil, viewModel: TradingViewModel? = nil) {
        self.symbol = symbol
        self.orion = orion
        self.candles = candles
        self.patterns = patterns
        self.viewModel = viewModel
        self._sanctumVM = StateObject(wrappedValue: SanctumViewModel(symbol: symbol))
    }

    var body: some View {
        NavigationView {
            Group {
                // PRIORITY 1: Use OrionMotherboardView with reactive SanctumViewModel
                if let analysis = sanctumVM.orionAnalysis {
                    OrionMotherboardView(
                        analysis: analysis,
                        symbol: symbol,
                        viewModel: sanctumVM
                    )
                }
                // FALLBACK: Use legacy OrionDetailView if only single-timeframe data available
                else if let orion = orion {
                    OrionDetailView(symbol: symbol, orion: orion, candles: candles, patterns: patterns)
                }
                else {
                    VStack {
                        ProgressView()
                        Text("Orion analizi yukleniyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Aether Sheet (Opens Full Educational Detail View)
struct ArgusAetherSheet: View {
    let macro: MacroEnvironmentRating?

    var body: some View {
        if let macro = macro {
            ArgusAetherDetailView(rating: macro)
        } else {
            NavigationView {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Aether Verileri Yükleniyor...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .navigationTitle("Aether")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Hermes Sheet
// MARK: - Hermes Sheet
struct ArgusHermesSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
            ArgusBistHub(symbol: symbol, viewModel: viewModel)
        } else {
            HermesSheetView(viewModel: viewModel, symbol: symbol)
        }
    }
}

// MARK: - Hermes Shared Views

struct HermesSheetView: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    private var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // BIST Banner
                    if isBist {
                        HStack(spacing: 8) {
                            Text("🇹🇷")
                            Text("BIST Haber Taraması")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Yerel RSS Kaynakları")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(DesignTokens.Opacity.glassCard))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Manual Scan Button
                    Button(action: {
                        Task {
                            await viewModel.analyzeOnDemand(symbol: symbol)
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text(viewModel.isLoadingNews ? "Taranıyor..." : "Haberleri Şimdi Tara")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isBist ? Color.red.opacity(0.2) : Theme.tint.opacity(0.2))
                        .foregroundColor(isBist ? Color.red : Theme.tint)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoadingNews)
                    .padding(.horizontal)
                    
                    // KAP Bildirimleri (Sadece BIST)
                    if isBist, let disclosures = viewModel.kapDisclosures[symbol], !disclosures.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("KAP Bildirimleri", systemImage: "bell.badge.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(disclosures) { news in
                                KAPDisclosureRow(news: news)
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    let events = isBist ? (viewModel.kulisEventsBySymbol[symbol] ?? []) : (viewModel.hermesEventsBySymbol[symbol] ?? [])
                    if events.isEmpty {
                        if viewModel.isLoadingNews {
                            HStack {
                                Spacer()
                                ProgressView("Yapay Zeka Analiz Ediyor...")
                                Spacer()
                            }
                            .padding()
                        } else {

                            if let error = viewModel.newsErrorMessage {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Sanctum2Theme.crimsonRed)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(Sanctum2Theme.crimsonRed)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                            } else {
                                Text(isBist ? "Kulis verisi bulunamadı" : "Hermes verisi bulunamadı")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                    } else {
                        Label(isBist ? "Kulis Analizleri" : "Hermes Analizleri", systemImage: "brain.head.profile")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(events.sorted { $0.publishedAt > $1.publishedAt }) { event in
                            HermesEventTeachingCard(
                                viewModel: viewModel,
                                symbol: symbol,
                                scope: isBist ? .bist : .global
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(isBist ? "🇹🇷 Hermes BIST" : "Hermes Haberleri")
            .background(Theme.background)
        }
    }
}

private struct HermesEventRow: View {
    let event: HermesEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.headline)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text(event.eventType.displayTitleTR)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                badge("Etki \(Int(event.finalScore))")
                badge("Ufuk \(event.horizonHint.rawValue)")
                badge("Güven \(String(format: "%.2f", event.confidence))")
            }
            
            Text("Ders Notu: \(event.rationaleShort)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
            
            if let quote = event.evidenceQuotes.first, !quote.isEmpty {
                Text("Kanıt: \"\(quote)\"")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HermesWhyScoreView(event: event)
        }
        .padding()
        .background(Theme.secondaryBackground.opacity(0.6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
    }
}

struct NewsInsightRow: View {
    let insight: NewsInsight
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.headline)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            Text(insight.summaryTRLong)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack {
                Text(insight.impactSentenceTR)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(Theme.tint)
                
                Spacer()
                
                Text(String(format: "%.0f%% Güven", insight.confidence * 100))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
    }
}

struct KAPDisclosureRow: View {
    let news: KAPDataService.KAPNews
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(news.type.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: news.disclosureTypeColor).opacity(0.2))
                    .foregroundColor(Color(hex: news.disclosureTypeColor))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(news.date.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text(news.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            
            Text(news.summary)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(3)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
