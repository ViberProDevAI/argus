import SwiftUI
import Charts

struct ChronosLabView: View {
    @StateObject var viewModel: ChronosLabViewModel
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    if viewModel.isAnalyzing {
                        loadingView
                    } else if let result = viewModel.result, let overfit = viewModel.overfitAnalysis {
                        resultView(result: result, overfit: overfit)
                    } else {
                        configView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Chronos Lab ")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Components
    
    var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.cyan)
            
            Text("Walk-Forward Validation")
                .font(.headline)
                .foregroundColor(.white)
            
            if !viewModel.selectedSymbol.isEmpty {
                Text(viewModel.selectedSymbol)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical)
    }
    
    var configView: some View {
        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("⚙️ Test Konfigürasyonu")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Divider().background(Color.gray)
                    
                    // In-Sample Slider
                    VStack(alignment: .leading) {
                        Text("Öğrenme Penceresi: \(Int(viewModel.inSampleDays)) Gün")
                            .foregroundColor(.gray)
                        Slider(value: $viewModel.inSampleDays, in: 90...365, step: 30)
                    }
                    
                    // Out-of-Sample Slider
                    VStack(alignment: .leading) {
                        Text("Test Penceresi: \(Int(viewModel.outOfSampleDays)) Gün")
                            .foregroundColor(.gray)
                        Slider(value: $viewModel.outOfSampleDays, in: 7...90, step: 7)
                    }
                    
                    Text("Simülasyon, veriyi pencerelere bölerek 'İleri' doğru kaydırır.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            Button {
                viewModel.startAnalysis()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Teste Başla")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(2)
            
            Text("Zaman Bükülüyor...")
                .font(.headline)
                .foregroundColor(.cyan)
            
            ProgressView(value: viewModel.progress)
                .tint(.cyan)
        }
        .padding(.top, 40)
    }
    
    func resultView(result: WalkForwardResult, overfit: OverfitAnalysis) -> some View {
        VStack(spacing: 20) {
            // 1. Recommendation Card
            GlassCard {
                VStack(spacing: 12) {
                    Text("Chronos Kararı")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(overfit.recommendation)
                        .font(.title3)
                        .bold()
                        .multilineTextAlignment(.center)
                        .foregroundColor(colorForLevel(overfit.level))
                        .padding()
                        .background(colorForLevel(overfit.level).opacity(0.1))
                        .cornerRadius(8)
                    
                    HStack {
                        metricCell(title: "Overfit Skoru", value: "\(Int(overfit.score))/100", color: .white)
                        Divider().background(Color.gray)
                        metricCell(title: "Tutarlılık", value: viewModel.formattedConsistency, color: .white)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            
            // 2. Performance Breakdown
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Performans Özeti")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        metricCell(title: "IS Getiri (Ort)", value: String(format: "%.1f%%", result.avgInSampleReturn), color: .gray)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.gray)
                        Spacer()
                        metricCell(title: "OOS Getiri (Ort)", value: String(format: "%.1f%%", result.avgOutOfSampleReturn), color: result.avgOutOfSampleReturn > 0 ? .green : .red)
                    }
                    
                    Divider().background(Color.gray)
                    
                    Text("Overfitting Oranı: \(String(format: "%.2f", result.overfitRatio))x")
                        .font(.caption)
                        .foregroundColor(result.overfitRatio < 0.7 ? .orange : .green)
                }
            }
            .padding(.horizontal)
            
            // 3. Reset Button
            Button("Yeni Test") {
                viewModel.result = nil
            }
            .foregroundColor(.cyan)
        }
    }
    
    func metricCell(title: String, value: String, color: Color) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
        }
    }
    
    func colorForLevel(_ level: OverfitLevel) -> Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
