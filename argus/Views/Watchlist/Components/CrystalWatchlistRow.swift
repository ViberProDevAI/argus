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
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                if let sig = signal, !sig.reason.isEmpty {
                    Text(sig.reason)
                        .font(.system(size: 11))
                        .foregroundColor(reasonColor(sig))
                        .lineLimit(1)
                } else {
                    Text(quote?.shortName ?? "Yükleniyor")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Aksiyon pill (V5 pill — radius 8, mono 10pt/700)
            if let sig = signal {
                actionPill(for: sig)
            } else if let f = forecast {
                PrometheusBadge(forecast: f)
                    .frame(width: 70)
            } else {
                Color.clear.frame(width: 48)
            }

            // 4. Fiyat + % kapsülü
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

    // MARK: - Action pill

    private func actionPill(for sig: AISignal) -> some View {
        let label = localizedAction(sig)
        let (bg, fg) = pillColors(for: sig)
        return Text(label)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(bg)
            )
            .frame(width: 56, alignment: .center)
    }

    private func pillColors(for sig: AISignal) -> (Color, Color) {
        switch sig.action {
        case .buy:
            return (InstitutionalTheme.Colors.aurora, Color(hex: "0A1F0A"))
        case .sell:
            return (InstitutionalTheme.Colors.crimson.opacity(0.2),
                    InstitutionalTheme.Colors.crimson)
        case .hold:
            return (Color(white: 0.25).opacity(0.5),
                    InstitutionalTheme.Colors.textPrimary)
        case .wait:
            return (InstitutionalTheme.Colors.Motors.chiron.opacity(0.2),
                    InstitutionalTheme.Colors.Motors.chiron)
        case .skip:
            return (InstitutionalTheme.Colors.textTertiary.opacity(0.2),
                    InstitutionalTheme.Colors.textTertiary)
        }
    }

    private func localizedAction(_ sig: AISignal) -> String {
        switch sig.action {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "İZLE"
        case .skip: return "PAS"
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

    private var priceBlock: some View {
        Group {
            if let q = quote {
                let isBist = symbol.uppercased().hasSuffix(".IS")
                let currency = isBist ? "₺" : "$"
                let changeColor: Color = q.change >= 0
                    ? InstitutionalTheme.Colors.aurora
                    : InstitutionalTheme.Colors.crimson

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "\(currency)%.2f", q.currentPrice))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                    Text(String(format: "%+.2f%%", q.percentChange))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(changeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(changeColor.opacity(0.18))
                        )
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
