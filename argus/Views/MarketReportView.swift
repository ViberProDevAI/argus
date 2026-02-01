import SwiftUI

struct MarketReportView: View {
    let report: MarketAnalysisReport
    @Environment(\.presentationMode) var presentationMode
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
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
                            title: "Trend Fırsatları (MACD/SMA) ",
                            subtitle: "Bu hisseler güçlü bir trendde. Trend takipçisi indikatörler (MACD, SMA) en iyi sonucu verir.",
                            signals: report.trendOpportunities,
                            color: Theme.tint
                        )
                    }
                    
                    // 2. Reversal Opportunities (RSI/Bollinger)
                    if !report.reversalOpportunities.isEmpty {
                        ReportSignalSection(
                            title: "Tepki Fırsatları (RSI/Bollinger)",
                            subtitle: "Bu hisseler aşırı alım/satım bölgesinde. Dönüş sinyalleri (RSI, Bollinger) takip edilmeli.",
                            signals: report.reversalOpportunities,
                            color: Theme.warning
                        )
                    }
                    
                    // 3. Breakout Opportunities
                    if !report.breakoutOpportunities.isEmpty {
                        ReportSignalSection(
                            title: "Sert Hareket Edenler (Breakout) ",
                            subtitle: "Fiyat ve hacimde ani değişim var. Volatilite stratejileri uygun.",
                            signals: report.breakoutOpportunities,
                            color: Theme.positive
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Piyasa Raporu")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrawer = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .background(Theme.background.edgesIgnoringSafeArea(.all))
        }
        .overlay {
            if showDrawer {
                ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                    drawerSections(openSheet: openSheet)
                }
                .zIndex(200)
            }
        }
    }

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "EKRANLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .markets)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus", subtitle: "Yapay zeka merkez", icon: "brain.head.profile") {
                        deepLinkManager.navigate(to: .alkindus)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portfoy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Ayarlar", subtitle: "Tercihler", icon: "gearshape") {
                        deepLinkManager.navigate(to: .settings)
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "RAPOR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Kapat", subtitle: "Raporu kapat", icon: "xmark.circle") {
                        presentationMode.wrappedValue.dismiss()
                        showDrawer = false
                    }
                ]
            )
        )
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "ARACLAR",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                        openSheet(.calendar)
                    },
                    ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                        openSheet(.dictionary)
                    },
                    ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sagligi", icon: "waveform.path.ecg") {
                        openSheet(.systemHealth)
                    },
                    ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                        openSheet(.feedback)
                    }
                ]
            )
        )
        
        return sections
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
