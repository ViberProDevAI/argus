import SwiftUI

// MARK: - Analist Konsensüs Kartı
// borsapy backend'den analist hedef fiyatları ve AL/TUT/SAT dağılımı gösterir.

struct BistAnalystCard: View {
    let symbol: String
    @State private var consensus: BistAnalystConsensus?
    @State private var currentPrice: Double?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEducation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ANALİST KONSENSÜSü")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Hedef Fiyat ve Tavsiyeler")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    Image(systemName: showEducation ? "info.circle.fill" : "info.circle")
                        .foregroundColor(.cyan)
                }
            }
            .padding(16)
            
            // Öğretici Not
            if showEducation {
                educationNote
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            if isLoading {
                ProgressView()
                    .padding(32)
            } else if let c = consensus {
                // Hedef Fiyat Bölümü
                targetPriceSection(c)
                
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                
                // AL/TUT/SAT Gauge
                recommendationGauge(c)
                
                // Potansiyel Getiri
                if let price = currentPrice, let target = c.averageTargetPrice, price > 0 {
                    Divider().background(InstitutionalTheme.Colors.borderSubtle)
                    potentialReturnSection(current: price, target: target)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Analist verisi bulunamadı")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                    }
                }
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
    
    // MARK: - Hedef Fiyat
    
    @ViewBuilder
    private func targetPriceSection(_ c: BistAnalystConsensus) -> some View {
        VStack(spacing: 12) {
            if let avg = c.averageTargetPrice {
                HStack(spacing: 16) {
                    // Düşük hedef
                    VStack(spacing: 2) {
                        Text("DÜŞÜK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text(formatPrice(c.lowTargetPrice))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                    }
                    
                    Spacer()
                    
                    // Ortalama hedef (büyük)
                    VStack(spacing: 2) {
                        Text("ORTALAMA HEDEF")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text(formatPrice(avg))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Yüksek hedef
                    VStack(spacing: 2) {
                        Text("YÜKSEK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text(formatPrice(c.highTargetPrice))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                    }
                }
            } else {
                Text("Hedef fiyat belirtilmemiş")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(16)
    }
    
    // MARK: - AL/TUT/SAT Gauge
    
    @ViewBuilder
    private func recommendationGauge(_ c: BistAnalystConsensus) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("TAVSİYE DAĞILIMI")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("\(c.totalAnalysts) analist")
                    .font(.system(size: 9))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            if c.totalAnalysts > 0 {
                // Gauge Bar
                GeometryReader { geo in
                    let total = Double(c.totalAnalysts)
                    let buyW = (Double(c.buyCount) / total) * geo.size.width
                    let holdW = (Double(c.holdCount) / total) * geo.size.width
                    let sellW = (Double(c.sellCount) / total) * geo.size.width
                    
                    HStack(spacing: 2) {
                        if c.buyCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(InstitutionalTheme.Colors.positive)
                                .frame(width: buyW)
                        }
                        if c.holdCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(InstitutionalTheme.Colors.warning)
                                .frame(width: holdW)
                        }
                        if c.sellCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(InstitutionalTheme.Colors.negative)
                                .frame(width: sellW)
                        }
                    }
                }
                .frame(height: 8)
                
                // Labels
                HStack {
                    Label("\(c.buyCount) AL", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.positive)
                    Spacer()
                    Label("\(c.holdCount) TUT", systemImage: "equal.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.warning)
                    Spacer()
                    Label("\(c.sellCount) SAT", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.negative)
                }
                
                // Konsensüs badge
                HStack {
                    Text("Konsensüs:")
                        .font(.system(size: 10))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(c.recommendation.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(consensusColor(c.recommendation))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(consensusColor(c.recommendation).opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .padding(16)
        .onAppear { loadData() }
    }
    
    // MARK: - Potansiyel Getiri
    
    @ViewBuilder
    private func potentialReturnSection(current: Double, target: Double) -> some View {
        let returnPct = ((target - current) / current) * 100.0
        let isPositive = returnPct >= 0
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("POTANSİYEL GETİRİ")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text("Mevcut fiyat: \(formatPrice(current))")
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%+.1f%%", returnPct))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isPositive ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
        }
        .padding(16)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await MainActor.run { isLoading = true; errorMessage = nil }
            
            do {
                let clean = symbol.replacingOccurrences(of: ".IS", with: "")
                
                async let consensusTask = BorsaPyProvider.shared.getAnalystRecommendations(symbol: clean)
                async let quoteTask = BorsaPyProvider.shared.getBistQuote(symbol: clean)
                
                let fetchedConsensus = try await consensusTask
                let quote = try? await quoteTask
                
                await MainActor.run {
                    self.consensus = fetchedConsensus
                    self.currentPrice = quote?.last
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatPrice(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "₺%.2f", v)
    }
    
    private func formatPrice(_ value: Double) -> String {
        return String(format: "₺%.2f", value)
    }
    
    private func consensusColor(_ rec: String) -> Color {
        let lower = rec.lowercased()
        if lower.contains("buy") || lower.contains("al") { return InstitutionalTheme.Colors.positive }
        if lower.contains("sell") || lower.contains("sat") { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.warning
    }
    
    // MARK: - Öğretici Not
    
    private var educationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption)
                    .foregroundColor(.cyan)
                Text("Analist Konsensüsü Nasıl Okunur?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                educationBullet("Hedef fiyat, analistlerin 12 aylık beklentisidir")
                educationBullet("AL/TUT/SAT oranı, analistlerin genel eğilimini gösterir")
                educationBullet("Yüksek potansiyel getiri tek başına yeterli değildir — konsensüs gücüne bakın")
            }
            
            Text("⚠️ Analist tahminleri geçmiş performansı garanti etmez. Eğitim amaçlıdır.")
                .font(.system(size: 9))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(Color.cyan.opacity(0.08))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func educationBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption)
                .foregroundColor(.cyan)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }
}
