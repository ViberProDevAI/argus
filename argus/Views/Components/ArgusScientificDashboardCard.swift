import SwiftUI

// MARK: - Argus Scientific Dashboard Card
/// Bilimsel doğrulama sonuçlarını gösteren yeni nesil Chiron UI bileşeni.
/// Sharpe, Drawdown ve Profit Factor gibi kurumsal metrikleri içerir.
struct ArgusScientificDashboardCard: View {
    @State private var stats: ScientificStats = .empty
    @State private var pendingHypotheses: [PendingForwardTest] = []
    @State private var recentResults: [ForwardTestResult] = []
    @State private var isProcessing = false
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "flask")
                    .foregroundColor(.cyan)
                Text("BİLİMSEL DOĞRULAMA")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Process Button
                Button(action: runValidation) {
                    if isProcessing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal")
                            Text("Analiz Et")
                        }
                        .font(.caption)
                        .foregroundColor(.cyan)
                    }
                }
                .disabled(isProcessing)
            }
            
            if isLoading {
                ProgressView().scaleEffect(0.7)
            } else {
                // Key Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ScientificMetricBox(title: "Doğrulanan", value: "\(stats.validatedHypotheses)", color: .white)
                    ScientificMetricBox(title: "Win Rate", value: String(format: "%.1f%%", stats.winRate * 100), color: stats.winRate > 0.5 ? .green : .orange)
                    ScientificMetricBox(title: "Profit Factor", value: String(format: "%.2f", stats.profitFactor), color: stats.profitFactor > 1.5 ? .green : .gray)
                    
                    ScientificMetricBox(title: "Sharpe Oranı", value: String(format: "%.2f", stats.sharpeRatio), color: stats.sharpeRatio > 1.0 ? .cyan : .gray)
                    ScientificMetricBox(title: "Max Kuraklık", value: String(format: "%.1f%%", stats.maxDrawdown), color: .red)
                    ScientificMetricBox(title: "Ort. Getiri", value: String(format: "%.2f%%", stats.averageReturn), color: stats.averageReturn > 0 ? .green : .red)
                }
                
                // Recent Validations List
                if !recentResults.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    Text("Doğrulama Günlüğü")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(recentResults.prefix(3)) { result in
                        ValidationResultRow(result: result)
                    }
                }
                
                // Pending Hypotheses
                if !pendingHypotheses.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    HStack {
                        Text("Bekleyen Hipotezler")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(pendingHypotheses.filter { $0.isMature }.count) Adet İncelenebilir")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(hex: "1A1A1A")) // Dark scientific background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .task {
            await loadData()
        }
    }
    
    // MARK: - Logic
    
    private func loadData() async {
        isLoading = true
        // ArgusValidator'dan bilimsel istatistikleri çek
        stats = await ArgusValidator.shared.calculateScientificMetrics()
        pendingHypotheses = await ArgusValidator.shared.getPendingHypotheses()
        
        // Diskten son sonuçları yükle (Manuel cache erişimi, basitlik için kopyalandı)
        let resultsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ArgusScientificResults.json")
        if let data = try? Data(contentsOf: resultsPath),
           let results = try? JSONDecoder().decode([ForwardTestResult].self, from: data) {
            recentResults = Array(results.suffix(5).reversed())
        }
        
        isLoading = false
    }
    
    private func runValidation() {
        isProcessing = true
        Task {
            let newResults = await ArgusValidator.shared.validateMaturedHypotheses()
            print("Validation complete: \(newResults.count) hypotheses verified.")
            await loadData()
            isProcessing = false
        }
    }
}

// MARK: - Components

struct ScientificMetricBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ValidationResultRow: View {
    let result: ForwardTestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.wasCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundColor(result.wasCorrect ? .green : .red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.symbol)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                Text("Gerçekleşen: \(String(format: "%+.2f%%", result.actualChange))")
                    .font(.caption2)
                    .foregroundColor(result.actualChange >= 0 ? .green : .red)
            }
            
            Spacer()
            
            Text(result.notes ?? "")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)
    }
}
