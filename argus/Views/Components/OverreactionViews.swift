import SwiftUI
import Charts

struct OverreactionCardView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @State private var showDetail = false
    
    var body: some View {
        // Only show if result exists (or show empty state if Lab is active?)
        // User Requirement: "Orion kartının hemen altında yeni bir mini kart ekle"
        // If result is nil, it means NO opportunity passing filters.
        // Should we show "No Opportunity" or hide?
        // Prompt says: "Şu an aşırı tepki fırsatı görmüyorum" text if nil or low score?
        // Actually Engine returns 'nil' if pre-filters fail.
        // If result is nil, maybe show "Hunter: Standby" or similar.
        // Let's show it always to confirm module is active.
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scope")
                    .foregroundColor(.cyan)
                Text("Overreaction Hunter")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                if let result = viewModel.overreactionResult {
                    OverreactionScoreBadge(score: Int(result.score))
                } else {
                    Text("Standby")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.gray)
                }
            }
            
            if let result = viewModel.overreactionResult {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(result.shockType.rawValue) Tespiti: Skor \(Int(result.score))/100")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            } else {
                 Text("Şu an aşırı tepki fırsatı/kriteri oluşmadı.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            if viewModel.overreactionResult != nil {
                showDetail = true
            }
        }
        .contextMenu {
             // Simülasyon testi kaldırıldı (Prod için)
        }
        .sheet(isPresented: $showDetail) {
            if let res = viewModel.overreactionResult {
                OverreactionDetailSheet(result: res, symbol: symbol)
            }
        }
    }
}

struct OverreactionDetailSheet: View {
    let result: OverreactionResult
    let symbol: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(symbol)
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Overreaction Analysis")
                                .font(.headline)
                                .foregroundColor(.cyan)
                            
                            OverreactionScoreBadge(score: Int(result.score), size: 60)
                                .padding(.top)
                        }
                        .padding(.top)
                        
                        // Plan Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trade Planı")
                                .font(.title3)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 20) {
                                PlanItem(label: "Giriş", value: String(format: "%.2f", result.entryPrice ?? 0), color: .blue)
                                PlanItem(label: "Stop", value: String(format: "%.2f", result.stopLoss ?? 0), color: .red)
                            }
                            
                            Divider().background(Theme.border)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hedefler").font(.caption).foregroundColor(.gray)
                                HStack {
                                    ForEach(0..<result.targets.count, id: \.self) { i in
                                        Text("TP\(i+1): \(String(format: "%.2f", result.targets[i]))")
                                            .font(.caption)
                                            .bold()
                                            .padding(6)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                Text("Zaman Stopu: \(result.timeStopDays) Gün")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan, lineWidth: 1))
                        .padding(.horizontal)
                        
                        // Analysis Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analiz Detayları")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack {
                                Text("Şok Tipi:")
                                Spacer()
                                Text(result.shockType.rawValue).bold().foregroundColor(.orange)
                            }
                            
                            HStack {
                                Text("Z-Score (Şiddet):")
                                Spacer()
                                Text(String(format: "%.2f", result.magnitudeZScore)).foregroundColor(.red)
                            }
                            
                            if let rel = result.relativeToSpy {
                                HStack {
                                    Text("vs SPY (Relatif):")
                                    Spacer()
                                    Text(String(format: "%.2f%%", rel * 100))
                                        .foregroundColor(rel < -0.02 ? .green : .gray) // Green means good relative drop for buying? Or red? It represents discount. Green is intuitive for "Opportunity".
                                }
                            }
                            
                            Divider().background(Theme.border)
                            
                            HStack {
                                Text("Atlas (Kalite):")
                                Spacer()
                                Text(String(format: "%.0f", result.qualityScore)).foregroundColor(Theme.tint)
                            }
                            
                            HStack {
                                Text("Aether (Makro):")
                                Spacer()
                                Text(String(format: "%.0f", result.macroScore)).foregroundColor(Theme.tint)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Disclaimer
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Bu modül 'Lab Mode' kapsamındadır. Argus ana skorunu etkilemez. Sunulan trade planı istatistiksel overreaction modeline dayanır ve kesinlikle yatırım tavsiyesi değildir.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// Helper Views
struct PlanItem: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.gray)
            Text(value).font(.title3).bold().foregroundColor(color)
        }
    }
}

struct OverreactionScoreBadge: View {
    let score: Int
    var size: CGFloat = 24
    
    var body: some View {
        Text("\(score)")
            .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(badgeColor(for: score))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
    }
    
    private func badgeColor(for score: Int) -> Color {
        if score >= 80 {
            return .red // High overreaction
        } else if score >= 60 {
            return .orange // Moderate overreaction
        } else if score >= 40 {
            return .yellow // Low overreaction
        } else {
            return .gray // No significant overreaction
        }
    }
}
