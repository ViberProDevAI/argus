import SwiftUI

struct EconomicCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    upcomingEvents
                    impactGuide
                    tcmbSection
                    fedSection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Ekonomi Takvimi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
        }
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAKRO TAKVIM")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)

            Text("Onemli ekonomik olaylar piyasalari dogrudan etkiler. Bu olaylarin oncesinde ve sonrasinda volatilite artar.")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Upcoming Events (Placeholder - ideally from API)

    private var upcomingEvents: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("YAKLASAN OLAYLAR")

            VStack(spacing: 8) {
                eventRow(date: "Her ay", event: "TCMB PPK Toplantisi", impact: .high)
                eventRow(date: "Her ay", event: "TUFE Aciklamasi", impact: .high)
                eventRow(date: "6 haftada bir", event: "FED FOMC Karari", impact: .high)
                eventRow(date: "Ceyreklik", event: "GSYH Verisi", impact: .medium)
                eventRow(date: "Aylik", event: "Issizlik Orani", impact: .medium)
            }

            Text("Gercek zamanli takvim verileri yaklasik olarak ekleniyor.")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .italic()
                .padding(.top, 4)
        }
    }

    private func eventRow(date: String, event: String, impact: EventImpact) -> some View {
        HStack(spacing: 12) {
            Text(date)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(event)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            impactBadge(impact)
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    private enum EventImpact {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return Theme.negative
            case .medium: return Theme.warning
            case .low: return Theme.textSecondary
            }
        }

        var text: String {
            switch self {
            case .high: return "Yuksek"
            case .medium: return "Orta"
            case .low: return "Dusuk"
            }
        }
    }

    private func impactBadge(_ impact: EventImpact) -> some View {
        Text(impact.text)
            .font(.caption2)
            .foregroundColor(impact.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(impact.color.opacity(DesignTokens.Opacity.glassCard))
            .cornerRadius(4)
    }

    // MARK: - Impact Guide

    private var impactGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ETKI REHBERI")

            VStack(alignment: .leading, spacing: 8) {
                Text("Yuksek etkili olaylar oncesinde:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    guideItem("Pozisyon boyutunu kucult")
                    guideItem("Stop-loss seviyelerini gozden gecir")
                    guideItem("Ani volatiliteye hazirlikli ol")
                    guideItem("Veri sonrasi ilk 15 dakika islem yapma")
                }
            }
        }
    }

    private func guideItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Theme.tint)
            Text(text)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - TCMB

    private var tcmbSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TCMB KARARLARI")

            VStack(alignment: .leading, spacing: 8) {
                Text("TCMB Para Politikasi Kurulu (PPK) her ay toplanir ve politika faizini belirler.")
                    .font(.caption)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    impactScenario("Faiz Artisi", "BIST icin genellikle negatif", Theme.negative)
                    impactScenario("Faiz Indirimi", "BIST icin genellikle pozitif", Theme.positive)
                }

                Text("Ancak beklentiler onemli: Beklenen faiz artisi zaten fiyatlanmis olabilir.")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - FED

    private var fedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("FED KARARLARI")

            VStack(alignment: .leading, spacing: 8) {
                Text("ABD Merkez Bankasi (FED) kararlari global piyasalari etkiler. FOMC toplantilari yaklasik 6 haftada bir yapilir.")
                    .font(.caption)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    impactScenario("Sikilastirma", "Gelisen piyasalardan cikis", Theme.negative)
                    impactScenario("Gevsetme", "Risk istahi artar", Theme.positive)
                }

                tipBox("FED karari sonrasi Dolar/TL hareketini izleyin. Guclu dolar genellikle BIST icin negatif.")
            }
        }
    }

    private func impactScenario(_ scenario: String, _ impact: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenario)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)

            Text(impact)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tipBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb")
                .font(.subheadline)
                .foregroundColor(Theme.tint)

            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Theme.tint.opacity(0.1))
        .cornerRadius(Theme.Radius.small)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Theme.textSecondary)
            .tracking(0.5)
    }
}

#Preview {
    EconomicCalendarSheet()
}
