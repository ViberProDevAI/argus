import SwiftUI

/// Anasayfada görünen makro durum kartı.
///
/// 2026-04-25 H-32 — P3 layout (kullanıcı onayı):
///   • Sol: "Bugün" 17pt başlık + iki sıfatlık alt satır
///     (örn. "Tedirgin, dalgalı" / "Sakin, dengeli")
///   • Sağ: "MAKRO" küçük mono caption + skor (22pt mono)
///   • Border: nötr slate
///   • Page header'da zaten "Piyasa" yazdığı için kart başlığı "Bugün" —
///     duplikasyon çözüldü. Kart fontu da küçük (17pt) ki header'la
///     hiyerarşi karışmasın.
///
/// Bu kart hem Aether (skor) hem Chiron (rejim) bilgisini sıfat
/// zinciri olarak taşır — anasayfada iki ayrı kart yerine tek kart.
/// Detay sheet'inde tam rejim adı, aktif strateji ("salınım/hücum")
/// ve üç dilimlik makro skor (leading/coincident/lagging) yaşar.
///
/// Tap → Aether (makro) detay sheet.
struct AetherDashboardHUD: View {
    let rating: MacroEnvironmentRating?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // 2026-04-25 H-32: P3 — page header zaten "Piyasa" diyor,
                    // kart başlığı "Bugün" ile çakışmayı çözüyor. Font 22→17pt
                    // küçüldü ki page header'la kıyasta dominant durmasın.
                    Text("Bugün")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(adjectivePhrase)
                        .font(.system(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                scoreBlock
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    // MARK: - Score block (sağ alt)

    @ViewBuilder
    private var scoreBlock: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("MAKRO")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            if let r = rating {
                Text("\(Int(r.numericScore))")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Adjective dictionary
    //
    // Trader jargonu (yatay seyir / salınım / risk-on) yerine yeni
    // indiren biri için anlaşılır iki sıfat. Detay sayfasında tam
    // rejim adı + aktif strateji yine var.
    private var adjectivePhrase: String {
        guard let r = rating else { return "Hesaplanıyor" }
        switch r.numericScore {
        case 70...:   return "İyimser, hareketli"
        case 55...:   return "Sakin, dengeli"
        case 40..<55: return "Tedirgin, dalgalı"
        default:      return "Riskli, savunmada"
        }
    }
}
