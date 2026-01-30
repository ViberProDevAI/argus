
import SwiftUI
import Charts

struct FundDetailView: View {
    let fundCode: String
    var fundName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    @State private var fundDetail: FundDetail?
    @State private var history: [FundPrice] = []
    @State private var allocation: [FundAllocation] = []
    @State private var riskMetrics: RiskMetrics?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Veriler Yükleniyor...")
                        .padding(.top, 50)
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else if let detail = fundDetail {
                    // 1. Header
                    headerSection(detail: detail)
                    
                    // 2. Returns Grid
                    returnsGrid(detail: detail)
                    
                    // 3. Risk Analysis Card
                    if let metrics = riskMetrics {
                        riskAnalysisCard(metrics: metrics)
                    }
                    
                    // 4. Allocation Chart
                    if !allocation.isEmpty {
                        allocationSection
                    }
                    
                    // 5. Price Chart
                    if !history.isEmpty {
                        priceChartSection
                    }
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(fundCode)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }
    
    // MARK: - Sections
    
    private func headerSection(detail: FundDetail) -> some View {
        VStack(spacing: 8) {
            Text(detail.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                VStack {
                    Text("Fiyat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "₺%.4f", detail.price))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                
                VStack {
                    Text("Günlük")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%%%.2f", detail.dailyReturn))
                        .font(.title2)
                        .bold()
                        .foregroundColor(detail.dailyReturn >= 0 ? .green : .red)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func returnsGrid(detail: FundDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            returnBox(title: "1 Ay", value: detail.return1M)
            returnBox(title: "3 Ay", value: detail.return3M)
            returnBox(title: "Yılbaşı", value: detail.return1Y)
        }
    }
    
    private func returnBox(title: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let v = value {
                Text(String(format: "%%%.1f", v))
                    .font(.headline)
                    .foregroundColor(v >= 0 ? .green : .red)
            } else {
                Text("-")
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }
    
    private func riskAnalysisCard(metrics: RiskMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.shield")
                    .foregroundColor(.orange)
                Text("Risk Analizi (Yıllık)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 20) {
                riskMetricItem(title: "Sharpe", value: String(format: "%.2f", metrics.sharpeRatio), description: "Getiri/Risk Oranı")
                Divider()
                riskMetricItem(title: "Volatilite", value: String(format: "%%%.1f", metrics.annualizedVolatility), description: "Standart Sapma")
                Divider()
                riskMetricItem(title: "Max Drawdown", value: String(format: "%%%.1f", metrics.maxDrawdown), description: "En Büyük Düşüş", color: .red)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func riskMetricItem(title: String, value: String, description: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Varlık Dağılımı")
                .font(.headline)
                .padding(.leading, 4)
            
            Chart(allocation) { item in
                SectorMark(
                    angle: .value("Oran", item.weight),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Varlık", item.assetName))
            }
            .frame(height: 200)
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(16)
        }
    }
    
    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fiyat Geçmişi (\(history.count) Gün)")
                .font(.headline)
                .padding(.leading, 4)
            
            Chart(history) { item in
                LineMark(
                    x: .value("Tarih", item.date),
                    y: .value("Fiyat", item.price)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.tint)
                
                AreaMark(
                    x: .value("Tarih", item.date),
                    y: .value("Fiyat", item.price)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.tint.opacity(0.3), Theme.tint.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 250)
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Logic
    
    private func loadData() {
        Task {
            isLoading = true
            do {
                // FundTurkey API - max 60 günlük veri destekliyor
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -60, to: endDate)!
                
                print("📊 FundDetail: Loading \(fundCode) from \(startDate) to \(endDate)")
                
                // Sadece history çalışıyor - allocation API engelli
                let hist = try await TefasService.shared.fetchHistory(fundCode: fundCode, startDate: startDate, endDate: endDate)
                
                print("📊 FundDetail: Got \(hist.count) price points")
                
                let prices = hist.map { $0.price }
                let metrics = await RiskMetricsEngine.shared.calculateMetricsAsync(prices: prices)
                
                await MainActor.run {
                    self.history = hist
                    self.riskMetrics = metrics
                    
                    if let last = hist.last, let first = hist.first {
                        // Getiri hesapla
                        let totalReturn = ((last.price - first.price) / first.price) * 100
                        
                        self.fundDetail = FundDetail(
                            code: fundCode,
                            name: fundName.isEmpty ? "\(fundCode) Fonu" : fundName,
                            price: last.price,
                            dailyReturn: hist.count >= 2 ? ((last.price - hist[hist.count - 2].price) / hist[hist.count - 2].price) * 100 : 0,
                            return1M: calculateReturn(hist, days: 30),
                            return3M: nil, // 60 günlük veri ile hesaplanamaz
                            return6M: nil,
                            return1Y: nil,
                            return3Y: nil,
                            return5Y: nil,
                            riskValue: 4,
                            categoryRank: nil,
                            fundSize: last.fundSize,
                            investors: last.investors,
                            allocation: [] // Allocation API engelli
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                print("❌ FundDetail Error: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateReturn(_ history: [FundPrice], days: Int) -> Double? {
        guard history.count > days, let last = history.last else { return nil }
        let start = history[history.count - days - 1]
        return ((last.price - start.price) / start.price) * 100
    }
}
