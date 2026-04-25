import SwiftUI

// MARK: - Splash Screen (V5.H-8 · Argus Eye + Motor Consensus)
//
// **2026-04-23 yeniden tasarım.** Eski splash generic bir logo + orbital
// ring + partikül + letter reveal kombosuydu. Yeni tasarım Argus'un
// mitolojik temasına sadık: **100 gözlü bekçi** → çok katmanlı göz,
// çevresinde 8 motorun konseye akışı, ardından echo pulse ile "göz
// artık izliyor" hissi. Tasarım V5 token'larıyla (holo mavi + titan
// altın + motor palet).
//
// **Faz zaman çizelgesi** (toplam ~2.8s, reduceMotion ~0.9s):
//
//   0.00 → 0.35   FAZ 1 · Uyanış        (nefes alan merkez nokta)
//   0.35 → 0.85   FAZ 2 · Göz           (dış halka + iç iris + pupil)
//   0.85 → 1.45   FAZ 3 · Konsey akışı  (8 motor dot → pupili besler)
//   1.45 → 1.95   FAZ 4 · Echo pulse    (3 halka dışarı yayılır)
//   1.95 → 2.30   FAZ 5 · ARGUS reveal  (harf-harf glitch)
//   2.30 → 2.55   FAZ 6 · Subtitle      (altyazı fade in)
//   2.55 → 2.80   FAZ 7 · Handoff       (fade + zoom out)
//
// Public API `SplashScreenView(onFinished:)` korundu — çağıran kod
// aynı kalıyor.

struct SplashScreenView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // FAZ 1 · Uyanış
    @State private var centerDotOpacity: Double = 0
    @State private var centerDotScale: CGFloat = 0.4

    // FAZ 2 · Aperture materyalizasyonu (V5.H-9: el-çizimi ring'ler kalktı,
    // ArgusEyeIcon asset hero olarak kullanılıyor)
    @State private var pupilOpacity: Double = 0
    @State private var pupilScale: CGFloat = 0.3
    @State private var eyeGlow: Double = 0

    // FAZ 3 · Motor konseyi
    @State private var motorsVisible: Bool = false
    @State private var motorsConverge: Bool = false
    @State private var motorsFadeOut: Bool = false

    // FAZ 4 · Echo pulse
    @State private var echoPhases: [Double] = [0, 0, 0]    // 0…1 (expansion)

    // FAZ 5 · ARGUS
    @State private var titleRevealCount: Int = 0
    @State private var titleGlitch: Bool = false

    // FAZ 6 · Subtitle
    @State private var underlineWidth: CGFloat = 0
    @State private var subtitleOpacity: Double = 0

    // FAZ 7 · Handoff
    @State private var sceneOffset: CGFloat = 0
    @State private var sceneFade: Double = 1
    @State private var sceneScale: CGFloat = 1

    // Ring rotation (sürekli)
    @State private var continuousRotation: Double = 0

    @State private var sequenceTask: Task<Void, Never>?

    private let titleText = "ARGUS"

    // Motor sırası (saat 12'den başlayarak saat yönünde).
    private let motors: [MotorEngine] = [
        .orion, .atlas, .aether, .hermes,
        .athena, .demeter, .chiron, .prometheus
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let eyeSize = min(size.width, size.height) * 0.42

            ZStack {
                // Derin siyah zemin
                InstitutionalTheme.Colors.backgroundDeep
                    .ignoresSafeArea()

                // Merkezi nefes alan glow (tüm fazlarda arkada)
                RadialGradient(
                    colors: [
                        InstitutionalTheme.Colors.Motors.argus.opacity(0.18),
                        InstitutionalTheme.Colors.Motors.athena.opacity(0.06),
                        .clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: eyeSize * 1.8
                )
                .opacity(centerDotOpacity)
                .blur(radius: 38)
                .ignoresSafeArea()

                // Ana kompozisyon
                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        // Echo pulse halkaları (arka plan)
                        ForEach(0..<echoPhases.count, id: \.self) { idx in
                            EchoRing(
                                phase: echoPhases[idx],
                                baseSize: eyeSize,
                                color: InstitutionalTheme.Colors.Motors.argus
                            )
                        }

                        // Motor dotlar (orbital pozisyon)
                        ForEach(Array(motors.enumerated()), id: \.offset) { idx, motor in
                            MotorOrbitDot(
                                motor: motor,
                                angle: Double(idx) * (360.0 / Double(motors.count)) - 90,
                                visible: motorsVisible,
                                converge: motorsConverge,
                                fadeOut: motorsFadeOut,
                                orbitRadius: eyeSize * 0.82
                            )
                        }

                        // 2026-04-23 V5.H-9: SplashScreen artık yeni Aperture
                        // logosunu (ArgusEyeIcon) hero olarak kullanıyor. Eski
                        // el-çizimi göz katmanları kaldırıldı; "deklanşör
                        // açılıyor" efekti scale + rotation ile veriliyor.

                        // APERTURE HERO — ArgusEyeIcon asset
                        Image("ArgusEyeIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: eyeSize * 1.25, height: eyeSize * 1.25)
                            .rotationEffect(.degrees(continuousRotation * 0.15))
                            .scaleEffect(pupilScale)
                            .opacity(pupilOpacity)
                            .shadow(
                                color: InstitutionalTheme.Colors.Motors.argus
                                    .opacity(0.4 * eyeGlow),
                                radius: 24
                            )

                        // Pupil glow (merkezden yayılan hafif ışık — orta pupile denk gelir)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        InstitutionalTheme.Colors.Motors.argus.opacity(0.35),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: eyeSize * 0.22
                                )
                            )
                            .frame(width: eyeSize * 0.45, height: eyeSize * 0.45)
                            .opacity(eyeGlow * 0.8)
                            .blur(radius: 6)

                        // Faz 1 merkez nokta (aperture gelmeden önceki sparkle)
                        Circle()
                            .fill(InstitutionalTheme.Colors.Motors.argus)
                            .frame(width: 6, height: 6)
                            .opacity(centerDotOpacity * (1 - pupilOpacity))
                            .scaleEffect(centerDotScale)
                            .shadow(
                                color: InstitutionalTheme.Colors.Motors.argus.opacity(0.9),
                                radius: 12
                            )
                    }
                    .frame(width: eyeSize * 2.2, height: eyeSize * 2.2)

                    Spacer().frame(height: 40)

                    // Başlık — harf harf glitch reveal
                    HStack(spacing: 6) {
                        ForEach(Array(titleText.enumerated()), id: \.offset) { index, char in
                            ArgusLetterReveal(
                                character: String(char),
                                revealed: titleRevealCount > index,
                                glitching: titleGlitch && titleRevealCount > index
                            )
                        }
                    }

                    Spacer().frame(height: 14)

                    // Altın ayırıcı çizgi
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    InstitutionalTheme.Colors.titan.opacity(0.7),
                                    InstitutionalTheme.Colors.Motors.argus.opacity(0.9),
                                    InstitutionalTheme.Colors.titan.opacity(0.7),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: underlineWidth, height: 1)

                    Spacer().frame(height: 12)

                    // Alt başlık
                    VStack(spacing: 4) {
                        Text("INSTITUTIONAL DECISION CORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(3.2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("100 GÖZ · 8 MOTOR · 1 KARAR")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(InstitutionalTheme.Colors.Motors.argus.opacity(0.7))
                    }
                    .opacity(subtitleOpacity)

                    Spacer()
                    Spacer()
                }
                .offset(y: sceneOffset)
                .opacity(sceneFade)
                .scaleEffect(sceneScale)
            }
        }
        .onAppear { startSequence() }
        .onDisappear { sequenceTask?.cancel() }
    }

    // MARK: - Animasyon Sekansı

    private func startSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task { await runSequence() }
    }

    private func runSequence() async {
        let fast = reduceMotion

        // Sürekli dönen halkalar (paralel başlat)
        await animate(duration: fast ? 10 : 22, repeating: true) {
            continuousRotation = 360
        }

        // ── FAZ 1 · Uyanış (0.35s) ──
        await animate(duration: fast ? 0.15 : 0.35, spring: true) {
            centerDotOpacity = 1
            centerDotScale = 1.0
        }
        guard await pause(ms: fast ? 60 : 180) else { return }

        // ── FAZ 2 · Aperture materyalizasyonu (0.55s) ──
        // V5.H-9: ArgusEyeIcon asset'i deklanşör açılma efektiyle ortaya
        // çıkıyor — scale 0.3 → 1, opacity 0 → 1, glow 0 → 1. Spring ile
        // hafif overshoot, gerçek mekanik deklanşör gibi "klik" hissi.
        await animate(duration: fast ? 0.28 : 0.6, spring: true) {
            pupilOpacity = 1
            pupilScale = 1
            eyeGlow = 1
        }
        guard await pause(ms: fast ? 80 : 200) else { return }

        // ── FAZ 3 · Motor konseyi (0.60s) ──
        await animate(duration: fast ? 0.18 : 0.40) {
            motorsVisible = true
        }
        guard await pause(ms: fast ? 80 : 200) else { return }
        await animate(duration: fast ? 0.18 : 0.40) {
            motorsConverge = true
        }
        guard await pause(ms: fast ? 60 : 150) else { return }
        await animate(duration: fast ? 0.12 : 0.25) {
            motorsFadeOut = true
            // Pupil bir an parlar (motorlar pupile akarken)
            eyeGlow = 1.4
        }
        await animate(duration: fast ? 0.15 : 0.3) {
            eyeGlow = 1.0
        }

        // ── FAZ 4 · Echo pulse (0.50s) ──
        // 3 halka 150ms arayla başlatılır
        for idx in 0..<echoPhases.count {
            _ = Task { @MainActor in
                withAnimation(.easeOut(duration: fast ? 0.4 : 0.9)) {
                    echoPhases[idx] = 1.0
                }
            }
            guard await pause(ms: fast ? 70 : 150) else { return }
        }
        guard await pause(ms: fast ? 100 : 280) else { return }

        // ── FAZ 5 · ARGUS harfler (0.35s) ──
        // Önce glitch flash, sonra settle
        await MainActor.run { titleGlitch = true }
        for idx in 0..<titleText.count {
            await MainActor.run {
                withAnimation(.easeOut(duration: fast ? 0.06 : 0.14)) {
                    titleRevealCount = idx + 1
                }
            }
            guard await pause(ms: fast ? 30 : 70) else { return }
        }
        guard await pause(ms: fast ? 60 : 180) else { return }
        await MainActor.run { titleGlitch = false }

        // Altın çizgi genişler
        await animate(duration: fast ? 0.2 : 0.45) {
            underlineWidth = 180
        }

        // ── FAZ 6 · Subtitle (0.25s) ──
        await animate(duration: fast ? 0.15 : 0.4) {
            subtitleOpacity = 1
        }

        // Nefes — tüm sahne görünür, kullanıcı sindirir
        guard await pause(ms: fast ? 300 : 650) else { return }

        // ── FAZ 7 · Handoff (0.25s) ──
        await animate(duration: fast ? 0.18 : 0.4) {
            sceneFade = 0
            sceneScale = 1.08
            sceneOffset = -10
        }
        guard await pause(ms: fast ? 60 : 150) else { return }

        await MainActor.run { onFinished() }
    }

    // MARK: - Yardımcılar

    private func animate(
        duration: Double,
        spring: Bool = false,
        repeating: Bool = false,
        block: @escaping () -> Void
    ) async {
        await MainActor.run {
            let animation: Animation
            if repeating {
                animation = .linear(duration: duration).repeatForever(autoreverses: false)
            } else if spring {
                animation = .spring(response: duration, dampingFraction: 0.72)
            } else {
                animation = .easeInOut(duration: duration)
            }
            withAnimation(animation, block)
        }
    }

    private func pause(ms: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: ms * 1_000_000)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Echo Ring (göz'den yayılan radar pulse)

private struct EchoRing: View {
    let phase: Double    // 0…1 (0 = merkez, 1 = tam yayılmış)
    let baseSize: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .stroke(
                color.opacity((1 - phase) * 0.55),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
            .frame(
                width: baseSize * (1 + phase * 1.3),
                height: baseSize * (1 + phase * 1.3)
            )
            .blur(radius: phase * 1.5)
    }
}

// MARK: - Motor Orbit Dot

/// Belirli bir açıda orbital pozisyonda duran, sonra pupile akan motor noktası.
private struct MotorOrbitDot: View {
    let motor: MotorEngine
    let angle: Double
    let visible: Bool
    let converge: Bool
    let fadeOut: Bool
    let orbitRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motorColor: Color {
        InstitutionalTheme.Colors.Motors.color(for: motor)
    }

    private var dx: CGFloat {
        let r: CGFloat = converge ? 0 : orbitRadius
        return r * cos(CGFloat(angle) * .pi / 180)
    }

    private var dy: CGFloat {
        let r: CGFloat = converge ? 0 : orbitRadius
        return r * sin(CGFloat(angle) * .pi / 180)
    }

    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(motorColor.opacity(0.5))
                .frame(width: 14, height: 14)
                .blur(radius: 6)

            // Solid motor rengi nokta
            Circle()
                .fill(motorColor)
                .frame(width: 6, height: 6)

            // Küçük motor logo (opsiyonel — görünürse çok küçük)
            MotorLogo(motor, size: 10)
                .opacity(converge ? 0 : 0.9)
        }
        .offset(x: dx, y: dy)
        .opacity(visible ? (fadeOut ? 0 : 1) : 0)
        .scaleEffect(converge ? 0.3 : 1.0)
        .animation(
            .spring(response: reduceMotion ? 0.2 : 0.5, dampingFraction: 0.75),
            value: converge
        )
        .animation(
            .easeInOut(duration: reduceMotion ? 0.1 : 0.25),
            value: fadeOut
        )
    }
}

// MARK: - ARGUS Letter Reveal

/// Tek harf reveal animasyonu — kısa glitch flash (random char) → settle.
private struct ArgusLetterReveal: View {
    let character: String
    let revealed: Bool
    let glitching: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayChar: String = ""

    private let glitchPool: [String] = ["0", "1", "X", "Γ", "Δ", "Σ", "⟊", "⟜", "∴", "#"]

    var body: some View {
        Text(displayChar)
            .font(.system(size: 40, weight: .black, design: .monospaced))
            .tracking(4)
            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            .shadow(
                color: InstitutionalTheme.Colors.Motors.argus.opacity(revealed ? 0.4 : 0),
                radius: 8
            )
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 6)
            .onChange(of: revealed) { _, new in
                guard new else { displayChar = ""; return }
                if reduceMotion || !glitching {
                    displayChar = character
                    return
                }
                // Kısa glitch flaş
                Task {
                    for _ in 0..<3 {
                        await MainActor.run {
                            displayChar = glitchPool.randomElement() ?? character
                        }
                        try? await Task.sleep(nanoseconds: 35_000_000)
                    }
                    await MainActor.run { displayChar = character }
                }
            }
            .onAppear {
                if revealed { displayChar = character }
            }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
