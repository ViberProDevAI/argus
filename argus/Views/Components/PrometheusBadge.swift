import SwiftUI

/// Watchlist satırında fiyat bloğunun altına oturan ufak tahmin satırı.
///
/// 2026-04-25 H-33 — Q3 layout (kullanıcı onayı):
///   • Eski mor "P" daire + serif harfi tamamen kaldırıldı (mor yasak,
///     serif harfi AI-tell idi).
///   • Yeni hâl: tek satır mono 10pt — "↑ 5.2% tahmin" formatında.
///   • Renk yön bilgisini taşır: pozitif → aurora, negatif → crimson,
///     sıfıra yakın (|%|<2) → tertiary gri.
///   • Geçersiz/nil forecast → EmptyView (slot kaplamaz, layout
///     diğer satırlarla aynı yükseklikte kalır).
///
/// "Tahmin" kelimesi suffix olarak duruyor — Prometheus marka adı
/// kullanıcıya gösterilmez (naming policy).
struct PrometheusBadge: View {
    let forecast: PrometheusForecast?

    var body: some View {
        if let f = forecast, f.isValid {
            Text("\(arrow(f.changePercent)) \(formatPercent(f.changePercent)) tahmin")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color(f.changePercent))
                .lineLimit(1)
        } else {
            EmptyView()
        }
    }

    private func arrow(_ pct: Double) -> String {
        if pct >= 0.5 { return "↑" }
        if pct <= -0.5 { return "↓" }
        return "→"
    }

    private func formatPercent(_ pct: Double) -> String {
        String(format: "%.1f%%", abs(pct))
    }

    private func color(_ pct: Double) -> Color {
        if pct >= 2 { return InstitutionalTheme.Colors.aurora }
        if pct <= -2 { return InstitutionalTheme.Colors.crimson }
        return InstitutionalTheme.Colors.textTertiary
    }
}
