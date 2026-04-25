import SwiftUI

/// Argus Voice FAB — V5 mockup'tan (`Argus_Mockup_V5.html` .fab-voice) port.
///
/// 2026-04-22 Sprint 2: ArgusEye logosu, V5 radial gradient (30%/55%/100%),
/// pulse halkası (2.8s), iç gölge vurgusu.
///
/// Eski davranış: düz holo renk + SF waveform ikonu. Yeni: V5 neon göz
/// + mavi derinliği (açık → holo → derin).
struct PulsingFABView: View {
    @State private var pulseOpacity: Double = 0.8
    @State private var pulseScale: CGFloat = 0.9
    var size: CGFloat = 64
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring — V5 .fab-voice::before (2.8s, 0.9 → 1.35, opacity 0.8 → 0)
                Circle()
                    .stroke(InstitutionalTheme.Colors.holo.opacity(pulseOpacity), lineWidth: 1)
                    .frame(width: size + 20, height: size + 20)
                    .scaleEffect(pulseScale)

                // Ana gövde — V5 radial gradient
                // background:radial-gradient(circle at 30% 30%, #6aa5ff, var(--holo) 55%, #143a7a 100%)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "6AA5FF"), location: 0),
                                .init(color: InstitutionalTheme.Colors.holo, location: 0.55),
                                .init(color: Color(hex: "143A7A"), location: 1.0)
                            ]),
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        // V5 shadow iç parlaklık: inset 0 -8px 18px rgba(255,255,255,.08)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, Color.white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: InstitutionalTheme.Colors.holo.opacity(0.6),
                            radius: 10, x: 0, y: 4)
                    .shadow(color: InstitutionalTheme.Colors.holo.opacity(0.15),
                            radius: 0, x: 0, y: 0)  // 0 3px ring

                // Argus Eye logosu — iç içerik (ikondan büyük, V5'te ico-lg)
                MotorLogo(.argus, size: size * 0.75)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(
                .easeOut(duration: 2.8)
                    .repeatForever(autoreverses: false)
            ) {
                pulseScale = 1.35
                pulseOpacity = 0
            }
        }
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.backgroundDeep.ignoresSafeArea()
        VStack(spacing: 40) {
            PulsingFABView()
            PulsingFABView(size: 80)
        }
    }
}
