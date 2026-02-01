import SwiftUI
import Charts

struct ArgusBacktestView: View {
    let symbol: String
    let candles: [Candle]
    
    @State private var result: BacktestResult?
    @State private var selectedStrategy: BacktestConfig.StrategyType = .orionV2
    @State private var isRunning = false
    
    // Auto-Tune States
    @State private var isAutoTuning = false
    @State private var autoTuneResult: ChironAutoTuner.TuneResult?
    @State private var currentIteration = 0
    @State private var showAutoTuneSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Orion Teknik Laboratuvarı ")
                        .font(.title2)
                        .bold()
                    Text("Fiyat ve hHacim verileriyle teknik strateji testi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                    Text("⚠️ Uyarı: Temel Analiz (Atlas) ve Haberler (Hermes) simülasyona dahil değildir. Sonuçlar sadece teknik zamanlamayı gösterir.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Controls
                // Controls
                VStack(spacing: 16) {
                    // Strategy Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(BacktestConfig.StrategyType.allCases, id: \.self) { type in
                                Button(action: { selectedStrategy = type }) {
                                    Text(type.rawValue)
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedStrategy == type ? Theme.tint : Theme.secondaryBackground)
                                        .foregroundColor(selectedStrategy == type ? .white : Theme.textPrimary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Buttons Row
                    HStack(spacing: 12) {
                        // Normal Backtest
                        Button(action: runSimulation) {
                            HStack {
                                if isRunning { ProgressView().padding(.trailing, 5) }
                                Text(isRunning ? "Hesaplanıyor..." : "Simülasyonu Başlat")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.tint)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRunning || isAutoTuning)
                        
                        // Auto-Tune Button (NEW!)
                        Button(action: startAutoTune) {
                            HStack(spacing: 6) {
                                if isAutoTuning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("\(currentIteration)/10")
                                        .font(.caption)
                                } else {
                                    Image(systemName: "brain.head.profile")
                                    Text("Auto-Tune")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRunning || isAutoTuning)
                    }
                }
                .padding(.horizontal)
                
                // Auto-Tune Results Banner
                if let tuneResult = autoTuneResult {
                    autoTuneBanner(tuneResult)
                }
                
                // Results
                if let res = result {
                    VStack(spacing: 20) {
                        // 1. Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            BacktestStatCard(title: "Toplam Getiri", value: String(format: "%.2f%%", res.totalReturn), color: res.totalReturn >= 0 ? .green : .red)
                            BacktestStatCard(title: "Son Sermaye", value: String(format: "$%.0f", res.finalCapital), color: .primary)
                            BacktestStatCard(title: "Max Drawdown", value: String(format: "%.2f%%", res.maxDrawdown), color: .orange)
                            BacktestStatCard(title: "İşlem Sayısı", value: "\(res.trades.count)", color: .blue)
                        }
                        .padding(.horizontal)
                        
                        // 2. Equity Curve
                        VStack(alignment: .leading) {
                            Text("Sermaye Eğrisi")
                                .font(.headline)
                                .padding(.leading)
                            
                            Chart(res.equityCurve) { point in
                                LineMark(
                                    x: .value("Tarih", point.date),
                                    y: .value("Değer", point.value)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.tint.gradient)
                            }
                            .frame(height: 250)
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // 3. Trade List (Last 5)
                        VStack(alignment: .leading) {
                            Text("Son İşlemler")
                                .font(.headline)
                                .padding(.leading)
                            
                            if res.trades.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "eyes")
                                        .font(.largeTitle)
                                        .foregroundColor(Theme.tint)
                                    Text("Argus bu dönemde hiç alım fırsatı bulamadı.")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                        .multilineTextAlignment(.center)
                                    Text("Skorlar alım eşiğinin (60) altında kaldı (Güvenli Mod).")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.secondaryBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                ForEach(res.trades.suffix(5).reversed()) { trade in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(trade.type.rawValue)
                                                .bold()
                                                .foregroundColor(trade.pnl >= 0 ? .green : .red)
                                            Text(trade.entryDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text(String(format: "%+.2f", trade.pnl))
                                                .bold()
                                                .foregroundColor(trade.pnl >= 0 ? .green : .red)
                                            Text(String(format: "%.2f%%", trade.pnlPercent))
                                                .font(.caption)
                                        }
                                    }
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // 4. Detailed Logs (New)
                        VStack(alignment: .leading) {
                            Text("Günlük Kayıtlar (Son 100)")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top)

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(res.logs.suffix(100).reversed()) { log in
                                        HStack {
                                            Text(log.date.formatted(date: .numeric, time: .omitted))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .frame(width: 70, alignment: .leading)
                                            
                                            Text("$\(String(format: "%.1f", log.price))")
                                                .font(.caption2)
                                                .bold()
                                                .frame(width: 60, alignment: .trailing)
                                                
                                            Spacer()
                                            
                                            Text(log.details) // "O:45 T:10 A:50"
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            
                                            Text(String(format: "%.1f", log.score))
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(log.score >= 60 ? .green : (log.score < 45 ? .red : .orange))
                                                .frame(width: 40)
                                            
                                            Text(log.action == "BUY" ? "AL" : (log.action == "SELL" ? "SAT" : "TUT"))
                                                .font(.caption2)
                                                .bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(log.action == "BUY" ? Color.green.opacity(0.2) : (log.action == "SELL" ? Color.red.opacity(0.2) : Color.gray.opacity(0.1)))
                                                .cornerRadius(4)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        .background(Theme.secondaryBackground.opacity(0.5))
                                        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.1)), alignment: .bottom)
                                    }
                                }
                            }
                            .frame(height: 300)
                            .background(Theme.secondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Sonuçları görmek için simülasyonu başlatın.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func runSimulation() {
        isRunning = true
        
        // Simulate Async work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            let config = BacktestConfig(
                initialCapital: 10_000,
                strategy: selectedStrategy,
                startDate: nil
            )
            
            let simulationResult = ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: config,
                candles: candles,
                financials: nil // Assuming pure price for MVP, or inject later
            )
            
            DispatchQueue.main.async {
                withAnimation {
                    self.result = simulationResult
                    self.isRunning = false
                }
                
                // Feed to Chiron
                Task {
                    await ArgusBacktestEngine.shared.feedBacktestToChiron(symbol: symbol, result: simulationResult)
                }
            }
        }
    }
    
    // MARK: - Auto-Tune
    
    private func startAutoTune() {
        isAutoTuning = true
        currentIteration = 0
        autoTuneResult = nil
        
        Task {
            let tuneResult = await ChironAutoTuner.shared.autoTune(
                symbol: symbol,
                candles: candles,
                engine: .pulse,
                config: ChironAutoTuner.TuneConfig(
                    maxIterations: 10,
                    convergenceThreshold: 1.0,
                    strategy: selectedStrategy
                ),
                onProgress: { iteration, _ in
                    Task { @MainActor in
                        currentIteration = iteration
                    }
                }
            )
            
            await MainActor.run {
                withAnimation {
                    self.autoTuneResult = tuneResult
                    self.isAutoTuning = false
                }
            }
        }
    }
    
    // MARK: - Auto-Tune Banner
    
    @ViewBuilder
    private func autoTuneBanner(_ tuneResult: ChironAutoTuner.TuneResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Chiron Auto-Tune Tamamlandı")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                Spacer()
                if tuneResult.converged {
                    Text("✓ Converged")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Best Results
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("En İyi İterasyon")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("#\(tuneResult.bestIteration)")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.purple)
                }
                
                Divider().frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Win Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", tuneResult.bestWinRate))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.green)
                }
                
                Divider().frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Getiri")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", tuneResult.bestTotalReturn))
                        .font(.title3)
                        .bold()
                        .foregroundColor(tuneResult.bestTotalReturn >= 0 ? .green : .red)
                }
            }
            
            // Iterations Mini Chart
            HStack(spacing: 2) {
                ForEach(tuneResult.iterations, id: \.iteration) { iter in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(iter.iteration == tuneResult.bestIteration ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 20, height: CGFloat(max(10, iter.winRate / 2)))
                        Text("\(iter.iteration)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(String(format: "Süre: %.1f saniye | %d iterasyon", tuneResult.totalTime, tuneResult.iterations.count))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [.purple.opacity(0.5), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal)
    }
}

// Helper Card
struct BacktestStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}
