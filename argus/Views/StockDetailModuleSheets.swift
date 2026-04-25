import SwiftUI

// MARK: - Stock Detail Module Sheets (V5)
//
// **2026-04-23 Hotfix.** Hisse detayındaki motor chip grid'inde
// Prometheus / Alkindus / Demeter chip'lerinin yanlış sheet açtığı bug'ı
// fix ettik. Bu dosya 3 yeni sheet için ortak chrome + yardımcı view'ları
// barındırır:
//   • `ModuleSheetShell` — ArgusNavHeader + dismiss + scroll sarmal.
//   • `ModulePlaceholderSheet` — fallback (advice yok, veri yok) için
//     bilgilendirici boş hal. Artık bomboş gri sheet yok.
//   • `ModulePlaceholderBody` — shell içinde kullanılan gövde.
//   • `DemeterSectorCard` — Demeter sektör skoru panel kartı; data
//     sözleşmesi HoloPanel'deki `.demeter` case'iyle aynı.

// MARK: - Module Sheet Shell

struct ModuleSheetShell<Content: View>: View {
    let title: String
    let motor: MotorEngine
    let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(title: String,
         motor: MotorEngine,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.motor = motor
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: title,
                subtitle: "HİSSE · MODÜL DETAYI",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [
                    .custom(sfSymbol: "xmark", action: { dismiss() })
                ]
            )

            ScrollView {
                VStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Module Placeholder Sheet

struct ModulePlaceholderSheet: View {
    let title: String
    let subtitle: String
    let message: String
    let motor: MotorEngine

    var body: some View {
        ModuleSheetShell(title: title, motor: motor) {
            ModulePlaceholderBody(message: message, motor: motor)
        }
    }
}

struct ModulePlaceholderBody: View {
    let message: String
    let motor: MotorEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MotorLogo(motor, size: 18)
                ArgusSectionCaption("VERİ BEKLENİYOR")
                Spacer()
                ArgusChip("PASİF", tone: .titan)
            }

            HStack(alignment: .top, spacing: 10) {
                ArgusDot(color: InstitutionalTheme.Colors.titan)
                    .padding(.top, 5)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.color(for: motor).opacity(0.3),
                        lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
    }
}

// MARK: - Hermes Module Sheet (V5)
//
// 2026-04-23 V5.H-5: Inline shell (StockDetailView) kendi struct'ına alındı.
// Eklenenler:
//   • Filter bar: POZ / NÖT / NEG sayıları (HermesEvent.polarity üzerinden).
//   • Yüksek etki kartı: finalScore >= 70 ise en yüksek event vurgulu gösterilir.
//   • Sentiment Pulse + son 5 teaching card + "Haberleri Tara" butonu korundu.

struct HermesModuleSheet: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel

    private var events: [HermesEvent] {
        viewModel.hermesEventsBySymbol[symbol]
            ?? viewModel.kulisEventsBySymbol[symbol]
            ?? []
    }

    private var scope: HermesEventScope {
        (symbol.uppercased().hasSuffix(".IS")
         || SymbolResolver.shared.isBistSymbol(symbol)) ? .bist : .global
    }

    private var positiveCount: Int { events.filter { $0.polarity == .positive }.count }
    private var mixedCount:    Int { events.filter { $0.polarity == .mixed    }.count }
    private var negativeCount: Int { events.filter { $0.polarity == .negative }.count }

    private var highImpact: HermesEvent? {
        events.max(by: { $0.finalScore < $1.finalScore })
    }

    var body: some View {
        ModuleSheetShell(title: "HERMES · HABER ETKİSİ", motor: .hermes) {
            SentimentPulseCard(symbol: symbol)

            if !events.isEmpty {
                filterBar
            }

            if let top = highImpact, top.finalScore >= 70 {
                highImpactCard(top)
            }

            ForEach(Array(events.prefix(5))) { event in
                HermesEventTeachingCard(
                    viewModel: viewModel,
                    symbol: symbol,
                    scope: scope,
                    injectedEvent: event
                )
            }

            scanButton
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ArgusChip("POZ · \(positiveCount)", tone: .aurora)
            ArgusChip("NÖT · \(mixedCount)",    tone: .holo)
            ArgusChip("NEG · \(negativeCount)", tone: .crimson)
            Spacer()
            Text("\(events.count) OLAY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }

    // MARK: - High impact highlight

    private func highImpactCard(_ event: HermesEvent) -> some View {
        let tone: ArgusChipTone = {
            switch event.polarity {
            case .positive: return .aurora
            case .negative: return .crimson
            case .mixed:    return .titan
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ArgusSectionCaption("YÜKSEK ETKİ")
                Spacer()
                ArgusChip("ETKİ \(Int(event.finalScore))", tone: tone)
                ArgusChip(event.sourceName.uppercased(), tone: .neutral)
            }

            Text(event.headline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !event.rationaleShort.isEmpty {
                Text(event.rationaleShort)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.Motors.hermes.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Scan button

    private var scanButton: some View {
        Button {
            Task { await viewModel.analyzeOnDemand(symbol: symbol) }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingNews {
                    ProgressView().scaleEffect(0.7)
                        .tint(InstitutionalTheme.Colors.Motors.hermes)
                } else {
                    MotorLogo(.hermes, size: 14)
                }
                Text(viewModel.isLoadingNews ? "ANALİZ EDİLİYOR…" : "HABERLERİ TARA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(InstitutionalTheme.Colors.Motors.hermes.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingNews)
    }
}

// MARK: - Demeter Sector Card (V5)
//
// `HoloPanelView` .demeter case'iyle aynı veri alanlarını kullanır
// (sector.name, totalScore, grade, momentumScore, shockImpactScore,
//  regimeScore, breadthScore, activeShocks).

struct DemeterSectorCard: View {
    let score: DemeterScore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroCard
            introCard
            breakdownCard

            if !score.activeShocks.isEmpty {
                shocksCard
            }

            pedagogyFooter
        }
    }

    // 2026-04-23 V5.H-4: Demeter sheet'i artık yalnızca skor değil öğretici.
    // Her bileşenin "ne ölçer" mikro-başlığı + şok türü açıklaması + "Demeter
    // nedir?" pedagoji footer'ı.
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArgusSectionCaption("NASIL OKUNUR?")
            Text("Demeter sektörün momentumunu, ani şokları, makro rejimle uyumunu ve kaç hissenin trendi paylaştığını tek skorda toplar. Hisse-bazlı değildir.")
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.Motors.demeter)
                .frame(width: 2)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var pedagogyFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArgusSectionCaption("DEMETER NEDİR?")
            Text("Demeter bir sektörün \"hasat zamanı mı?\" sorusunu cevaplar. Yüksek skor sektörün taze bir yükseliş ivmesinde olduğunu gösterir; aktif şoklar ise dikkat etmeniz gereken beklenmedik olayları işaretler.")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    InstitutionalTheme.Colors.border,
                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    ArgusSectionCaption("SEKTÖR PUANI")
                    Text(score.sector.name)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                Spacer()
                Text("\(Int(score.totalScore))")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(scoreColor(score.totalScore))
            }
            ArgusBar(value: max(0, min(1, score.totalScore / 100)),
                     color: scoreColor(score.totalScore),
                     height: 6)
            HStack(spacing: 6) {
                ArgusChip("DEĞERLENDİRME · \(score.grade.uppercased())",
                          tone: scoreTone(score.totalScore))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.demeter.opacity(0.3),
                        lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArgusSectionCaption("BİLEŞEN KIRILIMI")

            VStack(spacing: 10) {
                factorRow("MOMENTUM",
                          caption: "son dönem getirisi",
                          value: score.momentumScore,
                          color: InstitutionalTheme.Colors.Motors.prometheus)
                factorRow("ŞOK ETKİSİ",
                          caption: "büyük haberlerin izi",
                          value: score.shockImpactScore,
                          color: InstitutionalTheme.Colors.crimson)
                factorRow("REJİM",
                          caption: "makro ile uyum",
                          value: score.regimeScore,
                          color: InstitutionalTheme.Colors.Motors.aether)
                factorRow("GENİŞLİK",
                          caption: "kaç hisse katıldı",
                          value: score.breadthScore,
                          color: InstitutionalTheme.Colors.aurora)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.demeter.opacity(0.3),
                        lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
    }

    private var shocksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ArgusSectionCaption("AKTİF ŞOKLAR")
                Spacer()
                ArgusChip("\(score.activeShocks.count) UYARI", tone: .crimson)
            }

            Text("Sektörün genel seyrini etkileyen ani olaylar:")
                .font(.system(size: 10.5))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(score.activeShocks) { shock in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            ArgusDot(color: InstitutionalTheme.Colors.crimson)
                            Text("\(shock.type.displayName) \(shock.direction.symbol)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer(minLength: 0)
                            ArgusChip("Şiddet \(Int(shock.severity))",
                                      tone: shock.severity >= 70 ? .crimson
                                           : shock.severity >= 40 ? .titan
                                           : .neutral)
                        }
                        if !shock.description.isEmpty {
                            Text(shock.description)
                                .font(.system(size: 10.5))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
                .stroke(InstitutionalTheme.Colors.crimson.opacity(0.3),
                        lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg,
                             style: .continuous)
        )
    }

    private func factorRow(_ label: String,
                            caption: String,
                            value: Double,
                            color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer(minLength: 0)
                Text("\(Int(value))")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            ArgusBar(value: max(0, min(1, value / 100.0)), color: color, height: 5)
        }
    }

    private func scoreColor(_ value: Double) -> Color {
        if value >= 60 { return InstitutionalTheme.Colors.aurora }
        if value >= 40 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func scoreTone(_ value: Double) -> ArgusChipTone {
        if value >= 60 { return .aurora }
        if value >= 40 { return .titan }
        return .crimson
    }
}
