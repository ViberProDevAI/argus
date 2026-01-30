import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void // Controls app launch state
    
    // Animation States
    @State private var eyeOpacity: Double = 0.0
    @State private var eyeScale: CGFloat = 0.95
    @State private var glowOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // 1. Absolute Black Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 2. Main Content
            VStack(spacing: 50) {
                
                // The Eye (Logo)
                ZStack {
                    // Outer Glow (Breathing Shadow)
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .blur(radius: 30)
                        .scaleEffect(eyeScale)
                        .opacity(glowOpacity)
                    
                    // The Icon
                    Image("SplashLogo") // Utilizes the new asset
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .cornerRadius(20) // Subtle rounding if needed, though icon is borderless
                        .opacity(eyeOpacity)
                        .scaleEffect(eyeScale)
                }
                
                // 3. Brand Name
                VStack(spacing: 12) {
                    Text("ARGUS")
                        .font(.custom("HelveticaNeue-CondensedBold", size: 42))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(12) // Very wide stance
                        .opacity(textOpacity)
                    
                    Text("YATIRIM KONSEYİ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                        .tracking(6)
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            startSeriousAnimation()
        }
    }
    
    private func startSeriousAnimation() {
        // Phase 1: Eye Emerges from Darkness (Slow & Heavy)
        withAnimation(.easeInOut(duration: 1.8)) {
            eyeOpacity = 1.0
            glowOpacity = 1.0
        }
        
        // Phase 2: Subtle Breathing (The eye is alive)
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            eyeScale = 1.05
        }
        
        // Phase 3: Identity Reveal (Delayed)
        withAnimation(.easeOut(duration: 1.2).delay(0.8)) {
            textOpacity = 1.0
        }
        
        // Phase 4: Transition to App (Wait for user to feel the weight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                // Fade out everything to black
                eyeOpacity = 0.0
                textOpacity = 0.0
                glowOpacity = 0.0
            }
            
            // Handover
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onFinished()
            }
        }
    }
}
