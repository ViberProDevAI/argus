import SwiftUI

/// Motor öğrenme rehberi — kullanıcıya yönelik dilde, mitolojik isim olmadan.
/// 2026-04-30: "Orion / Atlas / Hermes / Aether" gibi iç modül adları kaldırıldı,
/// yerine kullanıcının anlayacağı kavramsal başlıklar kullanılıyor.
struct EngineGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEngine: EngineType = .technical

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "DERS 2 · ANALİZ MOTORLARI",
                subtitle: "TEKNİK · BİLANÇO · HABER · MAKRO",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [.custom(sfSymbol: "xmark", action: { dismiss() })]
            )

            Picker("Motor", selection: $selectedEngine) {
                ForEach(EngineType.allCases) { engine in
                    Text(engine.shortName).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)
            .background(InstitutionalTheme.Colors.surface1)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection(selectedEngine)
                    whatItMeasuresSection(selectedEngine)
                    readingSequenceSection(selectedEngine)
                    usageSection(selectedEngine)
                    cautionSection(selectedEngine)
                }
                .padding(20)
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
    }

    private func headerSection(_ engine: EngineType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(engine.title)
                .font(InstitutionalTheme.Typography.title)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(engine.subtitle)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.primary)
            Text(engine.summary)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func whatItMeasuresSection(_ engine: EngineType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("NEYİ ÖLÇER")
            ForEach(engine.checks, id: \.self) { item in
                bullet(item)
            }
        }
    }

    private func readingSequenceSection(_ engine: EngineType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("OKUMA SIRASI")
            ForEach(Array(engine.readingSequence.enumerated()), id: \.offset) { index, item in
                sequenceRow(index: index + 1, text: item)
            }
        }
    }

    private func usageSection(_ engine: EngineType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("KULLANIM REHBERİ")

            VStack(alignment: .leading, spacing: 8) {
                Text("Ne zaman kullan?")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.positive)
                ForEach(engine.whenToUse, id: \.self) { item in
                    bullet(item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ne zaman tek başına güvenme?")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                ForEach(engine.whenNotToTrustAlone, id: \.self) { item in
                    bullet(item)
                }
            }
        }
    }

    private func cautionSection(_ engine: EngineType) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.warning)
                .padding(.top, 2)

            Text(engine.caution)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(InstitutionalTheme.Colors.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                )
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundColor(InstitutionalTheme.Colors.primary)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(InstitutionalTheme.Colors.primary)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sequenceRow(index: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(String(index))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .frame(width: 14, alignment: .leading)
                Text(text)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }
}

private enum EngineType: String, CaseIterable, Identifiable {
    case technical
    case fundamental
    case news
    case macro

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .technical:   return "Teknik"
        case .fundamental: return "Bilanço"
        case .news:        return "Haber"
        case .macro:       return "Makro"
        }
    }

    var title: String {
        switch self {
        case .technical:   return "Teknik Analiz · Momentum"
        case .fundamental: return "Bilanço & Değerleme"
        case .news:        return "Haber Akışı & Sentiment"
        case .macro:       return "Makro Ortam & Rejim"
        }
    }

    var subtitle: String {
        switch self {
        case .technical:   return "Soru: Fiyatın ritmi güçlü mü, zayıf mı?"
        case .fundamental: return "Soru: Şirketin kalitesi fiyatla uyumlu mu?"
        case .news:        return "Soru: Haber akışı fiyatı taşıyor mu?"
        case .macro:       return "Soru: Piyasa risk iştahı artıyor mu, azalıyor mu?"
        }
    }

    var summary: String {
        switch self {
        case .technical:
            return "Kısa ve orta vadeli yön değişimlerini fiyat hareketi ve göstergeler üzerinden okur."
        case .fundamental:
            return "Orta ve uzun vadede bilanço gücü ile piyasa fiyatı arasındaki dengeyi ölçer."
        case .news:
            return "Haberi gürültüden ayırır; etkili bilgiyle yüzeysel başlığı ayrıştırır."
        case .macro:
            return "Pozisyonun yönünden çok risk dozunu belirlemekte kullanılır."
        }
    }

    var checks: [String] {
        switch self {
        case .technical:
            return [
                "RSI ve benzeri osilatörlerle hız değişimini ölçer.",
                "ADX ile trendin gücünü kontrol eder.",
                "Kırılım sonrası devam edip etmeyeceğini test eder."
            ]
        case .fundamental:
            return [
                "F/K, PD/DD gibi çarpanlarla göreli pahalılık/ucuzluk okur.",
                "Kârlılık ve borç kalitesiyle bilanço dayanıklılığına bakar.",
                "Döngüsel sektörlerde sürdürülebilirlik sinyali arar."
            ]
        case .news:
            return [
                "Haberin tonunu (pozitif / negatif / nötr) sınıflandırır.",
                "Haberi kaynağı ve bağlamıyla birlikte ağırlıklandırır.",
                "Kısa süreli gürültü ile yön değiştirici haberi ayırır."
            ]
        case .macro:
            return [
                "VIX hareketini ve oynaklık rejimini izler.",
                "Faiz, tahvil ve dolar ekseninde risk iştahını ölçer.",
                "Genel risk dozunu rejime göre savunmacı ya da agresif tarafa kaydırır."
            ]
        }
    }

    var readingSequence: [String] {
        switch self {
        case .technical:
            return [
                "Önce trend var mı, yok mu kontrol et.",
                "Sonra momentum ivmesinin devam edip etmediğine bak.",
                "En son stop / bozulma seviyesini belirle."
            ]
        case .fundamental:
            return [
                "Önce şirketin kalite profilini oku.",
                "Sonra fiyatın bu kaliteyi ne kadar yansıttığını karşılaştır.",
                "En son teknik ve rejim teyidiyle giriş zamanını seç."
            ]
        case .news:
            return [
                "Haberi başlıkla değil, içerik ve kaynakla değerlendir.",
                "Piyasanın habere ilk tepkisini izle.",
                "Etkisi kalıcı mı, geçici mi karar ver."
            ]
        case .macro:
            return [
                "Önce volatilite yönünü oku (risk yükselişi mi, düşüşü mü).",
                "Sonra likidite koşullarını kontrol et.",
                "En son pozisyon boyutunu rejime göre ayarla."
            ]
        }
    }

    var whenToUse: [String] {
        switch self {
        case .technical:
            return [
                "Yön belirgin ve işlem zamanlaması kritik olduğunda.",
                "Kırılım veya dönüş teyidi almak istediğinde."
            ]
        case .fundamental:
            return [
                "Orta / uzun vadeli seçim yaparken.",
                "Kalite odaklı portföy kurarken."
            ]
        case .news:
            return [
                "Ani hareketin nedenini anlamak istediğinde.",
                "Bilanço / duyuru gibi haber yoğun günlerde."
            ]
        case .macro:
            return [
                "Risk boyutunu belirlerken.",
                "Piyasa rejimi değiştiğinde pozisyonu yeniden kalibre ederken."
            ]
        }
    }

    var whenNotToTrustAlone: [String] {
        switch self {
        case .technical:
            return [
                "Yatay piyasada sık fake hareket varken.",
                "Güçlü haber akışı fiyatı keskin bozarken."
            ]
        case .fundamental:
            return [
                "Dakikalık işlem kararında.",
                "Yalnızca çarpan ucuz diye giriş yapılırken."
            ]
        case .news:
            return [
                "Haber akışı çok zayıfken.",
                "Başlık okunup fiyat tepkisi doğrulanmadan karar verilirken."
            ]
        case .macro:
            return [
                "Tek başına hisse seçmek için.",
                "Mikro ölçekte 1-2 mumluk hareket yorumunda."
            ]
        }
    }

    var caution: String {
        switch self {
        case .technical:
            return "Teknik analiz hız verir; yönü kendi başına garanti etmez. Rejime ters düşen hız sinyaline tek başına güvenme."
        case .fundamental:
            return "Bilanço analizi kaliteyi ölçer; zamanlamayı değil. Teknik teyit olmadan giriş, gereksiz bekleme maliyeti yaratabilir."
        case .news:
            return "Haber akışı bağlam üretir; emir vermez. Haber güçlü olsa bile fiyat onayı olmadan işlem açma."
        case .macro:
            return "Makro analiz risk dozunu ayarlar. Yön ve zamanlama için mutlaka diğer analiz katmanlarının teyidini ekle."
        }
    }
}

#Preview {
    EngineGuideSheet()
}
