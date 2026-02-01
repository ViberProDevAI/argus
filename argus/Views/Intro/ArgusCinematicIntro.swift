import SwiftUI
import UIKit

///  THE PRISM INTRO 
/// A high-end, holographic reveal of the Argus identity.
struct ArgusCinematicIntro: View {
    var onFinished: () -> Void
    
    // Animation States
    @State private var phase = 0 // 0: Start, 1: Prism Rise, 2: Eye Open, 3: Flash, 4: Text, 5: End
    
    // Geometry States
    @State private var rotation: Double = 30
    @State private var prismScale: CGFloat = 0.5
    @State private var prismOpacity: Double = 0.0
    @State private var eyeScale: CGFloat = 0.01
    @State private var eyeOpacity: Double = 0.0
    @State private var flashOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var textSpacing: CGFloat = 20
    
    // Haptics
    private let impact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .light)
    
    // Colors
    let voidBlack = Color(hex: "050505")
    let hologramGold = Color(hex: "FFD700") // Pure Gold
    let hologramCore = Color(hex: "FFF8E7") // Bright Core
    
    var body: some View {
        ZStack {
            // 1. VOID CANVAS
            voidBlack.ignoresSafeArea()
            
            // Nebula / Ambient Glow
            Circle()
                .fill(hologramGold.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .scaleEffect(phase >= 1 ? 1.0 : 0.5)
                .opacity(phase >= 1 ? 0.3 : 0.0)
            
            VStack(spacing: 60) {
                // 2. THE PRISM ARTIFACT
                ZStack {
                    // Outer Triangle (The Shell)
                    PrismShape()
                        .stroke(
                            LinearGradient(
                                colors: [.clear, hologramGold, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 180, height: 160)
                        .scaleEffect(prismScale)
                        .opacity(prismOpacity)
                        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                        .shadow(color: hologramGold.opacity(0.5), radius: 20)
                    
                    // Inner Triangle (The Core Reflection)
                    PrismShape()
                        .fill(hologramGold.opacity(0.05))
                        .frame(width: 160, height: 140)
                        .scaleEffect(prismScale)
                        .opacity(prismOpacity * 0.5)
                        .rotation3DEffect(.degrees(-rotation), axis: (x: 0, y: 1, z: 0))
                        .blur(radius: 2)
                    
                    // THE EYE (All-Seeing)
                    ZStack {
                        // Pupil
                        Capsule()
                            .fill(hologramCore)
                            .frame(width: 8, height: 24)
                        
                        // Iris Ring
                        Circle()
                            .stroke(hologramGold, lineWidth: 2)
                            .frame(width: 40, height: 40)
                        
                        // Rays
                        ForEach(0..<8) { i in
                            Rectangle()
                                .fill(hologramGold)
                                .frame(width: 1, height: 10)
                                .offset(y: -28)
                                .rotationEffect(.degrees(Double(i) * 45))
                        }
                    }
                    .scaleEffect(eyeScale)
                    .opacity(eyeOpacity)
                    // Offset to Optical Center of Triangle (approx 1/3 from bottom, but geometrically focused)
                    // Triangle Height 160. Centroid is at 1/3 height from base.
                    // Visual center usually feels better slightly higher.
                    .offset(y: 15) 
                    .shadow(color: hologramGold, radius: 15)
                }
                .overlay(
                    // FLASH EFFECT
                    Color.white
                        .opacity(flashOpacity)
                        .mask(Circle().blur(radius: 20))
                        .frame(width: 300, height: 300)
                )
                
                // 3. THE IDENTITY
                Text("A R G U S")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .tracking(textSpacing)
                    .foregroundColor(hologramCore)
                    .shadow(color: hologramGold, radius: 10)
                    .opacity(textOpacity)
                    .overlay(
                        // Shine across text
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing))
                            .rotationEffect(.degrees(20))
                            .offset(x: phase >= 4 ? 200 : -200)
                            .mask(Text("A R G U S").font(.system(size: 28, weight: .bold, design: .serif)).tracking(textSpacing))
                            .animation(phase >= 4 ? .easeInOut(duration: 1.5) : .default, value: phase)
                    )
            }
        }
        .onAppear {
            runSequence()
        }
    }
    
    private func runSequence() {
        // Step 1: Initialize
        impact.prepare()
        
        // Step 2: Prism Rise (0.0s -> 1.5s)
        withAnimation(.easeOut(duration: 1.5)) {
            phase = 1
            prismOpacity = 1.0
            prismScale = 1.0
            rotation = 0 // Align to flat
        }
        
        // Step 3: Eye Open (1.5s -> 2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            softImpact.impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                phase = 2
                eyeOpacity = 1.0
                eyeScale = 1.0
            }
        }
        
        // Step 4: The Flash (Ignition) (2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            impact.impactOccurred()
            
            // Flash Burst
            withAnimation(.easeIn(duration: 0.1)) {
                flashOpacity = 1.0
            }
            
            // Flash Fade
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                flashOpacity = 0.0
            }
        }
        
        // Step 5: Text Reveal (2.1s -> 3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeOut(duration: 1.2)) {
                phase = 4
                textOpacity = 1.0
                textSpacing = 12 // Condense slightly
            }
        }
        
        // Step 6: Completion (4.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                phase = 5
                onFinished()
            }
        }
    }
}

// MARK: - GEOMETRY
struct PrismShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Equilateral Triangle Logic
        let topPoint = CGPoint(x: width / 2, y: 0)
        let bottomLeft = CGPoint(x: 0, y: height)
        let bottomRight = CGPoint(x: width, y: height)
        
        path.move(to: bottomLeft)
        path.addLine(to: topPoint)
        path.addLine(to: bottomRight)
        path.closeSubpath()
        return path
    }
}

#Preview {
    ArgusCinematicIntro(onFinished: {})
}
