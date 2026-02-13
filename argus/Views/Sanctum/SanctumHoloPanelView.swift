import SwiftUI
struct HoloPanelView: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    @ObservedObject var vm: SanctumViewModel
    let symbol: String
    let router: NavigationRouter
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
                    SanctumModuleIconView(module: module, size: 28)
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
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    
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
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(8)
                            .background(Circle().fill(InstitutionalTheme.Colors.surface3))
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
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        
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
                            .padding(.bottom, 20) // Added padding to separate from graph
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
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        OrionMotherboardErrorView(symbol: symbol)
                    }
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
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .padding()
                    .background(InstitutionalTheme.Colors.surface2)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SanctumTheme.hologramBlue.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // NEW: Prometheus - 5 Day Forecast (Moved to Bottom)
                if !vm.candles.isEmpty, vm.candles.count >= 30, vm.orionAnalysis == nil {
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: vm.candles.map { $0.close }
                    )
                    .padding(.top, 16) // Spacing from strategy button
                }
            }

            .sheet(isPresented: $showStrategySheet) {
                NavigationView {
                    StrategyDashboardView(viewModel: viewModel)
                        .navigationBarItems(trailing: Button("Kapat") { showStrategySheet = false })
                }
            }
            
        case .aether:
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // REJİM MERKEZİ (BIST) - Piyasa Rejimi + Makro + Teknik + Sektör
                RejimView(symbol: symbol)
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
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
                                .tint(SanctumTheme.hologramBlue)
                            Text("Makro veriler yükleniyor...")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SanctumTheme.aetherColor)
                            Text("ORACLE LENS")
                                .font(InstitutionalTheme.Typography.micro)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            Spacer()
                        }

                        OracleChamberEmbeddedView()
                            .frame(height: 320)
                    }
                }
            }
            
        case .hermes:
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // KULİS MERKEZİ (BIST) - Duygu Barometresi + Analist + KAP + Temettü
                VStack(spacing: 16) {
                    // 1. Piyasa Duygu Barometresi
                    DuyguBarometresiCard(symbol: symbol)

                    // 2. Analist Konsensüsü (eğitim notlu)
                    AnalistEgitimWrapper(symbol: symbol)

                    // 3. KAP Bildirimleri (eğitim notlu)
                    KAPEgitimWrapper(symbol: symbol)

                    // 4. Temettü & Sermaye (eğitim notlu)
                    TemettuEgitimWrapper(symbol: symbol)

                    // Haberleri Tara Butonu
                    Button(action: {
                        Task { await vm.analyzeOnDemand() }
                    }) {
                        HStack {
                            if vm.isLoadingNews {
                                ProgressView()
                                    .tint(InstitutionalTheme.Colors.textPrimary)
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
                        .background(SanctumTheme.titanGold.opacity(0.3))
                        .cornerRadius(10)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    .disabled(vm.isLoadingNews)

                    // Disclaimer
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                        Text("Eğitim amaçlıdır, yatırım tavsiyesi değildir.")
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // GLOBAL Hermes - eski görünüm koru
                VStack(alignment: .leading, spacing: 16) {
                    SentimentPulseCard(symbol: symbol)

                    // Global Module Detail Card
                    if let grandDecision = viewModel.grandDecisions[symbol],
                       let hermesDecision = grandDecision.hermesDecision {
                        let councilDecision = CouncilDecision(
                            symbol: symbol,
                            action: .hold,
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
                    }

                    // Manual Analysis Button
                    Button(action: {
                        Task { await vm.analyzeOnDemand() }
                    }) {
                        HStack {
                            if vm.isLoadingNews {
                                ProgressView()
                                    .tint(InstitutionalTheme.Colors.textPrimary)
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
                        .background(SanctumTheme.titanGold.opacity(0.3))
                        .cornerRadius(10)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    .disabled(vm.isLoadingNews)

                    if let error = vm.newsErrorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(SanctumTheme.crimsonRed)
                            .padding(.horizontal)
                    }

                    if !vm.newsInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Haber Analizi")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            ForEach(Array(vm.newsInsights.prefix(5))) { insight in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(insight.headline)
                                        .font(.caption).bold()
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        .lineLimit(2)
                                    Text(insight.impactSentenceTR)
                                        .font(.caption2)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                        .lineLimit(3)
                                }
                                .padding()
                                .background(InstitutionalTheme.Colors.surface2)
                                .cornerRadius(10)
                            }
                        }
                    } else if !vm.hermesEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hermes Analizleri")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            ForEach(Array(vm.hermesEvents.prefix(5))) { event in
                                HermesEventTeachingCard(
                                    viewModel: viewModel,
                                    symbol: symbol,
                                    scope: .global,
                                    injectedEvent: event
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "newspaper")
                                .font(.title)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            Text("Henüz haber analizi yok")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
            
        case .athena:
            if let athena = viewModel.athenaResults[symbol] {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Smart Beta Puan:").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(athena.factorScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(athena.factorScore > 50 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                    }
                    
                    // Factor breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(athena.momentumFactorScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        HStack {
                            Text("Value:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(athena.valueFactorScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        HStack {
                            Text("Quality:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(athena.qualityFactorScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                    .font(.caption)
                    
                    Text(athena.styleLabel)
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                }
            } else {
                Text("Athena analizi yükleniyor...")
                    .italic().foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
        case .demeter:
            // Find relevant sector for this symbol (simplified: show first available or Technology default)
            let demeterScore = viewModel.demeterScores.first(where: { $0.sector == .XLK }) ?? viewModel.demeterScores.first
            
            if let demeter = demeterScore {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sektör Puanı:").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(demeter.totalScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(demeter.totalScore > 50 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                    }
                    
                    Text("Sektör: \(demeter.sector.name)")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                    
                    // Component breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(demeter.momentumScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        HStack {
                            Text("Şok Etkisi:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(demeter.shockImpactScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        HStack {
                            Text("Rejim:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(demeter.regimeScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        HStack {
                            Text("Genişlik:").foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(demeter.breadthScore))").foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                    .font(.caption)
                    
                    // Active shocks
                    if !demeter.activeShocks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktif Şoklar:").font(.caption).foregroundColor(SanctumTheme.titanGold)
                            ForEach(demeter.activeShocks) { shock in
                                Text("• \(shock.type.displayName) \(shock.direction.symbol)")
                                    .font(.caption2)
                                    .foregroundColor(InstitutionalTheme.Colors.warning)
                            }
                        }
                    }
                    
                    Text("Değerlendirme: \(demeter.grade)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(
                            demeter.totalScore > 60 ? InstitutionalTheme.Colors.positive :
                            (demeter.totalScore > 40 ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.negative)
                        )
                }
            } else {
                VStack(spacing: 8) {
                    Text("Sektör analizi yükleniyor...")
                        .italic().foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Demeter verisi için lütfen bekleyin veya seç modülünden yükletin.")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("Chiron Öğrenme Sistemi")
                        .font(.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                }
                
                // Regime from ArgusDecisions if available
                if let decision = viewModel.argusDecisions[symbol],
                   let chironResult = decision.chironResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Market Rejimi")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text(chironResult.regime.descriptor)
                                .font(.headline)
                                .bold()
                                .foregroundColor(
                                    chironResult.regime == .trend ? InstitutionalTheme.Colors.positive :
                                    (chironResult.regime == .riskOff ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.warning)
                                )
                        }
                        
                        Text(chironResult.explanationTitle)
                            .font(.caption)
                            .bold()
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        
                        Text(chironResult.explanationBody)
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                    }
                    .padding()
                    .background(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                
                // PULSE Weights (Short-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(SanctumTheme.hologramBlue)
                        Text("PULSE Ağırlıkları (Kısa Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    if let weights = chironPulseWeights {
                        chironWeightProgressRows(weights: weights)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .padding()
                .background(SanctumTheme.hologramBlue.opacity(0.1))
                .cornerRadius(12)
                
                // CORSE Weights (Long-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tortoise.fill")
                            .foregroundColor(SanctumTheme.hologramBlue)
                        Text("CORSE Ağırlıkları (Uzun Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    if let weights = chironCorseWeights {
                        chironWeightProgressRows(weights: weights)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .padding()
                .background(InstitutionalTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                )
                .cornerRadius(12)
                
                // Learning tips
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(SanctumTheme.titanGold)
                        Text("Nasıl Öğreniyor?")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    Text("Chiron, geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik olarak ayarlar. Başarılı modüllerin ağırlığı artar.")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding()
                .background(InstitutionalTheme.Colors.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                )
                .cornerRadius(8)
                
                // CHRONOS LAB Button (Navigation)
                Button {
                    router.navigate(to: .chronosLab)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.title3)
                            .foregroundColor(SanctumTheme.hologramBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chronos Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Text("Walk-Forward Validation & Backtest")
                                .font(.caption2)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    .padding()
                    .background(InstitutionalTheme.Colors.surface2)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SanctumTheme.hologramBlue.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // ARGUS LAB Button (Navigation)
                Button {
                    router.navigate(to: .argusLab)
                } label: {
                    HStack {
                        Image(systemName: "flask.fill")
                            .font(.title3)
                            .foregroundColor(SanctumTheme.hologramBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Argus Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Text("İşlem Geçmişi & Öğrenmeler")
                                .font(.caption2)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    .padding()
                    .background(SanctumTheme.hologramBlue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SanctumTheme.hologramBlue.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
        case .prometheus:
            PrometheusPanelView(symbol: symbol, candles: vm.candles)

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
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if isPercentage {
                    Text(String(format: "%.1f%%", v * 100))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                } else {
                    Text(String(format: "%.2f", v))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
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
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            score / max > 0.6 ? InstitutionalTheme.Colors.positive :
                            (score / max > 0.4 ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.negative)
                        )
                        .frame(width: geometry.size.width * CGFloat(min(score / max, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(score))/\(Int(max))")
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func componentProgressRow(_ label: String, score: Double, max: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.borderSubtle)
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
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func chironWeightProgressRows(weights: ChironModuleWeights) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            chironWeightRow("Orion", weight: weights.orion, color: SanctumTheme.orionColor)
            chironWeightRow("Atlas", weight: weights.atlas, color: SanctumTheme.atlasColor)
            chironWeightRow("Phoenix", weight: weights.phoenix, color: InstitutionalTheme.Colors.negative)
            chironWeightRow("Aether", weight: weights.aether, color: SanctumTheme.aetherColor)
            chironWeightRow("Hermes", weight: weights.hermes, color: SanctumTheme.hermesColor)
            chironWeightRow("Demeter", weight: weights.demeter, color: SanctumTheme.demeterColor)
            chironWeightRow("Athena", weight: weights.athena, color: SanctumTheme.athenaColor)
        }
    }
    
    @ViewBuilder
    func chironWeightRow(_ label: String, weight: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 55, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(weight, 1.0)), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(weight * 100))%")
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}
