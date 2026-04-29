import SwiftUI

// MARK: - ARGUS SANCTUM VIEW
/// Ana hisse detay ekrani - Argus Konseyi gorunum.
/// Theme ve modul tipleri SanctumTypes.swift'te tanimli.
struct ArgusSanctumView: View {
    let symbol: String
    // LEAVING LEGACY VM BUT REMOVING OBSERVATION TO STOP RE-RENDERS
    let viewModel: TradingViewModel
    @StateObject private var vm: SanctumViewModel
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject var router: NavigationRouter

    init(symbol: String, viewModel: TradingViewModel) {
        self.symbol = symbol
        self.viewModel = viewModel
        self._vm = StateObject(wrappedValue: SanctumViewModel(symbol: symbol))
    }

    @Environment(\.dismiss) private var dismiss

    // State
    @State private var selectedModule: SanctumModuleType? = nil
    @State private var selectedBistModule: SanctumBistModuleType? = nil
    @State private var showDecision = false
    @State private var showDrawer = false // Contextual Drawer State

    // Legacy type alias for internal references
    typealias ModuleType = SanctumModuleType
    typealias BistModuleType = SanctumBistModuleType

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
    
    private var isBistSymbol: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    private var activeDecision: ArgusGrandDecision? {
        vm.grandDecision ?? viewModel.grandDecisions[symbol]
    }

    @State private var showTradeSheet = false
    @State private var tradeAction: TradeAction = .buy
    @State private var hasAppliedLaunchOverride = false
    @State private var showArgusAnalysis = false

    enum TradeAction { case buy, sell }

    /// MotorEngine → SanctumModuleType ters eşleşme (HoloPanel için).
    /// SanctumModuleType.motor zaten ileri yönde mevcut; biz tersini üretiyoruz.
    private func sanctumModule(from motor: MotorEngine) -> SanctumModuleType? {
        switch motor {
        case .atlas:      return .atlas
        case .orion:      return .orion
        case .aether:     return .aether
        case .hermes:     return .hermes
        case .athena:     return .athena
        case .demeter:    return .demeter
        case .chiron:     return .chiron
        case .prometheus: return .prometheus
        case .council:    return .council
        case .phoenix:    return .prometheus  // Phoenix = Tahmin altında Prometheus ile birleşik
        default:          return nil
        }
    }

    var body: some View {
        ZStack {
            // 1. Background
            InstitutionalTheme.Colors.background.ignoresSafeArea()
            SanctumTheme.bg.ignoresSafeArea()
            
            // 2. Main Content
            // 2. Main Content
            Group {
                if vm.isLoading && vm.quote == nil {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: InstitutionalTheme.Colors.textPrimary))
                        
                        LoadingQuoteView()
                    }
                } else {
                    // 2026-04-25 H-36 — Sticky top nav + content scrollview.
                    // Top nav: back chevron + sembol/meta + Argus app-icon
                    // butonu (analiz aç) + drawer (line.3.horizontal). Eski
                    // floating backButtonOverlay kaldırıldı.
                    VStack(spacing: 0) {
                        sanctumTopNav
                        ScrollView {
                            VStack(spacing: 16) {
                                SanctumHeader(symbol: symbol, quote: vm.quote)
                                SanctumCouncilBody(
                                    symbol: symbol,
                                    decision: activeDecision,
                                    prometheusForecast: viewModel.prometheusForecastBySymbol[symbol],
                                    onOpenArgusAnalysis: {
                                        showArgusAnalysis = true
                                    },
                                    onSelectMotor: { motor in
                                        if let mod = sanctumModule(from: motor) {
                                            withAnimation(.spring()) {
                                                self.selectedModule = mod
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .blur(radius: (selectedModule != nil || selectedBistModule != nil) ? 10 : 0)
            .scaleEffect((selectedModule != nil || selectedBistModule != nil) ? 0.95 : 1.0)
            .animation(.spring(), value: selectedModule)
            .animation(.spring(), value: selectedBistModule)
            
            // 4. HoloPanel (Module Details)
            if let module = selectedModule {
                HoloPanelView(
                    module: module,
                    viewModel: viewModel,
                    vm: vm,
                    symbol: symbol,
                    router: router,
                    onClose: { withAnimation { selectedModule = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // 5. BIST HoloPanel
            if let bistMod = selectedBistModule {
                // Legacy oracle entry is normalized to Rejim/Aether flow.
                let normalizedBistMod: BistModuleType = (bistMod == .oracle) ? .rejim : bistMod

                // Map BIST module to Global equivalent for HoloPanel
                let mappedModule: ModuleType = {
                    switch normalizedBistMod {
                    case .tahta: return .orion
                    case .kasa: return .atlas
                    case .kulis: return .hermes
                    case .rejim: return .aether
                    default: return .orion // Fallback for legacy types
                    }
                }()
                
                HoloPanelView(
                    module: mappedModule,
                    viewModel: viewModel,
                    vm: vm,
                    symbol: symbol,
                    router: router,
                    onClose: { withAnimation { selectedBistModule = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // 6. Sheets & Modals
            // Trade Action Panel (Flanking FAB - near tab bar)
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
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom))
                }
            }
            .zIndex(90)

            // FAB REMOVED

            
            // LOCAL CONTEXTUAL DRAWER
            if showDrawer {
                ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                    drawerSections(openSheet: openSheet)
                }
                .zIndex(200) // Highest Z-Index
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTradeSheet) {
            SanctumTradeSheet(
                symbol: symbol,
                viewModel: viewModel,
                action: tradeAction
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showArgusAnalysis) {
            ArgusAnalysisSheet(
                symbol: symbol,
                decision: activeDecision
            )
            .preferredColorScheme(.dark)
        }
        // Navigation via Router - Orphaned sheets removed, use router.navigate() instead
        .task {
            // Ensure data is loaded when view appears
            if vm.quote == nil || vm.grandDecision == nil {
                await vm.loadData()
            }
            if vm.grandDecision == nil {
                await vm.refresh()
            }
            await applyLaunchModuleOverrideIfNeeded()
        }
        .onAppear {
            // Re-apply after appearance in case parent navigation rebuilds the view.
            Task {
                await applyLaunchModuleOverrideIfNeeded()
            }
        }
    }
    
    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        // 1) ANA EKRANLAR — router üstünden proper destinasyonlara
        // "Ana Sayfa" = Alkindus Merkez; duplicate "Alkindus/NotificationCenter"
        // kalemi 2026-04-22 V5 sprintinde temizlendi.
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "EKRANLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Alkindus Merkez",
                                               subtitle: "Yapay zeka ana sayfa",
                                               icon: "AlkindusIcon") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar",
                                               subtitle: "Kokpit ekranı",
                                               icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portföy",
                                               subtitle: "Pozisyonlar",
                                               icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar",
                                               subtitle: "Tercihler",
                                               icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )

        // 2) MERKEZLER — global motor dashboard'ları (V5 views).
        // Buradaki linkler symbol-context değil; Chiron/Aether/Phoenix'in
        // ağırlıklı genel görünümlerine yönlendirir.
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "MERKEZLER",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Chiron Öğrenme",
                                               subtitle: "Ağırlıklar ve performans",
                                               icon: "ChironIcon") {
                        router.navigate(to: .chiron)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Aether Makro",
                                               subtitle: "3 katman rejim analizi",
                                               icon: "AetherIcon") {
                        router.navigate(to: .aetherDashboard)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Phoenix Anka",
                                               subtitle: "Geri dönüş adayları",
                                               icon: "flame.fill") {
                        router.navigate(to: .phoenix)
                        showDrawer = false
                    }
                ]
            )
        )
        
        // 3) HISSE İŞLEMLERI — mevcut sembole özgü aksiyonlar
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "HİSSE İŞLEMLERİ",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Alım İşlemi",
                                               subtitle: "Pozisyon aç",
                                               icon: "arrow.up.circle.fill") {
                        tradeAction = .buy
                        showTradeSheet = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Satış İşlemi",
                                               subtitle: "Pozisyon kapat",
                                               icon: "arrow.down.circle.fill") {
                        tradeAction = .sell
                        showTradeSheet = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Analist Raporu",
                                               subtitle: "\(symbol) detaylı rapor",
                                               icon: "AnalystIcon") {
                        router.navigate(to: .analystReport(symbol: symbol))
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Konsey Tartışması",
                                               subtitle: "Motor görüşleri",
                                               icon: "bubble.left.and.bubble.right.fill") {
                        router.navigate(to: .symbolDebate(symbol: symbol))
                        showDrawer = false
                    }
                ]
            )
        )

        // 4) MODÜLLER — symbol-context HoloPanel açılır.
        // Global (non-BIST) ek olarak Athena (Smart Beta) ve Demeter (Sektör).
        var moduleItems: [ArgusDrawerView.DrawerItem] = [
            ArgusDrawerView.DrawerItem(title: "Orion",
                                       subtitle: "Teknik momentum",
                                       icon: "OrionIcon") {
                selectedModule = .orion
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Atlas",
                                       subtitle: "Temel analiz",
                                       icon: "AtlasIcon") {
                selectedModule = .atlas
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Hermes",
                                       subtitle: "Haber etkisi",
                                       icon: "HermesIcon") {
                selectedModule = .hermes
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Chiron",
                                       subtitle: "Öğrenme · bu sembol",
                                       icon: "ChironIcon") {
                selectedModule = .chiron
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Aether",
                                       subtitle: "Makro rejim",
                                       icon: "AetherIcon") {
                selectedModule = .aether
                showDrawer = false
            },
            ArgusDrawerView.DrawerItem(title: "Prometheus",
                                       subtitle: "Fiyat projeksiyonu",
                                       icon: "PrometheusIcon") {
                selectedModule = .prometheus
                showDrawer = false
            }
        ]

        if !isBistSymbol {
            moduleItems.append(contentsOf: [
                ArgusDrawerView.DrawerItem(title: "Athena",
                                           subtitle: "Smart Beta faktörleri",
                                           icon: "AthenaIcon") {
                    selectedModule = .athena
                    showDrawer = false
                },
                ArgusDrawerView.DrawerItem(title: "Demeter",
                                           subtitle: "Sektör momentum",
                                           icon: "DemeterIcon") {
                    selectedModule = .demeter
                    showDrawer = false
                }
            ])
        }

        sections.append(
            ArgusDrawerView.DrawerSection(title: "MODÜLLER", items: moduleItems)
        )
        
        sections.append(commonToolsSection(openSheet: openSheet))
        
        return sections
    }
    
    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "ARACLAR",
            items: [
                ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                    openSheet(.calendar)
                },
                ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                    openSheet(.dictionary)
                },
                ArgusDrawerView.DrawerItem(title: "Unlu Finans Sozleri", subtitle: "Finans alintilari", icon: "quote.opening") {
                    openSheet(.financeWisdom)
                },
                ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sağlığı", icon: "waveform.path.ecg") {
                    openSheet(.systemHealth)
                },
                ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                    openSheet(.feedback)
                }
            ]
        )
    }

    // MARK: - Subviews (Computed Properties)

    // 2026-04-25 H-36 · Sticky top nav (P1 layout, kullanıcı onayı):
    //   sol: chevron.left + sembol + borsa altyazısı
    //   sağ: Argus app-icon (analiz aç) + line.3.horizontal (drawer)
    // Eski floating backButtonOverlay (chevron + AnalystIcon + ellipsis)
    // kaldırıldı; bunun yerine sticky bar nav-bar standardını izliyor.
    private var sanctumTopNav: some View {
        HStack(spacing: 8) {
            Button(action: handleBackAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")

            VStack(alignment: .leading, spacing: 0) {
                Text(symbol)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(exchangeMeta)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.leading, 2)

            Spacer()

            Button(action: { showArgusAnalysis = true }) {
                Image("ArgusAppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(InstitutionalTheme.Colors.holo.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Argus analizi")

            Button(action: { showDrawer = true }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menüyü aç")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.border)
                .frame(height: 0.5)
        }
    }

    /// "NASDAQ · Global" gibi alt başlık. BIST sembolleri için "BIST · Sirkiye".
    private var exchangeMeta: String {
        if symbol.uppercased().hasSuffix(".IS") {
            return "BIST · Sirkiye"
        }
        return "NASDAQ · Global"
    }
    
    // 2. HEADER → Views/Sanctum/SanctumHeader.swift
    // 3. CENTER CORE → Views/Sanctum/SanctumModuleGrid.swift
    //    (decision panel → Views/Sanctum/SanctumDecisionPanel.swift)

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

    private func handleBackAction() {
        if selectedModule != nil || selectedBistModule != nil || showDecision {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                selectedModule = nil
                selectedBistModule = nil
                showDecision = false
            }
            return
        }

        dismiss()
    }

    @MainActor
    private func applyLaunchModuleOverrideIfNeeded() async {
        guard !hasAppliedLaunchOverride else { return }

        // Small delay avoids race with initial deep-link navigation state propagation.
        try? await Task.sleep(nanoseconds: 350_000_000)

        let arguments = ProcessInfo.processInfo.arguments
        let isBistSymbol = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)

        let bistRaw: String? = {
            if let inline = arguments.first(where: { $0.hasPrefix("--argus-bist-module=") }) {
                return inline.replacingOccurrences(of: "--argus-bist-module=", with: "")
            }
            if let index = arguments.firstIndex(of: "--argus-bist-module"), arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            return nil
        }()

        if isBistSymbol, let bistRaw {
            let rawBist = bistRaw.uppercased()
            if let bistModule = SanctumBistModuleType(rawValue: rawBist) {
                let normalizedBistModule: BistModuleType = (bistModule == .oracle) ? .rejim : bistModule
                withAnimation(.spring()) {
                    selectedBistModule = normalizedBistModule
                }
                hasAppliedLaunchOverride = true
                return
            }
        }

        let globalRaw: String? = {
            if let inline = arguments.first(where: { $0.hasPrefix("--argus-module=") }) {
                return inline.replacingOccurrences(of: "--argus-module=", with: "")
            }
            if let index = arguments.firstIndex(of: "--argus-module"), arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            return nil
        }()

        guard let globalRaw else {
            return
        }

        let rawModule = globalRaw.uppercased()

        if isBistSymbol, let bistModule = SanctumBistModuleType(rawValue: rawModule) {
            let normalizedBistModule: BistModuleType = (bistModule == .oracle) ? .rejim : bistModule
            withAnimation(.spring()) {
                selectedBistModule = normalizedBistModule
            }
            hasAppliedLaunchOverride = true
            return
        }

        if let globalModule = SanctumModuleType(rawValue: rawModule) {
            withAnimation(.spring()) {
                selectedModule = globalModule
            }
            hasAppliedLaunchOverride = true
        }
    }
}

private struct SanctumCommandButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.caption2).weight(.semibold))

                Text(title)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .tracking(0.5)
            }
            .foregroundColor(tint)
            .padding(.horizontal, isPrimary ? 12 : 10)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2.opacity(isPrimary ? 0.95 : 0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(isPrimary ? tint.opacity(0.30) : InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - COMPONENTS

// OrbView ve BistOrbView -> Views/Sanctum/SanctumOrbViews.swift

// CenterCoreView -> Views/Sanctum/SanctumCenterCore.swift

// MARK: - PANTHEON (THE OVERWATCH DECK)
// PantheonDeckView ve PantheonFlankView -> Views/Sanctum/SanctumPantheon.swift


// MARK: - BIST HOLO PANEL (ESKİ BORSACI VERSİYONU)

// MARK: - Hermes Helper View

