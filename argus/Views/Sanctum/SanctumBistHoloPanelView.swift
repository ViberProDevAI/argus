import SwiftUI
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
                    SanctumModuleIconView(bistModule: module, size: 28)
                        .foregroundColor(module.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.rawValue) // TR ISIM
                            .font(.headline)
                            .bold()
                            .tracking(2)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(module.description)
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    
                    Button(action: { withAnimation { showInfoCard = true } }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(module.color.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .padding(8)
                            .background(Circle().fill(InstitutionalTheme.Colors.surface3))
                            .overlay(
                                Circle()
                                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                            )
                    }
                }
                .padding()
                .background(module.color.opacity(0.14))
                
                Divider().background(module.color)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(module.color.opacity(0.9))
                                .padding(.top, 1)
                            Text(module.description)
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(InstitutionalTheme.Colors.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
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
                    case .oracle: return .aether
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
        
        // TCMB'den gerçek makro veriler
        let tcmbSnapshot = await TCMBDataService.shared.getMacroSnapshot()
        
        // BorsaPy'den canlı makro verileri paralel çek
        async let brentTask = { try? await BorsaPyProvider.shared.getBrentPrice() }()
        async let inflationTask = { try? await BorsaPyProvider.shared.getInflationData() }()
        async let policyRateTask = { try? await BorsaPyProvider.shared.getPolicyRate() }()
        async let xu100Task = { try? await BorsaPyProvider.shared.getXU100() }()
        async let goldTask = { try? await BorsaPyProvider.shared.getGoldPrice() }()

        let (bpBrent, bpInflation, bpPolicyRate, bpXu100, bpGold) = await (brentTask, inflationTask, policyRateTask, xu100Task, goldTask)

        var xu100Change: Double? = nil
        var xu100Value: Double? = nil
        if let xu = bpXu100 {
            xu100Value = xu.last
            if xu.open > 0 {
                xu100Change = ((xu.last - xu.open) / xu.open) * 100
            }
        }

        let macro = await MacroSnapshotService.shared.getSnapshot()
        let sirkiyeInput = SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: usdTryPrev,
            dxy: macro.dxy,
            brentOil: bpBrent?.last ?? tcmbSnapshot.brentOil ?? 80.0,
            globalVix: macro.vix ?? 15.0,
            newsSnapshot: nil,
            currentInflation: bpInflation?.yearlyInflation ?? tcmbSnapshot.inflation ?? 45.0,
            policyRate: bpPolicyRate ?? tcmbSnapshot.policyRate ?? 50.0,
            xu100Change: xu100Change,
            xu100Value: xu100Value,
            goldPrice: bpGold?.last ?? tcmbSnapshot.goldPrice
        )

        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candleList,
            snapshot: nil,
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
            // KASA MERKEZİ: Bilanço + Faktörler + Analist
            VStack(spacing: 24) {
                // 1. Temel Analiz (Atlas)
                let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
                BISTBilancoDetailView(sembol: bistSymbol)
                
                Divider().background(SanctumTheme.atlasColor.opacity(0.3))
                
                // 2. Faktör Analizi (Smart Beta)
                BistFaktorCard(symbol: symbol)
                
                Divider().background(SanctumTheme.atlasColor.opacity(0.3))
                
                // 3. Analist Konsensüs (borsapy)
                BistAnalystCard(symbol: symbol)
            }

        case .rejim:
            // REJİM MERKEZİ: Piyasa Rejimi + Makro Göstergeler + Teknik Konsensüs + Sektör
            RejimView(symbol: symbol)
            
        case .kulis:
            // KULİS MERKEZİ: Duygu Barometresi + Analist + KAP + Temettü
            VStack(spacing: 16) {
                // Section Header
                HStack(spacing: 10) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 14))
                        .foregroundColor(SanctumTheme.hermesColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KULİS MERKEZİ")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("Haber, Analist & Duygu Analizi")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                // 1. Piyasa Duygu Barometresi
                DuyguBarometresiCard(symbol: symbol)

                // 2. Analist Konsensüsü (eğitim notlu)
                AnalistEgitimWrapper(symbol: symbol)

                // 3. KAP Bildirimleri (eğitim notlu)
                KAPEgitimWrapper(symbol: symbol)

                // 4. Temettü & Sermaye (eğitim notlu)
                TemettuEgitimWrapper(symbol: symbol)

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

        case .oracle:
            // ORACLE: dedicated makro sinyal görünümü
            OracleChamberEmbeddedView()
                .frame(height: 360)

        // ESKİ MODÜLLER (Fallback)
        default:
             VStack {
                 Text("Modül taşındı.")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
             }
        }
    }
}
