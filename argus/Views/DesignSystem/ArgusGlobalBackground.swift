import SwiftUI

/// The Living Background of Argus
/// A subtle, animated nebula effect that gives depth to the void.
struct ArgusGlobalBackground: View {
    @State private var startAnimation = false
    
    var body: some View {
        ZStack {
            // 1. Void Base
            Theme.background
                .ignoresSafeArea()
            
            // 2. Deep Nebula (Slow Spinning)
            GeometryReader { proxy in
                let size = proxy.size
                
                ZStack {
                    // Blue Nebula
                    Circle()
                        .fill(Theme.accent.opacity(0.1))
                        .frame(width: size.width * 1.5, height: size.width * 1.5)
                        .blur(radius: 80)
                        .offset(x: -size.width * 0.4, y: -size.height * 0.3)
                        .scaleEffect(startAnimation ? 1.1 : 1.0)
                    
                    // Gold Nebula (Argus Eye)
                    Circle()
                        .fill(Theme.primary.opacity(0.05))
                        .frame(width: size.width * 1.2, height: size.width * 1.2)
                        .blur(radius: 60)
                        .offset(x: size.width * 0.4, y: size.height * 0.4)
                        .rotationEffect(.degrees(startAnimation ? 360 : 0))
                }
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: startAnimation)
            }
            
            // 3. Stardust (Particles)
            // Optional: Can add a looping particle system here if performance allows.
            // For now, gradient mesh provides enough "living" feel.
            
            // 4. Vignette (Focus on Center)
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                center: .center,
                startRadius: 200,
                endRadius: 800
            )
            .ignoresSafeArea()
            
            // 5. Grid Overlay (Subtle Tech Feel)
            /*
            Image("grid_pattern") // If we had an asset
                .resizable()
                .opacity(0.05)
                .blendMode(.overlay)
            */
        }
        .onAppear {
            startAnimation = true
        }
    }
}

#Preview {
    ArgusGlobalBackground()
}
