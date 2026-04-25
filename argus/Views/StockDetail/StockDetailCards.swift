import SwiftUI

// MARK: - 1. Karar Özeti Kartı
// "Karar Protokolü" çok adımlı iç süreç şemasını yerine koyar.
// Kullanıcı için önemli olan SON SONUÇ + varsa neden reddedildiği.
struct AgoraTraceCard: View {
    let trace: AgoraTrace?

    var body: some View {
        // Veri yoksa gösterme
        guard let t = trace else { return AnyView(EmptyView()) }

        let approved = t.riskEvaluation.isApproved
        let action   = t.finalDecision.action

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: approved ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .foregroundColor(approved ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson)
                    Text(approved ? "Argus onayladı" : "Argus reddetti")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    Text(action.rawValue.uppercased())
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(action == .buy ? InstitutionalTheme.Colors.aurora.opacity(0.15) : InstitutionalTheme.Colors.holo.opacity(0.15))
                        .foregroundColor(action == .buy ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.holo)
                        .cornerRadius(8)
                }

                // Neden reddedildi — sadece ret durumunda göster
                if !approved, !t.riskEvaluation.reason.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text(t.riskEvaluation.reason)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .cornerRadius(16)
        )
    }
}

// MARK: - Geriye dönük uyumluluk için boş alt yapılar
struct TraceStepRow: View {
    let icon: String; let title: String; let detail: String; let isActive: Bool
    var isError: Bool = false; var isLast: Bool = false
    var body: some View { EmptyView() }
}
struct TraceLine: View { var body: some View { EmptyView() } }

// MARK: - 2. Risk Kartı
// Sadece risk limiti aşıldıysa ya da veto varsa görünür.
struct RiskSummaryCard: View {
    let riskReport: String?

    var body: some View {
        // Anlamlı içerik yoksa hiç gösterme
        guard let report = riskReport, !report.isEmpty else { return AnyView(EmptyView()) }

        let isVeto = report.contains("VETO")
        return AnyView(
            HStack(spacing: 10) {
                Image(systemName: isVeto ? "hand.raised.fill" : "shield.lefthalf.filled")
                    .foregroundColor(isVeto ? InstitutionalTheme.Colors.crimson : InstitutionalTheme.Colors.holo)
                Text(isVeto ? report.replacingOccurrences(of: "VETO: ", with: "") : report)
                    .font(.system(size: 13))
                    .foregroundColor(isVeto ? InstitutionalTheme.Colors.crimson : InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(isVeto ? InstitutionalTheme.Colors.crimson.opacity(0.08) : InstitutionalTheme.Colors.surface1)
            .cornerRadius(14)
        )
    }
}

// MARK: - Destekleyici yapılar (backward compat)
struct RiskRow: View {
    let label: String; let value: String
    var body: some View { EmptyView() }
}

// MARK: - 3. Kanalda Konum Kartı
// "PHOENIX KANALI" adı kaldırıldı. Anlamlı veri varsa gösterilir.
struct PhoenixChannelCard: View {
    let advice: PhoenixAdvice
    var onRunBacktest: (() -> Void)? = nil

    var body: some View {
        guard advice.channelUpper != nil || advice.channelLower != nil else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.and.down.circle")
                        .foregroundColor(InstitutionalTheme.Colors.holo)
                    Text("Kanal Analizi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    if let run = onRunBacktest {
                        Button("Geçmiş Test", action: run)
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.holo)
                    }
                }

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", advice.channelUpper ?? 0))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.crimson.opacity(0.9))
                        Text("Direnç")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                        Rectangle()
                            .fill(LinearGradient(
                                colors: [InstitutionalTheme.Colors.crimson.opacity(0.3), InstitutionalTheme.Colors.aurora.opacity(0.3)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 4, height: 30)

                        Text(String(format: "%.2f", advice.channelLower ?? 0))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.aurora.opacity(0.9))
                        Text("Destek")
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Konum:")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Text(advice.triggers.touchLowerBand ? "Destek bölgesi" : "Kanal içi")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        if advice.triggers.rsiReversal || advice.triggers.bullishDivergence {
                            Text(advice.triggers.rsiReversal ? "RSI dönüş sinyali var" : "Yükseliş ayrışması")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.holo)
                        }
                        if !advice.reasonShort.isEmpty {
                            Text(advice.reasonShort)
                                .font(.system(size: 12))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .italic()
                        }
                    }
                }
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .cornerRadius(16)
        )
    }
}

// MARK: - 4. İşlem Geçmişi
struct TransactionHistoryCard: View {
    let transactions: [Transaction]

    var body: some View {
        guard !transactions.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Bu Hissedeki İşlemler")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                ForEach(transactions.prefix(5)) { tx in
                    HStack {
                        Text(tx.type.rawValue == "BUY" ? "ALIM" : "SATIM")
                            .font(.caption)
                            .bold()
                            .foregroundColor(tx.type.rawValue == "BUY" ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson)
                        Text(tx.date.formatted(date: .numeric, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.0f", tx.amount)) adet @ \(String(format: "%.2f", tx.price))")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    Divider()
                }
            }
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)
            .cornerRadius(16)
        )
    }
}

// MARK: - Kaldırılan kartlar (backward compat — her zaman boş döner)

/// Korelasyon veri güvenilir olmadan gösterilmemeli — her zaman gizli.
struct CorrelationCard: View {
    var body: some View { EmptyView() }
}

/// "İlk tespit tarihi" gibi meta-veriler kullanıcıya anlamsız — kaldırıldı.
struct UniverseInfoCard: View {
    let source: UniverseSource?
    let firstSeen: Date?
    var body: some View { EmptyView() }
}
