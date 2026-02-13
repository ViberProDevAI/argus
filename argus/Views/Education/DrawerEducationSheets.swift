import SwiftUI

// MARK: - Alkindus Education Sheet

struct AlkindusEducationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    promptSection
                    responseSection
                    dailyFlowSection
                    safetySection
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Ders 4 · Alkindus")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Alkindus Ne İşe Yarar?")
                .font(InstitutionalTheme.Typography.title)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text("Alkindus emir veren bir bot değil; Argus çıktısını doğal dilde anlaşılır hale getiren karar asistanıdır.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("Doğru kullanım: önce veri ekranını oku, sonra Alkindus ile neden-sonuç netleştir.")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .tracking(0.3)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SORU YAZIM ŞABLONU")
            promptRow("Bağlam", "“THYAO için bugün rejim ne söylüyor?”")
            promptRow("Ayrışma", "“Orion ve Atlas neden ayrıştı?”")
            promptRow("Aksiyon", "“Bu tabloda riski nasıl ayarlamalıyım?”")
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ÇIKTIYI DOĞRU OKUMA")
            bullet("Özet cümle: Alkindus’un ana yorumu.")
            bullet("Neden bölümü: Hangi motor ve hangi veri bunu üretti?")
            bullet("Risk notu: Pozisyon boyutunu artır mı azalt mı?")
            bullet("Karar kilidi: Senin gözlemin ile metin çelişiyorsa işlemi ertele.")
        }
    }

    private var dailyFlowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("GÜNLÜK KULLANIM AKIŞI")
            stepRow("1", "Sembolü aç ve rejimi kontrol et.")
            stepRow("2", "Motor dağılımını oku (özellikle ayrışma).")
            stepRow("3", "Alkindus’a 1 net soru sor.")
            stepRow("4", "Cevabı ANALİZ butonundaki rapor ile eşleştir.")
            stepRow("5", "Yalnızca uyum varsa işlem kararını onayla.")
        }
    }

    private var safetySection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.warning)
                .padding(.top, 2)
            Text("Alkindus hızlı cevap verir ama kesinlik vadetmez. Kesin karar için her zaman rejim + motor + fiyat davranışı üçlüsünü birlikte değerlendir.")
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

    private func promptRow(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 56, alignment: .leading)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func stepRow(_ index: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(index)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .frame(width: 14, alignment: .leading)
                Text(text)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .tracking(0.8)
    }
}
