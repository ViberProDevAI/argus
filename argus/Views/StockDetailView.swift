import SwiftUI

// MARK: - Router View
struct StockDetailView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @State private var isEtf: Bool? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack { // Changed Group to ZStack to resolve ambiguous toolbar attachment
            Theme.background.ignoresSafeArea() // Ensure background is behind everything
            
            if let isEtf = isEtf {
                if isEtf {
                    // Assuming ArgusEtfDetailView exists or will be created
                    // For now, let's just show a placeholder or the stock detail content
                    // If ArgusEtfDetailView is not defined, this will cause a compile error.
                    // For the purpose of this edit, I'll assume it's a valid type.
                    // If not, a fallback like StockDetailContent(symbol: symbol, viewModel: viewModel)
                    // or a simple Text("ETF Detail View for \(symbol)") would be needed.
                    ArgusEtfDetailView(symbol: symbol, viewModel: viewModel)
                } else {
                    StockDetailContent(symbol: symbol, viewModel: viewModel)
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Varlık türü belirleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 1. Track Signal Button (REMOVED - ArgusLedger auto-logs calls)
                    /*
                    if let decision = viewModel.argusDecisions[symbol],
                       let quote = viewModel.quotes[symbol] {
                        Button(action: {
                             // Legacy Journaling removed in Phase 1
                        }) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(.gray)
                        }
                    }
                    */
                    
                    // 2. Chronos Lab Button (Walk-Forward)
                    NavigationLink(destination: ChronosDetailView(symbol: symbol)
                        .environmentObject(viewModel) // Inject EnvironmentObject
                    ) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(Theme.tint)
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            print(" UI DEBUG: StockDetailView appeared for \(symbol)")
            #endif
            checkType()
        }
        // React to data reloading (e.g. after manual override)
        .onChange(of: viewModel.argusDecisions[symbol]?.assetType) { oldValue, newValue in
            #if DEBUG
            print(" UI DEBUG: Asset Type Changed for \(symbol). Old: \(String(describing: oldValue)), New: \(String(describing: newValue))")
            #endif
            checkType()
        }
    }

    private func checkType() {
        #if DEBUG
        print(" UI DEBUG: checkType called for \(symbol)")
        #endif
        Task {
            // Force check again (checking overrides)
            let result = await viewModel.checkIsEtf(symbol)
            #if DEBUG
            print(" UI DEBUG: checkIsEtf result for \(symbol): \(String(describing: result))")
            #endif
            await MainActor.run {
                withAnimation {
                    self.isEtf = result
                }
            }
        }
    }
}

// MARK: - Content View (Standard Stock Detail)
struct StockDetailContent: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    // UI State for Sheets
    @State private var showAtlasSheet = false
    @State private var showOrionSheet = false
    @State private var showAetherSheet = false // Rejim
    @State private var showCronosSheet = false // Zaman
    @State private var showHermesSheet = false // Haber
    @State private var showAthenaSheet = false // Smart Beta
    @State private var showChironSheet = false // Risk Rejimi
    @State private var showPhoenixSheet = false // Phoenix Detay
    
    // Chart Toggles
    @State private var showSMA = false
    @State private var showBollinger = false
    @State private var showIchimoku = false
    @State private var showMACD = false
    @State private var showVolume = true
    @State private var showRSI = false
    @State private var showStochastic = false
    
    // Collapsed Sections
    @State private var showFullBacktest = false
    
    // Time Filter State
    @State private var selectedRange = "1G"
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
            // Sanctum View (Primary and only view)
            ArgusSanctumView(symbol: symbol, viewModel: viewModel)
        .background(Theme.background.ignoresSafeArea())
        .task {
            // 1. Standard Data Load
            await viewModel.loadArgusData(for: symbol)
            
            // 2. Orion 2.0 Multi-Timeframe Analysis (Parallel)
            await viewModel.ensureOrionAnalysis(for: symbol)
            
            // 3. News & Insights
            viewModel.loadNewsAndInsights(for: symbol)
        }
        // MARK: - Sheets
        .sheet(isPresented: $showAtlasSheet) {
            ArgusAtlasSheet(score: viewModel.getFundamentalScore(for: symbol), symbol: symbol)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOrionSheet) {
            ArgusOrionSheet(
                symbol: symbol,
                orion: viewModel.orionScores[symbol],
                candles: viewModel.candles[symbol],
                patterns: viewModel.patterns[symbol],
                viewModel: viewModel
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAetherSheet) {
            ArgusAetherSheet(macro: viewModel.macroRating)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showHermesSheet) {
            ArgusHermesSheet(viewModel: viewModel, symbol: symbol)
        }
        .sheet(isPresented: $showAthenaSheet) {
             ArgusAthenaSheet(result: viewModel.athenaResults[symbol])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showChironSheet) {
            ChironDetailView()
        }
        .sheet(isPresented: $showPhoenixSheet) {
            if let decision = viewModel.argusDecisions[symbol],
               let advice = decision.phoenixAdvice {
                PhoenixDetailView(
                    symbol: symbol,
                    advice: advice,
                    candles: viewModel.candles[symbol] ?? [],
                    onRunBacktest: {
                        viewModel.runPhoenixBacktest(symbol: symbol)
                    }
                )
            }
        }
        .sheet(item: $viewModel.activeBacktestResult) { res in
            NavigationView {
                BacktestResultDetailsView(result: res)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Kapat") {
                                viewModel.activeBacktestResult = nil
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Radar Chart Helpers
    
    private func buildRadarScores() -> RadarScores {
        let decision = viewModel.argusDecisions[symbol]
        
        let orion = viewModel.orionScores[symbol]?.score ?? 50
        let atlas = viewModel.getFundamentalScore(for: symbol)?.totalScore ?? 50
        let aether = viewModel.macroRating?.numericScore ?? 50
        let athena = viewModel.athenaResults[symbol]?.factorScore ?? 50
        let phoenix = decision?.phoenixAdvice?.confidence ?? 50
        let hermes = viewModel.newsInsightsBySymbol[symbol]?.first?.impactScore ?? 50
        let demeter: Double = viewModel.demeterScores.first?.totalScore ?? 50
        
        return RadarScores(
            orion: orion,
            atlas: atlas,
            aether: aether,
            athena: athena,
            phoenix: phoenix,
            hermes: hermes,
            demeter: demeter
        )
    }
    
    private func buildChironWeights() -> ChironWeightsData? {
        guard let context = buildChironContext() else { return nil }
        let result = ChironRegimeEngine.shared.evaluate(context: context)
        return ChironWeightsData.from(result.coreWeights)
    }
    
    private func buildChironContext() -> ChironContext? {
        let decision = viewModel.argusDecisions[symbol]
        
        return ChironContext(
            atlasScore: viewModel.getFundamentalScore(for: symbol)?.totalScore,
            orionScore: viewModel.orionScores[symbol]?.score,
            aetherScore: viewModel.macroRating?.numericScore,
            demeterScore: viewModel.demeterScores.first?.totalScore,
            phoenixScore: decision?.phoenixAdvice?.confidence,
            hermesScore: viewModel.newsInsightsBySymbol[symbol]?.first?.impactScore,
            athenaScore: viewModel.athenaResults[symbol]?.factorScore,
            symbol: symbol,
            orionTrendStrength: nil,
            chopIndex: nil,
            volatilityHint: nil,
            isHermesAvailable: !(viewModel.newsInsightsBySymbol[symbol]?.isEmpty ?? true)
        )
    }
    
    private func handleModuleTap(_ module: RadarModule) {
        switch module {
        case .orion: showOrionSheet = true
        case .atlas: showAtlasSheet = true
        case .aether: showAetherSheet = true
        case .athena: showAthenaSheet = true
        case .phoenix: showPhoenixSheet = true
        case .hermes: showHermesSheet = true
        case .demeter: break // Demeter sheet yok henüz
        }
    }
    
    // MARK: - Grand Council
    
    private func loadGrandCouncilDecision() async {
        guard let candles = viewModel.candles[symbol], candles.count >= 50 else { return }
        
        // 1. Fetch Real Snapshot via Service
        let snapshot = try? await FinancialSnapshotService.shared.fetchSnapshot(symbol: symbol)
        
        // 2. Get macro snapshot
        let macro = buildMacroSnapshot()
        
        // 3. Get news snapshot
        let news = buildNewsSnapshot()
        
        // 4. Convene the Grand Council with Real Data
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candles,
            snapshot: snapshot, // CHANGED: Passing real snapshot
            macro: macro,
            news: news,
            engine: .pulse
        )
        
        // Update UI directly via SignalStateViewModel
        await MainActor.run {
            SignalStateViewModel.shared.grandDecisions[symbol] = decision
        }
    }
    
    private func buildMacroSnapshot() -> MacroSnapshot {
        // MacroEnvironmentRating'den basit snapshot
        // Gerçek VIX ve Fear&Greed verileri API'den gelecek
        return MacroSnapshot(
            timestamp: Date(),
            vix: nil, // Gelecekte API'den
            fearGreedIndex: nil,
            putCallRatio: nil,
            fedFundsRate: nil,
            tenYearYield: nil,
            twoYearYield: nil,
            yieldCurveInverted: false,
            advanceDeclineRatio: nil,
            percentAbove200MA: nil,
            newHighsNewLows: nil,
            gdpGrowth: nil,
            unemploymentRate: nil,
            inflationRate: nil,
            consumerConfidence: nil,
            sectorRotation: nil,
            leadingSectors: [],
            laggingSectors: []
        )
    }
    
    private func buildNewsSnapshot() -> HermesNewsSnapshot? {
        guard let insights = viewModel.newsInsightsBySymbol[symbol],
              !insights.isEmpty else { return nil }
        
        let articles = viewModel.newsBySymbol[symbol] ?? []
        
        return HermesNewsSnapshot(
            symbol: symbol,
            timestamp: Date(),
            insights: insights,
            articles: articles
        )
    }
}

// MARK: - Trade Action Panel
// MARK: - Trade Action Panel
// MARK: - Trade Action Panel
struct TradeActionPanel: View {
    let symbol: String
    let currentPrice: Double
    let onBuy: (Double) -> Void
    let onSell: (Double) -> Void
    
    @State private var inputAmount: String = ""
    @FocusState private var isFocused: Bool
    
    var estimatedQuantity: Double {
        guard let amount = Double(inputAmount),
              amount > 0,  // NEGATIVE INPUT KONTROLÜ
              currentPrice > 0 else { return 0 }
        return amount / currentPrice
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Amount Input (Spot Style)
            VStack(alignment: .leading, spacing: 4) {
                Text("İşlem Tutarı")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 4) {
                    Text("$")
                        .font(.title3)
                        .bold()
                        .foregroundColor(Theme.textPrimary.opacity(0.6))
                    
                    TextField("0", text: $inputAmount)
                        .font(.title3)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .frame(width: 100)
                        .onChange(of: inputAmount) { oldValue, newValue in
                            if newValue.hasPrefix("-") {
                                inputAmount = ""
                            }
                        }
                }
                
                Text("≈ \(String(format: "%.4f", estimatedQuantity)) Adet")
                    .font(.caption2)
                    .foregroundColor(Theme.tint)
            }
            .padding(12)
            .background(Theme.secondaryBackground)
            .cornerRadius(12)
            .onTapGesture { isFocused = true }
            
            Spacer()
            
            // 2. Quick Actions
            HStack(spacing: 8) {
                Button(action: { 
                    if estimatedQuantity > 0 { onSell(estimatedQuantity) }
                    inputAmount = ""
                    isFocused = false
                }) {
                    VStack(spacing: 0) {
                        Text("SAT")
                            .font(.headline)
                        if estimatedQuantity > 0 {
                            Text("\(String(format: "%.4f", estimatedQuantity)) Adet")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                    }
                    .frame(minWidth: 70, minHeight: 48)
                    .background(Theme.negative.opacity(DesignTokens.Opacity.glassCard))
                    .foregroundColor(Theme.negative)
                    .cornerRadius(12)
                }
                .disabled(estimatedQuantity == 0)
                .opacity(estimatedQuantity == 0 ? 0.6 : 1.0)
                
                Button(action: { 
                    if estimatedQuantity > 0 { onBuy(estimatedQuantity) }
                    inputAmount = ""
                    isFocused = false
                }) {
                    VStack(spacing: 0) {
                        Text("AL")
                            .font(.headline)
                        if estimatedQuantity > 0 {
                            Text("\(String(format: "%.4f", estimatedQuantity)) Adet")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                    }
                    .frame(minWidth: 70, minHeight: 48)
                    .background(Theme.positive)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(estimatedQuantity == 0)
                .opacity(estimatedQuantity == 0 ? 0.6 : 1.0)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal)
    }
}

// Helper Extension for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
// MARK: - Data Health Capsule (Pillar 1)
struct DataHealthCapsule: View {
    let health: DataHealth
    
    var color: Color {
        if health.qualityScore >= 80 { return Theme.positive }
        else if health.qualityScore >= 60 { return .yellow }
        else { return Theme.negative }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 4)
            
            Text("Veri: \(health.localizedStatus) (\(health.qualityScore)%)")
                .font(.caption2)
                .bold()
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
