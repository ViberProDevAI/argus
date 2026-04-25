import SwiftUI

// MARK: - Technical Consensus View (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Orion modülü içinde, `orionAnalysis` yoksa gösterilen teknik konsensüs.
// Eski: 4-renkli gauge (red/orange/blue/green), bloberset boyutlar,
// `fontWeight(.bold)` karışımı.
// Yeni: 3-bucket gauge (crimson→titan→aurora), mono caps dil, ArgusChip
// action rozetleri, ArgusHair satır separator'ları, motor(.orion) border.
struct TechnicalConsensusView: View {
    let breakdown: OrionSignalBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gaugeCard
            consensusSplit
        }
        .padding(.horizontal)
    }

    // MARK: - Gauge Card

    private var gaugeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MotorLogo(.orion, size: 14)
                ArgusSectionCaption("TEKNİK KONSENSÜS")
                Spacer()
                ArgusChip("\(breakdown.summary.total) SİNYAL", tone: .motor(.orion))
            }

            ZStack {
                GaugeView(value: consensusValue)
                    .frame(height: 120)

                VStack(spacing: 3) {
                    Spacer()
                    Text(breakdown.summary.dominant.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(dominantTone.foreground)
                    Text("\(breakdown.summary.buy) AL · \(breakdown.summary.sell) SAT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .offset(y: 16)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.orion.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
    }

    // MARK: - Consensus Split (2 kolon)

    private var consensusSplit: some View {
        HStack(alignment: .top, spacing: 10) {
            SignalColumn(
                title: "OSİLATÖRLER",
                vote: breakdown.oscillators,
                signals: breakdown.indicators.filter { isOscillator($0.name) }
            )
            SignalColumn(
                title: "HAREKETLİ ORT.",
                vote: breakdown.movingAverages,
                signals: breakdown.indicators.filter { !isOscillator($0.name) }
            )
        }
    }

    // MARK: - Helpers

    /// -1 (Strong Sell) to 1 (Strong Buy)
    var consensusValue: Double {
        let total = Double(breakdown.summary.total)
        if total == 0 { return 0 }
        let net = Double(breakdown.summary.buy - breakdown.summary.sell)
        return net / total
    }

    var dominantTone: ArgusChipTone {
        switch breakdown.summary.dominant {
        case "AL":  return .aurora
        case "SAT": return .crimson
        default:    return .titan
        }
    }

    func isOscillator(_ name: String) -> Bool {
        let oscs = ["RSI", "Stoch", "CCI", "Williams", "Momentum", "MACD Level", "Aroon"]
        return oscs.contains { name.contains($0) }
    }
}

// MARK: - Signal Column (V5)

struct SignalColumn: View {
    let title: String
    let vote: VoteCount
    let signals: [OrionSignalBreakdown.SignalItem]

    var body: some View {
        VStack(spacing: 0) {
            columnHeader

            VStack(spacing: 0) {
                ForEach(signals, id: \.name) { signal in
                    signalRow(signal)
                        .overlay(ArgusHair(), alignment: .bottom)
                }
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
        )
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Spacer()
            HStack(spacing: 4) {
                voteChip(count: vote.buy, label: "A", tone: .aurora)
                voteChip(count: vote.sell, label: "S", tone: .crimson)
                voteChip(count: vote.neutral, label: "N", tone: .titan)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(ArgusHair(), alignment: .bottom)
    }

    private func voteChip(count: Int, label: String, tone: ArgusChipTone) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(tone.foreground)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous).fill(tone.background)
        )
    }

    private func signalRow(_ signal: OrionSignalBreakdown.SignalItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.name.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(signal.value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Spacer(minLength: 4)
            ArgusChip(signal.action.uppercased(), tone: actionTone(signal.action))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    func actionTone(_ action: String) -> ArgusChipTone {
        switch action {
        case "AL":  return .aurora
        case "SAT": return .crimson
        default:    return .titan
        }
    }
}

// MARK: - Gauge (V5)
//
// 3-bucket arc: crimson (180-240°) → titan (240-300°) → aurora (300-360°).
// Needle mono tip, mini dot pivot.

struct GaugeView: View {
    let value: Double // -1.0 to 1.0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height)
            let radius = min(size.width / 2, size.height) - 12
            let lineWidth: CGFloat = 10

            // Track background (hairline)
            let fullTrack = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(180),
                         endAngle: .degrees(360),
                         clockwise: false)
            }
            context.stroke(fullTrack,
                           with: .color(InstitutionalTheme.Colors.surface3),
                           lineWidth: lineWidth + 2)

            // Crimson bucket (sell)
            let crimsonArc = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(180),
                         endAngle: .degrees(240),
                         clockwise: false)
            }
            context.stroke(crimsonArc,
                           with: .color(InstitutionalTheme.Colors.crimson),
                           lineWidth: lineWidth)

            // Titan bucket (neutral)
            let titanArc = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(240),
                         endAngle: .degrees(300),
                         clockwise: false)
            }
            context.stroke(titanArc,
                           with: .color(InstitutionalTheme.Colors.titan),
                           lineWidth: lineWidth)

            // Aurora bucket (buy)
            let auroraArc = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(300),
                         endAngle: .degrees(360),
                         clockwise: false)
            }
            context.stroke(auroraArc,
                           with: .color(InstitutionalTheme.Colors.aurora),
                           lineWidth: lineWidth)

            // Needle
            let angle = 180 + ((value + 1.0) / 2.0) * 180
            let needleEnd = CGPoint(
                x: center.x + Foundation.cos(Angle(degrees: angle).radians) * (radius - 14),
                y: center.y + Foundation.sin(Angle(degrees: angle).radians) * (radius - 14)
            )

            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: needleEnd)
            context.stroke(needle,
                           with: .color(InstitutionalTheme.Colors.textPrimary),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Pivot dot
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                with: .color(InstitutionalTheme.Colors.Motors.orion)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                with: .color(InstitutionalTheme.Colors.surface1),
                lineWidth: 2
            )
        }
    }
}
