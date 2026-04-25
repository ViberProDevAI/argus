import SwiftUI

// MARK: - Global Module Orb View (V5)
//
// V5 mockup Sanctum (`Argus_Mockup_V5.html` satır 1188-1211):
//   • 48pt daire, surface2 zemin
//   • 1.5px motor rengi border (opacity 0.7)
//   • Motor rengi glow (blur 16, opacity 0.45)
//   • İçinde MotorLogo (SVG/PNG)
//   • Altta caption "ORION · 91" — motor rengi, mono 8pt/700
//
// 2026-04-22 Sprint 5: Sanctum orb grid V5 kimliğine taşındı.
//
// 2026-04-24 V5.H-20: Çift kaynak + durum matrisi — StockDetailV5Body motor
// chip'leriyle aynı dil. Orb'un dinleyeceği üç katman:
//   1. Konsey (SignalStateViewModel.grandDecisions[symbol]) — en güvenilir.
//   2. AutoPilot/ArgusDecisionEngine (SignalStateViewModel.argusDecisions[symbol])
//      — Konsey toplanmadan da skor üretir.
//   3. Motor'a özgü zenginleştirme (phoenix regressionSlope okları vb.)
// Üç kaynak da kuruysa `pending(BEKLİYOR)`. Renk ve glow yoğunluğu da
// state'e göre değişir — "çizgi" gösterip bilgisiz duran orb kalmaz.

struct OrbView: View {
    let module: SanctumModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glow katmanı — state'e bağlı yoğunluk.
                // Active: 0.45 (V5 default), Pending: 0.18, Empty: 0.08.
                Circle()
                    .fill(module.color.opacity(orbState.haloOpacity))
                    .frame(width: 54, height: 54)
                    .blur(radius: 10)

                // Ana orb
                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(module.color.opacity(orbState.borderOpacity), lineWidth: 1.5)
                    .frame(width: 48, height: 48)

                // V5 logo — motor tipinden üretilen MotorLogo
                MotorLogo(module.motor, size: 28)
                    .opacity(orbState.logoOpacity)
            }

            // Caption — motor adı + state-aware değer
            Text(captionText)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(module.color.opacity(orbState.captionOpacity))
                .tracking(0.5)
        }
        .accessibilityLabel(Text("\(displayName). \(orbState.accessibilityValue)"))
    }

    // MARK: - Caption & Display Helpers

    private var captionText: String {
        "\(displayName.uppercased()) · \(orbState.valueText)"
    }

    private var displayName: String {
        if symbol.uppercased().hasSuffix(".IS") {
            switch module {
            case .aether: return "SIRKIYE"
            case .orion:  return "TAHTA"
            case .atlas:  return "KASA"
            case .hermes: return "KULIS"
            case .chiron: return "KISMET"
            default:      return module.rawValue
            }
        }
        return module.rawValue
    }

    // MARK: - Orb State (V5.H-20 dual-source cascade)

    private enum OrbState {
        /// Gerçek bir skor/duruş üretildi — orb canlı, kapak numarası caption'da.
        case active(valueText: String)
        /// Sistem hâlâ toplanıyor veya yarı-bilgi (ör. haber sayısı) — soluk ama
        /// "ölü" değil. Kullanıcı "çizgi" yerine ne olduğunu okur.
        case pending(label: String)
        /// Hiçbir kaynak veri üretmedi — orb pasif (veri yok/destek dışı modül).
        case empty

        var valueText: String {
            switch self {
            case .active(let v): return v
            case .pending(let l): return l
            case .empty:          return "—"
            }
        }

        var haloOpacity: Double {
            switch self {
            case .active:   return 0.45
            case .pending:  return 0.18
            case .empty:    return 0.08
            }
        }

        var borderOpacity: Double {
            switch self {
            case .active:   return 0.70
            case .pending:  return 0.40
            case .empty:    return 0.20
            }
        }

        var logoOpacity: Double {
            switch self {
            case .active:   return 1.0
            case .pending:  return 0.72
            case .empty:    return 0.45
            }
        }

        var captionOpacity: Double {
            switch self {
            case .active:   return 1.0
            case .pending:  return 0.75
            case .empty:    return 0.45
            }
        }

        var accessibilityValue: String {
            switch self {
            case .active(let v):  return "Skor \(v)"
            case .pending(let l): return "Bekleniyor: \(l)"
            case .empty:          return "Veri yok"
            }
        }
    }

    /// 4-adımlı kaynak öncelik cascade'i.
    /// 1. Konsey grandDecisions → 2. argusDecisions → 3. motor-özgü zenginleştirme →
    /// 4. pending/empty.
    private var orbState: OrbState {
        let grand = SignalStateViewModel.shared.grandDecisions[symbol]
        let argus = SignalStateViewModel.shared.argusDecisions[symbol]

        switch module {
        case .orion:
            if let grand, let s = grand.orionDetails?.score {
                return .active(valueText: "\(Int(round(s)))")
            }
            if let grand {
                // netSupport -1..+1 → 0..100 skalaya yay
                let pct = (grand.orionDecision.netSupport + 1) * 50
                return .active(valueText: "\(Int(round(pct)))")
            }
            if let argus {
                return .active(valueText: "\(Int(round(argus.orionScore)))")
            }
            return .pending(label: "BEKLİYOR")

        case .atlas:
            if let grand, let a = grand.atlasDecision {
                let pct = (a.netSupport + 1) * 50
                return .active(valueText: "\(Int(round(pct)))")
            }
            if let argus, argus.atlasScore > 0 {
                return .active(valueText: "\(Int(round(argus.atlasScore)))")
            }
            return .pending(label: "BEKLİYOR")

        case .aether:
            if let grand {
                let pct = (grand.aetherDecision.netSupport + 1) * 50
                return .active(valueText: "\(Int(round(pct)))")
            }
            if let argus, argus.aetherScore > 0 {
                return .active(valueText: "\(Int(round(argus.aetherScore)))")
            }
            return .pending(label: "BEKLİYOR")

        case .hermes:
            if let grand, let h = grand.hermesDecision {
                let pct = (h.netSupport + 1) * 50
                return .active(valueText: "\(Int(round(pct)))")
            }
            if let argus, argus.hermesScore > 0 {
                return .active(valueText: "\(Int(round(argus.hermesScore)))")
            }
            // Haber sayısı "hermes çizgi ama veri var" dertini çözer.
            let newsCount = viewModel.newsInsightsBySymbol[symbol]?.count ?? 0
            if newsCount > 0 {
                return .pending(label: "\(newsCount) HABER")
            }
            return .pending(label: "BEKLİYOR")

        case .prometheus:
            // Phoenix status-aware: aktif → yön oku + güven yüzdesi;
            // pasif/veri-kısıtlı → durum etiketi; hata → empty.
            if let phoenix = grand?.phoenixAdvice ?? argus?.phoenixAdvice {
                switch phoenix.status {
                case .active:
                    let arrow: String
                    if let slope = phoenix.regressionSlope {
                        arrow = slope > 0 ? "↑" : (slope < 0 ? "↓" : "•")
                    } else {
                        arrow = "•"
                    }
                    let pct = Int(round(phoenix.confidence * 100))
                    return .active(valueText: "\(arrow)%\(pct)")
                case .inactive:
                    return .pending(label: "PASİF")
                case .insufficientData:
                    return .pending(label: "VERİ KISITLI")
                case .error:
                    return .empty
                }
            }
            // Grand confidence fallback (Phoenix yoksa ama Konsey vardıysa).
            if let grand, grand.phoenixAdvice == nil {
                let pct = Int(round(grand.confidence * 100))
                return .active(valueText: "%\(pct)")
            }
            return .pending(label: "BEKLİYOR")

        case .athena, .demeter, .chiron, .council:
            // Bu orb'lar halkada gösterilmiyor; defensive default.
            return .empty
        }
    }
}

// MARK: - BIST Module Orb View (V5)

struct BistOrbView: View {
    let module: SanctumBistModuleType

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(module.color.opacity(0.45))
                    .frame(width: 54, height: 54)
                    .blur(radius: 10)

                Circle()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(module.color.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 48, height: 48)

                MotorLogo(module.motor, size: 28)
            }

            Text(module.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(module.color)
                .tracking(0.5)
        }
    }
}
