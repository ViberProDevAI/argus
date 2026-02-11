import SwiftUI

struct EngineGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEngine: EngineType = .orion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Ders 2 · Motorlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
        }
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
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .tracking(0.8)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(InstitutionalTheme.Colors.primary)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
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
    case orion
    case atlas
    case hermes
    case aether

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .orion: return "Orion"
        case .atlas: return "Atlas"
        case .hermes: return "Hermes"
        case .aether: return "Aether"
        }
    }

    var title: String {
        switch self {
        case .orion: return "Orion · Teknik Momentum"
        case .atlas: return "Atlas · Temel Değerleme"
        case .hermes: return "Hermes · Haber ve Duygu"
        case .aether: return "Aether · Makro Rejim"
        }
    }

    var subtitle: String {
        switch self {
        case .orion: return "Soru: Fiyatın ritmi güçlü mü, zayıf mı?"
        case .atlas: return "Soru: Şirketin kalitesi fiyatla uyumlu mu?"
        case .hermes: return "Soru: Haber akışı fiyatı taşıyor mu?"
        case .aether: return "Soru: Piyasa risk iştahı artıyor mu azalıyor mu?"
        }
    }

    var summary: String {
        switch self {
        case .orion:
            return "Kısa ve orta vadeli yön değişimlerini yakalamaya çalışır."
        case .atlas:
            return "Orta ve uzun vadede bilanço gücü ile fiyat arasındaki dengeyi ölçer."
        case .hermes:
            return "Haberi gürültüden ayırır, etkili bilgi ile yüzeysel başlığı ayrıştırır."
        case .aether:
            return "Pozisyonun yönünden çok risk dozunu belirlemede kullanılır."
        }
    }

    var checks: [String] {
        switch self {
        case .orion:
            return [
                "RSI ve benzeri osilatörler ile hız değişimini ölçer.",
                "ADX ile trendin gücünü kontrol eder.",
                "Kırılım sonrası devam edip etmeyeceğini test eder."
            ]
        case .atlas:
            return [
                "F/K, PD/DD gibi çarpanlarla göreli pahalılık/ucuzluk okur.",
                "Kârlılık ve borç kalitesiyle bilanço dayanıklılığına bakar.",
                "Döngüsel sektörlerde sürdürülebilirlik sinyali arar."
            ]
        case .hermes:
            return [
                "Haberin tonunu (pozitif/negatif/nötr) sınıflandırır.",
                "Haberi kaynağı ve bağlamıyla birlikte ağırlıklandırır.",
                "Kısa süreli gürültü ile yön değiştirici haberi ayırır."
            ]
        case .aether:
            return [
                "VIX hareketini ve oynaklık rejimini izler.",
                "Faiz, tahvil ve dolar ekseninde risk iştahını ölçer.",
                "Motor ağırlıklarını rejime göre daha savunmacı veya agresif hale getirir."
            ]
        }
    }

    var readingSequence: [String] {
        switch self {
        case .orion:
            return [
                "Önce trend var mı yok mu kontrol et.",
                "Sonra momentum ivmesinin devam edip etmediğine bak.",
                "En son stop/bozulma seviyesini belirle."
            ]
        case .atlas:
            return [
                "Önce şirketin kalite profilini oku.",
                "Sonra fiyatın bu kaliteyi ne kadar yansıttığını karşılaştır.",
                "En son teknik ve rejim teyidiyle giriş zamanını seç."
            ]
        case .hermes:
            return [
                "Haberi başlıkla değil içerik ve kaynakla değerlendir.",
                "Piyasanın habere ilk tepkisini izle.",
                "Etkisi kalıcı mı geçici mi karar ver."
            ]
        case .aether:
            return [
                "Önce volatilite yönünü (risk yükselişi/düşüşü) oku.",
                "Sonra likidite koşullarını kontrol et.",
                "En son pozisyon boyutunu rejime göre ayarla."
            ]
        }
    }

    var whenToUse: [String] {
        switch self {
        case .orion:
            return [
                "Yön belirgin ve işlem zamanlaması kritik olduğunda.",
                "Kırılım veya dönüş teyidi almak istediğinde."
            ]
        case .atlas:
            return [
                "Orta/uzun vadeli seçim yaparken.",
                "Kalite odaklı portföy kurarken."
            ]
        case .hermes:
            return [
                "Ani hareketin nedenini anlamak istediğinde.",
                "Bilanço/duyuru gibi haber yoğun günlerde."
            ]
        case .aether:
            return [
                "Risk boyutunu belirlerken.",
                "Piyasa rejimi değiştiğinde pozisyonu yeniden kalibre ederken."
            ]
        }
    }

    var whenNotToTrustAlone: [String] {
        switch self {
        case .orion:
            return [
                "Yatay piyasada sık fake hareket varken.",
                "Güçlü haber akışı fiyatı keskin bozuyorken."
            ]
        case .atlas:
            return [
                "Dakikalık işlem kararında.",
                "Yalnızca çarpan ucuz diye giriş yapılırken."
            ]
        case .hermes:
            return [
                "Haber akışı çok zayıfken.",
                "Başlık okunup fiyat tepkisi doğrulanmadan karar verilirken."
            ]
        case .aether:
            return [
                "Tek başına hisse seçmek için.",
                "Mikro ölçekte 1-2 mumluk hareket yorumunda."
            ]
        }
    }

    var caution: String {
        switch self {
        case .orion:
            return "Orion hız verir; yönü körlemez. Rejime ters düşen hız sinyaline tek başına güvenme."
        case .atlas:
            return "Atlas kaliteyi ölçer; zamanlamayı değil. Teknik teyit olmadan giriş, gereksiz bekleme maliyeti yaratabilir."
        case .hermes:
            return "Hermes bağlam üretir; emir vermez. Haber güçlü olsa bile fiyat onayı olmadan işlem açma."
        case .aether:
            return "Aether risk dozunu ayarlar. Yön ve zamanlama için mutlaka diğer motorların teyidini ekle."
        }
    }
}

#Preview {
    EngineGuideSheet()
}
