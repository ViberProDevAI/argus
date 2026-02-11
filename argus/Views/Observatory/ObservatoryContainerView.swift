import SwiftUI

// MARK: - Observatory Container View
/// Main container view for Observatory with tab-based navigation
// MARK: - Observatory Container View
/// Main container view for Observatory with tab-based navigation
struct ObservatoryContainerView: View {
    @State private var selectedTab: ObservatoryTab = .timeline
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // 1. Background
            SanctumTheme.bg.edgesIgnoringSafeArea(.all)
            NeuralNetworkBackground().edgesIgnoringSafeArea(.all).opacity(0.3)
            
            VStack(spacing: 0) {
                // 2. Header
                observatoryHeader
                
                // 3. Custom Tab Bar
                cyberTabBar
                
                // 4. Content Area
                ZStack {
                    switch selectedTab {
                    case .timeline:
                        ObservatoryTimelineContentView()
                    case .learning:
                        ObservatoryLearningContentView()
                    case .trades:
                        TradeHistoryView()
                    case .health:
                        ObservatoryHealthContentView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Components
    
    private var observatoryHeader: some View {
        HStack {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 18))
                .foregroundColor(SanctumTheme.titanGold)
            
            Text("GÖZLEMEVİ")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(SanctumTheme.ghostGrey)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(SanctumTheme.glassMaterial)
    }
    
    private var cyberTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ObservatoryTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.title)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(selectedTab == tab ? SanctumTheme.hologramBlue : SanctumTheme.ghostGrey)
                        .padding(.vertical, 12)
                        
                        // Active Indicator Line
                        Rectangle()
                            .fill(selectedTab == tab ? SanctumTheme.hologramBlue : Color.clear)
                            .frame(height: 2)
                            .shadow(color: SanctumTheme.hologramBlue, radius: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedTab == tab ? 
                        SanctumTheme.hologramBlue.opacity(0.05) : 
                        Color.clear
                    )
                }
            }
        }
        .padding(.horizontal)
        .background(
            Rectangle()
                .fill(SanctumTheme.glassMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
        )
    }
}

enum ObservatoryTab: String, CaseIterable {
    case timeline
    case learning
    case trades
    case health
    
    var title: String {
        switch self {
        case .timeline: return "ZAMANÇİZ"
        case .learning: return "ÖĞRENME"
        case .trades: return "TRADE"
        case .health: return "SAĞLIK"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "clock.arrow.circlepath"
        case .learning: return "brain.head.profile"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .health: return "waveform.path.ecg"
        }
    }
}

// MARK: - Timeline Content (Embedded)
struct ObservatoryTimelineContentView: View {
    @State private var decisions: [DecisionCard] = []
    @State private var isLoading = true
    @State private var selectedFilter: TimelineFilter = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter
            Picker("Filtre", selection: $selectedFilter) {
                ForEach(TimelineFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if isLoading {
                Spacer()
                ProgressView("Yükleniyor...")
                Spacer()
            } else if decisions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("Henüz karar yok")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDecisions) { decision in
                            DecisionCardView(decision: decision)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear { loadDecisions() }
    }
    
    private var filteredDecisions: [DecisionCard] {
        switch selectedFilter {
        case .all: return decisions
        case .pending: return decisions.filter { $0.outcome == .pending }
        case .matured: return decisions.filter { $0.outcome == .matured }
        case .bist: return decisions.filter { $0.market == "BIST" }
        case .global: return decisions.filter { $0.market == "US" }
        }
    }
    
    private func loadDecisions() {
        isLoading = true
        Task {
            let events = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            await MainActor.run {
                self.decisions = events
                self.isLoading = false
            }
        }
    }
}

// MARK: - Learning Content (Embedded)
struct ObservatoryLearningContentView: View {
    @State private var events: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        if isLoading {
            Spacer()
            ProgressView("Yükleniyor...")
            Spacer()
        } else if events.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                Text("Henüz öğrenme kaydı yok")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(events) { event in
                        LearningEventCardView(event: event)
                    }
                }
                .padding()
            }
        }
    }
    
    init() {
        // Load on init
    }
}

// MARK: - Health Content (Embedded)
struct ObservatoryHealthContentView: View {
    @State private var metrics: PerformanceMetrics = .empty
    @State private var distribution: PredictionDistribution = .empty
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCardView(
                        title: "Sharpe",
                        value: String(format: "%.2f", metrics.sharpe),
                        icon: "chart.xyaxis.line",
                        color: metrics.sharpe > 1 ? .green : (metrics.sharpe > 0.5 ? .yellow : .red)
                    )
                    MetricCardView(
                        title: "İsabet",
                        value: String(format: "%.0f%%", metrics.hitRate * 100),
                        icon: "target",
                        color: metrics.hitRate > 0.55 ? .green : .yellow
                    )
                    MetricCardView(
                        title: "Kâr Faktörü",
                        value: String(format: "%.2f", metrics.profitFactor),
                        icon: "dollarsign.circle",
                        color: metrics.profitFactor > 1.5 ? .green : .yellow
                    )
                    MetricCardView(
                        title: "Maks DD",
                        value: String(format: "%.1f%%", metrics.maxDrawdown),
                        icon: "arrow.down.right",
                        color: metrics.maxDrawdown < 10 ? .green : .red
                    )
                }
                
                // Distribution Bar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Çıktı Dağılımı")
                        .font(.headline)
                    
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.green)
                            .frame(width: CGFloat(distribution.buyPercent) * 2, height: 20)
                        Rectangle().fill(Color.gray)
                            .frame(width: CGFloat(distribution.holdPercent) * 2, height: 20)
                        Rectangle().fill(Color.red)
                            .frame(width: CGFloat(distribution.sellPercent) * 2, height: 20)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if distribution.isDrifting {
                        Label("Drift tespit edildi: \(distribution.driftReason)", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
            .padding()
        }
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            let decisions = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            let matured = decisions.filter { $0.outcome == .matured }
            let wins = matured.filter { ($0.actualPnl ?? 0) > 0 }
            let hitRate = matured.isEmpty ? 0.5 : Double(wins.count) / Double(matured.count)
            
            let buyCount = decisions.filter { $0.action.contains("BİRİKTİR") || $0.action.contains("HÜCUM") }.count
            let sellCount = decisions.filter { $0.action.contains("AZALT") || $0.action.contains("ÇIK") }.count
            let holdCount = decisions.count - buyCount - sellCount
            let total = max(1, Double(decisions.count))
            
            await MainActor.run {
                self.metrics = PerformanceMetrics(sharpe: 0.8, hitRate: hitRate, profitFactor: 1.2, maxDrawdown: 8.5)
                self.distribution = PredictionDistribution(
                    buyPercent: Double(buyCount) / total * 100,
                    holdPercent: Double(holdCount) / total * 100,
                    sellPercent: Double(sellCount) / total * 100,
                    isDrifting: false,
                    driftReason: ""
                )
                self.isLoading = false
            }
        }
    }
}

// MARK: - Decision Card View
struct DecisionCardView: View {
    let decision: DecisionCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(decision.symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(decision.action)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(decision.actionColor.opacity(0.2))
                    .foregroundColor(decision.actionColor)
                    .cornerRadius(4)
            }
            
            // Factor bilgilerini göster
            if !decision.topFactors.isEmpty {
                HStack(spacing: 6) {
                    ForEach(decision.topFactors.prefix(3), id: \.name) { factor in
                        Text("\(factor.name): \(Int(factor.value))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(factor.value >= 50 ? .green : .red)
                    }
                }
            }
            
            HStack {
                Label(decision.market, systemImage: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(SanctumTheme.ghostGrey)
                
                Spacer()
                
                if let pnl = decision.actualPnl {
                    Text(String(format: "%.2f%%", pnl))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(pnl >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SanctumTheme.hologramBlue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Learning Event Card View
struct LearningEventCardView: View {
    let event: LearningEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(SanctumTheme.hologramBlue)
                
                Text("ÖĞRENME")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(event.timestamp, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(SanctumTheme.ghostGrey)
            }
            
            Text(event.reason)
                .font(.system(size: 12))
                .foregroundColor(SanctumTheme.ghostGrey)
                .lineLimit(3)
            
            // Weight değişimlerini göster
            Text(event.summaryText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(SanctumTheme.hologramBlue)
        }
        .padding()
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SanctumTheme.hologramBlue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Metric Card View
struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(SanctumTheme.ghostGrey)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ObservatoryContainerView()
}
