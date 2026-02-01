import SwiftUI

// MARK: - Strategy Dashboard View
/// Tüm strateji bucket'larının performansını gösteren dashboard.
/// Scalp, Swing, Position stratejilerinin durumu tek bakışta.

struct StrategyDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel
    
    @State private var selectedBucket: OrionMultiFrameEngine.StrategyBucket = .swing
    @State private var multiFrameReports: [String: OrionMultiFrameEngine.MultiFrameReport] = [:]
    @State private var isLoading = true
    
    // Theme
    private let bg = Color(red: 0.04, green: 0.05, blue: 0.08)
    private let cardBg = Color(red: 0.08, green: 0.10, blue: 0.14)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let green = Color(red: 0.0, green: 0.9, blue: 0.5)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Bucket Selector
                bucketSelector
                
                // Content
                if isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Selected Bucket Detail
                            bucketDetailCard
                            
                            // Timeframe Consensus
                            timeframeConsensusSection
                            
                            // Top Opportunities
                            topOpportunitiesSection
                            
                            // Alkindus Insights
                            alkindusInsightsSection
                            
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Strateji Merkezi")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRADE BRAIN 2.0")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(gold)
                    .tracking(2)
                
                Text("Multi-Timeframe Strategy Conductor")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Refresh Button
            Button(action: { Task { await loadData() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(cyan)
            }
        }
        .padding()
    }
    
    // MARK: - Bucket Selector
    
    private var bucketSelector: some View {
        HStack(spacing: 12) {
            ForEach([OrionMultiFrameEngine.StrategyBucket.scalp, .swing, .position], id: \.rawValue) { bucket in
                bucketTab(bucket)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private func bucketTab(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> some View {
        Button(action: { selectedBucket = bucket }) {
            VStack(spacing: 4) {
                Text(bucket.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(selectedBucket == bucket ? .white : .gray)
                
                Text(bucketTimeframeLabel(bucket))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                // Indicator line
                Rectangle()
                    .fill(selectedBucket == bucket ? bucketColor(bucket) : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func bucketTimeframeLabel(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> String {
        switch bucket {
        case .scalp: return "5M-15M"
        case .swing: return "1H-4H"
        case .position: return "1D-1W"
        }
    }
    
    private func bucketColor(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> Color {
        switch bucket {
        case .scalp: return .orange
        case .swing: return cyan
        case .position: return gold
        }
    }
    
    // MARK: - Bucket Detail Card
    
    private var bucketDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(bucketColor(selectedBucket))
                    .frame(width: 12, height: 12)
                
                Text(selectedBucket.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Aktif")
                    .font(.caption)
                    .foregroundColor(green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(green.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Stats
            HStack(spacing: 20) {
                statItem(label: "Risk", value: riskLabel(selectedBucket))
                statItem(label: "Hold Süresi", value: holdLabel(selectedBucket))
                statItem(label: "Hedef", value: targetLabel(selectedBucket))
            }
            
            // Description
            Text(bucketDescription(selectedBucket))
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func riskLabel(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> String {
        switch bucket {
        case .scalp: return "1%"
        case .swing: return "3%"
        case .position: return "7%"
        }
    }
    
    private func holdLabel(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> String {
        switch bucket {
        case .scalp: return "~4 saat"
        case .swing: return "~7 gün"
        case .position: return "~30 gün"
        }
    }
    
    private func targetLabel(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> String {
        switch bucket {
        case .scalp: return "2%"
        case .swing: return "8%"
        case .position: return "20%"
        }
    }
    
    private func bucketDescription(_ bucket: OrionMultiFrameEngine.StrategyBucket) -> String {
        switch bucket {
        case .scalp: return "Kısa vadeli fırsatları yakala. Hızlı giriş-çıkış, düşük hedef ama sık trade."
        case .swing: return "Orta vadeli trendleri takip et. Sabır gerektirir ama daha yüksek getiri potansiyeli."
        case .position: return "Uzun vadeli yatırım. Temel analiz ağırlıklı, az trade ama büyük kazanç hedefi."
        }
    }
    
    // MARK: - Timeframe Consensus
    
    private var timeframeConsensusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⏱️ ZAMAN DİLİMİ KONSENSUS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            if multiFrameReports.isEmpty {
                Text("Veri yükleniyor...")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ForEach(Array(multiFrameReports.keys.prefix(5)), id: \.self) { symbol in
                    if let report = multiFrameReports[symbol] {
                        consensusRow(symbol: symbol, report: report)
                    }
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    private func consensusRow(symbol: String, report: OrionMultiFrameEngine.MultiFrameReport) -> some View {
        HStack {
            Text(symbol)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            // Timeframe dots
            HStack(spacing: 4) {
                ForEach(report.analyses, id: \.timeframe.rawValue) { analysis in
                    Circle()
                        .fill(signalColor(analysis.signal))
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            Text(report.consensus.overallSignal.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(signalColor(report.consensus.overallSignal))
        }
        .padding(.vertical, 4)
    }
    
    private func signalColor(_ signal: OrionMultiFrameEngine.TimeframeAnalysis.Signal) -> Color {
        switch signal {
        case .strongBuy: return green
        case .buy: return green.opacity(0.7)
        case .neutral: return .gray
        case .sell: return red.opacity(0.7)
        case .strongSell: return red
        }
    }
    
    // MARK: - Top Opportunities
    
    private var topOpportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(" EN İYİ FIRSATLAR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            let opportunities = getTopOpportunities()
            
            if opportunities.isEmpty {
                Text("Şu an güçlü fırsat yok")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ForEach(opportunities.prefix(3), id: \.symbol) { opp in
                    opportunityRow(opp)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    private func opportunityRow(_ opp: Opportunity) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(opp.symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(opp.reason)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(opp.confidence * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(green)
                
                Text(opp.bucket.rawValue)
                    .font(.caption2)
                    .foregroundColor(bucketColor(opp.bucket))
            }
        }
        .padding(.vertical, 6)
    }
    
    private struct Opportunity {
        let symbol: String
        let bucket: OrionMultiFrameEngine.StrategyBucket
        let confidence: Double
        let reason: String
    }
    
    private func getTopOpportunities() -> [Opportunity] {
        return multiFrameReports.compactMap { symbol, report in
            if let rec = report.bucketRecommendations[selectedBucket],
               rec.signal == .strongBuy || rec.signal == .buy {
                return Opportunity(
                    symbol: symbol,
                    bucket: selectedBucket,
                    confidence: rec.confidence,
                    reason: rec.reasoning
                )
            }
            return nil
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Alkindus Insights
    
    private var alkindusInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(gold)
                Text("ALKINDUS TAVSİYELERİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
            
            Text("Bu strateji bucketı için Alkindus önerileri yükleniyor...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Multi-timeframe analiz yapılıyor...")
                .font(.caption)
                .foregroundColor(.gray)
            
            LoadingQuoteView()
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        
        // Get watchlist symbols
        let symbols = Array(viewModel.quotes.keys.prefix(10))
        
        for symbol in symbols {
            let report = await OrionMultiFrameEngine.shared.analyzeMultiFrame(symbol: symbol) { sym, tf in
                // Return candles for the timeframe
                // This is a simplified version - in production, fetch from MarketDataStore
                return viewModel.candles[symbol]
            }
            
            await MainActor.run {
                multiFrameReports[symbol] = report
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        StrategyDashboardView(viewModel: TradingViewModel())
    }
}
