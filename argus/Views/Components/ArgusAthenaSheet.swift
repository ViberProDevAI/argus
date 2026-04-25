import SwiftUI

// MARK: - Argus Athena Sheet (V5)
//
// **2026-04-23 V5 tam yazım.** Eski `ArgusAthenaSheet` raw `Color.teal` +
// `presentationMode` + `cornerRadius(12)` + Türkçe karakter eksik metinler
// şablonuyla V5 dışındaydı. Yeni sheet:
//
//   • `ModuleSheetShell` → `ArgusNavHeader` + dismiss + scroll sarmal.
//   • Hero kart: circular skor ring + styleLabel + "GÜÇLÜ SINIFLA" pill.
//   • Eğitici intro: Athena'yı 1 cümlede tanıtır.
//   • 4 faktör kartı (Değer / Kalite / Momentum / Risk):
//       - Mikro alt-başlık ("ucuz mu pahalı mı?" gibi).
//       - Skor + `ArgusBar`.
//       - En güçlü faktöre "EN GÜÇLÜ" rozeti + vurgulu arka plan.
//       - Alt-satır gerçek veri cümlesi (F/K, ROE, Beta, trendDesc) —
//         sadece `TradingViewModel`'da o alan mevcutsa render edilir.
//         **Veri yoksa satır gizlenir.** Uydurma yok.
//   • Athena yargısı: en güçlü 1-2 faktör + styleLabel birleşimi.
//   • Pedagoji footer: 4 faktörün akademik tanımları (statik öğretici).
//
// Gerçek veri kaynağı:
//   - `viewModel.athenaResults[symbol]` → `AthenaFactorResult` (4 skor)
//   - `viewModel.getFundamentalScore(for:)?.financials` → `FinancialsData`
//     (peRatio, priceToBook, returnOnEquity, profitMargin, debtToEquity)
//   - `viewModel.getFinancialSnapshot(for:)?.beta` → `Double?`
//   - `viewModel.orionScores[symbol]?.components.trendDesc` → String
//
// `AthenaFactorResult` yoksa `ModulePlaceholderSheet` ile bilgilendirici
// boş hal gösterilir.

struct ArgusAthenaSheet: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel

    // MARK: - Veri erişim

    private var result: AthenaFactorResult? {
        viewModel.athenaResults[symbol]
    }

    private var financials: FinancialsData? {
        viewModel.getFundamentalScore(for: symbol)?.financials
    }

    private var snapshot: FinancialSnapshot? {
        viewModel.getFinancialSnapshot(for: symbol)
    }

    private var orionTrendDesc: String? {
        let d = viewModel.orionScores[symbol]?.components.trendDesc
        return (d?.isEmpty == false) ? d : nil
    }

    /// 4 faktör skorunun en büyüğünü bul — "EN GÜÇLÜ" rozeti ve yargı için.
    private func strongestFactor(_ r: AthenaFactorResult) -> AthenaSheetFactor {
        let pairs: [(AthenaSheetFactor, Double)] = [
            (.value,    r.valueFactorScore),
            (.quality,  r.qualityFactorScore),
            (.momentum, r.momentumFactorScore),
            (.risk,     r.riskFactorScore),
        ]
        return pairs.max(by: { $0.1 < $1.1 })?.0 ?? .quality
    }

    // MARK: - Body

    var body: some View {
        if let r = result {
            ModuleSheetShell(title: "ATHENA · FAKTÖR ANALİZİ", motor: .athena) {
                heroCard(r)
                educationalIntroCard
                factorCaption
                factorCard(.value,    score: r.valueFactorScore,    strongest: strongestFactor(r))
                factorCard(.quality,  score: r.qualityFactorScore,  strongest: strongestFactor(r))
                factorCard(.momentum, score: r.momentumFactorScore, strongest: strongestFactor(r))
                factorCard(.risk,     score: r.riskFactorScore,     strongest: strongestFactor(r))
                verdictCard(r)
                pedagogyFooter
            }
        } else {
            ModulePlaceholderSheet(
                title: "ATHENA · BEKLİYOR",
                subtitle: "Faktör analizi hazır değil",
                message: "Athena bu hisse için 4 faktör skorunu henüz hesaplamadı. Motor daha fazla veri bekliyor.",
                motor: .athena
            )
        }
    }

    // MARK: - Hero

    private func heroCard(_ r: AthenaFactorResult) -> some View {
        let athenaColor = InstitutionalTheme.Colors.Motors.athena

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(athenaColor.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, r.factorScore)) / 100.0))
                    .stroke(athenaColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(r.factorScore))")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("/ 100")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(athenaColor)
                }
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                ArgusSectionCaption("STRATEJİ ETİKETİ")
                Text(r.styleLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                ArgusChip("GÜÇLÜ SINIFLA", tone: .motor(.athena))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(athenaColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Educational intro

    private var educationalIntroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArgusSectionCaption("NASIL OKUNUR?")
            Text("Athena, hisseyi 4 akademik faktöre göre puanlar. En yüksek 2 faktör strateji etiketini belirler.")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.Motors.athena)
                .frame(width: 2)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Factor caption

    private var factorCaption: some View {
        HStack {
            ArgusSectionCaption("4 FAKTÖR · KIRILIM")
            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Factor card

    private func factorCard(_ factor: AthenaSheetFactor,
                            score: Double,
                            strongest: AthenaSheetFactor) -> some View {
        let isStrongest = (factor == strongest)
        let athenaColor = InstitutionalTheme.Colors.Motors.athena
        let clamped = max(0, min(100, score))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(factor.title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(isStrongest ? athenaColor : InstitutionalTheme.Colors.textPrimary)
                Text(factor.microCaption)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer(minLength: 0)
                if isStrongest {
                    ArgusChip("EN GÜÇLÜ", tone: .aurora)
                }
                Text("\(Int(clamped))")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }

            ArgusBar(value: clamped / 100.0, color: athenaColor, height: 5)

            if let line = factorDataLine(factor) {
                Text(line)
                    .font(.system(size: 11))
                    .foregroundColor(isStrongest
                                     ? InstitutionalTheme.Colors.textPrimary
                                     : InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(
                    isStrongest ? athenaColor.opacity(0.35) : InstitutionalTheme.Colors.border,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Gerçek veri satırları (uydurma yok — yoksa nil döner, satır gizlenir)

    private func factorDataLine(_ factor: AthenaSheetFactor) -> String? {
        switch factor {
        case .value:    return valueLine()
        case .quality:  return qualityLine()
        case .momentum: return momentumLine()
        case .risk:     return riskLine()
        }
    }

    private func valueLine() -> String? {
        var parts: [String] = []
        if let pe = financials?.peRatio {
            parts.append("F/K \(AtlasMetric.format(pe))")
        }
        if let pb = financials?.priceToBook {
            parts.append("PD/DD \(AtlasMetric.format(pb))")
        }
        if let ev = financials?.evToEbitda {
            parts.append("EV/EBITDA \(AtlasMetric.format(ev))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func qualityLine() -> String? {
        var parts: [String] = []
        // ROE önceliği: FinancialsData > FinancialSnapshot
        if let roe = financials?.returnOnEquity ?? snapshot?.roe {
            parts.append("ROE \(AtlasMetric.formatPercent(roe))")
        }
        if let nm = financials?.profitMargin ?? snapshot?.netMargin {
            parts.append("Net marj \(AtlasMetric.formatPercent(nm))")
        }
        if let de = financials?.debtToEquity ?? snapshot?.debtToEquity {
            parts.append("Borç/Özkaynak \(AtlasMetric.format(de))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func momentumLine() -> String? {
        // Orion trendDesc varsa onu kullan; yoksa satır gizle.
        // "Son 3-12 ay getirisi" için kayıtlı field yok — uydurmuyoruz.
        if let desc = orionTrendDesc {
            if let age = viewModel.orionScores[symbol]?.components.trendAge {
                return "Trend · \(desc) · \(age) gün önce başladı"
            }
            return "Trend · \(desc)"
        }
        return nil
    }

    private func riskLine() -> String? {
        // Beta: global için FinancialSnapshot.beta; BIST için cache yok —
        // null dönerse satır gizlenir.
        guard let beta = snapshot?.beta else { return nil }
        let tone = beta < 0.9 ? "sakin" : (beta > 1.2 ? "hareketli" : "dengeli")
        return "Beta \(String(format: "%.2f", beta)) · \(tone)"
    }

    // MARK: - Verdict

    private func verdictCard(_ r: AthenaFactorResult) -> some View {
        let (primary, secondary) = topTwoFactors(r)
        let summary = verdictText(primary: primary, secondary: secondary, styleLabel: r.styleLabel)

        return VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("ATHENA'NIN YARGISI")
            Text(summary)
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.Motors.athena.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.athena.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func topTwoFactors(_ r: AthenaFactorResult) -> (AthenaSheetFactor, AthenaSheetFactor) {
        let pairs: [(AthenaSheetFactor, Double)] = [
            (.value,    r.valueFactorScore),
            (.quality,  r.qualityFactorScore),
            (.momentum, r.momentumFactorScore),
            (.risk,     r.riskFactorScore),
        ].sorted(by: { $0.1 > $1.1 })
        return (pairs[0].0, pairs[1].0)
    }

    private func verdictText(primary: AthenaSheetFactor,
                             secondary: AthenaSheetFactor,
                             styleLabel: String) -> String {
        // Strateji etiketi zaten Athena servisi tarafından üretiliyor —
        // burada kendi yargımızı eklemiyoruz, sadece en güçlü 2 faktörü
        // okunaklı bir cümleye sarıyoruz.
        return "En güçlü iki faktör: \(primary.title) ve \(secondary.title). Strateji: \(styleLabel)."
    }

    // MARK: - Pedagogy footer

    private var pedagogyFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("FAKTÖR YATIRIMI NEDİR?")

            VStack(alignment: .leading, spacing: 6) {
                pedagogyRow(.value)
                pedagogyRow(.quality)
                pedagogyRow(.momentum)
                pedagogyRow(.risk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    InstitutionalTheme.Colors.border,
                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func pedagogyRow(_ factor: AthenaSheetFactor) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(factor.title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.Motors.athena)
                .frame(width: 80, alignment: .leading)
            Text(factor.pedagogy)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Factor Enum

private enum AthenaSheetFactor: Hashable {
    case value, quality, momentum, risk

    var title: String {
        switch self {
        case .value:    return "DEĞER"
        case .quality:  return "KALİTE"
        case .momentum: return "MOMENTUM"
        case .risk:     return "RİSK"
        }
    }

    var microCaption: String {
        switch self {
        case .value:    return "ucuz mu pahalı mı?"
        case .quality:  return "sağlıklı mı?"
        case .momentum: return "son dönemde yükseliyor mu?"
        case .risk:     return "ne kadar sakin?"
        }
    }

    var pedagogy: String {
        switch self {
        case .value:
            return "Ucuz fiyatlı hisseler uzun vadede fark yaratır (F/K, PD/DD düşükse değerli)."
        case .quality:
            return "İyi işleyen şirketler krizleri rahat atlatır (yüksek ROE, düşük borç)."
        case .momentum:
            return "Kazananlar bir süre daha kazanır (güçlü trend, yerleşik yükseliş)."
        case .risk:
            return "Sakin hisseler zamanla daha iyi getirir (düşük beta = düşük oynaklık)."
        }
    }
}
