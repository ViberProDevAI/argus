import SwiftUI
import UniformTypeIdentifiers

// MARK: - AYARLAR

struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("notify_all_signals") private var notifyAllSignals = true
    @State private var showDrawer = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    // Alkindus kalibrasyon aksiyon durumu
    @State private var isRunningCalibration: Bool = false
    @State private var calibrationFlash: String? = nil

    // AutoPilot durumu — kullanıcı "trade etmiyor" dediğinde nedeni burada görünür
    @ObservedObject private var autoPilotStore = AutoPilotStore.shared

    // Özet veriler — Chiron & Alkindus durumu
    @State private var chironTradeCount: Int = 0
    @State private var chironWinRate: Int = 0
    @State private var alkindusPendingCount: Int = 0

    // "Neden trade etmiyor?" teşhisi
    @State private var tradeBlockReasons: [String] = []
    @State private var policyMode: String = "NORMAL"
    @State private var marketOpenGlobal: Bool = false
    @State private var marketOpenBist: Bool = false
    @State private var watchlistCount: Int = 0

    // Harmony — MarketContextCoordinator canlı durumu
    @ObservedObject private var marketContext = MarketContextCoordinator.shared

    // Aether velocity durumu (trend dönüş paneli için)
    @State private var aetherCurrent: Double = 0
    @State private var aetherVelocity: Double = 0
    @State private var aetherSignal: String = "—"
    @State private var aetherCrossingMsg: String? = nil

    // Aether Rejim Dönüşüm durumu
    @State private var regimeTransitionDirection: String = "STABLE"
    @State private var regimeTransitionSummary: String? = nil
    @State private var regimeEvidence: [String] = []
    @State private var regimeConfidence: Double = 0

    // Watchlist Pulse — tüm listenin ortak ani hareketi
    @State private var pulseSummary: String = "Veri yok"
    @State private var pulseIntensity: String = "DORMANT"
    @State private var pulseDirection: String = "MIXED"
    @State private var pulseMoveRate: Double = 0

    // Trend dönüş hassasiyeti
    @AppStorage("trendReversalSensitivity") private var trendSensitivity: String = "balanced"

    // Durum Panosu sheet
    @State private var showStatusConsole: Bool = false

    // 2026-04-25 H-38 — Settings tamamen yeniden tasarlandı:
    //   • Eski commandHeader (mono caps "AYARLAR" + 3px holo şerit + alt yazı)
    //     → sade "Ayarlar" + drawer butonu sticky top nav.
    //   • Eski snapshotRibbon (Chiron/Alkindus/Aether tile'ları) kaldırıldı —
    //     bu veriler Argus Status Console'a aittir.
    //   • Eski intelligenceSection (compactAutoPilotCard + aetherSensitivityCard +
    //     Chiron/Alkindus TerminalSection'lar) "Argus zekâsı" grubu altında 5
    //     ayrı alt sayfaya bölündü: Sistem durumu, Motor kalibrasyonu, Otopilot
    //     kuralları, Trend hassasiyeti, API anahtarları.
    //   • iOS Settings.app dilinde gruplandırılmış list — toggle, chevron,
    //     value badge formatı tutarlı.
    //   • Eski section computed property'leri (commandHeader, snapshotRibbon,
    //     intelligenceSection, vs.) şimdilik kodda kaldı, sonraki cleanup
    //     turunda silinecek. Artık çağrılmıyor.
    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    topNav
                    ScrollView {
                        settingsList
                            .padding(.top, 14)
                            .padding(.bottom, 60)
                    }
                }
                .task { await refreshSnapshots() }
                .sheet(isPresented: $showStatusConsole) {
                    ArgusStatusConsoleView(
                        aetherCurrent: aetherCurrent,
                        aetherVelocity: aetherVelocity,
                        aetherSignal: aetherSignal,
                        aetherCrossingMsg: aetherCrossingMsg,
                        regimeDirection: regimeTransitionDirection,
                        regimeSummary: regimeTransitionSummary,
                        regimeEvidence: regimeEvidence,
                        regimeConfidence: regimeConfidence,
                        pulseSummary: pulseSummary,
                        pulseIntensity: pulseIntensity,
                        pulseDirection: pulseDirection,
                        chironTradeCount: chironTradeCount,
                        chironWinRate: chironWinRate,
                        alkindusPendingCount: alkindusPendingCount,
                        policyMode: policyMode,
                        marketOpenGlobal: marketOpenGlobal,
                        marketOpenBist: marketOpenBist,
                        watchlistCount: watchlistCount,
                        tradeBlockReasons: tradeBlockReasons
                    )
                    .preferredColorScheme(.dark)
                }

                if showDrawer {
                    ArgusDrawerView(isPresented: $showDrawer) { openSheet in
                        drawerSections(openSheet: openSheet)
                    }
                    .zIndex(200)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        // NavigationStack zaten stack davranışı veriyor; navigationViewStyle
        // modifier'ı NavigationView için tasarlanmıştı, NavigationStack'e gerek yok.
    }
}

// MARK: - 2026-04-25 H-38 · Yeni sade list dili

extension SettingsView {

    // MARK: Top nav

    fileprivate var topNav: some View {
        HStack(spacing: 8) {
            Text("Ayarlar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: { showDrawer = true }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menüyü aç")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.border)
                .frame(height: 0.5)
        }
    }

    // MARK: Liste

    fileprivate var settingsList: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Görünüm") {
                settingsToggleRow(title: "Karanlık mod", isOn: $isDarkMode, last: true)
            }

            settingsGroup("Bildirimler") {
                settingsToggleRow(title: "Sinyal bildirimleri", isOn: $notifyAllSignals)
                settingsLinkRow(title: "Fiyat alarmları", last: true) { PriceAlertSettingsView() }
            }

            settingsGroup("İşlem") {
                settingsLinkRow(title: "Komisyon ve stopaj") {
                    SettingsSubPage(title: "Komisyon ve stopaj") { tradingFeesSection }
                }
                settingsToggleRow(title: "Otopilot", isOn: $autoPilotStore.isAutoPilotEnabled, last: true)
            }

            settingsGroup("Argus zekâsı") {
                settingsButtonRow(title: "Sistem durumu") { showStatusConsole = true }
                settingsLinkRow(title: "Motor kalibrasyonu") {
                    SettingsSubPage(title: "Motor kalibrasyonu") { motorCalibrationSubPage }
                }
                settingsLinkRow(title: "Otopilot kuralları") {
                    SettingsSubPage(title: "Otopilot kuralları") { autopilotRulesSubPage }
                }
                settingsLinkRow(title: "Trend hassasiyeti", value: trendSensitivityShortLabel) {
                    SettingsSubPage(title: "Trend hassasiyeti") { trendSensitivitySubPage }
                }
                settingsLinkRow(title: "API anahtarları", last: true) { APIKeyCenterView() }
            }

            settingsGroup("Veri") {
                settingsLinkRow(title: "Önbellek", last: true) {
                    SettingsSubPage(title: "Önbellek") {
                        VStack(spacing: 12) {
                            StorageCleanupSection()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }
                }
            }

            settingsGroup("Hakkında") {
                settingsLinkRow(title: "Argus rehberi") { ArgusGuideView() }
                settingsLinkRow(title: "Gizlilik politikası") { LegalDocumentView(document: settingsViewModel.privacyPolicy) }
                settingsLinkRow(title: "Kullanım koşulları") { LegalDocumentView(document: settingsViewModel.termsOfUse) }
                settingsLinkRow(title: "Risk bildirimi") { LegalDocumentView(document: settingsViewModel.riskDisclosure) }
                settingsButtonRow(title: "Geri bildirim") {
                    if let url = URL(string: "mailto:destek@argusapp.com") {
                        UIApplication.shared.open(url)
                    }
                }
                settingsValueRow(title: "Sürüm", value: appVersionString, last: true)
            }
        }
        .padding(.horizontal, 16)
    }

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var trendSensitivityShortLabel: String {
        switch trendSensitivity {
        case "conservative": return "Muhafazakâr"
        case "aggressive":   return "Agresif"
        default:             return "Dengeli"
        }
    }

    // MARK: Group & row helpers

    @ViewBuilder
    fileprivate func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.leading, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    fileprivate func settingsToggleRow(title: String, isOn: Binding<Bool>, last: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(InstitutionalTheme.Colors.aurora)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.border)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    @ViewBuilder
    fileprivate func settingsLinkRow<Destination: View>(
        title: String,
        value: String? = nil,
        last: Bool = false,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.border)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    fileprivate func settingsButtonRow(title: String, value: String? = nil, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.border)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    fileprivate func settingsValueRow(title: String, value: String, last: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.border)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    // MARK: Argus zekâsı alt sayfaları
    //
    // Eski intelligenceSection content'i 3 ayrı alt sayfaya bölündü.
    // İçerikler eski compactAutoPilotCard / aetherSensitivityCard /
    // Chiron + Alkindus TerminalSection'lar.

    fileprivate var motorCalibrationSubPage: some View {
        VStack(spacing: 12) {
            // Chiron Öğrenme Motoru
            TerminalSection(title: "CHIRON · ÖĞRENME",
                            motor: .chiron) {
                NavigationLink(destination: ChironInsightsView()) {
                    ArgusTerminalRow(
                        label: "Kokpit",
                        value: chironTradeCount > 0 ? "WR %\(chironWinRate) · T \(chironTradeCount)" : "Henüz veri yok",
                        icon: "ChironIcon",
                        color: InstitutionalTheme.Colors.Motors.chiron
                    )
                }
                NavigationLink(destination: ChironPerformanceView()) {
                    ArgusTerminalRow(
                        label: "Performans",
                        value: "Grafikler",
                        icon: "chart.bar.xaxis",
                        color: InstitutionalTheme.Colors.primary
                    )
                }
                NavigationLink(destination: ChironInsightsView(symbol: nil)) {
                    ArgusTerminalRow(
                        label: "İçgörüler",
                        value: "Son dersler",
                        icon: "waveform.path.ecg",
                        color: InstitutionalTheme.Colors.positive
                    )
                }
            }

            // Alkindus Kalibrasyon Motoru
            TerminalSection(title: "ALKINDUS · KALİBRASYON",
                            motor: .alkindus) {
                NavigationLink(destination: AlkindusDashboardView()) {
                    ArgusTerminalRow(
                        label: "Gözlem Paneli",
                        value: alkindusPendingCount > 0 ? "\(alkindusPendingCount) bekliyor" : "Boş",
                        icon: "eye.circle.fill",
                        color: InstitutionalTheme.Colors.neutral
                    )
                }

                Button(action: runCalibrationNow) {
                    HStack(spacing: 12) {
                        Image(systemName: isRunningCalibration ? "arrow.triangle.2.circlepath" : "play.circle.fill")
                            .font(.system(.callout))
                            .foregroundColor(isRunningCalibration ? InstitutionalTheme.Colors.textSecondary : InstitutionalTheme.Colors.primary)
                            .frame(width: 20)
                            .rotationEffect(.degrees(isRunningCalibration ? 360 : 0))
                            .animation(isRunningCalibration ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default, value: isRunningCalibration)

                        Text(isRunningCalibration ? "Çalışıyor…" : "Kalibrasyonu şimdi çalıştır")
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                        Spacer()

                        if let flash = calibrationFlash {
                            Text(flash)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.positive)
                                .transition(.opacity)
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRunningCalibration)
                .accessibilityLabel(isRunningCalibration ? "Kalibrasyon çalışıyor" : "Kalibrasyonu şimdi çalıştır")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    fileprivate var autopilotRulesSubPage: some View {
        VStack(spacing: 12) {
            compactAutoPilotCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    fileprivate var trendSensitivitySubPage: some View {
        VStack(spacing: 12) {
            aetherSensitivityCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

// MARK: - SettingsSubPage helper
//
// Argus zekâsı ve İşlem alt sayfalarını sarmalar — back chevron + başlık
// üst nav. NavigationLink destination olarak kullanıma hazır.

struct SettingsSubPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Geri")

                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(InstitutionalTheme.Colors.surface1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.border)
                        .frame(height: 0.5)
                }

                ScrollView {
                    content()
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

extension SettingsView {

    // -- Compact Otopilot Kartı (sade ayar) --
    //
    // Sadece toggle + tek satır mod etiketi + "Detaylar →" link. Canlı teşhis,
    // Harmony paneli, blocker listesi Durum Panosu sheet'inde (Snapshot Ribbon tıkla).

    private var compactAutoPilotCard: some View {
        TerminalSection(title: "OTOPİLOT",
                        motor: .argus) {
            HStack(spacing: 12) {
                Image(systemName: autoPilotStore.isAutoPilotEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(.callout))
                    .foregroundColor(autoPilotStore.isAutoPilotEnabled ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(autoPilotStore.isAutoPilotEnabled ? "Aktif" : "Kapalı")
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(compactModeLabel)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(compactModeColor)
                }
                Spacer()
                Toggle("", isOn: $autoPilotStore.isAutoPilotEnabled)
                    .labelsHidden()
                    .tint(InstitutionalTheme.Colors.positive)
                    .accessibilityLabel("Otopilot")
            }
            .padding(.vertical, 8)

            Button(action: { showStatusConsole = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(.footnote))
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .frame(width: 20)
                    Text("Durum Panosu")
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    if !tradeBlockReasons.isEmpty {
                        Text("\(tradeBlockReasons.count) uyarı")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.neutral)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.7))
                }
                .frame(minHeight: 44)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Durum panosunu aç")
        }
    }

    private var compactModeLabel: String {
        let snap = marketContext.snapshot
        if !autoPilotStore.isAutoPilotEnabled { return "Hiçbir alım/satım yapılmaz" }
        if snap.opportunityMode { return "🚀 Fırsat modu (×\(String(format: "%.2f", snap.positionMultiplier)))" }
        if snap.protectiveMode { return "🛡️ Koruyucu mod (×\(String(format: "%.2f", snap.positionMultiplier)))" }
        return "Normal seyir"
    }

    private var compactModeColor: Color {
        let snap = marketContext.snapshot
        if !autoPilotStore.isAutoPilotEnabled { return InstitutionalTheme.Colors.neutral }
        if snap.opportunityMode { return InstitutionalTheme.Colors.positive }
        if snap.protectiveMode { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.textSecondary
    }

    // -- Aether Hassasiyet Kartı (sade ayar) --

    private var aetherSensitivityCard: some View {
        TerminalSection(title: "AETHER · TREND DÖNÜŞ HASSASİYETİ",
                        motor: .aether) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Hassasiyet", selection: $trendSensitivity) {
                    Text("Muhafazakâr").tag("conservative")
                    Text("Dengeli").tag("balanced")
                    Text("Agresif").tag("aggressive")
                }
                .pickerStyle(.segmented)

                Text(sensitivityExplanation)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }

    private var sensitivityExplanation: String {
        switch trendSensitivity {
        case "conservative":
            return "Skor eşikleri bekler — trend dönüşlerini geç yakalar, yanlış sinyal riski düşük."
        case "aggressive":
            return "Hız pozitifse skor düşük olsa bile alım penceresi açar — erken girer, yanlış sinyal riski yüksek."
        default:
            return "Skor + hız birlikte değerlendirilir — denge. Savaş→ateşkes geçişinde rally penceresi yakalanır."
        }
    }

    // -- İşlem Ayarları (Komisyon / Stopaj) --

    private var tradingFeesSection: some View {
        TerminalSection(title: "İŞLEM AYARLARI",
                        systemImage: "percent",
                        accentColor: InstitutionalTheme.Colors.titan) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Aracı kurumunuzun komisyon oranlarını girin. Sıfır bırakırsanız komisyon hesaplanmaz — Midas, Garanti, Alpaca gibi sıfır komisyon aracılar için doğru ayar.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                feeRow(
                    label: "BIST komisyon",
                    value: $settingsViewModel.bistCommissionPercent,
                    range: 0...1.5,
                    icon: "turkishlirasign.circle.fill"
                )

                feeRow(
                    label: "ABD/Global komisyon",
                    value: $settingsViewModel.globalCommissionPercent,
                    range: 0...1.0,
                    icon: "dollarsign.circle.fill"
                )

                Divider().background(InstitutionalTheme.Colors.textSecondary.opacity(0.2))

                Text("BIST stopajı şu an 2026 itibariyle hisse senedi kâr istisnası kapsamında. Vergi rejimi değişirse buradan oran girebilirsiniz; backtest ve gerçek alım hesaplarında kâra uygulanır.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                feeRow(
                    label: "BIST stopaj",
                    value: $settingsViewModel.bistWithholdingPercent,
                    range: 0...30,
                    icon: "doc.text.fill"
                )
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func feeRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.callout))
                .foregroundColor(InstitutionalTheme.Colors.titan)
                .frame(width: 20)
            Text(label)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            Text(String(format: "%%%.2f", value.wrappedValue))
                .font(InstitutionalTheme.Typography.data)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 64, alignment: .trailing)
        }
        Slider(value: value, in: range, step: 0.01)
            .tint(InstitutionalTheme.Colors.titan)
            .accessibilityLabel(label)
    }

}

// MARK: - Aksiyonlar & Veri Yenileme

extension SettingsView {

    /// Chiron & Alkindus özet verilerini tazele.
    /// Başlangıçta ve kalibrasyon sonrası çağrılır.
    fileprivate func refreshSnapshots() async {
        // Chiron istatistikleri — iki kaynak: ChironDataLake (son dönem, tam kayıt) +
        // PortfolioStore (tüm tarihsel kapalı trade'ler). Eski import edilmemiş 92
        // trade Chiron dosyasında olmadığı için WR hep boş kalıyordu. PortfolioStore'dan
        // doğrudan okuyoruz, fallback olarak Chiron lake kullanılır.
        let chironTrades = await ChironDataLakeService.shared.loadAllTradeHistory()
        let portfolioClosed = await MainActor.run {
            PortfolioStore.shared.trades.filter { !$0.isOpen && $0.exitPrice != nil }
        }
        let pending = await AlkindusMemoryStore.shared.loadPendingObservations().count
        let velocity = await AetherVelocityEngine.shared.analyze()

        // Rejim dönüşüm durumu — Settings'de banner olarak gösterilecek
        let watchlist = await MainActor.run { WatchlistStore.shared.items }
        let quotes = await MainActor.run { MarketDataStore.shared.quotes.compactMapValues { $0.value } }
        let candles = await MainActor.run { MarketDataStore.shared.candles.compactMapValues { $0.value } }
        let globalMomentum = await MarketMomentumGate.shared.assessGlobal(
            quotes: quotes, candles: candles, watchlistSymbols: watchlist
        )
        let bistMomentum = await MarketMomentumGate.shared.assessBist(
            quotes: quotes, candles: candles, watchlistSymbols: watchlist
        )
        // Hermes event sayımı — gerçek event store'dan son 24 saat
        let hermesPos = HermesEventStore.shared.countHighImpactEvents(polarity: .positive)
        let hermesNeg = HermesEventStore.shared.countHighImpactEvents(polarity: .negative)

        // Watchlist pulse — tüm listenin nabzı
        let pulse = await WatchlistPulseMonitor.shared.assess(candlesBySymbol: candles)

        let transition = await AetherRegimeTransitionDetector.shared.analyze(
            velocity: velocity,
            recentPositiveHermesEvents: hermesPos,
            recentNegativeHermesEvents: hermesNeg,
            globalMomentumLevel: globalMomentum.level,
            bistMomentumLevel: bistMomentum.level,
            watchlistPulse: pulse
        )

        // Kapalı trade sayımı — iki kaynaktan en büyüğünü al (eski import edilmemiş
        // trade'ler PortfolioStore'da olabilir ama Chiron'a yansımamış)
        let tradeCount = max(chironTrades.count, portfolioClosed.count)
        let winRate: Int = {
            if !portfolioClosed.isEmpty {
                let wins = portfolioClosed.filter { ($0.exitPrice ?? 0) > $0.entryPrice }.count
                return Int((Double(wins) / Double(portfolioClosed.count)) * 100)
            }
            if !chironTrades.isEmpty {
                let wins = chironTrades.filter { $0.pnlPercent > 0 }.count
                return Int((Double(wins) / Double(chironTrades.count)) * 100)
            }
            return 0
        }()

        // Trade blocker teşhisi
        let policy = RiskEscapePolicy.from(aetherScore: velocity.currentScore)
        let globalOpen = MarketStatusService.shared.canTrade(for: .global)
        let bistOpen   = MarketStatusService.shared.canTrade(for: .bist)
        let watchCount = await MainActor.run { WatchlistStore.shared.items.count }

        var reasons: [String] = []
        if !autoPilotStore.isAutoPilotEnabled {
            reasons.append("Otopilot kapalı — yukarıdaki toggle'dan aç")
        }
        if policy.mode != .normal {
            reasons.append("Risk politikası \(policy.mode.rawValue) — Aether \(Int(velocity.currentScore)) (riskli alım bloke)")
        }
        if !globalOpen && !bistOpen {
            reasons.append("Tüm piyasalar kapalı — açılış saatini bekliyor")
        }
        if watchCount == 0 {
            reasons.append("İzleme listesi boş — sembol ekle")
        }

        await MainActor.run {
            self.chironTradeCount = tradeCount
            self.chironWinRate = winRate
            self.alkindusPendingCount = pending
            self.aetherCurrent = velocity.currentScore
            self.aetherVelocity = velocity.velocity
            self.aetherSignal = velocity.signal.rawValue
            self.aetherCrossingMsg = velocity.crossingAlert?.description
            self.regimeTransitionDirection = transition.direction.rawValue
            self.regimeTransitionSummary = transition.direction == .stable ? nil : transition.summary
            self.regimeEvidence = transition.evidence
            self.regimeConfidence = transition.confidence
            self.pulseSummary = pulse.summary
            self.pulseIntensity = pulse.intensity.rawValue
            self.pulseDirection = pulse.direction.rawValue
            self.pulseMoveRate = pulse.avgMoveRate
            self.policyMode = policy.mode.rawValue
            self.marketOpenGlobal = globalOpen
            self.marketOpenBist = bistOpen
            self.watchlistCount = watchCount
            self.tradeBlockReasons = reasons
        }
    }

    /// Alkindus kalibrasyonu manuel tetikle.
    /// Periyodik maturation'a bağımlı kalmadan kullanıcı "şimdi bak" diyebilir.
    fileprivate func runCalibrationNow() {
        guard !isRunningCalibration else { return }
        isRunningCalibration = true
        calibrationFlash = nil

        Task {
            await AlkindusCalibrationEngine.shared.periodicMatureCheck()
            await refreshSnapshots()

            await MainActor.run {
                withAnimation { calibrationFlash = "Güncellendi" }
                isRunningCalibration = false
            }

            // 2 sn sonra flash mesajını temizle
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation { calibrationFlash = nil }
            }
        }
    }
}

// MARK: - Drawer

extension SettingsView {
    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        [
            ArgusDrawerView.DrawerSection(
                title: "Ekranlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ana Sayfa", subtitle: "Piyasa özeti", icon: "waveform.path.ecg") {
                        deepLinkManager.navigate(to: .home)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Kokpit", subtitle: "Tam liste", icon: "chart.line.uptrend.xyaxis") {
                        deepLinkManager.navigate(to: .kokpit)
                        showDrawer = false
                    },
                    ArgusDrawerView.DrawerItem(title: "Portföy", subtitle: "Pozisyonlar", icon: "briefcase.fill") {
                        deepLinkManager.navigate(to: .portfolio)
                        showDrawer = false
                    }
                ]
            ),
            ArgusDrawerView.DrawerSection(
                title: "Araçlar",
                items: [
                    ArgusDrawerView.DrawerItem(title: "Ekonomi Takvimi", subtitle: "Önemli tarihler", icon: "calendar") {
                        openSheet(.calendar)
                    },
                    ArgusDrawerView.DrawerItem(title: "Finans Sözlüğü", subtitle: "Terimler", icon: "character.book.closed") {
                        openSheet(.dictionary)
                    },
                    ArgusDrawerView.DrawerItem(title: "Geri Bildirim", subtitle: "Sorun bildir", icon: "envelope") {
                        openSheet(.feedback)
                    }
                ]
            )
        ]
    }
}

// MARK: - UI: Terminal Section

/// V5 card-2 + section title düzeni.
///
/// 2026-04-22 Sprint 3: Başlığın yanına opsiyonel motor logosu/SF ikonu,
/// V5 radius `lg (14)`, solid border renkleri. `motor:` parametresi verilirse
/// MotorLogo gösterilir; `systemImage:` fallback olarak SF Symbol (kalan
/// alt bölümler için: bildirim, api, depolama).
struct TerminalSection<Content: View>: View {
    let title: String
    let motor: MotorEngine?
    let systemImage: String?
    let accentColor: Color
    let content: Content

    init(title: String,
         motor: MotorEngine? = nil,
         systemImage: String? = nil,
         accentColor: Color = InstitutionalTheme.Colors.textSecondary,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.motor = motor
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let motor {
                    MotorLogo(motor, size: 14)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 14, height: 14)
                }
                ArgusSectionCaption(title)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
    }
}

// MARK: - UI: Terminal Row

struct ArgusTerminalRow: View {
    let label: String
    let value: String?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.callout))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Spacer()

            if let v = value {
                Text(v)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(color.opacity(0.8))
            }

            Image(systemName: "chevron.right")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.7))
        }
        .frame(minHeight: 44)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(InstitutionalTheme.Colors.borderSubtle),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(value.map { "\(label), \($0)" } ?? label))
    }
}

// MARK: - Utility: Legal Document Viewer

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            Text(document.content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
        }
        .background(InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all))
        .navigationTitle(document.title)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Utility: Share Sheet

struct ArgusShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Depolama Temizligi

struct StorageCleanupSection: View {
    @State private var isCleaningUp = false
    @State private var cleanupResult: String?
    @State private var storageSize: String = "Hesaplanıyor..."
    @State private var showCleanupConfirmation = false

    var body: some View {
        TerminalSection(title: "DEPOLAMA",
                        systemImage: "externaldrive.fill",
                        accentColor: InstitutionalTheme.Colors.textSecondary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(InstitutionalTheme.Colors.neutral)
                        .font(.system(.callout))
                        .frame(width: 20)
                    Text("Kullanılan alan")
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    Text(storageSize)
                        .font(InstitutionalTheme.Typography.dataSmall)
                        .foregroundColor(InstitutionalTheme.Colors.neutral)
                }

                Divider().background(InstitutionalTheme.Colors.borderSubtle)

                Button(action: { showCleanupConfirmation = true }) {
                    HStack(spacing: 12) {
                        if isCleaningUp {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(InstitutionalTheme.Colors.negative)
                                .frame(width: 20)
                        } else {
                            Image(systemName: "trash.fill")
                                .foregroundColor(InstitutionalTheme.Colors.negative)
                                .font(.system(.callout))
                                .frame(width: 20)
                        }
                        Text(isCleaningUp ? "Temizleniyor..." : "Önbelleği temizle")
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isCleaningUp)
                .padding(.vertical, 4)
                .accessibilityLabel(isCleaningUp ? "Temizleniyor" : "Önbelleği temizle")

                if let result = cleanupResult {
                    Text(result)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.positive)
                }

                Text("Önbellek ve geçici dosyalar silinir. Öğrenme verileri korunur.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .onAppear { calculateStorageSize() }
        .alert("Emin misiniz?", isPresented: $showCleanupConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Temizle", role: .destructive) { performCleanup() }
        } message: {
            Text("Bu işlem önbellek ve geçici dosyaları silecek. İşlem geçmişi ve öğrenme verileri korunur.")
        }
    }

    private func calculateStorageSize() {
        Task {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

            var totalSize: Int64 = 0
            if let docs = docsDir { totalSize += folderSize(url: docs) }
            if let caches = cachesDir { totalSize += folderSize(url: caches) }

            let mb = Double(totalSize) / 1024.0 / 1024.0
            let gb = mb / 1024.0

            await MainActor.run {
                storageSize = gb >= 1.0
                    ? String(format: "%.2f GB", gb)
                    : String(format: "%.0f MB", mb)
            }
        }
    }

    private func folderSize(url: URL) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize ?? 0)
                }
            }
        }
        return size
    }

    private func performCleanup() {
        isCleaningUp = true
        cleanupResult = nil

        Task {
            let ledgerResult = await ArgusLedger.shared.aggressiveCleanup(maxBlobAgeDays: 0, maxEventAgeDays: 0)
            DiskCacheService.shared.cleanup(maxAgeDays: 0)
            DiskCacheService.shared.clearAll()

            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fm = FileManager.default
                if let contents = try? fm.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil) {
                    let safeToClean: Set<String> = [
                        "ArgusScience_V1.sqlite",
                        "ArgusScience_V2.sqlite",
                        "forward_test_results.json",
                        "argus_data_export.zip"
                    ]
                    for url in contents {
                        if safeToClean.contains(where: { url.lastPathComponent.contains($0) }) {
                            try? fm.removeItem(at: url)
                        }
                    }
                }
            }

            await MainActor.run {
                isCleaningUp = false
                cleanupResult = ledgerResult.summary
                calculateStorageSize()
            }
        }
    }
}
