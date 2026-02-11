import SwiftUI

// MARK: - Deep Tune Result Sheet
/// Shows comparison between current and optimized configs with apply/cancel options
struct TuningResultSheet: View {
    let result: ChironDeepTuner.DeepTuneResult
    let currentConfig: OrionV2TuningConfig
    let onApply: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Performance Comparison
                    performanceComparison
                    
                    // Weight Comparison
                    weightComparison
                    
                    // Threshold Comparison
                    thresholdComparison
                    
                    // Out-of-Sample Warning (if applicable)
                    if let oos = result.outOfSampleResult {
                        outOfSampleSection(oos)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Deep Tune Sonuçları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chiron Deep Tune")
                        .font(.headline)
                    Text("\(result.symbol) için optimize edildi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(result.iterations.count) iterasyon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f sn", result.totalTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if result.converged {
                Label("Convergence sağlandı", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }
    
    // MARK: - Performance Comparison
    
    private var performanceComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                Text("Performans Karşılaştırma")
                    .font(.headline)
            }
            
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 100, alignment: .leading)
                Text("Mevcut")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Text("Önerilen")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                Text("Fark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            
            Divider()
            
            performanceRow("Win Rate", 
                          current: result.baselineResult.winRate, 
                          proposed: result.bestResult.winRate, 
                          format: "%.1f%%")
            
            performanceRow("Toplam Getiri", 
                          current: result.baselineResult.totalReturn, 
                          proposed: result.bestResult.totalReturn, 
                          format: "%.1f%%")
            
            performanceRow("Max Drawdown", 
                          current: result.baselineResult.maxDrawdown, 
                          proposed: result.bestResult.maxDrawdown, 
                          format: "%.1f%%",
                          lowerIsBetter: true)
            
            performanceRow("Sharpe Ratio", 
                          current: result.baselineResult.sharpeRatio, 
                          proposed: result.bestResult.sharpeRatio, 
                          format: "%.2f")
            
            performanceRow("Trade Sayısı", 
                          current: Double(result.baselineResult.tradeCount), 
                          proposed: Double(result.bestResult.tradeCount), 
                          format: "%.0f")
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func performanceRow(_ label: String, current: Double, proposed: Double, format: String, lowerIsBetter: Bool = false) -> some View {
        let diff = proposed - current
        let isImproved = lowerIsBetter ? diff < 0 : diff > 0
        
        return HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(String(format: format, current))
                .font(.caption)
                .frame(maxWidth: .infinity)
            
            Text(String(format: format, proposed))
                .font(.caption)
                .bold()
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
            
            Text(String(format: "%+.1f", diff))
                .font(.caption2)
                .foregroundColor(isImproved ? .green : .red)
                .frame(width: 60)
        }
    }
    
    // MARK: - Weight Comparison
    
    private var weightComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚖️ Ağırlık Değişimleri")
                .font(.headline)
            
            weightRow("Structure", current: currentConfig.structureWeight, proposed: result.bestConfig.structureWeight, color: .blue)
            weightRow("Trend", current: currentConfig.trendWeight, proposed: result.bestConfig.trendWeight, color: .green)
            weightRow("Momentum", current: currentConfig.momentumWeight, proposed: result.bestConfig.momentumWeight, color: .orange)
            weightRow("Pattern", current: currentConfig.patternWeight, proposed: result.bestConfig.patternWeight, color: .purple)
            weightRow("Volatility", current: currentConfig.volatilityWeight, proposed: result.bestConfig.volatilityWeight, color: .cyan)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func weightRow(_ label: String, current: Double, proposed: Double, color: Color) -> some View {
        let diff = (proposed - current) * 100
        
        return HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Current bar
            GeometryReader { geo in
                Capsule()
                    .fill(color.opacity(0.3))
                    .frame(width: geo.size.width * CGFloat(current))
            }
            .frame(height: 8)
            
            Text(String(format: "%.0f%%", current * 100))
                .font(.caption2)
                .frame(width: 35)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            // Proposed bar
            GeometryReader { geo in
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(proposed))
            }
            .frame(height: 8)
            
            Text(String(format: "%.0f%%", proposed * 100))
                .font(.caption2)
                .bold()
                .foregroundColor(color)
                .frame(width: 35)
            
            // Diff badge
            if abs(diff) > 0.5 {
                Text(String(format: "%+.0f", diff))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(diff > 0 ? .green : .red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(diff > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    )
            }
        }
    }
    
    // MARK: - Threshold Comparison
    
    private var thresholdComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .foregroundColor(.purple)
                Text("Threshold Değişimleri")
                    .font(.headline)
            }
            
            thresholdRow("Entry ≥", current: currentConfig.entryThreshold, proposed: result.bestConfig.entryThreshold)
            thresholdRow("Exit <", current: currentConfig.exitThreshold, proposed: result.bestConfig.exitThreshold)
            thresholdRow("Stop-Loss", current: currentConfig.stopLossPercent, proposed: result.bestConfig.stopLossPercent, suffix: "%")
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func thresholdRow(_ label: String, current: Double, proposed: Double, suffix: String = "") -> some View {
        let diff = proposed - current
        
        return HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(String(format: "%.0f\(suffix)", current))
                .font(.caption)
                .frame(maxWidth: .infinity)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Text(String(format: "%.0f\(suffix)", proposed))
                .font(.caption)
                .bold()
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
            
            if abs(diff) > 0.5 {
                Text(String(format: "%+.0f", diff))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(diff > 0 ? .green : .red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(diff > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    )
            }
        }
    }
    
    // MARK: - Out of Sample
    
    private func outOfSampleSection(_ oos: ChironDeepTuner.BacktestMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Out-of-Sample Test", systemImage: "flask.fill")
                .font(.caption)
                .bold()
                .foregroundColor(.orange)
            
            HStack {
                VStack {
                    Text("Win Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", oos.winRate))
                        .font(.caption)
                        .bold()
                }
                
                Spacer()
                
                VStack {
                    Text("Getiri")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", oos.totalReturn))
                        .font(.caption)
                        .bold()
                        .foregroundColor(oos.totalReturn >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack {
                    Text("Max DD")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", oos.maxDrawdown))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)
                }
            }
            
            if oos.winRate < result.bestResult.winRate * 0.8 {
                Label("Dikkat: OOS performans train'den düşük - overfitting olabilir", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                onCancel()
                dismiss()
            }) {
                Text("Vazgeç")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            
            Button(action: {
                onApply()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Uygula")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(.top)
    }
}
