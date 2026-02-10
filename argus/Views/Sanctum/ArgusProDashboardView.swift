import SwiftUI

// MARK: - ARGUS SANCTUM 2.0 DASHBOARD
// "The High-Density Terminal"

struct ArgusProDashboardView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // State
    @State private var activeModule: SanctumModuleType? = nil
    
    // Dedicated Sanctum VM for Orion Module
    @StateObject private var sanctumVM: SanctumViewModel

    init(symbol: String, viewModel: TradingViewModel) {
        self.symbol = symbol
        self.viewModel = viewModel
        self._sanctumVM = StateObject(wrappedValue: SanctumViewModel(symbol: symbol))
    }
    
    // Grid Layout (2 Columns)
    // Left Column: Orion (1x1) + Hermes (1x1)
    // Right Column: Atlas (1x1) + Alkindus (1x1)
    // Center: Phoenix (2x1 Spanning)
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Sanctum2Theme.voidBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Cinematic Header
                CinematicHeader(
                    symbol: symbol,
                    price: viewModel.quotes[symbol]?.currentPrice,
                    change: viewModel.quotes[symbol]?.percentChange,
                    sector: "Technology", // TODO: Fetch real sector
                    onDismiss: { presentationMode.wrappedValue.dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 12) {
                        
                        // ROW 1: ORION (Trend) & ATLAS (Fund.)
                        HStack(spacing: 12) {
                            // BLOCK A: ORION (1x1)
                            BentoCard(title: "ORION", icon: "chart.xyaxis.line", accentColor: Sanctum2Theme.neonGreen, height: 160) {
                                orionContent
                            }
                            .onTapGesture { activeModule = .orion }
                            
                            // BLOCK B: ATLAS (1x1)
                            BentoCard(title: "ATLAS", icon: "building.columns.fill", accentColor: Sanctum2Theme.hologramBlue, height: 160) {
                                atlasContent
                            }
                            .onTapGesture { activeModule = .atlas }
                        }
                        
                        // ROW 2: PROMETHEUS (Target) & ATHENA (Signals)
                        HStack(spacing: 12) {
                            // BLOCK C: PROMETHEUS (Was Phoenix)
                            BentoCard(title: "PROMETHEUS", icon: "scope", accentColor: SanctumTheme.titanGold, height: 160) {
                                prometheusContent
                            }
                            .onTapGesture { activeModule = .prometheus }
                            
                            // BLOCK D: ATHENA (New)
                            BentoCard(title: "ATHENA", icon: "owl", accentColor: Sanctum2Theme.amberWarning, height: 160) {
                                athenaContent
                            }
                            .onTapGesture { activeModule = .athena }
                        }
                        
                        // ROW 3: HERMES (News) & ALKINDUS (Strategy)
                        HStack(spacing: 12) {
                            // BLOCK E: HERMES (1x1)
                            BentoCard(title: "HERMES", icon: "bubble.left.and.bubble.right.fill", accentColor: Sanctum2Theme.amberWarning, height: 160) {
                                hermesContent
                            }
                            .onTapGesture { activeModule = .hermes }
                             
                            // BLOCK F: ALKINDUS (1x1)
                            BentoCard(title: "ALKINDUS", icon: "AlkindusIcon", accentColor: Sanctum2Theme.crimsonRed, height: 160) {
                                alkindusContent
                            }
                            .onTapGesture { activeModule = .chiron }
                        }
                        
                        // Footer / Copyright
                        Text("ARGUS TERMINAL v2.2 • SANCTUM CORE")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 20)
                    }
                    .padding(12)
                }
            }
        }
        .navigationBarHidden(true)
        // Reuse existing sheet logic for module details
        .sheet(item: $activeModule) { module in
            NavigationView {
                moduleView(for: module)
            }
        }
    }
    
    // MARK: - MODULE CONTENTS (Micro-Widgets)
    
    // 1. ORION (Trend & RSI)
    private var orionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let score = viewModel.orionScores[symbol] {
                // Big Metric: Trend Direction
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.components.trendDesc.uppercased().replacingOccurrences(of: "TREND: ", with: ""))
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(score.score > 50 ? Sanctum2Theme.neonGreen : Sanctum2Theme.crimsonRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("TREND YÖNÜ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Secondary Metrics: RSI & Signal
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(Int(score.components.rsi ?? 0))")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("RSI")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(Int(score.score))")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(displayColor(for: score.score))
                        Text("GÜÇ")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            } else {
                loadingPlaceholder
            }
        }
    }
    
    // 2. ATLAS (Valuation)
    private var atlasContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let atlas = viewModel.getFundamentalScore(for: symbol) {
                // Valuation Status
                let isCheap = (atlas.valuationGrade ?? "").contains("Ucuz") || (atlas.valuationGrade ?? "").contains("Makul")
                let color = isCheap ? Sanctum2Theme.neonGreen : Sanctum2Theme.crimsonRed
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(atlas.valuationGrade?.uppercased() ?? "N/A")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("DEĞERLEME")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Score & FK
                HStack {
                    VStack(alignment: .leading) {
                        Text(String(format: "%.1f", atlas.totalScore / 10.0)) // Assuming 0-100 scale -> 0-10
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("KALİTE") // Atlas Total Score = Quality
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        if let pe = atlas.financials?.peRatio {
                            Text(String(format: "%.1f", pe))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        } else {
                            Text("N/A")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        Text("F/K")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                
            } else {
                loadingPlaceholder
            }
        }
    }
    
    // 3. PROMETHEUS (Target) - Was PHOENIX
    private var prometheusContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let decision = viewModel.argusDecisions[symbol],
               let phoenix = decision.phoenixAdvice {
                
                // Target Price
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", phoenix.targets.first ?? 0))
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(Sanctum2Theme.hologramBlue)
                        .minimumScaleFactor(0.8)
                    
                    Text("HEDEF FİYAT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Confidence & Stop
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(Int(phoenix.confidence))%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(phoenix.confidence > 70 ? Sanctum2Theme.neonGreen : Sanctum2Theme.amberWarning)
                        Text("GÜVEN")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.2f", (viewModel.quotes[symbol]?.currentPrice ?? 0) * 0.95))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Sanctum2Theme.crimsonRed)
                        Text("STOP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                
            } else {
                loadingPlaceholder
            }
        }
    }
    
    // 4. ATHENA (Signals) - New
    private var athenaContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Check for Athena/Chimera signals
            if let signal = viewModel.chimeraSignals[symbol] {
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.type.turkishName.uppercased())
                        .font(.system(size: 14, weight: .bold)) // Slightly smaller to fit
                        .foregroundColor(Color(hex: signal.type.severityColor))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    Text("SİNYAL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("AKTİF")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("DURUM")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SİNYAL YOK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }
    
    // 5. HERMES (News)
    private var hermesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let insights = viewModel.newsInsightsBySymbol[symbol], !insights.isEmpty, let topNews = insights.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topNews.sentiment.displayTitle.uppercased())
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(sentColor(topNews.sentiment))
                        .lineLimit(1)
                    
                    Text("SENTIMENT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(topNews.headline)
                        .font(.system(size: 9))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                        .lineLimit(2)
                }
            } else {
                VStack(alignment: .center) {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Veri Yok")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                }
            }
        }
    }
    
    // 6. ALKINDUS (Strategy)
    private var alkindusContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Strategy Name
            VStack(alignment: .leading, spacing: 2) {
                Text("TREND TAKİP")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("STRATEJİ")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Risk & Frequency
            HStack {
                VStack(alignment: .leading) {
                    Text("YÜKSEK")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Sanctum2Theme.neonGreen)
                    Text("FREKANS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - HELPERS
    
    private var loadingPlaceholder: some View {
        VStack {
            Spacer()
            ProgressView().tint(InstitutionalTheme.Colors.textSecondary)
            Spacer()
        }
    }
    
    private func displayColor(for score: Double) -> Color {
        if score >= 70 { return Sanctum2Theme.neonGreen }
        if score >= 40 { return Sanctum2Theme.amberWarning }
        return Sanctum2Theme.crimsonRed
    }
    
    private func sentColor(_ s: NewsSentiment) -> Color {
        switch s {
        case .strongPositive, .weakPositive: return SanctumTheme.auroraGreen
        case .strongNegative, .weakNegative: return SanctumTheme.crimsonRed
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    private func timeAgoDisplay(date: Date) -> String {
        return "Now" 
    }
    
    // Module Sheet Builder
    @ViewBuilder
    private func moduleView(for module: SanctumModuleType) -> some View {
        if module == .orion {
            if let analysis = viewModel.orionAnalysis[symbol] {
                // IMPORTANT: Use OrionMotherboardView as requested
                // We map MultiTimeframeAnalysis to it
                OrionMotherboardView(analysis: analysis, symbol: symbol, viewModel: sanctumVM)
                    .navigationBarHidden(true)
            } else {
                // Fallback attempt to create wrapper if only legacy score exists or loading
                // For now just show loading or fallback detail
                 if let scores = viewModel.orionScores[symbol] {
                    // Try to construct a pseudo-analysis or just show DetailView
                    OrionDetailView(
                        symbol: symbol, 
                        orion: scores,
                        candles: viewModel.candles[symbol],
                        patterns: viewModel.patterns[symbol]
                    ).navigationBarHidden(true)
                 } else {
                     Text("Orion Motherboard Verisi Yükleniyor...")
                 }
            }
        } else if module == .atlas {
            AtlasV2DetailView(symbol: symbol).navigationBarHidden(true)
        } else if module == .hermes {
            // DIRECT LINK TO HERMES FEED
            HermesFeedView(viewModel: viewModel)
        } else if module == .prometheus {
            // Link to Phoenix (Prometheus) Scanner
            PhoenixView()
        } else if module == .athena {
             // Link to Athena Factor Analysis
             // We need access to athenaFactor result. 
             // Ideally viewModel should provide it.
             // If not available, we pass nil or try to fetch.
             ArgusAthenaSheet(
                 result: viewModel.athenaResults[symbol],
                 signals: (viewModel.chimeraSignals[symbol] != nil ? [viewModel.chimeraSignals[symbol]!] : [])
             )
        } else if module == .chiron {
            // Strategy Center
            ArgusStrategyCenterView(viewModel: viewModel).navigationBarHidden(true)
        } else {
             Text("Modül Hazırlanıyor: \(module.rawValue)")
        }
    }
}
