import SwiftUI

// MARK: - 3. Argus Etf Detail View (Full Page Container)
struct ArgusEtfDetailView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    @State private var profile: ETFProfile?
    @State private var titanResult: ArgusEtfEngine.TitanResult?
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Theme.secondaryBackground))
                        }
                        
                        Text(symbol)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text("ETF")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(4)
                            .foregroundColor(.purple)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 1. Price
                    if let quote = viewModel.quotes[symbol] {
                        let isBist = symbol.uppercased().hasSuffix(".IS")
                        HStack(alignment: .lastTextBaseline) {
                            Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                Image(systemName: quote.change >= 0 ? "arrow.up" : "arrow.down")
                                Text(String(format: "%.2f%%", quote.percentChange))
                            }
                            .font(.headline)
                            .foregroundColor(quote.change >= 0 ? Theme.positive : Theme.negative)
                        }
                    }
                    
                    if isLoading {
                        ProgressView("Analiz Yapılıyor...")
                            .padding(.top, 40)
                    } else if let res = titanResult {
                        // 2. Titan Analysis
                        TitanAnalysisCard(result: res)
                            .padding(.horizontal)
                        
                        // 3. Fund Profile
                        FundProfileCard(profile: profile)
                            .padding(.horizontal)
                        
                        // 4. Chart Placeholder (Reusing existing or simple)
                        if let candles = viewModel.candles[symbol], !candles.isEmpty {
                            // Using standard chart but wrapped
                            ZStack {
                                Theme.cardBackground.cornerRadius(16)
                                InteractiveCandleChart(
                                    candles: candles,
                                    trades: nil,
                                    showSMA: true,
                                    showBollinger: false,
                                    showIchimoku: false,
                                    showMACD: false,
                                    showVolume: true,
                                    showRSI: false,
                                    showStochastic: false,
                                    showSAR: true,
                                    showTSI: true
                                )
                                    .padding()
                            }
                            .frame(height: 300)
                            .padding(.horizontal)
                        }
                        
                    } else {
                        Text("Veri Alınamadı")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .task {
            // Load Data
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        print(" Titan: loadData started for \(symbol)")
        
        // 1. Ensure Quote is available
        if viewModel.quotes[symbol] == nil {
            print(" Titan: Fetching quote for \(symbol)...")
            await viewModel.fetchQuote(for: symbol)
        }
        
        // 2. Ensure Candles are available (Critical for Titan)
        var candles = viewModel.candles[symbol] ?? []
        
        if candles.isEmpty {
            print(" Titan: Candles empty. Fetching candles for \(symbol)...")
            await viewModel.loadCandles(for: symbol, timeframe: "1G")
            candles = viewModel.candles[symbol] ?? []
            print(" Titan: Fetched \(candles.count) candles")
        } else {
            print(" Titan: Using cached \(candles.count) candles")
        }
        
        // 3. Ensure Macro data if possible
        if viewModel.macroRating == nil {
            print(" Titan: Macro rating missing, using nil")
        }
        
        // 4. Profile - Currently disabled (FMP removed)
        self.profile = nil
        
        // 5. Run Titan Analysis
        guard !candles.isEmpty else {
            print("⚠️ Titan: No candles available for \(symbol). Cannot analyze.")
            self.titanResult = nil
            isLoading = false
            return
        }
        
        let res = ArgusEtfEngine.shared.analyze(
            symbol: symbol,
            quotes: candles,
            macro: viewModel.macroRating,
            profile: self.profile
        )
        
        print(" Titan: Analysis complete. Score: \(String(format: "%.1f", res.score))")
        
        self.titanResult = res
        isLoading = false
    }
}
