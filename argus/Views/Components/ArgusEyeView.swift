import SwiftUI
import Combine

// MARK: - Argus Mode (Configuration)
enum ArgusMode {
    case argus
    case atlas
    case aether
    case orion
    case demeter
    case hermes
    case athena
    case poseidon
    case phoenix
    case scout
    case council
    case offline
    
    var color: Color {
        switch self {
        case .argus: return Theme.tint // Generic Blue
        case .atlas: return Color.blue // Deep Blue
        case .aether: return Color.cyan // Sky Blue
        case .orion: return Color.purple // Mystery
        case .demeter: return Color.green // Sector/Growth
        case .hermes: return Color.pink // Speed
        case .athena: return Color.teal // Wisdom
        case .poseidon: return Color.indigo // Depth
        case .phoenix: return Color.red // Rebirth
        case .scout: return Color.green // Discovery
        case .council: return Color.yellow // Governance (Gold)
        case .offline: return Color.gray
        }
    }
}

// MARK: - Cyber Shutter (Blinking Eyelid)
struct CyberEyelid: View {
    let delay: Double
    let position: CGPoint // Relative 0-1
    let scale: CGFloat
    
    @State private var isBlinking = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The Eyelid (Dark Metallic Cover)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.4)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // When not blinking (Open), scaleY is 0 (thin line hidden)
                    // When blinking (Closed), scaleY is 1 (Full cover)
                    .scaleEffect(y: isBlinking ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.15), value: isBlinking)
            }
            .frame(width: geo.size.width * scale, height: geo.size.width * scale)
            .position(x: geo.size.width * position.x, y: geo.size.height * position.y)
        }
        .onAppear {
            scheduleBlink()
        }
    }
    
    func scheduleBlink() {
        // Random blink interval for complex "alive" feel
        // Main eye (center) blinks less often
        let isCenter = abs(position.x - 0.5) < 0.1
        let interval = isCenter ? Double.random(in: 3.0...7.0) : Double.random(in: 0.5...3.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + interval) {
            // Close
            isBlinking = true
            
            // Re-open after short time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
                scheduleBlink() // Loop
            }
        }
    }
}

// MARK: - Animated Argus V2 Eye (Programmatic)
struct ArgusEyeView: View {
    var mode: ArgusMode = .argus
    var size: CGFloat = 80 // Base Size
    var isElliptical: Bool = false
    
    @State private var isAnimating = false
    @State private var blinkState: CGFloat = 0.0 // 0.0 = Open, 1.0 = Closed
    @State private var pupilDilation: CGFloat = 1.0
    @State private var lookOffset: CGSize = .zero
    
    // Animation Timers
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 1. Outer Glow (Halo)
            Circle()
                .fill(mode.color)
                .frame(width: size, height: size)
                .blur(radius: size * 0.5)
                .opacity(isAnimating ? 0.4 : 0.2)
                .scaleEffect(isAnimating ? 1.2 : 0.9)
            
            // 2. The Globe (Sclera equivalent - Tech Sphere)
            ZStack {
                // Background Sphere
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3), Color.black]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().stroke(mode.color.opacity(0.3), lineWidth: 1)
                    )
                
                // 3. The Iris & Pupil (Dynamic)
                ZStack {
                    // Iris Glow
                    Circle()
                        .fill(mode.color.opacity(0.5))
                        .frame(width: size * 0.5, height: size * 0.5)
                        .blur(radius: 5)
                    
                    // Iris Detail (Rings)
                    Circle()
                        .strokeBorder(mode.color, lineWidth: 2)
                        .frame(width: size * 0.45, height: size * 0.45)
                    
                    Circle()
                        .strokeBorder(mode.color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .frame(width: size * 0.55, height: size * 0.55)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    
                    // Pupil (The Void)
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.25 * pupilDilation, height: size * 0.25 * pupilDilation)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .offset(lookOffset) // Eye Movement
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: lookOffset)
                
                // 4. Glare / Reflection (Glass effect)
                Circle()
                    .trim(from: 0.1, to: 0.25)
                    .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .rotationEffect(.degrees(-45))
                
            }
            // Eyelid Mask (Blinking)
            .mask(
                GeometryReader { geo in
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                        
                        // Upper Lid
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: geo.size.height / 2 * blinkState)
                            .offset(y: -geo.size.height / 4) // Start from top
                            .position(x: geo.size.width / 2, y: 0 + (geo.size.height / 2 * blinkState) / 2)
                        
                        // Lower Lid
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: geo.size.height / 2 * blinkState)
                            .offset(y: geo.size.height / 4)
                            .position(x: geo.size.width / 2, y: geo.size.height - (geo.size.height / 2 * blinkState) / 2)
                    }
                }
            )
            
            // 5. Tech Ring overlay (Rotates independent of blink)
            if mode != .offline {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(mode.color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [size * 0.1, 5]))
                    .frame(width: size * 1.15, height: size * 1.15)
                    .rotationEffect(.degrees(isAnimating ? -360 : 0))
            }
        }
        .scaleEffect(x: isElliptical ? 1.2 : 1.0, y: isElliptical ? 0.8 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            startLifeCycle()
        }
    }
    
    // MARK: - Life Cycle Logic
    
    func startLifeCycle() {
        // Random Blinking
        scheduleBlink()
        // Random Eye Movement
        scheduleLook()
        // Random Dilation
        scheduleDilation()
    }
    
    func scheduleBlink() {
        let interval = Double.random(in: 2.0...6.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            // Close
            withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                blinkState = 1.0
            }
            // Open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    blinkState = 0.0
                }
                scheduleBlink()
            }
        }
    }
    
    func scheduleLook() {
        let interval = Double.random(in: 1.0...4.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            // Random gaze offset (limited by size)
            let limit = size * 0.15
            let x = CGFloat.random(in: -limit...limit)
            let y = CGFloat.random(in: -limit...limit)
            lookOffset = CGSize(width: x, height: y)
            
            // Sometimes return to center
            if Bool.random() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    lookOffset = .zero
                }
            }
            scheduleLook()
        }
    }
    
    func scheduleDilation() {
        withAnimation(.easeInOut(duration: 2.0)) {
            pupilDilation = CGFloat.random(in: 0.8...1.3)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            scheduleDilation()
        }
    }
}
