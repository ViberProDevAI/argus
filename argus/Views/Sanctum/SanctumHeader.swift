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

    // 2026-04-25 H-36: Büyük sembol Sanctum top nav'a taşındı; bu header
    // artık sadece fiyat ve yüzde değişim taşıyor. Sola hizalı, top nav'ın
    // hemen altında yaşar — duplikasyon yok.
    var body: some View {
        if let quote {
            let change = quote.percentChange ?? 0
            let priceColor: Color = change >= 0
                ? SanctumTheme.auroraGreen
                : SanctumTheme.crimsonRed
            let isBist = symbol.uppercased().hasSuffix(".IS")
            let currency = isBist ? "₺" : "$"

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "\(currency)%.2f", quote.currentPrice))
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                HStack(spacing: 8) {
                    Text(String(format: "%@%.2f", change >= 0 ? "+" : "", quote.change))
                        .font(.system(size: 13, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(priceColor)
                    Text(String(format: "%@%.2f%%", change >= 0 ? "+" : "", change))
                        .font(.system(size: 13, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(priceColor)
                    Spacer()
                    Text("Son · \(formattedTime)")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(
                "Fiyat \(String(format: "%.2f", quote.currentPrice)), " +
                "değişim \(String(format: "%+.2f", change)) yüzde"
            ))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("—")
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formattedTime: String {
        Date().formatted(.dateTime.hour().minute())
    }
}
