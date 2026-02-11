import SwiftUI

// MARK: - Piyasa Duygu Barometresi Kartı
/// Haber tonunu ve piyasa algısını ölçen gauge kart.
/// Korku-Açgözlülük spektrumunda gösterir.

struct DuyguBarometresiCard: View {
    let symbol: String

    @State private var sentimentScore: Double = 0 // -100..+100
    @State private var sentimentLabel: String = "Nötr"
    @State private var isLoading = true
    @State private var showEducation = false

    private var sentimentColor: Color {
        if sentimentScore >= 30 { return InstitutionalTheme.Colors.positive }
        if sentimentScore <= -30 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.warning
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PİYASA DUYGU BAROMETRESİ")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("Haber & Algı Analizi")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    Image(systemName: showEducation ? "lightbulb.fill" : "lightbulb")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                }
            }
            .padding(16)

            Divider().background(InstitutionalTheme.Colors.borderSubtle)

            if isLoading {
                ProgressView()
                    .tint(InstitutionalTheme.Colors.primary)
                    .padding(32)
            } else {
                VStack(spacing: 16) {
                    // Duygu Badge
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text(sentimentLabel.uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(sentimentColor)
                            Text(sentimentScore >= 0 ? "+\(Int(sentimentScore))" : "\(Int(sentimentScore))")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(sentimentColor)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sentimentColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(sentimentColor.opacity(0.3), lineWidth: 1)
                        )
                        Spacer()
                    }

                    // Spectrum Bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("Korku")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.negative)
                            Spacer()
                            Text("Açgözlülük")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.positive)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Gradient bar
                                LinearGradient(
                                    colors: [
                                        InstitutionalTheme.Colors.negative,
                                        InstitutionalTheme.Colors.warning,
                                        InstitutionalTheme.Colors.positive
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(height: 8)
                                .cornerRadius(4)

                                // Pointer
                                let normalizedPos = (sentimentScore + 100) / 200.0
                                let clampedPos = max(0, min(1, normalizedPos))
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                    .offset(x: geo.size.width * clampedPos - 7)
                            }
                        }
                        .frame(height: 14)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(16)
            }

            // Eğitim Notu
            if showEducation {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(InstitutionalTheme.Colors.borderSubtle)
                    HStack(alignment: .top, spacing: 8) {
                        Text("💡")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ne Demek?")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                            Text("Duygu barometresi haber tonunu ve piyasa algısını ölçer. Aşırı açgözlülük genelde tepe sinyalidir (herkes iyimser olunca dikkatli olunmalı), aşırı korku ise fırsat olabilir (piyasa aşırı satılmış olabilir).")
                                .font(.system(size: 11))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(InstitutionalTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .task { await loadSentiment() }
    }

    private func loadSentiment() async {
        // BISTSentimentEngine'den çek
        if let payload = try? await BISTSentimentEngine.shared.analyzeSentimentPayload(for: symbol) {
            let score = payload.result.overallScore // 0..100 varsayımıyla
            let normalized = (score - 50) * 2 // -100..+100 aralığına dönüştür

            let label: String
            if normalized >= 50 { label = "Çok Olumlu" }
            else if normalized >= 15 { label = "Olumlu" }
            else if normalized >= -15 { label = "Nötr" }
            else if normalized >= -50 { label = "Olumsuz" }
            else { label = "Çok Olumsuz" }

            await MainActor.run {
                self.sentimentScore = normalized
                self.sentimentLabel = label
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.sentimentScore = 0
                self.sentimentLabel = "Veri Yok"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Analist Eğitim Wrapper
/// Mevcut BistAnalystCard'a Türkçe eğitim notu ekleyen sarmalayıcı.

struct AnalistEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        VStack(spacing: 0) {
            // Mevcut analist kartını göster
            BistAnalystCard(symbol: symbol)

            // Eğitim notu butonu
            HStack {
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 10))
                        Text("Ne Demek?")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if showEducation {
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.system(size: 14))
                    Text("Analist konsensüsü, profesyonel yatırımcıların ortalama beklentisini gösterir. Hedef fiyat, analistlerin 12 aylık tahminidir. Tek başına yeterli olmaz, diğer modüllerle birlikte değerlendirilmelidir.")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - KAP Eğitim Wrapper
/// Mevcut KulisKAPCard'a Türkçe eğitim notu ekleyen sarmalayıcı.

struct KAPEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        VStack(spacing: 0) {
            KulisKAPCard(symbol: symbol)

            HStack {
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 10))
                        Text("Ne Demek?")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if showEducation {
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.system(size: 14))
                    Text("KAP bildirimleri şirketlerin yasal olarak açıklaması gereken önemli gelişmelerdir. Finansal tablolar, yönetim kurulu kararları, ortaklık yapısı değişiklikleri gibi bilgiler burada yayınlanır. Hızlı hareket eden bilgidir.")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Temettü Eğitim Wrapper
/// BistDividendCard'a Türkçe eğitim notu ekleyen sarmalayıcı.

struct TemettuEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        VStack(spacing: 0) {
            BistDividendCard(symbol: symbol)

            HStack {
                Spacer()
                Button(action: { withAnimation(.snappy) { showEducation.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 10))
                        Text("Ne Demek?")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if showEducation {
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.system(size: 14))
                    Text("Temettü, şirketin kârından ortaklara dağıttığı paydır. Düzenli temettü ödeyen şirketler genelde daha güvenilir kabul edilir. Bedelsiz sermaye artırımı ise hisse adedini artırır ancak toplam değeri değiştirmez.")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
