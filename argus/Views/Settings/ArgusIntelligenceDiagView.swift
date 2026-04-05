import SwiftUI

// MARK: - Argus Intelligence Diagnostic View
/// Faz 1 Teşhis: Öğrenme sisteminin gerçekten çalışıp çalışmadığını tek bakışta gösterir.
/// Settings → "Sistem Zekası" menüsünden erişilir.

struct ArgusIntelligenceDiagView: View {

    // MARK: - State
    @State private var snapshot: DiagSnapshot? = nil
    @State private var isLoading = true
    @State private var isFlushingRAG = false
    @State private var lastRefresh = Date()

    // Yeni sistemler
    @State private var velocityData: VelocityDiagData? = nil
    @State private var kellyData: KellyDiagData? = nil
    @State private var oppCostData: OppCostDiagData? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                diagHeader

                if isLoading {
                    ProgressView("Analiz ediliyor...")
                        .padding(60)
                        .foregroundColor(.gray)
                } else if let s = snapshot {
                    // Overall health banner
                    overallBanner(s)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Sections
                    diagSection("TRADE LOG", icon: "chart.bar.fill", color: .blue) {
                        tradeSection(s.trade)
                    }
                    diagSection("CHİRON ÖĞRENMESİ", icon: "brain", color: .purple) {
                        chironSection(s.chiron)
                    }
                    diagSection("ALKİNDUS KALİBRASYON", icon: "eye.fill", color: .yellow) {
                        alkindusSection(s.alkindus)
                    }
                    diagSection("RAG SYNC KUYRUĞU", icon: "arrow.clockwise.icloud", color: .cyan) {
                        ragSection(s.rag)
                    }

                    // ─── Yeni İstihbarat Sistemleri ───────────────────────
                    diagSection("AETHER HIZ ANALİZİ", icon: "speedometer", color: .mint) {
                        velocitySection()
                    }
                    diagSection("KELLY POZİSYON BOYUTU", icon: "chart.pie.fill", color: .indigo) {
                        kellySection()
                    }
                    diagSection("PORTFÖY KORELASYON ISISI", icon: "network", color: .teal) {
                        correlSection()
                    }
                    diagSection("KRİZ ALFA FIRSAT", icon: "bolt.fill", color: .red) {
                        crisisSection()
                    }
                    diagSection("FIRSATÇILIK MALİYETİ", icon: "dollarsign.arrow.circlepath", color: .orange) {
                        oppCostSection()
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Sistem Zekası Tanı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.tint)
                }
            }
        }
        .task { await reload() }
    }

    // MARK: - Header

    private var diagHeader: some View {
        HStack(spacing: 12) {
            AlkindusAvatarView(size: 36, isThinking: isLoading, hasIdea: !isLoading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Öğrenme Sistemi Tanısı")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("Son güncelleme: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Overall Banner

    @ViewBuilder
    private func overallBanner(_ s: DiagSnapshot) -> some View {
        let health = s.overallHealth
        HStack(spacing: 12) {
            Image(systemName: health.icon)
                .font(.title2)
                .foregroundColor(health.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(health.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(health.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(health.color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(health.color.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Trade Section

    @ViewBuilder
    private func tradeSection(_ t: TradeStats) -> some View {
        if t.total == 0 {
            emptyState("Henüz kaydedilmiş trade yok")
        } else {
            HStack(spacing: 0) {
                bigStat(value: "\(t.total)", label: "Toplam Trade")
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(value: t.winRateText, label: "Kazanma Oranı", color: t.winRate >= 0.5 ? .green : .red)
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(value: "\(t.winCount)W / \(t.lossCount)L", label: "Kazanan / Kaybeden")
            }
            .padding(.vertical, 8)

            if let last = t.lastTradeDate {
                diagRow(label: "Son trade", value: last.formatted(date: .abbreviated, time: .omitted))
            }
            if let regime = t.lastRegime {
                diagRow(label: "Son rejim", value: regime)
            }
        }
    }

    // MARK: - Chiron Section

    @ViewBuilder
    private func chironSection(_ c: ChironStats) -> some View {
        HStack(spacing: 0) {
            bigStat(value: "\(c.experienceCount)", label: "Deneyim")
            Divider().frame(height: 40).background(Color.white.opacity(0.1))
            bigStat(
                value: String(format: "%.0f", c.healthScore),
                label: "Sağlık Skoru",
                color: c.healthScore >= 70 ? .green : c.healthScore >= 40 ? .orange : .red
            )
            Divider().frame(height: 40).background(Color.white.opacity(0.1))
            bigStat(value: c.regime, label: "Rejim")
        }
        .padding(.vertical, 8)

        diagRow(label: "Son güncelleme", value: c.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "Hiç güncellenmedi")
        diagRow(label: "Durum", value: c.isHealthy ? "Sağlıklı" : "Dikkat gerekiyor", valueColor: c.isHealthy ? .green : .orange)

        if c.experienceCount == 0 {
            warningBadge("Chiron hiç deneyim kazanmamış — trade kapatılınca öğrenme başlayacak")
        }
    }

    // MARK: - Alkindus Section

    @ViewBuilder
    private func alkindusSection(_ a: AlkindusStats2) -> some View {
        HStack(spacing: 0) {
            bigStat(value: "\(a.pendingCount)", label: "Bekleyen Gözlem")
            Divider().frame(height: 40).background(Color.white.opacity(0.1))
            bigStat(value: "\(a.verdictCount)", label: "Tamamlanan Analiz")
            Divider().frame(height: 40).background(Color.white.opacity(0.1))
            bigStat(
                value: a.verdictCount > 0 ? String(format: "%.0f%%", a.correctRate * 100) : "—",
                label: "Doğruluk",
                color: a.correctRate >= 0.55 ? .green : a.correctRate >= 0.45 ? .orange : .red
            )
        }
        .padding(.vertical, 8)

        if let top = a.topModule {
            diagRow(label: "En İyi Modül", value: "\(top.name) — \(Int(top.hitRate * 100))%", valueColor: .green)
        }
        if let weak = a.weakestModule {
            diagRow(label: "En Zayıf Modül", value: "\(weak.name) — \(Int(weak.hitRate * 100))%", valueColor: .orange)
        }
        diagRow(label: "Son kalibrasyon", value: a.lastCalibration?.formatted(date: .abbreviated, time: .omitted) ?? "Hiç yapılmadı")

        if a.pendingCount == 0 && a.verdictCount == 0 {
            warningBadge("Alkindus hiç gözlem yapmamış — Argus'un BUY/SELL kararları geldikçe dolacak")
        }
    }

    // MARK: - RAG Section

    @ViewBuilder
    private func ragSection(_ r: RAGStats2) -> some View {
        HStack(spacing: 0) {
            bigStat(
                value: "\(r.pendingCount)",
                label: "Bekleyen Sync",
                color: r.pendingCount == 0 ? .green : r.pendingCount < 10 ? .orange : .red
            )
        }
        .padding(.vertical, 8)

        if r.pendingCount > 0 {
            Button {
                Task {
                    isFlushingRAG = true
                    await AlkindusSyncRetryQueue.shared.processRetryQueue()
                    isFlushingRAG = false
                    await reload()
                }
            } label: {
                HStack {
                    if isFlushingRAG {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise.icloud")
                    }
                    Text(isFlushingRAG ? "Gönderiliyor..." : "Şimdi Pinecone'a Gönder (\(r.pendingCount) adet)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cyan)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
        } else {
            diagRow(label: "Durum", value: "Tüm öğrenmeler senkronize", valueColor: .green)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func diagSection<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .tracking(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func bigStat(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func diagRow(label: String, value: String, valueColor: Color = Color(white: 0.75)) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
    }

    @ViewBuilder
    private func warningBadge(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.gray)
            .italic()
            .padding(16)
    }

    // MARK: - Data Loading

    private func reload() async {
        isLoading = true
        async let tradeStats = loadTradeStats()
        async let chironStats = loadChironStats()
        async let alkindusStats = loadAlkindusStats()
        async let ragStats = loadRAGStats()
        async let velData = loadVelocityData()
        async let klyData = loadKellyData()
        async let ocData = loadOppCostData()

        let (t, c, a, r) = await (tradeStats, chironStats, alkindusStats, ragStats)
        snapshot = DiagSnapshot(trade: t, chiron: c, alkindus: a, rag: r)
        velocityData = await velData
        kellyData = await klyData
        oppCostData = await ocData
        lastRefresh = Date()
        isLoading = false
    }

    private func loadTradeStats() async -> TradeStats {
        let logs = TradeLogStore.shared.fetchLogs()
        let wins = logs.filter { $0.isWin }
        return TradeStats(
            total: logs.count,
            winCount: wins.count,
            lossCount: logs.count - wins.count,
            lastTradeDate: logs.last?.date,
            lastRegime: logs.last?.entryRegime.rawValue
        )
    }

    private func loadChironStats() async -> ChironStats {
        let state = await ChironLearningSystem.shared.getCurrentState()
        let data = await ChironLearningSystem.shared.exportLearningData()
        let expCount = (data["experienceCount"] as? Int) ?? 0
        return ChironStats(
            experienceCount: expCount,
            healthScore: state.healthScore,
            regime: state.regime.rawValue,
            lastUpdated: state.lastUpdated,
            isHealthy: state.isHealthy
        )
    }

    private func loadAlkindusStats() async -> AlkindusStats2 {
        let stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
        let verdicts = await AlkindusMemoryStore.shared.loadVerdicts()
        let correctCount = verdicts.filter { $0.wasCorrect }.count
        return AlkindusStats2(
            pendingCount: stats.pendingCount,
            verdictCount: verdicts.count,
            correctRate: verdicts.isEmpty ? 0 : Double(correctCount) / Double(verdicts.count),
            topModule: stats.topModule,
            weakestModule: stats.weakestModule,
            lastCalibration: stats.lastUpdated
        )
    }

    private func loadRAGStats() async -> RAGStats2 {
        let count = await AlkindusSyncRetryQueue.shared.queueCount()
        return RAGStats2(pendingCount: count)
    }

    private func loadVelocityData() async -> VelocityDiagData {
        let analysis = await AetherVelocityEngine.shared.analyze()
        return VelocityDiagData(
            signal: analysis.signal.rawValue,
            velocity: analysis.velocity,
            currentScore: analysis.currentScore,
            crossingAlert: analysis.crossingAlert?.description,
            signalColor: velocitySignalColor(analysis.signal)
        )
    }

    private func loadKellyData() async -> KellyDiagData {
        let profile = await KellyCache.shared.getSystemProfile()
        let confText: String
        switch profile.confidence {
        case .low(let r): confText = "Düşük (\(r))"
        case .medium:     confText = "Orta"
        case .high:       confText = "Yüksek"
        }
        return KellyDiagData(
            winRate: profile.winRate,
            kellyFraction: profile.kellyFraction,
            effectiveFraction: profile.effectiveFraction,
            positionMultiplier: profile.positionMultiplier,
            sampleSize: profile.sampleSize,
            confidence: confText,
            avgWinPct: profile.avgWinPct,
            avgLossPct: profile.avgLossPct
        )
    }

    private func loadOppCostData() async -> OppCostDiagData {
        let summary = await OpportunityCostTracker.shared.getSummary(lastNDays: 30)
        let signal = await OpportunityCostTracker.shared.calibrationSignal()
        return OppCostDiagData(
            totalMissed: summary.totalMissed,
            goodSkips: summary.goodSkips,
            missedGains: summary.missedGains,
            avgMissedReturn: summary.avgMissedReturn,
            skipAccuracy: summary.skipAccuracy,
            calibrationSignal: signal.description,
            isTooCautious: summary.isTooCautious,
            isWellCalibrated: summary.isWellCalibrated
        )
    }

    // MARK: - New Intelligence Sections

    @ViewBuilder
    private func velocitySection() -> some View {
        if let v = velocityData {
            HStack(spacing: 0) {
                bigStat(
                    value: String(format: "%.1f", v.currentScore),
                    label: "Mevcut Aether",
                    color: v.currentScore >= 55 ? .green : v.currentScore >= 35 ? .orange : .red
                )
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(
                    value: String(format: "%+.1f/gün", v.velocity),
                    label: "Hız",
                    color: v.velocity > 0 ? .green : v.velocity < 0 ? .red : .gray
                )
            }
            .padding(.vertical, 8)

            diagRow(label: "Sinyal", value: v.signal, valueColor: v.signalColor)
            if let alert = v.crossingAlert {
                diagRow(label: "Eşik Uyarısı", value: alert, valueColor: .yellow)
            } else {
                diagRow(label: "Eşik Uyarısı", value: "Yok", valueColor: .gray)
            }
        } else {
            emptyState("Henüz Aether kaydı yok — sistem çalışmaya başlayınca dolacak")
        }
    }

    @ViewBuilder
    private func kellySection() -> some View {
        if let k = kellyData {
            HStack(spacing: 0) {
                bigStat(
                    value: String(format: "%.0f%%", k.winRate * 100),
                    label: "Kazanma Oranı",
                    color: k.winRate >= 0.55 ? .green : k.winRate >= 0.45 ? .orange : .red
                )
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(
                    value: String(format: "%.2f", k.kellyFraction),
                    label: "Kelly f*",
                    color: .white
                )
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(
                    value: String(format: "%.2fx", k.positionMultiplier),
                    label: "Pozisyon Çarpanı",
                    color: k.positionMultiplier >= 1.0 ? .green : k.positionMultiplier >= 0.5 ? .orange : .red
                )
            }
            .padding(.vertical, 8)

            diagRow(label: "Güven", value: k.confidence,
                    valueColor: k.confidence.contains("Yüksek") ? .green : k.confidence.contains("Orta") ? .orange : .red)
            diagRow(label: "Örneklem", value: "\(k.sampleSize) verdict")
            diagRow(label: "Ort. Kazanç / Kayıp", value: String(format: "%.1f%% / %.1f%%", k.avgWinPct, k.avgLossPct))
            if k.sampleSize < 10 {
                warningBadge("Yeterli veri yok — \(k.sampleSize) örnek. Kelly güvenilir olmak için 10+ gerektirir")
            }
        } else {
            emptyState("Yükleniyor...")
        }
    }

    @ViewBuilder
    private func correlSection() -> some View {
        if let cr = TradeBrainExecutor.shared.lastCorrelResult {
            HStack(spacing: 0) {
                bigStat(
                    value: "\(cr.rawPositionCount)",
                    label: "Ham Pozisyon"
                )
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                bigStat(
                    value: String(format: "%.1f", cr.effectivePositionCount),
                    label: "Bağımsız Risk",
                    color: cr.rawPositionCount == 0 ? .gray :
                           cr.effectivePositionCount / Double(max(1, cr.rawPositionCount)) < 0.5 ? .red : .green
                )
            }
            .padding(.vertical, 8)

            diagRow(
                label: "Konsantrasyon",
                value: cr.concentrationRisk.label,
                valueColor: cr.concentrationRisk == .healthy ? .green :
                            cr.concentrationRisk == .moderate ? .yellow :
                            cr.concentrationRisk == .high ? .orange : .red
            )
            diagRow(
                label: "Yeni Alım Çarpanı",
                value: String(format: "%.0f%%", cr.positionMultiplier * 100),
                valueColor: cr.positionMultiplier >= 1.0 ? .green : cr.positionMultiplier > 0 ? .orange : .red
            )
            if !cr.groups.isEmpty {
                diagRow(label: "Gruplar", value: cr.groups.map { "\($0.label) (\($0.symbols.count))" }.joined(separator: ", "))
            }
            if cr.concentrationRisk == .critical {
                warningBadge("Kritik: Tüm pozisyonlar aynı risk grubunda — yeni alım engellendi")
            }
        } else {
            emptyState("Henüz korelasyon analizi yapılmadı — bir sonraki karar döngüsünde hesaplanacak")
        }
    }

    @ViewBuilder
    private func crisisSection() -> some View {
        let opps = TradeBrainExecutor.shared.lastCrisisOpportunities
        if opps.isEmpty {
            emptyState("Aktif kriz fırsatı yok — Aether < 35 olduğunda sistem otomatik tarar")
        } else {
            ForEach(Array(opps.enumerated()), id: \.offset) { _, opp in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(opp.symbol)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(opp.opportunityType.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                    }
                    HStack {
                        Text(String(format: "Güven: %.0f%%", opp.confidence * 100))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                        Text(String(format: "Boyut: %.0f%%", opp.positionSizeMultiplier * 100))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func oppCostSection() -> some View {
        if let oc = oppCostData {
            if oc.totalMissed == 0 {
                emptyState("Henüz değerlendirilen atlanan fırsat yok (7 günlük pencere bekleniyor)")
            } else {
                HStack(spacing: 0) {
                    bigStat(value: "\(oc.totalMissed)", label: "Toplam Atlama")
                    Divider().frame(height: 40).background(Color.white.opacity(0.1))
                    bigStat(
                        value: "\(oc.goodSkips)",
                        label: "Haklı Atlama",
                        color: .green
                    )
                    Divider().frame(height: 40).background(Color.white.opacity(0.1))
                    bigStat(
                        value: "\(oc.missedGains)",
                        label: "Kaçırılan Fırsat",
                        color: .red
                    )
                }
                .padding(.vertical, 8)

                diagRow(
                    label: "Atlama Doğruluğu",
                    value: String(format: "%.0f%%", oc.skipAccuracy * 100),
                    valueColor: oc.isWellCalibrated ? .green : oc.isTooCautious ? .orange : .yellow
                )
                diagRow(label: "Ort. Kaçırılan Getiri", value: String(format: "%+.1f%%", oc.avgMissedReturn),
                        valueColor: oc.avgMissedReturn > 5 ? .red : .gray)
                diagRow(label: "Kalibrasyon", value: oc.calibrationSignal,
                        valueColor: oc.isWellCalibrated ? .green : oc.isTooCautious ? .orange : .yellow)

                if oc.isTooCautious {
                    warningBadge("Sistem çok temkinli: Fırsatların büyük çoğunluğu kaçırılıyor — eşikler gözden geçirilmeli")
                }
            }
        } else {
            emptyState("Yükleniyor...")
        }
    }

    // MARK: - Velocity Color Helper

    private func velocitySignalColor(_ signal: AetherVelocityEngine.VelocitySignal) -> Color {
        switch signal {
        case .recoveringFast: return .green
        case .recovering:     return Color(red: 0.5, green: 0.9, blue: 0.3)
        case .stable:         return .gray
        case .deteriorating:  return .orange
        case .deterioratingFast: return .red
        }
    }
}

// MARK: - Data Models

private struct DiagSnapshot {
    let trade: TradeStats
    let chiron: ChironStats
    let alkindus: AlkindusStats2
    let rag: RAGStats2

    var overallHealth: HealthStatus {
        // Kırmızı: hiç veri yok
        if trade.total == 0 && chiron.experienceCount == 0 && alkindus.verdictCount == 0 {
            return .init(
                title: "Sistem Henüz Uyanmadı",
                subtitle: "Trade kapatıldıkça öğrenme başlayacak",
                icon: "moon.fill",
                color: .gray
            )
        }
        // Kırmızı: RAG birikmiş
        if rag.pendingCount > 20 {
            return .init(
                title: "Öğrenme Verisi Sıkışmış",
                subtitle: "\(rag.pendingCount) kayıt Pinecone'a gönderilemedi — internet bağlantısını kontrol et",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
        // Sarı: Chiron hasta
        if !chiron.isHealthy {
            return .init(
                title: "Chiron Dikkat Gerektiriyor",
                subtitle: "Sağlık skoru düşük — daha fazla trade gerekiyor",
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
        }
        // Yeşil
        return .init(
            title: "Sistem Çalışıyor",
            subtitle: "\(trade.total) trade · \(chiron.experienceCount) deneyim · \(alkindus.verdictCount) tamamlanan analiz",
            icon: "checkmark.seal.fill",
            color: .green
        )
    }
}

private struct TradeStats {
    let total: Int
    let winCount: Int
    let lossCount: Int
    let lastTradeDate: Date?
    let lastRegime: String?
    var winRate: Double { total == 0 ? 0 : Double(winCount) / Double(total) }
    var winRateText: String { total == 0 ? "—" : String(format: "%.0f%%", winRate * 100) }
}

private struct ChironStats {
    let experienceCount: Int
    let healthScore: Double
    let regime: String
    let lastUpdated: Date?
    let isHealthy: Bool
}

private struct AlkindusStats2 {
    let pendingCount: Int
    let verdictCount: Int
    let correctRate: Double
    let topModule: (name: String, hitRate: Double)?
    let weakestModule: (name: String, hitRate: Double)?
    let lastCalibration: Date?
}

private struct RAGStats2 {
    let pendingCount: Int
}

private struct HealthStatus {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private struct VelocityDiagData {
    let signal: String
    let velocity: Double
    let currentScore: Double
    let crossingAlert: String?
    let signalColor: Color
}

private struct KellyDiagData {
    let winRate: Double
    let kellyFraction: Double
    let effectiveFraction: Double
    let positionMultiplier: Double
    let sampleSize: Int
    let confidence: String
    let avgWinPct: Double
    let avgLossPct: Double
}

private struct OppCostDiagData {
    let totalMissed: Int
    let goodSkips: Int
    let missedGains: Int
    let avgMissedReturn: Double
    let skipAccuracy: Double
    let calibrationSignal: String
    let isTooCautious: Bool
    let isWellCalibrated: Bool
}
