import SwiftUI
import Charts

// MARK: - Sirkülasyon Analizi (Volume & Money Flow)
struct CirculationAnalysisView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    // Mock Data for now, will connect to BorsaPy later
    @State private var volumeData: [VolumePoint] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Sirkülasyon Analizi", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(symbol)
                    .font(.caption)
                    .bold()
                    .padding(6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Main Chart: Price vs Volume with Divergence Highlight
            ZStack {
                Theme.cardBackground
                    .cornerRadius(16)
                
                if volumeData.isEmpty {
                    ProgressView()
                } else {
                    VStack {
                        Chart {
                            ForEach(volumeData) { point in
                                BarMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("Volume", point.volume)
                                )
                                .foregroundStyle(point.isUp ? Theme.positive.gradient : Theme.negative.gradient)
                            }
                            
                            // Trend Line (Mock)
                            ForEach(volumeData) { point in
                                LineMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("OBV", point.obv)
                                )
                                .foregroundStyle(Color.blue)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisValueLabel()
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal)
            
            // Insight Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InsightCard(
                        title: "Para Girişi",
                        value: "Yüksek",
                        icon: "arrow.up.circle.fill",
                        color: Theme.positive
                    )
                    InsightCard(
                        title: "Hacim Trendi",
                        value: "Yükseliyor",
                        icon: "chart.line.uptrend.xyaxis",
                        color: Theme.accent
                    )
                    InsightCard(
                        title: "RSI Uyumsuzluğu",
                        value: "Yok",
                        icon: "equal.circle.fill",
                        color: .gray
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.black.opacity(0.3))
        .onAppear {
            generateMockData()
        }
    }
    
    private func generateMockData() {
        // Generate last 30 days dummy volume data
        var points: [VolumePoint] = []
        let calendar = Calendar.current
        var obv: Double = 1000000
        
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -30 + i, to: Date())!
            let isUp = Bool.random()
            let vol = Double.random(in: 1000...50000)
            
            if isUp {
                obv += vol
            } else {
                obv -= vol
            }
            
            points.append(VolumePoint(date: date, volume: vol, isUp: isUp, obv: obv))
        }
        
        self.volumeData = points
    }
}

struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
    let isUp: Bool
    let obv: Double // On Balance Volume simülasyonu
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.headline)
                .bold()
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 120)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
