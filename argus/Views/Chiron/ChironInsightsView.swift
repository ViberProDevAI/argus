import SwiftUI

/// Rejim öğrenme dashboard'u (eski adıyla Chiron Insights).
/// Bileşen performanslarını ve öğrenilmiş ağırlıkları gösterir.
///
/// 2026-04-30 H-58 — sade refactor.
/// Eski yapı: Theme (legacy DS) + raw .cyan/.purple/.white/.gray + emoji
/// brain icon + "Chiron Akıllı Öğrenme" başlık + caps "Win:" + cornerRadius
/// 12 yığını. Yeni: InstitutionalTheme + sentence başlık ("Rejim öğrenme") +
/// sade hairline kartlar + sentence "Yapı/Trend/Momentum..." weight isimleri.
/// Public API korundu — `init(symbol: String? = nil)`.

struct ChironInsightsView: View {
    let symbol: String?

    @State private var globalStats: [ComponentPerformanceService.ComponentStats] = []
    @State private var symbolStats: [ComponentPerformanceService.ComponentStats] = []
    @State private var learnedWeights: OrionWeightSnapshot?
    @State private var learningStatus: (hasLearning: Bool, confidence: Double, note: String)?

    // 2026-05-04 H-62: Chiron öğrenme tetikleyicisi state'i.
    // Eski sürümde manuel buton yoktu — yalnızca arka planda zamanlanmış
    // job çalışıyordu, kullanıcı "şimdi öğren" diyemiyordu.
    @State private var isLearning = false
    @State private var actionFlash: String? = nil
    @State private var lastLearningAt: Date? = nil

    // 2026-05-04 H-61: Settings → Motor kalibrasyonu → ChironInsightsView
    // push'unda parent'ın `.navigationBarHidden(true)` ayarı sistem geri
    // butonunu gizliyordu. Çözüm: kendi inline top nav'ını koy, dismiss
    // ile pop et. router.navigationStack boş olsa bile (NavigationLink
    // path'i değiştirmiyor) `\.dismiss` push'u doğru pop'lar.
    @Environment(\.dismiss) private var dismiss
    // 2026-05-09: ChironPerformanceView'daki gibi nested NavigationLink
    // push'larında `\.dismiss` bazen ölü kalıyor; eski API fallback.
    @Environment(\.presentationMode) private var presentationMode

    init(symbol: String? = nil) {
        self.symbol = symbol
    }

    var body: some View {
        VStack(spacing: 0) {
            inlineTopNav

            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    if let status = learningStatus {
                        learningStatusCard(status)
                    }

                    if let weights = learnedWeights {
                        learnedWeightsCard(weights)
                    }

                    if !symbolStats.isEmpty || !globalStats.isEmpty {
                        componentPerformanceSection
                    }

                    actionsCard

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadData() }
    }

    // MARK: - Pop helper
    private func popBack() {
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Inline top nav (2026-05-04 H-61)
    //
    // Sade üst nav: chevron geri + "Rejim öğrenme" başlık. Parent'ın
    // SettingsSubPage'i `.navigationBarHidden(true)` yaptığı için sistem
    // bar'ına güvenemiyoruz; her durumda kendi geri butonumuzu çiziyoruz.
    private var inlineTopNav: some View {
        HStack(spacing: 8) {
            Button(action: popBack) {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Fonts.custom(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")

            Text("Rejim öğrenme")
                .font(DesignTokens.Fonts.custom(size: 17, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    // MARK: - Header
    //
    // 2026-05-04 H-61: H1 başlık inline top nav'a taşındığından buradan
    // kaldırıldı; sadece bağlam altyazısı kalıyor (sembol / tüm portföy).
    private var headerSection: some View {
        Text(symbol != nil ? "Sembol: \(symbol!)" : "Tüm portföy")
            .font(DesignTokens.Fonts.custom(size: 13))
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    // MARK: - Öğrenme Durumu Card

    private func learningStatusCard(_ status: (hasLearning: Bool, confidence: Double, note: String)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Öğrenme durumu")
                    .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Spacer()

                if status.hasLearning {
                    Text("%\(Int(status.confidence * 100))")
                        .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                        .foregroundColor(confidenceColor(status.confidence))
                        .monospacedDigit()
                } else {
                    Text("Bekliyor")
                        .font(DesignTokens.Fonts.custom(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            Text(status.note)
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            if status.hasLearning {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.surface2)
                            .frame(height: 4)
                            .cornerRadius(2)

                        Rectangle()
                            .fill(confidenceColor(status.confidence))
                            .frame(width: geo.size.width * status.confidence, height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Öğrenilmiş Ağırlıklar Card

    private func learnedWeightsCard(_ weights: OrionWeightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Öğrenilmiş ağırlıklar")
                .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            VStack(spacing: 10) {
                weightBar(name: "Yapı",      value: weights.structure)
                weightBar(name: "Trend",     value: weights.trend)
                weightBar(name: "Momentum",  value: weights.momentum)
                weightBar(name: "Formasyon", value: weights.pattern)
                weightBar(name: "Volatilite", value: weights.volatility)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func weightBar(name: String, value: Double) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 88, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.textPrimary)
                        .frame(width: geo.size.width * min(1.0, value * 2.5), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)

            Text("%\(Int(value * 100))")
                .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Bileşen Performansı

    private var componentPerformanceSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bileşen performansı")
                    .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            let stats = symbol != nil && !symbolStats.isEmpty ? symbolStats : globalStats
            let sorted = stats.sorted(by: { $0.reliability > $1.reliability })

            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.component) { idx, stat in
                    if idx > 0 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, 14)
                    }
                    componentRow(stat)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func componentRow(_ stat: ComponentPerformanceService.ComponentStats) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(reliabilityColor(stat.reliability))
                .frame(width: 6, height: 6)

            Text(componentLabel(stat.component))
                .font(DesignTokens.Fonts.custom(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Kazanma %\(Int(stat.winRate))")
                    .font(DesignTokens.Fonts.custom(size: 12))
                    .foregroundColor(stat.winRate > 50
                                     ? InstitutionalTheme.Colors.aurora
                                     : InstitutionalTheme.Colors.crimson)
                    .monospacedDigit()
                Text("\(stat.signalCount) sinyal")
                    .font(DesignTokens.Fonts.custom(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .monospacedDigit()
            }

            Text(reliabilityLabel(stat.reliability))
                .font(DesignTokens.Fonts.custom(size: 11, weight: .medium))
                .foregroundColor(reliabilityColor(stat.reliability))
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// Mitoloji bileşen kodlarını sentence Türkçe'ye çevir.
    private func componentLabel(_ component: String) -> String {
        switch component.lowercased() {
        case "structure": return "Yapı"
        case "trend": return "Trend"
        case "momentum": return "Momentum"
        case "pattern": return "Formasyon"
        case "volatility": return "Volatilite"
        default: return component.capitalized
        }
    }

    // MARK: - Aksiyonlar
    //
    // 2026-05-04 H-62: "Şimdi öğren" tetikleyicisi.
    // Buton, sembol verilmişse `analyzeSymbol(symbol)`, yoksa
    // `runFullAnalysis()` çağırır. ChironLearningJob:
    //   1) ChironDataLakeService'ten trade history yükler (en az 5 trade)
    //   2) %95 güven aralığı kontrolü yapar (>15% ise erteler)
    //   3) Pulse + Corse motorlarını ayrı analiz eder
    //   4) 5+ trade varsa LLM ile, yoksa deterministic ağırlık önerir
    //   5) ChironWeightStore.updateWeights ile yazar
    //   6) ChironDataLakeService.logLearningEvent ile loglar
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Aksiyon")
                    .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if let flash = actionFlash {
                    Text(flash)
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.aurora)
                        .transition(.opacity)
                } else if let last = lastLearningAt {
                    Text("son · \(timeAgo(last))")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            Button(action: runLearning) {
                HStack(spacing: 10) {
                    if isLearning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(DesignTokens.Fonts.custom(size: 13))
                            .frame(width: 16)
                    }
                    Text(learningButtonTitle)
                        .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                    Spacer()
                    Text(symbol != nil ? "Sembol" : "Tüm portföy")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(InstitutionalTheme.Colors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(isLearning ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isLearning)

            Text(learningHint)
                .font(DesignTokens.Fonts.custom(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var learningButtonTitle: String {
        if isLearning {
            return symbol != nil ? "Bu sembol öğreniyor" : "Tüm portföy öğreniyor"
        }
        return symbol != nil ? "Bu sembolü öğren" : "Şimdi öğren"
    }

    private var learningHint: String {
        if symbol != nil {
            return "Bu sembol için trade geçmişi (≥5 işlem) analiz edilir, yeterli güven aralığı varsa Pulse / Corse ağırlıkları güncellenir."
        }
        return "Trade geçmişi olan tüm sembolleri tek tek analiz eder. Her birinde en az 5 işlem ve dar güven aralığı gerekir."
    }

    /// Chiron öğrenmeyi tetikle. `symbol` varsa onu, yoksa tüm portföyü.
    private func runLearning() {
        isLearning = true
        actionFlash = nil
        Task {
            if let sym = symbol {
                await ChironLearningJob.shared.analyzeSymbol(sym)
            } else {
                await ChironLearningJob.shared.runFullAnalysis()
            }
            await MainActor.run {
                self.lastLearningAt = Date()
                self.isLearning = false
                withAnimation { self.actionFlash = "Öğrenme tamam" }
                // Yeni ağırlıklar ve istatistikler için yeniden yükle.
                self.loadData()
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation { self.actionFlash = nil }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "şimdi" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) dk" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600)) sa" }
        return "\(Int(elapsed / 86400)) gün"
    }

    // MARK: - Helpers

    private func loadData() {
        globalStats = ComponentPerformanceService.shared.analyzeGlobalPerformance()

        if let sym = symbol {
            symbolStats = ComponentPerformanceService.shared.analyzePerformance(for: sym)
            learnedWeights = ChironRegimeEngine.shared.getLearnedOrionWeights(symbol: sym)
            learningStatus = ChironRegimeEngine.shared.getLearningStatus(symbol: sym)
        } else {
            learnedWeights = ComponentPerformanceService.shared.calculateLearnedWeights(symbol: nil)
            let totalSignals = globalStats.reduce(0) { $0 + $1.signalCount }
            learningStatus = (totalSignals >= 10, Double(min(totalSignals, 20)) / 20.0, "\(totalSignals) trade analiz edildi")
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value >= 0.7 { return InstitutionalTheme.Colors.aurora }
        if value >= 0.5 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func reliabilityColor(_ value: Double) -> Color {
        if value >= 0.6 { return InstitutionalTheme.Colors.aurora }
        if value >= 0.45 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func reliabilityLabel(_ value: Double) -> String {
        if value >= 0.6 { return "Güvenilir" }
        if value >= 0.45 { return "Nötr" }
        return "Zayıf"
    }
}

#Preview {
    NavigationStack {
        ChironInsightsView(symbol: "AAPL")
    }
}
