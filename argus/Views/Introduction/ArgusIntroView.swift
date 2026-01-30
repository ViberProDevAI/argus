//
//  ArgusIntroView.swift
//  Algo-Trading
//
//  Created by Argus Team on 27.01.2026.
//

import SwiftUI

struct ArgusIntroView: View {
    let onFinished: () -> Void
    
    // Animation States
    @State private var showLogo = false
    @State private var showText = false
    @State private var glitchEffect = false
    @State private var ringRotation = 0.0
    @State private var ringScale = 0.5
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
            Color.black.ignoresSafeArea()
            
            // 2. Cyber Grid (Subtle)
            CyberGridBackground()
                .opacity(0.2)
            
            VStack {
                Spacer()
                
                // 3. Holographic Logo Construction
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.cyan, .blue, .purple, .cyan],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(ringRotation))
                        .scaleEffect(showLogo ? 1.0 : 0.1)
                        .opacity(showLogo ? 0.8 : 0)
                        .shadow(color: .cyan.opacity(0.8), radius: 10)
                    
                    // Inner Data Ring
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 10]))
                        .foregroundColor(.blue.opacity(0.8))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-ringRotation * 1.5))
                        .scaleEffect(showLogo ? 1.0 : 0.1)
                    
                    // Core Eye (Argus)
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.cyan)
                        .shadow(color: .white, radius: glitchEffect ? 20 : 5)
                        .scaleEffect(showLogo ? 1.0 : 0.01)
                        .offset(x: glitchEffect ? 5 : 0, y: glitchEffect ? -2 : 0)
                }
                .frame(width: 200, height: 200) // Fixed frame for logo container
                
                Spacer().frame(height: 40)
                
                // 4. Glitch Text Title
                if showText {
                    Text("ARGUS TERMINAL")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(8)
                        .shadow(color: .purple.opacity(0.8), radius: 10)
                        .offset(x: glitchEffect ? -3 : 0)
                        .opacity(glitchEffect ? 0.7 : 1.0)
                }
                
                Spacer().frame(height: 80)
                
                // 5. Terminal Boot Log
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(terminalLogs, id: \.self) { log in
                        Text("> \(log)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
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

// Helper: Cyber Grid
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
            .stroke(Color.cyan, lineWidth: 0.5)
        }
    }
}
