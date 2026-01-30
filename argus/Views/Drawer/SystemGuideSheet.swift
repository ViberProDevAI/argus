import SwiftUI

struct SystemGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    flowDiagram
                    dataSourcesSection
                    enginesOverview
                    decisionSection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Argus Nasil Calisir?")
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
            Text("ARGUS KARAR SISTEMI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)

            Text("Argus, birden fazla analiz motorunun ciktisini birlestirerek yatirim kararlari ureten bir karar destek sistemidir.")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Flow Diagram

    private var flowDiagram: some View {
        VStack(spacing: 16) {
            flowStep(number: "1", title: "Veri Toplama", description: "BIST, TCMB, Yahoo Finance")
            flowArrow
            flowStep(number: "2", title: "Motor Analizi", description: "Her motor kendi bakis acisiyla degerlendirir")
            flowArrow
            flowStep(number: "3", title: "Konsey Oylamasi", description: "Motorlarin sinyalleri agirliklandirilir")
            flowArrow
            flowStep(number: "4", title: "Karar", description: "AL / SAT / BEKLE")
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(Theme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }

    private func flowStep(number: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Theme.background)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.tint))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption)
            .foregroundColor(Theme.tint.opacity(0.5))
    }

    // MARK: - Data Sources

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("VERI KAYNAKLARI")

            VStack(spacing: 8) {
                dataSourceRow("BIST", "Anlik fiyat, hacim, derinlik verileri")
                dataSourceRow("TCMB", "Faiz, kur, enflasyon verileri")
                dataSourceRow("Yahoo Finance", "Global piyasa verileri")
                dataSourceRow("KAP", "Sirket haberleri ve finansal tablolar")
            }
        }
    }

    private func dataSourceRow(_ source: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Text(source)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.tint)
                .frame(width: 80, alignment: .leading)

            Text(description)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    // MARK: - Engines Overview

    private var enginesOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ANALIZ MOTORLARI")

            VStack(spacing: 8) {
                engineRow("Orion", "Teknik momentum", "SAR, TSI, RSI, ADX")
                engineRow("Atlas", "Temel degerleme", "F/K, PD/DD, CAGR")
                engineRow("Phoenix", "Trend yakalama", "Breakout, ADX")
                engineRow("Chiron", "Makro rejim", "VIX, faiz, yabanci akis")
            }

            Text("Her motor bagimsiz sinyal uretir. Konsey bu sinyalleri agirliklandirarak nihai karari olusturur.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    private func engineRow(_ name: String, _ role: String, _ indicators: String) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(role)
                    .font(.caption)
                    .foregroundColor(Theme.tint)

                Text(indicators)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    // MARK: - Decision Section

    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("KARAR SURECI")

            VStack(alignment: .leading, spacing: 8) {
                Text("Argus Konseyi, her motorun ciktisini motor agirligi ile carparak toplam skor hesaplar.")
                    .font(.caption)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    decisionBadge("AL", color: Theme.positive)
                    decisionBadge("SAT", color: Theme.negative)
                    decisionBadge("BEKLE", color: Theme.neutral)
                }
                .padding(.top, 4)

                Text("Motor agirliklari piyasa rejimine gore dinamik olarak ayarlanir. Ornegin trend rejiminde Orion agirligi artar.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 8)
            }
        }
    }

    private func decisionBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(DesignTokens.Opacity.glassCard))
            .cornerRadius(Theme.Radius.small)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Theme.textSecondary)
            .tracking(0.5)
    }
}

#Preview {
    SystemGuideSheet()
}
