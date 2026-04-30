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
                // 2026-04-30 H-42 sade üst nav: close + sentence case başlık + opsiyonel aksiyonlar
                topNav

                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Sade alt başlık — modülün ne yaptığını tek cümleyle anlatır.
                        Text(module.description)
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // DYNAMIC CONTENT BASED ON MODULE
                        contentForModule(module)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
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
            .onAppear {
                // Phase 6 PR-C.2: AutoPilot pause-on-focus.
                MarketDataStore.shared.setUserFocus(symbol)
            }
            .onDisappear {
                MarketDataStore.shared.clearUserFocus()
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

    // MARK: - Top nav (2026-04-30 H-42 sade)
    //
    // V5 mor chip + 36×36 tinted square ikon barı + caps borsacı başlık (KASA /
    // TAHTA / SİRKİYE / KULİS / KISMET) komple gitti. Yerine sade nav: solda
    // close, ortada tek-kelime sentence case modül adı, sağda opsiyonel grafik
    // genişlet ve bilgi ikonları.

    /// Modülün MotorEngine karşılığı (yoksa nil → council/diğer).
    private var motorEngine: MotorEngine? {
        switch module {
        case .orion:      return .orion
        case .atlas:      return .atlas
        case .aether:     return .aether
        case .hermes:     return .hermes
        case .athena:     return .athena
        case .demeter:    return .demeter
        case .chiron:     return .chiron
        case .prometheus: return .prometheus
        case .council:    return .council
        }
    }

    /// Sentence case modül adı (header için). Tek kelime, işlev karşılığı.
    private var moduleTitle: String {
        switch module {
        case .atlas:      return "Bilanço"
        case .orion:      return "Teknik"
        case .aether:     return "Makro"
        case .hermes:     return "Haber"
        case .athena:     return "Faktörler"
        case .demeter:    return "Sektör"
        case .chiron:     return "Rejim"
        case .prometheus: return "Tahmin"
        case .council:    return "Konsey"
        }
    }

    /// Sade üst nav — close + başlık + bilgi/grafik ikonları.
    private var topNav: some View {
        let showChartExpand = !vm.candles.isEmpty &&
            (module == .orion || module == .atlas || module == .aether)

        return HStack(spacing: 8) {
            navIcon(system: "xmark", action: onClose)

            Text(moduleTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Spacer()

            if showChartExpand {
                navIcon(system: "arrow.up.left.and.arrow.down.right") {
                    showImmersiveChart = true
                }
            }

            navIcon(system: "info.circle") {
                withAnimation { showInfoCard = true }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.background)
    }

    /// Sade nav ikonu — sadece sembol, çerçeve/dolgu yok.
    private func navIcon(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                // ENTRY SETUP — conviction sonrası "hangi fiyat / ne zaman" layer'ı.
                // Orion evet dediyse burası sipariş defterini kurar; dediyse değilse bekleme sebebini anlatır.
                if let setup = vm.entrySetup {
                    EntrySetupCard(setup: setup, currentPrice: vm.quote?.currentPrice)
                }

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
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.7)
                            Text("Teknik analiz yükleniyor…")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        OrionMotherboardErrorView(
                            symbol: symbol,
                            failure: vm.orionFailure,
                            onRetry: {
                                Task {
                                    await OrionStore.shared.ensureAnalysis(for: symbol, forceRefresh: true)
                                }
                            }
                        )
                    }
                }

                // Sade strateji merkezi link satırı
                Button(action: { showStrategySheet = true }) {
                    HStack(spacing: 10) {
                        Text("Strateji merkezi")
                            .font(.system(size: 14))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text("Scalp · Swing · Position")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(InstitutionalTheme.Colors.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // NEW: Prometheus - 5 Day Forecast (Moved to Bottom)
                if !vm.candles.isEmpty, vm.candles.count >= 120, vm.orionAnalysis == nil {
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
                // 2026-04-30 H-42 — sade Aether (global sembol)
                VStack(alignment: .leading, spacing: 16) {
                    // 1) Konsey duruşu — pill kalktı, sayı body'de
                    if let grandDecision = viewModel.grandDecisions[symbol] {
                        let aetherDecision = grandDecision.aetherDecision
                        let stanceLabel: String = {
                            switch aetherDecision.stance {
                            case .riskOn:  return "risk-on"
                            case .riskOff: return "risk-off"
                            default:       return "nötr"
                            }
                        }()
                        let stanceColor: Color = {
                            switch aetherDecision.stance {
                            case .riskOn:  return InstitutionalTheme.Colors.aurora
                            case .riskOff: return InstitutionalTheme.Colors.crimson
                            default:       return InstitutionalTheme.Colors.textSecondary
                            }
                        }()
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Konsey duruşu")
                            Text("Piyasa duruşu — \(stanceLabel)")
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Piyasa modu")
                                        .font(.system(size: 11))
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(aetherDecision.marketMode.rawValue.capitalized)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Net destek")
                                        .font(.system(size: 11))
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(String(format: "%+.2f", aetherDecision.netSupport))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(stanceColor)
                                        .monospacedDigit()
                                }
                            }
                            ArgusBar(value: max(0, min(1, (aetherDecision.netSupport + 1) / 2)),
                                     color: stanceColor,
                                     height: 4)
                        }
                    } else {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.7)
                            Text("Konsey toplanıyor…")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                    }

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    // 2) Makro dashboard
                    if let macro = viewModel.macroRating {
                        AetherDashboardCard(rating: macro, isCompact: true)
                    } else {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.7)
                            Text("Makro veriler yükleniyor…")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                    }

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    // 3) Oracle lens
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Oracle")
                        OracleChamberEmbeddedView()
                            .frame(height: 320)
                    }

                    // 4) Global makro merkezi link satırı
                    Button {
                        router.navigate(to: .aetherDashboard)
                        onClose()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Makro merkezine git")
                                .font(.system(size: 14))
                                .foregroundColor(InstitutionalTheme.Colors.holo)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.holo.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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

                    // Sade haberleri tara butonu
                    Button(action: { Task { await vm.analyzeOnDemand() } }) {
                        HStack(spacing: 10) {
                            if vm.isLoadingNews {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            Text(vm.isLoadingNews ? "Analiz ediliyor…" : "Haberleri tara")
                                .font(.system(size: 14))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(InstitutionalTheme.Colors.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingNews)

                    Text("Eğitim amaçlıdır, yatırım tavsiyesi değildir.")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .padding(.top, 2)
                }
            } else {
                // 2026-04-30 H-42 — sade Hermes (global)
                VStack(alignment: .leading, spacing: 16) {
                    // 1) Duygu nabzı (child view, kendi stilinde)
                    SentimentPulseCard(symbol: symbol)

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    // 2) Konsey duruşu — pill kalktı, üstte muted satır
                    if let grandDecision = viewModel.grandDecisions[symbol],
                       let hermesDecision = grandDecision.hermesDecision {
                        let toneColor: Color = hermesDecision.isHighImpact
                            ? (hermesDecision.netSupport >= 0
                               ? InstitutionalTheme.Colors.aurora
                               : InstitutionalTheme.Colors.crimson)
                            : InstitutionalTheme.Colors.textSecondary
                        let impactLabel = hermesDecision.isHighImpact ? "yüksek etki" : "normal"

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Konsey duruşu")
                            Text("Etki — \(impactLabel)")
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Duygu")
                                        .font(.system(size: 11))
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(hermesDecision.sentiment.displayTitle)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Net destek")
                                        .font(.system(size: 11))
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(String(format: "%+.2f", hermesDecision.netSupport))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(toneColor)
                                        .monospacedDigit()
                                }
                            }
                            ArgusBar(value: max(0, min(1, (hermesDecision.netSupport + 1) / 2)),
                                     color: toneColor, height: 4)
                        }

                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5)
                    }

                    // 3) Haberleri tara butonu — sade outline
                    Button(action: { Task { await vm.analyzeOnDemand() } }) {
                        HStack(spacing: 10) {
                            if vm.isLoadingNews {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            Text(vm.isLoadingNews ? "Analiz ediliyor…" : "Haberleri tara")
                                .font(.system(size: 14))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(InstitutionalTheme.Colors.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingNews)

                    // 4) Hata satırı
                    if let error = vm.newsErrorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.crimson)
                            .lineLimit(3)
                    }

                    // 5) İçerik (insights / events / boş hal)
                    if !vm.newsInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Haber analizi", trailing: "\(vm.newsInsights.count) kayıt")
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(vm.newsInsights.prefix(5).enumerated()), id: \.offset) { idx, insight in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(insight.headline)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                            .lineLimit(2)
                                        Text(insight.impactSentenceTR)
                                            .font(.system(size: 12))
                                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 10)
                                    if idx < min(vm.newsInsights.count, 5) - 1 {
                                        Rectangle()
                                            .fill(InstitutionalTheme.Colors.borderSubtle)
                                            .frame(height: 0.5)
                                    }
                                }
                            }
                        }
                    } else if !vm.hermesEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Haber analizi")
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
                        Text("Henüz haber analizi yok.")
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            
        case .athena:
            // 2026-04-30 H-42 — sade Athena (faktör skoru)
            if let athena = viewModel.athenaResults[symbol] {
                let scoreColor: Color = athena.factorScore > 50
                    ? InstitutionalTheme.Colors.aurora
                    : InstitutionalTheme.Colors.crimson

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Toplam puan — \(Int(athena.factorScore))/100")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(athena.styleLabel)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(athena.factorScore))")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(scoreColor)
                                .monospacedDigit()
                        }
                        ArgusBar(value: max(0, min(1, athena.factorScore / 100.0)),
                                 color: scoreColor,
                                 height: 4)
                    }

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Faktör kırılımı")
                        VStack(spacing: 8) {
                            v5FactorRow("Momentum", value: athena.momentumFactorScore,
                                        color: InstitutionalTheme.Colors.Motors.prometheus)
                            v5FactorRow("Değer", value: athena.valueFactorScore,
                                        color: InstitutionalTheme.Colors.holo)
                            v5FactorRow("Kalite", value: athena.qualityFactorScore,
                                        color: InstitutionalTheme.Colors.aurora)
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7)
                    Text("Faktör analizi yükleniyor…")
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
        case .demeter:
            // 2026-04-30 H-42 — sade Demeter (sektör)
            let demeterScore = viewModel.demeterScores.first(where: { $0.sector == .XLK }) ?? viewModel.demeterScores.first

            if let demeter = demeterScore {
                let scoreColor = v5ScoreColor(demeter.totalScore)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Toplam puan — \(Int(demeter.totalScore))/100 · \(demeter.grade)")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(demeter.sector.name)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(demeter.totalScore))")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(scoreColor)
                                .monospacedDigit()
                        }
                        ArgusBar(value: max(0, min(1, demeter.totalScore / 100.0)),
                                 color: scoreColor,
                                 height: 4)
                    }

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Bileşen kırılımı")
                        VStack(spacing: 8) {
                            v5FactorRow("Momentum", value: demeter.momentumScore,
                                        color: InstitutionalTheme.Colors.Motors.prometheus)
                            v5FactorRow("Şok etkisi", value: demeter.shockImpactScore,
                                        color: InstitutionalTheme.Colors.crimson)
                            v5FactorRow("Rejim", value: demeter.regimeScore,
                                        color: InstitutionalTheme.Colors.Motors.aether)
                            v5FactorRow("Genişlik", value: demeter.breadthScore,
                                        color: InstitutionalTheme.Colors.aurora)
                        }
                    }

                    if !demeter.activeShocks.isEmpty {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Aktif şoklar",
                                         trailing: "\(demeter.activeShocks.count) uyarı")
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(demeter.activeShocks) { shock in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(InstitutionalTheme.Colors.crimson)
                                            .frame(width: 5, height: 5)
                                        Text("\(shock.type.displayName) \(shock.direction.symbol)")
                                            .font(.system(size: 13))
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7)
                    Text("Sektör analizi yükleniyor…")
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
        case .chiron:
            // 2026-04-30 H-42 — sade Chiron (rejim + ağırlıklar).
            // Mor pill + caps başlıklar gitti; rejim adı muted üst satırda,
            // ağırlık tabloları sentence case + sade hairline ayrımla geliyor.
            VStack(alignment: .leading, spacing: 18) {
                // 1) Sembol rejimi
                if let decision = viewModel.argusDecisions[symbol],
                   let chironResult = decision.chironResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Şu anki rejim — \(chironResult.regime.descriptor.lowercased())")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text(chironResult.explanationTitle)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(chironResult.explanationBody)
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)
                }

                // 2) Pulse ağırlıkları
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Kısa vade ağırlıkları", trailing: "Pulse")
                    if let weights = chironPulseWeights {
                        chironWeightProgressRows(weights: weights)
                        Text(weights.reasoning)
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor.")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }

                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)

                // 3) Corse ağırlıkları
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Uzun vade ağırlıkları", trailing: "Corse")
                    if let weights = chironCorseWeights {
                        chironWeightProgressRows(weights: weights)
                        Text(weights.reasoning)
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor.")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }

                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)

                // 4) Nasıl öğreniyor
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nasıl öğreniyor?")
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik ayarlar. Başarılı modüllerin payı zamanla artar.")
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 5) Rejim merkezi kısayolu
                Button {
                    router.navigate(to: .chiron)
                    onClose()
                } label: {
                    HStack(spacing: 8) {
                        Text("Rejim merkezine git")
                            .font(.system(size: 14))
                            .foregroundColor(InstitutionalTheme.Colors.holo)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.holo.opacity(0.6))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 8) {
            chironWeightRow("Teknik",  engine: .orion,   weight: weights.orion)
            chironWeightRow("Bilanço", engine: .atlas,   weight: weights.atlas)
            chironWeightRow("Risk",    engine: nil,      weight: weights.phoenix,
                            color: InstitutionalTheme.Colors.crimson)
            chironWeightRow("Makro",   engine: .aether,  weight: weights.aether)
            chironWeightRow("Haber",   engine: .hermes,  weight: weights.hermes)
            chironWeightRow("Sektör",  engine: .demeter, weight: weights.demeter)
            // Athena kullanıcı UI'da gizli; ağırlığı diğer motorlarla
            // birlikte sayılır ama satır çizilmez. (2026-04-25 H-39)
        }
    }

    /// Sade Chiron ağırlık satırı — sentence case label + bar + sade yüzde.
    /// Bar rengi motor rengini taşımaya devam eder ki ağırlık dağılımı
    /// görsel olarak okunabilir kalsın.
    @ViewBuilder
    func chironWeightRow(_ label: String,
                         engine: MotorEngine?,
                         weight: Double,
                         color overrideColor: Color? = nil) -> some View {
        let barColor: Color = overrideColor
            ?? engine.map { InstitutionalTheme.Colors.Motors.color(for: $0) }
            ?? InstitutionalTheme.Colors.holo

        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 70, alignment: .leading)

            ArgusBar(value: min(1.0, weight), color: barColor, height: 4)

            Text("\(Int(weight * 100))%")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Sade primitives (2026-04-30 H-42)
    //
    // v5CardShell motor-tint border'ı + ArgusChipTone parametresi gitti.
    // Sade kart: surface1 + 0.5px borderSubtle hairline + radius 12.
    // borderTone parametresi backward-compat için alındı, görmezden gelinir.

    @ViewBuilder
    private func v5CardShell<Content: View>(borderTone: ArgusChipTone = .neutral,
                                            @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Sade faktör satırı — sentence case label + bar + sade puan.
    /// Bar rengi sayısal vurgu için motor rengini kullanmaya devam eder.
    private func v5FactorRow(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 96, alignment: .leading)
            ArgusBar(value: max(0, min(1, value / 100.0)), color: color, height: 4)
            Text("\(Int(value))")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    /// Sade bölüm başlığı — sentence case body, mono caps yerine kullanılır.
    @ViewBuilder
    private func sectionTitle(_ text: String, trailing: String? = nil) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
    }

    private func v5ScoreColor(_ value: Double) -> Color {
        if value >= 60 { return InstitutionalTheme.Colors.aurora }
        if value >= 40 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func v5ScoreTone(_ value: Double) -> ArgusChipTone {
        if value >= 60 { return .aurora }
        if value >= 40 { return .titan }
        return .crimson
    }

    /// Chiron regime → V5 tone (trend=aurora, riskOff=crimson, chop=titan vb.)
    private func chironRegimeTone(_ regime: MarketRegime) -> ArgusChipTone {
        switch regime {
        case .trend:   return .aurora
        case .riskOff: return .crimson
        default:       return .titan
        }
    }
}
