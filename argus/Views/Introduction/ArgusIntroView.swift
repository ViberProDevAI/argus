//
//  ArgusIntroView.swift
//  Algo-Trading
//
//  V5: Holographic boot sequence. Raw SwiftUI renkleri (`.cyan`, `.blue`,
//  `.purple`) Institutional token'ları ile değiştirildi. Terminal log,
//  amblem inşaası ve glitch efekti korunuyor.
//

import SwiftUI

struct ArgusIntroView: View {
    let onFinished: () -> Void

    // Animation States
    @State private var showLogo = false
    @State private var showText = false
    @State private var glitchEffect = false
    @State private var ringRotation = 0.0
    @State private var opacity = 1.0
    @State private var terminalLogs: [String] = []

    // Boot Sequence Logs
    let bootLogs = [
        "Initializing Core Systems...",
        "Loading Neural Modules: [ORION, ATLAS, AETHER]...",
        "Establishing Secure Link to BIST...",
        "Calibrating Quantum Sensors...",
        "Syncing Portfolio Ledger...",
        "Decrypting User Keys...",
        "Optimizing Holographic Drivers...",
        "Checking Sentinel Protocols...",
        "System Green. Access Granted."
    ]

    var body: some View {
        ZStack {
            // 1. Deep Void Background
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            // 2. Cyber Grid (Subtle)
            CyberGridBackground()
                .opacity(0.18)

            VStack {
                Spacer()

                // 3. Holographic Logo Construction
                ZStack {
                    // Outer Ring — holo + titan angular gradient
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    InstitutionalTheme.Colors.holo,
                                    InstitutionalTheme.Colors.titan,
                                    InstitutionalTheme.Colors.primary,
                                    InstitutionalTheme.Colors.holo
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(ringRotation))
                        .scaleEffect(showLogo ? 1.0 : 0.1)
                        .opacity(showLogo ? 0.85 : 0)
                        .shadow(color: InstitutionalTheme.Colors.holo.opacity(0.7), radius: 12)

                    // Inner Data Ring (dashed, counter-rotating)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 10]))
                        .foregroundColor(InstitutionalTheme.Colors.primary.opacity(0.8))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-ringRotation * 1.5))
                        .scaleEffect(showLogo ? 1.0 : 0.1)

                    // Core Eye (Argus)
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(InstitutionalTheme.Colors.holo)
                        .shadow(color: InstitutionalTheme.Colors.textPrimary,
                                radius: glitchEffect ? 20 : 5)
                        .scaleEffect(showLogo ? 1.0 : 0.01)
                        .offset(x: glitchEffect ? 5 : 0, y: glitchEffect ? -2 : 0)
                }
                .frame(width: 200, height: 200)

                Spacer().frame(height: 40)

                // 4. Glitch Text Title
                if showText {
                    Text("ARGUS TERMINAL")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .tracking(8)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .shadow(color: InstitutionalTheme.Colors.holo.opacity(0.75), radius: 10)
                        .offset(x: glitchEffect ? -3 : 0)
                        .opacity(glitchEffect ? 0.7 : 1.0)
                }

                Spacer().frame(height: 80)

                // 5. Terminal Boot Log
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(terminalLogs, id: \.self) { log in
                        HStack(spacing: 6) {
                            Text(">")
                                .foregroundColor(InstitutionalTheme.Colors.titan)
                            Text(log)
                                .foregroundColor(InstitutionalTheme.Colors.aurora)
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .transition(.opacity)
                    }
                }
                .frame(height: 100, alignment: .bottomLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .opacity(opacity)
        .onAppear {
            startBootSequence()
        }
    }

    private func startBootSequence() {
        // Logo Animation (Slower, heavier spring for premium feel)
        withAnimation(.spring(response: 1.5, dampingFraction: 0.9)) {
            showLogo = true
        }

        // Endless Rotation (Slower, more majestic)
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Text Appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 1.0)) { showText = true }
        }

        // Glitch Effect Loop
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if Int.random(in: 0...10) > 8 {
                glitchEffect.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    glitchEffect = false
                }
            }
        }

        // Terminal Typing Effect
        var delay = 1.5
        for log in bootLogs {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if terminalLogs.count > 5 { terminalLogs.removeFirst() }
                terminalLogs.append(log)

                // Haptic Feedback (Lighter, sophisticated tick)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            delay += Double.random(in: 0.2...0.5)
        }

        // Finish Transition (Keep logic onscreen longer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onFinished()
            }
        }
    }
}

// Helper: Cyber Grid — holo-tinted
struct CyberGridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 40

                // Vertical Lines
                for x in stride(from: 0, to: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                // Horizontal Lines
                for y in stride(from: 0, to: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(InstitutionalTheme.Colors.holo.opacity(0.6), lineWidth: 0.5)
        }
    }
}
