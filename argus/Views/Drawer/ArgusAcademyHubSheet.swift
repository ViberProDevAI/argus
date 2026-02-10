import SwiftUI

struct ArgusAcademyHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSheet: ArgusDrawerView.DrawerSheet?

    private let lessons: [AcademyLesson] = [
        AcademyLesson(
            title: "Ders 1 · Argus Nasıl Karar Verir?",
            subtitle: "Temel karar zinciri",
            purpose: "Sinyalin nereden geldiğini anlamak",
            durationMinutes: 6,
            sheet: .systemGuide
        ),
        AcademyLesson(
            title: "Ders 2 · Motorları Doğru Kullanma",
            subtitle: "Orion, Atlas, Hermes, Aether",
            purpose: "Yanlış motora güvenme hatasını bitirmek",
            durationMinutes: 8,
            sheet: .engineGuide
        ),
        AcademyLesson(
            title: "Ders 3 · Rejimi Okuma",
            subtitle: "Trend, çapraz, risk-off",
            purpose: "Piyasa koşuluna göre davranmak",
            durationMinutes: 7,
            sheet: .regimeGuide
        ),
        AcademyLesson(
            title: "Ders 4 · Alkindus ile Pratik",
            subtitle: "Doğal dilde hızlı analiz",
            purpose: "Günlük kullanım akışını hızlandırmak",
            durationMinutes: 5,
            sheet: .alkindusGuide
        )
    ]

    private let resources: [AcademyResource] = [
        AcademyResource(
            title: "Finans Sözlüğü",
            subtitle: "Terimler, oranlar, kavramlar",
            sheet: .dictionary
        ),
        AcademyResource(
            title: "Finans Özlü Sözler",
            subtitle: "Psikoloji ve disiplin notları",
            sheet: .financeWisdom
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    lessonPathSection
                    practiceProtocolSection
                    resourcesSection
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .navigationTitle("Argus Akademi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
        }
        .sheet(item: $selectedSheet) { sheet in
            academyContent(for: sheet)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sıfırdan Öğrenme Programı")
                .font(InstitutionalTheme.Typography.title)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Text("Argus’u doğru kullanmak için tek bir yol: önce karar mantığı, sonra motorlar, sonra rejim, en son doğal dil pratiği.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Öneri: Dersi aç -> aynı sembolde Sanctum’a dön -> tekrar yorumla.")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lessonPathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ÖĞRENME YOLU")

            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                Button {
                    selectedSheet = lesson.sheet
                } label: {
                    lessonRow(order: index + 1, lesson: lesson)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lessonRow(order: Int, lesson: AcademyLesson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(String(format: "%02d", order))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                    .frame(width: 26, alignment: .leading)
                Text(lesson.title)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Text(lesson.subtitle)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            Text("Hedef: \(lesson.purpose) · Tahmini süre: \(lesson.durationMinutes) dk")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private var practiceProtocolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("PRATİK PROTOKOLÜ")
            protocolRow(index: "1", text: "Dersi bitirir bitirmez aynı sembolde Sanctum ekranına dön.")
            protocolRow(index: "2", text: "Önce rejimi oku, sonra motor ayrışmasını kontrol et.")
            protocolRow(index: "3", text: "En son ANALİZ metnini açıp kendi yorumunla karşılaştır.")
        }
    }

    private func protocolRow(index: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 12, alignment: .leading)
            Text(text)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("KAYNAKLAR")

            ForEach(resources) { resource in
                Button {
                    selectedSheet = resource.sheet
                } label: {
                    resourceRow(resource)
                }
                .buttonStyle(.plain)
            }

            Button {
                selectedSheet = .calendar
            } label: {
                HStack(spacing: 8) {
                    Text("Makro Takvim (opsiyonel)")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func resourceRow(_ resource: AcademyResource) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(resource.subtitle)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(InstitutionalTheme.Typography.micro)
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .tracking(0.8)
    }

    @ViewBuilder
    private func academyContent(for sheet: ArgusDrawerView.DrawerSheet) -> some View {
        switch sheet {
        case .systemGuide:
            SystemGuideSheet()
        case .engineGuide:
            EngineGuideSheet()
        case .regimeGuide:
            RegimeGuideSheet()
        case .dictionary:
            FinanceDictionarySheet()
        case .calendar:
            EconomicCalendarSheet()
        case .systemHealth:
            EmptyView()
        case .feedback:
            FeedbackSheet()
        case .alkindusGuide:
            AlkindusEducationSheet()
        case .financeWisdom:
            FinanceWisdomSheet()
        case .academyHub:
            EmptyView()
        }
    }
}

private struct AcademyLesson: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let purpose: String
    let durationMinutes: Int
    let sheet: ArgusDrawerView.DrawerSheet
}

private struct AcademyResource: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let sheet: ArgusDrawerView.DrawerSheet
}
