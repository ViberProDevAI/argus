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
    @State private var pulseAnimation = false
    @State private var rotateOrbit = false
    @State private var showDecision = false
    @State private var showDrawer = false // NEW: Contextual Drawer State
    
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
    
    private var isBistSymbol: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    private var activeDecision: ArgusGrandDecision? {
        vm.grandDecision ?? viewModel.grandDecisions[symbol]
    }

    @State private var showTradeSheet = false
    @State private var tradeAction: TradeAction = .buy
    @State private var hasAppliedLaunchOverride = false
    
    enum TradeAction { case buy, sell }

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
                    VStack(spacing: 0) {
                        headerView
                        footerHelper // Pantheon modülleri - Header altında (küçük toplar)
                        Spacer().frame(height: 40)
                        centerCoreArea
                        if showDecision,
                           let decision = activeDecision,
                           selectedModule == nil,
                           selectedBistModule == nil {
                            SanctumContributionCard(
                                decision: decision,
                                isBist: isBistSymbol
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        Spacer(minLength: 8)
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
        .sheet(isPresented: $showTradeSheet) {
            SanctumTradeSheet(
                symbol: symbol,
                viewModel: viewModel,
                action: tradeAction
            )
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
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "EKRANLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "OrionIcon") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "AlkindusIcon") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAlkindusDashboard"), object: nil)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portfoy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "HISSE ISLEMLERI",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Alim Islemi", subtitle: "Pozisyon ac", icon: "arrow.up.circle") {
                        tradeAction = .buy
                        showTradeSheet = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Satis Islemi", subtitle: "Pozisyon kapat", icon: "arrow.down.circle") {
                        tradeAction = .sell
                        showTradeSheet = true
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Analiz Raporu", subtitle: "Detayli rapor", icon: "doc.text.magnifyingglass") {
                        router.navigate(to: .analystReport(symbol: symbol))
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "MODULLER",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Orion", subtitle: "Teknik momentum", icon: "OrionIcon") {
                        selectedModule = .orion
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Atlas", subtitle: "Temel analiz", icon: "AtlasIcon") {
                        selectedModule = .atlas
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Hermes", subtitle: "Haber etkisi", icon: "HermesIcon") {
                        selectedModule = .hermes
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Chiron", subtitle: "Ogrenme ve agirliklar", icon: "ChironIcon") {
                        selectedModule = .chiron
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Aether", subtitle: "Makro rejim", icon: "AetherIcon") {
                        selectedModule = .aether
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Prometheus", subtitle: "Bilimsel fiyat projeksiyonu", icon: "crystal.ball") {
                        selectedModule = .prometheus
                        showDrawer = false
                    }
                ]
            )
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
                ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sagligi", icon: "OrionIcon") {
                    openSheet(.systemHealth)
                },
                ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                    openSheet(.feedback)
                }
            ]
        )
    }

    // MARK: - Subviews (Computed Properties)
    
    // 1. BACK BUTTON
    private var backButtonOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                SanctumCommandButton(
                    title: "GERI",
                    icon: "chevron.left",
                    tint: InstitutionalTheme.Colors.textPrimary,
                    isPrimary: true,
                    action: handleBackAction
                )

                Spacer(minLength: 0)

                SanctumCommandButton(
                    title: "MENU",
                    icon: "line.3.horizontal",
                    tint: InstitutionalTheme.Colors.textSecondary,
                    isPrimary: false,
                    action: { showDrawer = true }
                )

                SanctumCommandButton(
                    title: "RAPOR",
                    icon: "sparkles.rectangle.stack",
                    tint: Theme.accent,
                    isPrimary: false,
                    action: { router.navigate(to: .analystReport(symbol: symbol)) }
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface1.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
            .padding(.top, 52)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
    
    // 2. HEADER
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .tracking(2)
                .shadow(color: SanctumTheme.hologramBlue.opacity(0.5), radius: 10)
            
            if let quote = vm.quote {
                VStack(spacing: 6) {
                    Text(String(format: "%.2f", quote.currentPrice))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor((quote.percentChange ?? 0) >= 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                    
                    // NEW: SIGNAL CAPSULE (Restored Feature)
                    Button(action: { router.navigate(to: .symbolDebate(symbol: symbol)) }) {
                        SanctumSignalCapsule(
                            signal: vm.grandDecision,
                            dataHealth: .healthy
                        )
                    }
                }
            }
        }

        .padding(.top, 110) // Increased to clear top bar buttons
    }
    
    // 3. CENTER CORE
    private var centerCoreArea: some View {
        ZStack {
            // The Dial
            CenterCoreView(symbol: symbol, decision: activeDecision, showDecision: $showDecision)
            
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
                                self.showDecision = false
                            }
                        }
                }
            } else {
                // GLOBAL MODULES ORBIT (Classic Argus)
                let globalModules: [ModuleType] = [.orion, .atlas, .aether, .hermes, .prometheus]
                ForEach(0..<globalModules.count, id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(globalModules.count)) - 90
                    let mod = globalModules[i]
                    
                    OrbView(module: mod, viewModel: viewModel, symbol: symbol)
                        .offset(x: cos(angle * .pi / 180) * orbitRadius, y: sin(angle * .pi / 180) * orbitRadius)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedModule = mod
                                self.showDecision = false
                            }
                        }
                }
            }
        }
        .frame(height: 260) // Daha kompakt - yukarıda konumlanır
    }
    
    // ALKINDUS SHEET CONTENT
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
                    .font(.system(size: 11, weight: .semibold))

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundColor(tint)
            .padding(.horizontal, isPrimary ? 12 : 10)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
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
    }
}

// MARK: - COMPONENTS

// OrbView ve BistOrbView -> Views/Sanctum/SanctumOrbViews.swift

// CenterCoreView -> Views/Sanctum/SanctumCenterCore.swift

// MARK: - PANTHEON (THE OVERWATCH DECK)
// PantheonDeckView ve PantheonFlankView -> Views/Sanctum/SanctumPantheon.swift


// MARK: - BIST HOLO PANEL (ESKİ BORSACI VERSİYONU)

// MARK: - Hermes Helper View

