import SwiftUI

// MARK: - Alkindus Symbol Card
/// Shows symbol-specific Alkindus insights in StockDetailView (Sanctum).
/// "For AAPL, Orion has 75% hit rate"

struct AlkindusSymbolCard: View {
    let symbol: String
    
    @State private var insight: SymbolInsight?
    @State private var bestModule: (module: String, hitRate: Double)?
    @State private var isLoading = true
    
    // Theme
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(gold)
                Text("ALKINDUS ÖĞRENMELERİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Yükleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            } else if let insight = insight {
                // Has data
                VStack(alignment: .leading, spacing: 8) {
                    // Best module
                    HStack {
                        Circle()
                            .fill(green)
                            .frame(width: 8, height: 8)
                        Text("En Güvenilir:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(insight.bestModule.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(insight.bestHitRate * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(green)
                    }
                    
                    // Worst module (if different)
                    if insight.bestModule != insight.worstModule {
                        HStack {
                            Circle()
                                .fill(red.opacity(0.6))
                                .frame(width: 8, height: 8)
                            Text("Dikkatli Ol:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(insight.worstModule.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(insight.worstHitRate * 100))%")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Sample size
                    Text("\(insight.totalDecisions) karar üzerinden")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                // No data
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.gray)
                    Text("Henüz \(symbol) için yeterli veri yok")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        insight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: symbol)
        bestModule = await AlkindusSymbolLearner.shared.getBestModule(for: symbol)
        isLoading = false
    }
}

// MARK: - Alkindus Time Card
/// Shows temporal insights for the current time.

struct AlkindusTimeCard: View {
    @State private var timeAdvice: String?
    @State private var anomalies: [TemporalAnomaly] = []
    
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(cyan)
                Text("ZAMAN BAZLI İÇGÖRÜLER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
            
            if let advice = timeAdvice {
                Text(advice)
                    .font(.caption)
                    .foregroundColor(.white)
            } else {
                Text("Henüz zaman bazlı pattern yok")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if !anomalies.isEmpty {
                ForEach(anomalies.prefix(2), id: \.timeSlot) { anomaly in
                    Text("• \(anomaly.message)")
                        .font(.caption2)
                        .foregroundColor(anomaly.deviation > 0 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .task {
            timeAdvice = await AlkindusTemporalAnalyzer.shared.getCurrentTimeAdvice()
            anomalies = await AlkindusTemporalAnalyzer.shared.getTemporalAnomalies()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AlkindusSymbolCard(symbol: "AAPL")
        AlkindusTimeCard()
    }
    .padding()
    .background(Color.black)
}
