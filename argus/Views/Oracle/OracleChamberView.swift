import SwiftUI
import Combine

// MARK: - Oracle Odası (The Oracle Chamber)
/// Piyasanın Kahini - Makro ekonomik verilerin hisse/sektör üzerindeki etkisini gösteren holografik arayüz

struct OracleChamberView: View {
    @StateObject private var viewModel = OracleChamberViewModel()
    @State private var showSimulator = false
    
    var body: some View {
        ZStack {
            // Background
            OracleBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Merkezi Hologram
                    economyCoreView
                    
                    // Sektör Grid
                    sectorGridView
                    
                    // Zincir Reaksiyon Feed
                    chainReactionFeed
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            
            // Simülasyon Modu (Alt Panel)
            VStack {
                Spacer()
                if showSimulator {
                    simulatorPanel
                        .transition(.move(edge: .bottom))
                }
                simulatorToggleButton
            }
        }
        .navigationTitle("ORACLE ODASI")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSignals()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("PİYASANIN KAHİNİ")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text("Makro Veri → Sektör Etkisi")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Merkezi Hologram (Economy Core)
    
    private var economyCoreView: some View {
        ZStack {
            // Outer Ring Animation
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan.opacity(0.3), .purple.opacity(0.5), .cyan.opacity(0.3)],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: viewModel.rotationAngle)
            
            // Inner Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [viewModel.coreColor.opacity(0.8), viewModel.coreColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .overlay(
                    // Pulse Effect
                    Circle()
                        .stroke(viewModel.coreColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(viewModel.pulseScale)
                        .opacity(2 - viewModel.pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: false), value: viewModel.pulseScale)
                )
            
            // Center Content
            VStack(spacing: 4) {
                Text(viewModel.economyStatus.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(viewModel.economyScore)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(viewModel.coreColor)
                
                Text("EKONOMİ SKORU")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            viewModel.startAnimations()
        }
    }
    
    // MARK: - Sektör Grid
    
    private var sectorGridView: some View {
        VStack(spacing: 12) {
            Text("SEKTÖR ETKİLERİ")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.sectorNodes) { node in
                    SectorNodeView(node: node)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Zincir Reaksiyon Feed
    
    private var chainReactionFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("ZİNCİR REAKSİYON")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            if viewModel.chainReactions.isEmpty {
                Text("Henüz aktif sinyal yok")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.chainReactions) { reaction in
                    ChainReactionCard(reaction: reaction)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    // MARK: - Simülasyon Paneli
    
    private var simulatorPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text("SİMÜLASYON MODU")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Button(action: { withAnimation { showSimulator = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // Dolar/TL Slider
            SimulatorSlider(
                title: "DOLAR/TL",
                value: $viewModel.simDollarTry,
                range: 25...50,
                unit: "₺"
            )
            
            // Faiz Slider
            SimulatorSlider(
                title: "FAİZ",
                value: $viewModel.simInterestRate,
                range: 20...60,
                unit: "%"
            )
            
            // Enflasyon Slider
            SimulatorSlider(
                title: "ENFLASYON",
                value: $viewModel.simInflation,
                range: 20...80,
                unit: "%"
            )
            
            // Hesapla Butonu
            Button(action: {
                Task { await viewModel.runSimulation() }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("ETKİYİ HESAPLA")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding()
    }
    
    private var simulatorToggleButton: some View {
        Button(action: { withAnimation(.spring()) { showSimulator.toggle() } }) {
            HStack {
                Image(systemName: showSimulator ? "chevron.down" : "slider.horizontal.3")
                Text(showSimulator ? "KAPAT" : "SİMÜLASYON")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.cyan)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
            )
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Supporting Views

struct OracleBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.02, blue: 0.15),
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct SectorNodeView: View {
    let node: SectorNode
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Hexagon-like shape
                Circle()
                    .fill(node.impactColor.opacity(DesignTokens.Opacity.glassCard))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(node.impactColor.opacity(0.5), lineWidth: 1)
                    )
                
                Image(systemName: node.icon)
                    .font(.system(size: 18))
                    .foregroundColor(node.impactColor)
            }
            
            Text(node.name)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(node.impactText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(node.impactColor)
        }
    }
}

struct ChainReactionCard: View {
    let reaction: ChainReaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Stock Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(reaction.symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(reaction.sectorName)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Impact
            VStack(alignment: .trailing, spacing: 2) {
                Text(reaction.impactText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(reaction.impact > 0 ? .green : .red)
                Text(reaction.reason)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Mini Chart Placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(reaction.impact > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 40, height: 24)
                .overlay(
                    // Simple trend line
                    Path { path in
                        path.move(to: CGPoint(x: 4, y: reaction.impact > 0 ? 18 : 6))
                        path.addLine(to: CGPoint(x: 20, y: 12))
                        path.addLine(to: CGPoint(x: 36, y: reaction.impact > 0 ? 6 : 18))
                    }
                    .stroke(reaction.impact > 0 ? Color.green : Color.red, lineWidth: 2)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }
}

struct SimulatorSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(String(format: "%.1f", value))\(unit)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Slider(value: $value, in: range)
                .tint(.cyan)
        }
    }
}

// MARK: - Data Models

struct SectorNode: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let impact: Double
    
    var impactColor: Color {
        if impact > 0 { return .green }
        if impact < 0 { return .red }
        return .gray
    }
    
    var impactText: String {
        if impact > 0 { return "+\(Int(impact))" }
        if impact < 0 { return "\(Int(impact))" }
        return "0"
    }
}

struct ChainReaction: Identifiable {
    let id = UUID()
    let symbol: String
    let sectorName: String
    let impact: Double
    let reason: String
    
    var impactText: String {
        if impact > 0 { return "+\(String(format: "%.1f", impact))%" }
        return "\(String(format: "%.1f", impact))%"
    }
}

enum EconomyStatus: String {
    case stable = "İSTİKRARLI"
    case growing = "BÜYÜME"
    case overheating = "AŞIRI ISINMA"
    case recession = "DARALMA"
    case stagflation = "STAGFLASYON"
}

// MARK: - ViewModel

@MainActor
class OracleChamberViewModel: ObservableObject {
    @Published var sectorNodes: [SectorNode] = []
    @Published var chainReactions: [ChainReaction] = []
    @Published var economyStatus: EconomyStatus = .stable
    @Published var economyScore: String = "72"
    @Published var coreColor: Color = .cyan
    
    // Animation State
    @Published var rotationAngle: Double = 0
    @Published var pulseScale: Double = 1.0
    
    // Simulation Values
    @Published var simDollarTry: Double = 32.5
    @Published var simInterestRate: Double = 38.0
    @Published var simInflation: Double = 45.0
    
    func startAnimations() {
        rotationAngle = 360
        pulseScale = 1.5
    }
    
    func loadSignals() async {
        // Oracle Engine'den sinyalleri al - GERÇEK VERİ
        let input = await TCMBDataService.shared.getOracleInput()
        let signals = await OracleEngine.shared.analyze(input: input)
        
        // Sektör Node'larını oluştur
        sectorNodes = [
            SectorNode(name: "KONUT", icon: "house.fill", impact: signals.first(where: { $0.type == .housingBoom })?.effects.first?.scoreImpact ?? 0),
            SectorNode(name: "TÜKETİM", icon: "creditcard.fill", impact: signals.first(where: { $0.type == .retailPulse })?.effects.first?.scoreImpact ?? 0),
            SectorNode(name: "SANAYİ", icon: "gearshape.2.fill", impact: signals.first(where: { $0.type == .industryGear })?.effects.first?.scoreImpact ?? 0),
            SectorNode(name: "TURİZM", icon: "airplane.departure", impact: signals.first(where: { $0.type == .tourismRush })?.effects.first?.scoreImpact ?? 0),
            SectorNode(name: "OTOMOTİV", icon: "car.fill", impact: signals.first(where: { $0.type == .autoVelocity })?.effects.first?.scoreImpact ?? 0),
            SectorNode(name: "BANKALAR", icon: "building.columns.fill", impact: 12), // Mock
            SectorNode(name: "SAVUNMA", icon: "shield.checkered", impact: 8), // Mock
            SectorNode(name: "SERMAYE", icon: "chart.line.uptrend.xyaxis", impact: -5) // Mock
        ]
        
        // Zincir Reaksiyonları oluştur
        chainReactions = []
        for signal in signals {
            for effect in signal.effects {
                for stock in effect.impactedStocks.prefix(2) {
                    chainReactions.append(ChainReaction(
                        symbol: stock,
                        sectorName: effect.sectorCode,
                        impact: effect.scoreImpact,
                        reason: String(signal.message.prefix(50))
                    ))
                }
            }
        }
        
        // Ekonomi durumunu belirle
        updateEconomyStatus()
    }
    
    func runSimulation() async {
        // Simülasyon parametreleriyle yeniden hesapla
        // Önce gerçek verileri al, sonra simülasyon parametrelerini uygula
        let baseInput = await TCMBDataService.shared.getOracleInput()

        // Simülasyon: Kullanıcının girdiği değerlere göre etkileri hesapla
        // Faiz ve dolar değişimi sektörleri farklı etkiler
        let simInput = OracleDataInput(
            inflationYoY: simInflation,
            housingSalesTotal: baseInput.housingSalesTotal,
            housingSalesChangeYoY: simInterestRate > 40 ? baseInput.housingSalesChangeYoY * 0.5 : baseInput.housingSalesChangeYoY,
            housingSalesChangeMoM: baseInput.housingSalesChangeMoM,
            creditCardSpendingTotal: baseInput.creditCardSpendingTotal,
            creditCardSpendingChangeYoY: simInflation + 15, // Enflasyon + nominal artış
            capacityUsageRatio: simDollarTry > 40 ? baseInput.capacityUsageRatio - 4 : baseInput.capacityUsageRatio,
            prevCapacityUsageRatio: baseInput.prevCapacityUsageRatio,
            touristArrivalsTotal: baseInput.touristArrivalsTotal,
            touristArrivalsChangeYoY: simDollarTry > 40 ? baseInput.touristArrivalsChangeYoY * 1.5 : baseInput.touristArrivalsChangeYoY,
            autoSalesTotal: baseInput.autoSalesTotal,
            autoSalesChangeYoY: simInterestRate > 45 ? -15 : baseInput.autoSalesChangeYoY
        )
        
        let signals = await OracleEngine.shared.analyze(input: simInput)
        
        // UI güncelle
        await MainActor.run {
            // Sektör etkilerini güncelle
            for (index, node) in sectorNodes.enumerated() {
                if let matchingSignal = signals.first(where: { signalMatchesSector($0, node.name) }) {
                    sectorNodes[index] = SectorNode(
                        name: node.name,
                        icon: node.icon,
                        impact: matchingSignal.effects.first?.scoreImpact ?? 0
                    )
                }
            }
            
            // Zincir reaksiyonları güncelle
            chainReactions = []
            for signal in signals {
                for effect in signal.effects {
                    for stock in effect.impactedStocks.prefix(2) {
                        chainReactions.append(ChainReaction(
                            symbol: stock,
                            sectorName: effect.sectorCode,
                            impact: effect.scoreImpact,
                            reason: String(signal.message.prefix(50))
                        ))
                    }
                }
            }
            
            updateEconomyStatus()
        }
    }
    
    private func signalMatchesSector(_ signal: OracleEngine.OracleSignal, _ sectorName: String) -> Bool {
        switch signal.type {
        case .housingBoom: return sectorName == "KONUT"
        case .retailPulse: return sectorName == "TÜKETİM"
        case .industryGear: return sectorName == "SANAYİ"
        case .tourismRush: return sectorName == "TURİZM"
        case .autoVelocity: return sectorName == "OTOMOTİV"
        default: return false
        }
    }
    
    private func updateEconomyStatus() {
        // Basit durum hesaplama
        if simInflation > 60 && simInterestRate < 40 {
            economyStatus = .overheating
            coreColor = .red
            economyScore = "35"
        } else if simInflation > 50 {
            economyStatus = .stagflation
            coreColor = .purple
            economyScore = "45"
        } else if simInflation < 30 && simInterestRate < 30 {
            economyStatus = .growing
            coreColor = .green
            economyScore = "85"
        } else {
            economyStatus = .stable
            coreColor = .cyan
            economyScore = "72"
        }
    }
}

// MARK: - Embedded Version (BistHoloPanelView için)
/// Bu versiyon, scroll container içinde embed edildiğinde stabil çalışır
/// ViewModel singleton olarak tutularak state kaybolması önlenir
struct OracleChamberEmbeddedView: View {
    // Singleton ViewModel - state kaybolmasını önler
    @StateObject private var viewModel = OracleChamberViewModel.shared

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("PİYASANIN KAHİNİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)

                Text("Makro Veri → Sektör Etkisi")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Merkezi Ekonomi Skoru
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [viewModel.coreColor.opacity(0.6), viewModel.coreColor.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                VStack(spacing: 2) {
                    Text(viewModel.economyStatus.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(viewModel.economyScore)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(viewModel.coreColor)

                    Text("EKONOMİ SKORU")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            // Sektör Etkileri - Compact Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.sectorNodes) { node in
                    VStack(spacing: 4) {
                        Image(systemName: node.icon)
                            .font(.system(size: 16))
                            .foregroundColor(node.impactColor)

                        Text(node.name)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)

                        Text(node.impactText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(node.impactColor)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(node.impactColor.opacity(0.1))
                    )
                }
            }

            // Zincir Reaksiyonlar
            if !viewModel.chainReactions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("ZİNCİR REAKSİYON")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    ForEach(viewModel.chainReactions.prefix(4)) { reaction in
                        HStack {
                            Text(reaction.symbol)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            Text(reaction.impactText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(reaction.impact > 0 ? .green : .red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    }
                }
            } else {
                Text("Veri yükleniyor...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }

            // Veri Kaynağı Notu
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text("TCMB EVDS + TÜİK Verileri")
                    .font(.system(size: 9))
            }
            .foregroundColor(.gray.opacity(0.6))
        }
        .padding()
        .task {
            // Sadece veriler boşsa yükle
            if viewModel.sectorNodes.isEmpty {
                await viewModel.loadSignals()
            }
        }
    }
}

// ViewModel'ı singleton yapıyoruz
extension OracleChamberViewModel {
    static let shared = OracleChamberViewModel()
}

#Preview {
    NavigationStack {
        OracleChamberView()
    }
}
