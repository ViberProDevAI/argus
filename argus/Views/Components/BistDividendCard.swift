import SwiftUI

// MARK: - BIST Temettü Kartı (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Eski: hardcoded `.orange / .gray / .white / .red` + `Color.gray.opacity(0.3)`
// divider, `RoundedRectangle.cornerRadius(16)` sarmalı.
// Yeni: motor(.atlas) tint (temettü = temel/nakit akışı), mono caps caption,
// `ArgusHair` separator, `ArgusChip` son temettü rozeti, satırlar arası
// hairline.

struct BistDividendCard: View {
    let symbol: String
    @State private var dividends: [BistDividend] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }

    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let error = errorMessage {
                    errorBlock(error)
                } else if dividends.isEmpty && !isLoading {
                    emptyBlock
                } else {
                    dividendList

                    if let lastDividend = dividends.first {
                        ArgusHair()
                        footerRow(last: lastDividend)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.Motors.atlas.opacity(0.3), lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
            )
            .onAppear { loadDividends() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.atlas, size: 14)
            ArgusSectionCaption("TEMETTÜ GEÇMİŞİ")
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.6)
                    .tint(InstitutionalTheme.Colors.Motors.atlas)
            } else {
                ArgusChip("\(dividends.count) KAYIT", tone: .motor(.atlas))
            }
        }
    }

    private var dividendList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(dividends.prefix(5)) { dividend in
                DividendRow(dividend: dividend)
                    .padding(.vertical, 6)
                    .overlay(ArgusHair(), alignment: .bottom)
            }
        }
    }

    private func footerRow(last: BistDividend) -> some View {
        HStack {
            Text("SON TEMETTÜ")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Spacer()
            Text("%\(String(format: "%.1f", last.grossRate)) BRÜT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(InstitutionalTheme.Colors.aurora)
        }
        .padding(.top, 2)
    }

    private var emptyBlock: some View {
        HStack(spacing: 8) {
            ArgusDot(color: InstitutionalTheme.Colors.textTertiary)
            Text("Bu hisse için temettü kaydı bulunamadı.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func errorBlock(_ error: String) -> some View {
        HStack(spacing: 8) {
            ArgusDot(color: InstitutionalTheme.Colors.crimson)
            Text(error)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.crimson)
        }
    }

    private func loadDividends() {
        Task {
            do {
                let result = try await BorsaPyProvider.shared.getDividends(symbol: symbol)
                await MainActor.run {
                    self.dividends = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Veri yüklenemedi"
                    self.isLoading = false
                }
            }
        }
    }
}

struct DividendRow: View {
    let dividend: BistDividend

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(dividend.date).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("HİSSE BAŞI · ₺\(String(format: "%.2f", dividend.perShare))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("%\(String(format: "%.1f", dividend.grossRate))")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.aurora)
                Text("BRÜT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - BIST Sermaye Artırımı Kartı (V5)

struct BistCapitalIncreaseCard: View {
    let symbol: String
    @State private var capitalIncreases: [BistCapitalIncrease] = []
    @State private var isLoading = true

    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }

    var body: some View {
        if isBist && !capitalIncreases.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                header

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(capitalIncreases.prefix(3)) { increase in
                        CapitalIncreaseRow(increase: increase)
                            .padding(.vertical, 6)
                            .overlay(ArgusHair(), alignment: .bottom)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.Motors.athena.opacity(0.3), lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
            )
            .onAppear { loadCapitalIncreases() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.athena, size: 14)
            ArgusSectionCaption("SERMAYE ARTIRIMLARI")
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.6)
                    .tint(InstitutionalTheme.Colors.Motors.athena)
            } else {
                ArgusChip("\(capitalIncreases.count) KAYIT",
                          tone: .motor(.athena))
            }
        }
    }

    private func loadCapitalIncreases() {
        Task {
            do {
                let result = try await BorsaPyProvider.shared.getCapitalIncreases(symbol: symbol)
                await MainActor.run {
                    self.capitalIncreases = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct CapitalIncreaseRow: View {
    let increase: BistCapitalIncrease

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(increase.date).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                if increase.rightsIssueRate > 0 {
                    Text("BEDELLİ · %\(String(format: "%.0f", increase.rightsIssueRate))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .foregroundColor(InstitutionalTheme.Colors.holo)
                }
            }

            Spacer()

            if increase.totalBonusRate > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("%\(String(format: "%.0f", increase.totalBonusRate))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.aurora)
                    Text("BEDELSİZ")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        BistDividendCard(symbol: "THYAO.IS")
        BistCapitalIncreaseCard(symbol: "THYAO.IS")
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
