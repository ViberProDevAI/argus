import SwiftUI

// MARK: - Aether v5 Educational Detail View
struct ArgusAetherDetailView: View {
    let rating: MacroEnvironmentRating
    @Environment(\.presentationMode) var presentationMode
    @State private var expandedCategory: IndicatorCategory? = nil
    @State private var showExpectationsSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Main Score Header
                        MainScoreHeader(rating: rating)
                        
                        // 2. Educational Intro
                        EducationalIntroCard()
                        
                        // 3. Category Sections
                        CategorySection(
                            category: .leading,
                            score: rating.leadingScore ?? 50,
                            indicators: leadingIndicators,
                            isExpanded: expandedCategory == .leading,
                            onToggle: { toggleCategory(.leading) }
                        )
                        
                        CategorySection(
                            category: .coincident,
                            score: rating.coincidentScore ?? 50,
                            indicators: coincidentIndicators,
                            isExpanded: expandedCategory == .coincident,
                            onToggle: { toggleCategory(.coincident) }
                        )
                        
                        CategorySection(
                            category: .lagging,
                            score: rating.laggingScore ?? 50,
                            indicators: laggingIndicators,
                            isExpanded: expandedCategory == .lagging,
                            onToggle: { toggleCategory(.lagging) }
                        )
                        
                        // 4. Council Math Card
                        CouncilMathCard(rating: rating)
                        
                        // 5. Final Verdict
                        VerdictCard(rating: rating)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showExpectationsSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Beklenti")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showExpectationsSheet) {
                ExpectationsEntryView()
            }
        }
    }
    
    // MARK: - Toggle Logic
    private func toggleCategory(_ cat: IndicatorCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedCategory == cat {
                expandedCategory = nil
            } else {
                expandedCategory = cat
            }
        }
    }
    
    // MARK: - Indicator Data
    private var leadingIndicators: [IndicatorItem] {
        [
            IndicatorItem(
                key: "vix", icon: "waveform.path.ecg", title: "VIX (Korku Endeksi)",
                score: rating.volatilityScore ?? 50,
                value: nil, change: rating.componentChanges["volatility"],
                isInverse: true,
                explanation: "VIX, piyasadaki beklenen volatiliteyi ölçer. Düşük VIX (15 altı) yatırımcıların rahat olduğunu, yüksek VIX (30+) panik olduğunu gösterir.",
                interpretation: vixInterpretation
            ),
            IndicatorItem(
                key: "rates", icon: "percent", title: "Yield Curve (10Y-2Y)",
                score: rating.interestRateScore ?? 50,
                value: nil, change: nil,
                isInverse: false,
                explanation: "Verim eğrisi, kısa ve uzun vadeli faizler arasındaki farkı gösterir. Pozitif eğri sağlıklı ekonomi, ters eğri (negatif) resesyon habercisidir.",
                interpretation: yieldInterpretation
            ),
            IndicatorItem(
                key: "claims", icon: "person.badge.minus", title: "İşsizlik Başvuruları (ICSA)",
                score: rating.claimsScore ?? 50,
                value: nil, change: nil,
                isInverse: true,
                explanation: "Haftalık işsizlik maaşı başvuruları. Düşen başvurular güçlü iş piyasası, yükselen başvurular zayıflama sinyali verir.",
                interpretation: claimsInterpretation
            ),
            IndicatorItem(
                key: "btc", icon: "bitcoinsign.circle.fill", title: "Bitcoin (Risk İştahı)",
                score: rating.cryptoRiskScore ?? 50,
                value: nil, change: rating.componentChanges["crypto"],
                isInverse: false,
                explanation: "Bitcoin, spekülatif risk iştahının en net göstergesidir. Yükselen BTC genellikle piyasada risk alma iştahı olduğunu gösterir.",
                interpretation: btcInterpretation
            )
        ]
    }
    
    private var coincidentIndicators: [IndicatorItem] {
        [
            IndicatorItem(
                key: "trend", icon: "chart.line.uptrend.xyaxis", title: "S&P 500 Trendi (SPY)",
                score: rating.equityRiskScore ?? 50,
                value: nil, change: rating.componentChanges["equity"],
                isInverse: false,
                explanation: "SPY ETF'in 50 günlük hareketli ortalamaya göre konumu. Fiyat ortalamanın üstündeyse boğa piyasası, altındaysa ayı piyasası.",
                interpretation: spyInterpretation
            ),
            IndicatorItem(
                key: "growth", icon: "person.3.fill", title: "İstihdam (Payrolls)",
                score: rating.growthScore ?? 50,
                value: nil, change: nil,
                isInverse: false,
                explanation: "Aylık tarım dışı istihdam değişimi. Pozitif büyüme ekonomik genişleme, negatif büyüme daralma işaretidir.",
                interpretation: jobsInterpretation
            ),
            IndicatorItem(
                key: "dxy", icon: "dollarsign.circle.fill", title: "Dolar Endeksi (DXY)",
                score: rating.currencyScore ?? 50,
                value: nil, change: rating.componentChanges["dollar"],
                isInverse: true,
                explanation: "ABD Dolarının diğer para birimlerine karşı gücü. Güçlü dolar riskli varlıklar (hisse, kripto) üzerinde baskı yaratır.",
                interpretation: dxyInterpretation
            )
        ]
    }
    
    private var laggingIndicators: [IndicatorItem] {
        [
            IndicatorItem(
                key: "cpi", icon: "cart.fill", title: "Enflasyon (CPI)",
                score: rating.inflationScore ?? 50,
                value: nil, change: nil,
                isInverse: true,
                explanation: "Tüketici Fiyat Endeksi yıllık değişimi. Fed'in hedefi %2. Yüksek enflasyon faiz artışı ve piyasa baskısı demektir.",
                interpretation: cpiInterpretation
            ),
            IndicatorItem(
                key: "labor", icon: "person.crop.circle.badge.xmark", title: "İşsizlik Oranı",
                score: rating.laborScore ?? 50,
                value: nil, change: nil,
                isInverse: true,
                explanation: "Çalışmak isteyip iş bulamayanların oranı. %4 altı tam istihdam, %6+ ekonomik sorun işareti.",
                interpretation: laborInterpretation
            ),
            IndicatorItem(
                key: "gld", icon: "circle.hexagongrid.fill", title: "Altın (GLD)",
                score: rating.safeHavenScore ?? 50,
                value: nil, change: rating.componentChanges["gold"],
                isInverse: true,
                explanation: "Altın güvenli liman varlığıdır. Yükselen altın yatırımcıların riskten kaçtığını, düşen altın risk iştahı olduğunu gösterir.",
                interpretation: goldInterpretation
            )
        ]
    }
    
    // MARK: - Interpretations
    private var vixInterpretation: String {
        let s = rating.volatilityScore ?? 50
        if s >= 70 { return "✅ VIX düşük, piyasa sakin. Risk almak için uygun ortam." }
        if s >= 50 { return "⚠️ VIX normal seviyelerde. Dikkatli ol." }
        return " VIX yüksek, panik havası var. Riskli pozisyonlardan uzak dur."
    }
    
    private var yieldInterpretation: String {
        let s = rating.interestRateScore ?? 50
        if s >= 70 { return "✅ Verim eğrisi pozitif. Ekonomi sağlıklı görünüyor." }
        if s >= 50 { return "⚠️ Verim eğrisi düzleşiyor. Dikkatli ol." }
        return " Verim eğrisi ters! Tarihsel olarak resesyon habercisi."
    }
    
    private var claimsInterpretation: String {
        let s = rating.claimsScore ?? 50
        if s >= 70 { return "✅ Başvurular düşüyor. İş piyasası güçlü." }
        if s >= 50 { return "⚠️ Başvurular stabil. Normal seyir." }
        return " Başvurular artıyor. İş piyasası zayıflıyor olabilir."
    }
    
    private var btcInterpretation: String {
        let s = rating.cryptoRiskScore ?? 50
        if s >= 70 { return "✅ BTC yükselişte. Risk iştahı yüksek." }
        if s >= 50 { return "⚠️ BTC nötr. Piyasa kararsız." }
        return " BTC düşüşte. Risk iştahı düşük, dikkatli ol."
    }
    
    private var spyInterpretation: String {
        let s = rating.equityRiskScore ?? 50
        if s >= 70 { return "✅ SPY trend yukarı. Boğa piyasası devam ediyor." }
        if s >= 50 { return "⚠️ SPY kararsız. Trend belirsiz." }
        return " SPY trend aşağı. Ayı piyasası sinyalleri var."
    }
    
    private var jobsInterpretation: String {
        let s = rating.growthScore ?? 50
        if s >= 70 { return "✅ İstihdam artıyor. Ekonomi genişliyor." }
        if s >= 50 { return "⚠️ İstihdam stabil. Normal seyir." }
        return " İstihdam azalıyor. Ekonomik daralma riski."
    }
    
    private var dxyInterpretation: String {
        let s = rating.currencyScore ?? 50
        if s >= 70 { return "✅ Dolar zayıf. Riskli varlıklar için olumlu." }
        if s >= 50 { return "⚠️ Dolar nötr. Normal seyir." }
        return " Dolar güçlü. Hisseler üzerinde baskı olabilir."
    }
    
    private var cpiInterpretation: String {
        let s = rating.inflationScore ?? 50
        if s >= 70 { return "✅ Enflasyon kontrol altında. Fed rahat." }
        if s >= 50 { return "⚠️ Enflasyon yüksek ama düşüyor." }
        return " Enflasyon çok yüksek! Fed agresif olabilir."
    }
    
    private var laborInterpretation: String {
        let s = rating.laborScore ?? 50
        if s >= 70 { return "✅ İşsizlik düşük. Tam istihdam." }
        if s >= 50 { return "⚠️ İşsizlik normal seviyelerde." }
        return " İşsizlik yükseliyor. Ekonomik sorun işareti."
    }
    
    private var goldInterpretation: String {
        let s = rating.safeHavenScore ?? 50
        if s >= 70 { return "✅ Altın zayıf. Yatırımcılar risk alıyor." }
        if s >= 50 { return "⚠️ Altın nötr. Karışık sinyaller." }
        return " Altın güçlü. Yatırımcılar güvenli limana kaçıyor."
    }
}

// MARK: - Indicator Category
enum IndicatorCategory {
    case leading, coincident, lagging
    
    var title: String {
        switch self {
        case .leading: return " ÖNCÜ GÖSTERGELER"
        case .coincident: return " EŞZAMANLI GÖSTERGELER"
        case .lagging: return " GECİKMELİ GÖSTERGELER"
        }
    }
    
    var weight: String {
        switch self {
        case .leading: return "x1.5 Ağırlık"
        case .coincident: return "x1.0 Ağırlık"
        case .lagging: return "x0.8 Ağırlık"
        }
    }
    
    var color: Color {
        switch self {
        case .leading: return .green
        case .coincident: return .yellow
        case .lagging: return .red
        }
    }
    
    var description: String {
        switch self {
        case .leading: return "Bu göstergeler ekonomiyi 3-6 ay önceden tahmin eder. En yüksek ağırlığa sahiptirler çünkü geleceği gösterirler."
        case .coincident: return "Bu göstergeler ekonominin şu anki durumunu gösterir. Gerçek zamanlı ekonomik sağlığı yansıtırlar."
        case .lagging: return "Bu göstergeler ekonomiyi geriden takip eder. Trendleri onaylarlar ama tahmin güçleri düşüktür."
        }
    }
}

// MARK: - Indicator Item
struct IndicatorItem: Identifiable {
    let id = UUID()
    let key: String
    let icon: String
    let title: String
    let score: Double
    let value: String?
    let change: Double?
    let isInverse: Bool
    let explanation: String
    let interpretation: String
}

// MARK: - Main Score Header (Compact)
struct MainScoreHeader: View {
    let rating: MacroEnvironmentRating
    
    var body: some View {
        HStack(spacing: 16) {
            // Compact Score Circle
            ZStack {
                Circle()
                    .stroke(scoreGradient[0].opacity(0.3), lineWidth: 4)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: rating.numericScore / 100)
                    .stroke(scoreGradient[0], style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(rating.numericScore))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(scoreGradient[0])
            }
            
            // Info + Categories
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text("AETHER v5")
                        .font(.caption)
                        .bold()
                        .tracking(1)
                        .foregroundColor(.cyan)
                    Spacer()
                    Text(rating.regime.rawValue)
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(regimeColor.opacity(0.2))
                        .foregroundColor(regimeColor)
                        .clipShape(Capsule())
                }
                
                // Mini Category Pills
                HStack(spacing: 6) {
                    MiniCatPill(emoji: "", label: "Öncü", score: rating.leadingScore ?? 50)
                    MiniCatPill(emoji: "", label: "Eşzamanlı", score: rating.coincidentScore ?? 50)
                    MiniCatPill(emoji: "", label: "Gecikmeli", score: rating.laggingScore ?? 50)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(scoreGradient[0].opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var regimeColor: Color {
        switch rating.regime {
        case .riskOn: return .green
        case .neutral: return .yellow
        case .riskOff: return .red
        }
    }
    
    private var scoreGradient: [Color] {
        let score = rating.numericScore
        if score >= 70 { return [.green, .mint] }
        if score >= 50 { return [.yellow, .orange] }
        return [.red, .pink]
    }
}

// Mini Category Pill for Header
struct MiniCatPill: View {
    let emoji: String
    let label: String
    let score: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 8))
            Text("\(Int(score))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(scoreColor.opacity(DesignTokens.Opacity.glassCard))
        .clipShape(Capsule())
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Category Score Row
struct CategoryScoreRow: View {
    let category: IndicatorCategory
    let score: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Text(category == .leading ? "" : category == .coincident ? "" : "")
                .font(.system(size: 14))
            
            Text(category == .leading ? "Öncü" : category == .coincident ? "Eşzamanlı" : "Gecikmeli")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 65, alignment: .leading)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.border.opacity(0.3))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(category.color)
                        .frame(width: geo.size.width * (score / 100))
                }
            }
            .frame(width: 60, height: 6)
            
            Text("\(Int(score))")
                .font(.caption)
                .bold()
                .foregroundColor(category.color)
                .frame(width: 25, alignment: .trailing)
            
            Text(category.weight)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
    }
}

// MARK: - Educational Intro Card
struct EducationalIntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.cyan)
                Text("Nasıl Çalışır?")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text("Aether, ekonomik göstergeleri 3 kategoride analiz eder:")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                    Text("**Öncü göstergeler** ekonomiyi 3-6 ay önceden tahmin eder (VIX, Verim Eğrisi, İşsizlik Başvuruları)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                    Text("**Eşzamanlı göstergeler** ekonominin şu anki durumunu gösterir (SPY, İstihdam, Dolar)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                    Text("**Gecikmeli göstergeler** trendleri onaylar ama geç bilgi verir (CPI, İşsizlik Oranı, Altın)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

// MARK: - Category Section
struct CategorySection: View {
    let category: IndicatorCategory
    let score: Double
    let indicators: [IndicatorItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (Tappable)
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                        Text(category.weight)
                            .font(.caption2)
                            .foregroundColor(category.color)
                    }
                    
                    Spacer()
                    
                    // Score Badge
                    Text("\(Int(score))")
                        .font(.title3)
                        .bold()
                        .foregroundColor(scoreColor)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(category.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Description
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    
                    // Indicators
                    ForEach(indicators) { indicator in
                        IndicatorDetailRow(indicator: indicator)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Indicator Detail Row
struct IndicatorDetailRow: View {
    let indicator: IndicatorItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Row
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: indicator.icon)
                            .font(.system(size: 16))
                            .foregroundColor(scoreColor)
                    }
                    
                    // Title & Change
                    VStack(alignment: .leading, spacing: 2) {
                        Text(indicator.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        
                        if let change = indicator.change {
                            let isGood = (change >= 0) != indicator.isInverse
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text("\(change >= 0 ? "+" : "")\(String(format: "%.2f", change))%")
                                    .font(.caption)
                                    .bold()
                            }
                            .foregroundColor(isGood ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    // Score
                    Text("\(Int(indicator.score))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(scoreColor)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
                .padding(12)
                .background(Theme.secondaryBackground)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Explanation
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // What is it?
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Ne Anlama Geliyor?")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                        }
                        Text(indicator.explanation)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // Current Interpretation
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Güncel Yorumu")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                        }
                        Text(indicator.interpretation)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(12)
                .background(Theme.background)
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var scoreColor: Color {
        if indicator.score >= 70 { return .green }
        if indicator.score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Verdict Card
struct VerdictCard: View {
    let rating: MacroEnvironmentRating
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(verdictColor)
                Text("Final Değerlendirme")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text(verdictText)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            // Action Hint
            HStack {
                Image(systemName: verdictIcon)
                    .foregroundColor(verdictColor)
                Text(verdictAction)
                    .font(.caption)
                    .bold()
                    .foregroundColor(verdictColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(verdictColor.opacity(DesignTokens.Opacity.glassCard))
            .cornerRadius(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(verdictColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var verdictColor: Color {
        switch rating.regime {
        case .riskOn: return .green
        case .neutral: return .yellow
        case .riskOff: return .red
        }
    }
    
    private var verdictIcon: String {
        switch rating.regime {
        case .riskOn: return "arrow.up.right.circle.fill"
        case .neutral: return "pause.circle.fill"
        case .riskOff: return "arrow.down.right.circle.fill"
        }
    }
    
    private var verdictText: String {
        let score = rating.numericScore
        if score >= 70 {
            return "Makro ortam oldukça olumlu. Öncü göstergeler iyimser, risk iştahı yüksek. Uzun pozisyonlar için uygun ortam."
        } else if score >= 50 {
            return "Makro ortam karışık sinyaller veriyor. Bazı göstergeler olumlu, bazıları olumsuz. Seçici olmak önemli."
        } else {
            return "Makro ortam olumsuz. Öncü göstergeler uyarı veriyor. Riskli pozisyonlardan kaçınmak veya hedge düşünmek mantıklı."
        }
    }
    
    private var verdictAction: String {
        switch rating.regime {
        case .riskOn: return "RİSK AL - Uzun pozisyonlar için uygun"
        case .neutral: return "DİKKATLİ OL - Seçici yaklaşım"
        case .riskOff: return "RİSKTEN KAÇIN - Savunmacı ol"
        }
    }
}

// MARK: - Council Math Card
struct CouncilMathCard: View {
    let rating: MacroEnvironmentRating
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.cyan)
                Text("Skor Hesaplaması")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Formula Visualization
            VStack(alignment: .leading, spacing: 8) {
                Text("Ağırlıklı Ortalama Formülü:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                // Formula
                HStack(spacing: 4) {
                    Text("Skor = ")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Text("(Öncü×1.5) + (Eşzamanlı×1.0) + (Gecikmeli×0.8)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        Rectangle()
                            .fill(Theme.textSecondary)
                            .frame(height: 1)
                        Text("3.3 (Toplam Ağırlık)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(8)
                .background(Theme.background)
                .cornerRadius(8)
            }
            
            Divider().background(Theme.border)
            
            // Calculation Breakdown
            VStack(alignment: .leading, spacing: 6) {
                Text("Bu Anın Hesabı:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                
                MathRow(emoji: "", label: "Öncü", value: rating.leadingScore ?? 50, weight: 1.5)
                MathRow(emoji: "", label: "Eşzamanlı", value: rating.coincidentScore ?? 50, weight: 1.0)
                MathRow(emoji: "", label: "Gecikmeli", value: rating.laggingScore ?? 50, weight: 0.8)
                
                Divider().background(Theme.border)
                
                // Result
                let leading = (rating.leadingScore ?? 50) * 1.5
                let coincident = (rating.coincidentScore ?? 50) * 1.0
                let lagging = (rating.laggingScore ?? 50) * 0.8
                let total = (leading + coincident + lagging) / 3.3
                
                HStack {
                    Text("= (\(Int(leading)) + \(Int(coincident)) + \(Int(lagging))) / 3.3")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("= \(Int(total))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(scoreColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var scoreColor: Color {
        let score = rating.numericScore
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// Math Row for calculation - Shows contribution to final score
struct MathRow: View {
    let emoji: String
    let label: String
    let value: Double
    let weight: Double
    
    // Weighted value and contribution to total (assuming 3.3 total weight)
    private var weighted: Double { value * weight }
    private var contribution: Double { weighted / 3.3 }  // How much this adds to final score
    
    var body: some View {
        HStack {
            Text(emoji)
                .font(.system(size: 10))
            Text("\(label):")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 65, alignment: .leading)
            
            // Raw score with color based on score value
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(scoreColor)
                .frame(width: 30, alignment: .trailing)
            
            Text("→")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            
            // Contribution to final score
            Text("+\(String(format: "%.1f", contribution))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(contributionColor)
                .frame(width: 45, alignment: .trailing)
            
            Text("puan")
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    // Color based on RAW SCORE, not weighted value
    private var scoreColor: Color {
        if value >= 70 { return .green }
        if value >= 50 { return .yellow }
        return .red
    }
    
    // Contribution color - higher contribution = brighter
    private var contributionColor: Color {
        if contribution >= 25 { return .green }
        if contribution >= 15 { return .yellow }
        return .orange
    }
}
