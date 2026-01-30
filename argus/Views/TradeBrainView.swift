import SwiftUI
import Charts

// MARK: - Trade Brain View
/// Kapsamlı pozisyon yönetim ve eğitim görünümü

struct TradeBrainView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @State private var selectedTab = 0
    @State private var selectedPlan: PositionPlan?
    @State private var showPlanDetail = false
    @State private var marketMode: MarketMode = .all
    
    enum MarketMode: String, CaseIterable {
        case all = "Tümü"
        case global = "Global"
        case bist = "BIST"
    }
    
    // Filtered portfolio based on market mode
    private var filteredPortfolio: [Trade] {
        switch marketMode {
        case .all: return viewModel.portfolio
        case .global: return viewModel.portfolio.filter { !$0.symbol.hasSuffix(".IS") }
        case .bist: return viewModel.portfolio.filter { $0.symbol.hasSuffix(".IS") }
        }
    }
    
    // Filtered balance based on market mode
    private var filteredBalance: Double {
        switch marketMode {
        case .all: return viewModel.balance + viewModel.bistBalance
        case .global: return viewModel.balance
        case .bist: return viewModel.bistBalance
        }
    }
    
    // Filtered equity based on market mode
    private var filteredEquity: Double {
        let portfolioValue = filteredPortfolio.filter { $0.isOpen }.reduce(0.0) { sum, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (trade.quantity * price)
        }
        return filteredBalance + portfolioValue
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Market Selector
                    marketSelector
                    
                    // Header
                    headerSection
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content based on tab
                    switch selectedTab {
                    case 0:
                        portfolioHealthSection
                        activePositionsSection
                    case 1:
                        riskDashboardSection
                    case 2:
                        calendarSection
                    default:
                        educationSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trade Brain")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AlkindusAvatarView(size: 24, isThinking: false)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPlanDetail) {
                if let plan = selectedPlan {
                    PositionPlanDetailView(plan: plan)
                }
            }
        }
    }
    
    // MARK: - Market Selector
    
    private var marketSelector: some View {
        HStack(spacing: 0) {
            ForEach(MarketMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        marketMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        if mode == .bist {
                            Text("🇹🇷")
                        } else if mode == .global {
                            Text("🌍")
                        } else {
                            Text("📊")
                        }
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(marketMode == mode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        marketMode == mode ?
                        RoundedRectangle(cornerRadius: 10)
                            .fill(mode == .bist ? Color.red : (mode == .global ? Color.blue : Color.purple))
                        : nil
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Akıllı Pozisyon Yönetimi")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Profesyonel Trader Gibi Düşün")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Brain Score
                ZStack {
                    Circle()
                        .fill(brainScoreGradient)
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(brainScore))")
                            .font(DesignTokens.Fonts.custom(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("IQ")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                QuickStatBadge(
                    icon: "chart.pie.fill",
                    value: "\(openPositionsCount)",
                    label: "Açık",
                    color: .blue
                )
                
                QuickStatBadge(
                    icon: "banknote.fill",
                    value: "\(Int(cashRatio * 100))%",
                    label: "Nakit",
                    color: cashRatio >= 0.2 ? .green : .orange
                )
                
                QuickStatBadge(
                    icon: "calendar",
                    value: "\(upcomingEventsCount)",
                    label: "Olay",
                    color: upcomingEventsCount > 0 ? .orange : .gray
                )
                
                QuickStatBadge(
                    icon: "checkmark.shield.fill",
                    value: riskStatus,
                    label: "Risk",
                    color: riskStatusColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.title3)
                        Text(tabTitle(for: index))
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == index ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == index ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : nil
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "chart.line.uptrend.xyaxis"
        case 1: return "shield.lefthalf.filled"
        case 2: return "calendar.badge.clock"
        default: return "book.fill"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Pozisyonlar"
        case 1: return "Risk"
        case 2: return "Takvim"
        default: return "Öğren"
        }
    }
    
    // MARK: - Portfolio Health Section
    
    private var portfolioHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Portföy Sağlığı", icon: "heart.fill", color: .red)
            
            let health = PortfolioRiskManager.shared.checkPortfolioHealth(
                portfolio: filteredPortfolio,
                cashBalance: filteredBalance,
                totalEquity: filteredEquity,
                quotes: viewModel.quotes
            )
            
            // Health Score Ring
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: health.score / 100)
                        .stroke(
                            healthScoreGradient(score: health.score),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(health.score))")
                            .font(DesignTokens.Fonts.custom(size: 24, weight: .bold))
                        Text("puan")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(healthStatusColor(health.status))
                            .frame(width: 12, height: 12)
                        Text(health.status.rawValue)
                            .font(.headline)
                            .foregroundColor(healthStatusColor(health.status))
                    }
                    
                    if !health.issues.isEmpty {
                        ForEach(health.issues.prefix(2), id: \.self) { issue in
                            Text("• \(issue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("✓ Tüm göstergeler normal")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            
            // Suggestions
            if !health.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Öneriler")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(health.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Active Positions Section
    
    private var activePositionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pozisyon Planları", icon: "doc.text.fill", color: .blue)
            
            let openTrades = filteredPortfolio.filter { $0.isOpen }
            
            if openTrades.isEmpty {
                BrainEmptyCard(
                    icon: "tray",
                    title: "Açık Pozisyon Yok",
                    subtitle: "AutoPilot açıkken yeni pozisyonlar burada görünecek"
                )
            } else {
                ForEach(openTrades) { trade in
                    PositionPlanCard(
                        trade: trade,
                        plan: PositionPlanStore.shared.getPlan(for: trade.id),
                        currentPrice: viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
                    ) {
                        if let plan = PositionPlanStore.shared.getPlan(for: trade.id) {
                            selectedPlan = plan
                            showPlanDetail = true
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Risk Dashboard
    
    private var riskDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Risk Kontrol Paneli", icon: "shield.lefthalf.filled", color: .purple)
            
            // Limit Cards
            VStack(spacing: 12) {
                RiskLimitCard(
                    title: "Nakit Oranı",
                    current: cashRatio,
                    limit: 0.20,
                    isMinimum: true,
                    icon: "banknote.fill",
                    description: "Minimum %20 nakit tutarak ani fırsatlara hazır olun"
                )
                
                RiskLimitCard(
                    title: "Açık Pozisyon",
                    current: Double(openPositionsCount) / 15.0,
                    limit: 1.0,
                    isMinimum: false,
                    icon: "chart.pie.fill",
                    currentText: "\(openPositionsCount)/15",
                    description: "Maksimum 15 pozisyon ile diversifikasyonu koruyun"
                )
                
                RiskLimitCard(
                    title: "En Büyük Pozisyon",
                    current: maxPositionWeight,
                    limit: 0.15,
                    isMinimum: false,
                    icon: "scalemass.fill",
                    description: "Tek bir hisseye portföyün %15'inden fazla yatırmayın"
                )
            }
            
            // Education Box
            EducationCard(
                title: "Risk Yönetimi Neden Önemli?",
                content: "Profesyonel traderlar sermaye korumayı en öncelikli hedef olarak görür. Tek bir kötü işlem tüm kazançlarınızı silebilir. Bu limitler sizi korur.",
                icon: "graduationcap.fill"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Yaklaşan Olaylar", icon: "calendar.badge.clock", color: .orange)
            
            let events = EventCalendarService.shared.getUpcomingEvents(days: 14)
            
            if events.isEmpty {
                BrainEmptyCard(
                    icon: "calendar.badge.checkmark",
                    title: "Yakın Tarihte Olay Yok",
                    subtitle: "Önümüzdeki 14 gün içinde kritik olay bulunmuyor"
                )
            } else {
                ForEach(events) { event in
                    EventCard(event: event)
                }
            }
            
            // Education Box
            EducationCard(
                title: "Bilanço Öncesi Neden Alım Yapmıyoruz?",
                content: "Bilanço açıklamaları büyük fiyat hareketlerine neden olabilir. Sonuç beklentilerin altında kalırsa hisse %20+ düşebilir. Risk/getiri oranı olumsuz.",
                icon: "exclamationmark.triangle.fill"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Education Section
    
    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Trade Brain Öğreticisi", icon: "book.fill", color: .indigo)
            
            // Lesson Cards
            LessonCard(
                number: 1,
                title: "Pozisyon Planı Nedir?",
                content: "Her trade'e girmeden önce çıkış stratejinizi belirleyin. 'Ne zaman kâr alacağım?', 'Stop nerede?' sorularına önceden cevap verin.",
                isCompleted: true
            )
            
            LessonCard(
                number: 2,
                title: "Kademeli Satış",
                content: "Tüm pozisyonu tek seferde satmak yerine kademeli satın. Örnek: %15 kârda %30 sat, %25 kârda %30 sat, %35 kârda kalanı sat.",
                isCompleted: true
            )
            
            LessonCard(
                number: 3,
                title: "Risk Limitleri",
                content: "Asla tek bir hisseye portföyün %15'inden fazlasını yatırmayın. Her zaman %20 nakit tutun. Maksimum 15 açık pozisyon.",
                isCompleted: true
            )
            
            LessonCard(
                number: 4,
                title: "Takvim Farkındalığı",
                content: "Bilanço açıklamasından 3 gün önce yeni pozisyon açmayın. Fed toplantıları öncesi dikkatli olun.",
                isCompleted: false
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Computed Properties
    
    private var brainScore: Double {
        let health = PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: viewModel.portfolio,
            cashBalance: viewModel.balance,
            totalEquity: viewModel.getEquity(),
            quotes: viewModel.quotes
        )
        return health.score
    }
    
    private var brainScoreGradient: LinearGradient {
        if brainScore >= 80 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if brainScore >= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var openPositionsCount: Int {
        viewModel.portfolio.filter { $0.isOpen }.count
    }
    
    private var cashRatio: Double {
        let equity = viewModel.getEquity()
        return equity > 0 ? viewModel.balance / equity : 1.0
    }
    
    private var upcomingEventsCount: Int {
        EventCalendarService.shared.getUpcomingEvents(days: 7).count
    }
    
    private var riskStatus: String {
        let health = PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: viewModel.portfolio,
            cashBalance: viewModel.balance,
            totalEquity: viewModel.getEquity(),
            quotes: viewModel.quotes
        )
        
        switch health.status {
        case .healthy: return "OK"
        case .warning: return "⚠️"
        case .critical: return "❌"
        }
    }
    
    private var riskStatusColor: Color {
        let health = PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: viewModel.portfolio,
            cashBalance: viewModel.balance,
            totalEquity: viewModel.getEquity(),
            quotes: viewModel.quotes
        )
        
        switch health.status {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private var maxPositionWeight: Double {
        let openTrades = viewModel.portfolio.filter { $0.isOpen }
        let equity = viewModel.getEquity()
        guard equity > 0 else { return 0 }
        
        var maxWeight: Double = 0
        for trade in openTrades {
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let value = trade.quantity * price
            let weight = value / equity
            maxWeight = max(maxWeight, weight)
        }
        
        return maxWeight
    }
    
    private func healthScoreGradient(score: Double) -> LinearGradient {
        if score >= 80 {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        } else if score >= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private func healthStatusColor(_ status: PortfolioRiskManager.HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
    }
}

struct QuickStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct BrainEmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(DesignTokens.Fonts.custom(size: 40))
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct EducationCard: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.indigo)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.08))
        )
    }
}

struct LessonCard: View {
    let number: Int
    let title: String
    let content: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct RiskLimitCard: View {
    let title: String
    let current: Double
    let limit: Double
    let isMinimum: Bool
    let icon: String
    var currentText: String? = nil
    let description: String
    
    private var isWithinLimit: Bool {
        if isMinimum {
            return current >= limit
        } else {
            return current <= limit
        }
    }
    
    private var progressValue: Double {
        if isMinimum {
            return min(current / limit, 2.0) / 2.0
        } else {
            return min(current / limit, 1.0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isWithinLimit ? .green : .red)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(currentText ?? "\(Int(current * 100))%")
                .font(DesignTokens.Fonts.custom(size: 14, weight: .bold))
                    .foregroundColor(isWithinLimit ? .green : .red)
                
                Text(isMinimum ? "/ min \(Int(limit * 100))%" : "/ max \(Int(limit * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isWithinLimit ? Color.green : Color.red)
                        .frame(width: geo.size.width * progressValue, height: 8)
                }
            }
            .frame(height: 8)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct EventCard: View {
    let event: EventCalendarService.MarketEvent
    
    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: event.date).day ?? 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Date Badge
            VStack(spacing: 0) {
                Text(event.date.formatted(.dateTime.day()))
                    .font(DesignTokens.Fonts.custom(size: 24, weight: .bold))
                Text(event.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.type.emoji)
                    Text(event.symbol ?? "MARKET")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(daysUntil == 0 ? "BUGÜN" : "\(daysUntil) gün")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(daysUntil <= 1 ? .red : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(daysUntil <= 1 ? Color.red.opacity(DesignTokens.Opacity.glassCard) : Color.orange.opacity(DesignTokens.Opacity.glassCard))
                        )
                }
                
                Text(event.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let desc = event.description {
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct PositionPlanCard: View {
    let trade: Trade
    let plan: PositionPlan?
    let currentPrice: Double
    let onTap: () -> Void
    
    private var pnlPercent: Double {
        ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }
    
    private var isProfitable: Bool {
        pnlPercent >= 0
    }
    
    private var completedStepsCount: Int {
        plan?.executedSteps.count ?? 0
    }
    
    private var totalStepsCount: Int {
        guard let plan = plan else { return 0 }
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        return scenarios.flatMap { $0.steps }.count
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trade.symbol)
                            .font(.headline)
                        Text("\(String(format: "%.2f", trade.quantity)) adet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // PnL Badge
                    Text("\(isProfitable ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                    .font(DesignTokens.Fonts.custom(size: 14, weight: .bold))
                        .foregroundColor(isProfitable ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isProfitable ? Color.green.opacity(DesignTokens.Opacity.glassCard) : Color.red.opacity(DesignTokens.Opacity.glassCard))
                        )
                }
                
                Divider()
                
                // Plan Progress
                if let plan = plan {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        
                        Text("Plan Durumu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(completedStepsCount)/\(totalStepsCount) adım")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    // Next Step Preview
                    if let nextStep = findNextStep(in: plan) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text("Sonraki: \(nextStep.trigger.displayText) → \(nextStep.action.displayText)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Plan oluşturulmadı")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Tap hint
                HStack {
                    Spacer()
                    Text("Detaylar için dokun →")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func findNextStep(in plan: PositionPlan) -> PlannedAction? {
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        for scenario in scenarios where scenario.isActive {
            for step in scenario.steps.sorted(by: { $0.priority < $1.priority }) {
                if !plan.executedSteps.contains(step.id) {
                    return step
                }
            }
        }
        return nil
    }
}

// MARK: - Position Plan Detail View

struct PositionPlanDetailView: View {
    let plan: PositionPlan
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Thesis Card
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Giriş Tezi", icon: "lightbulb.fill", color: .yellow)
                        
                        Text(plan.thesis)
                            .font(.body)
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Giriş Fiyatı")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", plan.originalSnapshot.entryPrice))
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Miktar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", plan.initialQuantity))
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Tarih")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(plan.originalSnapshot.capturedAt.formatted(.dateTime.day().month()))
                                    .font(.headline)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    
                    // Invalidation
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Tez Geçersizliği", icon: "xmark.circle.fill", color: .red)
                        Text(plan.invalidation)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.05))
                    )
                    
                    // Scenarios
                    let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
                    ForEach(scenarios) { scenario in
                        ScenarioCard(scenario: scenario, executedSteps: plan.executedSteps)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(plan.originalSnapshot.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

struct ScenarioCard: View {
    let scenario: Scenario
    let executedSteps: [UUID]
    
    private var scenarioColor: Color {
        switch scenario.type {
        case .bullish: return .green
        case .neutral: return .gray
        case .bearish: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(scenario.type.rawValue)
                    .font(.headline)
                    .foregroundColor(scenarioColor)
                
                Spacer()
                
                if scenario.isActive {
                    Text("AKTİF")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(scenarioColor))
                }
            }
            
            ForEach(scenario.steps.sorted(by: { $0.priority < $1.priority })) { step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(executedSteps.contains(step.id) ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                        
                        if executedSteps.contains(step.id) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.priority)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.trigger.displayText)
                            .font(.subheadline)
                            .strikethrough(executedSteps.contains(step.id))
                        
                        Text("→ \(step.action.displayText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(scenarioColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    TradeBrainView()
        .environmentObject(TradingViewModel())
}
