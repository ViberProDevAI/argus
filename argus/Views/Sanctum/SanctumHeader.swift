import SwiftUI

// MARK: - SanctumHeader
//
// Argus Sanctum ekranının başlık bloğu: sembol + fiyat + yüzdelik değişim.
// Önceden ArgusSanctumView içinde computed property olarak yaşıyordu.
// Split edildi → bağımsız bir bileşen olarak Views/Sanctum/ altına alındı.
//
// Kullanım:
//     SanctumHeader(symbol: symbol, quote: vm.quote)
//
// Veri kaynağı: SanctumViewModel.quote (Quote)
// Demo veri yok — quote nil ise yalnızca sembol gösterilir.

struct SanctumHeader: View {
    let symbol: String
    let quote: Quote?

    var body: some View {
        VStack(spacing: 6) {
            Text(symbol)
                .font(.system(.title, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .tracking(2)
                .shadow(color: SanctumTheme.hologramBlue.opacity(0.4), radius: 12)
                .accessibilityAddTraits(.isHeader)

            if let quote {
                let change = quote.percentChange ?? 0
                let priceColor: Color = change >= 0
                    ? SanctumTheme.auroraGreen
                    : SanctumTheme.crimsonRed

                HStack(spacing: 8) {
                    Text(String(format: "%.2f", quote.currentPrice))
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(priceColor)

                    Text(String(format: "%@%.2f%%", change >= 0 ? "+" : "", change))
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(priceColor.opacity(0.7))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(
                    "Fiyat \(String(format: "%.2f", quote.currentPrice)), " +
                    "değişim \(String(format: "%+.2f", change)) yüzde"
                ))
            }
        }
        .padding(.top, 100)
    }
}
