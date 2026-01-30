import SwiftUI

/// Strateji ve Öğrenme Merkezi Dashboard'u
/// Alkindus (Zaman) ve Chiron (Öğrenme) modüllerini birleştirir.
struct ArgusStrategyCenterView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var selectedSegment: StrategySegment = .alkindus

    enum StrategySegment: String, CaseIterable, Identifiable {
        case aether = "KAHİN (AETHER)"
        case chiron = "SİSTEM (CHIRON)"
        case alkindus = "STRATEJİ (ALKINDUS)"
        case backtest = "SİMÜLASYON"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .aether: return "eye.trianglebadge.exclamationmark"
            case .chiron: return "network"
            case .alkindus: return "brain.head.profile"
            case .backtest: return "flask"
            }
        }
    }

    var body: some View {
        ZStack {
            SanctumTheme.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Segmented Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(StrategySegment.allCases) { segment in
                            Button(action: {
                                withAnimation(.spring()) { selectedSegment = segment }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: segment.icon)
                                        .font(.system(size: 18))
                                    Text(segment.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(selectedSegment == segment ? SanctumTheme.hologramBlue.opacity(0.2) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedSegment == segment ? SanctumTheme.hologramBlue : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .foregroundColor(selectedSegment == segment ? SanctumTheme.hologramBlue : .gray)
                        }
                    }
                    .padding()
                }
                .background(SanctumTheme.surface)
                
                // Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSegment {
                        case .aether:
                            AetherDecisionView(viewModel: viewModel)
                        case .chiron:
                            ChironLearningDashboard(viewModel: viewModel)
                        case .alkindus:
                            AlkindusDashboard(viewModel: viewModel)
                        case .backtest:
                            BacktestResultsView()
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("STRATEJİ MERKEZİ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

struct AetherDecisionView: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(SanctumTheme.neonGreen)
                    Text("AETHER MAKRO GÖRÜŞÜ")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("PİYASA REJİMİ")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(viewModel.market.marketRegime.rawValue.uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(SanctumTheme.hologramBlue)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("RİSK İŞTAHI")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("NÖTR") // Todo: dynamic
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding()
            .background(SanctumTheme.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            // Insight Feed (Mock for now)
            VStack(alignment: .leading, spacing: 12) {
                Text("MAKRO ANALİZ NOTLARI")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                ForEach(0..<3) { _ in
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(SanctumTheme.neonGreen)
                            .frame(width: 4, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enflasyon verisi beklentilere paralel geldi.")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text("2 saat önce • TCMB")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct BacktestResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "flask.fill")
                .font(.system(size: 48))
                .foregroundColor(SanctumTheme.crimsonRed)
            
            Text("SİMÜLASYON MODU")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Geçmiş veriler üzerinde strateji testleri ve Monte Carlo simülasyonları burada görüntülenecek.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {}) {
                Text("YENİ TEST BAŞLAT")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(SanctumTheme.crimsonRed)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
        .padding()
        .background(SanctumTheme.surface)
        .cornerRadius(16)
    }
}

// MARK: - ALKINDUS DASHBOARD (Temporal Insights)
struct AlkindusDashboard: View {
    @ObservedObject var viewModel: TradingViewModel
    
    // Mock data for UI if real data is missing
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ZAMANSAL ANALİZ (TEMPORAL)")
                .font(.caption)
                .bold()
                .foregroundColor(.gray)
            
            // 1. Time Warp Status
            HStack {
                VStack(alignment: .leading) {
                    Text("Piyasa Frekansı")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Yüksek Volatilite")
                        .foregroundColor(.orange)
                        .bold()
                }
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundColor(.purple)
            }
            .padding()
            .background(SanctumTheme.surface)
            .cornerRadius(12)
            
            // 2. Seasonality Card
            VStack(alignment: .leading) {
                Text("Mevsimsellik (Ocak)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Geçmiş 5 Yıl Ortalaması:")
                    Spacer()
                    Text("%+2.4")
                        .foregroundColor(.green)
                        .bold()
                }
                .font(.subheadline)
                .padding(.top, 4)
                
                ProgressView(value: 0.7)
                    .tint(.purple)
                    .padding(.vertical, 8)
                
                Text("Şu an piyasa döngüsünün 'Birikim' evresindeyiz.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(SanctumTheme.surface)
            .cornerRadius(12)
        }
    }
}

// MARK: - CHIRON DASHBOARD (Learning System)
struct ChironLearningDashboard: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SİSTEM ÖĞRENME GÜNLÜĞÜ")
                .font(.caption)
                .bold()
                .foregroundColor(.gray)
            
            // Stats
            HStack(spacing: 12) {
                StrategyStatBox(title: "Öğrenilen Model", value: "142", color: .cyan)
                StrategyStatBox(title: "Doğruluk", value: "%78", color: .green)
                StrategyStatBox(title: "Hata Payı", value: "%22", color: .red)
            }
            
            // Recent Logs
            ForEach(0..<5) { i in
                HStack {
                    Circle()
                        .fill(i % 2 == 0 ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i % 2 == 0 ? "Başarılı Tahmin (THYAO)" : "Stop-Loss Tetiklendi (GARAN)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Model #\(1042 - i) - Parametre optimize edildi.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("1\(i)dk önce")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(SanctumTheme.surface)
                .cornerRadius(8)
            }
        }
    }
}

struct StrategyStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(SanctumTheme.surface)
        .cornerRadius(8)
    }
}
