import SwiftUI

struct SirkiyeDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var rotateOrbit = false
    @State private var showDetails = false
    @State private var xu100Value: Double = 0
    @State private var xu100Change: Double = 0
    
    // Gerçek veriyi ViewModel'den al
    var atmosphere: (score: Double, mode: MarketMode, reason: String) {
        if let decision = viewModel.bistAtmosphere {
            let score = decision.netSupport * 100.0
            let reason = decision.winningProposal?.reasoning ?? "Analiz tamamlandı"
            return (score, decision.marketMode, reason)
        } else {
            return (50.0, .neutral, "Veri bekleniyor...")
        }
    }
    
    var statusIndicator: (color: Color, text: String) {
        if viewModel.bistAtmosphere != nil {
            return (InstitutionalTheme.Colors.positive, "Canlı Veri")
        } else {
            return (InstitutionalTheme.Colors.warning, "Güncelleniyor...")
        }
    }
    
    var xu100DisplayValue: String {
        if xu100Value > 0 {
            return String(format: "%.0f", xu100Value)
        }
        return "---"
    }
    
    var xu100ChangeText: String {
        if xu100Value > 0 {
            let sign = xu100Change >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", xu100Change))%"
        }
        return ""
    }
    
    var xu100ChangeColor: Color {
        return xu100Change >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 0) {
                // Left: Cortex Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(atmosphere.score / 100.0))
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: modeColors), center: .center),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    // Skor göstergesi
                    Text("\(Int(atmosphere.score))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
                .padding(.leading, 16)
                .padding(.vertical, 16)
                
                // Center: Text Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("SİRKİYE KORTEKS")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text(modeDisplayText)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle().fill(statusIndicator.color).frame(width: 6, height: 6)
                        Text(statusIndicator.text)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Right: XU100 Endeks Değeri (Gerçek Veri)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BIST 100")
                        .font(.caption2).bold().foregroundColor(.secondary)
                    
                    Text(xu100DisplayValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if !xu100ChangeText.isEmpty {
                        Text(xu100ChangeText)
                            .font(.caption2).bold()
                            .foregroundColor(xu100ChangeColor)
                    }
                }
                .padding(.trailing, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal, 16)
        }
        .onAppear { 
            rotateOrbit = true
            // İlk yüklemede atmosferi ve XU100'ü güncelle
            Task {
                if viewModel.bistAtmosphere == nil {
                    await viewModel.refreshBistAtmosphere()
                }
                await loadXU100()
            }
        }
        .sheet(isPresented: $showDetails) {
            NavigationStack {
                SirkiyeAetherView()
            }
        }
    }
    
    // MARK: - XU100 Loader
    private func loadXU100() async {
        do {
            let quote = try await BorsaPyProvider.shared.getXU100()
            await MainActor.run {
                xu100Value = quote.last
                xu100Change = quote.changePercent
            }
        } catch {
            print("⚠️ XU100 yüklenemedi: \(error)")
        }
    }
    
    // MARK: - Helper Properties
    
    private var modeColors: [Color] {
        switch atmosphere.mode {
        case .panic: return [InstitutionalTheme.Colors.negative, InstitutionalTheme.Colors.warning]
        case .extremeFear: return [InstitutionalTheme.Colors.negative, InstitutionalTheme.Colors.textSecondary]
        case .fear: return [InstitutionalTheme.Colors.warning, InstitutionalTheme.Colors.textSecondary]
        case .neutral: return [InstitutionalTheme.Colors.primary, InstitutionalTheme.Colors.textSecondary]
        case .greed: return [InstitutionalTheme.Colors.positive, InstitutionalTheme.Colors.primary]
        case .extremeGreed: return [InstitutionalTheme.Colors.positive, InstitutionalTheme.Colors.warning]
        case .complacency: return [InstitutionalTheme.Colors.textSecondary, InstitutionalTheme.Colors.textTertiary]
        }
    }
    
    private var scoreColor: Color {
        if atmosphere.score >= 70 { return InstitutionalTheme.Colors.positive }
        else if atmosphere.score >= 50 { return InstitutionalTheme.Colors.primary }
        else if atmosphere.score >= 30 { return InstitutionalTheme.Colors.warning }
        else { return InstitutionalTheme.Colors.negative }
    }
    
    private var modeDisplayText: String {
        switch atmosphere.mode {
        case .panic: return "PANİK MOD"
        case .extremeFear: return "AŞIRI KORKU"
        case .fear: return "KORKU MOD"
        case .neutral: return "Politik Atmosfer"
        case .greed: return "AÇGÖZLÜ MOD"
        case .extremeGreed: return "AŞIRI AÇGÖZLÜLÜK"
        case .complacency: return "REHAVET"
        }
    }
    
    private var stanceText: String {
        guard let decision = viewModel.bistAtmosphere else { return "BEKLENİYOR" }
        switch decision.stance {
        case .riskOff: return "RİSK KAPALI"
        case .defensive: return "DEFANSİF"
        case .cautious: return "TEDBİRLİ"
        case .riskOn: return "RİSK AÇIK"
        }
    }
    
    private var stanceColor: Color {
        guard let decision = viewModel.bistAtmosphere else { return .gray }
        switch decision.stance {
        case .riskOff: return .red
        case .defensive: return .orange
        case .cautious: return .yellow
        case .riskOn: return .green
        }
    }
}

// Custom Badge Helper
extension View {
    func paddingbadge(_ color: Color) -> some View {
        self.padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// Sheet for Detailed View (News + Scores)
struct SirkiyeDetailsSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // NEW: Real Macro Data State
    @State private var snapshot: TCMBDataService.TCMBMacroSnapshot?
    
    // Optional: If nil, shows "General/Market" news. If set, shows symbol news.
    var symbol: String?
    
    var newsInsights: [NewsInsight] {
        if let s = symbol, let list = viewModel.newsInsightsBySymbol[s] {
            return list
        } else {
            // General Dashboard Mode: Use 'generalNewsInsights' from ViewModel
            // Or aggregate BIST specific news if available
            return viewModel.generalNewsInsights
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Pulse
                        ZStack {
                            Circle().fill(Color.purple.opacity(0.1)).frame(width: 120, height: 120)
                            Circle().stroke(Color.purple.opacity(0.5), lineWidth: 1).frame(width: 140, height: 140)
                            Image(systemName: "eye.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.purple)
                        }
                        .padding(.top, 20)
                        
                        Text("SİRKİYE GÖZETİMİ")
                            .font(.title2).bold().foregroundColor(.white).tracking(2)
                        
                        if let s = symbol {
                            Text("\(s) için politik ve sistemik risk takibi.")
                                .font(.caption).foregroundColor(.gray)
                        } else {
                            Text("Borsa İstanbul Genel Atmosfer")
                                .font(.caption).foregroundColor(.gray)
                        }
                        
                        // Score Cards - Gerçek Verilerle
                        HStack(spacing: 16) {
                            ScoreCard(
                                title: "POLİTİK RİSK",
                                value: politicalRiskValue,
                                color: politicalRiskColor,
                                icon: "building.columns.fill"
                            )
                            ScoreCard(
                                title: "GENEL DURUŞ", 
                                value: stanceValue,
                                color: stanceColor,
                                icon: "shield.fill"
                            )
                        }
                        .padding(.horizontal)
                        
                        // Sirkiye Detay Kartı
                        if let decision = viewModel.bistAtmosphere {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("SİRKİYE ANALİZİ")
                                        .font(.caption).bold().foregroundColor(.gray)
                                    Spacer()
                                    if let updated = viewModel.bistAtmosphereLastUpdated {
                                        Text(timeAgo(updated))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Skor göstergesi
                                HStack {
                                    Text("Atmosfer Skoru:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(decision.netSupport * 100))/100")
                                        .font(.title2).bold()
                                        .foregroundColor(scoreColor(decision.netSupport * 100))
                                }
                                
                                // V2: USD/TRY ve Reel Getiri Göstergeleri (Gerçek Veri)
                                HStack(spacing: 12) {
                                    // USD/TRY Mini Card
                                    VStack(spacing: 4) {
                                        Text("USD/TRY")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        // Use snapshot if available, else fallback to viewModel or 0
                                        Text(String(format: "%.2f", snapshot?.usdTry ?? viewModel.usdTryRate))
                                            .font(.title3).bold()
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    
                                    // Enflasyon Mini Card
                                    VStack(spacing: 4) {
                                        Text("ENFLASYON")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        
                                        if let inf = snapshot?.inflation {
                                            Text("%\(String(format: "%.1f", inf))")
                                                .font(.title3).bold()
                                                .foregroundColor(.orange)
                                        } else {
                                            Text("---")
                                                .font(.title3).bold()
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                    
                                    // Reel Getiri Mini Card (Politika Faizi - Enflasyon kabaca)
                                    VStack(spacing: 4) {
                                        Text("REEL FAİZ")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        
                                        if let pol = snapshot?.policyRate, let inf = snapshot?.inflation {
                                            let real = pol - inf
                                            Text("\(real >= 0 ? "+" : "")%\(String(format: "%.1f", real))")
                                                .font(.title3).bold()
                                                .foregroundColor(real >= 0 ? .green : .red)
                                        } else {
                                            Text("---")
                                                .font(.title3).bold()
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                

                                
                                // Makro Zeka Linki (Aether)
                                NavigationLink(destination: SirkiyeAetherView()) {
                                    HStack {
                                        Image(systemName: "globe.europe.africa.fill")
                                            .font(.title3)
                                            .foregroundColor(.cyan)
                                        
                                        Text("DETAYLI MAKRO RAPORU (AETHER)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue.opacity(0.1))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                                    )
                                }
                                .padding(.vertical, 8)
                                
                                Divider().background(Color.gray.opacity(0.3))
                                
                                // Reasoning
                                if let proposal = decision.winningProposal {
                                    Text(proposal.reasoning)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                
                                // Uyarılar
                                if !decision.warnings.isEmpty {
                                    ForEach(decision.warnings, id: \.self) { warning in
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text(warning)
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // News Feed Placeholder
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("KRİTİK BAŞLIKLAR").font(.caption).bold().foregroundColor(.gray)
                                Spacer()
                                if viewModel.isLoadingNews {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Button(action: { refreshNews() }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            
                            if newsInsights.isEmpty {
                                Text(viewModel.isLoadingNews ? "Veri çekiliyor..." : "Henüz kritik bir başlık tespit edilmedi.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(newsInsights, id: \.id) { insight in
                                    NewsRow(
                                        source: insight.symbol == "GENERAL" ? "Piyasa" : insight.symbol,
                                        title: insight.headline,
                                        time: timeAgo(insight.createdAt),
                                        sentiment: insight.sentiment
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarItems(trailing: Button("Kapat") { presentationMode.wrappedValue.dismiss() })
            .onAppear {
                if newsInsights.isEmpty {
                    refreshNews()
                }
                // Load Real Macro Data
                Task {
                    self.snapshot = await TCMBDataService.shared.getMacroSnapshot()
                }
            }
        }
    }
    
    private func refreshNews() {
        if let s = symbol {
            viewModel.loadNewsAndInsights(for: s, isGeneral: false)
        } else {
            viewModel.loadGeneralFeed()
        }
    }
    
    // Helper
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Computed Properties for Real Data
    
    private var politicalRiskValue: String {
        guard let decision = viewModel.bistAtmosphere else { return "BEKLENİYOR" }
        switch decision.marketMode {
        case .panic: return "KRİTİK"
        case .extremeFear: return "KRİTİK"
        case .fear: return "YÜKSEK"
        case .neutral: return "NÖTR"
        case .greed: return "DÜŞÜK"
        case .extremeGreed: return "ÇOK DÜŞÜK"
        case .complacency: return "REHAVET"
        }
    }
    
    private var politicalRiskColor: Color {
        guard let decision = viewModel.bistAtmosphere else { return .gray }
        switch decision.marketMode {
        case .panic: return .red
        case .extremeFear: return .red
        case .fear: return .orange
        case .neutral: return .yellow
        case .greed: return .green
        case .extremeGreed: return .green
        case .complacency: return .purple
        }
    }
    
    private var stanceValue: String {
        guard let decision = viewModel.bistAtmosphere else { return "BEKLENİYOR" }
        switch decision.stance {
        case .riskOff: return "KAPALI"
        case .defensive: return "DEFANSİF"
        case .cautious: return "TEDBİRLİ"
        case .riskOn: return "AÇIK"
        }
    }
    
    private var stanceColor: Color {
        guard let decision = viewModel.bistAtmosphere else { return .gray }
        switch decision.stance {
        case .riskOff: return .red
        case .defensive: return .orange
        case .cautious: return .yellow
        case .riskOn: return .green
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        else if score >= 50 { return .cyan }
        else if score >= 30 { return .orange }
        else { return .red }
    }
}

struct ScoreCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2).bold().foregroundColor(.gray)
            
            Text(value)
                .font(.headline).bold().foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct NewsRow: View {
    let source: String
    let title: String
    let time: String
    var sentiment: NewsSentiment = .neutral // Add sentiment color
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(sentimentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(source).font(.caption2).bold().foregroundColor(.gray)
                    Spacer()
                    Text(time).font(.caption2).foregroundColor(.gray)
                }
                Text(title).font(.subheadline).foregroundColor(.white).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    var sentimentColor: Color {
        switch sentiment {
        case .strongPositive, .weakPositive: return .green
        case .strongNegative, .weakNegative: return .red
        default: return .purple
        }
    }
}
