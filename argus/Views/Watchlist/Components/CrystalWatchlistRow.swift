import SwiftUI

/// V5 mockup "01 · Piyasa" watchlist satırı Swift karşılığı.
/// (`Argus_Mockup_V5.html` satır 390-449).
///
/// Layout:
///   • 36pt gradient daire (logo placeholder)
///   • Kimlik + neden (aurora/holo/crimson/chiron renk)
///   • Aksiyon pill: AL/SAT/BEKLE/İZLE — V5 aurora/crimson/neutral/chiron
///   • Fiyat + küçük % kapsülü (aurora/crimson)
struct CrystalWatchlistRow: View {
    let symbol: String
    let quote: Quote?
    let candles: [Candle]?
    let forecast: PrometheusForecast?
    var signal: AISignal? = nil

    var body: some View {
        HStack(spacing: 12) {
            // 1. Avatar — V5 gradient dairesi (logo olmayabilir)
            avatar

            // 2. Kimlik + neden
            //
            // 2026-04-24 H-26: Eski layout sembolü iki kere gösteriyordu —
            // üstte bold "ADBE", altta gri "ADBE". Yeni: üstte şirket adı
            // (varsa), altta sembol mono küçük. Sinyal varsa neden, sembol
            // yerine alt satıra geçer ama sembol her zaman bir yerde okunur
            // kalır (avatar'ın üstündeki büyük yazı sembolün alfanumerik
            // formuna gerek bırakmıyor).
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let sig = signal, !sig.reason.isEmpty {
                    Text(sig.reason)
                        .font(.system(size: 12))
                        .foregroundColor(reasonColor(sig))
                        .lineLimit(1)
                } else {
                    Text(symbolDisplay)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Aksiyon pill (sadece AI sinyali varsa)
            // 2026-04-25 H-33: Tahmin (Prometheus) artık burada değil —
            // priceBlock'un altına üçüncü satır olarak iniyor (Q3 layout).
            // Slot sadece sinyal pill'i için, sinyal yoksa boş kalmıyor.
            if let sig = signal {
                actionPill(for: sig)
            }

            // 4. Fiyat + % + (varsa) tahmin satırı
            priceBlock
        }
        .padding(.vertical, 10)
        .overlay(ArgusHair(), alignment: .bottom)
        .contentShape(Rectangle())
    }

    // MARK: - Avatar
    //
    // 2026-04-22 logo-fix-4: Row eskiden sadece deterministic gradient
    // çiziyordu — CompanyLogoView'e hiç bağlanmamıştı. Bu yüzden global
    // piyasa ekranında hisse logoları asla görünmüyordu. Artık
    // CompanyLogoView (dairesel) çağırılıyor; logo gelmezse gradient
    // fallback zaten onun içinde çalışıyor.
    private var avatar: some View {
        CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
    }

    // MARK: - Display helpers
    //
    // 2026-04-24 H-26: "ADBE / ADBE" tekrarını kırmak için. Quote.shortName
    // doluysa onu göster (örn. "Adobe"); değilse sembolü göster — her durumda
    // alt satırda sembol mono küçük olarak okunur kalıyor.
    private var displayName: String {
        if let name = quote?.shortName, !name.isEmpty, name != symbol {
            return name
        }
        return cleanedSymbol
    }

    /// Alt satır — sembol kanonik formda (`ADBE`, `THYAO.IS`).
    private var symbolDisplay: String { cleanedSymbol }

    /// `ADBE` → `ADBE`, `THYAO.IS` → `THYAO`. BIST suffix'i alt satırda
    /// gerek yok, üstteki şirket adı zaten "Türk Hava Yolları" gibi geliyor.
    private var cleanedSymbol: String {
        symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
    }

    // MARK: - Action pill

    // 2026-04-25 H-33: ALL CAPS mono black tracking → sentence case 11pt
    // semibold capsule. Renkler 0.16 opacity tone fill — ticker bandı,
    // chiron rejim chip'i ile aynı dilde.
    private func actionPill(for sig: AISignal) -> some View {
        let label = localizedAction(sig)
        let tone = pillTone(for: sig)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tone)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.opacity(0.16))
            )
    }

    private func pillTone(for sig: AISignal) -> Color {
        switch sig.action {
        case .buy:  return InstitutionalTheme.Colors.aurora
        case .sell: return InstitutionalTheme.Colors.crimson
        case .hold: return InstitutionalTheme.Colors.textSecondary
        case .wait: return InstitutionalTheme.Colors.Motors.chiron
        case .skip: return InstitutionalTheme.Colors.textTertiary
        }
    }

    private func localizedAction(_ sig: AISignal) -> String {
        switch sig.action {
        case .buy:  return "Al"
        case .sell: return "Sat"
        case .hold: return "Bekle"
        case .wait: return "İzle"
        case .skip: return "Pas"
        }
    }

    private func reasonColor(_ sig: AISignal) -> Color {
        switch sig.action {
        case .buy, .hold:  return InstitutionalTheme.Colors.aurora
        case .sell: return InstitutionalTheme.Colors.crimson
        case .wait: return InstitutionalTheme.Colors.Motors.chiron
        case .skip: return InstitutionalTheme.Colors.textTertiary
        }
    }

    // MARK: - Price block
    //
    // 2026-04-25 H-33: Yüzde değişim renkli kapsülden çıkıp düz renkli
    // text'e geçti (ticker bandı + Aether kartı ile aynı dil). Tahmin
    // (Prometheus) varsa üçüncü satır olarak ufak mono — "↑ 5.2% tahmin".

    private var priceBlock: some View {
        Group {
            if let q = quote {
                let isBist = symbol.uppercased().hasSuffix(".IS")
                let currency = isBist ? "₺" : "$"
                let changeColor: Color = q.change >= 0
                    ? InstitutionalTheme.Colors.aurora
                    : InstitutionalTheme.Colors.crimson

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "\(currency)%.2f", q.currentPrice))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Text(String(format: "%+.2f%%", q.percentChange))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(changeColor)

                    PrometheusBadge(forecast: forecast)
                }
                .frame(minWidth: 82, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 40, height: 14)
                }
                .frame(minWidth: 82, alignment: .trailing)
            }
        }
    }
}
