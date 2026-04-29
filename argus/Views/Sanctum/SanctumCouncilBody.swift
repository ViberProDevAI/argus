import SwiftUI

// MARK: - Sanctum Council Body (V5.H-35 — Z1a layout)
//
// 2026-04-25 — Z1a (kullanıcı onayı). Yapı:
//   1. Sembol + fiyat (header zaten üstte; burası body)
//   2. "Konsey" küçük caption + "Al, %72 güven" büyük tipografik karar
//   3. 8pt stacked bar — her motor bir segment, genişlik = ağırlık,
//      renk = stance (aurora / nötr / crimson). İçinde label yok.
//   4. Bar altında mini rail — motor isimleri segmentlerle hizalı
//   5. Hairline-ayrılmış sade liste: motor · stance · skor
//   6. En altta "Detaylı yorum →" link (Argus analiz sheet'ini açar)
//
// AI dili azaltıldı: motor başına 1-2 cümlelik gerekçe metni
// ana ekrandan çıkarıldı. Tek satırda stance + skor; gerekçe sadece
// detay sheet'inde yaşıyor. Card/border/glow yok, çoğunlukla
// hairline ile ayrım.

struct SanctumCouncilBody: View {
    let symbol: String
    let decision: ArgusGrandDecision?
    /// Watchlist row'unda kullanılan tahmin verisi — Sanctum'da Prometheus
    /// kartı bu kaynaktan beslenir. Council `phoenixAdvice`'i set etmediği
    /// için fallback olarak burayı okuyoruz. (2026-04-25 H-40)
    var prometheusForecast: PrometheusForecast? = nil
    let onOpenArgusAnalysis: () -> Void
    let onSelectMotor: (MotorEngine) -> Void

    /// Motor reasoning'i decision'dan üretir; Prometheus pending durumdaysa
    /// ve elimizde forecast varsa onu enjekte eder. Watchlist row'undaki
    /// "↑ %5.2 tahmin" satırı ile aynı veri.
    private var enrichedReasonings: [MotorReasoning] {
        guard let d = decision else { return [] }
        var reasonings = d.motorReasonings
        if let f = prometheusForecast, f.isValid {
            let weight = d.weight(forKey: "prometheus", fallbackCount: max(reasonings.count, 1))
            let pr = MotorReasoning.fromPrometheusForecast(f, weight: weight)
            if let idx = reasonings.firstIndex(where: { $0.motor == .prometheus }) {
                reasonings[idx] = pr
            } else {
                reasonings.append(pr)
            }
        }
        return reasonings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            decisionHeadline
            decisionDivider
            stackedBarSection
            motorList
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // trade panel için
    }

    // MARK: - Karar başlık

    @ViewBuilder
    private var decisionHeadline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Konsey")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(decisionWord)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(decisionTone)
                if let d = decision {
                    Text("güven %\(Int(d.finalScoreCore.rounded()))")
                        .font(.system(size: 14))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var decisionDivider: some View {
        Rectangle()
            .fill(InstitutionalTheme.Colors.border)
            .frame(height: 0.5)
            .padding(.vertical, 16)
    }

    private var decisionWord: String {
        guard let action = decision?.finalActionCore else { return "Hazırlanıyor" }
        switch action {
        case .buy:  return "Al"
        case .sell: return "Sat"
        case .hold: return "Bekle"
        case .wait: return "İzle"
        case .skip: return "Pas"
        }
    }

    private var decisionTone: Color {
        guard let action = decision?.finalActionCore else {
            return InstitutionalTheme.Colors.textSecondary
        }
        switch action {
        case .buy:                return InstitutionalTheme.Colors.aurora
        case .hold, .wait, .skip: return InstitutionalTheme.Colors.holo
        case .sell:               return InstitutionalTheme.Colors.crimson
        }
    }

    // MARK: - Stacked bar + rail

    @ViewBuilder
    private var stackedBarSection: some View {
        let segments = weightedSegments
        if !segments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(segments, id: \.motor) { seg in
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: max(2, geo.size.width * CGFloat(seg.ratio)))
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                // Mini rail
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(segments, id: \.motor) { seg in
                            let w = max(2, geo.size.width * CGFloat(seg.ratio))
                            Text(w >= 36 ? seg.label : "·")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .frame(width: w, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(height: 14)
            }
            .padding(.bottom, 22)
        }
    }

    /// Motor segmentleri normalleştirilmiş ağırlıklarla.
    private var weightedSegments: [(motor: MotorEngine, color: Color, ratio: Double, label: String)] {
        let reasonings = enrichedReasonings
        guard !reasonings.isEmpty else { return [] }
        let fallback = 1.0 / Double(reasonings.count)
        let raw = reasonings.map { $0.weight ?? fallback }
        let total = max(raw.reduce(0, +), 0.0001)
        return zip(reasonings, raw).map { r, w in
            (motor: r.motor,
             color: stanceColor(r.stance),
             ratio: w / total,
             label: r.motor.displayName)
        }
    }

    // MARK: - Motor liste

    @ViewBuilder
    private var motorList: some View {
        if decision != nil {
            let reasonings = enrichedReasonings
            if !reasonings.isEmpty {
                ForEach(Array(reasonings.enumerated()), id: \.element.motor) { idx, r in
                    motorRow(r)
                    if idx < reasonings.count - 1 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.border)
                            .frame(height: 0.5)
                    }
                }
            } else {
                Text("Motor oyları henüz toplanmadı.")
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.vertical, 8)
            }
        } else {
            ForEach(0..<3, id: \.self) { _ in
                placeholderRow
            }
        }
    }

    private func motorRow(_ r: MotorReasoning) -> some View {
        // 2026-04-25 H-39: Üç görünüm:
        // 1. valueText var (Chiron) → sağda metin (örn. "Yatay seyir"),
        //    stance rengi metne uygulanır, sayı yok.
        // 2. score > 0 → standart "↑ 78" stance arrow + skor.
        // 3. score 0 (pending) → "—" tertiary, motor adı soluk.
        let isPending = r.score <= 0 && r.valueText == nil
        return Button(action: { onSelectMotor(r.motor) }) {
            HStack(spacing: 8) {
                Text(r.motor.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(isPending
                        ? InstitutionalTheme.Colors.textSecondary
                        : InstitutionalTheme.Colors.textPrimary)
                Spacer()
                if let value = r.valueText {
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundColor(stanceColor(r.stance))
                        .lineLimit(1)
                } else if isPending {
                    Text("—")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                } else {
                    Text("\(r.stance.arrowGlyph) \(Int(r.score))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(stanceColor(r.stance))
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var placeholderRow: some View {
        HStack {
            Text("…")
                .font(.system(size: 14))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Spacer()
            Text("toplanıyor")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.vertical, 9)
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.border)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Footer link

    private var footerLink: some View {
        Button(action: onOpenArgusAnalysis) {
            HStack {
                Spacer()
                Text("Detaylı yorum →")
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                Spacer()
            }
            .padding(.top, 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func stanceColor(_ stance: MotorStance) -> Color {
        switch stance {
        case .strongBuy, .buy:   return InstitutionalTheme.Colors.aurora
        case .wait:              return InstitutionalTheme.Colors.holo
        case .neutral:           return InstitutionalTheme.Colors.textSecondary
        case .sell, .strongSell: return InstitutionalTheme.Colors.crimson
        }
    }
}
