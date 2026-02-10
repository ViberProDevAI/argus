import SwiftUI

struct RegimeGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    regimeDefinitionsSection
                    fastDecisionFlowSection
                    actionMatrixSection
                    errorPreventionSection
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Ders 3 · Rejim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rejimi Okumadan İşlem Açma")
                .font(InstitutionalTheme.Typography.title)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text("Aynı strateji her piyasada aynı sonucu vermez. Rejim, işlemin yönünü değil risk dozunu belirler.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private var regimeDefinitionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("3 TEMEL REJİM")
            regimeRow(
                name: "Trend",
                color: InstitutionalTheme.Colors.positive,
                summary: "Yön belirgin, devam olasılığı daha yüksek.",
                clue: "ADX güçlü, kırılım teyitli."
            )
            regimeRow(
                name: "Çapraz",
                color: InstitutionalTheme.Colors.warning,
                summary: "Yön zayıf, bant içi hareket baskın.",
                clue: "ADX düşük, sık fake breakout."
            )
            regimeRow(
                name: "Risk-off",
                color: InstitutionalTheme.Colors.negative,
                summary: "Belirsizlik yüksek, korunma öncelikli.",
                clue: "VIX yükseliş eğiliminde, volatilite sert."
            )
        }
    }

    private var fastDecisionFlowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("60 SANİYELİK HIZLI AKIŞ")
            stepRow(index: "1", title: "Volatiliteye bak", detail: "VIX yukarıysa risk boyutunu otomatik düşür.")
            stepRow(index: "2", title: "Trend gücünü ölç", detail: "ADX güçlü ise trend; değilse çapraz kabul et.")
            stepRow(index: "3", title: "Motor önceliğini değiştir", detail: "Risk-off’ta Aether/Atlas önceliği artır, agresif teknik ağırlığı azalt.")
            stepRow(index: "4", title: "Nihai kararı yeniden oku", detail: "Konsey kararı ile rejim çelişiyorsa işlem boyutunu küçült.")
        }
    }

    private var actionMatrixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("REJİME GÖRE EYLEM MATRİSİ")
            matrixRow(regime: "Trend", action: "Teyitli yönde kal, gereksiz karşı işlem açma.")
            matrixRow(regime: "Çapraz", action: "İşlem sayısını azalt, seçiciliği artır.")
            matrixRow(regime: "Risk-off", action: "Pozisyon küçült, stop disiplinini sıkılaştır.")
        }
    }

    private var errorPreventionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SIK YAPILAN HATALAR")
            bullet("Rejim çaprazken trenddeymiş gibi agresif kaldıraç kullanmak.")
            bullet("Makro stres artarken pozisyon büyütmek.")
            bullet("Rejimi sadece bir metrikle okuyup diğer bağlamı yok saymak.")
        }
    }

    private func regimeRow(name: String, color: Color, summary: String, clue: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Text(summary)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("İpucu: \(clue)")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private func stepRow(index: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(index)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .frame(width: 14, alignment: .leading)
                Text(title)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .padding(.leading, 22)
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private func matrixRow(regime: String, action: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(regime)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 64, alignment: .leading)
            Text(action)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(InstitutionalTheme.Colors.warning)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .tracking(0.8)
    }
}

#Preview {
    RegimeGuideSheet()
}
