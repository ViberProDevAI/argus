import SwiftUI

/// Chiron Öğrenme Dashboard
/// Bileşen performanslarını ve öğrenilmiş ağırlıkları gösterir.
struct ChironInsightsView: View {
    let symbol: String?
    
    @State private var globalStats: [ComponentPerformanceService.ComponentStats] = []
    @State private var symbolStats: [ComponentPerformanceService.ComponentStats] = []
    @State private var learnedWeights: OrionWeightSnapshot?
    @State private var learningStatus: (hasLearning: Bool, confidence: Double, note: String)?
    
    init(symbol: String? = nil) {
        self.symbol = symbol
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Learning Status
                if let status = learningStatus {
                    learningStatusCard(status)
                }
                
                // Learned Weights
                if let weights = learnedWeights {
                    learnedWeightsCard(weights)
                }
                
                // Component Performance
                if !symbolStats.isEmpty || !globalStats.isEmpty {
                    componentPerformanceSection
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(" Chiron Öğrenme")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.cyan)
            
            Text("Chiron Akıllı Öğrenme")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(symbol != nil ? "Sembol: \(symbol!)" : "Global Analiz")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    // MARK: - Learning Status Card
    
    private func learningStatusCard(_ status: (hasLearning: Bool, confidence: Double, note: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.hasLearning ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(status.hasLearning ? .green : .orange)
                
                Text("Öğrenme Durumu")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if status.hasLearning {
                    Text("\(Int(status.confidence * 100))%")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(confidenceColor(status.confidence))
                        .cornerRadius(8)
                }
            }
            
            Text(status.note)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Confidence bar
            if status.hasLearning {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(confidenceColor(status.confidence))
                            .frame(width: geo.size.width * status.confidence, height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Learned Weights Card
    
    private func learnedWeightsCard(_ weights: OrionWeightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                
                Text("Öğrenilmiş Ağırlıklar")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Weight bars
            weightBar(name: "Structure", value: weights.structure, color: .blue)
            weightBar(name: "Trend", value: weights.trend, color: .green)
            weightBar(name: "Momentum", value: weights.momentum, color: .orange)
            weightBar(name: "Pattern", value: weights.pattern, color: .purple)
            weightBar(name: "Volatility", value: weights.volatility, color: .red)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private func weightBar(name: String, value: Double, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * min(1.0, value * 2.5), height: 8) // Scale for visibility
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(value * 100))%")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    // MARK: - Component Performance Section
    
    private var componentPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                
                Text("Bileşen Performansı")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            let stats = symbol != nil && !symbolStats.isEmpty ? symbolStats : globalStats
            
            ForEach(stats.sorted(by: { $0.reliability > $1.reliability }), id: \.component) { stat in
                componentRow(stat)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private func componentRow(_ stat: ComponentPerformanceService.ComponentStats) -> some View {
        HStack {
            Circle()
                .fill(reliabilityColor(stat.reliability))
                .frame(width: 8, height: 8)
            
            Text(stat.component.capitalized)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Win: \(Int(stat.winRate))%")
                    .font(.caption)
                    .foregroundColor(stat.winRate > 50 ? .green : .red)
                
                Text("\(stat.signalCount) sinyal")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Reliability badge
            Text(reliabilityLabel(stat.reliability))
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(reliabilityColor(stat.reliability).opacity(0.2))
                .foregroundColor(reliabilityColor(stat.reliability))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Helpers
    
    private func loadData() {
        globalStats = ComponentPerformanceService.shared.analyzeGlobalPerformance()
        
        if let sym = symbol {
            symbolStats = ComponentPerformanceService.shared.analyzePerformance(for: sym)
            learnedWeights = ChironRegimeEngine.shared.getLearnedOrionWeights(symbol: sym)
            learningStatus = ChironRegimeEngine.shared.getLearningStatus(symbol: sym)
        } else {
            learnedWeights = ComponentPerformanceService.shared.calculateLearnedWeights(symbol: nil)
            let totalSignals = globalStats.reduce(0) { $0 + $1.signalCount }
            learningStatus = (totalSignals >= 10, Double(min(totalSignals, 20)) / 20.0, "\(totalSignals) trade analiz edildi")
        }
    }
    
    private func confidenceColor(_ value: Double) -> Color {
        if value >= 0.7 { return .green }
        if value >= 0.5 { return .orange }
        return .red
    }
    
    private func reliabilityColor(_ value: Double) -> Color {
        if value >= 0.6 { return .green }
        if value >= 0.45 { return .orange }
        return .red
    }
    
    private func reliabilityLabel(_ value: Double) -> String {
        if value >= 0.6 { return "Güvenilir" }
        if value >= 0.45 { return "Nötr" }
        return "Zayıf"
    }
}

#Preview {
    NavigationStack {
        ChironInsightsView(symbol: "AAPL")
    }
}
