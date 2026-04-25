import SwiftUI

/// V5 yasal uyarı ekranı. İlk açılışta, kullanıcı koşulları kabul etmeden
/// uygulama içeriğine geçemez. Renk paleti Institutional token'larına
/// (titan / crimson / holo) bağlı — raw SwiftUI renkleri kullanılmaz.
struct DisclaimerView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer: Bool = false
    @State private var canAccept: Bool = false

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header ribbon
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(InstitutionalTheme.Colors.titan.opacity(0.1))
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .stroke(InstitutionalTheme.Colors.titan.opacity(0.45), lineWidth: 1)
                            )
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(InstitutionalTheme.Colors.titan)
                    }
                    .shadow(color: InstitutionalTheme.Colors.titan.opacity(0.25), radius: 18)

                    VStack(spacing: 4) {
                        ArgusSectionCaption("ARGUS · YASAL")
                        Text("YASAL UYARI")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .tracking(3)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                .padding(.top, 48)

                ArgusHair()

                // Content Scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        disclaimerText(
                            title: "1. YATIRIM TAVSİYESİ DEĞİLDİR",
                            content: "Bu uygulama (Argus Terminal), yalnızca finansal verileri analiz etmek ve matematiksel modeller sunmak amacıyla geliştirilmiştir. Uygulama içerisindeki hiçbir veri, grafik, analiz veya 'AI Konseyi' yorumu, Sermaye Piyasası Kurulu (SPK) kapsamında bir 'Yatırım Tavsiyesi' değildir. Alım-satım kararları tamamen kullanıcının kendi sorumluluğundadır."
                        )

                        disclaimerText(
                            title: "2. RİSK BİLDİRİMİ",
                            content: "Finansal piyasalar (Hisse Senedi, Kripto Para, Forex vb.) yüksek risk içerir. Yatırımlarınızın tamamını veya bir kısmını kaybedebilirsiniz. Geçmiş performanslar, gelecek sonuçların garantisi değildir. Argus Terminal'in sunduğu tahminler olasılık hesaplarına dayanır ve kesinlik içermez."
                        )

                        disclaimerText(
                            title: "3. YAZILIM GARANTİSİ VE SORUMLULUK REDDİ",
                            content: "Bu yazılım 'OLDUĞU GİBİ' (AS-IS) sunulmuştur. Geliştirici ekip, yazılımın hatasız olduğunu, kesintisiz çalışacağını veya verilerin %100 doğru olduğunu garanti etmez. Uygulamanın kullanımı, veri hataları veya teknik aksaklıklar nedeniyle oluşabilecek doğrudan veya dolaylı hiçbir maddi/manevi zarardan Argus Ekibi sorumlu tutulamaz."
                        )

                        disclaimerText(
                            title: "4. KULLANIM KOŞULLARI",
                            content: "Uygulamayı kullanarak, piyasa risklerini anladığınızı ve tüm sorumluluğun şahsınıza ait olduğunu, geliştiriciyi herhangi bir zarardan dolayı sorumlu tutmayacağınızı kabul etmiş olursunuz."
                        )

                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.textTertiary, size: 4)
                            Text("SON GÜNCELLEME · 26.12.2025")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }
                        .padding(.top, 10)
                    }
                    .padding(22)
                }
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Accept button
                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                    haptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasAcceptedDisclaimer = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: canAccept ? "checkmark.seal.fill" : "hourglass")
                            .font(.system(size: 14, weight: .bold))
                        Text(canAccept ? "OKUDUM · KABUL EDİYORUM" : "LÜTFEN METNİ OKUYUN")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                    }
                    .foregroundColor(canAccept
                                     ? InstitutionalTheme.Colors.background
                                     : InstitutionalTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .fill(canAccept
                                  ? InstitutionalTheme.Colors.holo
                                  : InstitutionalTheme.Colors.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(canAccept
                                    ? InstitutionalTheme.Colors.holo
                                    : InstitutionalTheme.Colors.border, lineWidth: 1)
                    )
                    .shadow(color: canAccept
                            ? InstitutionalTheme.Colors.holo.opacity(0.35)
                            : .clear, radius: 14)
                }
                .disabled(!canAccept)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            canAccept = true
                        }
                    }
                }
            }
        }
    }

    private func disclaimerText(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ArgusDot(color: InstitutionalTheme.Colors.titan, size: 6)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(InstitutionalTheme.Colors.titan)
            }

            Text(content)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
}

#Preview {
    DisclaimerView()
}
