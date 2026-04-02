import SwiftUI

/// Bir pozisyonun "inanç gücü"nü görsel olarak gösterir.
/// Statik "%78 Güven" chip'inin yerini alır — çok daha fazla bilgi taşır.
struct ConvictionMeterView: View {
    let conviction: ConvictionState

    @State private var animated = false

    private var meterColor: Color { Color(hex: conviction.verdict.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Üst satır: etiket + oran + verdict
            HStack(spacing: 6) {
                Text("İNANÇ")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(0.8)

                Spacer()

                Text(conviction.verdict.label.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(meterColor)
                    .tracking(0.6)

                Text("·")
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)

                Text("%\(Int(conviction.current * 100))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(meterColor)
            }

            // Bar: orijinal (ghost) + güncel (solid) + decay gap görünür
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Zemin
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                        .frame(height: 6)

                    // Orijinal skor — hayalet iz (nereden geldiğimiz)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: w * conviction.original, height: 6)

                    // Şu anki inanç — canlı dolu bar
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [meterColor.opacity(0.7), meterColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animated ? w * conviction.current : 0, height: 6)
                        .animation(.easeOut(duration: 0.8), value: animated)
                }
            }
            .frame(height: 6)

            // Alt satır: baskın faktör açıklaması
            Text(factorText)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(meterColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                        .stroke(meterColor.opacity(conviction.verdict == .expired ? 0.35 : 0.12), lineWidth: 1)
                )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { animated = true }
        }
    }

    private var factorText: String {
        switch conviction.dominantFactor {
        case .timeDecay:      return "Fiyat tezi henüz onaylamadı"
        case .priceAgainst:   return "Fiyat teze karşı hareket ediyor"
        case .regimeMismatch: return "Makro rejim pozisyonu desteklemiyor"
        case .priceConfirm:   return "Fiyat tezi onaylıyor"
        }
    }
}
