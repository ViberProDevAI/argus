import SwiftUI

struct StockDetailView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @State private var isEtf: Bool? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()
            
            if let isEtf = isEtf {
                if isEtf {
                    ArgusEtfDetailView(symbol: symbol, viewModel: viewModel)
                } else {
                    StockDetailContent(symbol: symbol, viewModel: viewModel)
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Varlık türü belirleniyor...")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ChronosDetailView(symbol: symbol)
                        .environmentObject(viewModel)
                    ) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(InstitutionalTheme.Colors.primary)
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

struct StockDetailContent: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    @State private var showAtlasSheet = false
    @State private var showOrionSheet = false
    @State private var showAetherSheet = false
    @State private var showCronosSheet = false
    @State private var showHermesSheet = false
    @State private var showAthenaSheet = false
    @State private var showChironSheet = false
    @State private var showPhoenixSheet = false
    
    @State private var showSMA = false
    @State private var showBollinger = false
    @State private var showIchimoku = false
    @State private var showMACD = false
    @State private var showVolume = true
    @State private var showRSI = false
    @State private var showStochastic = false
    
    @State private var showFullBacktest = false
    @State private var selectedRange = "1G"
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ArgusSanctumView(symbol: symbol, viewModel: viewModel)
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .task {
            await viewModel.loadArgusData(for: symbol)
            await viewModel.ensureOrionAnalysis(for: symbol)
            viewModel.loadNewsAndInsights(for: symbol)
        }
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
        case .demeter: break
        }
    }
    
    // MARK: - Grand Council
    
    private func loadGrandCouncilDecision() async {
        guard let candles = viewModel.candles[symbol], candles.count >= 50 else { return }
        
        let snapshot = try? await FinancialSnapshotService.shared.fetchSnapshot(symbol: symbol)
        let macro = buildMacroSnapshot()
        let news = buildNewsSnapshot()
        
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candles,
            snapshot: snapshot,
            macro: macro,
            news: news,
            engine: .pulse
        )
        
        await MainActor.run {
            SignalStateViewModel.shared.grandDecisions[symbol] = decision
        }
    }
    
    private func buildMacroSnapshot() -> MacroSnapshot {
        return MacroSnapshot(
            timestamp: Date(),
            vix: nil,
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
            dxy: nil,
            brent: nil,
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

struct TradeActionPanel: View {
    let symbol: String
    let currentPrice: Double
    let onBuy: (Double) -> Void
    let onSell: (Double) -> Void
    
    @State private var inputAmount: String = ""
    @FocusState private var isFocused: Bool
    
    var estimatedQuantity: Double {
        guard let amount = Double(inputAmount),
              amount > 0,
              currentPrice > 0 else { return 0 }
        return amount / currentPrice
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("İşlem Tutarı")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                
                HStack(spacing: 4) {
                    Text("$")
                        .font(InstitutionalTheme.Typography.body)
                        .bold()
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.6))
                    
                    TextField("0", text: $inputAmount)
                        .font(InstitutionalTheme.Typography.body)
                        .bold()
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
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
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.primary)
            }
            .padding(12)
            .institutionalCard(scale: .standard, elevated: false)
            .onTapGesture { isFocused = true }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { 
                    if estimatedQuantity > 0 { onSell(estimatedQuantity) }
                    inputAmount = ""
                    isFocused = false
                }) {
                    VStack(spacing: 0) {
                        Text("SAT")
                            .font(InstitutionalTheme.Typography.bodyStrong)
                        if estimatedQuantity > 0 {
                            Text("\(String(format: "%.4f", estimatedQuantity)) Adet")
                                .font(InstitutionalTheme.Typography.micro)
                                .opacity(0.8)
                        }
                    }
                    .frame(minWidth: 70, minHeight: 48)
                    .background(InstitutionalTheme.Colors.negative.opacity(0.2))
                    .foregroundColor(InstitutionalTheme.Colors.negative)
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
                            .font(InstitutionalTheme.Typography.bodyStrong)
                        if estimatedQuantity > 0 {
                            Text("\(String(format: "%.4f", estimatedQuantity)) Adet")
                                .font(InstitutionalTheme.Typography.micro)
                                .opacity(0.8)
                        }
                    }
                    .frame(minWidth: 70, minHeight: 48)
                    .background(InstitutionalTheme.Colors.positive)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(estimatedQuantity == 0)
                .opacity(estimatedQuantity == 0 ? 0.6 : 1.0)
            }
        }
        .padding(16)
        .institutionalCard(scale: .insight, elevated: true)
        .padding(.horizontal)
    }
}

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

struct DataHealthCapsule: View {
    let health: DataHealth
    
    var color: Color {
        if health.qualityScore >= 80 { return InstitutionalTheme.Colors.positive }
        else if health.qualityScore >= 60 { return InstitutionalTheme.Colors.warning }
        else { return InstitutionalTheme.Colors.negative }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 4)
            
            Text("Veri: \(health.localizedStatus) (\(health.qualityScore)%)")
                .font(InstitutionalTheme.Typography.micro)
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
