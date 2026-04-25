import SwiftUI

// MARK: - Piyasa Duygu Barometresi Kartı (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// BIST Kulis modülünün hero kartı. Eski: orange lightbulb butonu, 💡 emoji
// eğitim balonu, gradient bar üzerinde beyaz shadowlu daire pointer.
// Yeni: motor(.hermes) tint, mono caps caption, aurora↔titan↔crimson
// gradient spectrum üzerinde motor-tint dot, `ArgusChip("NE DEMEK?")`
// toggle, hairline separator'lı eğitim kartı.

struct DuyguBarometresiCard: View {
    let symbol: String

    @State private var sentimentScore: Double = 0 // -100..+100
    @State private var sentimentLabel: String = "Nötr"
    @State private var isLoading = true
    @State private var showEducation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingBlock
            } else {
                sentimentHero
                spectrumBar
            }

            if showEducation {
                EducationRow(
                    text: "Duygu barometresi haber tonunu ve piyasa algısını ölçer. Aşırı açgözlülük genelde tepe sinyalidir (herkes iyimser olunca dikkatli olunmalı), aşırı korku ise fırsat olabilir (piyasa aşırı satılmış olabilir)."
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
        .task { await loadSentiment() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.hermes, size: 14)
            VStack(alignment: .leading, spacing: 2) {
                ArgusSectionCaption("PİYASA DUYGU BAROMETRESİ")
                Text("Haber · Algı Analizi")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Spacer()
            EducationToggle(isOn: $showEducation)
        }
    }

    private var sentimentHero: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DUYGU")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(sentimentLabel.uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(tone.foreground)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("SKOR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(sentimentScore >= 0
                     ? "+\(Int(sentimentScore))"
                     : "\(Int(sentimentScore))")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(tone.foreground)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .fill(tone.background)
        )
    }

    private var spectrumBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("KORKU")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
                Spacer()
                Text("NÖTR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("AÇGÖZLÜLÜK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.aurora)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    InstitutionalTheme.Colors.crimson,
                                    InstitutionalTheme.Colors.titan,
                                    InstitutionalTheme.Colors.aurora
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 5)

                    // Pointer — kart yüzeyiyle aynı surface1 halka, motor tint dolgu
                    let clampedPos = max(0, min(1, (sentimentScore + 100) / 200))
                    Circle()
                        .strokeBorder(InstitutionalTheme.Colors.surface1, lineWidth: 2)
                        .background(
                            Circle().fill(InstitutionalTheme.Colors.Motors.hermes)
                        )
                        .frame(width: 14, height: 14)
                        .offset(x: geo.size.width * clampedPos - 7)
                        .animation(.easeOut(duration: 0.4), value: sentimentScore)
                }
            }
            .frame(height: 14)
        }
    }

    private var loadingBlock: some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.7)
                .tint(InstitutionalTheme.Colors.Motors.hermes)
            Text("BAROMETRE OKUNUYOR…")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }

    // MARK: - Helpers

    private var tone: ArgusChipTone {
        if sentimentScore >= 30 { return .aurora }
        if sentimentScore <= -30 { return .crimson }
        return .titan
    }

    private func loadSentiment() async {
        if let payload = try? await BISTSentimentEngine.shared.analyzeSentimentPayload(for: symbol) {
            let score = payload.result.overallScore
            let normalized = (score - 50) * 2

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

// MARK: - Analist Eğitim Wrapper (V5)

struct AnalistEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        EducationShell(
            showEducation: $showEducation,
            content: { BistAnalystCard(symbol: symbol) },
            note: "Analist konsensüsü, profesyonel yatırımcıların ortalama beklentisini gösterir. Hedef fiyat, analistlerin 12 aylık tahminidir. Tek başına yeterli olmaz, diğer modüllerle birlikte değerlendirilmelidir."
        )
    }
}

// MARK: - KAP Eğitim Wrapper (V5)

struct KAPEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        EducationShell(
            showEducation: $showEducation,
            content: { KulisKAPCard(symbol: symbol) },
            note: "KAP bildirimleri şirketlerin yasal olarak açıklaması gereken önemli gelişmelerdir. Finansal tablolar, yönetim kurulu kararları, ortaklık yapısı değişiklikleri gibi bilgiler burada yayınlanır. Hızlı hareket eden bilgidir."
        )
    }
}

// MARK: - Temettü Eğitim Wrapper (V5)

struct TemettuEgitimWrapper: View {
    let symbol: String
    @State private var showEducation = false

    var body: some View {
        EducationShell(
            showEducation: $showEducation,
            content: { BistDividendCard(symbol: symbol) },
            note: "Temettü, şirketin kârından ortaklara dağıttığı paydır. Düzenli temettü ödeyen şirketler genelde daha güvenilir kabul edilir. Bedelsiz sermaye artırımı ise hisse adedini artırır ancak toplam değeri değiştirmez."
        )
    }
}

// MARK: - V5 Eğitim Shell
//
// "Ne Demek?" butonu + açılır titan tonlu eğitim notu. Artık orange
// lightbulb yerine ArgusChip, `💡` emoji yerine ArgusDot.

private struct EducationShell<Content: View>: View {
    @Binding var showEducation: Bool
    let content: () -> Content
    let note: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            content()

            EducationToggle(isOn: $showEducation)
                .padding(.top, 2)

            if showEducation {
                EducationRow(text: note)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct EducationToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.titan)
                Text("NE DEMEK?")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(InstitutionalTheme.Colors.titan)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(InstitutionalTheme.Colors.titan.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(InstitutionalTheme.Colors.titan.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EducationRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ArgusDot(color: InstitutionalTheme.Colors.titan)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.titan.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
        )
    }
}
