import SwiftUI

/// Alkindus — öğrenme paneli.
///
/// 2026-05-03 H-60: tam UI redesign + öğrenme akışı görünür hale getirildi.
///
/// Önceki yapı (880 satır, 9 ayrı bölüm) berbattı:
///   • headerCard, insights, dataTools, correlations, moduleCalibration,
///     regimeInsights, AlkindusTimeCard, marketComparison, pending
///     — kullanıcı hangi sayıya bakacağını bilmiyordu
///   • "Eventlerden öğren" butonu sadece konsola print yapıyordu
///     (`AlkindusEventProcessor.saveLearnings` calibration'a yazmıyor!)
///   • Veritabanı boyutu, blob temizle gibi dev-tool detayları kullanıcının
///     önündeydi
///   • "Bekleyen" sayısı en altta — esas KPI olması gereken bilgi gizliydi
///
/// Yeni yapı (~280 satır, 4 bölüm):
///   1. Özet KPI grid — gözlem, olgun, doğruluk, bekleyen
///   2. Modül performansı — sade bar listesi
///   3. Son değerlendirilen kararlar — verdict listesi
///   4. Manuel olgunlaştırma butonu + nasıl çalışıyor açıklaması
///
/// Public API korundu: `init(symbol: String? = nil)`.

struct AlkindusDashboardView: View {
    var symbol: String? = nil

    @State private var stats: AlkindusStats?
    @State private var verdicts: [AlkindusVerdict] = []
    @State private var pending: [PendingObservation] = []
    @State private var pendingCount: Int = 0
    @State private var symbolInsight: SymbolInsight?
    @State private var isLoading = true
    @State private var isMaturing = false
    @State private var isAnalyzing = false
    @State private var isCleaningUp = false
    @State private var isResetting = false
    @State private var showResetConfirmation = false
    @State private var showAdvanced = false
    @State private var analysisProgress: (done: Int, total: Int)? = nil
    @State private var lastMatureRun: Date?
    @State private var lastProcessingResult: ProcessingResult?
    @State private var dbSizeMB: Double = 0
    @State private var actionFlash: String?
    @State private var showDrawer = false

    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.dismiss) private var dismiss

    // 2026-05-04 H-61: isPushed detection genişletildi.
    // Eski: sadece `!router.navigationStack.isEmpty` — Settings →
    // NavigationLink ile push'ta router yolunu değiştirmediği için
    // false dönüyor, geri butonu gözükmüyordu.
    // Ara çözüm: `\.isPresented` ekledik ama nested NavigationLink
    // (Settings → Motor kalibrasyonu → Gözlem Paneli) zincirinde
    // güvenilir dönmüyordu — kullanıcı yine geri dönemiyordu.
    //
    // 2026-05-09: View tab root değil, her erişim push üzerinden geçiyor
    // (NavigationRouter case .alkindusDashboard veya Settings'ten
    // NavigationLink). `isPushed` artık daima true — geri butonu her
    // zaman görünür. Drawer menüsü de gerekmiyor; navigation hiyerarşisi
    // pop ile çözülür.
    private var isPushed: Bool { true }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "Öğrenme paneli",
                subtitle: symbol == nil ? "Argus karar geçmişi" : "Sembol: \(symbol!)",
                leadingDeco: isPushed ? .back(onTap: { dismiss() }) : .none,
                actions: isPushed
                    ? [.custom(sfSymbol: "arrow.clockwise", action: refresh)]
                    : [
                        .menu({ withAnimation(ArgusDrawerView.toggleAnimation) { showDrawer = true } }),
                        .custom(sfSymbol: "arrow.clockwise", action: refresh)
                      ]
            )

            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 16) {
                            if symbol != nil {
                                symbolInsightCard
                            }

                            // 2026-05-09 yeniden tasarım:
                            // 4 KPI grid + sayısal karmaşa kaldırıldı. Yerine
                            // 3 sade bölüm: 1) "şu an test edilen", 2) "son
                            // sonuçlar", 3) "öğrenilen örüntüler". En üstte
                            // tek cümlelik durum banner'ı, en altta katlanır
                            // "gelişmiş" bölümü. Kullanıcı her açışta net
                            // görür: ne dönüyor, ne öğrenildi, ne zaman gelecek.
                            heroStatusCard(stats: stats)

                            activeTestsCard

                            verdictsCard

                            learnedPatternsCard(stats: stats)

                            modulePerformanceCard(stats: stats)

                            advancedCard

                            Color.clear.frame(height: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
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
            await loadAll()
        }
    }

    // MARK: - Symbol bağlamı kartı

    @ViewBuilder
    private var symbolInsightCard: some View {
        if let sym = symbol {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bu sembol için okuma")
                        .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(sym)
                        .font(DesignTokens.Fonts.custom(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                if let insight = symbolInsight {
                    Text(insight.message)
                        .font(DesignTokens.Fonts.custom(size: 14))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)

                    insightStatRow(label: "En iyi modül",
                                   value: "\(displayName(for: insight.bestModule)) · %\(Int(insight.bestHitRate * 100))",
                                   color: InstitutionalTheme.Colors.aurora)
                    insightStatRow(label: "En zayıf modül",
                                   value: "\(displayName(for: insight.worstModule)) · %\(Int(insight.worstHitRate * 100))",
                                   color: InstitutionalTheme.Colors.crimson)
                    insightStatRow(label: "Toplam karar",
                                   value: "\(insight.totalDecisions)",
                                   color: InstitutionalTheme.Colors.textPrimary)
                } else {
                    Text("Bu sembol için en az 5 karar gerekli. Veriler biriktikçe burası dolacak.")
                        .font(DesignTokens.Fonts.custom(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
    }

    private func insightStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(DesignTokens.Fonts.custom(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                .foregroundColor(color)
                .monospacedDigit()
        }
    }

    // MARK: - 1. Hero Status (durum banner'ı)
    //
    // 2026-05-09: 4 KPI grid yerine tek cümlelik anlamlı durum.
    // Eski grid (Olgunlaşan / Doğruluk / Bekleyen / Son güncelleme)
    // tek başına anlam taşımayan rakamlar gösteriyordu — kullanıcı
    // "1024 bekleyen" görse bile öğrenme olduğunu sanıyordu.
    // Yeni banner: aktif test sayısı + en yakın sonuç ETA + öğrenilmiş
    // doğruluk yüzdesi (varsa).

    private func heroStatusCard(stats: AlkindusStats) -> some View {
        let activeCount = pending.filter { !$0.isFullyEvaluated }.count
        let totalEvaluated = verdicts.count
        let correctCount = verdicts.filter { $0.wasCorrect }.count
        let accuracy = totalEvaluated > 0 ? Double(correctCount) / Double(totalEvaluated) : 0
        let etaDays = daysUntilNextVerdict()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(activeCount > 0 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.textTertiary)
                    .frame(width: 6, height: 6)
                Text(heroHeadline(activeCount: activeCount, totalEvaluated: totalEvaluated))
                    .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
            }

            Text(heroDetail(activeCount: activeCount,
                            etaDays: etaDays,
                            totalEvaluated: totalEvaluated,
                            accuracy: accuracy))
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
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

    private func heroHeadline(activeCount: Int, totalEvaluated: Int) -> String {
        if activeCount == 0 && totalEvaluated == 0 {
            return "Henüz öğrenme döngüsü başlamadı"
        }
        if activeCount == 0 {
            return "Aktif test yok — yeni karar bekleniyor"
        }
        return "\(activeCount) sembol için 15 günlük test sürüyor"
    }

    private func heroDetail(activeCount: Int, etaDays: Int?, totalEvaluated: Int, accuracy: Double) -> String {
        var parts: [String] = []
        if let days = etaDays, activeCount > 0 {
            if days == 0 {
                parts.append("İlk sonuç bugün olgunlaşacak")
            } else if days == 1 {
                parts.append("İlk sonuç yarın olgunlaşacak")
            } else {
                parts.append("İlk sonuç \(days) gün sonra olgunlaşacak")
            }
        } else if activeCount == 0 && totalEvaluated == 0 {
            parts.append("Otopilot ya da sembol detayı bir karar üretince 7 ve 15 gün sonra otomatik test edilir.")
        }

        if totalEvaluated > 0 {
            parts.append("\(totalEvaluated) test tamamlandı, doğruluk %\(Int(accuracy * 100)).")
        }

        return parts.joined(separator: " · ")
    }

    private func daysUntilNextVerdict() -> Int? {
        let now = Date()
        let upcoming: [Int] = pending.flatMap { obs -> [Int] in
            obs.horizons
                .filter { !obs.evaluatedHorizons.contains($0) }
                .map { horizon in
                    let target = Calendar.current.date(byAdding: .day, value: horizon, to: obs.decisionDate) ?? obs.decisionDate
                    let secondsLeft = target.timeIntervalSince(now)
                    return max(0, Int(ceil(secondsLeft / 86400)))
                }
        }
        return upcoming.min()
    }

    // MARK: - 2. Modül Performansı

    private func modulePerformanceCard(stats: AlkindusStats) -> some View {
        let modules = aggregatedModulePerformance(stats: stats)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Modül performansı")
                    .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if !modules.isEmpty {
                    Text("\(modules.count) modül")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            if modules.isEmpty {
                Text("Henüz veri yok. Kararlar olgunlaştıkça burada modüllerin doğruluk oranı görünür.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(modules, id: \.module) { entry in
                        moduleRow(name: entry.module,
                                  hitRate: entry.hitRate,
                                  attempts: entry.attempts)
                    }
                }
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

    private func moduleRow(name: String, hitRate: Double, attempts: Double) -> some View {
        HStack(spacing: 10) {
            Text(displayName(for: name))
                .font(DesignTokens.Fonts.custom(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 88, alignment: .leading)

            ArgusBar(value: hitRate, color: scoreColor(hitRate), height: 4)

            Text("%\(Int(hitRate * 100))")
                .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                .foregroundColor(scoreColor(hitRate))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)

            Text("\(Int(attempts))")
                .font(DesignTokens.Fonts.custom(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    /// Modül başına tüm bracket'lerin ağırlıklı ortalama doğruluk oranı.
    private func aggregatedModulePerformance(stats: AlkindusStats)
    -> [(module: String, hitRate: Double, attempts: Double)] {
        var rows: [(String, Double, Double)] = []
        for (module, cal) in stats.calibration.modules {
            let totalAttempts = cal.brackets.values.reduce(0.0) { $0 + $1.attempts }
            let totalCorrect  = cal.brackets.values.reduce(0.0) { $0 + $1.correct }
            guard totalAttempts >= 3 else { continue }
            let rate = totalCorrect / totalAttempts
            rows.append((module, rate, totalAttempts))
        }
        return rows.sorted(by: { $0.1 > $1.1 })
    }

    // MARK: - 3. Son değerlendirilen kararlar

    private var verdictsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Son değerlendirilen kararlar")
                    .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if !verdicts.isEmpty {
                    Text("son \(min(8, verdicts.count))")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            if verdicts.isEmpty {
                Text("Henüz olgunlaşmış karar yok. Her karar 7 ve 15 gün sonra otomatik değerlendirilir.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    let sorted = verdicts.sorted(by: { $0.evaluationDate > $1.evaluationDate }).prefix(8)
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, verdict in
                        verdictRow(verdict)
                        if idx < sorted.count - 1 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                        }
                    }
                }
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

    private func verdictRow(_ verdict: AlkindusVerdict) -> some View {
        HStack(spacing: 10) {
            Image(systemName: verdict.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(DesignTokens.Fonts.custom(size: 14))
                .foregroundColor(verdict.wasCorrect
                                 ? InstitutionalTheme.Colors.aurora
                                 : InstitutionalTheme.Colors.crimson)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verdict.symbol)
                        .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(verdict.action == "BUY" ? "al" : "sat")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("· T+\(verdict.horizon)g")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                Text("Değerlendirildi · \(timeAgo(verdict.evaluationDate))")
                    .font(DesignTokens.Fonts.custom(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Spacer()

            Text(String(format: "%+.1f%%", verdict.priceChange))
                .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                .foregroundColor(verdict.priceChange >= 0
                                 ? InstitutionalTheme.Colors.aurora
                                 : InstitutionalTheme.Colors.crimson)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }

    // MARK: - 2. Şu an test edilen
    //
    // 2026-05-09: Pending observations'ı geri sayımla göster. Kullanıcı
    // hangi semboller için aktif öğrenme döngüsü çalıştığını ve ne zaman
    // sonuç geleceğini somut görür.

    private var activeTestsCard: some View {
        let active = pending
            .filter { !$0.isFullyEvaluated }
            .sorted { lhs, rhs in nextHorizonDate(for: lhs) < nextHorizonDate(for: rhs) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Şu an test edilen")
                    .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if !active.isEmpty {
                    Text("\(active.count) sembol")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            if active.isEmpty {
                Text("Aktif test yok. Otopilot taraması ya da sembol detay açılması yeni test başlatır.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    let display = Array(active.prefix(8))
                    ForEach(Array(display.enumerated()), id: \.element.id) { idx, obs in
                        activeTestRow(obs)
                        if idx < display.count - 1 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5)
                        }
                    }
                    if active.count > 8 {
                        Text("…ve \(active.count - 8) tane daha")
                            .font(DesignTokens.Fonts.custom(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .padding(.top, 8)
                    }
                }
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

    private func activeTestRow(_ obs: PendingObservation) -> some View {
        let nextHorizon = obs.horizons.first { !obs.evaluatedHorizons.contains($0) } ?? obs.horizons.last ?? 15
        let target = Calendar.current.date(byAdding: .day, value: nextHorizon, to: obs.decisionDate) ?? obs.decisionDate
        let now = Date()
        let daysLeft = max(0, Int(ceil(target.timeIntervalSince(now) / 86400)))
        let actionLabel: String = {
            switch obs.action {
            case "BUY":    return "al"
            case "SELL":   return "sat"
            case "HOLD":   return "bekle"
            case "VETOED": return "veto"
            default:       return obs.action.lowercased()
            }
        }()

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(obs.symbol)
                        .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(actionLabel)
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("· T+\(nextHorizon)g")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                Text("Başlangıç \(timeAgo(obs.decisionDate))")
                    .font(DesignTokens.Fonts.custom(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Spacer()
            Text(daysLeft == 0 ? "bugün olgunlaşacak"
                 : daysLeft == 1 ? "1 gün kaldı"
                 : "\(daysLeft) gün kaldı")
                .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                .foregroundColor(daysLeft <= 1 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }

    private func nextHorizonDate(for obs: PendingObservation) -> Date {
        let nextHorizon = obs.horizons.first { !obs.evaluatedHorizons.contains($0) } ?? obs.horizons.last ?? 15
        return Calendar.current.date(byAdding: .day, value: nextHorizon, to: obs.decisionDate) ?? obs.decisionDate
    }

    // MARK: - 4. Öğrenilen örüntüler
    //
    // 2026-05-09: Calibration data'dan düz Türkçe cümleler türet.
    // Ham bracket istatistiği değil, kullanıcının okuyabileceği tespit:
    // "Risk-On rejiminde Teknik (%72)" gibi.

    private func learnedPatternsCard(stats: AlkindusStats) -> some View {
        let patterns = derivedPatterns(stats: stats)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Öğrenilen örüntüler")
                    .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if !patterns.isEmpty {
                    Text("\(patterns.count) tespit")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }

            if patterns.isEmpty {
                Text("Henüz örüntü yok. Tamamlanmış testler arttıkça modül × rejim performans tespiti burada cümleyle çıkar.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(patterns.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(InstitutionalTheme.Colors.aurora)
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)
                            Text(line)
                                .font(DesignTokens.Fonts.custom(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                    }
                }
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

    private func derivedPatterns(stats: AlkindusStats) -> [String] {
        var lines: [String] = []

        // 1. En güçlü modül-rejim eşleşmeleri (en az 5 attempt)
        var regimeBest: [(regime: String, module: String, rate: Double, attempts: Int)] = []
        for (regime, insight) in stats.calibration.regimes {
            for (module, attempts) in insight.moduleAttempts where attempts >= 5 {
                let correct = insight.moduleCorrect[module] ?? 0
                let rate = Double(correct) / Double(attempts)
                regimeBest.append((regime, module, rate, attempts))
            }
        }
        regimeBest.sort { $0.rate > $1.rate }

        for entry in regimeBest.prefix(2) where entry.rate >= 0.6 {
            let strength = entry.rate >= 0.7 ? "güçlü" : "iyi"
            lines.append("\(displayRegime(entry.regime)) rejiminde \(displayName(for: entry.module)) \(strength) çalışıyor (%\(Int(entry.rate * 100)) · \(entry.attempts) test).")
        }

        // 2. En zayıf modül-rejim (alarm değeri)
        if let worst = regimeBest.last, worst.rate < 0.4, worst.attempts >= 5 {
            lines.append("\(displayRegime(worst.regime)) rejiminde \(displayName(for: worst.module)) zayıf (%\(Int(worst.rate * 100)) · \(worst.attempts) test).")
        }

        // 3. Yüksek skor bracket'inde modül performansı
        for (module, cal) in stats.calibration.modules {
            if let high = cal.brackets["80-100"], high.attempts >= 5 {
                let rate = high.hitRate
                if rate >= 0.7 {
                    lines.append("\(displayName(for: module)) %80+ skor verdiğinde %\(Int(rate * 100)) doğru — yüksek güven sinyali.")
                } else if rate < 0.45 {
                    lines.append("\(displayName(for: module)) %80+ skor verdiğinde sadece %\(Int(rate * 100)) doğru — yüksek güven sinyali güvenilmez.")
                }
            }
        }

        return Array(lines.prefix(5))
    }

    private func displayRegime(_ regime: String) -> String {
        switch regime.lowercased() {
        case "riskon", "risk_on", "risk-on": return "Risk-On"
        case "riskoff", "risk_off", "risk-off": return "Risk-Off"
        case "neutral", "nötr": return "Nötr"
        case "transition", "geçiş": return "Geçiş"
        default: return regime.capitalized
        }
    }

    // MARK: - 5. Gelişmiş (katlanır)
    //
    // Eski actionsCard + howItWorksCard tek bir "gelişmiş" başlığı altında
    // toplandı. Varsayılan kapalı; kullanıcı manuel olgunlaştırma, analiz,
    // temizlik, sıfırlama isterse açar. Her gün dashboard'u açan kullanıcının
    // bu butonlara her seferinde maruz kalmaması için.

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text("Gelişmiş")
                        .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: 10) {
                    Color.clear.frame(height: 4)

                    if let flash = actionFlash {
                        Text(flash)
                            .font(DesignTokens.Fonts.custom(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.aurora)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    actionRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: isMaturing ? "Olgunlaştırma çalışıyor" : "Şimdi olgunlaştır",
                        trailing: "\(pendingCount) bekliyor",
                        isRunning: isMaturing,
                        disabled: isMaturing || isAnalyzing || isCleaningUp || isResetting,
                        action: runMaturation
                    )

                    actionRow(
                        icon: "chart.bar.doc.horizontal",
                        title: analysisTitle,
                        trailing: analysisTrailing,
                        isRunning: isAnalyzing,
                        disabled: isMaturing || isAnalyzing || isCleaningUp || isResetting,
                        action: runAnalysis
                    )

                    actionRow(
                        icon: "trash",
                        title: isCleaningUp ? "Veritabanı temizleniyor" : "Eski kayıtları temizle",
                        trailing: dbSizeMB > 0 ? String(format: "%.1f MB", dbSizeMB) : nil,
                        isRunning: isCleaningUp,
                        disabled: isMaturing || isAnalyzing || isCleaningUp || isResetting,
                        action: runCleanup
                    )

                    actionRow(
                        icon: "exclamationmark.arrow.circlepath",
                        title: isResetting ? "Sıfırlanıyor" : "Öğrenmeyi sıfırla",
                        trailing: nil,
                        isRunning: isResetting,
                        disabled: isMaturing || isAnalyzing || isCleaningUp || isResetting,
                        action: { showResetConfirmation = true }
                    )

                    Text("Şimdi olgunlaştır: bekleyen testleri zamanı gelmişse hemen değerlendirir. Sıfırla: tüm öğrenmeyi siler — bozuk eski veriyi temizlemek için. Sıfırlamadan sonra ilk gerçek sonuç ~7 gün sonra gelir.")
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                        .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    InstitutionalTheme.Colors.borderSubtle,
                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Öğrenmeyi sıfırla?", isPresented: $showResetConfirmation) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive) { runReset() }
        } message: {
            Text("Tüm bekleyen testler, sonuçlar ve öğrenilmiş kalibrasyon silinir. İlk gerçek sonuç yeniden ~7 gün sonra olgunlaşır. Geri alınamaz.")
        }
    }

    /// Analiz butonunun başlık metni — çalışırken ilerleme göstergesi.
    private var analysisTitle: String {
        if isAnalyzing {
            if let p = analysisProgress, p.total > 0 {
                return "Analiz · \(p.done)/\(p.total)"
            }
            return "Analiz çalışıyor"
        }
        return "Verileri analiz et"
    }

    /// Analiz butonu sağ trailing — son analiz sonucu özet.
    private var analysisTrailing: String? {
        guard !isAnalyzing else { return nil }
        if let r = lastProcessingResult, r.eventsProcessed > 0 {
            return "son \(r.eventsProcessed) event"
        }
        return nil
    }

    /// Sade aksiyon satırı — ikon + title + opsiyonel trailing + ProgressView.
    private func actionRow(icon: String,
                           title: String,
                           trailing: String?,
                           isRunning: Bool,
                           disabled: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(DesignTokens.Fonts.custom(size: 13))
                        .frame(width: 16)
                }
                Text(title)
                    .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .monospacedDigit()
                }
            }
            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(InstitutionalTheme.Colors.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(disabled ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // 2026-05-09: howItWorksCard kaldırıldı.
    // Nasıl çalıştığı bilgisi artık heroStatusCard ve advancedCard içindeki
    // dipnotlardan akıyor; ayrı kart kullanıcıya tekrar dilden gelen bir
    // ekran daha ekliyordu.

    // MARK: - Empty state

    // 2026-05-09: Boş hâl artık dürüst.
    // Eski metin "istatistikler burada görünecek" diyordu ama uygulama
    // 6 ay boyunca veri toplamış görünüp hiç olgunlaşmadığında bu mesaj
    // anlamsızlaşıyordu. Yeni metin somut: ilk sonuç tarihi tahmini +
    // ne yapılması gerektiği. Otopilot tarama yoksa kullanıcıya neden
    // veri gelmediğini söylüyor.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(DesignTokens.Fonts.custom(size: 28))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Henüz öğrenme döngüsü başlamadı")
                .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text("Otopilot tarama yapınca ya da bir sembol detayı açınca Argus karar üretir; o karar 7 ve 15 gün sonra otomatik test edilir. İlk sonuç en erken bir hafta sonra olgunlaşır.")
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(2)
        }
    }

    // MARK: - Helpers

    /// Motor adından kullanıcıya gösterilecek işlev karşılığı.
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

    private func scoreColor(_ rate: Double) -> Color {
        if rate >= 0.6 { return InstitutionalTheme.Colors.aurora }
        if rate >= 0.45 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "şimdi" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) dk önce" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600)) sa önce" }
        return "\(Int(elapsed / 86400)) gün önce"
    }

    // MARK: - Drawer

    private func drawerSections(openSheet: @escaping (ArgusDrawerView.DrawerSheet) -> Void) -> [ArgusDrawerView.DrawerSection] {
        let dismiss = ArgusDrawerView.dismissClosure($showDrawer)

        return [
            ArgusDrawerView.commonScreensSection(excluding: [.alkindus], dismiss: dismiss),
            ArgusDrawerView.commonToolsSection(openSheet: openSheet, dismiss: dismiss)
        ]
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        async let s = AlkindusCalibrationEngine.shared.getCurrentStats()
        async let v = AlkindusMemoryStore.shared.loadVerdicts()
        async let p = AlkindusMemoryStore.shared.loadPendingObservations()

        let (stats, verdicts, pending) = await (s, v, p)

        var freshInsight: SymbolInsight? = nil
        if let sym = symbol {
            freshInsight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: sym)
        }

        // Aksiyon kartının "Eski kayıtları temizle" satırında gösterilecek
        // DB boyutu bilgisi.
        let size = AlkindusEventProcessor.shared.getDatabaseSizeMB()

        await MainActor.run {
            self.stats = stats
            self.verdicts = verdicts
            self.pending = pending
            self.pendingCount = pending.count
            self.symbolInsight = freshInsight
            self.dbSizeMB = size
            self.isLoading = false
        }
    }

    private func refresh() {
        Task { await loadAll() }
    }

    /// Manuel olgunlaştırma — bekleyen tüm gözlemleri olgunluk durumuna göre
    /// değerlendirir. Eski "Eventlerden öğren" butonu (sadece print yapıyordu)
    /// yerine gerçek öğrenme tetikleyicisi.
    private func runMaturation() {
        isMaturing = true
        actionFlash = nil
        Task {
            await AlkindusCalibrationEngine.shared.periodicMatureCheck()
            await MainActor.run {
                self.lastMatureRun = Date()
                self.isMaturing = false
                withAnimation { self.actionFlash = "Güncellendi" }
            }
            await loadAll()
            await clearFlashAfterDelay()
        }
    }

    /// Verileri analiz et — `AlkindusEventProcessor.processHistoricalEvents`
    /// SQLite'deki işlenmemiş eventleri (decision'ları) batch-batch okur,
    /// modül × skor × aksiyon paternlerini çıkartır, calibration'a yazar.
    /// Sonuç: kaç event işlendi, kaç patern çıktı, hangi modüller öğrendi.
    /// Component performance cache'i de yenilenir ki KPI'lar tazelensin.
    private func runAnalysis() {
        isAnalyzing = true
        actionFlash = nil
        analysisProgress = (0, 0)
        Task {
            // 1) Gerçek event analizi — DB'deki tüm processed=0 eventler.
            let result = await AlkindusEventProcessor.shared.processHistoricalEvents { done, total in
                Task { @MainActor in
                    self.analysisProgress = (done, total)
                }
            }

            // 2) Component performance cache → taze hesap.
            ComponentPerformanceService.shared.clearCache()

            // 3) Sembol özelinde içgörü.
            var freshInsight: SymbolInsight? = nil
            if let sym = symbol {
                freshInsight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: sym)
            }

            // 4) DB boyutu — temizleme sonrası karşılaştırma için.
            let size = AlkindusEventProcessor.shared.getDatabaseSizeMB()

            await MainActor.run {
                self.symbolInsight = freshInsight
                self.lastProcessingResult = result
                self.dbSizeMB = size
                self.analysisProgress = nil
                self.isAnalyzing = false

                let msg: String
                if result.eventsProcessed == 0 {
                    msg = "İşlenecek event yok"
                } else {
                    msg = "\(result.eventsProcessed) event · \(result.patternsExtracted) patern"
                }
                withAnimation { self.actionFlash = msg }
            }
            await loadAll()
            await clearFlashAfterDelay()
        }
    }

    /// Eski kayıtları temizle — `deleteProcessedBlobs` blobs tablosunu
    /// siler ve VACUUM ile diski geri kazanır. Calibration ve verdict
    /// verisi etkilenmez (ayrı dosya/store'larda). DataLake ve ledger
    /// processed event'leri de süpürülür.
    private func runCleanup() {
        isCleaningUp = true
        actionFlash = nil
        Task {
            // Önce/sonra DB boyutu — kullanıcı geri kazanılan alanı görsün.
            let beforeMB = AlkindusEventProcessor.shared.getDatabaseSizeMB()

            // 1) Alkindus event blob'ları — DELETE FROM blobs + VACUUM.
            AlkindusEventProcessor.shared.deleteProcessedBlobs()
            // İşlenmiş eventleri de processed=1 işaretle (yeniden tetiklenmesin).
            AlkindusEventProcessor.shared.markEventsAsProcessed()

            // 2) DataLake — 7+ gün öncesi senkronlanmış kayıtlar.
            let lakeDeleted = await ChironDataLakeService.shared.cleanupSyncedRecords(olderThanDays: 7)

            // 3) Ledger — işlenmiş eventler.
            await ArgusLedger.shared.cleanupProcessedEvents()

            let afterMB = AlkindusEventProcessor.shared.getDatabaseSizeMB()
            let reclaimed = max(0, beforeMB - afterMB)

            await MainActor.run {
                self.dbSizeMB = afterMB
                self.isCleaningUp = false
                let msg: String
                if reclaimed >= 0.1 {
                    msg = String(format: "%.1f MB geri kazanıldı", reclaimed)
                } else if lakeDeleted > 0 {
                    msg = "\(lakeDeleted) lake kaydı silindi"
                } else {
                    msg = "Temiz"
                }
                withAnimation { self.actionFlash = msg }
            }
            await clearFlashAfterDelay()
        }
    }

    /// 2026-05-09: Tüm öğrenme verisini sıfırla.
    /// pending_observations.json + alkindus_verdicts.json + calibration.json
    /// silinir. Eski FIFO cap'i tarafından buduulmuş bozuk veri için temiz
    /// başlangıç sağlar. Ardından KPI'lar boşalır, ilk gerçek verdict ~7 gün
    /// sonra olgunlaşır.
    private func runReset() {
        isResetting = true
        actionFlash = nil
        Task {
            await AlkindusMemoryStore.shared.resetLearning()
            ComponentPerformanceService.shared.clearCache()

            await MainActor.run {
                self.isResetting = false
                withAnimation { self.actionFlash = "Öğrenme sıfırlandı" }
            }
            await loadAll()
            await clearFlashAfterDelay()
        }
    }

    /// Aksiyon flash mesajını 2 sn sonra temizler.
    private func clearFlashAfterDelay() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            withAnimation { self.actionFlash = nil }
        }
    }
}

#Preview {
    AlkindusDashboardView()
}
