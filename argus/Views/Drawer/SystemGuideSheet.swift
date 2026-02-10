import SwiftUI

struct SystemGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    argusInThreeLines
                    decisionFlowSection
                    sanctumReadingSection
                    quickPracticeSection
                    mistakeGuardSection
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Ders 1 · Sistem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Argus Karar Sistemi")
                .font(InstitutionalTheme.Typography.title)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text("Amaç: Ekrandaki çıktıyı ezberlemek değil, kararın hangi zincirden geldiğini görmek.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("Bu ders 6 dakikadır. Bitince aynı sembolde Sanctum’a dönüp tekrar okumalısın.")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .tracking(0.3)
        }
    }

    private var argusInThreeLines: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("3 CÜMLEDE ARGUS")
            bullet("Argus tek bir model değil; birden çok motorun birlikte çalıştığı bir karar sistemi.")
            bullet("Sinyal önce veriyle beslenir, sonra motorlar puan üretir, en son konsey ağırlıklandırır.")
            bullet("Doğru okuma sırası: rejim -> motor ayrışması -> nihai karar.")
        }
    }

    private var decisionFlowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("KARAR ZİNCİRİ")
            numbered("1", "Veri Toplama", "Fiyat, hacim, haber ve makro veri aynı anda çekilir.")
            numbered("2", "Motor Skorları", "Orion/Atlas/Hermes/Aether kendi uzmanlığında puan üretir.")
            numbered("3", "Ağırlıklandırma", "Rejim bilgisine göre hangi motorun sesi daha güçlü olacağı belirlenir.")
            numbered("4", "Nihai Çıktı", "AL · SAT · BEKLE kararı ve açıklama birlikte üretilir.")
        }
    }

    private var sanctumReadingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SANCTUM EKRANINI OKUMA")
            bullet("Merkez alan: Konseyin birleşik yorumu (tek cümlelik yön).")
            bullet("Çevredeki motorlar: Ayrışmayı görürsün; kimin neden farklı düşündüğünü buradan anlarsın.")
            bullet("Sağ üst ANALİZ: Tüm sistemi metne döker; kararın nedeni burada netleşir.")
        }
    }

    private var quickPracticeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("90 SANİYELİK PRATİK")
            numbered("A", "Rejimi Gör", "Aether ne diyor? Risk artırmalı mısın azaltmalı mısın?")
            numbered("B", "Ayrışmayı Bul", "Hangi motor uyumsuz? Ayrışma varsa nedeni anlamadan işlem yok.")
            numbered("C", "ANALİZ ile Kilitle", "Metin, senin okumanla uyumluysa karar tamam.")
        }
    }

    private var mistakeGuardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("HATA ÖNLEYİCİ KURALLAR")
            bullet("Tek motor skoru ile işlem açma.")
            bullet("Rejim çaprazken agresif trend işlemi zorlama.")
            bullet("ANALİZ metnini tek başına değil, motor dağılımıyla birlikte oku.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(InstitutionalTheme.Colors.primary)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func numbered(_ index: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(index)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .frame(width: 16, alignment: .leading)
                Text(title)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .padding(.leading, 24)
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .tracking(0.8)
    }
}

#Preview {
    SystemGuideSheet()
}
