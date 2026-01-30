import SwiftUI

struct MarketReportView: View {
    let report: MarketAnalysisReport
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Info
                    HStack {
                        Text("Rapor Zamanı:")
                            .foregroundColor(.secondary)
                        Text(report.timestamp, style: .time)
                            .bold()
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    
                    // 1. Trend Opportunities (MACD/SMA)
                    if !report.trendOpportunities.isEmpty {
                        ReportSignalSection(
                            title: "Trend Fırsatları (MACD/SMA) 📈",
                            subtitle: "Bu hisseler güçlü bir trendde. Trend takipçisi indikatörler (MACD, SMA) en iyi sonucu verir.",
                            signals: report.trendOpportunities,
                            color: Theme.tint
                        )
                    }
                    
                    // 2. Reversal Opportunities (RSI/Bollinger)
                    if !report.reversalOpportunities.isEmpty {
                        ReportSignalSection(
                            title: "Tepki Fırsatları (RSI/Bollinger) ⚡️",
                            subtitle: "Bu hisseler aşırı alım/satım bölgesinde. Dönüş sinyalleri (RSI, Bollinger) takip edilmeli.",
                            signals: report.reversalOpportunities,
                            color: Theme.warning
                        )
                    }
                    
                    // 3. Breakout Opportunities
                    if !report.breakoutOpportunities.isEmpty {
                        ReportSignalSection(
                            title: "Sert Hareket Edenler (Breakout) 🚀",
                            subtitle: "Fiyat ve hacimde ani değişim var. Volatilite stratejileri uygun.",
                            signals: report.breakoutOpportunities,
                            color: Theme.positive
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("AI Piyasa Raporu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .background(Theme.background.edgesIgnoringSafeArea(.all))
        }
    }
}

struct ReportSignalSection: View {
    let title: String
    let subtitle: String?
    let signals: [AnalysisSignal]
    let color: Color
    
    init(title: String, subtitle: String? = nil, signals: [AnalysisSignal], color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.signals = signals
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .bold()
                .padding(.horizontal)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(signals) { signal in
                        AnalysisSignalCard(signal: signal, color: color)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AnalysisSignalCard: View {
    let signal: AnalysisSignal
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(signal.symbol)
                    .font(.title2)
                    .bold()
                Spacer()
                Text("\(Int(signal.score))")
                    .font(.headline)
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Divider()
            
            // Reason
            Text(signal.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Factors
            VStack(alignment: .leading, spacing: 4) {
                ForEach(signal.keyFactors.prefix(3), id: \.self) { factor in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                        Text(factor)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 280, height: 220)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
