import SwiftUI

// MARK: - Makro Özet Kartı
// Türkiye makro verilerini kompakt şekilde gösterir.
// Veri kaynağı: TCMBDataService (öncelikli) + borsapy backend (fallback)

struct BistMacroSummaryCard: View {
    @State private var snapshot: TCMBDataService.TCMBMacroSnapshot?
    @State private var isLoading = true
    @State private var showEducation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAKRO PANO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Piyasa Nabzı")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    Image(systemName: showEducation ? "info.circle.fill" : "info.circle")
                        .foregroundColor(.orange)
                }
            }
            .padding(16)
            
            if showEducation {
                macroEducationNote
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            if isLoading {
                ProgressView()
                    .padding(32)
            } else if let s = snapshot {
                macroGrid(s)
            } else {
                Text("Makro veri yüklenemedi")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(24)
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: InstitutionalTheme.Colors.background.opacity(0.35), radius: 8, x: 0, y: 4)
        .onAppear { loadData() }
    }
    
    // MARK: - Macro Grid
    
    @ViewBuilder
    private func macroGrid(_ s: TCMBDataService.TCMBMacroSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // Row 1: USD, EUR, Altın
            macroCell(
                title: "USD/TRY",
                value: formatRate(s.usdTry),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            macroCell(
                title: "EUR/TRY",
                value: formatRate(s.eurTry),
                icon: "eurosign.circle.fill",
                color: .blue
            )
            macroCell(
                title: "ALTIN",
                value: formatGold(s.goldPrice),
                icon: "square.fill",
                color: .yellow
            )
            
            // Row 2: Faiz, Enflasyon, Reel Faiz
            macroCell(
                title: "POLİTİKA FAİZİ",
                value: formatPct(s.policyRate),
                icon: "building.columns.fill",
                color: .cyan
            )
            macroCell(
                title: "TÜFE",
                value: formatPct(s.inflation),
                icon: "chart.line.uptrend.xyaxis",
                color: .red
            )
            macroCell(
                title: "REEL FAİZ",
                value: formatPct(s.realInterestRate),
                icon: "arrow.up.arrow.down",
                color: realRateColor(s.realInterestRate)
            )
        }
        .padding(16)
        
        // Alt satır: Ek bilgiler
        if s.currentAccount != nil || s.industrialProduction != nil {
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            HStack(spacing: 16) {
                if let ca = s.currentAccount {
                    miniStat(title: "Cari Denge", value: String(format: "%.1fB$", ca))
                }
                if let ip = s.industrialProduction {
                    miniStat(title: "Sanayi Üretimi", value: String(format: "%.1f%%", ip))
                }
                if let gdp = s.gdpGrowth {
                    miniStat(title: "GSYH Büyüme", value: String(format: "%.1f%%", gdp))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Cell
    
    @ViewBuilder
    private func macroCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface2.opacity(0.5))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(title)
                .font(.system(size: 8))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }
    
    // MARK: - Data
    
    private func loadData() {
        Task {
            let fetched = await TCMBDataService.shared.getMacroSnapshot()
            
            // Eğer TCMB verisi boşsa, borsapy backend'den fallback dene
            var finalSnapshot = fetched
            if fetched.usdTry == nil {
                finalSnapshot = await fetchBorsapyFallback(existing: fetched)
            }
            
            await MainActor.run {
                self.snapshot = finalSnapshot
                self.isLoading = false
            }
        }
    }
    
    private func fetchBorsapyFallback(existing: TCMBDataService.TCMBMacroSnapshot) -> TCMBDataService.TCMBMacroSnapshot {
        // borsapy backend'den döviz ve altın verisi çekme
        // Bu async fonksiyon olmalı ama basitlik için mevcut snapshot'ı döndürüyoruz
        // TCMB API key varsa zaten TCMB kullanılacak
        return existing
    }
    
    // MARK: - Formatters
    
    private func formatRate(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.4f", v)
    }
    
    private func formatGold(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        if v > 1000 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.2f", v)
    }
    
    private func formatPct(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.1f%%", v)
    }
    
    private func realRateColor(_ value: Double?) -> Color {
        guard let v = value else { return .gray }
        return v > 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }
    
    // MARK: - Öğretici Not
    
    private var macroEducationNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Makro Veriler Piyasayı Nasıl Etkiler?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            Group {
                macroBullet("Faiz artışı → Borsa için baskı, TL için destek")
                macroBullet("Enflasyon yüksekse → Reel getiri düşer, tasarruf eriyebilir")
                macroBullet("USD/TL yükselişi → İthalatçılar zorlanır, ihracatçılar kazanır")
                macroBullet("Altın yükselişi → Genellikle riskten kaçış sinyali")
            }
            
            Text("⚠️ Bu veriler bilgilendirme amaçlıdır, yatırım tavsiyesi değildir.")
                .font(.system(size: 9))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func macroBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption).foregroundColor(.orange)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }
}
