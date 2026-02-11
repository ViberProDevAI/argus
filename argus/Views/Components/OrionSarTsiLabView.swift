import SwiftUI

struct OrionSarTsiLabCard: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @State private var showDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                    .shadow(color: .purple.opacity(0.5), radius: 4)
                
                Text("Orion SAR+TSI Lab (Deneysel)")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                if viewModel.isLoadingSarTsiBacktest {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.sarTsiBacktestResult != nil {
                     Image(systemName: "chevron.right")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // Content
            if viewModel.sarTsiErrorMessage != nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Test çalıştırılamadı.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button("Tekrar Dene") {
                        Task { await viewModel.loadArgusData(for: symbol) }
                    }
                    .font(.caption)
                    .foregroundColor(Theme.tint)
                }
                .padding(.vertical, 4)
            } else if let result = viewModel.sarTsiBacktestResult {
                // Success Content
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        MetricCompact(label: "Net Getiri", value: String(format: "%.1f%%", result.netReturnPercent), color: result.netReturnPercent > 0 ? .green : .red)
                        MetricCompact(label: "Win Rate", value: String(format: "%.0f%%", result.winRatePercent), color: .blue)
                        MetricCompact(label: "Max DD", value: String(format: "%.1f%%", result.maxDrawdownPercent), color: .orange)
                    }
                    
                    Divider().background(Theme.border)
                    
                    HStack {
                        Text("Sinyal: \(result.lastSignal.rawValue)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(signalColor(result.lastSignal))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(signalColor(result.lastSignal).opacity(0.1))
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text("\(result.tradesCount) işlem (5 Yıl)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .onTapGesture {
                    showDetail = true
                }
            } else if !viewModel.isLoadingSarTsiBacktest {
                Text("Veri yok.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showDetail) {
             if let result = viewModel.sarTsiBacktestResult {
                 OrionSarTsiDetailSheet(result: result)
             }
        }
    }
    
    func signalColor(_ signal: OrionSarTsiSignal) -> Color {
        switch signal {
        case .buy: return .green
        case .exit: return .red
        case .hold: return .blue
        case .none: return .gray
        }
    }
}

// MARK: - Sub Components
struct MetricCompact: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
    }
}

// MARK: - Detail Sheet
struct OrionSarTsiDetailSheet: View {
    let result: OrionSarTsiBacktestResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Orion Deneysel Lab")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(20)
                            
                            Text("Parabolic SAR + TSI")
                                .font(.title2)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("US hisseleri için tasarlanmış trend takipçisi.")
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Performance Cards
                        VStack(spacing: 16) {
                            PerformanceRow(label: "Strateji Getirisi", value: String(format: "%.2f%%", result.netReturnPercent), color: result.netReturnPercent > 0 ? .green : .red)
                            PerformanceRow(label: "Buy & Hold Getirisi", value: String(format: "%.2f%%", result.buyAndHoldReturnPercent), color: .gray)
                            Divider().background(Theme.border)
                            PerformanceRow(label: "Max Drawdown", value: String(format: "%.2f%%", result.maxDrawdownPercent), color: .orange)
                            PerformanceRow(label: "Win Rate", value: String(format: "%.1f%%", result.winRatePercent), color: .blue)
                            PerformanceRow(label: "Toplam İşlem", value: "\(result.tradesCount)", color: .white)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Signal Status
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mevcut Durum")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack {
                                Text("Son Sinyal:")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(result.lastSignal.rawValue)
                                    .bold()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(signalColor(result.lastSignal).opacity(0.2))
                                    .foregroundColor(signalColor(result.lastSignal))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Explanation
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Nasıl Çalışır?")
                                    .bold()
                            }
                            .foregroundColor(Theme.textPrimary)
                            
                            Text("Bu algoritma, 3 farklı hassasiyette (Yavaş, Orta, Hızlı) Parabolic SAR kullanarak ana trendi belirler. Eğer fiyat tüm SAR'ların üzerindeyse (Bull Trend) ve TSI momentumu (3, 9, Slope 20) pozitifse AL sinyali üretir.\n\nTrend bozulduğunda veya momentum zayıfladığında pozisyonu kapatır. Sadece LONG (Alım) yönlü çalışır.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    func signalColor(_ signal: OrionSarTsiSignal) -> Color {
        switch signal {
        case .buy: return .green
        case .exit: return .red
        case .hold: return .blue
        case .none: return .gray
        }
    }
}

struct PerformanceRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).bold().foregroundColor(color)
        }
    }
}
