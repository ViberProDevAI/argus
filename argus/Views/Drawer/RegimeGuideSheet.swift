import SwiftUI

struct RegimeGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    regimesSection
                    detectionSection
                    strategySection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Piyasa Rejimleri")
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
            Text("REJIM NEDIR?")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)

            Text("Piyasa rejimi, piyasanin genel karakterini tanimlar. Farkli rejimlerde farkli stratejiler calisir. Yanlis rejimde dogru strateji bile para kaybettirir.")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Regimes

    private var regimesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("REJIM TIPLERI")

            VStack(spacing: 12) {
                regimeCard(
                    name: "TREND",
                    color: Theme.positive,
                    description: "Piyasa net bir yone sahip. Yukselis veya dusus trendi mevcut.",
                    indicators: "ADX > 25, net fiyat yonu",
                    strategy: "Trendi takip et, Orion motoru oncelikli"
                )

                regimeCard(
                    name: "CAPRAZ (Yatay)",
                    color: Theme.warning,
                    description: "Piyasa belirli bir aralikta yukari-asagi hareket ediyor.",
                    indicators: "ADX < 20, destek/direnc arasinda sikisma",
                    strategy: "Trend motorlarindan kacin, destek/direncte islem yap"
                )

                regimeCard(
                    name: "RISK-OFF",
                    color: Theme.negative,
                    description: "Yuksek belirsizlik ve korku. Yatirimcilar riskli varliklardan kaciyor.",
                    indicators: "VIX > 30, sert dususler, yuksek volatilite",
                    strategy: "Nakit agirligini artir, defansif sektorlere don"
                )
            }
        }
    }

    private func regimeCard(
        name: String,
        color: Color,
        description: String,
        indicators: String,
        strategy: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
            }

            Text(description)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Divider().background(color.opacity(0.3))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Gostergeler:")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(indicators)
                        .font(.caption2)
                        .foregroundColor(.white)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("Strateji:")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(strategy)
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(Theme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Detection

    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("REJIM NASIL BELIRLENIR?")

            VStack(alignment: .leading, spacing: 8) {
                detectionRow("ADX Seviyesi", "Trend gucu olcer")
                detectionRow("VIX", "Korku/belirsizlik seviyesi")
                detectionRow("Yabanci Akisi", "Risk istahi gostergesi")
                detectionRow("Faiz Trendi", "Parasal kosullar")
            }

            Text("Chiron motoru bu gostergeleri birlestirerek dominant rejimi tespit eder ve diger motorlarin agirliklarini ayarlar.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    private func detectionRow(_ indicator: String, _ description: String) -> some View {
        HStack {
            Text(indicator)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.tint)
                .frame(width: 100, alignment: .leading)

            Text(description)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    // MARK: - Strategy

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("REJIME GORE STRATEJI")

            tipBox("TREND rejiminde Orion'a guvenilebilir. CAPRAZ rejimde Orion cok sayida yanlis sinyal uretir - bu rejimde islem sayisini azaltin veya destek/direnc stratejisi kullanin.")

            tipBox("RISK-OFF rejiminde en iyi strateji genellikle 'bir sey yapmamak'tir. Nakit tutun, firtina dinene kadar bekleyin.")
        }
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
    RegimeGuideSheet()
}
