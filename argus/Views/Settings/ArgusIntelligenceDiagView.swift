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

        let (t, c, a, r) = await (tradeStats, chironStats, alkindusStats, ragStats)
        snapshot = DiagSnapshot(trade: t, chiron: c, alkindus: a, rag: r)
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
