import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sceneOpacity: Double = 0
    @State private var sceneScale: CGFloat = 0.97
    @State private var gridShift: CGFloat = 0
    @State private var starPulse: Double = 0

    @State private var coreOpacity: Double = 0
    @State private var coreScale: CGFloat = 0.86
    @State private var coreRotation: Double = -22
    @State private var ringProgress: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var scanPosition: CGFloat = -150
    @State private var lensPulse: CGFloat = 0.84

    @State private var visibleBootLines: Int = 0
    @State private var progressValue: Double = 0
    @State private var moduleStates: [Bool] = [false, false, false, false, false, false]
    @State private var statusText = "SECURE BOOT HAZIRLANIYOR"
    @State private var showCompleted = false

    @State private var sequenceTask: Task<Void, Never>?

    private let modules = ["TAHTA", "KASA", "KULIS", "REJIM", "ORACLE", "RISK"]
    private let bootScript = [
        "[INIT] Core integrity check",
        "[SYNC] Council topology restored",
        "[LOAD] Market routers engaged",
        "[BIND] Portfolio shield active",
        "[READY] Strategy chamber online"
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compact = size.width < 380
            let coreSize: CGFloat = compact ? 214 : 248

            ZStack {
                backgroundLayer

                SplashConstellationLayer(pulse: starPulse)
                    .opacity(0.28)
                    .ignoresSafeArea()

                SplashCommandGridLayer(shift: gridShift)
                    .opacity(0.24)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        InstitutionalTheme.Colors.primary.opacity(0.18),
                        InstitutionalTheme.Colors.warning.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.54
                )
                .blur(radius: 24)
                .ignoresSafeArea()
                .opacity(coreOpacity)

                VStack(spacing: compact ? 14 : 18) {
                    sigil(size: coreSize)

                    VStack(spacing: compact ? 8 : 10) {
                        Text("ARGUS")
                            .font(.system(size: compact ? 34 : 40, weight: .semibold, design: .rounded))
                            .tracking(compact ? 7 : 9)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(coreOpacity))

                        Text("INSTITUTIONAL DECISION CORE")
                            .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .monospaced))
                            .tracking(2.8)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(coreOpacity))
                    }

                    moduleRow(compact: compact)
                        .padding(.top, compact ? 2 : 4)

                    bootPanel(compact: compact)
                        .padding(.top, compact ? 2 : 6)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(sceneOpacity)
                .scaleEffect(sceneScale)

                LinearGradient(
                    colors: [.black.opacity(0.50), .clear, .black.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            startSequence()
        }
        .onDisappear {
            sequenceTask?.cancel()
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                InstitutionalTheme.Colors.background,
                InstitutionalTheme.Colors.surface1,
                InstitutionalTheme.Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func sigil(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            InstitutionalTheme.Colors.primary.opacity(0.18),
                            InstitutionalTheme.Colors.primary,
                            InstitutionalTheme.Colors.warning,
                            InstitutionalTheme.Colors.primary.opacity(0.18)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .rotationEffect(.degrees(ringRotation - 90))
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0.05, to: 0.95)
                .stroke(
                    InstitutionalTheme.Colors.primary.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 8])
                )
                .rotationEffect(.degrees(-ringRotation * 0.6))
                .frame(width: size - 26, height: size - 26)

            HexagonShape()
                .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                .frame(width: size - 76, height: size - 76)
                .rotationEffect(.degrees(coreRotation))

            Circle()
                .stroke(InstitutionalTheme.Colors.primary.opacity(0.26), lineWidth: 7)
                .frame(width: size - 90, height: size - 90)
                .blur(radius: 8)
                .scaleEffect(lensPulse)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, InstitutionalTheme.Colors.primary.opacity(0.78), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size + 36, height: 2)
                .offset(y: scanPosition)
                .opacity(coreOpacity)

            Text("A")
                .font(.system(size: size * 0.27, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.94))
                .shadow(color: InstitutionalTheme.Colors.primary.opacity(0.35), radius: 16, x: 0, y: 0)
        }
        .scaleEffect(coreScale)
        .opacity(coreOpacity)
    }

    private func moduleRow(compact: Bool) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(modules.indices, id: \.self) { idx in
                HStack(spacing: 6) {
                    Circle()
                        .fill(moduleStates[idx] ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.textTertiary.opacity(0.45))
                        .frame(width: 6, height: 6)

                    Text(modules[idx])
                        .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(moduleStates[idx] ? InstitutionalTheme.Colors.textPrimary : InstitutionalTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: compact ? 22 : 24)
                .padding(.horizontal, compact ? 7 : 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface2.opacity(moduleStates[idx] ? 0.88 : 0.62))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            moduleStates[idx] ? InstitutionalTheme.Colors.borderStrong : InstitutionalTheme.Colors.borderSubtle,
                            lineWidth: 1
                        )
                )
                .opacity(moduleStates[idx] ? 1 : 0.78)
                .scaleEffect(moduleStates[idx] ? 1 : 0.95)
            }
        }
        .frame(maxWidth: 470)
    }

    private func bootPanel(compact: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(showCompleted ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.warning)
                    .frame(width: 8, height: 8)

                Text(showCompleted ? "BOOT COMPLETE" : "BOOTING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                Spacer()

                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bootScript.indices, id: \.self) { idx in
                    Text(bootScript[idx])
                        .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
                        .foregroundColor(colorForBootLine(index: idx))
                        .lineLimit(1)
                        .opacity(visibleBootLines > idx ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: compact ? 62 : 70, alignment: .topLeading)

            VStack(spacing: 6) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(InstitutionalTheme.Colors.surface3)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        InstitutionalTheme.Colors.primary.opacity(0.76),
                                        InstitutionalTheme.Colors.warning.opacity(0.72)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * progressValue)
                    }
                }
                .frame(height: 7)

                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 11 : 12)
        .frame(maxWidth: 470)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface1.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
        )
    }

    private func colorForBootLine(index: Int) -> Color {
        if visibleBootLines > index {
            return showCompleted
                ? InstitutionalTheme.Colors.positive.opacity(0.92)
                : InstitutionalTheme.Colors.textPrimary.opacity(0.93)
        }
        return InstitutionalTheme.Colors.textTertiary.opacity(0.4)
    }

    private func startSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task {
            await runSequence()
        }
    }

    private func runSequence() async {
        let step: UInt64 = reduceMotion ? 70 : 130

        await MainActor.run {
            withAnimation(.easeOut(duration: reduceMotion ? 0.20 : 0.38)) {
                sceneOpacity = 1
                sceneScale = 1
                coreOpacity = 1
                coreScale = 1
            }

            withAnimation(.linear(duration: reduceMotion ? 6 : 10).repeatForever(autoreverses: false)) {
                gridShift = 38
                ringRotation = 360
            }

            withAnimation(.easeInOut(duration: reduceMotion ? 1.0 : 1.6).repeatForever(autoreverses: true)) {
                lensPulse = 1.03
                starPulse = 1
            }
        }

        guard await pause(milliseconds: step) else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: reduceMotion ? 0.38 : 0.72)) {
                ringProgress = 1
                coreRotation = 0
            }
        }

        guard await pause(milliseconds: step) else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: reduceMotion ? 0.34 : 1.02)) {
                scanPosition = 150
            }
        }

        for idx in bootScript.indices {
            await MainActor.run {
                withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.26)) {
                    visibleBootLines = idx + 1
                    progressValue = min(0.78, Double(idx + 1) / Double(bootScript.count + 1))
                }
            }
            guard await pause(milliseconds: step) else { return }
        }

        for idx in modules.indices {
            await MainActor.run {
                withAnimation(.spring(response: reduceMotion ? 0.18 : 0.40, dampingFraction: 0.84)) {
                    moduleStates[idx] = true
                    progressValue = min(0.94, progressValue + 0.03)
                }
            }
            guard await pause(milliseconds: step / 2 + 32) else { return }
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: reduceMotion ? 0.16 : 0.3)) {
                statusText = "ARGUS CORE STABLE"
                progressValue = 1
                showCompleted = true
            }
        }

        guard await pause(milliseconds: reduceMotion ? 220 : 560) else { return }

        await MainActor.run {
            withAnimation(.easeIn(duration: reduceMotion ? 0.2 : 0.42)) {
                sceneOpacity = 0
                sceneScale = 1.02
            }
        }

        guard await pause(milliseconds: reduceMotion ? 180 : 420) else { return }
        await MainActor.run {
            onFinished()
        }
    }

    private func pause(milliseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

private struct SplashConstellationLayer: View {
    let pulse: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(0..<40, id: \.self) { idx in
                    let point = starPoint(for: idx, in: size)
                    Circle()
                        .fill(InstitutionalTheme.Colors.textPrimary)
                        .frame(width: idx % 7 == 0 ? 2.4 : 1.4, height: idx % 7 == 0 ? 2.4 : 1.4)
                        .opacity(baseOpacity(for: idx) + pulse * 0.10)
                        .position(point)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func starPoint(for index: Int, in size: CGSize) -> CGPoint {
        let normalizedX = (sin(Double(index) * 12.37) * 0.5) + 0.5
        let normalizedY = (cos(Double(index) * 8.11) * 0.5) + 0.5
        return CGPoint(
            x: normalizedX * size.width,
            y: normalizedY * size.height
        )
    }

    private func baseOpacity(for index: Int) -> Double {
        0.06 + Double((index * 13) % 9) * 0.01
    }
}

private struct SplashCommandGridLayer: View {
    let shift: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let spacing: CGFloat = 34
            let shifted = shift.truncatingRemainder(dividingBy: spacing)

            Path { path in
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                for y in stride(from: -spacing + shifted, through: height + spacing, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(InstitutionalTheme.Colors.primary.opacity(0.22), lineWidth: 0.45)
        }
        .allowsHitTesting(false)
    }
}

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for index in 0..<6 {
            let angle = Angle.degrees(Double(index) * 60 - 90).radians
            let point = CGPoint(
                x: center.x + CGFloat(Foundation.cos(angle)) * radius,
                y: center.y + CGFloat(Foundation.sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
