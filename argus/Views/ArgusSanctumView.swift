import SwiftUI

// MARK: - ARGUS SANCTUM VIEW
/// Ana hisse detay ekrani - Argus Konseyi gorunum.
/// Theme ve modul tipleri SanctumTypes.swift'te tanimli.
struct ArgusSanctumView: View {
    let symbol: String
    // LEAVING LEGACY VM BUT REMOVING OBSERVATION TO STOP RE-RENDERS
    let viewModel: TradingViewModel 
    @StateObject private var vm: SanctumViewModel
    
    init(symbol: String, viewModel: TradingViewModel) {
        self.symbol = symbol
        self.viewModel = viewModel
        self._vm = StateObject(wrappedValue: SanctumViewModel(symbol: symbol))
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    // State
    @State private var selectedModule: SanctumModuleType? = nil
    @State private var selectedBistModule: SanctumBistModuleType? = nil
    @State private var pulseAnimation = false
    @State private var rotateOrbit = false
    @State private var showDecision = false
    @State private var showDebateSheet = false
    @State private var showChronosLabSheet = false
    @State private var showArgusLabSheet = false
    @State private var showObservatorySheet = false
    @State private var showAlkindusSheet = false
    @State private var showAnalystReportSheet = false // NEW: Quick Access to AI Report
    
    // Legacy type alias for internal references
    typealias ModuleType = SanctumModuleType
    typealias BistModuleType = SanctumBistModuleType
    
    // Orbit Animation Parameters
    // Only used for visualization, logic is in ViewModel
    private let orbitRadius: CGFloat = 130
    private let animationDuration: Double = 40
    
    // Modules calculated property
    var modules: [ModuleType] {
        ModuleType.allCases
    }
    
    // BIST Modülleri - Konsolidasyon sonrası
    // TAHTA = Grafik + MoneyFlow + RS (Teknik)
    // KASA = Bilanço + Faktör (Temel)
    // Diğer modüller aşamalı olarak REJİM'e taşınacak
    var bistModules: [BistModuleType] = [
        .tahta, // Teknik + Hacim + Takas -> Orion (Cyan)
        .kasa,  // Temel + Bilanço -> Atlas (Gold)
        .kulis, // Haber + Sentiment -> Hermes (Orange)
        .rejim  // Makro + Oracle + Sektör -> Aether (Purple)
    ]
    var moduleCount: Double {
        Double(bistModules.count)
    }

    @State private var showTradeSheet = false
    @State private var tradeAction: TradeAction = .buy
    
    enum TradeAction { case buy, sell }

    var body: some View {
        ZStack {
            // 1. Background
            Color.black.ignoresSafeArea() // Fallback to prevent white screen
            SanctumTheme.bg.ignoresSafeArea()
            
            // 2. Main Content
            // 2. Main Content
            Group {
                if vm.isLoading && vm.quote == nil {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    VStack(spacing: 0) {
                        headerView
                        footerHelper // Pantheon modülleri - Header altında (küçük toplar)
                        Spacer().frame(height: 40)
                        centerCoreArea
                        Spacer()
                    }
                }
            }
            .blur(radius: (selectedModule != nil || selectedBistModule != nil) ? 10 : 0)
            .scaleEffect((selectedModule != nil || selectedBistModule != nil) ? 0.95 : 1.0)
            .animation(.spring(), value: selectedModule)
            .animation(.spring(), value: selectedBistModule)
            
            // 3. Overlays
            backButtonOverlay
            
            // 4. HoloPanel (Module Details)
            if let module = selectedModule {
                HoloPanelView(
                    module: module,
                    viewModel: viewModel,
                    vm: vm,
                    symbol: symbol,
                    showChronosLabSheet: $showChronosLabSheet,
                    showArgusLabSheet: $showArgusLabSheet,
                    onClose: { withAnimation { selectedModule = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // 5. BIST HoloPanel (Handling BIST Mapping)
            if let bistMod = selectedBistModule {
                // Map BIST module to Global equivalent for HoloPanel
                let mappedModule: ModuleType = {
                    switch bistMod {
                    case .tahta: return .orion
                    case .kasa: return .atlas
                    case .kulis: return .hermes
                    case .rejim: return .aether
                    default: return .orion // Fallback for other types
                    }
                }()
                
                HoloPanelView(
                    module: mappedModule,
                    viewModel: viewModel,
                    vm: vm,
                    symbol: symbol,
                    showChronosLabSheet: $showChronosLabSheet,
                    showArgusLabSheet: $showArgusLabSheet,
                    onClose: { withAnimation { selectedBistModule = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // 6. Sheets & Modals
            // Trade Action Panel (Floating)
            VStack {
                Spacer()
                if let quote = vm.quote, selectedModule == nil && selectedBistModule == nil {
                    SanctumTradePanel(
                        symbol: symbol,
                        currentPrice: quote.currentPrice,
                        onBuy: {
                            self.tradeAction = .buy
                            self.showTradeSheet = true
                        },
                        onSell: {
                            self.tradeAction = .sell
                            self.showTradeSheet = true
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom))
                }
            }
            .zIndex(90)

            // 7. ARGUS ANALYST FAB (Quick Access)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if selectedModule == nil && selectedBistModule == nil {
                        Button(action: { showAnalystReportSheet = true }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.tint)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Theme.tint.opacity(0.4), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 100) // Align with Trade Panel or slightly above
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .zIndex(95) // Above Trade Panel (90), Below HoloPanel (100)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTradeSheet) {
            SanctumTradeSheet(
                symbol: symbol,
                viewModel: viewModel,
                action: tradeAction
            )
        }
        // Auxiliary Sheets
        .sheet(isPresented: $showDebateSheet) { debateSheetContent }
        .sheet(isPresented: $showChronosLabSheet) { chronosLabSheetContent }
        .sheet(isPresented: $showArgusLabSheet) { argusLabSheetContent }
        .sheet(isPresented: $showObservatorySheet) { observatorySheetContent }
        .sheet(isPresented: $showAlkindusSheet) { alkindusSheetContent }
        .sheet(isPresented: $showAnalystReportSheet) {
            ArgusAnalystReportView(symbol: symbol, viewModel: viewModel)
        }
        .task {
            // Ensure data is loaded when view appears
            if vm.quote == nil {
                await vm.loadData()
            }
        }
    }

    // MARK: - Subviews (Computed Properties)
    
    // 1. BACK BUTTON
    private var backButtonOverlay: some View {
        VStack {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Terminal")
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(SanctumTheme.ghostGrey)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                Spacer()
                
                // Alkindus Button (Brain)
                Button(action: { showAlkindusSheet = true }) {
                    AlkindusAvatarView(size: 24, isThinking: false, hasIdea: false)
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                
                // Observatory Button
                Button(action: { showObservatorySheet = true }) {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 18))
                        .foregroundColor(SanctumTheme.titanGold)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
    
    // 2. HEADER
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
                .shadow(color: SanctumTheme.hologramBlue.opacity(0.5), radius: 10)
            
            if let quote = vm.quote {
                VStack(spacing: 6) {
                    Text(String(format: "%.2f", quote.currentPrice))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor((quote.percentChange ?? 0) >= 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                    
                    // NEW: SIGNAL CAPSULE (Restored Feature)
                    Button(action: { showDebateSheet = true }) {
                        SanctumSignalCapsule(
                            signal: vm.grandDecision,
                            dataHealth: .healthy
                        )
                    }
                }
            }
        }
        .padding(.top, 50)
    }
    
    // 3. CENTER CORE
    private var centerCoreArea: some View {
        ZStack {
            // The Dial
            CenterCoreView(symbol: symbol, viewModel: viewModel, showDecision: $showDebateSheet)
            
            // Orbiting Satellites (Modules)
            // BIST vs Global Separation
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // BIST MODULES ORBIT
                ForEach(0..<bistModules.count, id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(bistModules.count)) - 90 // Start from Top
                    let mod = bistModules[i]
                    
                    BistOrbView(module: mod)
                        .offset(x: cos(angle * .pi / 180) * orbitRadius, y: sin(angle * .pi / 180) * orbitRadius)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedBistModule = mod
                                self.showDecision = true
                            }
                        }
                }
            } else {
                // GLOBAL MODULES ORBIT (Classic Argus)
                let globalModules: [ModuleType] = [.orion, .atlas, .aether, .hermes]
                ForEach(0..<globalModules.count, id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(globalModules.count)) - 90
                    let mod = globalModules[i]
                    
                    OrbView(module: mod, viewModel: viewModel, symbol: symbol)
                        .offset(x: cos(angle * .pi / 180) * orbitRadius, y: sin(angle * .pi / 180) * orbitRadius)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedModule = mod
                                self.showDecision = true
                            }
                        }
                }
            }
        }
        .frame(height: 260) // Daha kompakt - yukarıda konumlanır
    }
    
    // ALKINDUS SHEET CONTENT
    private var alkindusSheetContent: some View {
        NavigationView {
            AlkindusDashboardView()
                .navigationBarItems(trailing: Button("Kapat") { showAlkindusSheet = false })
        }
    }
    
    // 4. FOOTER (Pantheon)
    private var footerHelper: some View {
         PantheonDeckView(
            symbol: symbol,
            viewModel: viewModel,
            isBist: symbol.uppercased().hasSuffix(".IS"),
            selectedModule: $selectedModule,
            selectedBistModule: $selectedBistModule
        )
    }
    
    // 5. SHEETS
    private var debateSheetContent: some View {
        NavigationView {
             if let decision = viewModel.grandDecisions[symbol] {
                 SymbolDebateView(decision: decision, viewModel: viewModel, isPresented: $showDebateSheet)
                     .navigationTitle("Konsey Tartışması")
                     .navigationBarHidden(true) // Custom header in view
             } else {
                 Text("Henüz karar oluşmadı.")
                     .navigationBarItems(trailing: Button("Kapat") { showDebateSheet = false })
             }
        }
    }
    
    private var chronosLabSheetContent: some View {
         NavigationView {
             ChronosLabView(viewModel: ChronosLabViewModel())
                 .environmentObject(viewModel) 
                 .navigationBarItems(trailing: Button("Kapat") { showChronosLabSheet = false })
         }
    }
    
    private var argusLabSheetContent: some View {
         NavigationView {
             ArgusLabView()
                 .environmentObject(viewModel)
                 .navigationBarItems(trailing: Button("Kapat") { showArgusLabSheet = false })
         }
    }
    
    private var observatorySheetContent: some View {
         NavigationView {
             ObservatoryContainerView()
                 .navigationBarItems(trailing: Button("Kapat") { showObservatorySheet = false })
         }
    }
}

// MARK: - COMPONENTS

// OrbView ve BistOrbView -> Views/Sanctum/SanctumOrbViews.swift

// CenterCoreView -> Views/Sanctum/SanctumCenterCore.swift

// MARK: - PANTHEON (THE OVERWATCH DECK)
// PantheonDeckView ve PantheonFlankView -> Views/Sanctum/SanctumPantheon.swift

// Custom Shape for Chiron
struct HoloPanelView: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    @ObservedObject var vm: SanctumViewModel
    let symbol: String
    @Binding var showChronosLabSheet: Bool
    @Binding var showArgusLabSheet: Bool
    let onClose: () -> Void
    
    // State for async data loading
    @State private var chironPulseWeights: ChironModuleWeights?
    @State private var chironCorseWeights: ChironModuleWeights?
    @State private var showBacktestSheet = false
    @State private var showInfoCard = false
    @State private var showImmersiveChart = false // NEW: Full Screen Charts
    @State private var showStrategySheet = false // NEW: Multi-Timeframe Strategy Dashboard
    
    var body: some View {
        ZStack { // Wrap in ZStack for Info Card Overlay
            VStack(spacing: 0) {
                // Holo Header
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(module.color)
                    
                    // LOCALIZED NAMES FOR BIST (Eski Borsacı Jargonu)
                    let title: String = {
                        if symbol.uppercased().hasSuffix(".IS") {
                            switch module {
                            case .aether: return "SİRKİYE"
                            case .orion: return "TAHTA"
                            case .atlas: return "KASA"
                            case .hermes: return "KULİS"
                            case .chiron: return "KISMET"
                            default: return module.rawValue
                            }
                        } else {
                            return module.rawValue
                        }
                    }()
                    
                    Text(title)
                        .font(.headline)
                        .bold()
                        .tracking(2)
                        .foregroundColor(.white)
                    
                    // NEW: Info Button
                    Button(action: { withAnimation { showInfoCard = true } }) {
                        Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(module.color.opacity(0.8))
                    }
                    
                    // NEW: Expand Chart Button (Only if candles exist)
                    let candles = vm.candles
                    if !candles.isEmpty && (module == .orion || module == .atlas || module == .aether) {
                        Button(action: { showImmersiveChart = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16))
                                .foregroundColor(module.color.opacity(0.8))
                        }
                        .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding()
                .background(module.color.opacity(0.2))
                
                Divider().background(module.color)
                
                // Holo Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(module.description)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                        
                        // DYNAMIC CONTENT BASED ON MODULE
                        contentForModule(module)
                    }
                    .padding()
                    .padding(.bottom, 100) // Tab bar clearance
                }
            }
            .task {
                if module == .chiron {
                    // Load weights from ChironWeightStore
                    chironPulseWeights = await ChironWeightStore.shared.getWeights(symbol: symbol, engine: .pulse)
                    chironCorseWeights = await ChironWeightStore.shared.getWeights(symbol: symbol, engine: .corse)
                }
            }
            
            // System Info Card Overlay
            if showInfoCard {
                SystemInfoCard(entity: mapModuleToEntity(module), isPresented: $showInfoCard)
                    .zIndex(200)
            }
        }
        .fullScreenCover(isPresented: $showImmersiveChart) {
            ArgusImmersiveChartView(
                viewModel: viewModel,
                symbol: symbol
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SanctumTheme.bg.opacity(0.95)) // Deep Navy High Opacity
        .cornerRadius(0) // Full screen usually stays 0, but content inside might be card.
        // Let's keep HoloPanel as the "Base" layer for the module, effectively a new page.
        // User requested "Containers" to be cards. HoloPanel content is the container.

    }
    
    // Helper to map UI Module to System Entity
    private func mapModuleToEntity(_ module: ArgusSanctumView.ModuleType) -> ArgusSystemEntity {
        switch module {
        case .atlas: return .atlas
        case .orion: return .orion
        case .aether: return .aether
        case .hermes: return .hermes
        case .athena: return .argus // Athena maps to Argus main for now
        case .demeter: return .poseidon // Demeter maps to Poseidon (Sectors/Whales similar concept)
        case .chiron: return .demeter // Chiron/Demeter mapping
        case .prometheus: return .orion // Prometheus uses Orion's technical data
        case .council: return .council
        }
    }
    
    @ViewBuilder
    func contentForModule(_ module: ArgusSanctumView.ModuleType) -> some View {
        switch module {
        case .atlas:
            // 🆕 BIST vs Global kontrolü (.IS suffix veya bilinen BIST sembolü)
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // BIST sembolü için .IS suffix ekle (gerekirse)
                let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
                BISTBilancoDetailView(sembol: bistSymbol)
            } else {
                AtlasV2DetailView(symbol: symbol)
            }
            
        case .orion:
            VStack(spacing: 16) {
                // ORION MOTHERBOARD (V2 - Multi-Timeframe)
                if let analysis = vm.orionAnalysis {
                    // Motherboard View with ViewModel binding for reactive updates
                    OrionMotherboardView(
                        analysis: analysis,
                        symbol: symbol,
                        viewModel: vm
                    )
                    .frame(height: 600)
                }
                // ORION LEGACY (V1/1.5 - Single Timeframe Fallback)
                else if let orion = vm.orionScore {
                    // NEW: Technical Consensus Dashboard
                    if let consensus = orion.signalBreakdown {
                        TechnicalConsensusView(breakdown: consensus)
                    }
                    
                    OrionDetailView(
                        symbol: symbol,
                        orion: orion,
                        candles: vm.candles,
                        patterns: viewModel.patterns[symbol] ?? []
                    )
                } else {
                    if vm.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(SanctumTheme.orionColor)
                            Text("Orion analizi yükleniyor...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        OrionMotherboardErrorView(symbol: symbol)
                    }
                }
                
                // NEW: Prometheus - 5 Day Forecast (Shared across versions)
                if !vm.candles.isEmpty, vm.candles.count >= 30, vm.orionAnalysis == nil {
                    // Only show simpler components if not in Motherboard mode (Motherboard is immersive)
                    // Or keep it as "Forward Look" below the board?
                    // Let's keep it below for now.
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: vm.candles.map { $0.close }
                    )
                }
                
                // NEW: Multi-Timeframe Strategy Button
                Button(action: { showStrategySheet = true }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("STRATEJİ MERKEZİ")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Spacer()
                        Text("Scalp • Swing • Position")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color(red: 0.1, green: 0.12, blue: 0.18))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showStrategySheet) {
                NavigationView {
                    StrategyDashboardView(viewModel: viewModel)
                        .navigationBarItems(trailing: Button("Kapat") { showStrategySheet = false })
                }
            }
            
        case .aether:
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // SİRKİYE (BIST)
                SirkiyeDashboardView(viewModel: viewModel)
                    .padding(.vertical, 8)
            } else {
                // AETHER (Global)
                VStack(alignment: .leading, spacing: 16) {
                    // NEW: Global Module Detail Card
                    if let grandDecision = viewModel.grandDecisions[symbol] {
                        let aetherDecision = grandDecision.aetherDecision
                        // Convert AetherDecision to CouncilDecision
                        let councilDecision = CouncilDecision(
                            symbol: symbol,
                            action: .hold, // Aether uses Stance (riskOn/Off), mapping to Hold for generic UI or update logic later
                            netSupport: aetherDecision.netSupport,
                            approveWeight: 0,
                            vetoWeight: 0,
                            isStrongSignal: abs(aetherDecision.netSupport) > 0.5,
                            isWeakSignal: abs(aetherDecision.netSupport) > 0.2,
                            winningProposal: CouncilProposal(
                                proposer: "Aether",
                                proposerName: "Aether Konseyi",
                                action: .hold,
                                confidence: 1.0,
                                reasoning: "Piyasa Rejimi: \(aetherDecision.marketMode.rawValue)\nDuruş: \(aetherDecision.stance.rawValue)",
                                entryPrice: nil,
                                stopLoss: nil,
                                target: nil
                            ),
                            allProposals: [],
                            votes: [],
                            vetoReasons: [],
                            timestamp: Date()
                        )
                        
                        GlobalModuleDetailCard(
                            moduleName: "Aether",
                            decision: councilDecision,
                            moduleColor: SanctumTheme.aetherColor,
                            moduleIcon: "globe.europe.africa.fill"
                        )
                    } else {
                        // Loading State
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(SanctumTheme.aetherColor)
                            Text("Aether Konseyi toplanıyor...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    
                    // NEW: Aether v5 Dashboard Card (Compact)
                    if let macro = viewModel.macroRating {
                        AetherDashboardCard(rating: macro, isCompact: true)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.purple)
                            Text("Makro veriler yükleniyor...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            
        case .hermes:
            VStack(alignment: .leading, spacing: 16) {
                let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
                if isBist {
                    BISTSentimentPulseCard(symbol: symbol)
                } else {
                    SentimentPulseCard(symbol: symbol)
                }
                
                // BIST: Analist Konsensüsü
                if isBist {
                    HermesAnalystCard(symbol: symbol, currentPrice: viewModel.quotes[symbol]?.currentPrice ?? 0)
                }
                
                // NEW: Global Module Detail Card
                if let grandDecision = viewModel.grandDecisions[symbol],
                   let hermesDecision = grandDecision.hermesDecision {
                    // Convert HermesDecision to CouncilDecision
                    let councilDecision = CouncilDecision(
                        symbol: symbol,
                        action: .hold, // Hermes is sentiment based
                        netSupport: hermesDecision.netSupport,
                        approveWeight: 0,
                        vetoWeight: 0,
                        isStrongSignal: hermesDecision.isHighImpact,
                        isWeakSignal: !hermesDecision.isHighImpact && hermesDecision.netSupport > 0.3,
                        winningProposal: CouncilProposal(
                            proposer: "Hermes",
                            proposerName: "Hermes Habercisi",
                            action: .hold,
                            confidence: 1.0,
                            reasoning: "Duygu Durumu: \(hermesDecision.sentiment.displayTitle)\nEtki: \(hermesDecision.isHighImpact ? "YÜKSEK" : "Normal")",
                            entryPrice: nil,
                            stopLoss: nil,
                            target: nil
                        ),
                        allProposals: [],
                        votes: [],
                        vetoReasons: [],
                        timestamp: Date()
                    )
                    
                    GlobalModuleDetailCard(
                        moduleName: "Hermes",
                        decision: councilDecision,
                        moduleColor: SanctumTheme.hermesColor,
                        moduleIcon: "gavel.fill"
                    )
                } else {
                    // No Decision Yet - Show Hermes Intro Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(SanctumTheme.hermesColor)
                            Text("Hermes Kulak Kesidi")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        // Description
                        Text("Hermes, finansal haberleri ve piyasa dedikodularını analiz ederek hisse senedinin medyadaki algısını değerlendirir.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Dynamic Tips
                        VStack(alignment: .leading, spacing: 8) {
                            HermesInfoRow(icon: "newspaper.fill", text: "Haberleri taramak için aşağıdaki butonu kullanın")
                            HermesInfoRow(icon: "chart.line.uptrend.xyaxis", text: "Olumlu haberler fiyat yükselişini destekleyebilir")
                            HermesInfoRow(icon: "exclamationmark.triangle", text: "Olumsuz haberler risk oluşturabilir")
                        }
                    }
                    .padding()
                    .background(SanctumTheme.hermesColor.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Manual Analysis Button (Uses SanctumViewModel)
                Button(action: {
                    Task {
                        await vm.analyzeOnDemand()
                    }
                }) {
                    HStack {
                        if vm.isLoadingNews {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(vm.isLoadingNews ? "Analiz Ediliyor..." : "Haberleri Tara")
                            .font(.caption)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                }
                .disabled(vm.isLoadingNews)

                // Error Message
                if let error = vm.newsErrorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // News Insights (From SanctumViewModel - reactive binding)
                if !vm.newsInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Haber Analizi")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(Array(vm.newsInsights.prefix(5))) { insight in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(insight.headline)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .lineLimit(2)

                                Text(insight.impactSentenceTR)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(3)

                                HStack {
                                    // Sentiment Badge
                                    Text(insight.sentiment.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((insight.sentiment == .strongPositive || insight.sentiment == .weakPositive) ? Color.green.opacity(0.3) : ((insight.sentiment == .strongNegative || insight.sentiment == .weakNegative) ? Color.red.opacity(0.3) : Color.gray.opacity(0.3)))
                                        .cornerRadius(4)
                                        .foregroundColor(.white)

                                    // Impact Score
                                    Text("Etki: \(Int(insight.impactScore))")
                                        .font(.caption2)
                                        .foregroundColor(insight.impactScore > 60 ? .green : (insight.impactScore < 40 ? .red : .gray))

                                    Spacer()

                                    // Time
                                    Text(insight.createdAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                } else if !vm.hermesEvents.isEmpty || !vm.kulisEvents.isEmpty {
                    // Show Hermes Events if available
                    let events = isBist ? vm.kulisEvents : vm.hermesEvents
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isBist ? "Kulis Analizleri" : "Hermes Analizleri")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(Array(events.prefix(5))) { event in
                            HermesEventTeachingCard(
                                viewModel: viewModel,
                                symbol: symbol,
                                scope: isBist ? .bist : .global,
                                injectedEvent: event
                            )
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Henüz haber analizi yok")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Yukarıdaki butona tıklayarak haber taraması başlatın")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            
        case .athena:
            if let athena = viewModel.athenaResults[symbol] {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Smart Beta Puan:").foregroundColor(.white)
                        Spacer()
                        Text("\(Int(athena.factorScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(athena.factorScore > 50 ? .green : .red)
                    }
                    
                    // Factor breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.momentumFactorScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Value:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.valueFactorScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Quality:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.qualityFactorScore))").foregroundColor(.white)
                        }
                    }
                    .font(.caption)
                    
                    Text(athena.styleLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Text("Athena analizi yükleniyor...")
                    .italic().foregroundColor(.gray)
            }
            
        case .demeter:
            // Find relevant sector for this symbol (simplified: show first available or Technology default)
            let demeterScore = viewModel.demeterScores.first(where: { $0.sector == .XLK }) ?? viewModel.demeterScores.first
            
            if let demeter = demeterScore {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sektör Puanı:").foregroundColor(.white)
                        Spacer()
                        Text("\(Int(demeter.totalScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(demeter.totalScore > 50 ? .green : .red)
                    }
                    
                    Text("Sektör: \(demeter.sector.name)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Component breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.momentumScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Şok Etkisi:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.shockImpactScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Rejim:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.regimeScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Genişlik:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.breadthScore))").foregroundColor(.white)
                        }
                    }
                    .font(.caption)
                    
                    // Active shocks
                    if !demeter.activeShocks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktif Şoklar:").font(.caption).foregroundColor(.orange)
                            ForEach(demeter.activeShocks) { shock in
                                Text("• \(shock.type.displayName) \(shock.direction.symbol)")
                                    .font(.caption2)
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
                    }
                    
                    Text("Değerlendirme: \(demeter.grade)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(demeter.totalScore > 60 ? .green : (demeter.totalScore > 40 ? .yellow : .red))
                }
            } else {
                VStack(spacing: 8) {
                    Text("Sektör analizi yükleniyor...")
                        .italic().foregroundColor(.gray)
                    Text("Demeter verisi için lütfen bekleyin veya seç modülünden yükletin.")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            
        case .chiron:
            // Chiron - Learning & Risk Management
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    AlkindusAvatarView(size: 14, isThinking: false, hasIdea: false)
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Chiron Öğrenme Sistemi")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Regime from ArgusDecisions if available
                if let decision = viewModel.argusDecisions[symbol],
                   let chironResult = decision.chironResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Market Rejimi")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(chironResult.regime.descriptor)
                                .font(.headline)
                                .bold()
                                .foregroundColor(chironResult.regime == .trend ? .green : 
                                                chironResult.regime == .riskOff ? .red : .yellow)
                        }
                        
                        Text(chironResult.explanationTitle)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(chironResult.explanationBody)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // PULSE Weights (Short-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.purple)
                        Text("PULSE Ağırlıkları (Kısa Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    
                    if let weights = chironPulseWeights {
                        chironWeightProgressRows(weights: weights, color: .purple)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                // CORSE Weights (Long-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tortoise.fill")
                            .foregroundColor(.blue)
                        Text("CORSE Ağırlıkları (Uzun Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    
                    if let weights = chironCorseWeights {
                        chironWeightProgressRows(weights: weights, color: .blue)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Learning tips
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Nasıl Öğreniyor?")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Text("Chiron, geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik olarak ayarlar. Başarılı modüllerin ağırlığı artar.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // CHRONOS LAB Button (Sheet)
                Button {
                    showChronosLabSheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.title3)
                            .foregroundColor(.cyan)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chronos Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Text("Walk-Forward Validation & Backtest")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // ARGUS LAB Button (Sheet)
                Button {
                    showArgusLabSheet = true
                } label: {
                    HStack {
                        Image(systemName: "flask.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Argus Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Text("İşlem Geçmişi & Öğrenmeler")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
        case .prometheus:
            // Prometheus - 5 Day Price Forecasting (Holt-Winters)
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "crystal.ball")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Prometheus Öngörü Sistemi")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Info Box
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange.opacity(0.8))
                    Text("Prometheus, geçmiş fiyat verilerini Holt-Winters algoritması ile analiz ederek 5 günlük fiyat tahmini üretir. Güven skoru, son dönem volatilitesine göre hesaplanır.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Forecast Card
                if let candles = viewModel.candles[symbol], candles.count >= 30 {
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: candles.map { $0.close }
                    )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        Text("Fiyat verisi yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("En az 30 günlük veri gerekli")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                }
            }
        case .council:
            VStack {
                ArgusAnalystReportView(symbol: symbol, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    func ratioRow(_ label: String, value: Double?, isPercentage: Bool = false) -> some View {
        if let v = value {
            HStack {
                Text(label)
                    .foregroundColor(.gray)
                Spacer()
                if isPercentage {
                    Text(String(format: "%.1f%%", v * 100))
                        .foregroundColor(.white)
                } else {
                    Text(String(format: "%.2f", v))
                        .foregroundColor(.white)
                }
            }
            .font(.caption)
        }
    }
    
    @ViewBuilder
    func scoreBreakdownRow(_ label: String, score: Double, max: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(score / max > 0.6 ? Color.green : (score / max > 0.4 ? Color.yellow : Color.red))
                        .frame(width: geometry.size.width * CGFloat(min(score / max, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(score))/\(Int(max))")
                .font(.caption2)
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func componentProgressRow(_ label: String, score: Double, max: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(score / max, 1.0)), height: 10)
                }
            }
            .frame(height: 10)
            
            Text("\(Int(score))/\(Int(max))")
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func chironWeightProgressRows(weights: ChironModuleWeights, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            chironWeightRow("Orion", weight: weights.orion, color: .cyan)
            chironWeightRow("Atlas", weight: weights.atlas, color: .yellow)
            chironWeightRow("Phoenix", weight: weights.phoenix, color: .orange)
            chironWeightRow("Aether", weight: weights.aether, color: .purple)
            chironWeightRow("Hermes", weight: weights.hermes, color: .green)
            chironWeightRow("Demeter", weight: weights.demeter, color: .brown)
            chironWeightRow("Athena", weight: weights.athena, color: .pink)
        }
    }
    
    @ViewBuilder
    func chironWeightRow(_ label: String, weight: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 55, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(weight, 1.0)), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(weight * 100))%")
                .font(.caption2)
                .foregroundColor(.white)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

struct NeuralNetworkBackground: View {
    @State private var phase = 0.0
    
    var body: some View {
        Canvas { context, size in
            let points = (0..<20).map { _ in
                CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
            }
            
            for point in points {
                for other in points {
                    let dist =  hypot(point.x - other.x, point.y - other.y)
                    if dist < 100 {
                        var path = Path()
                        path.move(to: point)
                        path.addLine(to: other)
                        context.stroke(path, with: .color(SanctumTheme.ghostGrey.opacity(0.1 - (dist/1000))), lineWidth: 1)
                    }
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x-2, y: point.y-2, width: 4, height: 4)), with: .color(SanctumTheme.hologramBlue.opacity(0.3)))
            }
        }
        .opacity(0.3)
    }
}

struct SanctumMiniChart: View {
    let candles: [Candle]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minPrice = candles.map { $0.low }.min() ?? 0
            let maxPrice = candles.map { $0.high }.max() ?? 100
            let priceRange = maxPrice - minPrice
            
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Gradient Fill
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: height))
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                    
                    if index == candles.count - 1 {
                        path.addLine(to: CGPoint(x: xPosition, y: height))
                        path.closeSubpath()
                    }
                }
            }
            .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.01)]), startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - BIST HOLO PANEL (ESKİ BORSACI VERSİYONU)
struct BistHoloPanelView: View {
    let module: ArgusSanctumView.BistModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let onClose: () -> Void
    
    // State
    @State private var showInfoCard = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(module.color)
                    Text(module.rawValue) // TR ISIM
                        .font(.headline)
                        .bold()
                        .tracking(2)
                        .foregroundColor(.white)
                    
                    Button(action: { withAnimation { showInfoCard = true } }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(module.color.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding()
                .background(module.color.opacity(0.2))
                
                Divider().background(module.color)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(module.description)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                        
                        bistContentForModule(module)
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .task {
                if module == .oracle {
                    // Oracle verilerini tazele vs if needed
                }
                if module == .sirkiye {
                    // Sirkiye verilerini tazele
                    await refreshSirkiyeData()
                }
            }
            
            // Info Overlay (Reuse Entity mapping logic or simple hack)
            if showInfoCard {
                // Map BIST module to closest ArgusSystemEntity for help text
                let entity: ArgusSystemEntity = {
                    switch module {
                    // Yeni konsolide modüller
                    case .tahta: return .orion    // TAHTA = Teknik -> Orion
                    case .kasa: return .atlas     // KASA = Temel -> Atlas
                    case .rejim: return .aether   // REJIM = Makro -> Aether
                    // Eski modüller
                    case .bilanco: return .atlas
                    case .grafik: return .orion
                    case .sirkiye: return .aether
                    case .kulis: return .hermes
                    case .faktor: return .argus
                    case .vektor: return .orion
                    case .sektor: return .poseidon
                    case .oracle: return .demeter
                    case .moneyflow: return .poseidon // Moneyflow map to Whale/Poseidon
                    }
                }()
                SystemInfoCard(entity: entity, isPresented: $showInfoCard)
                    .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SanctumTheme.bg.opacity(0.95))
        .cornerRadius(0)
    }
    
    private func refreshSirkiyeData() async {
        // Sirkiye verilerini tazelemek için (Macro snapshot vs)
        // Burada force refresh yapabiliriz
        
        // 1. Dataları al
        guard let candles = await MainActor.run(body: {
            viewModel.candles[symbol]
        }), !candles.isEmpty else { return }
        
        // Ensure minimal candles
        let sortedCandles = candles.sorted { $0.date < $1.date }
        guard let candles = try? sortedCandles.suffix(60).map({ $0 }),
            candles.count >= 50 // Need enough data
        else { return }
        
        // Safely unwrap optional limited candles
        // Actually ArraySlice to Array is safe.
        // let limitCandles = Array(candles) 
        
        // Re-run logic... but this view creates SirkiyeDashboard which uses viewModel.
        // We just need to trigger viewModel refresher if needed.
        // ArgusGrandCouncil convene() handles this internal logic.
        
        // Manually triggering convene for comprehensive update:
        
        // 1. Candles hazirla (Async context safe)
        // let candles = viewModel.candles[symbol] // Main actor isolation issue if accessed directly here?
        // Using MainActor.run above
        
        // We need 'candles' here available to this scope.
        // Using previous guard results.
        
        // 1.1 Limit to 60 (son 60 gün yeterli sirkülasyon için)
        // This logic was in ArgusGrandCouncil.
        
        // Let's call convene on background
        
        // 1. Sirkiye Input hazırlamak için verilere eriş (Main Actor)
        
        // ... (Logic from Step 2594 - refreshSirkiyeData implementation)
        // I will copy exact logic if I can find it.
        // Step 2594 line 1950 implies logic existed.
        
        // Logic from Step 2594 (lines 1940+):
        
        let candleList = Array(candles) // Convert slice to array
        
        // 2. Sirkiye Input
        let usdTry = await MainActor.run { viewModel.quotes["USD/TRY"]?.currentPrice ?? 35.0 }
        let usdTryPrev = await MainActor.run { viewModel.quotes["USD/TRY"]?.previousClose ?? 35.0 }
        
        let sirkiyeInput = SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: usdTryPrev,
            dxy: 104.0, // Default or fetch
            brentOil: 80.0,
            globalVix: 15.0,
            newsSnapshot: nil,
            currentInflation: 45.0,
            policyRate: 50.0,
            xu100Change: nil,
            xu100Value: nil,
            goldPrice: nil
        )
        
        let macro = await MacroSnapshotService.shared.getSnapshot()
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candleList,
            snapshot: nil, // Corrected parameter label
            macro: macro,
            news: nil,
            engine: .pulse,
            sirkiyeInput: sirkiyeInput
        )
        
        await MainActor.run {
            SignalStateViewModel.shared.grandDecisions[symbol] = decision
            print("✅ BistHoloPanel: \(symbol) için BIST kararı (Sirkülasyon) tazelendi.")
        }
    }
    
    @ViewBuilder
    private func bistContentForModule(_ module: ArgusSanctumView.BistModuleType) -> some View {
        // Backend'den BIST karar verilerini al
        let bistDetails = viewModel.grandDecisions[symbol]?.bistDetails

        switch module {
        // MARK: - YENİ KONSOLİDE MODÜLLER

        case .tahta:
            // TAHTA MERKEZİ: Teknik + Sirkülasyon + Takas
            VStack(spacing: 24) {
                 // 1. Orion (Teknik)
                 TahtaView(symbol: symbol)
                 
                 Divider().background(SanctumTheme.orionColor.opacity(0.3))
                 
                 // 2. Sirkülasyon (Hacim / Para Akışı)
                 CirculationAnalysisView(symbol: symbol, viewModel: viewModel)
            }

        case .kasa:
            // KASA MERKEZİ: Bilanço + Faktörler
            VStack(spacing: 24) {
                // 1. Temel Analiz (Atlas)
                let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
                BISTBilancoDetailView(sembol: bistSymbol)
                
                Divider().background(SanctumTheme.atlasColor.opacity(0.3))
                
                // 2. Faktör Analizi (Smart Beta)
                BistFaktorCard(symbol: symbol)
            }

        case .rejim:
            // REJİM MERKEZİ: Makro (Sirkiye) + Sektör + Gelecek (Oracle)
            VStack(spacing: 24) {
                // 1. Sirkiye (Makro Rüzgar)
                SirkiyeDashboardView(viewModel: viewModel)
                
                Divider().background(Color.purple.opacity(0.3))
                
                // 2. Oracle (Gelecek Sinyalleri)
                OracleChamberEmbeddedView()
                    .frame(height: 300)
                
                Divider().background(Color.purple.opacity(0.3))
                
                // 3. Sektör
                BistSektorCard()
            }
            
        case .kulis:
            // KULİS MERKEZİ: Haberler ve Sentiment
             VStack(spacing: 16) {
                // Intro
                BISTSentimentPulseCard(symbol: symbol)
                // Analist Görüşleri
                HermesAnalystCard(symbol: symbol, currentPrice: viewModel.quotes[symbol]?.currentPrice ?? 0)
            }

        // ESKİ MODÜLLER (Fallback)
        default:
             VStack {
                 Text("Modül taşındı.")
                    .font(.caption)
                    .foregroundColor(.gray)
             }
        }
    }
}

// MARK: - Hermes Helper View

struct HermesInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SanctumTheme.hermesColor.opacity(0.8))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
// MARK: - Error View
struct OrionMotherboardErrorView: View {
    let symbol: String
    
    var body: some View {
        VStack(spacing: 16) {
             Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
             
             Text("Analiz Başarısız")
                .font(.headline)
                .foregroundColor(.white)
             
             Text("Heimdall protokolü \(symbol) için teknik verileri derleyemedi. Lütfen internet bağlantısını kontrol edin veya daha sonra tekrar deneyin.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
