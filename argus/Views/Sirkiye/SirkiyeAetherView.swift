import SwiftUI

// MARK: - Sirkiye Aether View
/// Türkiye Makro Zeka Dashboard'u
/// Premium cyberpunk terminal estetiği

struct SirkiyeAetherView: View {
    @State private var macroScore: SirkiyeAetherEngine.TurkeyMacroScore = .empty
    @State private var snapshot: TCMBDataService.TCMBMacroSnapshot = .empty
    @State private var isLoading = true
    @State private var selectedComponent: SirkiyeAetherEngine.ScoreComponent?
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.large) {
                // Hero Section
                heroSection
                
                // 4 Mini Kartlar
                miniCardsGrid
                
                // Trend Grafikleri (Sparklines)
                trendSparklinesSection
                
                // Bileşen Detayları
                componentsSection
                
                // Veri Matrisi
                if !isLoading {
                    SirkiyeDataGrid(snapshot: snapshot)
                }
                
                // Insights Banner
                insightsBanner
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Sirkiye Aether")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.medium) {
            // Başlık
            HStack {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.bistAccent, Theme.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("TÜRKİYE MAKRO SKORU")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                // Yenileme Zamanı
                if !isLoading {
                    Text(macroScore.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // Büyük Gauge
            ZStack {
                // Arka Plan Halkası
                Circle()
                    .stroke(Theme.border, lineWidth: 12)
                    .frame(width: 180, height: 180)
                
                // Skor Halkası
                Circle()
                    .trim(from: 0, to: isLoading ? 0 : macroScore.overallScore / 100)
                    .stroke(
                        scoreGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: macroScore.overallScore)
                
                // Merkez İçerik
                VStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .tint(Theme.primary)
                    } else {
                        Text("\(Int(macroScore.overallScore))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreGradient)
                        
                        Text(macroScore.investmentRisk.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(riskColor)
                    }
                }
            }
            .frame(height: 200)
            
            // Risk Önerisi
            if !isLoading {
                Text(macroScore.investmentRisk.recommendation)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }
    
    // MARK: - Mini Kartlar Grid
    
    private var miniCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Theme.Spacing.medium) {
            // Para Politikası
            SirkiyeMiniCard(
                title: "Para Politikası",
                value: macroScore.monetaryStance.rawValue,
                icon: "building.columns.fill",
                color: stanceColor(macroScore.monetaryStance)
            )
            
            // Büyüme İvmesi
            SirkiyeMiniCard(
                title: "Büyüme",
                value: macroScore.growthMomentum.rawValue,
                icon: macroScore.growthMomentum.icon,
                color: momentumColor(macroScore.growthMomentum)
            )
            
            // Dış Risk
            SirkiyeMiniCard(
                title: "Dış Kırılganlık",
                value: macroScore.externalRisk.rawValue,
                icon: "globe",
                color: riskLevelColor(macroScore.externalRisk)
            )
            
            // Enflasyon Baskısı
            SirkiyeMiniCard(
                title: "Enflasyon",
                value: macroScore.inflationPressure.rawValue,
                icon: "flame.fill",
                color: pressureColor(macroScore.inflationPressure)
            )
        }
    }
    
    // MARK: - Trend Sparklines Section
    
    private var trendSparklinesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("TREND GÖSTERGELERİ (30 GÜN)")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: 12) {
                // USD/TRY
                sparklineCard(title: "USD/TRY", code: .usdTry, color: Theme.bistAccent)
                
                // BIST 100
                sparklineCard(title: "BIST 100", code: .bist100, color: Theme.positive)
                
                // Faiz (Politika)
                sparklineCard(title: "Politika Faizi", code: .policyRate, color: Theme.warning)
            }
            .frame(height: 100)
        }
        .padding()
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }
    
    private func sparklineCard(title: String, code: TCMBDataService.SerieCode, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            
            SirkiyeSparkline(serieCode: code, color: color)
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: - Bileşenler Section
    
    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("SKOR BİLEŞENLERİ")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundColor(Theme.textSecondary)
            
            ForEach(macroScore.components) { component in
                SirkiyeComponentRow(component: component)
            }
        }
        .padding()
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }
    
    // MARK: - Insights Banner
    
    private var insightsBanner: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.primary)
                
                Text("SIRKIYE INSIGHTS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            ForEach(macroScore.insights, id: \.self) { insight in
                Text(insight)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Theme.primary.opacity(0.1),
                    Theme.bistAccent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        // Parallel fetch
        async let scoreTask = SirkiyeAetherEngine.shared.analyze()
        async let snapshotTask = TCMBDataService.shared.getMacroSnapshot()
        
        macroScore = await scoreTask
        snapshot = await snapshotTask
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private var scoreGradient: LinearGradient {
        let score = macroScore.overallScore
        let colors: [Color]
        
        if score >= 70 {
            colors = [Color(hex: "00FFA3"), Color(hex: "00D9FF")]
        } else if score >= 50 {
            colors = [Color(hex: "FFD700"), Color(hex: "FFA500")]
        } else if score >= 30 {
            colors = [Color(hex: "FFA500"), Color(hex: "FF6B35")]
        } else {
            colors = [Color(hex: "FF3B3B"), Color(hex: "FF2E55")]
        }
        
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
    
    private var riskColor: Color {
        switch macroScore.investmentRisk {
        case .low: return Theme.positive
        case .moderate: return Theme.warning
        case .elevated: return .orange
        case .high: return Theme.negative
        }
    }
    
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.large)
            .fill(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
    
    private func stanceColor(_ stance: SirkiyeAetherEngine.PolicyStance) -> Color {
        switch stance {
        case .tight: return Theme.positive
        case .neutral: return Theme.warning
        case .loose: return Theme.negative
        }
    }
    
    private func momentumColor(_ momentum: SirkiyeAetherEngine.Momentum) -> Color {
        switch momentum {
        case .accelerating: return Theme.positive
        case .stable: return Theme.warning
        case .decelerating: return Theme.negative
        }
    }
    
    private func riskLevelColor(_ risk: SirkiyeAetherEngine.RiskLevel) -> Color {
        switch risk {
        case .low: return Theme.positive
        case .medium: return Theme.warning
        case .high: return .orange
        case .critical: return Theme.negative
        }
    }
    
    private func pressureColor(_ pressure: SirkiyeAetherEngine.Pressure) -> Color {
        switch pressure {
        case .low: return Theme.positive
        case .medium: return Theme.warning
        case .high: return .orange
        case .severe: return Theme.negative
        }
    }
}

// MARK: - Sirkiye Mini Card

struct SirkiyeMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Sirkiye Component Row

struct SirkiyeComponentRow: View {
    let component: SirkiyeAetherEngine.ScoreComponent
    
    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            // İkon
            Image(systemName: component.icon)
                .font(.system(size: 16))
                .foregroundColor(scoreColor)
                .frame(width: 24)
            
            // İsim ve Değer
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Text(formattedValue)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // Trend İkonu
            Image(systemName: component.trend.icon)
                .font(.caption)
                .foregroundColor(trendColor)
            
            // Skor Bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.border)
                    .frame(width: 60, height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(scoreColor)
                    .frame(width: 60 * (component.score / 100), height: 8)
            }
            
            // Skor Değeri
            Text("\(Int(component.score))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(scoreColor)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
    
    private var scoreColor: Color {
        if component.score >= 70 { return Theme.positive }
        if component.score >= 50 { return Theme.warning }
        if component.score >= 30 { return .orange }
        return Theme.negative
    }
    
    private var trendColor: Color {
        switch component.trend {
        case .up: return Theme.positive
        case .stable: return Theme.textSecondary
        case .down: return Theme.negative
        }
    }
    
    private var formattedValue: String {
        let val = component.value
        switch component.name {
        case "Enflasyon", "Reel Faiz", "Büyüme":
            return "%\(String(format: "%.1f", val))"
        case "Kur Stabilitesi":
            return "₺\(String(format: "%.2f", val))"
        case "Cari Denge":
            return "\(String(format: "%.1f", val))B$"
        case "MB Rezervleri":
            return "\(String(format: "%.0f", val))B$"
        default:
            return String(format: "%.1f", val)
        }
    }
}

// MARK: - Sirkiye Sparkline

struct SirkiyeSparkline: View {
    let serieCode: TCMBDataService.SerieCode
    let color: Color
    @State private var data: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 100
                let range = maxVal - minVal
                
                guard range > 0 else { return }
                
                let points = data.enumerated().map { index, value in
                    CGPoint(
                        x: CGFloat(index) * stepX,
                        y: geometry.size.height - (CGFloat(value - minVal) / CGFloat(range) * geometry.size.height)
                    )
                }
                
                path.addLines(points)
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .task {
            let points = await TCMBDataService.shared.getSeriesHistory(serieCode)
            // Sadece değerleri al ve normalize et
            if !points.isEmpty {
                withAnimation {
                    self.data = points.map { $0.value }
                }
            } else {
                // Mock data for preview if no API key
                self.data = (0..<30).map { _ in Double.random(in: 10...12) }
            }
        }
    }
}

// MARK: - Sirkiye Data Grid

struct SirkiyeDataGrid: View {
    let snapshot: TCMBDataService.TCMBMacroSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("MAKRO VERİ MATRİSİ")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .trailing),
                GridItem(.flexible(), alignment: .trailing)
            ], spacing: 12) {
                // Header
                Group {
                    Text("GÖSTERGE").font(.caption2).foregroundColor(.gray)
                    Text("DEĞER").font(.caption2).foregroundColor(.gray)
                    Text("TREND").font(.caption2).foregroundColor(.gray)
                }
                
                Divider()
                Divider()
                Divider()
                
                // Rows
                gridRow(name: "Enflasyon", value: snapshot.inflation, format: "%.1f%%", trend: .down) // Trend logic basitleştirildi
                gridRow(name: "Politika Faizi", value: snapshot.policyRate, format: "%.0f%%", trend: .up)
                gridRow(name: "USD/TRY", value: snapshot.usdTry, format: "%.2f₺", trend: .up)
                gridRow(name: "CDS Risk", value: 280, format: "%.0f", trend: .stable) // Mock CDS
                gridRow(name: "Rezervler", value: snapshot.reserves, format: "%.1fB$", trend: .up)
                gridRow(name: "Cari Denge", value: snapshot.currentAccount, format: "%.1fB$", trend: .down)
                gridRow(name: "Sanayi Üretimi", value: snapshot.industrialProduction, format: "%.1f", trend: .stable)
                gridRow(name: "İşsizlik", value: snapshot.unemployment, format: "%.1f%%", trend: .stable)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
    
    private func gridRow(name: String, value: Double?, format: String, trend: SirkiyeAetherEngine.Trend) -> some View {
        Group {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            
            Text(value != nil ? String(format: format, value!) : "-")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            
            Image(systemName: trend.icon)
                .font(.caption)
                .foregroundColor(trend == .up ? Theme.positive : (trend == .down ? Theme.negative : .gray))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SirkiyeAetherView()
    }
}
