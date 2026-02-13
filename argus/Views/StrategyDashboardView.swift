import SwiftUI

struct StrategyDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel
    
    @State private var selectedBucket: OrionMultiFrameEngine.StrategyBucket = .swing
    @State private var multiFrameReports: [String: OrionMultiFrameEngine.MultiFrameReport] = [:]
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                bucketSelector
                
                if isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            bucketDetailCard
                            timeframeConsensusSection
                            topOpportunitiesSection
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
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRADE BRAIN 2.0")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                    .tracking(2)
                
                Text("Multi-Timeframe Strategy Conductor")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { Task { await loadData() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(InstitutionalTheme.Colors.primary)
            }
        }
        .padding()
    }
    
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
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(selectedBucket == bucket ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textSecondary)
                
                Text(bucketTimeframeLabel(bucket))
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                
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
        case .scalp: return InstitutionalTheme.Colors.warning
        case .swing: return InstitutionalTheme.Colors.primary
        case .position: return InstitutionalTheme.Colors.warning
        }
    }
    
    private var bucketDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(bucketColor(selectedBucket))
                    .frame(width: 12, height: 12)
                
                Text(selectedBucket.displayName)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("Aktif")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.positive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(InstitutionalTheme.Colors.positive.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            HStack(spacing: 20) {
                statItem(label: "Risk", value: riskLabel(selectedBucket))
                statItem(label: "Hold Süresi", value: holdLabel(selectedBucket))
                statItem(label: "Hedef", value: targetLabel(selectedBucket))
            }
            
            Text(bucketDescription(selectedBucket))
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .padding(.top, 4)
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(InstitutionalTheme.Typography.dataSmall)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
    
    private var timeframeConsensusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ZAMAN DILİMİ KONSENSUS")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            if multiFrameReports.isEmpty {
                Text("Veri yükleniyor...")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            } else {
                ForEach(Array(multiFrameReports.keys.prefix(5)), id: \.self) { symbol in
                    if let report = multiFrameReports[symbol] {
                        consensusRow(symbol: symbol, report: report)
                    }
                }
            }
        }
        .padding()
        .institutionalCard(scale: .standard, elevated: false)
    }
    
    private func consensusRow(symbol: String, report: OrionMultiFrameEngine.MultiFrameReport) -> some View {
        HStack {
            Text(symbol)
                .font(InstitutionalTheme.Typography.dataSmall)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(report.analyses, id: \.timeframe.rawValue) { analysis in
                    Circle()
                        .fill(signalColor(analysis.signal))
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            Text(report.consensus.overallSignal.rawValue)
                .font(InstitutionalTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(signalColor(report.consensus.overallSignal))
        }
        .padding(.vertical, 4)
    }
    
    private func signalColor(_ signal: OrionMultiFrameEngine.TimeframeAnalysis.Signal) -> Color {
        switch signal {
        case .strongBuy: return InstitutionalTheme.Colors.positive
        case .buy: return InstitutionalTheme.Colors.positive.opacity(0.7)
        case .neutral: return InstitutionalTheme.Colors.textTertiary
        case .sell: return InstitutionalTheme.Colors.negative.opacity(0.7)
        case .strongSell: return InstitutionalTheme.Colors.negative
        }
    }
    
    private var topOpportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EN İYİ FIRSATLAR")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .tracking(1)
            
            let opportunities = getTopOpportunities()
            
            if opportunities.isEmpty {
                Text("Şu an güçlü fırsat yok")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            } else {
                ForEach(opportunities.prefix(3), id: \.symbol) { opp in
                    opportunityRow(opp)
                }
            }
        }
        .padding()
        .institutionalCard(scale: .standard, elevated: false)
    }
    
    private func opportunityRow(_ opp: Opportunity) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(opp.symbol)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                Text(opp.reason)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(opp.confidence * 100))%")
                    .font(InstitutionalTheme.Typography.data)
                    .foregroundColor(InstitutionalTheme.Colors.positive)
                
                Text(opp.bucket.rawValue)
                    .font(InstitutionalTheme.Typography.micro)
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
    
    private var alkindusInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                Text("ALKINDUS TAVSİYELERİ")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1)
            }
            
            Text("Bu strateji bucketı için Alkindus önerileri yükleniyor...")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding()
        .institutionalCard(scale: .standard, elevated: false)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Multi-timeframe analiz yapılıyor...")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            LoadingQuoteView()
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadData() async {
        isLoading = true
        
        let symbols = Array(viewModel.quotes.keys.prefix(10))
        
        for symbol in symbols {
            let report = await OrionMultiFrameEngine.shared.analyzeMultiFrame(symbol: symbol) { sym, tf in
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

#Preview {
    NavigationView {
        StrategyDashboardView(viewModel: TradingViewModel())
    }
}
