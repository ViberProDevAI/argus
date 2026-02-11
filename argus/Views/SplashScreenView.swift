import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Faz 1: Karanlıktan doğuş
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.3

    // Faz 2: Amblem
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.88
    @State private var ringRotation: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var titleRevealCount: Int = 0
    @State private var subtitleOpacity: Double = 0
    @State private var lineWidth: CGFloat = 0

    // Faz 3: Geçiş
    @State private var sceneOffset: CGFloat = 0
    @State private var sceneFade: Double = 1

    @State private var sequenceTask: Task<Void, Never>?

    private let titleText = "ARGUS"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Arka plan: saf siyahtan doğuş
                InstitutionalTheme.Colors.background
                    .ignoresSafeArea()

                // Merkezi glow efekti
                RadialGradient(
                    colors: [
                        Color(hex: "D4A843").opacity(0.22),
                        InstitutionalTheme.Colors.primary.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: min(size.width, size.height) * 0.42
                )
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: 40)
                .ignoresSafeArea()

                // Ambiyans partikülleri
                SplashAmbientParticles(opacity: glowOpacity * 0.4)
                    .ignoresSafeArea()

                // Ana içerik
                VStack(spacing: 0) {
                    Spacer()

                    // Logo + Ring grubu
                    ZStack {
                        // Dönen halka
                        SplashOrbitalRing(rotation: ringRotation)
                            .frame(width: 188, height: 188)
                            .opacity(ringOpacity)

                        // Logo görseli
                        Image("SplashLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(
                                color: Color(hex: "D4A843").opacity(0.3),
                                radius: 28, x: 0, y: 0
                            )
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }

                    Spacer().frame(height: 36)

                    // Başlık: Harf harf reveal
                    HStack(spacing: 4) {
                        ForEach(Array(titleText.enumerated()), id: \.offset) { index, char in
                            Text(String(char))
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                                .tracking(10)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .opacity(titleRevealCount > index ? 1 : 0)
                                .offset(y: titleRevealCount > index ? 0 : 8)
                                .animation(
                                    .easeOut(duration: reduceMotion ? 0.1 : 0.28)
                                        .delay(Double(index) * (reduceMotion ? 0.03 : 0.07)),
                                    value: titleRevealCount
                                )
                        }
                    }

                    Spacer().frame(height: 12)

                    // Ayırıcı çizgi
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color(hex: "D4A843").opacity(0.6),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: lineWidth, height: 1)

                    Spacer().frame(height: 14)

                    // Alt başlık
                    Text("INSTITUTIONAL DECISION CORE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(3.2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .opacity(subtitleOpacity)

                    Spacer()
                    Spacer()
                }
                .offset(y: sceneOffset)
                .opacity(sceneFade)
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

        // ── Faz 1: Karanlıktan doğuş ──
        await animate(duration: fast ? 0.4 : 0.9) {
            glowOpacity = 1
            glowScale = 1.0
        }

        guard await pause(ms: fast ? 100 : 250) else { return }

        // ── Faz 2: Amblem ortaya çıkışı ──
        await animate(duration: fast ? 0.3 : 0.7, spring: true) {
            logoOpacity = 1
            logoScale = 1.0
        }

        await animate(duration: fast ? 0.4 : 0.8) {
            ringOpacity = 1
        }

        // Halka dönüşü başlat
        await animate(duration: fast ? 8 : 14, repeating: true) {
            ringRotation = 360
        }

        guard await pause(ms: fast ? 80 : 180) else { return }

        // Başlık reveal
        await MainActor.run {
            titleRevealCount = titleText.count
        }

        guard await pause(ms: fast ? 200 : 500) else { return }

        // Çizgi genişlemesi
        await animate(duration: fast ? 0.3 : 0.6) {
            lineWidth = 160
        }

        guard await pause(ms: fast ? 80 : 160) else { return }

        // Alt başlık fade in
        await animate(duration: fast ? 0.2 : 0.5) {
            subtitleOpacity = 1
        }

        // Sahneyi göster - dinlenme süresi
        guard await pause(ms: fast ? 400 : 900) else { return }

        // ── Faz 3: Zarif çıkış ──
        await animate(duration: fast ? 0.3 : 0.5) {
            sceneFade = 0
            sceneOffset = -16
        }

        guard await pause(ms: fast ? 100 : 200) else { return }

        await MainActor.run {
            onFinished()
        }
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
                animation = .spring(response: duration, dampingFraction: 0.78)
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

// MARK: - Orbital Ring

private struct SplashOrbitalRing: View {
    let rotation: Double

    var body: some View {
        ZStack {
            // Dış halka
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: "D4A843").opacity(0.5),
                            InstitutionalTheme.Colors.primary.opacity(0.2),
                            .clear,
                            .clear,
                            Color(hex: "D4A843").opacity(0.5)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // İç ince halka
            Circle()
                .stroke(
                    InstitutionalTheme.Colors.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: 0.6, dash: [3, 9])
                )
                .padding(14)
                .rotationEffect(.degrees(-rotation * 0.5))
        }
    }
}

// MARK: - Ambient Particles

private struct SplashAmbientParticles: View {
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(0..<18, id: \.self) { idx in
                    Circle()
                        .fill(
                            idx % 3 == 0
                                ? Color(hex: "D4A843")
                                : InstitutionalTheme.Colors.textPrimary
                        )
                        .frame(width: particleSize(idx), height: particleSize(idx))
                        .opacity(particleOpacity(idx) * opacity)
                        .position(particlePosition(idx, in: size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func particleSize(_ idx: Int) -> CGFloat {
        CGFloat(1.0 + Double((idx * 7) % 5) * 0.4)
    }

    private func particleOpacity(_ idx: Int) -> Double {
        0.15 + Double((idx * 11) % 7) * 0.06
    }

    private func particlePosition(_ idx: Int, in size: CGSize) -> CGPoint {
        let nx = (sin(Double(idx) * 9.73) * 0.5) + 0.5
        let ny = (cos(Double(idx) * 6.29) * 0.5) + 0.5
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
