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
                // V5 HoloPanel başlığı: motor logo + mono caps pill + aksiyonlar + close
                v5Header

                ArgusHair()

                // Holo Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // V5 açıklama satırı — italics yerine mono micro caps.
                        HStack(spacing: 8) {
                            ArgusDot(color: motorEngine.map {
                                InstitutionalTheme.Colors.Motors.color(for: $0)
                            } ?? module.color, size: 6)
                            Text(module.description)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // DYNAMIC CONTENT BASED ON MODULE
                        contentForModule(module)
                    }
                    .padding(16)
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

    // MARK: - V5 Header (Sprint V5.A — 2026-04-22)

    /// Modülün MotorEngine karşılığı (yoksa nil → SF ikon fallback).
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

    /// BIST sembolünde motor ismine eski borsacı jargonu uygulanır.
    private var v5Title: String {
        if symbol.uppercased().hasSuffix(".IS") {
            switch module {
            case .aether: return "SİRKİYE"
            case .orion:  return "TAHTA"
            case .atlas:  return "KASA"
            case .hermes: return "KULİS"
            case .chiron: return "KISMET"
            default:      return module.rawValue.uppercased()
            }
        }
        return module.rawValue.uppercased()
    }

    /// V5 HoloPanel başlık barı — motor logo + mono caps başlık + aksiyon chip'ler + close.
    private var v5Header: some View {
        let motorColor = motorEngine.map {
            InstitutionalTheme.Colors.Motors.color(for: $0)
        } ?? module.color
        let showChartExpand = !vm.candles.isEmpty &&
            (module == .orion || module == .atlas || module == .aether)

        return HStack(spacing: 10) {
            // Motor chip (logo + caps başlık)
            HStack(spacing: 8) {
                if let engine = motorEngine {
                    MotorLogo(engine, size: 20)
                } else {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(motorColor)
                }
                Text(v5Title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(motorColor.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(motorColor.opacity(0.35), lineWidth: 1)
            )

            // Info
            v5IconButton(system: "info.circle", tint: motorColor) {
                withAnimation { showInfoCard = true }
            }

            // Expand chart (sadece teknik/makro/temel modüllerde)
            if showChartExpand {
                v5IconButton(system: "arrow.up.left.and.arrow.down.right", tint: motorColor) {
                    showImmersiveChart = true
                }
            }

            Spacer()

            // Close
            v5IconButton(system: "xmark", tint: InstitutionalTheme.Colors.textSecondary) {
                onClose()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
    }

    /// V5 ikon butonu — 36×36 rounded square (V5 drawer/cockpit ile aynı dil).
    private func v5IconButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(InstitutionalTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
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
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(SanctumTheme.orionColor)
                            Text("Orion analizi yükleniyor...")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
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
                // V5.A-2 — Aether Global Sembol bağlamı
                VStack(alignment: .leading, spacing: 14) {
                    // 1) Aether Konsey Duruşu
                    if let grandDecision = viewModel.grandDecisions[symbol] {
                        let aetherDecision = grandDecision.aetherDecision
                        let stanceTone: ArgusChipTone = {
                            switch aetherDecision.stance {
                            case .riskOn:  return .aurora
                            case .riskOff: return .crimson
                            default:       return .titan
                            }
                        }()
                        v5CardShell(borderTone: .motor(.aether)) {
                            HStack {
                                ArgusSectionCaption("AETHER KONSEY DURUŞU")
                                Spacer()
                                ArgusChip(aetherDecision.stance.rawValue.uppercased(),
                                          tone: stanceTone)
                            }
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PİYASA MODU")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(aetherDecision.marketMode.rawValue.capitalized)
                                        .font(InstitutionalTheme.Typography.bodyStrong)
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("NET DESTEK")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(String(format: "%+.2f", aetherDecision.netSupport))
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .foregroundColor(stanceTone.foreground)
                                }
                            }
                            ArgusBar(value: max(0, min(1, (aetherDecision.netSupport + 1) / 2)),
                                     color: stanceTone.foreground,
                                     height: 5)
                        }
                    } else {
                        v5CardShell(borderTone: .motor(.aether)) {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.7)
                                    .tint(InstitutionalTheme.Colors.Motors.aether)
                                Text("Aether konseyi toplanıyor…")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                        }
                    }

                    // 2) Aether Makro Dashboard (compact)
                    if let macro = viewModel.macroRating {
                        AetherDashboardCard(rating: macro, isCompact: true)
                    } else {
                        v5CardShell(borderTone: .holo) {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.7)
                                    .tint(InstitutionalTheme.Colors.holo)
                                Text("Makro veriler yükleniyor…")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                        }
                    }

                    // 3) Oracle Lens
                    v5CardShell(borderTone: .motor(.aether)) {
                        HStack {
                            ArgusSectionCaption("ORACLE LENS")
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                        }
                        OracleChamberEmbeddedView()
                            .frame(height: 320)
                    }

                    // 4) Global merkez kısayolu
                    Button {
                        router.navigate(to: .aetherDashboard)
                        onClose()
                    } label: {
                        HStack(spacing: 8) {
                            MotorLogo(.aether, size: 14)
                            Text("AETHER MAKRO MERKEZİNE GİT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundColor(InstitutionalTheme.Colors.Motors.aether)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(InstitutionalTheme.Colors.Motors.aether.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .fill(InstitutionalTheme.Colors.Motors.aether.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.35), lineWidth: 1)
                        )
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

                    // V5 Haberleri Tara butonu
                    Button(action: { Task { await vm.analyzeOnDemand() } }) {
                        HStack(spacing: 8) {
                            if vm.isLoadingNews {
                                ProgressView().scaleEffect(0.7)
                                    .tint(InstitutionalTheme.Colors.Motors.hermes)
                            } else {
                                MotorLogo(.hermes, size: 14)
                                    .tinted(InstitutionalTheme.Colors.Motors.hermes)
                            }
                            Text(vm.isLoadingNews ? "ANALİZ EDİLİYOR…" : "HABERLERİ TARA")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .fill(InstitutionalTheme.Colors.Motors.hermes.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingNews)

                    HStack(spacing: 6) {
                        ArgusDot(color: InstitutionalTheme.Colors.titan, size: 5)
                        Text("Eğitim amaçlıdır, yatırım tavsiyesi değildir.")
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                // V5.A-5 — Global Hermes
                VStack(alignment: .leading, spacing: 14) {
                    // 1) Duygu nabzı (child view, kendi stilinde)
                    SentimentPulseCard(symbol: symbol)

                    // 2) Hermes konsey duruşu
                    if let grandDecision = viewModel.grandDecisions[symbol],
                       let hermesDecision = grandDecision.hermesDecision {
                        let tone: ArgusChipTone = hermesDecision.isHighImpact
                            ? (hermesDecision.netSupport >= 0 ? .aurora : .crimson)
                            : .motor(.hermes)

                        v5CardShell(borderTone: .motor(.hermes)) {
                            HStack {
                                ArgusSectionCaption("HERMES DURUŞU")
                                Spacer()
                                ArgusChip(hermesDecision.isHighImpact ? "YÜKSEK ETKİ" : "NORMAL",
                                          tone: tone)
                            }
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DUYGU")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(hermesDecision.sentiment.displayTitle)
                                        .font(InstitutionalTheme.Typography.bodyStrong)
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("NET DESTEK")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                    Text(String(format: "%+.2f", hermesDecision.netSupport))
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .foregroundColor(tone.foreground)
                                }
                            }
                            ArgusBar(value: max(0, min(1, (hermesDecision.netSupport + 1) / 2)),
                                     color: tone.foreground, height: 5)
                        }
                    }

                    // 3) Haberleri Tara V5 butonu
                    Button(action: { Task { await vm.analyzeOnDemand() } }) {
                        HStack(spacing: 8) {
                            if vm.isLoadingNews {
                                ProgressView().scaleEffect(0.7)
                                    .tint(InstitutionalTheme.Colors.Motors.hermes)
                            } else {
                                MotorLogo(.hermes, size: 14)
                                    .tinted(InstitutionalTheme.Colors.Motors.hermes)
                            }
                            Text(vm.isLoadingNews ? "ANALİZ EDİLİYOR…" : "HABERLERİ TARA")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .fill(InstitutionalTheme.Colors.Motors.hermes.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingNews)

                    // 4) Hata satırı
                    if let error = vm.newsErrorMessage {
                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.crimson)
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(InstitutionalTheme.Colors.crimson)
                                .lineLimit(3)
                        }
                    }

                    // 5) İçerik (insights / events / boş hal)
                    if !vm.newsInsights.isEmpty {
                        v5CardShell(borderTone: .motor(.hermes)) {
                            HStack {
                                ArgusSectionCaption("HABER ANALİZİ")
                                Spacer()
                                ArgusChip("\(vm.newsInsights.count)", tone: .holo)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(vm.newsInsights.prefix(5))) { insight in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(insight.headline)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                            .lineLimit(2)
                                        Text(insight.impactSentenceTR)
                                            .font(.system(size: 11))
                                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 6)
                                    .overlay(ArgusHair(), alignment: .bottom)
                                }
                            }
                        }
                    } else if !vm.hermesEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ArgusSectionCaption("HERMES ANALİZLERİ")
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
                        v5CardShell(borderTone: .neutral) {
                            HStack(spacing: 10) {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 14))
                                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                Text("Henüz haber analizi yok")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            
        case .athena:
            // V5.A-6 — Smart Beta V5 kartı (bar listesi + toplam skor).
            if let athena = viewModel.athenaResults[symbol] {
                VStack(alignment: .leading, spacing: 14) {
                    v5CardShell(borderTone: .motor(.athena)) {
                        HStack {
                            ArgusSectionCaption("SMART BETA SKOR")
                            Spacer()
                            Text("\(Int(athena.factorScore))")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(athena.factorScore > 50
                                                 ? InstitutionalTheme.Colors.aurora
                                                 : InstitutionalTheme.Colors.crimson)
                        }
                        ArgusBar(value: max(0, min(1, athena.factorScore / 100.0)),
                                 color: InstitutionalTheme.Colors.Motors.athena,
                                 height: 6)
                        Text(athena.styleLabel)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    v5CardShell(borderTone: .motor(.athena)) {
                        ArgusSectionCaption("FAKTÖR KIRILIMI")
                        VStack(spacing: 8) {
                            v5FactorRow("MOMENTUM", value: athena.momentumFactorScore,
                                        color: InstitutionalTheme.Colors.Motors.prometheus)
                            v5FactorRow("VALUE", value: athena.valueFactorScore,
                                        color: InstitutionalTheme.Colors.holo)
                            v5FactorRow("QUALITY", value: athena.qualityFactorScore,
                                        color: InstitutionalTheme.Colors.aurora)
                        }
                    }
                }
            } else {
                v5CardShell(borderTone: .neutral) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                            .tint(InstitutionalTheme.Colors.Motors.athena)
                        Text("Athena analizi yükleniyor…")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            }
            
        case .demeter:
            // V5.A-7 — Demeter sektör kartı.
            let demeterScore = viewModel.demeterScores.first(where: { $0.sector == .XLK }) ?? viewModel.demeterScores.first

            if let demeter = demeterScore {
                VStack(alignment: .leading, spacing: 14) {
                    v5CardShell(borderTone: .motor(.demeter)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                ArgusSectionCaption("SEKTÖR PUANI")
                                Text(demeter.sector.name)
                                    .font(InstitutionalTheme.Typography.bodyStrong)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            }
                            Spacer()
                            Text("\(Int(demeter.totalScore))")
                                .font(.system(size: 30, weight: .black, design: .monospaced))
                                .foregroundColor(v5ScoreColor(demeter.totalScore))
                        }
                        ArgusBar(value: max(0, min(1, demeter.totalScore / 100.0)),
                                 color: v5ScoreColor(demeter.totalScore),
                                 height: 6)
                        HStack(spacing: 6) {
                            ArgusChip("DEĞERLENDİRME · \(demeter.grade.uppercased())",
                                      tone: v5ScoreTone(demeter.totalScore))
                        }
                    }

                    v5CardShell(borderTone: .motor(.demeter)) {
                        ArgusSectionCaption("BİLEŞEN KIRILIMI")
                        VStack(spacing: 8) {
                            v5FactorRow("MOMENTUM", value: demeter.momentumScore,
                                        color: InstitutionalTheme.Colors.Motors.prometheus)
                            v5FactorRow("ŞOK ETKİSİ", value: demeter.shockImpactScore,
                                        color: InstitutionalTheme.Colors.crimson)
                            v5FactorRow("REJİM", value: demeter.regimeScore,
                                        color: InstitutionalTheme.Colors.Motors.aether)
                            v5FactorRow("GENİŞLİK", value: demeter.breadthScore,
                                        color: InstitutionalTheme.Colors.aurora)
                        }
                    }

                    if !demeter.activeShocks.isEmpty {
                        v5CardShell(borderTone: .crimson) {
                            HStack {
                                ArgusSectionCaption("AKTİF ŞOKLAR")
                                Spacer()
                                ArgusChip("\(demeter.activeShocks.count) UYARI", tone: .crimson)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(demeter.activeShocks) { shock in
                                    HStack(spacing: 8) {
                                        ArgusDot(color: InstitutionalTheme.Colors.crimson)
                                        Text("\(shock.type.displayName) \(shock.direction.symbol)")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                v5CardShell(borderTone: .neutral) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                            .tint(InstitutionalTheme.Colors.Motors.demeter)
                        Text("Sektör analizi yükleniyor…")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
            }
            
        case .chiron:
            // V5.A-1 — Symbol-context Chiron panel (Sprint 2026-04-22).
            // ChironInsightsView (genel dashboard) ile aynı tasarım dilini
            // paylaşır; burası sembol-bazlı PULSE/CORSE ağırlıklarını gösterir.
            VStack(alignment: .leading, spacing: 14) {
                // 1) Sembol rejimi kartı
                if let decision = viewModel.argusDecisions[symbol],
                   let chironResult = decision.chironResult {
                    v5CardShell(borderTone: chironRegimeTone(chironResult.regime)) {
                        HStack {
                            ArgusSectionCaption("MARKET REJİMİ")
                            Spacer()
                            ArgusChip(chironResult.regime.descriptor.uppercased(),
                                      tone: chironRegimeTone(chironResult.regime))
                        }
                        Text(chironResult.explanationTitle)
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(chironResult.explanationBody)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // 2) PULSE ağırlıkları
                v5CardShell(borderTone: .holo) {
                    HStack {
                        ArgusSectionCaption("PULSE AĞIRLIKLARI · KISA VADE")
                        Spacer()
                        ArgusChip("HOLO", tone: .holo)
                    }
                    if let weights = chironPulseWeights {
                        chironWeightProgressRows(weights: weights)
                        Text(weights.reasoning)
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 4)
                    } else {
                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                            Text("Varsayılan ağırlıklar kullanılıyor…")
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                    }
                }

                // 3) CORSE ağırlıkları
                v5CardShell(borderTone: .motor(.chiron)) {
                    HStack {
                        ArgusSectionCaption("CORSE AĞIRLIKLARI · UZUN VADE")
                        Spacer()
                        ArgusChip("CHIRON", tone: .motor(.chiron), icon: .chiron)
                    }
                    if let weights = chironCorseWeights {
                        chironWeightProgressRows(weights: weights)
                        Text(weights.reasoning)
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 4)
                    } else {
                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                            Text("Varsayılan ağırlıklar kullanılıyor…")
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                    }
                }

                // 4) Öğrenme açıklaması
                v5CardShell(borderTone: .titan) {
                    HStack(spacing: 6) {
                        ArgusDot(color: InstitutionalTheme.Colors.titan)
                        Text("NASIL ÖĞRENİYOR?")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(InstitutionalTheme.Colors.titan)
                    }
                    Text("Chiron, geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik ayarlar. Başarılı modüllerin ağırlığı artar.")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 5) Global Chiron merkezi kısayolu
                Button {
                    router.navigate(to: .chiron)
                    onClose()
                } label: {
                    HStack(spacing: 8) {
                        MotorLogo(.chiron, size: 14)
                        Text("GLOBAL CHIRON MERKEZİNE GİT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.Motors.chiron)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.Motors.chiron.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .fill(InstitutionalTheme.Colors.Motors.chiron.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.Motors.chiron.opacity(0.35), lineWidth: 1)
                    )
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
            chironWeightRow("ORION",     engine: .orion,      weight: weights.orion)
            chironWeightRow("ATLAS",     engine: .atlas,      weight: weights.atlas)
            chironWeightRow("PHOENIX",   engine: nil,         weight: weights.phoenix,
                            color: InstitutionalTheme.Colors.crimson)
            chironWeightRow("AETHER",    engine: .aether,     weight: weights.aether)
            chironWeightRow("HERMES",    engine: .hermes,     weight: weights.hermes)
            chironWeightRow("DEMETER",   engine: .demeter,    weight: weights.demeter)
            chironWeightRow("ATHENA",    engine: .athena,     weight: weights.athena)
        }
    }

    /// V5 Chiron ağırlık satırı — motor logolu + ArgusBar + mono yüzde.
    @ViewBuilder
    func chironWeightRow(_ label: String,
                         engine: MotorEngine?,
                         weight: Double,
                         color overrideColor: Color? = nil) -> some View {
        let barColor: Color = overrideColor
            ?? engine.map { InstitutionalTheme.Colors.Motors.color(for: $0) }
            ?? InstitutionalTheme.Colors.holo

        HStack(spacing: 8) {
            if let engine {
                MotorLogo(engine, size: 14)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(barColor)
                    .frame(width: 14, height: 14)
            }

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 62, alignment: .leading)

            ArgusBar(value: min(1.0, weight), color: barColor, height: 5)

            Text("%\(Int(weight * 100))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: - V5 primitives (Sprint V5.A)

    /// V5 kartı — surface1 + motor-tint kenarlık.
    @ViewBuilder
    private func v5CardShell<Content: View>(borderTone: ArgusChipTone,
                                            @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(borderTone.foreground.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    /// V5 faktör satırı — label + ArgusBar + mono puan.
    private func v5FactorRow(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 96, alignment: .leading)
            ArgusBar(value: max(0, min(1, value / 100.0)), color: color, height: 5)
            Text("\(Int(value))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 32, alignment: .trailing)
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
