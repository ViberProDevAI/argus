import SwiftUI

/// REJİM MERKEZİ
/// Piyasa rejimi, makro göstergeler, teknik konsensüs ve sektör analizi.
/// Tüm veriler BorsaPy backend'inden canlı çekilir.

struct RejimView: View {
    let symbol: String

    @State private var rejimScore: Double = 50
    @State private var rejimLabel: String = "Nötr"
    @State private var rejimStance: String = "cautious"
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack(spacing: 10) {
                Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                    .font(.system(size: 14))
                    .foregroundColor(SanctumTheme.hologramBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("REJİM MERKEZİ")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Piyasa & Makro Analiz")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(SanctumTheme.hologramBlue)
                    Text("Rejim verileri yükleniyor...")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .padding(40)
            } else {
                VStack(spacing: 20) {
                    // 1. Piyasa Rejimi
                    PiyasaRejimiCard(
                        rejimScore: rejimScore,
                        rejimLabel: rejimLabel,
                        stance: rejimStance
                    )

                    // 2. Makro Göstergeler (BorsaPy canlı)
                    MakroGostergelerCard()

                    // 3. Teknik Konsensüs (28 gösterge)
                    TeknikKonsensusCard(symbol: symbol)

                    // 4. Sektör Analizi (mevcut bileşen)
                    BistSektorCard()

                    // Disclaimer
                    disclaimerFooter
                }
            }
        }
        .task { await loadRejimData() }
    }

    // MARK: - Disclaimer
    private var disclaimerFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.warning)
            Text("Eğitim amaçlıdır, yatırım tavsiyesi değildir.")
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Data Loading
    private func loadRejimData() async {
        // MacroSnapshot'tan rejim skorunu hesapla
        let macro = await MacroSnapshotService.shared.getSnapshot()

        // Rejim skoru: VIX + DXY + yield curve bileşiminden hesapla
        var score: Double = 50
        var label = "Nötr"
        var stance = "cautious"

        // VIX bazlı
        if let vix = macro.vix {
            if vix < 15 {
                score += 20; stance = "riskOn"
            } else if vix < 20 {
                score += 10
            } else if vix > 30 {
                score -= 25; stance = "riskOff"
            } else if vix > 25 {
                score -= 15; stance = "defensive"
            }
        }

        // Fed Funds / Rate bazlı
        if let rate = macro.fedFundsRate {
            if rate < 4.0 { score += 5 }
            else if rate > 5.5 { score -= 10 }
        }

        // Fear & Greed bazlı
        if let fg = macro.fearGreedIndex {
            if fg > 70 { score += 10 }
            else if fg < 30 { score -= 15 }
        }

        score = max(0, min(100, score))

        if score >= 65 { label = "Boğa"; stance = "riskOn" }
        else if score >= 50 { label = "Temkinli Boğa" }
        else if score >= 40 { label = "Nötr" }
        else if score >= 25 { label = "Temkinli Ayı"; stance = "defensive" }
        else { label = "Ayı"; stance = "riskOff" }

        await MainActor.run {
            self.rejimScore = score
            self.rejimLabel = label
            self.rejimStance = stance
            self.isLoading = false
        }
    }
}
