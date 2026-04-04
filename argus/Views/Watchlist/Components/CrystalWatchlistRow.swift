import SwiftUI

struct CrystalWatchlistRow: View {
    let symbol: String
    let quote: Quote?
    let candles: [Candle]?
    let forecast: PrometheusForecast?
    var signal: AISignal? = nil   // Argus aksiyon sinyali (opsiyonel)

    var changeColor: Color {
        guard let q = quote else { return Theme.textSecondary }
        return q.change >= 0 ? Theme.positive : Theme.negative
    }

    var body: some View {
        HStack(spacing: 12) {

            // 1. Logo
            CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))

            // 2. Kimlik + sinyal nedeni
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.custom("Inter-Bold", size: 15))
                    .foregroundColor(Theme.textPrimary)

                if let sig = signal, !sig.reason.isEmpty {
                    // Argus sinyali varsa şirket adı yerine neden göster
                    Text(sig.reason)
                        .font(.system(size: 11))
                        .foregroundColor(signalColor(sig).opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text(quote?.shortName ?? "Yükleniyor")
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Aksiyon pill (sinyal varsa) veya Prometheus tahmini (yoksa)
            if let sig = signal {
                Text(localizedAction(sig))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(signalColor(sig))
                    .cornerRadius(8)
                    .frame(width: 64, alignment: .center)
            } else if let f = forecast {
                PrometheusBadge(forecast: f)
                    .frame(width: 80, alignment: .center)
            } else {
                Color.clear.frame(width: 64)
            }

            // 4. Fiyat + değişim
            if let q = quote {
                let isBist = symbol.uppercased().hasSuffix(".IS")
                let currency = isBist ? "₺" : "$"
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "\(currency)%.2f", q.currentPrice))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(changeColor)
                        .cornerRadius(6)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 40, height: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func localizedAction(_ sig: AISignal) -> String {
        switch sig.action {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "İZLE"
        case .skip: return "PAS"
        }
    }

    private func signalColor(_ sig: AISignal) -> Color {
        switch sig.action {
        case .buy:  return .green
        case .sell: return .red
        case .hold: return Color(white: 0.45)
        case .wait: return Color(white: 0.45)
        case .skip: return Color(white: 0.45)
        }
    }
}
