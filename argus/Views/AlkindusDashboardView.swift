import SwiftUI

struct AlkindusDashboardView: View {
    // 2026-04-23 V5.H-6: Hisse chip'inden açılınca bağlam için opsiyonel
    // symbol parametresi. Nil ise global dashboard aynen çalışır.
    var symbol: String? = nil

    @State private var stats: AlkindusStats?
    @State private var isLoading = true
    @State private var showDrawer = false
    @State private var symbolInsight: SymbolInsight?
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalToProcess = 0
    @State private var processingResult: ProcessingResult?
    @State private var dbSizeMB: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "Alkindus",
                subtitle: "Argus'un öğrenme paneli",
                actions: [
                    .menu({ showDrawer = true }),
                    .custom(sfSymbol: "arrow.clockwise", action: refresh)
                ]
            )
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(InstitutionalTheme.Colors.primary)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 24) {
                            if let sym = symbol {
                                symbolInsightCard(for: sym)
                            }
                            headerCard(stats: stats)
                            insightsSection
                            dataToolsSection
                            correlationsSection
                            moduleCalibrationSection(stats: stats)
                            regimeInsightsSection(stats: stats)
                            AlkindusTimeCard()
                            marketComparisonSection
                            pendingSection(stats: stats)
                            Spacer(minLength: 50)
                        }
                        .padding()
                    }
                } else {
                    emptyState
                }

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(200)
                }
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await loadStats()
            if let sym = symbol {
                self.symbolInsight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: sym)
            }
        }
    }

    // MARK: - Hisse bağlamı kartı (V5.H-6)

    /// Hisse chip'inden Alkindus açılınca en üstte "Bu hisse için Alkindus
    /// okuması" kartı. `SymbolInsight` nil dönerse (yeterli karar birikmemiş)
    /// bilgilendirici bir boş hal gösterilir, global dashboard altta devam eder.
    @ViewBuilder
    private func symbolInsightCard(for sym: String) -> some View {
        // 2026-04-30 H-44 — sade. Mor border + caps başlık + sembol pill kalktı,
        // yerine sade kart + sentence case başlık + sembol muted text.
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bu hisse için okumam")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                Text(sym)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            if let insight = symbolInsight {
                Text(insight.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    insightRow(label: "En iyi modül",
                               value: "\(displayName(for: insight.bestModule)) · \(Int(insight.bestHitRate * 100))%",
                               valueColor: InstitutionalTheme.Colors.aurora)
                    insightRow(label: "En zayıf modül",
                               value: "\(displayName(for: insight.worstModule)) · \(Int(insight.worstHitRate * 100))%",
                               valueColor: InstitutionalTheme.Colors.crimson)
                    insightRow(label: "Toplam karar",
                               value: "\(insight.totalDecisions) adet",
                               valueColor: InstitutionalTheme.Colors.textPrimary)
                }
            } else {
                Text("Bu hisse için henüz yeterli karar birikmedi (en az 5 karar gerekiyor). Kararlar verildikçe burası dolacak.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func insightRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
    }

    /// Motor adından kullanıcıya gösterilecek işlev karşılığı.
    /// (drawer ve sanctum'la aynı dil — Orion → Teknik, Hermes → Haber, …)
    private func displayName(for moduleName: String) -> String {
        switch moduleName.lowercased() {
        case "orion":      return "Teknik"
        case "atlas":      return "Bilanço"
        case "aether":     return "Makro"
        case "hermes":     return "Haber"
        case "demeter":    return "Sektör"
        case "chiron":     return "Rejim"
        case "prometheus": return "Tahmin"
        case "athena":     return "Faktör"
        case "alkindus":   return "Alkindus"
        case "phoenix":    return "Risk"
        default:           return moduleName.capitalized
        }
    }
    
    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        var sections: [ArgusDrawerView.DrawerSection] = []
        
        sections.append(
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Sinyal akisi", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Piyasalar", subtitle: "Market ekranı", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
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
                title: "Alkindus",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Yenile", subtitle: "Istatistikleri guncelle", icon: "arrow.clockwise") {
                        refresh()
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Sistem Rehberi", subtitle: "Argus isleyisi", icon: "doc.text") {
                        openSheet(.systemGuide)
                    },
                    ArgusDrawerView.DrawerItem(title: "Alkindus Rehberi", subtitle: "Motor aciklamasi", icon: "book") {
                        openSheet(.alkindusGuide)
                    }
                ]
            )
        )
        
        sections.append(commonToolsSection(openSheet: openSheet))
        
        return sections
    }
    
    private func commonToolsSection(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> ArgusDrawerView.DrawerSection {
        ArgusDrawerView.DrawerSection(
            title: "Araçlar",
            items: [
                ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Gercek takvim", icon: "calendar") {
                    openSheet(.calendar)
                },
                ArgusDrawerView.DrawerItem(title: "Finans Sozlugu", subtitle: "Terimler", icon: "character.book.closed") {
                    openSheet(.dictionary)
                },
                ArgusDrawerView.DrawerItem(title: "Unlu Finans Sozleri", subtitle: "Finans alintilari", icon: "quote.opening") {
                    openSheet(.financeWisdom)
                },
                ArgusDrawerView.DrawerItem(title: "Sistem Durumu", subtitle: "Servis sagligi", icon: "waveform.path.ecg") {
                    openSheet(.systemHealth)
                },
                ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                    openSheet(.feedback)
                }
            ]
        )
    }
    
    private func headerCard(stats: AlkindusStats) -> some View {
        // 2026-04-30 H-44 — sade. ArgusOrb glow + ringColor + caps brand
        // satırı + SHADOW MODE pill + mini stat caps + tinted yüzde badge
        // hepsi gitti. Yerine küçük dairesel logo + "Kalibrasyon" sentence
        // + alt satır muted, mini stat'lar sentence case + büyük metin +
        // renkli yüzde (renk anlamı korundu).
        v5Card {
            HStack(spacing: 12) {
                MotorLogo(.alkindus, size: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Kalibrasyon")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("Shadow mode · \(stats.pendingCount) bekleyen karar")
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }

                Spacer()
            }

            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)

            HStack(spacing: 14) {
                if let top = stats.topModule {
                    miniStat(title: "En iyi modül",
                             value: displayName(for: top.name),
                             rate: top.hitRate,
                             color: InstitutionalTheme.Colors.aurora)
                }

                if let weak = stats.weakestModule {
                    miniStat(title: "En zayıf",
                             value: displayName(for: weak.name),
                             rate: weak.hitRate,
                             color: InstitutionalTheme.Colors.crimson)
                }
            }
        }
    }

    // MARK: - V5 card chrome

    @ViewBuilder
    private func v5Card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func miniStat(title: String, value: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(Int(rate * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sade bölüm başlığı — sentence case + sağda muted trailing.
    @ViewBuilder
    private func sectionTitle(_ text: String, trailing: String? = nil) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
    }
    
    private func moduleCalibrationSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Modül kalibrasyonu",
                         trailing: stats.calibration.modules.isEmpty
                            ? nil
                            : "\(stats.calibration.modules.count) modül")

            if stats.calibration.modules.isEmpty {
                Text("Henüz veri yok. Kararlar verildikçe burası dolacak.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(stats.calibration.modules.sorted(by: { $0.key < $1.key }), id: \.key) { module, cal in
                        moduleCard(name: module, calibration: cal)
                    }
                }
            }
        }
    }

    private func moduleCard(name: String, calibration: ModuleCalibration) -> some View {
        v5Card {
            HStack(spacing: 10) {
                Text(displayName(for: name))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                let totalAttempts = calibration.brackets.values.reduce(0) { $0 + $1.attempts }
                Text("\(totalAttempts) deneme")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(calibration.brackets.sorted(by: { $0.key > $1.key }), id: \.key) { bracket, bstats in
                    HStack(spacing: 10) {
                        Text(bracket)
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .frame(width: 56, alignment: .leading)

                        ArgusBar(value: bstats.hitRate,
                                 color: colorForHitRate(bstats.hitRate),
                                 height: 4)

                        Text("\(Int(bstats.hitRate * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(colorForHitRate(bstats.hitRate))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)

                        Text("\(bstats.attempts)")
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func motorFromName(_ name: String) -> MotorEngine? {
        switch name.lowercased() {
        case "orion":      return .orion
        case "atlas":      return .atlas
        case "aether":     return .aether
        case "hermes":     return .hermes
        case "athena":     return .athena
        case "demeter":    return .demeter
        case "chiron":     return .chiron
        case "prometheus": return .prometheus
        case "alkindus":   return .alkindus
        default:           return nil
        }
    }

    private func colorForHitRate(_ rate: Double) -> Color {
        if rate >= 0.6 { return InstitutionalTheme.Colors.aurora }
        if rate >= 0.45 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }
    
    private func regimeInsightsSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Rejim bazlı performans",
                         trailing: stats.calibration.regimes.isEmpty
                            ? nil
                            : "\(stats.calibration.regimes.count) rejim")

            if stats.calibration.regimes.isEmpty {
                Text("Rejim verisi henüz yok.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(stats.calibration.regimes.sorted(by: { $0.key < $1.key }), id: \.key) { regime, insight in
                        regimeCard(regime: regime, insight: insight)
                    }
                }
            }
        }
    }

    private func regimeCard(regime: String, insight: RegimeInsight) -> some View {
        v5Card {
            HStack {
                Circle()
                    .fill(regimeColor(regime))
                    .frame(width: 6, height: 6)
                Text(regime.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text("\(insight.moduleAttempts.count) modül")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(insight.moduleAttempts.sorted(by: { $0.key < $1.key }), id: \.key) { module, _ in
                    let rate = insight.hitRate(for: module)
                    HStack(spacing: 10) {
                        Text(displayName(for: module))
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        ArgusBar(value: rate, color: colorForHitRate(rate), height: 4)
                        Text("\(Int(rate * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(colorForHitRate(rate))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Rejim adına göre nokta rengi (sade — pill tone değil).
    private func regimeColor(_ regime: String) -> Color {
        let r = regime.lowercased()
        if r.contains("bull") || r.contains("trend") || r.contains("yüksel") {
            return InstitutionalTheme.Colors.aurora
        }
        if r.contains("bear") || r.contains("düş") || r.contains("risk") || r.contains("crash") {
            return InstitutionalTheme.Colors.crimson
        }
        return InstitutionalTheme.Colors.textSecondary
    }

    private func pendingSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Bekleyen gözlemler")
            v5Card {
                HStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 16))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stats.pendingCount) karar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("Olgunlaşma bekleniyor")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
            }
        }
    }

    @State private var insights: [AlkindusInsightGenerator.Insight] = []

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bugün öğrendiklerim")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Button(action: refreshInsights) {
                    Text("Yenile")
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.holo)
                }
                .buttonStyle(.plain)
            }

            if insights.isEmpty {
                Text("Henüz günlük içgörü yok. 'Eventlerden öğren' butonuna bas.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(insights.prefix(5)) { insight in
                        insightCard(insight: insight)
                    }
                }
            }
        }
    }

    private func insightCard(insight: AlkindusInsightGenerator.Insight) -> some View {
        let accent = importanceColor(insight.importance)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForCategory(insight.category))
                .font(.system(size: 14))
                .foregroundColor(accent)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    Text(categoryLabel(insight.category))
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Text(insight.detail)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func iconForCategory(_ category: AlkindusInsightGenerator.InsightCategory) -> String {
        switch category {
        case .correlation: return "link"
        case .anomaly:     return "exclamationmark.triangle"
        case .trend:       return "chart.line.uptrend.xyaxis"
        case .performance: return "chart.bar"
        case .regime:      return "waveform"
        case .warning:     return "exclamationmark.circle"
        case .discovery:   return "sparkle"
        }
    }

    private func categoryLabel(_ category: AlkindusInsightGenerator.InsightCategory) -> String {
        switch category {
        case .correlation: return "Korelasyon"
        case .anomaly:     return "Anomali"
        case .trend:       return "Trend"
        case .performance: return "Performans"
        case .regime:      return "Rejim"
        case .warning:     return "Uyarı"
        case .discovery:   return "Keşif"
        }
    }

    private func importanceColor(_ importance: AlkindusInsightGenerator.InsightImportance) -> Color {
        switch importance {
        case .critical: return InstitutionalTheme.Colors.crimson
        case .high:     return InstitutionalTheme.Colors.titan
        case .medium:   return InstitutionalTheme.Colors.holo
        case .low:      return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    @State private var topCorrelations: [(key: String, hitRate: Double, attempts: Int)] = []
    
    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("En başarılı kombinasyonlar",
                         trailing: topCorrelations.isEmpty
                            ? nil
                            : "İlk \(topCorrelations.count)")

            if topCorrelations.isEmpty {
                Text("Henüz korelasyon verisi yok.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topCorrelations.enumerated()), id: \.offset) { idx, corr in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .monospacedDigit()
                                .frame(width: 20, alignment: .leading)
                            Text(formatCorrelationKey(corr.key))
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(corr.hitRate * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colorForHitRate(corr.hitRate))
                                .monospacedDigit()
                            Text("\(corr.attempts)")
                                .font(.system(size: 11))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if idx < topCorrelations.count - 1 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(InstitutionalTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func formatCorrelationKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "80+", with: "↑")
            .replacingOccurrences(of: "60+", with: "→")
            .capitalized
    }
    
    @State private var marketComparison: (bist: Double, global: Double)?
    
    private var marketComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pazar karşılaştırması")

            if let comparison = marketComparison {
                v5Card {
                    HStack(spacing: 14) {
                        marketOrb(title: "BIST", rate: comparison.bist)
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(width: 0.5, height: 48)
                        marketOrb(title: "Global", rate: comparison.global)
                    }
                }
            } else {
                Text("Henüz BIST / Global karşılaştırma verisi yok.")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            }
        }
        .task {
            marketComparison = await AlkindusSymbolLearner.shared.getMarketComparison()
        }
    }

    private func marketOrb(title: String, rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("\(Int(rate * 100))%")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(colorForHitRate(rate))
                .monospacedDigit()
            ArgusBar(value: rate, color: colorForHitRate(rate), height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dataToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Veri araçları")

            v5Card {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 14))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Veritabanı boyutu")
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f MB", dbSizeMB))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(dbSizeMB > 100
                                         ? InstitutionalTheme.Colors.crimson
                                         : InstitutionalTheme.Colors.textPrimary)
                        .monospacedDigit()
                }

                if isProcessing {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.7)
                            Text("İşleniyor · \(processedCount)/\(totalToProcess)")
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .monospacedDigit()
                        }
                        let progress = totalToProcess > 0
                            ? Double(processedCount) / Double(totalToProcess)
                            : 0
                        ArgusBar(value: min(max(progress, 0), 1),
                                 color: InstitutionalTheme.Colors.holo,
                                 height: 4)
                    }
                }

                if let result = processingResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.eventsProcessed) olay · \(result.patternsExtracted) örüntü")
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.aurora)
                        if !result.modulesLearned.isEmpty {
                            Text("Öğrenilen: \(result.modulesLearned.map { displayName(for: $0) }.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                    }
                }

                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 0.5)

                HStack(spacing: 8) {
                    v5ActionButton(label: "Eventlerden öğren",
                                   sfSymbol: "sparkles",
                                   accent: InstitutionalTheme.Colors.holo,
                                   disabled: isProcessing,
                                   action: processEvents)

                    v5ActionButton(label: "Blob temizle",
                                   sfSymbol: "trash",
                                   accent: InstitutionalTheme.Colors.crimson,
                                   disabled: isProcessing,
                                   action: cleanupBlobs)
                }
            }
        }
    }

    /// Sade aksiyon butonu — outline + sentence case label + ikon.
    private func v5ActionButton(label: String,
                                sfSymbol: String,
                                accent: Color,
                                disabled: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(accent)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(InstitutionalTheme.Colors.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            AlkindusAvatarView(size: 40, isThinking: true, hasIdea: false)
                .font(.system(size: 60))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Alkindus henüz veri toplamadı")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Kararlar verildikçe burada istatistikler görünecek.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }
    
    private func loadStats() async {
        isLoading = true
        stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
        updateDbSize()
        loadPhase2Data()
        isLoading = false
    }
    
    private func refresh() {
        Task {
            await loadStats()
        }
    }
    
    private func updateDbSize() {
        dbSizeMB = AlkindusEventProcessor.shared.getDatabaseSizeMB()
    }
    
    private func processEvents() {
        isProcessing = true
        processedCount = 0
        processingResult = nil
        
        Task {
            let result = await AlkindusEventProcessor.shared.processHistoricalEvents { processed, total in
                DispatchQueue.main.async {
                    self.processedCount = processed
                    self.totalToProcess = total
                }
            }
            
            DispatchQueue.main.async {
                self.processingResult = result
                self.isProcessing = false
                self.refresh()
            }
        }
    }
    
    private func cleanupBlobs() {
        Task {
            AlkindusEventProcessor.shared.deleteProcessedBlobs()
            DispatchQueue.main.async {
                self.updateDbSize()
            }
        }
    }
    
    private func refreshInsights() {
        Task {
            let newInsights = await AlkindusInsightGenerator.shared.generateDailyInsights()
            DispatchQueue.main.async {
                self.insights = newInsights
            }
        }
    }
    
    private func refreshCorrelations() {
        Task {
            let correlations = await AlkindusCorrelationTracker.shared.getTopCorrelations(count: 5)
            DispatchQueue.main.async {
                self.topCorrelations = correlations
            }
        }
    }
    
    private func loadPhase2Data() {
        refreshInsights()
        refreshCorrelations()
    }
}

#Preview {
    AlkindusDashboardView()
}
