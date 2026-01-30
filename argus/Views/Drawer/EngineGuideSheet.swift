import SwiftUI

struct EngineGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEngine = 0

    private let engines = ["Orion", "Atlas", "Phoenix", "Chiron"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Engine Selector
                Picker("Motor", selection: $selectedEngine) {
                    ForEach(0..<engines.count, id: \.self) { index in
                        Text(engines[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(16)
                .background(Theme.cardBackground)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        engineContent(for: selectedEngine)
                    }
                    .padding(20)
                }
            }
            .background(Theme.background)
            .navigationTitle("Motor Rehberi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
        }
    }

    // MARK: - Engine Content

    @ViewBuilder
    private func engineContent(for index: Int) -> some View {
        switch index {
        case 0: orionContent
        case 1: atlasContent
        case 2: phoenixContent
        case 3: chironContent
        default: EmptyView()
        }
    }

    // MARK: - Orion

    private var orionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            engineHeader(
                name: "ORION",
                subtitle: "Teknik Momentum Motoru",
                description: "Fiyat hareketlerini ve momentum gostergelerini analiz ederek kisa-orta vadeli sinyaller uretir."
            )

            indicatorsSection([
                ("SAR", "Trend yonu ve donus noktalari"),
                ("TSI", "Momentum gucu (-100 / +100)"),
                ("RSI", "Asiri alim/satim (0-100)"),
                ("ADX", "Trend gucu (0-100)")
            ])

            usageSection(
                whenToUse: [
                    "ADX > 25 (guclu trend var)",
                    "Piyasa net yone sahip",
                    "Volatilite asiri yuksek degil"
                ],
                whenNotToUse: [
                    "ADX < 20 (yatay piyasa)",
                    "Capraz/range piyasa",
                    "Kriz donemleri"
                ]
            )

            tipBox("Orion yatay piyasada cok sayida yanlis sinyal uretir. Oncelikle ADX ile trend varligini dogrulayin.")
        }
    }

    // MARK: - Atlas

    private var atlasContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            engineHeader(
                name: "ATLAS",
                subtitle: "Temel Degerleme Motoru",
                description: "Sirketlerin finansal tablolarini analiz ederek degerinin altinda islenen hisseleri tespit eder."
            )

            indicatorsSection([
                ("F/K", "Fiyat/Kazanc orani"),
                ("PD/DD", "Piyasa/Defter degeri"),
                ("CAGR", "Bilesik buyume orani"),
                ("Borc/Ozkaynak", "Finansal yapilandirma")
            ])

            usageSection(
                whenToUse: [
                    "Risk-off donemleri",
                    "Uzun vadeli yatirim",
                    "Deger odakli strateji"
                ],
                whenNotToUse: [
                    "Guclu trend piyasasi (Orion daha iyi)",
                    "Kisa vadeli islemler",
                    "Momentum stratejileri"
                ]
            )

            tipBox("Atlas puani 80+ olan hisseler temel olarak ucuz sayilir. Ancak ucuz olmak tek basina yeterli degil, catalyst gerekir.")
        }
    }

    // MARK: - Phoenix

    private var phoenixContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            engineHeader(
                name: "PHOENIX",
                subtitle: "Trend Yakalama Motoru",
                description: "Yeni baslayan trendleri ve kirilim noktalarini tespit ederek erken giris firsatlari arar."
            )

            indicatorsSection([
                ("Breakout", "Destek/direnc kirilimlari"),
                ("ADX", "Trend gucu artisi"),
                ("Yeni Zirveler", "52 haftalik en yuksekler")
            ])

            usageSection(
                whenToUse: [
                    "ADX yukselirken",
                    "Onemli seviye kirilimlari",
                    "Hacimle desteklenen hareketler"
                ],
                whenNotToUse: [
                    "Yatay piyasa (ADX < 20)",
                    "Dusuk hacim ortami",
                    "Belirsizlik donemleri"
                ]
            )

            tipBox("Phoenix ralli yakalama motorudur. Yanlis kiriliklar (fake breakout) riskine karsi stop-loss kullanin.")
        }
    }

    // MARK: - Chiron

    private var chironContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            engineHeader(
                name: "CHIRON",
                subtitle: "Makro Rejim Motoru",
                description: "Piyasanin genel durumunu (rejim) belirler ve diger motorlarin agirliklarini ayarlar."
            )

            indicatorsSection([
                ("VIX", "Volatilite/korku endeksi"),
                ("Faiz", "TCMB/FED politika faizi"),
                ("Yabanci", "Yabanci yatirimci akisi"),
                ("Makro Veri", "Enflasyon, GSYH, issizlik")
            ])

            regimeSection

            tipBox("Chiron direkt sinyal vermez, piyasa halini tespit eder. Diger motorlarin ne zaman kullanilacagini belirler.")
        }
    }

    private var regimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PIYASA REJIMLERI")

            VStack(spacing: 8) {
                regimeRow("TREND", "Guclu yon mevcut", "Orion oncelikli", Theme.positive)
                regimeRow("CAPRAZ", "Yatay hareket", "Atlas oncelikli", Theme.warning)
                regimeRow("RISK-OFF", "Yuksek belirsizlik", "Nakit oncelikli", Theme.negative)
            }
        }
    }

    private func regimeRow(_ name: String, _ description: String, _ strategy: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)

            Text(description)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(strategy)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    // MARK: - Components

    private func engineHeader(name: String, subtitle: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Theme.tint)

            Text(description)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    private func indicatorsSection(_ indicators: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("GOSTERGELER")

            VStack(spacing: 6) {
                ForEach(indicators, id: \.0) { indicator in
                    HStack {
                        Text(indicator.0)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.tint)
                            .frame(width: 80, alignment: .leading)

                        Text(indicator.1)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.02))
            .cornerRadius(Theme.Radius.small)
        }
    }

    private func usageSection(whenToUse: [String], whenNotToUse: [String]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NE ZAMAN KULLAN")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.positive)

                ForEach(whenToUse, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(Theme.positive)
                        Text(item)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("NE ZAMAN KALIN")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.negative)

                ForEach(whenNotToUse, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(Theme.negative)
                        Text(item)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    EngineGuideSheet()
}
