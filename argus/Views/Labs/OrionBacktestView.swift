import SwiftUI
import Charts

/// Orion modülü için özel backtest view
/// Skor tabanlı entry/exit: ≥70 AL, <50 SAT
struct OrionBacktestView: View {
    let symbol: String
    let candles: [Candle]
    
    @State private var result: BacktestResult?
    @State private var isRunning = false
    @State private var cachedSummary: ModuleBacktestSummary?
    @Environment(\.presentationMode) var presentationMode
    
    // Deep Tune States
    @State private var isDeepTuning = false
    @State private var deepTuneResult: ChironDeepTuner.DeepTuneResult?
    @State private var currentIteration = 0
    @State private var totalIterations = 20
    @State private var showTuningSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Cache Status
                if let cached = cachedSummary {
                    cacheStatusCard(cached)
                }
                
                // Run Button
                runButton
                
                // Results
                if let res = result {
                    resultsSection(res)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Orion Backtest")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if result != nil {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await loadCache()
        }
        .sheet(isPresented: $showTuningSheet) {
            if let tuneResult = deepTuneResult {
                TuningResultSheet(
                    result: tuneResult,
                    currentConfig: OrionV2TuningStore.shared.getConfig(symbol: symbol),
                    onApply: {
                        // Apply the optimized config
                        OrionV2TuningStore.shared.updateConfig(symbol: symbol, config: tuneResult.bestConfig)
                        print("✅ Deep Tune config uygulandı: \(symbol)")
                    },
                    onCancel: {
                        // Restore original config
                        print("❌ Deep Tune iptal edildi")
                    }
                )
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "telescope.fill")
                    .font(.title)
                    .foregroundColor(.purple)
                Text("Orion Geçmiş Testi")
                    .font(.title2)
                    .bold()
            }
            
            Text("Orion V2 skorlamasına göre alım/satım simülasyonu")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Alım: Skor ≥ 70 (kademeli pozisyon)")
                }
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("Satım: Skor < 50 (tam çıkış) veya < 62 (yarım)")
                }
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Stop-Loss: %5")
                }
            }
            .font(.caption2)
            .foregroundColor(.orange)
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func cacheStatusCard(_ cached: ModuleBacktestSummary) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)
            Text("Önbellek: Win Rate %\(String(format: "%.1f", cached.winRate)) (\(cached.tradeCount) işlem)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var runButton: some View {
        VStack(spacing: 12) {
            // Normal Backtest Button
            Button(action: runBacktest) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 5)
                    }
                    Text(isRunning ? "Hesaplanıyor..." : "Simülasyonu Başlat")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRunning ? Color.gray : Theme.tint)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRunning || isDeepTuning)
            
            // Deep Tune Button (UPDATED!)
            Button(action: startDeepTune) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        if isDeepTuning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Optimize ediliyor... (\(currentIteration)/\(totalIterations))")
                                .font(.caption)
                        } else {
                            Image(systemName: "brain.head.profile")
                            Text("Chiron Deep Tune")
                                .bold()
                        }
                    }
                    
                    // Progress bar when running
                    if isDeepTuning && totalIterations > 0 {
                        ProgressView(value: Double(currentIteration), total: Double(totalIterations))
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: isDeepTuning ? [.gray, .gray.opacity(0.8)] : [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRunning || isDeepTuning)
        }
        .padding(.horizontal)
    }
    
    private func resultsSection(_ res: BacktestResult) -> some View {
        VStack(spacing: 20) {
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                BacktestStatCard(
                    title: "Toplam Getiri",
                    value: String(format: "%+.2f%%", res.totalReturn),
                    color: res.totalReturn >= 0 ? .green : .red
                )
                BacktestStatCard(
                    title: "Win Rate",
                    value: String(format: "%.1f%%", res.winRate),
                    color: res.winRate >= 50 ? .green : .orange
                )
                BacktestStatCard(
                    title: "Max Drawdown",
                    value: String(format: "%.2f%%", res.maxDrawdown),
                    color: .orange
                )
                BacktestStatCard(
                    title: "İşlem Sayısı",
                    value: "\(res.trades.count)",
                    color: .blue
                )
            }
            .padding(.horizontal)
            
            // Chart with Trade Markers
            chartSection(res)
            
            // Trade List
            tradeListSection(res)
        }
    }
    
    private func chartSection(_ res: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fiyat Grafiği & İşlemler")
                .font(.headline)
                .padding(.leading)
            
            Chart {
                // Candles (simplified as line for performance)
                ForEach(res.candles.suffix(200)) { candle in
                    LineMark(
                        x: .value("Tarih", candle.date),
                        y: .value("Fiyat", candle.close)
                    )
                    .foregroundStyle(Color.gray.opacity(0.5))
                }
                
                // Buy markers
                ForEach(res.trades) { trade in
                    PointMark(
                        x: .value("Giriş", trade.entryDate),
                        y: .value("Fiyat", trade.entryPrice)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(100)
                    .symbol(.circle)
                    .annotation(position: .top) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                    
                    // Sell markers
                    if trade.exitPrice > 0 {
                        PointMark(
                            x: .value("Çıkış", trade.exitDate),
                            y: .value("Fiyat", trade.exitPrice)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(100)
                        .symbol(.circle)
                        .annotation(position: .bottom) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 300)
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    private func tradeListSection(_ res: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("İşlem Geçmişi")
                .font(.headline)
                .padding(.leading)
            
            if res.trades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "eye.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Bu dönemde işlem sinyali üretilmedi")
                        .foregroundColor(.secondary)
                    Text("Orion skoru alım eşiğinin (70) altında kaldı")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.secondaryBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ForEach(res.trades.reversed().prefix(10)) { trade in
                    TradeRow(trade: trade)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))
            Text("Sonuçları görmek için simülasyonu başlatın")
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Actions
    
    private func loadCache() async {
        cachedSummary = await BacktestCacheService.shared.getCache(for: symbol)?.orion
    }
    
    private func runBacktest() {
        isRunning = true
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            let config = BacktestConfig(
                initialCapital: 10_000,
                strategy: .orionV2,
                stopLossPct: 0.05 // %5 stop
            )
            
            let simulationResult = ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: config,
                candles: candles,
                financials: nil
            )
            
            DispatchQueue.main.async {
                withAnimation {
                    self.result = simulationResult
                    self.isRunning = false
                }
                
                // Cache'e kaydet
                Task {
                    let summary = simulationResult.toModuleSummary()
                    await BacktestCacheService.shared.saveOrionResult(symbol: symbol, result: summary)
                    self.cachedSummary = summary
                }
            }
        }
    }
    
    // MARK: - Export
    
    private var exportText: String {
        guard let res = result else { return "" }
        return """
        Orion Backtest - \(symbol)
        ========================
        Toplam Getiri: \(String(format: "%.2f%%", res.totalReturn))
        Win Rate: \(String(format: "%.1f%%", res.winRate))
        Max Drawdown: \(String(format: "%.2f%%", res.maxDrawdown))
        İşlem Sayısı: \(res.trades.count)
        Profit Factor: \(String(format: "%.2f", res.profitFactor))
        
        İşlemler:
        \(res.trades.map { "[\($0.entryDate.formatted(date: .numeric, time: .omitted))] \($0.pnl >= 0 ? "✅" : "❌") \(String(format: "%+.2f%%", $0.pnlPercent))" }.joined(separator: "\n"))
        """
    }
    
    // MARK: - Deep Tune
    
    private func startDeepTune() {
        isDeepTuning = true
        currentIteration = 0
        totalIterations = 20
        deepTuneResult = nil
        
        Task {
            let config = ChironDeepTuner.DeepTuneConfig.standard(symbol: symbol, candles: candles)
            totalIterations = config.maxIterations
            
            let tuneResult = await ChironDeepTuner.shared.runDeepTune(
                config: config,
                onProgress: { current, total, _ in
                    Task { @MainActor in
                        self.currentIteration = current
                        self.totalIterations = total
                    }
                }
            )
            
            await MainActor.run {
                withAnimation {
                    self.deepTuneResult = tuneResult
                    self.isDeepTuning = false
                    self.showTuningSheet = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func autoTuneBanner(_ tuneResult: ChironAutoTuner.TuneResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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
            
            // Performance Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("En İyi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("#\(tuneResult.bestIteration)")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.purple)
                }
                
                Divider().frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Win Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", tuneResult.bestWinRate))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.green)
                }
                
                Divider().frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Getiri")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", tuneResult.bestTotalReturn))
                        .font(.title3)
                        .bold()
                        .foregroundColor(tuneResult.bestTotalReturn >= 0 ? .green : .red)
                }
            }
            
            // Orion V2 Component Weight Changes (CORRECT!)
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Orion V2 Bileşen Ağırlıkları")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.purple)
                }
                
                let orionWeights = OrionV2WeightStore.shared.getWeights(symbol: symbol)
                
                orionV2WeightRow("Structure", weight: orionWeights.structure, max: 0.35, color: .blue)
                orionV2WeightRow("Trend", weight: orionWeights.trend, max: 0.25, color: .green)
                orionV2WeightRow("Momentum", weight: orionWeights.momentum, max: 0.25, color: .orange)
                orionV2WeightRow("Pattern", weight: orionWeights.pattern, max: 0.15, color: .purple)
                
                // Confidence
                HStack {
                    Text("Güven:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", orionWeights.confidence * 100))
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.green)
                    Spacer()
                    Text(orionWeights.reasoning)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Weight Change Helpers
    
    @ViewBuilder
    private func weightChangeRow(_ name: String, before: Double, after: Double, color: Color) -> some View {
        let change = after - before
        let changePercent = before > 0 ? (change / before) * 100 : 0
        
        HStack {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(String(format: "%.0f%%", before * 100))
                .font(.caption2)
                .foregroundColor(.gray)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(.gray)
            
            Text(String(format: "%.0f%%", after * 100))
                .font(.caption2)
                .bold()
                .foregroundColor(color)
            
            Spacer()
            
            if abs(changePercent) > 0.5 {
                Text(String(format: "%+.0f%%", changePercent))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(change > 0 ? .green : .red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(change > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    )
            }
        }
    }
    
    private func weightPill(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(String(format: "%.0f", value * 100))
                .font(.system(size: 9))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.3))
        .cornerRadius(6)
    }
    
    // Orion V2 specific weight row with progress bar
    @ViewBuilder
    private func orionV2WeightRow(_ name: String, weight: Double, max: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(weight / max))
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.0f%%", weight * 100))
                .font(.caption2)
                .bold()
                .foregroundColor(color)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Trade Row Component

private struct TradeRow: View {
    let trade: BacktestTrade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: trade.pnl >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(trade.pnl >= 0 ? .green : .red)
                    Text(trade.entryDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .bold()
                }
                Text(trade.exitReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%+.2f%%", trade.pnlPercent))
                    .font(.headline)
                    .foregroundColor(trade.pnl >= 0 ? .green : .red)
                Text("$\(String(format: "%.0f", trade.entryPrice)) → $\(String(format: "%.0f", trade.exitPrice))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        OrionBacktestView(symbol: "THYAO.IS", candles: [])
    }
}
