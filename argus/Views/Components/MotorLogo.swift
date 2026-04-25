import SwiftUI

/// Argus 14 motoru için tek logo görüntüleme noktası.
///
/// **Tek strateji (2026-04-22 Sprint 1.1):** PNG asset + SF Symbol fallback.
/// V5 SVG'leri `sprint_1_assets/render.sh` ile @1x/@2x/@3x PNG'ye render edilip
/// `Assets.xcassets/[Motor]Icon.imageset/`'e yazıldı. qlmanage çıktısı V5
/// mockup ile birebir — radial gradient, kirpik çizgileri, glow halkaları
/// doğru geliyor. Path port'u (ChironLogoShape, ArgusEyeLogoShape) yedek
/// olarak branch'te kalıyor ama çağrılmıyor.
///
/// Rezerv motorlar (poseidon, titan, chronos, hephaestus) için asset yok;
/// SF Symbol `sparkles` + motor rengi fallback.
///
/// Kullanım:
///
///     MotorLogo(.orion, size: 18)
///     MotorLogo(.argus, size: 44)
///     MotorLogo(.chiron, size: 32).tinted(.white)   // template rendering
struct MotorLogo: View {
    let engine: MotorEngine
    var size: CGFloat = 18
    var renderingMode: Image.TemplateRenderingMode = .original

    init(_ engine: MotorEngine,
         size: CGFloat = 18,
         renderingMode: Image.TemplateRenderingMode = .original) {
        self.engine = engine
        self.size = size
        self.renderingMode = renderingMode
    }

    var body: some View {
        Group {
            if !assetName.isEmpty, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(renderingMode)
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.6, weight: .semibold))
                    .foregroundStyle(InstitutionalTheme.Colors.Motors.color(for: engine))
            }
        }
        .frame(width: size, height: size)
    }

    /// Template modunda foreground rengi uygulanır.
    func tinted(_ color: Color) -> some View {
        Group {
            if !assetName.isEmpty, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.6, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }

    private var assetName: String {
        switch engine {
        case .orion:       return "OrionIcon"
        case .atlas:       return "AtlasIcon"
        case .aether:      return "AetherIcon"
        case .hermes:      return "HermesIcon"
        case .athena:      return "AthenaIcon"
        case .demeter:     return "DemeterIcon"
        case .chiron:      return "ChironIcon"       // V5 SVG (vektör, şeffaf)
        case .prometheus:  return "PrometheusIcon"
        case .phoenix:     return "PrometheusIcon"   // V5: Prometheus alevi reuse
        case .alkindus:    return "AlkindusIcon"
        case .council:     return "AnalystIcon"
        case .argus:       return "ArgusEyeIcon"     // V5 SVG (vektör, şeffaf)
        case .poseidon,
             .titan,
             .chronos,
             .hephaestus:  return ""      // SF Symbol fallback
        }
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.backgroundDeep.ignoresSafeArea()

        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ForEach([MotorEngine.orion, .atlas, .aether, .hermes], id: \.self) { motor in
                    VStack {
                        MotorLogo(motor, size: 40)
                        Text("\(motor.rawValue)").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            HStack(spacing: 16) {
                ForEach([MotorEngine.athena, .demeter, .chiron, .prometheus], id: \.self) { motor in
                    VStack {
                        MotorLogo(motor, size: 40)
                        Text("\(motor.rawValue)").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            HStack(spacing: 16) {
                ForEach([MotorEngine.alkindus, .council, .argus], id: \.self) { motor in
                    VStack {
                        MotorLogo(motor, size: 40)
                        Text("\(motor.rawValue)").font(.caption).foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
    }
}
