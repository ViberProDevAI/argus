import SwiftUI

struct ChironDetailView: View {
    // State
    @ObservedObject var engine = ChironRegimeEngine.shared // NEW: Reactive Engine Source
    @State private var selectedEngine: AutoPilotEngine = .corse
    @State private var corseWeights: ChironModuleWeights?
    @State private var pulseWeights: ChironModuleWeights?
    @State private var learningEvents: [ChironLearningEvent] = []
    // @State private var regimeResult removed - using engine.lastResult directly
    
    @State private var isAnalyzing = false
    @State private var selectedTab = 0 // 0: Weights, 1: Performance
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header & Tab Switcher
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.tint)
                        VStack(alignment: .leading) {
                            Text("Chiron 3.0")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            Text("Öğrenen Trading Sistemi")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Tab Switcher
                    HStack(spacing: 0) {
                        Button(action: { withAnimation { selectedTab = 0 }}) {
                            VStack(spacing: 6) {
                                Text("Analiz & Öğrenme")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(selectedTab == 0 ? .white : .gray)
                                Rectangle()
                                    .fill(selectedTab == 0 ? Theme.tint : Color.clear)
                                    .frame(height: 3)
                            }
                        }
                        
                        Button(action: { withAnimation { selectedTab = 1 }}) {
                            VStack(spacing: 6) {
                                Text("Performans Karnesi")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(selectedTab == 1 ? .white : .gray)
                                Rectangle()
                                    .fill(selectedTab == 1 ? Theme.tint : Color.clear)
                                    .frame(height: 3)
                            }
                        }
                    }
                    .background(Theme.secondaryBackground)
                }
                .background(Theme.background)
                
                // MARK: - Content
                if selectedTab == 0 {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // MARK: - NEW: Regime Card (Reactive)
                            RegimeCard(result: engine.lastResult)
                                .padding(.horizontal)
                            
                            // MARK: - Engine Selector
                            HStack(spacing: 0) {
                                EngineTab(title: "CORSE 🐢", isSelected: selectedEngine == .corse) {
                                    withAnimation { selectedEngine = .corse }
                                }
                                EngineTab(title: "PULSE ⚡", isSelected: selectedEngine == .pulse) {
                                    withAnimation { selectedEngine = .pulse }
                                }
                            }
                            .background(Theme.secondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // MARK: - Active Weights Display
                            if let weights = selectedEngine == .corse ? corseWeights : pulseWeights {
                                WeightsCard(engine: selectedEngine, weights: weights)
                            } else {
                                VStack(spacing: 8) {
                                    Text("Varsayılan Ağırlıklar Aktif")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    Text("Henüz bu engine için öğrenilmiş ağırlık yok. Varsayılan değerler kullanılıyor.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    let defaults = selectedEngine == .corse ? ChironModuleWeights.defaultCorse : ChironModuleWeights.defaultPulse
                                    WeightsCard(engine: selectedEngine, weights: defaults)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // MARK: - Learning Timeline
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.green)
                                    Text("Öğrenme Geçmişi")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: triggerAnalysis) {
                                        if isAnalyzing {
                                            ProgressView().scaleEffect(0.8)
                                        } else {
                                            Label("Analiz Tetikle", systemImage: "arrow.clockwise")
                                                .font(.caption)
                                        }
                                    }
                                    .disabled(isAnalyzing)
                                    .foregroundColor(.green)
                                }
                                
                                if learningEvents.isEmpty {
                                    Text("Henüz öğrenme kaydı bulunmuyor.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ForEach(learningEvents.prefix(10)) { event in
                                        LearningEventRow(event: event)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(12)
                            
                            // MARK: - Forward Test Dashboard (NEW)
                            ArgusScientificDashboardCard()
                            
                            // MARK: - Performans Özeti (Chiron 3.0)
                            ChironPerformanceSummaryCard()
                            
                            // MARK: - Pişmanlık Köşesi (Chiron 3.0)
                            ChironRegretCornerCard()
                            
                            Spacer()
                        }
                        .padding()
                    }
                } else {
                    // Performance View
                    ScrollView {
                        ChironPerformanceView()
                            .padding()
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        corseWeights = await ChironWeightStore.shared.getWeights(symbol: "DEFAULT", engine: .corse)
        pulseWeights = await ChironWeightStore.shared.getWeights(symbol: "DEFAULT", engine: .pulse)
        learningEvents = await ChironDataLakeService.shared.loadLearningEvents()
        // regimeResult load removed - using reactive engine.lastResult
    }
    
    private func triggerAnalysis() {
        isAnalyzing = true
        Task {
            await ChironLearningJob.shared.runFullAnalysis()
            await loadData()
            isAnalyzing = false
        }
    }
}

// MARK: - Components
struct EngineTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Rectangle()
                    .fill(isSelected ? (title.contains("CORSE") ? Color.blue : Color.purple) : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

struct WeightsCard: View {
    let engine: AutoPilotEngine
    let weights: ChironModuleWeights
    
    var engineColor: Color {
        engine == .corse ? .blue : .purple
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(engine == .corse ? "CORSE Ağırlıkları 🐢" : "PULSE Ağırlıkları ⚡")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("Güven: %\(Int(weights.confidence * 100))")
                    .font(.caption)
                    .foregroundColor(weights.confidence > 0.7 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(weights.confidence > 0.7 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 10) {
                WeightBar(label: "Orion", value: weights.orion, color: .cyan, description: "Trend")
                WeightBar(label: "Atlas", value: weights.atlas, color: .blue, description: "Fund.")
                WeightBar(label: "Phoenix", value: weights.phoenix, color: .red, description: "Price")
                WeightBar(label: "Aether", value: weights.aether, color: .orange, description: "Macro")
                WeightBar(label: "Hermes", value: weights.hermes, color: .purple, description: "News")
            }
            
            Text("Son güncelleme: \(weights.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(engineColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(engineColor.opacity(0.3), lineWidth: 1))
    }
}

struct WeightBar: View {
    let label: String
    let value: Double
    let color: Color
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundColor(.white)
                Text(description).font(.caption2).foregroundColor(.gray)
            }
            .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(min(1.0, value)))
                }
            }
            .frame(height: 8)
            
            Text("%\(Int(value * 100))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct LearningEventRow: View {
    let event: ChironLearningEvent
    
    var eventIcon: String {
        switch event.eventType {
        case .weightUpdate: return "slider.horizontal.3"
        case .ruleAdded: return "plus.circle"
        case .ruleRemoved: return "minus.circle"
        case .analysisCompleted: return "checkmark.circle"
        case .anomalyDetected: return "exclamationmark.triangle"
        case .forwardTest: return "arrow.triangle.2.circlepath"
        }
    }
    
    var eventColor: Color {
        switch event.eventType {
        case .weightUpdate: return .blue
        case .ruleAdded: return .green
        case .ruleRemoved: return .red
        case .analysisCompleted: return .cyan
        case .anomalyDetected: return .orange
        case .forwardTest: return .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: eventIcon)
                .foregroundColor(eventColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let symbol = event.symbol {
                        Text(symbol).font(.caption).bold().foregroundColor(.white)
                    }
                    Spacer()
                    Text(event.date, style: .relative).font(.caption2).foregroundColor(.gray)
                }
                Text(event.description).font(.caption).foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(8)
        .background(eventColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Chiron 3.0 UI Components

/// Performans özeti kartı
struct ChironPerformanceSummaryCard: View {
    @State private var totalTrades: Int = 0
    @State private var globalWinRate: Double = 0
    @State private var topSymbols: [(symbol: String, winRate: Double)] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.cyan)
                Text("Performans Özeti")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Yükleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if totalTrades == 0 {
                Text("Henüz yeterli veri yok. Trade yapıldıkça burası dolacak.")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                HStack(spacing: 20) {
                    VStack {
                        Text("\(totalTrades)")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Text("Toplam Trade")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("%\(Int(globalWinRate))")
                            .font(.title2)
                            .bold()
                            .foregroundColor(globalWinRate >= 50 ? .green : .red)
                        Text("Kazanç Oranı")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                if !topSymbols.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("En İyi Semboller")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    ForEach(topSymbols.prefix(3), id: \.symbol) { item in
                        HStack {
                            Text(item.symbol)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            Text("%\(Int(item.winRate))")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(12)
        .task {
            await loadPerformanceData()
        }
    }
    
    private func loadPerformanceData() async {
        isLoading = true
        
        let allTrades = await ChironDataLakeService.shared.loadAllTradeHistory()
        totalTrades = allTrades.count
        
        if totalTrades > 0 {
            let wins = allTrades.filter { $0.pnlPercent > 0 }.count
            globalWinRate = Double(wins) / Double(totalTrades) * 100
            
            // Sembol bazlı win rate hesapla
            var symbolStats: [String: (wins: Int, total: Int)] = [:]
            for trade in allTrades {
                let current = symbolStats[trade.symbol] ?? (0, 0)
                symbolStats[trade.symbol] = (
                    wins: current.wins + (trade.pnlPercent > 0 ? 1 : 0),
                    total: current.total + 1
                )
            }
            
            // En az 3 trade'i olan sembolleri sırala
            topSymbols = symbolStats
                .filter { $0.value.total >= 3 }
                .map { (symbol: $0.key, winRate: Double($0.value.wins) / Double($0.value.total) * 100) }
                .sorted { $0.winRate > $1.winRate }
        }
        
        isLoading = false
    }
}

/// Pişmanlık köşesi kartı
struct ChironRegretCornerCard: View {
    @State private var regretSummary: ChironRegretEngine.RegretSummary?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Pişmanlık Köşesi")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Yükleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if let summary = regretSummary {
                if summary.totalPreventableLossCount == 0 && summary.totalMissedOpportunityCount == 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Henüz pişmanlık kaydı yok! Modülleri iyi dinliyorsunuz.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(summary.totalPreventableLossCount)")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.red)
                            Text("Önlenebilir Kayıp")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("\(summary.totalMissedOpportunityCount)")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.orange)
                            Text("Kaçırılan Fırsat")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let mostIgnored = summary.mostIgnoredModule {
                        Divider().background(Color.gray.opacity(0.3))
                        
                        HStack {
                            Text("En çok görmezden gelinen modül:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(mostIgnored.capitalized)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !summary.lessons.isEmpty {
                        Divider().background(Color.gray.opacity(0.3))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Öğrenilen Dersler")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        ForEach(summary.lessons.prefix(3), id: \.self) { lesson in
                            Text(lesson)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .task {
            await loadRegretData()
        }
    }
    
    private func loadRegretData() async {
        isLoading = true
        regretSummary = await ChironRegretEngine.shared.generateSummary()
        isLoading = false
    }
}

// MARK: - Regime Card (New)
struct RegimeCard: View {
    let result: ChironResult
    
    var regimeColor: Color {
        switch result.regime {
        case .trend: return .green
        case .riskOff: return .red
        case .chop: return .orange
        case .newsShock: return .purple
        case .neutral: return .blue
        }
    }
    
    var regimeIcon: String {
        switch result.regime {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .riskOff: return "shield.fill"
        case .chop: return "waveform.path.ecg"
        case .newsShock: return "bolt.fill"
        case .neutral: return "scale.3d"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: regimeIcon)
                    .font(.title2)
                    .foregroundColor(regimeColor)
                
                Text(result.explanationTitle.uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(result.regime.rawValue.uppercased())
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(regimeColor.opacity(0.2))
                    .foregroundColor(regimeColor)
                    .cornerRadius(6)
            }
            
            Text(result.explanationBody)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            if let notes = result.learningNotes, !notes.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(notes, id: \.self) { note in
                            Text(note)
                                .font(.caption2)
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding()
        .background(regimeColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(regimeColor.opacity(0.3), lineWidth: 1)
        )
    }
}
