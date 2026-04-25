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
                title: "ALKINDUS",
                subtitle: "ÖĞRENME · KALİBRASYON · İÇGÖRÜ",
                leadingDeco: .bars3([.holo, .text, .text]),
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MotorLogo(.alkindus, size: 14)
                ArgusSectionCaption("BU HİSSE İÇİN OKUMAM")
                Spacer()
                ArgusChip(sym.uppercased(), tone: .motor(.alkindus))
            }

            if let insight = symbolInsight {
                Text(insight.message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    insightRow(label: "En iyi modül",
                               value: "\(insight.bestModule.uppercased()) · %\(Int(insight.bestHitRate * 100))",
                               tone: .aurora)
                    insightRow(label: "En zayıf modül",
                               value: "\(insight.worstModule.uppercased()) · %\(Int(insight.worstHitRate * 100))",
                               tone: .crimson)
                    insightRow(label: "Toplam karar",
                               value: "\(insight.totalDecisions) adet",
                               tone: .neutral)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ArgusDot(color: InstitutionalTheme.Colors.titan)
                        .padding(.top, 5)
                    Text("Bu hisse için henüz yeterli karar birikmedi (en az 5 karar gerekiyor). Kararlar verildikçe burası dolacak.")
                        .font(.system(size: 11.5))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("↓ Global kalibrasyon panosu aşağıda")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.alkindus.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    private func insightRow(label: String, value: String, tone: ArgusChipTone) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer(minLength: 0)
            ArgusChip(value, tone: tone)
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
                title: "ALKINDUS",
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
            title: "ARACLAR",
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
        // V5: Motor avatar + caption + shadow mode chip + iki mini stat
        v5Card {
            HStack(spacing: 12) {
                ArgusOrb(size: 48,
                         ringColor: InstitutionalTheme.Colors.Motors.alkindus,
                         glowColor: InstitutionalTheme.Colors.Motors.alkindus) {
                    MotorLogo(.alkindus, size: 26)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ALKINDUS")
                            .font(InstitutionalTheme.Typography.dataMicro)
                            .tracking(1.2)
                            .foregroundColor(InstitutionalTheme.Colors.Motors.alkindus)
                        Text("·")
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("META-ZEKA")
                            .font(InstitutionalTheme.Typography.dataMicro)
                            .tracking(1.2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    Text("Kalibrasyon Dashboard")
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    ArgusPill("SHADOW MODE", tone: .motor(.alkindus))
                    Text("\(stats.pendingCount) bekleyen")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            ArgusHair()

            HStack(spacing: 14) {
                if let top = stats.topModule {
                    miniStat(title: "EN İYİ MODÜL", value: top.name.capitalized,
                             rate: top.hitRate, color: InstitutionalTheme.Colors.aurora)
                }

                if let weak = stats.weakestModule {
                    miniStat(title: "EN ZAYIF", value: weak.name.capitalized,
                             rate: weak.hitRate, color: InstitutionalTheme.Colors.crimson)
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
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }
    
    private func miniStat(title: String, value: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            HStack(spacing: 8) {
                Text(value)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(String(format: "%%%.0f", rate * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.18))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func moduleCalibrationSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ArgusSectionCaption("MODÜL KALİBRASYONU")
                Spacer()
                ArgusChip("\(stats.calibration.modules.count) MODÜL", tone: .motor(.alkindus))
            }

            if stats.calibration.modules.isEmpty {
                v5Card {
                    HStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                        Text("Henüz veri yok. Kararlar verildikçe burası dolacak.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
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
        let engine = motorFromName(name)
        return v5Card {
            HStack(spacing: 10) {
                if let engine {
                    MotorLogo(engine, size: 18)
                }
                Text(name.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                let totalAttempts = calibration.brackets.values.reduce(0) { $0 + $1.attempts }
                Text("\(totalAttempts) deneme")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            VStack(spacing: 6) {
                ForEach(calibration.brackets.sorted(by: { $0.key > $1.key }), id: \.key) { bracket, bstats in
                    HStack(spacing: 10) {
                        Text(bracket)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .frame(width: 56, alignment: .leading)

                        ArgusBar(value: bstats.hitRate,
                                 color: colorForHitRate(bstats.hitRate),
                                 height: 5)

                        Text(String(format: "%%%.0f", bstats.hitRate * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForHitRate(bstats.hitRate))
                            .frame(width: 36, alignment: .trailing)

                        Text("\(bstats.attempts)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
            HStack {
                ArgusSectionCaption("REJİM BAZLI PERFORMANS")
                Spacer()
                if !stats.calibration.regimes.isEmpty {
                    ArgusChip("\(stats.calibration.regimes.count) REJİM", tone: .motor(.aether))
                }
            }

            if stats.calibration.regimes.isEmpty {
                v5Card {
                    HStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                        Text("Rejim verisi henüz yok.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
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
                ArgusDot(color: regimeTone(regime).foreground)
                Text(regime.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                ArgusChip("\(insight.moduleAttempts.count) MODÜL", tone: regimeTone(regime))
            }

            VStack(spacing: 6) {
                ForEach(insight.moduleAttempts.sorted(by: { $0.key < $1.key }), id: \.key) { module, _ in
                    let rate = insight.hitRate(for: module)
                    HStack(spacing: 10) {
                        if let engine = motorFromName(module) {
                            MotorLogo(engine, size: 14)
                        } else {
                            Spacer().frame(width: 14, height: 14)
                        }
                        Text(module.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        ArgusBar(value: rate, color: colorForHitRate(rate), height: 4)
                        Text(String(format: "%%%.0f", rate * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForHitRate(rate))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Rejim adına göre V5 tonu — bilinen rejimleri aether/aurora/titan/crimson'a eşler.
    private func regimeTone(_ regime: String) -> ArgusChipTone {
        let r = regime.lowercased()
        if r.contains("bull") || r.contains("trend") || r.contains("yüksel") { return .aurora }
        if r.contains("bear") || r.contains("düş") || r.contains("risk") || r.contains("crash") { return .crimson }
        if r.contains("chop") || r.contains("yatay") || r.contains("neutral") { return .titan }
        return .motor(.aether)
    }

    private func pendingSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("BEKLEYEN GÖZLEMLER")
            v5Card {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(InstitutionalTheme.Colors.Motors.alkindus.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hourglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(InstitutionalTheme.Colors.Motors.alkindus)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stats.pendingCount)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("KARAR OLGUNLAŞMA BEKLİYOR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
                ArgusSectionCaption("BUGÜN ÖĞRENDİKLERİM")
                Spacer()
                Button(action: refreshInsights) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("YENİLE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                    }
                    .foregroundColor(InstitutionalTheme.Colors.titan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(InstitutionalTheme.Colors.titan.opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
            }

            if insights.isEmpty {
                v5Card {
                    HStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                        Text("Henüz günlük insight yok. 'Eventlerden Öğren' butonuna bas.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
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
        let tone = importanceTone(insight.importance)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tone.foreground.opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: iconForCategory(insight.category))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tone.foreground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(2)
                Text(insight.detail)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 8)
            ArgusChip(categoryLabel(insight.category), tone: tone)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(tone.foreground.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
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
        case .correlation: return "KORELASYON"
        case .anomaly:     return "ANOMALİ"
        case .trend:       return "TREND"
        case .performance: return "PERFORMANS"
        case .regime:      return "REJİM"
        case .warning:     return "UYARI"
        case .discovery:   return "KEŞİF"
        }
    }

    private func importanceTone(_ importance: AlkindusInsightGenerator.InsightImportance) -> ArgusChipTone {
        switch importance {
        case .critical: return .crimson
        case .high:     return .titan
        case .medium:   return .holo
        case .low:      return .neutral
        }
    }
    
    @State private var topCorrelations: [(key: String, hitRate: Double, attempts: Int)] = []
    
    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ArgusSectionCaption("EN BAŞARILI KOMBİNASYONLAR")
                Spacer()
                if !topCorrelations.isEmpty {
                    ArgusChip("TOP \(topCorrelations.count)", tone: .motor(.alkindus))
                }
            }

            if topCorrelations.isEmpty {
                v5Card {
                    HStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                        Text("Henüz korelasyon verisi yok.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(topCorrelations.enumerated()), id: \.offset) { idx, corr in
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.Motors.alkindus)
                                .frame(width: 28, alignment: .leading)
                            Text(formatCorrelationKey(corr.key))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("%\(Int(corr.hitRate * 100))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(colorForHitRate(corr.hitRate))
                            Text("\(corr.attempts)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(InstitutionalTheme.Colors.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
                    }
                }
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
            ArgusSectionCaption("MARKET KARŞILAŞTIRMASI")

            if let comparison = marketComparison {
                v5Card {
                    HStack(spacing: 14) {
                        marketOrb(title: "BIST", rate: comparison.bist, flag: "🇹🇷")
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.border)
                            .frame(width: 1, height: 48)
                        marketOrb(title: "GLOBAL", rate: comparison.global, flag: "🌐")
                    }
                }
            } else {
                v5Card {
                    HStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
                        Text("Henüz BIST/Global karşılaştırma verisi yok")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .task {
            marketComparison = await AlkindusSymbolLearner.shared.getMarketComparison()
        }
    }

    private func marketOrb(title: String, rate: Double, flag: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(flag).font(.system(size: 12))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Text("%\(Int(rate * 100))")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(colorForHitRate(rate))
            ArgusBar(value: rate, color: colorForHitRate(rate), height: 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dataToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("VERİ ARAÇLARI")

            v5Card {
                // DB boyutu satırı
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("VERİTABANI BOYUTU")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f MB", dbSizeMB))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(dbSizeMB > 100
                                         ? InstitutionalTheme.Colors.crimson
                                         : InstitutionalTheme.Colors.textPrimary)
                }

                if isProcessing {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(InstitutionalTheme.Colors.holo)
                            Text("İŞLENİYOR · \(processedCount)/\(totalToProcess)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundColor(InstitutionalTheme.Colors.holo)
                        }
                        let progress = totalToProcess > 0
                            ? Double(processedCount) / Double(totalToProcess)
                            : 0
                        ArgusBar(value: min(max(progress, 0), 1),
                                 color: InstitutionalTheme.Colors.holo,
                                 height: 5)
                    }
                }

                if let result = processingResult {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.aurora)
                            Text("\(result.eventsProcessed) event · \(result.patternsExtracted) pattern")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.aurora)
                        }
                        Text("ÖĞRENİLEN: \(result.modulesLearned.joined(separator: " · ").uppercased())")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                }

                ArgusHair()

                HStack(spacing: 8) {
                    v5ActionButton(label: "EVENTLERDEN ÖĞREN",
                                   icon: .alkindus,
                                   tone: .motor(.alkindus),
                                   disabled: isProcessing,
                                   action: processEvents)

                    v5ActionButton(label: "BLOB TEMİZLE",
                                   icon: nil,
                                   sfSymbol: "trash",
                                   tone: .crimson,
                                   disabled: isProcessing,
                                   action: cleanupBlobs)
                }
            }
        }
    }

    /// V5 aksiyon butonu — pill + mono label.
    private func v5ActionButton(label: String,
                                icon: MotorEngine? = nil,
                                sfSymbol: String? = nil,
                                tone: ArgusChipTone,
                                disabled: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    MotorLogo(icon, size: 12).tinted(tone.foreground)
                } else if let sfSymbol {
                    Image(systemName: sfSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tone.foreground)
                }
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(tone.foreground)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(tone.foreground.opacity(0.35), lineWidth: 1)
            )
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
